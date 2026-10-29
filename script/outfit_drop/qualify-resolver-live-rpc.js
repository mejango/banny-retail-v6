'use strict';

// Wire bridge only: separately pinned Rust clients own current sizing and exact-root proof.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { createHash } = require('node:crypto');
const { ethers } = require('ethers');
const { NETWORKS } = require('./export-safe-airdrop');
const ROOT = path.resolve(__dirname, '../..');
const CLIENT_REVISION = 'afcdc4e3eb1eeccea5d9c47977ec4ca381b4bbce';
const VERIFIER_REVISION = '9a31bf8fb9bc464243d3252c69fcdc1f6460fe3c';
const AUTHORIZATION_SCOPE = `current sizing ${CLIENT_REVISION} with existing local replay floor; exact-root verifier ${VERIFIER_REVISION}; synthetic approval only, no owner signatures or approval gas qualification`;
const BRIDGE = 'script/outfit_drop/live-rpc-bridge';
const SOURCE_FILES = ['script/outfit_drop/qualify-resolver-live-rpc.js',
    `${BRIDGE}/Cargo.toml`, `${BRIDGE}/Cargo.lock`, `${BRIDGE}/src/main.rs`, `${BRIDGE}/tests/sdk-wire.json`];
const MODULE = new ethers.utils.Interface(require('@sphinx-labs/contracts/contract-artifacts/sphinx/SphinxModule.sol/SphinxModule.json').abi);
const RELAY = new ethers.utils.Interface(['function exec(address,bytes)']);
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const quantity = value => `0x${BigInt(value).toString(16)}`;
const address = value => ethers.utils.getAddress(value).toLowerCase();
const LEAF_TYPES = ['Approve', 'Execute', 'Cancel'];
const OUTER_SEED_GRID = 1_000_000;

// Only sanitized bridge/boundary failures may cross the generic fork diagnostic
// guard. Provider and child-process errors never become this type directly.
class LiveQualificationError extends Error {}

class LiveGasClampError extends Error {
    constructor(hint) {
        for (const field of ['actionIndex', 'requestedOuterGas', 'effectiveOuterGas']) {
            assert(Number.isSafeInteger(hint[field]) && hint[field] > 0, 'Invalid numeric gas-clamp hint');
        }
        assert(Number.isSafeInteger(hint.precedingActions) && hint.precedingActions >= 0, 'Invalid preceding action count');
        super(`Live RPC bridge rejected changed outer gas at action ${hint.actionIndex} with ${hint.precedingActions} preceding actions: requested ${hint.requestedOuterGas}, effective ${hint.effectiveOuterGas}; no clamped response accepted`);
        this.hint = Object.freeze(Object.fromEntries(['actionIndex', 'precedingActions', 'requestedOuterGas', 'effectiveOuterGas']
            .map(field => [field, hint[field]])));
    }
}

function binaryFailure(code, stderr) {
    // Only fixed categories and numeric hints may cross the child-process boundary.
    const action = stderr.match(/action (\d+) with (\d+) preceding actions/);
    const rpc = stderr.match(/RPC code (?:Some\()?(-?\d+)\)?, category (state|header|revert|gas|other)/);
    const exhausted = stderr.includes('no successful gas pair within');
    const clamped = stderr.match(/changed outer gas: requested (\d+), effective (\d+)/);
    const clampContext = stderr.match(/action (\d+) with (\d+) preceding actions changed outer gas: requested (\d+), effective (\d+)/);
    if (clampContext) {
        try {
            return new LiveGasClampError({ actionIndex: Number(clampContext[1]), precedingActions: Number(clampContext[2]),
                requestedOuterGas: Number(clampContext[3]), effectiveOuterGas: Number(clampContext[4]) });
        } catch { /* Invalid or unsafe quantities remain an ordinary non-retryable failure. */ }
    }
    return new Error(`Live RPC bridge failed (exit ${code ?? 'terminated'})`
        + (action ? `; action ${action[1]} with ${action[2]} preceding actions` : '')
        + (rpc ? `; RPC code ${rpc[1]}, category ${rpc[2]}` : '')
        + (exhausted ? '; bounded live gas search found no successful pair' : '')
        + (clamped ? `; RPC changed requested outer gas ${clamped[1]} to ${clamped[2]}; increase the provider transaction and aggregate simulation allowance` : '')
        + '; no Anvil fallback or proposal submission');
}


