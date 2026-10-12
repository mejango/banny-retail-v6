#!/usr/bin/env node

// The official SDK owns proposal storage and submission. This adapter qualifies every part first.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { parseArgs } = require('node:util');
const { ethers } = require('ethers');
const core = require('@sphinx-labs/core');
const contracts = require('@sphinx-labs/contracts');
const utils = require('@sphinx-labs/plugins/dist/foundry/utils');
const { decodeDeploymentInfo, makeNetworkConfig } = require('@sphinx-labs/plugins/dist/foundry/decode');
const { makeSphinxContext } = require('@sphinx-labs/plugins/dist/cli/context');
const { makeCLI } = require('@sphinx-labs/plugins/dist/cli/setup');
const { propose } = require('@sphinx-labs/plugins/dist/cli/propose');
const exporter = require('./export-safe-airdrop');
const generator = require('./generate-v6-airdrop');

const ROOT = path.resolve(__dirname, '../..');
const NOOP = ethers.utils.id('sphinxFetchConfig()').slice(0, 10);
const RUN = ethers.utils.id('run()').slice(0, 10);

function selectChunks(batches, plans, env = process.env) {
    const read = name => {
        const value = env[name] || '0';
        assert(/^(0|[1-9]\d*)$/.test(value), `Invalid ${name}`);
        const number = Number(value);
        assert(Number.isSafeInteger(number) && number <= plans.length, `Invalid ${name}`);
        return number;
    };
    const exact = read('BANNY_AIRDROP_CHUNK');
    const maximum = read('BANNY_AIRDROP_MAX_CHUNK');
    assert(!(exact && maximum), 'Choose exact chunk or max chunk');
    const included = chunk => exact ? chunk === exact : !maximum || chunk <= maximum;
    const selected = batches.filter(({ safeTransaction: tx }) => tx.stage === 'setup' || included(tx.chunk));
    assert(selected.some(({ safeTransaction: tx }) => tx.stage === 'migration'), 'No selected airdrop migrations');
    return { batches: selected, plans: plans.filter((_, index) => included(index + 1)) };
}

function deploymentsFor(prepared, configArtifacts) {
    if (prepared.safeTransaction.stage !== 'setup') return [];
    return prepared.batch.transactions.map(tx => {
        assert.equal(tx.to.toLowerCase(), exporter.FACTORY.toLowerCase(), 'Unexpected setup target');
        const { create2Address: address, initCodeWithArgs } = core.decodeDeterministicDeploymentProxyData(tx.data);
        const fullyQualifiedName = utils.findFullyQualifiedNameForInitCode(initCodeWithArgs, configArtifacts);
        assert(fullyQualifiedName, 'Setup bytecode is missing its compiler artifact');
        return { address, initCodeWithArgs, fullyQualifiedName };
    });
}

function actionFor(prepared, index, configArtifacts) {
    const tx = prepared.safeTransaction;
    assert.equal(tx.transaction.value, '0');
    assert([0, 1].includes(tx.transaction.operation));
    assert(tx.stage === 'setup' || tx.stage === 'migration');
    return {
        actionType: core.ActionInputType.CALL,
        to: tx.transaction.to, value: tx.transaction.value, txData: tx.transaction.data,
        operation: tx.transaction.operation, gas: '0', requireSuccess: true, index: String(index + 1),
        contracts: deploymentsFor(prepared, configArtifacts),
        decodedAction: {
            referenceName: 'BannyAirdrop', functionName: tx.stage === 'setup' ? 'deploySafeExecutor' : 'mintAndMigrate',
            address: tx.transaction.to, value: '0',
            variables: tx.stage === 'setup' ? { implementation: tx.implementation, executor: tx.helper }
                : { chunk: tx.chunk, slice: tx.slice, executor: tx.helper, tokenIds: tx.expectedTokenIds },
        },
    };
}

function pinReads(provider, blockNumber) {
    const perform = provider.perform.bind(provider);
    provider.perform = (method, params) => perform(method,
        ['call', 'getCode', 'getBalance', 'getStorageAt'].includes(method)
            ? { ...params, blockTag: ethers.utils.hexValue(blockNumber) } : params);
    return provider;
}

