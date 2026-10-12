const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { test } = require('node:test');
const { ethers } = require('ethers');
const core = require('@sphinx-labs/core');
const { makeSphinxMerkleTree, SphinxLeafType, getPermissionlessRelayAddress } = require('@sphinx-labs/contracts');
const { NOOP, actionFor, selectChunks, pinReads, sourceIdentity, ensureBuildInfo, makeAirdropPropose, safeError,
    readPreparedArtifact, nextReadyPart, resumePrepared, writePreparedArtifact, assertProjectIdentity } = require('./propose-sphinx-airdrop');
const { FACTORY, MULTISEND, networksFor } = require('./export-safe-airdrop');
const { actionDigest } = require('./qualify-sphinx-airdrop');

const SAFE = '0x0000000000000000000000000000000000000001';
const MODULE = '0x0000000000000000000000000000000000000002';
const RELAY = getPermissionlessRelayAddress();
const INIT = '0x60006000f3';
const SALT = ethers.constants.HashZero;
const DEPLOYED = ethers.utils.getCreate2Address(FACTORY, SALT, ethers.utils.keccak256(INIT));
const configArtifacts = { 'Helper.sol:Helper': { buildInfoId: 'build', artifact: {
    contractName: 'Helper', sourceName: 'Helper.sol', abi: [], bytecode: INIT, linkReferences: {},
    metadata: { sources: { 'Helper.sol': {} } },
} } };
const buildInfos = { build: { id: 'build', solcVersion: '0.8.28', solcLongVersion: '0.8.28',
    input: { language: 'Solidity', sources: { 'Helper.sol': { content: 'contract Helper {}' } }, settings: {} } } };

function batch(stage, chunk = 1) {
    return { batch: { transactions: stage === 'setup' ? [{ to: FACTORY, data: SALT + INIT.slice(2), value: '0' }] : [] },
        safeTransaction: { stage, chunk, slice: 1, helper: DEPLOYED, implementation: DEPLOYED,
            expectedTokenIds: stage === 'migration' ? [1000000001] : [],
            transaction: { to: stage === 'setup' ? FACTORY : MULTISEND, value: '0',
                data: stage === 'setup' ? SALT + INIT.slice(2) : '0x12345678', operation: stage === 'setup' ? 0 : 1 } } };
}

function config(nonce = '2') {
    return { safeAddress: SAFE, moduleAddress: MODULE, executorAddress: RELAY, nonce, chainId: '42161',
        safeInitData: '0x', blockGasLimit: '32000000', blockNumber: '100', arbitraryChain: false,
        initialState: { isSafeDeployed: true, isModuleDeployed: true, isExecuting: false },
        newConfig: { projectName: 'banny-core', orgId: 'org', owners: [SAFE], mainnets: ['arbitrum'],
            testnets: [], threshold: '1', saltNonce: '0' }, executionMode: core.ExecutionMode.Platform, isSystemDeployed: true,
        libraries: [], unlabeledContracts: [], gitCommit: null,
        actionInputs: [actionFor(batch('setup'), 0, configArtifacts), actionFor(batch('migration'), 1, configArtifacts)]
            .map(action => ({ ...action, gas: '3000000' })) };
}

test('official payload preserves atomic delegatecall, signed gas, nonce and compiler metadata', () => {
    assert.equal(NOOP, '0x88288a38');
    const network = config();
    assert.deepEqual(network.actionInputs[0].contracts, [{ address: DEPLOYED, initCodeWithArgs: INIT,
        fullyQualifiedName: 'Helper.sol:Helper' }]);
    const tree = makeSphinxMerkleTree(core.makeDeploymentData([network]));
    const leaf = tree.leavesWithProofs.find(entry => entry.leaf.leafType === SphinxLeafType.EXECUTE && entry.leaf.index === 2n);
    const decoded = ethers.utils.defaultAbiCoder.decode(['address', 'uint256', 'uint256', 'bytes', 'uint256', 'bool'], leaf.leaf.data);
    assert.equal(decoded[0], MULTISEND);
    assert.equal(decoded[2].toString(), '3000000');
    assert.equal(decoded[3], batch('migration').safeTransaction.transaction.data);
    assert.equal(decoded[4].toNumber(), 1);
    assert.equal(decoded[5], true);
    const payload = core.makeDeploymentConfig([network], configArtifacts, buildInfos, tree);
    assert.equal(payload.inputs.length, 1);
    assert.deepEqual(payload.inputs[0].input.sources, buildInfos.build.input.sources);
    const serialized = JSON.parse(JSON.stringify(payload));
    assert.deepEqual(serialized.networkConfigs, [network]);
    assert.notEqual(makeSphinxMerkleTree(core.makeDeploymentData([config('3')])).root, tree.root);
    assert.throws(() => actionFor(batch('setup'), 0, {}), /missing its compiler artifact/);
});