function rustConfig(config, chain) {
    assert.equal(config.arbitraryChain, false, 'Live leaves must bind their chain');
    assert(config.actionInputs.length > 0, 'Live qualification requires canonical actions');
    assert(Number.isSafeInteger(chain?.blockTimestamp) && chain.blockTimestamp > 0, 'Live budget needs the pinned timestamp');
    const limits = require('./simulate-safe-airdrop').gasBudget(config.chainId,
        config.observedBlockGasLimit || config.blockGasLimit, { liveRpc: true, blockTimestamp: chain.blockTimestamp });
    const c = config.newConfig;
    return {
        safe_address: address(config.safeAddress), module_address: address(config.moduleAddress),
        executor_address: address(config.executorAddress), safe_init_data: config.safeInitData,
        nonce: quantity(config.nonce), chain_id: quantity(config.chainId),
        // Rust receives the reviewed physical outer cap. SDK batching metadata
        // remains on the original config and is not a transaction gas budget.
        block_gas_limit: quantity(limits.outerGasCap), block_number: quantity(config.blockNumber),
        new_config: { project_name: c.projectName, org_id: c.orgId, owners: c.owners.map(address),
            threshold: quantity(c.threshold), salt_nonce: quantity(c.saltNonce), mainnets: c.mainnets, testnets: c.testnets },
        initial_state: { is_safe_deployed: config.initialState.isSafeDeployed,
            is_module_deployed: config.initialState.isModuleDeployed, is_executing: config.initialState.isExecuting },
        is_system_deployed: config.isSystemDeployed, arbitrary_chain: false, libraries: config.libraries,
        git_commit: config.gitCommit ?? null,
        action_inputs: config.actionInputs.map((action, index) => {
            assert.equal(String(action.index), String(index + 1), 'Live action order changed');
            assert([0, 1].includes(action.operation), 'Live action must preserve its canonical Call or DelegateCall');
            assert.equal(BigInt(action.value), 0n, 'Live action must not send ETH');
            assert.equal(action.requireSuccess, true, 'Live action must require success');
            return { index: index + 1, to: address(action.to), value: quantity(action.value), gas: quantity(action.gas),
                tx_data: action.txData, operation: action.operation === 0 ? 'Call' : 'DelegateCall', require_success: true,
                action_type: 'Call', deployed_address: null, init_code: null };
        }),
    };
}

function rustTree(tree) {
    return { root: tree.root, leaves_with_proofs: tree.leavesWithProofs.map(({ leaf, proof }) => {
        assert([0, 1].includes(Number(leaf.leafType)), 'Live tree contains an unsupported leaf');
        return { leaf: { chain_id: quantity(leaf.chainId), index: quantity(leaf.index),
            leaf_type: LEAF_TYPES[Number(leaf.leafType)], data: leaf.data }, proof };
    }) };
}

function normalizedRust(config) {
    const copy = structuredClone(config);
    for (const key of ['nonce', 'chain_id', 'block_gas_limit', 'block_number']) copy[key] = quantity(copy[key]);
    for (const key of ['safe_address', 'module_address', 'executor_address']) copy[key] = address(copy[key]);
    copy.new_config.owners = copy.new_config.owners.map(address);
    for (const key of ['threshold', 'salt_nonce']) copy.new_config[key] = quantity(copy.new_config[key]);
    for (const action of copy.action_inputs) {
        action.to = address(action.to); action.value = quantity(action.value); action.gas = quantity(action.gas);
    }
    return copy;
}