function sourceIdentity(items, artifacts, sourceHashes) {
    return createHash('sha256').update(JSON.stringify({ items,
        artifacts: [...artifacts].sort(([a], [b]) => a.localeCompare(b)).map(([name, artifact]) => {
            const metadata = artifact.metadata || JSON.parse(artifact.rawMetadata || '{}');
            // AST IDs and source maps depend on the compilation group, even when executable code is identical.
            // Preserve each immutable's reference group while replacing its compiler-local numeric ID.
            const immutables = Object.values(artifact.deployedBytecode?.immutableReferences || {})
                .map(references => references.map(({ start, length }) => ({ start, length }))
                    .sort((a, b) => a.start - b.start || a.length - b.length))
                .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
            return [name, { abi: artifact.abi, compiler: metadata.compiler || artifact.compiler,
                settings: metadata.settings || artifact.settings,
                bytecode: { object: artifact.bytecode?.object ?? artifact.bytecode,
                    linkReferences: artifact.bytecode?.linkReferences || {} },
                deployedBytecode: { object: artifact.deployedBytecode?.object ?? artifact.deployedBytecode,
                    linkReferences: artifact.deployedBytecode?.linkReferences || {}, immutableReferences: immutables } }];
        }),
        sources: [...sourceHashes].sort(([a], [b]) => a.localeCompare(b)),
    })).digest('hex');
}

async function ensureBuildInfo(getConfigArtifacts, helperPlans, root = ROOT, readInitCodes) {
    const initCodes = readInitCodes || (() => {
        const executor = exporter.readCompiledArtifact('SafeAirdropExecutor', 'script/helpers/SafeAirdropExecutor.sol', root);
        // Constructor values do not affect compiler matching; these are never execution actions.
        const executorProbe = executor.bytecode.object + ethers.utils.defaultAbiCoder.encode(
            ['address', 'address'], [ethers.constants.AddressZero, ethers.constants.AddressZero]).slice(2);
        return [executorProbe, ...Object.values(helperPlans).flat().map(plan => exporter.readArtifact(plan, root).bytecode.object)];
    });
    const unresolved = async () => {
        const codes = initCodes();
        try {
            const { configArtifacts } = await getConfigArtifacts(codes);
            return codes.some(code => !utils.findFullyQualifiedNameForInitCode(code, configArtifacts));
        } catch (error) {
            if (error.code === 'ENOENT') return true;
            throw error;
        }
    };
    if (!await unresolved()) return;
    // An earlier ordinary build can leave current bytecode without build-info. Force one native
    // rebuild, with a disposable cache so Foundry cannot erase previous qualification/diagnostic files.
    const temporaryCache = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-sphinx-build-'));
    try {
        const output = await core.spawnAsync('forge', ['build', '--root', root, '--force', '--build-info',
            '--cache-path', temporaryCache, '--silent']);
        assert.equal(output.code, 0, 'Failed to rebuild Sphinx compiler metadata; no proposal was submitted');
        assert(!await unresolved(), 'Rebuilt setup bytecode still lacks Sphinx compiler metadata');
    } finally { fs.rmSync(temporaryCache, { recursive: true, force: true }); }
}

async function collectNetworkContext({ scriptPath, safe, rpcUrl, pluginInterface, targetContract, reportDir }) {
    const provider = new ethers.providers.JsonRpcProvider({ url: rpcUrl, timeout: 30000 });
    const chainId = (await provider.getNetwork()).chainId;
    const profile = Object.keys(exporter.NETWORKS).find(key => exporter.NETWORKS[key].some(n => n.chainId === chainId));
    assert(profile, `Unsupported airdrop chain ${chainId}`);
    const network = exporter.NETWORKS[profile].find(n => n.chainId === chainId);
    const block = await provider.getBlock('latest');
    assert(block && block.hash && block.number > 0, `Missing chain ${chainId} block`);
    pinReads(provider, block.number);
    const collectionPath = path.join(reportDir, `${chainId}-context.json`);
    const args = ['script', scriptPath, '--rpc-url', rpcUrl, '--fork-block-number', String(block.number),
        '--sig', 'sphinxCollectProposal(bytes,string,uint64)', NOOP, collectionPath,
        '--always-use-create-2-factory', String(core.DEFAULT_CALL_DEPTH)];
    if (targetContract) args.push('--target-contract', targetContract);
    const output = await core.spawnAsync('forge', args, { FOUNDRY_BUILD_INFO: 'false' });
    // Forge errors can contain its credential-bearing RPC argument. Keep those logs local to the process.
    assert.equal(output.code, 0, `Sphinx context collection failed on ${network.folder}; no proposal was submitted`);
    const info = decodeDeploymentInfo(fs.readFileSync(collectionPath, 'utf8'), pluginInterface, block.number);
    assert.equal(info.chainId, String(chainId));
    assert.equal(info.safeAddress.toLowerCase(), safe.toLowerCase(), 'Collected Safe differs from project config');
    assert.equal(info.accountAccesses.length, 0, 'Configuration getter unexpectedly collected actions');
    assert.equal(info.gasEstimates.length, 0, 'Configuration getter unexpectedly estimated actions');
    assert.equal(info.blockGasLimit, block.gasLimit.toString(), 'Collected block gas limit differs from pinned header');
    assert(!info.initialState.isExecuting, `An existing Sphinx root is active on ${network.folder}`);
    return { provider, chainId, profile, network, block, info,
        entry: { rpcUrl, networkConfig: makeNetworkConfig(info, true, {}, []) } };
}