test('chunk filters preserve setup, exact/max semantics and reject invalid selections', () => {
    const batches = [batch('setup'), batch('migration', 1), batch('migration', 2)];
    const plans = [{ chunk: 1 }, { chunk: 2 }];
    assert.deepEqual(selectChunks(batches, plans, {}).batches, batches);
    assert.deepEqual(selectChunks(batches, plans, { BANNY_AIRDROP_CHUNK: '2' }),
        { batches: [batches[0], batches[2]], plans: [plans[1]] });
    assert.equal(selectChunks(batches, plans, { BANNY_AIRDROP_MAX_CHUNK: '1' }).batches.length, 2);
    for (const value of ['-1', '1.5', '3', 'NaN', '9007199254740993']) {
        assert.throws(() => selectChunks(batches, plans, { BANNY_AIRDROP_CHUNK: value }), /Invalid/);
    }
    assert.throws(() => selectChunks(batches, plans, { BANNY_AIRDROP_CHUNK: '1', BANNY_AIRDROP_MAX_CHUNK: '1' }), /Choose exact/);
});

test('preflight contract reads stay at the selected block', async () => {
    const calls = [];
    const provider = pinReads({ perform: async (method, params) => calls.push({ method, params }) }, 100);
    for (const method of ['call', 'getCode', 'getBalance', 'getStorageAt']) await provider.perform(method, { blockTag: 'latest' });
    await provider.perform('getBlockNumber', {});
    assert(calls.slice(0, 4).every(call => call.params.blockTag === '0x64'));
    assert.deepEqual(calls[4].params, {});
});

test('source identity binds raw recipients, imports and exact rebuilt compiler artifacts', () => {
    const items = [{ owner: SAFE, tokenId: 1 }];
    const artifacts = new Map([['Helper', { bytecode: INIT, compiler: '0.8.28', settings: { optimizer: true } }]]);
    const sources = new Map([['Helper.sol', 'hash1'], ['Imported.sol', 'hash2']]);
    const identity = sourceIdentity(items, artifacts, sources);
    assert.equal(sourceIdentity(items, artifacts, new Map([...sources].reverse())), identity);
    assert.notEqual(sourceIdentity([{ ...items[0], owner: MODULE }], artifacts, sources), identity);
    assert.notEqual(sourceIdentity(items, new Map([['Helper', { ...artifacts.get('Helper'), bytecode: INIT + '00' }]]), sources), identity);
    assert.notEqual(sourceIdentity(items, new Map([['Helper', { ...artifacts.get('Helper'), compiler: '0.8.29' }]]), sources), identity);
    assert.notEqual(sourceIdentity(items, artifacts, new Map([['Helper.sol', 'hash1'], ['Imported.sol', 'changed']])), identity);
});