function validateResult(result, config, chain, mode, tree) {
    const wire = rustConfig(config, chain), returned = normalizedRust(result.config);
    const proposed = { ...config, actionInputs: config.actionInputs.map((action, index) =>
        ({ ...action, gas: BigInt(returned.action_inputs[index]?.gas).toString() })) };
    assert.deepEqual(returned, rustConfig(proposed, chain), 'Live bridge changed fields other than signed gas');
    if (mode === 'final') assert.deepEqual(rustConfig(proposed, chain), wire, 'Final live proof changed frozen signed gas');
    const report = result.report;
    assert.equal(report.authorization_scope, AUTHORIZATION_SCOPE, 'Live report sizing or verifier provenance changed');
    assert.equal(report.chain_id, String(config.chainId), 'Live report chain changed');
    assert.equal(report.block_number, Number(config.blockNumber), 'Live report pin changed');
    assert.equal(report.block_hash.toLowerCase(), chain.blockHash.toLowerCase(), 'Live report header hash changed');
    for (const [field, expected] of [['safe', config.safeAddress], ['module', config.moduleAddress], ['executor', config.executorAddress]]) {
        assert.equal(address(report[field]), address(expected), `Live report ${field} changed`);
    }
    assert(Number.isSafeInteger(report.base_timestamp) && report.base_timestamp > 0, 'Invalid live schedule');
    assert.equal(report.base_timestamp, chain.blockTimestamp, 'Live base timestamp changed');
    assert.equal(report.simulated_block_interval_seconds, 1, 'Live schedule changed');
    assert(report.execution_shape.startsWith('one execution leaf per transaction;'), 'Unsupported live execution shape');
    assert.equal(report.actions.length, config.actionInputs.length, 'Live report action count changed');
    const limits = require('./simulate-safe-airdrop').gasBudget(config.chainId,
        config.observedBlockGasLimit || config.blockGasLimit, { liveRpc: true, blockTimestamp: chain.blockTimestamp });
    report.actions.forEach((action, index) => {
        assert.equal(action.index, index + 1, 'Live report indices changed');
        for (const key of ['signed_inner_gas', 'outer_gas']) assert(Number.isSafeInteger(action[key]) && action[key] > 0,
            `Invalid live ${key}`);
        assert.equal(String(action.signed_inner_gas), proposed.actionInputs[index].gas, 'Live signed gas differs from report');
        assert(action.signed_inner_gas <= limits.budget, `Live action ${index + 1} exceeds reviewed execution budget ${limits.budget}`);
        assert(action.outer_gas <= limits.outerGasCap, `Live action ${index + 1} exceeds observed total gas ceiling ${limits.outerGasCap}`);
        if (mode === 'final') {
            const leaf = tree.leavesWithProofs.find(entry => String(entry.leaf.chainId) === String(config.chainId)
                && Number(entry.leaf.index) === index + 1 && Number(entry.leaf.leafType) === 1);
            assert(leaf, 'Live proof lacks its exact execution leaf');
            const calldata = RELAY.encodeFunctionData('exec', [config.moduleAddress,
                MODULE.encodeFunctionData('execute', [[leaf]])]);
            assert.equal(action.calldata_hash.toLowerCase(), ethers.utils.keccak256(calldata), 'Live execution calldata hash changed');
            assert(Number.isSafeInteger(action.final_proof_attempts) && action.final_proof_attempts > 0, 'Missing final live proof');
        }
    });
    assert.equal(report.final_merkle_root?.toLowerCase() ?? null, mode === 'final' ? tree.root.toLowerCase() : null,
        'Live report final root changed');
    return proposed;
}