async function collectAndQualify(scriptPath, scriptFunctionCalldata, safe, rpcUrls, pluginInterface,
    foundryToml, projectRoot, getConfigArtifacts, sphinxContext, targetContract, spinner) {
    assert.equal(path.resolve(projectRoot), ROOT, 'Run the airdrop proposal from the banny-retail-v6 directory');
    assert.equal(path.resolve(projectRoot, scriptPath), path.join(ROOT, 'script/AirdropV4Bannys.s.sol'),
        'Use script/AirdropV4Bannys.s.sol for the bounded airdrop proposal');
    assert.equal(scriptFunctionCalldata, RUN, 'The bounded airdrop proposal supports run() only');
    const items = generator.loadRawItems();
    const plans = generator.buildContractsByChain(items);
    const helperPlans = generator.buildCombinedContractsByChain(items);
    exporter.assertGeneratedSnapshot(plans, items);
    await ensureBuildInfo(getConfigArtifacts, helperPlans, projectRoot);
    const sourceHashes = new Map();
    const executorArtifact = exporter.readCompiledArtifact('SafeAirdropExecutor',
        'script/helpers/SafeAirdropExecutor.sol', ROOT, sourceHashes);
    const artifacts = new Map([['SafeAirdropExecutor', executorArtifact]]);
    fs.mkdirSync(path.join(ROOT, 'safe-airdrop'), { recursive: true });
    const reportDir = fs.mkdtempSync(path.join(ROOT, 'safe-airdrop', 'sphinx-'));
    const entries = [];
    const preparedChains = [];
    const preparedByChain = [];
    for (const rpcUrl of rpcUrls) {
        const { provider, chainId, profile, network, block, entry } = await collectNetworkContext({
            scriptPath, safe, rpcUrl, pluginInterface, targetContract, reportDir });
        assert(!entries.some(({ networkConfig }) => Number(networkConfig.chainId) === chainId), 'Duplicate chain');
        const helperPlan = helperPlans[network.sourceChainId][0];
        artifacts.set(helperPlan.contractName, exporter.readArtifact(helperPlan, ROOT, sourceHashes));
        let prepared;
        try {
            prepared = await exporter.prepareChain({ network, profile, safe, provider, plans, helperPlans,
                executorArtifact, sourceHashes });
        } catch (error) {
            throw new Error(`Cannot prepare ${network.folder}: ${safeError(error).message}. Check existing Safe permissions/configuration before proposing.`);
        }
        const selected = selectChunks(prepared.batches, plans[network.sourceChainId]);
        preparedByChain.push(selected.batches);
        preparedChains.push({ chainId, blockHash: block.hash, network, profile, safe, hook: prepared.chain.hook,
            authority: { owners: prepared.chain.owners, threshold: prepared.chain.threshold },
            resolver: prepared.chain.resolver, envelopes: selected.batches.map(batch => batch.safeTransaction),
            plans: selected.plans });
        entries.push(entry);
        spinner?.info(`Prepared ${network.folder} at block ${block.number}: ${selected.batches.length} atomic actions.`);
    }
    const initCodes = preparedByChain.flat().filter(batch => batch.safeTransaction.stage === 'setup')
        .flatMap(batch => batch.batch.transactions.map(tx => core.decodeDeterministicDeploymentProxyData(tx.data).initCodeWithArgs));
    const inputIdentity = sourceIdentity(items, artifacts, sourceHashes);
    const { configArtifacts, buildInfos } = await resolveCompilerArtifacts(getConfigArtifacts, initCodes, inputIdentity, () => {
        // Compiler collection can replace artifacts; reread every input rather than trusting cached identities.
        const freshItems = generator.loadRawItems();
        const freshHelpers = generator.buildCombinedContractsByChain(freshItems);
        const freshSources = new Map();
        const freshArtifacts = new Map([['SafeAirdropExecutor', exporter.readCompiledArtifact('SafeAirdropExecutor',
            'script/helpers/SafeAirdropExecutor.sol', ROOT, freshSources)]]);
        for (const chain of preparedChains) {
            const plan = freshHelpers[chain.network.sourceChainId][0];
            freshArtifacts.set(plan.contractName, exporter.readArtifact(plan, ROOT, freshSources));
        }
        return sourceIdentity(freshItems, freshArtifacts, freshSources);
    });
    for (let index = 0; index < entries.length; index++) {
        entries[index].networkConfig.actionInputs = preparedByChain[index].map((batch, actionIndex) =>
            actionFor(batch, actionIndex, configArtifacts));
    }
    await sphinxContext.assertNoLinkedLibraries(scriptPath, foundryToml.cachePath,
        foundryToml.artifactFolder, projectRoot, targetContract);
    const { qualifyProfile } = require('./qualify-sphinx-airdrop');
    fs.writeFileSync(path.join(reportDir, 'inputs.json'), `${JSON.stringify({ inputIdentity,
        rawItemsSha256: createHash('sha256').update(JSON.stringify(items)).digest('hex'),
        sources: Object.fromEntries(sourceHashes),
        artifacts: Object.fromEntries([...artifacts].map(([name, artifact]) =>
            [name, createHash('sha256').update(JSON.stringify(artifact)).digest('hex')])),
        chains: preparedChains.map((prepared, index) => ({ chainId: prepared.chainId,
            blockHash: prepared.blockHash, blockNumber: entries[index].networkConfig.blockNumber })),
    }, null, 2)}\n`);
    let qualification;
    try {
        qualification = await qualifyProfile(entries, preparedChains, reportDir);
    } catch (error) {
        throw new Error(`${safeError(error).message}; local evidence: ${reportDir}`);
    }
    assert(qualification.segments?.length, 'Qualification returned no proposal parts');
    return { ...qualification, entries, preparedChains, configArtifacts, buildInfos, reportDir, inputIdentity };
}