test('real ordinary Forge build gains official Sphinx metadata without deleting prior cache evidence', async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-sphinx-metadata-'));
    try {
        const source = path.join(directory, 'script/helpers/SafeAirdropExecutor.sol');
        fs.mkdirSync(path.dirname(source), { recursive: true });
        fs.copyFileSync(path.join(__dirname, '../helpers/SafeAirdropExecutor.sol'), source);
        fs.writeFileSync(path.join(directory, 'foundry.toml'), '[profile.default]\nsolc = "0.8.28"\nbytecode_hash = "none"\n');
        const built = await core.spawnAsync('forge', ['build', '--root', directory, '--silent'], { FOUNDRY_BUILD_INFO: 'false' });
        assert.equal(built.code, 0, 'Fixture Forge compilation failed');
        const buildInfoFolder = path.join(directory, 'out/build-info');
        assert(!fs.existsSync(buildInfoFolder) || fs.readdirSync(buildInfoFolder).every(name => {
            const info = JSON.parse(fs.readFileSync(path.join(buildInfoFolder, name)));
            return !info.input || !info.output;
        }), 'Fixture must start without full compiler build-info');
        // Newer Forge writes minimal bookkeeping here even without --build-info. Exercise the
        // absent-directory variant too, as found in previously cached ordinary builds.
        fs.rmSync(buildInfoFolder, { recursive: true, force: true });
        const cache = path.join(directory, 'cache');
        const evidence = path.join(cache, 'previous-proposal.json');
        fs.writeFileSync(evidence, '{"root":"preserve-me"}');
        const before = JSON.parse(fs.readFileSync(path.join(directory, 'out/SafeAirdropExecutor.sol/SafeAirdropExecutor.json')));
        const utils = require('@sphinx-labs/plugins/dist/foundry/utils');
        const getConfigArtifacts = utils.makeGetConfigArtifacts(path.join(directory, 'out'), buildInfoFolder, directory, cache);
        await ensureBuildInfo(getConfigArtifacts, {}, directory);
        assert.equal(fs.readFileSync(evidence, 'utf8'), '{"root":"preserve-me"}');
        const after = JSON.parse(fs.readFileSync(path.join(directory, 'out/SafeAirdropExecutor.sol/SafeAirdropExecutor.json')));
        assert.deepEqual(after.bytecode, before.bytecode, 'Metadata repair changed deployable bytecode');
        const initCode = after.bytecode.object + ethers.utils.defaultAbiCoder.encode(['address', 'address'], [SAFE, DEPLOYED]).slice(2);
        const { configArtifacts: actualArtifacts, buildInfos: actualBuildInfos } = await getConfigArtifacts([initCode]);
        const fqn = utils.findFullyQualifiedNameForInitCode(initCode, actualArtifacts);
        assert.equal(fqn, 'script/helpers/SafeAirdropExecutor.sol:SafeAirdropExecutor');
        const network = config();
        network.actionInputs[0].contracts = [{ address: DEPLOYED, initCodeWithArgs: initCode, fullyQualifiedName: fqn }];
        const payload = core.makeDeploymentConfig([network], actualArtifacts, actualBuildInfos,
            makeSphinxMerkleTree(core.makeDeploymentData([network])));
        assert.equal(payload.inputs.length, 1);
        assert(payload.inputs[0].input.sources['script/helpers/SafeAirdropExecutor.sol'].content.includes('contract SafeAirdropExecutor'));
        const metadataFiles = fs.readdirSync(buildInfoFolder);
        await ensureBuildInfo(getConfigArtifacts, {}, directory);
        assert.deepEqual(fs.readdirSync(buildInfoFolder), metadataFiles, 'Matching metadata should not rebuild again');
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

function qualification(directory) {
    const segments = [config('2'), config('3')].map(network => ({ networkConfigs: [network],
        merkleTree: makeSphinxMerkleTree(core.makeDeploymentData([network])) }));
    const report = { status: 'passed', sourceSha256: {}, segments: segments.map((segment, index) => ({ index, root: segment.merkleTree.root,
        chains: segment.networkConfigs.map(cfg => ({ chainId: cfg.chainId, moduleNonce: cfg.nonce,
            actions: cfg.actionInputs.map(action => ({ digest: actionDigest(action), signedGas: action.gas })) })) })) };
    if (directory) {
        fs.mkdirSync(directory, { recursive: true });
        fs.writeFileSync(path.join(directory, 'qualification.json'), JSON.stringify(report));
        fs.writeFileSync(path.join(directory, 'inputs.json'), JSON.stringify({ inputIdentity: 'fixture' }));
    }
    return { segments, report, reportDir: directory, configArtifacts, buildInfos, inputIdentity: 'fixture',
        preparedChains: [{ chainId: 42161, profile: 'mainnets', network: networksFor('mainnets', 42161)[0],
            safe: SAFE, hook: MODULE, resolver: RELAY, authority: { owners: [SAFE], threshold: 1 },
            plans: [{ contractName: 'OriginalPlan' }], envelopes: [batch('setup'), batch('migration'), batch('setup'), batch('migration')]
                .map(item => item.safeTransaction) }],
        entries: [{ networkConfig: config(), rpcUrl: 'https://example.invalid/private-key' }] };
}

async function sdkPayloadPass({ sphinxContext, isDryRun }) {
    const built = await sphinxContext.buildNetworkConfigArray('script', '0x', SAFE);
    const networks = built.networkConfigArrayWithRpcUrls.map(entry => entry.networkConfig);
    const tree = makeSphinxMerkleTree(core.makeDeploymentData(networks));
    const data = JSON.stringify(core.makeDeploymentConfig(networks, built.configArtifacts, built.buildInfos, tree));
    if (!isDryRun) {
        const deploymentConfigId = await sphinxContext.storeDeploymentConfig('secret', 'org', data);
        await sphinxContext.relayProposal({ tree: { root: tree.root }, deploymentConfigId });
    }
    return { merkleTree: tree };
}

test('all parts qualify before exactly one live upload; serialized evidence supports resume and dry run previews all', async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-sphinx-test-'));
    try {
        const events = [];
        const context = { storeDeploymentConfig: async () => { events.push('store'); return 'config-id'; },
            relayProposal: async () => events.push('relay') };
        const prepare = async () => {
            events.push('qualified-all');
            return qualification(directory);
        };
        const run = makeAirdropPropose(context, { officialPropose: sdkPayloadPass, prepare,
            assertReady: async () => events.push('fresh') });
        const result = await run({ isDryRun: false, silent: true, scriptPath: 'script/AirdropV4Bannys.s.sol', networks: ['mainnets'] });
        assert.equal(result.completed, 1);
        assert.deepEqual(events, ['qualified-all', 'fresh', 'store', 'relay']);
        const ledger = JSON.parse(fs.readFileSync(path.join(directory, 'proposal-progress.json')));
        assert.deepEqual(ledger.parts.map(part => part.status), ['submitted', 'not-submitted']);
        assert.equal(ledger.parts[0].deploymentConfigId, 'config-id');
        assert(!JSON.stringify(ledger).includes('private-key'));
        const artifact = readPreparedArtifact(directory);
        assert.equal(artifact.segments.length, 2);
        assert.deepEqual(artifact.proposalArgs.networks, ['mainnets']);
        assert(!JSON.stringify(artifact).includes('private-key'));
        assert.equal(artifact.preparedChains[0].planNames[0], 'OriginalPlan');
        events.length = 0;
        const dryDirectory = path.join(directory, 'dry');
        await makeAirdropPropose(context, { officialPropose: sdkPayloadPass,
            prepare: async () => qualification(dryDirectory) })({ isDryRun: true, silent: true });
        assert.deepEqual(events, []);
        assert(JSON.parse(fs.readFileSync(path.join(dryDirectory, 'proposal-progress.json'))).parts.every(part => part.status === 'dry-run'));
        fs.appendFileSync(path.join(directory, 'inputs.json'), ' ');
        assert.throws(() => readPreparedArtifact(directory), /input evidence changed/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('qualification failure prevents every upload and partial/unknown submission remains recoverable', async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-sphinx-failure-'));
    try {
        let stores = 0;
        let relays = 0;
        const context = { storeDeploymentConfig: async () => { stores++; return 'saved'; },
            relayProposal: async () => { relays++; throw Object.assign(new Error('private'), { code: 'TIMEOUT' }); } };
        await assert.rejects(makeAirdropPropose(context, { officialPropose: sdkPayloadPass,
            prepare: async () => { throw new Error('qualification failed'); } })({}), /qualification failed/);
        assert.equal(stores, 0);
        assert.equal(relays, 0);
        await assert.rejects(makeAirdropPropose(context, { officialPropose: sdkPayloadPass,
            prepare: async () => qualification(directory), assertReady: async () => {} })({ silent: true }), /0 part\(s\) were submitted/);
        const ledger = JSON.parse(fs.readFileSync(path.join(directory, 'proposal-progress.json')));
        assert.deepEqual(ledger.parts.map(part => part.status), ['submission-unknown', 'not-submitted']);
        assert.equal(ledger.parts[0].deploymentConfigId, 'saved');
        assert(ledger.parts.every(part => part.root && part.chains[0].nonce));
        assert.equal(relays, 1, 'No automatic retry');
        assert(!safeError(new Error('RPC https://user:password@node.invalid/token failed')).message.includes('password'));
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('payload or project identity changes after qualification fail before storage', async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-sphinx-mutation-'));
    try {
        let stored = false;
        const prepared = qualification(directory);
        prepared.segments[0].networkConfigs[0].actionInputs[0].gas = '1';
        await assert.rejects(makeAirdropPropose({ storeDeploymentConfig: async () => { stored = true; } }, {
            officialPropose: sdkPayloadPass, prepare: async () => prepared,
        })({ silent: true, isDryRun: true }), /Qualified proposal root changed/);
        assert.equal(stored, false);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('serial readiness requires completed roots, rejects failed/canceled prefixes and preserves uncertain submissions', async () => {
    const artifact = qualification();
    const progress = { parts: [{ status: 'submitted' }, { status: 'not-submitted' }] };
    for (const status of [3, 4]) await assert.rejects(nextReadyPart(artifact, progress,
        async () => ({ status, nonce: '3', activeRoot: ethers.constants.HashZero })), /canceled or failed/);
    const firstRoot = artifact.segments[0].merkleTree.root;
    const readState = async (_artifact, cfg, root) => ({ status: root === firstRoot ? 2 : 0,
        nonce: root === firstRoot ? '3' : cfg.nonce, activeRoot: ethers.constants.HashZero });
    assert.deepEqual(await nextReadyPart(artifact, progress, readState), { part: 1, completed: [0], status: 'ready' });
    for (const status of ['submitted', 'submission-unknown']) {
        const result = await nextReadyPart(artifact, { parts: [{ status }, { status: 'not-submitted' }] },
            async (_artifact, cfg) => ({ status: 0, nonce: cfg.nonce, activeRoot: ethers.constants.HashZero }));
        assert.equal(result.status, 'pending');
        assert.equal(result.part, 0);
    }
    await assert.rejects(nextReadyPart(artifact, { parts: [] }, async () =>
        ({ status: 0, nonce: '9', activeRoot: ethers.constants.HashZero })), /Module nonce changed/);
    await assert.rejects(nextReadyPart(artifact, { parts: [{ status: 'completed' }] }, async () =>
        ({ status: 0, nonce: '2', activeRoot: ethers.constants.HashZero })), /no longer completed/);
    const multichain = structuredClone(artifact);
    multichain.segments[0].networkConfigs.push({ ...multichain.segments[0].networkConfigs[0], chainId: '1' });
    assert.equal((await nextReadyPart(multichain, progress, async (_artifact, cfg) =>
        ({ status: cfg.chainId === '1' ? 0 : 2, nonce: cfg.nonce, activeRoot: ethers.constants.HashZero }))).status, 'pending');
});

test('resume refuses duplicate pending/unknown roots and submits only the next exact completed-prefix part', async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-sphinx-resume-'));
    try {
        let submissions = 0;
        const context = { storeDeploymentConfig: async () => 'saved', relayProposal: async () => { submissions++; } };
        await makeAirdropPropose(context, { officialPropose: sdkPayloadPass, prepare: async () => qualification(directory),
            assertReady: async () => {} })({ silent: true });
        const artifact = readPreparedArtifact(directory);
        const firstRoot = artifact.segments[0].merkleTree.root;
        const pending = await resumePrepared(context, directory, { silent: true }, {
            assertProject: async () => {},
            readState: async (_artifact, cfg) => ({ status: 0, nonce: cfg.nonce, activeRoot: ethers.constants.HashZero }),
        });
        assert.equal(pending.status, 'pending');
        assert.equal(submissions, 1);
        const events = [];
        const result = await resumePrepared(context, directory, { silent: true }, {
            assertProject: async () => {},
            officialPropose: async args => {
                events.push('sdk');
                return sdkPayloadPass(args);
            },
            readState: async (_artifact, cfg, root) => ({ status: root === firstRoot ? 2 : 0, nonce: cfg.nonce,
                activeRoot: ethers.constants.HashZero }),
            assertFresh: async () => events.push('fresh'), assertReady: async (_artifact, _directory, _progress, part) => {
                assert.equal(part, 1); events.push('ready');
            },
        });
        assert.equal(result.completed, 1);
        assert.equal(submissions, 2);
        assert.deepEqual(events, ['fresh', 'sdk', 'ready']);
        assert.deepEqual(JSON.parse(fs.readFileSync(path.join(directory, 'proposal-progress.json'))).parts.map(part => part.status),
            ['completed', 'submitted']);
        const complete = await resumePrepared(context, directory, { silent: true }, {
            assertProject: async () => {},
            readState: async () => ({ status: 2, nonce: '4', activeRoot: ethers.constants.HashZero }),
        });
        assert.equal(complete.status, 'complete');
        assert.equal(submissions, 2);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('resume binds canonical payloads and networks even when edited roots and evidence checksums are recomputed', () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-sphinx-binding-'));
    try {
        const original = writePreparedArtifact(qualification(directory), { scriptPath: 'script/AirdropV4Bannys.s.sol' });
        const hash = data => createHash('sha256').update(data).digest('hex');
        const persist = artifact => {
            const report = JSON.parse(fs.readFileSync(path.join(directory, 'qualification.json')));
            report.segments = artifact.segments.map((segment, index) => ({ index, root: segment.merkleTree.root,
                chains: segment.networkConfigs.map(cfg => ({ chainId: cfg.chainId, moduleNonce: cfg.nonce,
                    actions: cfg.actionInputs.map(action => ({ digest: actionDigest(action), signedGas: action.gas })) })) }));
            const proof = JSON.stringify(report);
            fs.writeFileSync(path.join(directory, 'qualification.json'), proof);
            artifact.qualificationSha256 = hash(proof);
            const body = JSON.stringify(artifact);
            fs.writeFileSync(path.join(directory, 'prepared.json'), body);
            fs.writeFileSync(path.join(directory, 'prepared.json.sha256'), hash(body));
        };
        const calldata = structuredClone(original);
        calldata.segments[1].networkConfigs[0].actionInputs[1].txData = '0xdeadbeef';
        calldata.segments[1].merkleTree = makeSphinxMerkleTree(core.makeDeploymentData(calldata.segments[1].networkConfigs));
        persist(calldata);
        assert.throws(() => readPreparedArtifact(directory), /canonical atomic envelope/);
        const network = structuredClone(original);
        network.preparedChains[0].network.sourceChainId = 1;
        persist(network);
        assert.throws(() => readPreparedArtifact(directory), /network mapping changed/);
        const unknown = structuredClone(original);
        unknown.segments[0].networkConfigs[0].chainId = '1';
        unknown.segments[0].merkleTree = makeSphinxMerkleTree(core.makeDeploymentData(unknown.segments[0].networkConfigs));
        persist(unknown);
        assert.throws(() => readPreparedArtifact(directory), /unprepared chain/);
        persist(structuredClone(original));
        const altered = JSON.parse(fs.readFileSync(path.join(directory, 'prepared.json')));
        altered.segments[0].networkConfigs[0].actionInputs[0].gas = '1';
        altered.segments[0].merkleTree = makeSphinxMerkleTree(core.makeDeploymentData(altered.segments[0].networkConfigs));
        const report = JSON.parse(fs.readFileSync(path.join(directory, 'qualification.json')));
        report.segments[0].root = altered.segments[0].merkleTree.root;
        const proof = JSON.stringify(report);
        fs.writeFileSync(path.join(directory, 'qualification.json'), proof);
        altered.qualificationSha256 = hash(proof);
        const body = JSON.stringify(altered);
        fs.writeFileSync(path.join(directory, 'prepared.json'), body);
        fs.writeFileSync(path.join(directory, 'prepared.json.sha256'), hash(body));
        assert.throws(() => readPreparedArtifact(directory), /gas differ from qualification/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('original script config anchors Safe and module before interpreting resume root state', async () => {
    const artifact = { ...qualification(), proposalArgs: { scriptPath: 'script/AirdropV4Bannys.s.sol' } };
    const official = async scriptPath => {
        assert.equal(scriptPath, 'script/AirdropV4Bannys.s.sol');
        return { safeAddress: SAFE, moduleAddress: MODULE, projectName: 'banny-core' };
    };
    await assertProjectIdentity(artifact, official);
    artifact.segments[0].networkConfigs[0].moduleAddress = SAFE;
    await assert.rejects(assertProjectIdentity(artifact, official), /Project module changed/);
});