async function callBinary(binary, args, input) {
    return new Promise((resolve, reject) => {
        const child = spawn(binary, args, { cwd: ROOT, env: process.env, stdio: ['pipe', 'pipe', 'pipe'] });
        let stdout = '', stderr = '';
        const timer = setTimeout(() => child.kill('SIGTERM'), 15 * 60 * 1000);
        child.on('error', error => { clearTimeout(timer); reject(new Error(`Live bridge could not start (${error.code || 'spawn'}); run npm run build:sphinx:live`)); });
        child.stdout.on('data', data => { stdout += data; if (stdout.length > 20_000_000) child.kill('SIGTERM'); });
        child.stderr.on('data', data => { stderr = (stderr + data).slice(-4000); });
        child.on('close', code => {
            clearTimeout(timer);
            if (code !== 0) {
                reject(binaryFailure(code, stderr));
            } else {
                try { resolve(JSON.parse(stdout)); } catch { reject(new Error('Live bridge returned invalid JSON')); }
            }
        });
        child.stdin.on('error', () => {});
        child.stdin.end(input);
    });
}

function assertCompiledVersion(version, sourceSha256) {
    const compiledSourceSha256 = Object.fromEntries(['Cargo.toml', 'Cargo.lock', 'src/main.rs'].map(file =>
        [file, sourceSha256[`${BRIDGE}/${file}`]]));
    assert(Object.values(compiledSourceSha256).every(hash => /^[a-f\d]{64}$/.test(hash)),
        'Live bridge source hashes missing');
    assert.deepEqual(version, { schemaVersion: 1, clientRevision: CLIENT_REVISION, verifierRevision: VERIFIER_REVISION, bridgeVersion: '0.1.0',
        compiledSourceSha256 }, 'Live bridge version or compiled source changed; run npm run build:sphinx:live');
}

async function provenance({ run = callBinary, readBinarySha256 = binary => {
    assert(fs.existsSync(binary), 'Build the pinned live qualifier first: npm run build:sphinx:live');
    return digest(fs.readFileSync(binary));
} } = {}) {
    const binary = path.join(ROOT, BRIDGE, 'target/debug/banny-resolver-live-rpc-bridge');
    const binarySha256 = readBinarySha256(binary);
    const version = await run(binary, ['--version']);
    const sourceSha256 = Object.fromEntries(SOURCE_FILES.map(file => [file, digest(fs.readFileSync(path.join(ROOT, file)))]));
    assertCompiledVersion(version, sourceSha256);
    assert(fs.readFileSync(path.join(ROOT, BRIDGE, 'Cargo.lock'), 'utf8').includes(`#${CLIENT_REVISION}`), 'Live client dependency pin changed');
    assert(fs.readFileSync(path.join(ROOT, BRIDGE, 'Cargo.lock'), 'utf8').includes(`#${VERIFIER_REVISION}`), 'Live verifier dependency pin changed');
    assert.equal(readBinarySha256(binary), binarySha256, 'Live bridge binary changed while checking version provenance');
    return { binary, binarySha256, schemaVersion: 1, clientRevision: CLIENT_REVISION, verifierRevision: VERIFIER_REVISION, sourceSha256 };
}

function evidenceFile(directory, label, data) {
    const content = `${JSON.stringify(data, null, 2)}\n`, sha256 = digest(content);
    const filename = `${label}-${sha256}.json`;
    fs.writeFileSync(path.join(directory, filename), content, { flag: 'wx', mode: 0o444 });
    return { filename, sha256 };
}