async function resolveCompilerArtifacts(getConfigArtifacts, initCodes, expectedIdentity, readIdentity, root = ROOT) {
    // Forge inspection/context collection can replace full compiler metadata; recover it after those operations.
    await ensureBuildInfo(getConfigArtifacts, {}, root, () => initCodes);
    assert.equal(readIdentity(), expectedIdentity, 'Compiler/source identity changed during metadata recovery');
    return getConfigArtifacts(initCodes);
}

function safeError(error) {
    // Never forward provider request/error objects, which frequently embed RPC credentials.
    const message = error?.code && !String(error.code).startsWith('ERR_ASSERTION')
        ? `Airdrop proposal failed (${error.code})` : String(error?.message || 'Airdrop proposal failed');
    return new Error(message.replace(/https?:\/\/[^\s'"<>]+/gi, '[redacted RPC URL]'));
}

const sha256 = data => createHash('sha256').update(data).digest('hex');
const serialize = value => JSON.stringify(value, null, 2);
const artifactFile = directory => path.join(directory, 'prepared.json');
const progressFile = directory => path.join(directory, 'proposal-progress.json');
const resumeCommand = directory => `node ./script/outfit_drop/propose-sphinx-airdrop.js resume '${directory.replace(/'/g, `'"'"'`)}'`;

function writePreparedArtifact(prepared, args, workflowTag) {
    assert.equal(prepared.report.status, 'passed', 'All parts must pass qualification before preparation is saved');
    assert(prepared.preparedChains?.length && prepared.inputIdentity, 'Missing frozen preparation inputs');
    const directory = prepared.reportDir;
    const filename = artifactFile(directory);
    assert(!fs.existsSync(filename), 'Preserve an existing prepared artifact; resume it instead');
    const artifact = JSON.parse(serialize({ version: 1, ...(workflowTag ? { workflow: workflowTag } : {}),
        proposalArgs: { scriptPath: args.scriptPath, networks: args.networks, targetContract: args.targetContract, sig: args.sig },
        filters: { BANNY_AIRDROP_CHUNK: process.env.BANNY_AIRDROP_CHUNK || '0',
            BANNY_AIRDROP_MAX_CHUNK: process.env.BANNY_AIRDROP_MAX_CHUNK || '0' },
        inputIdentity: prepared.inputIdentity,
        inputsSha256: sha256(fs.readFileSync(path.join(directory, 'inputs.json'))),
        qualificationSha256: sha256(fs.readFileSync(path.join(directory, 'qualification.json'))),
        preparedChains: prepared.preparedChains.map(({ plans, ...chain }) => ({ ...chain,
            planNames: plans.map(plan => plan.contractName) })),
        segments: prepared.segments, configArtifacts: prepared.configArtifacts, buildInfos: prepared.buildInfos,
    }));
    const content = serialize(artifact);
    fs.writeFileSync(filename, content);
    fs.writeFileSync(`${filename}.sha256`, `${sha256(content)}\n`);
    return artifact;
}

function readPreparedArtifact(directory) {
    const content = fs.readFileSync(artifactFile(directory), 'utf8');
    assert.equal(sha256(content), fs.readFileSync(`${artifactFile(directory)}.sha256`, 'utf8').trim(), 'Prepared artifact checksum changed');
    const artifact = JSON.parse(content);
    assert.equal(artifact.version, 1, 'Unsupported prepared artifact');
    assert.equal(sha256(fs.readFileSync(path.join(directory, 'inputs.json'))), artifact.inputsSha256, 'Prepared input evidence changed');
    const qualification = fs.readFileSync(path.join(directory, 'qualification.json'));
    assert.equal(sha256(qualification), artifact.qualificationSha256, 'Qualification evidence changed');
    const report = JSON.parse(qualification);
    assert.equal(report.status, 'passed', 'Prepared artifact lacks a passed qualification');
    const { actionDigest } = require('./qualify-sphinx-airdrop');
    assert.deepEqual(report.segments, artifact.segments.map((segment, index) => ({ index, root: segment.merkleTree.root,
        chains: segment.networkConfigs.map(config => ({ chainId: config.chainId, moduleNonce: config.nonce,
            actions: config.actionInputs.map(action => ({ digest: actionDigest(action), signedGas: action.gas })) })) })),
    'Prepared actions or gas differ from qualification');
    for (const segment of artifact.segments) {
        assert.deepEqual(JSON.parse(serialize(contracts.makeSphinxMerkleTree(core.makeDeploymentData(segment.networkConfigs)))),
            segment.merkleTree, 'Prepared actions or proofs differ from the signed root');
    }
    assertCanonicalActions(artifact);
    return artifact;
}

function assertActionsMatchEnvelopes(actions, envelopes) {
    const { actionDigest } = require('./qualify-sphinx-airdrop');
    assert.equal(actions.length, envelopes.length, 'Prepared action count differs from canonical envelopes');
    actions.forEach((action, index) => {
        const tx = envelopes[index].transaction;
        assert.equal(actionDigest(action), actionDigest({ to: tx.to, value: tx.value, txData: tx.data,
            operation: tx.operation, requireSuccess: true }), 'Prepared action differs from canonical atomic envelope');
    });
}

function assertCanonicalActions(artifact) {
    const chainIds = artifact.preparedChains.map(chain => String(chain.chainId));
    assert.equal(new Set(chainIds).size, chainIds.length, 'Duplicate prepared chain');
    for (const segment of artifact.segments) {
        const ids = segment.networkConfigs.map(config => config.chainId);
        assert.equal(new Set(ids).size, ids.length, 'Duplicate proposal chain');
        assert(ids.every(id => chainIds.includes(id)), 'Proposal includes an unprepared chain');
    }
    for (const chain of artifact.preparedChains) {
        assert.deepEqual(chain.network, exporter.networksFor(chain.profile, chain.chainId)[0], 'Prepared network mapping changed');
        const configs = artifact.segments.flatMap(segment => segment.networkConfigs).filter(config => config.chainId === String(chain.chainId));
        assert(configs.length, 'Prepared chain has no actions');
        for (const config of configs) {
            assert.equal(config.safeAddress.toLowerCase(), chain.safe.toLowerCase(), 'Prepared Safe identity changed');
            assert.equal(config.executorAddress.toLowerCase(), contracts.getPermissionlessRelayAddress().toLowerCase(), 'Prepared executor is not the Sphinx relay');
            assert.equal(config.arbitraryChain, false, 'Prepared root must bind its chain');
            assert.equal(config.executionMode, core.ExecutionMode.Platform, 'Prepared execution mode changed');
            config.actionInputs.forEach((action, index) => assert.equal(action.index, String(index + 1), 'Prepared action index changed'));
        }
        assertActionsMatchEnvelopes(configs.flatMap(config => config.actionInputs), chain.envelopes);
    }
}

async function assertProjectIdentity(artifact, readConfig = (scriptPath, targetContract) =>
    utils.getSphinxConfigFromScript(scriptPath,
        utils.readInterface(path.join(ROOT, 'out'), 'SphinxPluginTypes'), targetContract)) {
    assert.equal(path.resolve(ROOT, artifact.proposalArgs.scriptPath), path.join(ROOT, 'script/AirdropV4Bannys.s.sol'),
        'Prepared script is not the original airdrop script');
    const config = await readConfig(artifact.proposalArgs.scriptPath, artifact.proposalArgs.targetContract);
    for (const network of artifact.segments.flatMap(segment => segment.networkConfigs)) {
        assert.equal(network.safeAddress.toLowerCase(), config.safeAddress.toLowerCase(), 'Project Safe changed after qualification');
        assert.equal(network.moduleAddress.toLowerCase(), config.moduleAddress.toLowerCase(), 'Project module changed after qualification');
        assert.equal(network.newConfig.projectName, config.projectName, 'Project name changed after qualification');
    }
}

function providerFor(chain) {
    const rpcUrl = process.env[chain.network.rpc];
    assert(rpcUrl, `Missing ${chain.network.rpc}`);
    return new ethers.providers.JsonRpcProvider({ url: rpcUrl, timeout: 30000 });
}

async function readPartState(artifact, config, root) {
    const chain = artifact.preparedChains.find(chain => String(chain.chainId) === config.chainId);
    assert(chain, 'Prepared chain is missing');
    const provider = providerFor(chain);
    assert.equal(String((await provider.getNetwork()).chainId), config.chainId, 'RPC chain differs from prepared chain');
    const module = new ethers.Contract(config.moduleAddress, contracts.SphinxModuleABI, provider);
    const [state, nonce, activeRoot] = await Promise.all([module.merkleRootStates(root), module.merkleRootNonce(), module.activeMerkleRoot()]);
    return { status: Number(state.status), nonce: nonce.toString(), activeRoot };
}

async function nextReadyPart(artifact, progress, readState = readPartState) {
    const completed = [];
    for (const [part, segment] of artifact.segments.entries()) {
        const states = await Promise.all(segment.networkConfigs.map(config => readState(artifact, config, segment.merkleTree.root)));
        assert(!states.some(state => state.status === 3 || state.status === 4),
            `Part ${part + 1} was canceled or failed onchain. Stop and reconcile its completed actions before continuing`);
        if (states.every(state => state.status === 2)) { completed.push(part); continue; }
        assert(states.every(state => [0, 1, 2].includes(state.status)), 'Unknown Sphinx root state');
        const outcome = progress.parts[part]?.status;
        assert.notEqual(outcome, 'completed', `Part ${part + 1} is no longer completed onchain; stop and reconcile`);
        if (states.some(state => state.status !== 0) || ['submitted', 'submission-unknown'].includes(outcome)) {
            return { part, completed, status: 'pending', message: outcome === 'submission-unknown'
                ? `Part ${part + 1} has an uncertain submission. Check its exact root in Sphinx; no duplicate will be uploaded.`
                : `Part ${part + 1} is awaiting signatures or execution. Complete it on every participating chain, then resume.` };
        }
        states.forEach((state, index) => {
            assert.equal(state.nonce, segment.networkConfigs[index].nonce,
                `Module nonce changed on chain ${segment.networkConfigs[index].chainId}; stop and reconcile`);
            assert.equal(state.activeRoot, ethers.constants.HashZero, 'Another Sphinx root is active; finish it before continuing');
        });
        return { part, completed, status: 'ready' };
    }
    return { completed, status: 'complete' };
}

async function assertPreparedFresh(artifact, directory, part) {
    assertCanonicalActions(artifact);
    const report = JSON.parse(fs.readFileSync(path.join(directory, 'qualification.json')));
    for (const [file, hash] of Object.entries(report.sourceSha256)) {
        assert.equal(sha256(fs.readFileSync(path.join(ROOT, file))), hash, 'Qualified workflow source changed; stop and requalify');
    }
    const items = generator.loadRawItems();
    const plans = generator.buildContractsByChain(items);
    const helperPlans = generator.buildCombinedContractsByChain(items);
    exporter.assertGeneratedSnapshot(plans, items);
    const sourceHashes = new Map();
    const executorArtifact = exporter.readCompiledArtifact('SafeAirdropExecutor', 'script/helpers/SafeAirdropExecutor.sol', ROOT, sourceHashes);
    const artifacts = new Map([['SafeAirdropExecutor', executorArtifact]]);
    for (const chain of artifact.preparedChains) {
        const plan = helperPlans[chain.network.sourceChainId][0];
        artifacts.set(plan.contractName, exporter.readArtifact(plan, ROOT, sourceHashes));
    }
    assert.equal(sourceIdentity(items, artifacts, sourceHashes), artifact.inputIdentity,
        'Airdrop inputs or compiler artifacts changed after qualification; stop and requalify');
    for (const chain of artifact.preparedChains) {
        const completedActions = artifact.segments.slice(0, part).flatMap(segment => segment.networkConfigs)
            .filter(config => config.chainId === String(chain.chainId)).reduce((sum, config) => sum + config.actionInputs.length, 0);
        const remaining = chain.envelopes.slice(completedActions);
        if (!remaining.length) continue;
        const fresh = await exporter.prepareChain({ network: chain.network, profile: chain.profile, safe: chain.safe,
            provider: providerFor(chain), plans, helperPlans, executorArtifact, sourceHashes });
        const selected = selectChunks(fresh.batches, plans[chain.network.sourceChainId], artifact.filters).batches.map(batch => batch.safeTransaction);
        const key = envelope => `${envelope.stage}:${envelope.chunk}:${envelope.slice}`;
        const keys = new Set(remaining.map(key));
        // Any newly missing setup or an externally executed pending setup invalidates this exact sequence.
        assert.deepEqual(selected.filter(tx => tx.stage === 'setup').map(key), remaining.filter(tx => tx.stage === 'setup').map(key),
            `Pending setup changed on chain ${chain.chainId}; stop and requalify`);
        const executionFields = ({ order, ...envelope }) => envelope;
        assert.deepEqual(selected.filter(tx => keys.has(key(tx))).map(executionFields), remaining.map(executionFields),
            `Remaining atomic transactions changed on chain ${chain.chainId}; stop and requalify`);
        assertActionsMatchEnvelopes(artifact.segments.slice(part).flatMap(segment => segment.networkConfigs)
            .filter(config => config.chainId === String(chain.chainId)).flatMap(config => config.actionInputs),
        selected.filter(tx => keys.has(key(tx))));
        assert.deepEqual({ owners: fresh.chain.owners, threshold: fresh.chain.threshold }, chain.authority,
            `Safe authority changed on chain ${chain.chainId}; stop and requalify`);
    }
}

async function assertReadyToSubmit(artifact, directory, progress, part, assertFresh = assertPreparedFresh) {
    // Re-read durable evidence too: a review prompt can remain open while files or chain state change.
    assert.deepEqual(readPreparedArtifact(directory), artifact, 'Prepared artifact changed during review');
    await assertProjectIdentity(artifact);
    const ready = await nextReadyPart(artifact, progress);
    assert(ready.status === 'ready' && ready.part === part, ready.message || 'A different proposal part is ready; resume again');
    await assertFresh(artifact, directory, part);
}

function makeAirdropPropose(context, { officialPropose = propose, prepare = collectAndQualify,
    loaded, assertReady = assertReadyToSubmit, workflowTag, label = 'Airdrop', resumeCommand: command = resumeCommand } = {}) {
    return async args => {
        let artifact = loaded?.artifact;
        let directory = loaded?.directory;
        const outcomes = loaded ? loaded.progress.parts.map(({ status, deploymentConfigId }) => ({ status, deploymentConfigId })) : [];
        let part = loaded?.part || 0;
        let processed = 0;
        const progress = () => ({ parts: artifact.segments.map((segment, index) => ({
            part: index + 1, root: segment.merkleTree.root,
            chains: segment.networkConfigs.map(config => ({ chainId: config.chainId, nonce: config.nonce })),
            ...outcomes[index],
        })) });
        const save = () => {
            if (directory && artifact) fs.writeFileSync(progressFile(directory), `${serialize(progress())}\n`);
        };
        const scoped = { ...context,
            buildNetworkConfigArray: async (...collectionArgs) => {
                if (!artifact) {
                    const prepared = await prepare(...collectionArgs);
                    directory = prepared.reportDir;
                    artifact = writePreparedArtifact(prepared, args, workflowTag);
                    artifact.segments.forEach(() => outcomes.push({ status: 'not-submitted' }));
                    save();
                }
                const segment = artifact.segments[part];
                assert(segment?.networkConfigs.length, 'Missing qualified proposal part');
                for (const config of segment.networkConfigs) assert.equal(config.safeAddress.toLowerCase(),
                    collectionArgs[2].toLowerCase(), 'Project Safe changed after qualification');
                const merkleTree = contracts.makeSphinxMerkleTree(core.makeDeploymentData(segment.networkConfigs));
                assert.equal(merkleTree.root, segment.merkleTree.root, 'Qualified proposal root changed');
                return { isEmpty: false, configArtifacts: artifact.configArtifacts, buildInfos: artifact.buildInfos,
                    networkConfigArrayWithRpcUrls: segment.networkConfigs.map(networkConfig => ({ networkConfig,
                        rpcUrl: process.env[artifact.preparedChains.find(chain => String(chain.chainId) === networkConfig.chainId).network.rpc] })) };
            },
            storeDeploymentConfig: async (apiKey, orgId, data) => {
                assert(artifact, 'Qualification must finish before upload');
                const config = JSON.parse(data);
                assert.equal(config.merkleTree.root, artifact.segments[part].merkleTree.root, 'Upload root differs from qualification');
                assert.deepEqual(config.networkConfigs, artifact.segments[part].networkConfigs,
                    'Upload actions differ from qualification');
                await assertReady(artifact, directory, progress(), part);
                outcomes[part].status = 'uploading-config'; save();
                const id = await context.storeDeploymentConfig(apiKey, orgId, data);
                outcomes[part] = { status: 'config-stored', deploymentConfigId: id }; save();
                return id;
            },
            relayProposal: async request => {
                assert.equal(request.tree.root, artifact.segments[part].merkleTree.root, 'Proposal root differs from qualification');
                outcomes[part].status = 'submission-unknown'; save();
                await context.relayProposal(request);
                outcomes[part].status = 'submitted'; save();
            },
        };
        try {
            do {
                const result = await officialPropose({ ...args, sphinxContext: scoped });
                assert.equal(result.merkleTree?.root, artifact.segments[part].merkleTree.root, 'SDK returned a different root');
                // A preview must not erase a previous submission outcome.
                if (args.isDryRun && outcomes[part].status === 'not-submitted') outcomes[part].status = 'dry-run';
                save();
                if (!args.silent) console.log(`${label} part ${part + 1}/${artifact.segments.length}: ${result.merkleTree.root}`);
                part++;
                processed++;
            } while (args.isDryRun && !loaded && part < artifact.segments.length);
            if (!args.silent) console.log(`${args.isDryRun ? 'Prepared; nothing submitted.' : 'One part submitted. Wait for execution on every participating chain.'}\nResume: ${command(directory)}`);
            return { completed: processed, reportDir: directory, resumeCommand: command(directory) };
        } catch (error) {
            save();
            const failure = safeError(error);
            if (artifact && !args.isDryRun) failure.message +=
                `; ${outcomes.filter(outcome => outcome.status === 'submitted').length} part(s) were submitted. Review ${progressFile(directory)} before retrying; an unknown submission must be checked in Sphinx. No automatic retry was attempted.`;
            throw failure;
        }
    };
}

async function resumePrepared(context, directory, args = {}, { officialPropose = propose,
    readState = readPartState, assertReady = assertReadyToSubmit, assertFresh = assertPreparedFresh,
    assertProject = assertProjectIdentity, workflowTag, label = 'Airdrop', resumeCommand: command = resumeCommand } = {}) {
    directory = path.resolve(directory);
    const artifact = readPreparedArtifact(directory);
    assert.equal(artifact.workflow, workflowTag, 'Prepared workflow differs from this entrypoint');
    const progress = JSON.parse(fs.readFileSync(progressFile(directory), 'utf8'));
    assert.deepEqual(progress.parts.map(part => part.root), artifact.segments.map(segment => segment.merkleTree.root),
        'Progress ledger differs from prepared roots');
    const previousProject = process.env.BANNY_AIRDROP_SPHINX_PROJECT;
    process.env.BANNY_AIRDROP_SPHINX_PROJECT = artifact.segments[0].networkConfigs[0].newConfig.projectName;
    try {
        await assertProject(artifact);
        const ready = await nextReadyPart(artifact, progress, readState);
        for (const index of ready.completed) progress.parts[index].status = 'completed';
        fs.writeFileSync(progressFile(directory), `${serialize(progress)}\n`);
        if (ready.status !== 'ready') {
            const message = ready.message || 'Every prepared airdrop part completed onchain.';
            if (!args.silent) console.log(message);
            return { status: ready.status, message, reportDir: directory };
        }
        await assertFresh(artifact, directory, ready.part);
        return await makeAirdropPropose(context, { officialPropose, assertReady, workflowTag, label, resumeCommand: command,
            loaded: { artifact, progress, directory, part: ready.part } })({ ...artifact.proposalArgs, ...args });
    } finally {
        if (previousProject === undefined) delete process.env.BANNY_AIRDROP_SPHINX_PROJECT;
        else process.env.BANNY_AIRDROP_SPHINX_PROJECT = previousProject;
    }
}

if (require.main === module) {
    const context = makeSphinxContext();
    if (process.argv[2] === 'resume') {
        const { values, positionals } = parseArgs({ args: process.argv.slice(3), allowPositionals: true,
            options: { 'dry-run': { type: 'boolean' }, confirm: { type: 'boolean' } } });
        assert.equal(positionals.length, 1, 'Use resume PREPARED_DIRECTORY [--dry-run] [--confirm]');
        resumePrepared(context, positionals[0], { isDryRun: Boolean(values['dry-run']), confirm: Boolean(values.confirm) })
            .catch(error => { console.error(safeError(error).message); process.exitCode = 1; });
    } else {
        assert(['propose', '--help', '-h'].includes(process.argv[2]), 'Use propose script/AirdropV4Bannys.s.sol --networks <networks>');
        context.propose = makeAirdropPropose(context);
        makeCLI(process.argv.slice(2), context);
    }
}

module.exports = { NOOP, selectChunks, actionFor, deploymentsFor, pinReads, sourceIdentity, ensureBuildInfo,
    collectNetworkContext, collectAndQualify, makeAirdropPropose, safeError, writePreparedArtifact, readPreparedArtifact,
    nextReadyPart, assertPreparedFresh, assertReadyToSubmit, resumePrepared, assertCanonicalActions, assertActionsMatchEnvelopes,
    assertProjectIdentity, providerFor, progressFile, resumeCommand, resolveCompilerArtifacts };