function nextOuterSeed(error, request, config, chain, seenHints) {
    if (!(error instanceof LiveGasClampError)) return null;
    const hint = new LiveGasClampError(error.hint).hint;
    const index = hint.actionIndex - 1;
    const action = request.networks[0].report?.actions?.[index];
    const currentSeed = action?.outer_gas;
    const physicalCap = BigInt(rustConfig(config, chain).block_gas_limit);
    const key = JSON.stringify(hint);
    if (index >= config.actionInputs.length || hint.precedingActions !== index || action?.index !== hint.actionIndex
        || request.networks[0].report.actions.length !== config.actionInputs.length
        || String(action.signed_inner_gas) !== config.actionInputs[index].gas
        || !Number.isSafeInteger(currentSeed) || currentSeed <= 0
        || !(currentSeed < hint.effectiveOuterGas && hint.effectiveOuterGas < hint.requestedOuterGas)
        || BigInt(hint.effectiveOuterGas) <= BigInt(config.actionInputs[index].gas)
        || BigInt(hint.effectiveOuterGas) > physicalCap || BigInt(hint.requestedOuterGas) > physicalCap
        || seenHints.has(key)) return null;
    seenHints.add(key);
    // Leave aggregate allowance headroom when a coarser seed still progresses.
    // If that seed fails, a later clamp can still select the exact available gas.
    const rounded = Math.floor(hint.effectiveOuterGas / OUTER_SEED_GRID) * OUTER_SEED_GRID;
    const outerGas = rounded > currentSeed && BigInt(rounded) > BigInt(config.actionInputs[index].gas)
        ? rounded : hint.effectiveOuterGas;
    return { index, outerGas };
}

async function qualify(mode, configs, chains, directory, { reports, tree, run = callBinary, identity,
    allowOuterSeedRetry = false, readBinarySha256 = filename => digest(fs.readFileSync(filename)) } = {}) {
    assert.equal(typeof allowOuterSeedRetry, 'boolean', 'Outer seed retry must be explicitly enabled');
    identity ||= await provenance();
    const results = [], files = [];
    for (const [index, config] of configs.entries()) {
        const chain = chains.find(c => String(c.chainId) === String(config.chainId));
        assert(chain, 'Missing live preparation chain');
        assert.deepEqual(chain.network, Object.values(NETWORKS).flat().find(n => String(n.chainId) === String(config.chainId)), 'Live RPC mapping changed');
        const request = { schemaVersion: 1, clientRevision: CLIENT_REVISION, verifierRevision: VERIFIER_REVISION, mode,
            networks: [{ rpcEnv: chain.network.rpc, expectedBlockHash: chain.blockHash, expectedBlockTimestamp: chain.blockTimestamp, config: rustConfig(config, chain),
                ...(reports ? { report: structuredClone(reports[index]) } : {}) }], ...(tree ? { tree: rustTree(tree) } : {}) };
        const rejectedAttempts = [], seenHints = new Set();
        while (true) {
            const requestFile = evidenceFile(directory, `live-rpc-${mode}-request-${config.chainId}`, request);
            try {
                assert.equal(readBinarySha256(identity.binary), identity.binarySha256, 'Live qualifier binary changed before execution');
                const response = await run(identity.binary, [], JSON.stringify(request));
                assert.equal(readBinarySha256(identity.binary), identity.binarySha256, 'Live qualifier binary changed during execution');
                assert.equal(response.schemaVersion, 1, 'Live response schema changed');
                assert.equal(response.clientRevision, CLIENT_REVISION, 'Live client revision changed');
                assert.equal(response.verifierRevision, VERIFIER_REVISION, 'Live verifier revision changed');
                assert.equal(response.results.length, 1, 'Live response chain count changed');
                const updated = validateResult(response.results[0], config, chain, mode, tree);
                const evidence = evidenceFile(directory, `live-rpc-${mode}-${config.chainId}`,
                    { status: mode === 'final' ? 'passed' : 'estimated', request: requestFile, identity, response,
                        ...(rejectedAttempts.length ? { rejectedAttempts } : {}) });
                files.push(evidence); results.push({ config: updated, report: response.results[0].report });
                break;
            } catch (error) {
                const message = require('./propose-sphinx-airdrop').safeError(error).message;
                const failure = evidenceFile(directory, `live-rpc-${mode}-failed-${config.chainId}`,
                    { status: 'failed', request: requestFile, identity, error: message,
                        ...(error instanceof LiveGasClampError ? { gasClamp: error.hint } : {}),
                        ...(rejectedAttempts.length ? { rejectedAttempts: [...rejectedAttempts] } : {}) });
                const retry = mode === 'final' && allowOuterSeedRetry && rejectedAttempts.length < 3
                    ? nextOuterSeed(error, request, config, chain, seenHints) : null;
                if (!retry) throw new LiveQualificationError(`Live qualification failed on chain ${config.chainId}: ${message}. Evidence: ${path.join(directory, failure.filename)}`);
                rejectedAttempts.push(failure);
                // A provider hint is only a new seed. Reissue the unchanged complete
                // canonical proof; the rejected/clamped response proves nothing.
                request.networks[0].report.actions[retry.index].outer_gas = retry.outerGas;
            }
        }
    }
    return { configs: results.map(result => result.config), reports: results.map(result => result.report), files, identity };
}

function readEvidence(directory, file) {
    assert.equal(path.basename(file.filename), file.filename, 'Live evidence path escaped preparation');
    const bytes = fs.readFileSync(path.join(directory, file.filename));
    assert.equal(digest(bytes), file.sha256, 'Live evidence checksum changed');
    return JSON.parse(bytes);
}

function assertChainEvidence(config, chain, tree, identity, directory, file) {
    const evidence = readEvidence(directory, file);
    assert.equal(evidence.status, 'passed', 'Unfinished live proof');
    assert.deepEqual(evidence.identity, identity, 'Live evidence binary identity changed');
    const request = readEvidence(directory, evidence.request);
    assert.deepEqual(request, { schemaVersion: 1, clientRevision: CLIENT_REVISION, verifierRevision: VERIFIER_REVISION, mode: 'final',
        networks: [{ rpcEnv: chain.network.rpc, expectedBlockHash: chain.blockHash, expectedBlockTimestamp: chain.blockTimestamp,
            config: rustConfig(config, chain), report: request.networks[0].report }], tree: rustTree(tree) },
    'Live proof request differs from its canonical preparation');
    validateResult(evidence.response.results[0], config, chain, 'final', tree);
    return evidence.response.results[0].report;
}

async function assertEvidence(artifact, directory, { readProvenance = provenance } = {}) {
    const bytes = fs.readFileSync(path.join(directory, 'qualification.json'));
    assert.equal(digest(bytes), artifact.qualificationSha256, 'Live qualification checksum changed');
    const qualification = JSON.parse(bytes);
    assert.equal(qualification.status, 'passed', 'Unfinished live qualification');
    assert.equal(qualification.gasEstimator, 'live-rpc', 'Workflow requires live RPC gas qualification');
    assert.equal(artifact.segments.length, 1, 'Live workflow requires one proposal');
    const { liveRpc } = qualification;
    assert(liveRpc?.final?.files?.length, 'Missing exact-root live proof');
    assert.deepEqual(await readProvenance(), liveRpc.identity, 'Live qualifier source or binary changed; requalify');
    const segment = artifact.segments[0];
    assert.equal(liveRpc.final.files.length, segment.networkConfigs.length, 'Missing live chain proofs');
    const reports = liveRpc.final.files.map((file, index) => {
        const config = segment.networkConfigs[index];
        const chain = artifact.preparedChains.find(c => String(c.chainId) === String(config.chainId));
        return assertChainEvidence(config, chain, segment.merkleTree, liveRpc.identity, directory, file);
    });
    return { qualification, reports };
}

async function replay(artifact, directory, { verifyEvidence = assertEvidence,
    createProvider = url => new ethers.providers.JsonRpcProvider({ url, timeout: 30000 }),
    runQualify = qualify } = {}) {
    const { qualification, reports } = await verifyEvidence(artifact, directory);
    const identity = qualification.liveRpc.identity;
    const replayDirectory = fs.mkdtempSync(path.join(directory, 'live-rpc-replay-'));
    const summaryFile = path.join(replayDirectory, 'replay.json');
    const summary = { status: 'running', root: artifact.segments[0].merkleTree.root };
    const save = () => fs.writeFileSync(summaryFile, `${JSON.stringify(summary, null, 2)}\n`);
    save();
    try {
        const configs = [], chains = [], freshReports = [];
        for (const [index, frozen] of artifact.segments[0].networkConfigs.entries()) {
            const chain = artifact.preparedChains.find(c => String(c.chainId) === String(frozen.chainId));
            const provider = createProvider(process.env[chain.network.rpc]);
            assert.equal(String((await provider.getNetwork()).chainId), String(frozen.chainId), 'Live replay RPC chain changed');
            const block = await require('./propose-sphinx-airdrop').readFinalizedBlock(provider, frozen.chainId);
            configs.push({ ...frozen, blockNumber: String(block.number), observedBlockGasLimit: block.gasLimit.toString() });
            chains.push({ ...chain, blockHash: block.hash, blockTimestamp: block.timestamp });
            freshReports.push({ ...reports[index], block_number: block.number, block_hash: block.hash,
                base_timestamp: block.timestamp, final_merkle_root: null });
        }
        const result = await runQualify('final', configs, chains, replayDirectory,
            { reports: freshReports, tree: artifact.segments[0].merkleTree, identity, allowOuterSeedRetry: false });
        assert.deepEqual(result.identity, identity, 'Live replay qualifier identity differs from qualification');
        assert.deepEqual(result.reports.map(report => report.actions.map(action => action.outer_gas)),
            reports.map(report => report.actions.map(action => action.outer_gas)),
            'Live replay changed exact outer budgets; prepare and review a new executor handoff');
        summary.status = 'passed'; summary.files = result.files; save();
        return result;
    } catch (error) {
        summary.status = 'failed';
        summary.error = require('./propose-sphinx-airdrop').safeError(error).message;
        save();
        throw new LiveQualificationError(`${summary.error}. Replay evidence: ${summaryFile}`);
    }
}

function handoffTemplate(artifact, directory, reports) {
    return { schemaVersion: 1, root: artifact.segments[0].merkleTree.root,
        qualificationSha256: artifact.qualificationSha256, acknowledged: false,
        executionShape: 'one execution leaf per transaction',
        approvalGasQualified: false,
        networks: reports.map(report => ({ chainId: report.chain_id, safe: report.safe, module: report.module,
            executor: report.executor, actions: report.actions.map(action => ({ index: action.index,
                signedInnerGas: action.signed_inner_gas, outerGas: action.outer_gas, calldataHash: action.calldata_hash })) })),
        acknowledgement: 'The executor has received this exact root-bound report and must apply its exact outer gas limits and singleton shape. Queuing does not qualify owner signatures, approval gas, relay funding or hosted execution.' };
}

async function assertHandoff(artifact, directory, dependencies) {
    const { reports } = await assertEvidence(artifact, directory, dependencies);
    const filename = path.resolve(process.env.BANNY_SPHINX_EXECUTOR_HANDOFF_FILE || path.join(directory, 'executor-handoff.json'));
    assert(fs.existsSync(filename), `Executor handoff acknowledgement required: ${filename}`);
    const actual = JSON.parse(fs.readFileSync(filename));
    const expected = handoffTemplate(artifact, directory, reports);
    assert.equal(actual.acknowledged, true, 'Live report must be handed to the executor before proposal submission; exact outer limits and singleton execution are required');
    assert.deepEqual({ ...actual, acknowledged: false }, expected, 'Executor handoff does not bind the exact qualified root and budgets');
    return { filename, sha256: digest(fs.readFileSync(filename)) };
}

module.exports = { LiveGasClampError, binaryFailure, CLIENT_REVISION, VERIFIER_REVISION, AUTHORIZATION_SCOPE, SOURCE_FILES, LiveQualificationError, rustConfig, rustTree, validateResult, assertCompiledVersion, provenance,
    qualify, readEvidence, assertChainEvidence, assertEvidence, replay, handoffTemplate, assertHandoff };
