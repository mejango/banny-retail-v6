const assert = require('node:assert/strict');
const { test } = require('node:test');
const { ethers } = require('ethers');
const core = require('@sphinx-labs/core');
const { makeSphinxMerkleTree } = require('@sphinx-labs/contracts');
const adapter = require('./propose-sphinx-resolver-upgrade');
const upgrade = require('./prepare-resolver-upgrade');
const exporter = require('./export-safe-airdrop');
const qualifier = require('./qualify-sphinx-airdrop');
const SAFE = '0x0000000000000000000000000000000000000001';
const HOOK = '0x37e35937ecF949d7a44a9Fe878107DE264618B8f';
const PREVIOUS = '0x0000000000000000000000000000000000000003';
const HASH = ethers.constants.HashZero;
const tx = (to, data) => ({ to, data, value: '0', contractMethod: null, contractInputsValues: null });

function fixture() {
    const artifacts = new Map([
        ['BannySvgStorage', { abi: ['constructor(address)', 'function setWriter(address)'], bytecode: { object: '0x60006000f3' } }],
        ['Banny721TokenUriResolver', { abi: ['constructor(string,string,string,string,string,address,address,address)'], bytecode: { object: '0x60016000f3' } }],
        ['BannyResolverUpgradeGuard', { abi: ['function check(address,address,address,bytes32,bytes32,bytes32,uint256)'], bytecode: { object: '0x60026000f3' } }],
    ]);
    const settings = { owner: SAFE, trustedForwarder: SAFE, svgDescription: 'description', svgExternalUrl: 'url', svgBaseUri: 'base',
        bannyBody: 'body', defaultNecklace: 'necklace', defaultMouth: 'mouth', defaultStandardEyes: 'eyes', defaultAlienEyes: 'alien' };
    const products = Array.from({ length: 5 }, (_, index) => ({ upc: index + 1, hash: index === 4 ? ethers.utils.id('asset') : HASH, name: index === 4 ? 'Scene' : 'Alien', burned: '0' }));
    const storage = upgrade.deployment(artifacts.get('BannySvgStorage'), [SAFE], 'bytecode-svg-storage');
    const resolver = upgrade.deployment(artifacts.get('Banny721TokenUriResolver'),
        ['body', 'necklace', 'mouth', 'eyes', 'alien', SAFE, SAFE, storage.address], 'bytecode-svg');
    const guard = upgrade.deployment(artifacts.get('BannyResolverUpgradeGuard'), [], 'before-mint-guard');
    const evidence = { chainId: 1, guardStage: 'deploy', safe: SAFE, previous: PREVIOUS, previousCodeHash: HASH, replacementCodeHash: HASH,
        svgStorage: storage.address, replacement: resolver.address, guard: guard.address,
        settings, products, maxTierId: 5, configurationHash: upgrade.configurationHash(settings, products, 5) };
    const iface = new ethers.utils.Interface(['function setMetadata(string,string,string)', 'function setSvgHashesOf(uint256[],bytes32[])',
        'function setProductNames(uint256[],string[])']);
    const calls = [[storage.transaction, resolver.transaction, guard.transaction,
        upgrade.storageBinding(storage.address, ethers.constants.AddressZero, resolver.address)], [
        tx(resolver.address, iface.encodeFunctionData('setMetadata', ['description', 'url', 'base'])),
        tx(resolver.address, iface.encodeFunctionData('setSvgHashesOf', [[5], [products[4].hash]])),
        tx(resolver.address, iface.encodeFunctionData('setProductNames', [[5], ['Scene']])),
        tx(guard.address, new ethers.utils.Interface(artifacts.get('BannyResolverUpgradeGuard').abi).encodeFunctionData('check',
            [HOOK, PREVIOUS, resolver.address, HASH, HASH, evidence.configurationHash, 5])),
        tx(HOOK, new ethers.utils.Interface(['function setMetadata(string,string,string,string,address,uint256,bytes32)'])
            .encodeFunctionData('setMetadata', ['', '', '', '', resolver.address, 0, HASH])),
    ]];
    const envelopes = calls.map((transactions, index) => exporter.wrapBatch(transactions,
        { chainId: '1', safe: SAFE, guardStage: 'deploy', stage: index ? 'resolver-switch' : 'resolver-deploy' }, '').safeTransaction);
    return { chain: { chainId: 1, safe: SAFE, hook: HOOK, evidence, canonicalBatches: calls, envelopes }, build: { artifacts } };
}

test('resolver canonical stages preserve exact calls and a normal storage-writer CALL', () => {
    const { chain, build } = fixture();
    adapter.assertFrozenCalls(chain, build);
    assert.equal(chain.envelopes[0].transaction.operation, 1);
    assert.equal(chain.canonicalBatches[0][3].to, chain.evidence.svgStorage);
    assert.equal(chain.canonicalBatches[0][3].data.slice(0, 10), ethers.utils.id('setWriter(address)').slice(0, 10));
    const config = { chainId: '1', safeAddress: SAFE, arbitraryChain: false,
        actionInputs: chain.envelopes.map(envelope => ({ to: envelope.transaction.to, value: '0', txData: envelope.transaction.data,
            operation: envelope.transaction.operation, requireSuccess: true })) };
    adapter.validatePrepared(config, chain);
    config.actionInputs[1].txData = '0x';
    assert.throws(() => adapter.validatePrepared(config, chain), /canonical atomic envelope/);
});

test('lowercase registry hooks are normalized before frozen canonical call comparison', () => {
    const { chain, build } = fixture();
    const registry = { address: HOOK.toLowerCase() };
    chain.hook = registry.address;
    assert.throws(() => adapter.assertFrozenCalls(chain, build), /configuration\/switch calls changed/);
    const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-hook-registry-'));
    try {
        fs.mkdirSync(path.join(directory, 'ethereum'));
        fs.writeFileSync(path.join(directory, 'ethereum', 'JB721TiersHook__ProjectBAN.json'), JSON.stringify(registry));
        chain.hook = exporter.readHookAddress({ folder: 'ethereum' }, { deployments: directory });
        adapter.assertFrozenCalls(chain, build);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('changing both saved calls and envelope cannot authorize an arbitrary call', () => {
    const { chain, build } = fixture();
    chain.canonicalBatches[1][4].to = PREVIOUS;
    chain.envelopes[1] = exporter.wrapBatch(chain.canonicalBatches[1], chain.envelopes[1], '').safeTransaction;
    assert.throws(() => adapter.assertFrozenCalls(chain, build), /configuration\/switch calls changed/);
});

test('deployment artifacts, writer binding, commitments and stage order fail closed', () => {
    for (const change of [chain => { chain.canonicalBatches[0][3].data = '0x12345678'; },
        chain => { chain.evidence.products[4].hash = HASH; },
        chain => { chain.evidence.svgStorage = PREVIOUS; },
        chain => { chain.canonicalBatches[0].push(chain.canonicalBatches[0][0]); }]) {
        const { chain, build } = fixture(); change(chain);
        assert.throws(() => adapter.assertFrozenCalls(chain, build));
    }
    const { chain } = fixture(); chain.envelopes.reverse();
    assert.throws(() => adapter.validatePrepared({ chainId: '1', safeAddress: SAFE, arbitraryChain: false }, chain), /requires deployment/);
});

test('deployment and configuration are separate complete roots with consecutive module nonces', () => {
    const config = { chainId: '1', nonce: '8', blockGasLimit: '60000000', safeAddress: SAFE,
        moduleAddress: HOOK, executorAddress: PREVIOUS, safeInitData: '0x', arbitraryChain: false,
        actionInputs: [0, 1].map(index => ({ to: SAFE, value: '0', txData: '0x', operation: 0,
            gas: '1000000', requireSuccess: true, index: String(index + 1), actionType: core.ActionInputType.CALL, contracts: [] })) };
    const segments = qualifier.packSegments([config], 2, () => true);
    assert.equal(segments.length, 2);
    assert.deepEqual(segments.map(segment => segment.networkConfigs[0].nonce), ['8', '9']);
    assert.deepEqual(segments.map(segment => segment.networkConfigs[0].actionInputs[0].index), ['1', '1']);
    assert.notEqual(segments[0].merkleTree.root, segments[1].merkleTree.root);
    assert.equal(makeSphinxMerkleTree(core.makeDeploymentData(segments[0].networkConfigs)).root, segments[0].merkleTree.root);
});

test('unreviewed contract deployment metadata is rejected', () => {
    const { chain } = fixture();
    assert.throws(() => adapter.actionFor({ batch: { transactions: chain.canonicalBatches[0] },
        safeTransaction: chain.envelopes[0] }, 0, {}), /Unreviewed resolver deployment artifact/);
});

function mockProvider(chain, changes = {}) {
    const iface = new ethers.utils.Interface(['function getOwners() view returns(address[])',
        'function getThreshold() view returns(uint256)', 'function CONFIGURATOR() view returns(address)',
        'function writer() view returns(address)', 'function SVG_STORAGE() view returns(address)',
        'function svgOf(address,uint256,bool,bool) view returns(string)', 'function projectId() view returns(uint256)',
        'function PERMISSIONS() view returns(address)', 'function STORE() view returns(address)', 'function balanceOf(address) view returns(uint256)',
        'function tokenUriResolverOf(address) view returns(address)', 'function totalSupplyOf(address) view returns(uint256)',
        'function maxTierIdOf(address) view returns(uint256)', 'function numberOfBurnedFor(address,uint256) view returns(uint256)',
        'function svgHashOf(uint256) view returns(bytes32)', 'function namesOf(address,uint256) view returns(string,string,string)',
        ...Object.entries(chain.evidence.settings).map(([name, value]) =>
            `function ${name}() view returns(${ethers.utils.isAddress(value) ? 'address' : 'string'})`)]);
    const values = { getOwners: [SAFE], getThreshold: 2, CONFIGURATOR: SAFE,
        writer: chain.evidence.replacement, SVG_STORAGE: chain.evidence.svgStorage,
        STORE: PREVIOUS, projectId: 1, PERMISSIONS: PREVIOUS, balanceOf: 0, tokenUriResolverOf: chain.evidence.replacement,
        totalSupplyOf: 0, maxTierIdOf: 5, numberOfBurnedFor: 0, ...chain.evidence.settings, ...changes };
    const provider = new ethers.providers.StaticJsonRpcProvider('http://127.0.0.1:1', { chainId: 1, name: 'local' });
    provider.perform = async (method, args) => {
        if (method === 'getCode') return changes.guardCode !== undefined && args.address.toLowerCase() === chain.evidence.guard.toLowerCase()
            ? changes.guardCode : changes.code || '0x6000';
        assert.equal(method, 'call');
        const call = iface.parseTransaction({ data: args.transaction.data });
        if (call.name === 'trustedForwarder' && args.transaction.to.toLowerCase() === HOOK.toLowerCase())
            return iface.encodeFunctionResult(call.name, [changes.hookTrustedForwarder || values.trustedForwarder]);
        if (call.name === 'svgOf') return iface.encodeFunctionResult(call.name,
            [changes.svg && call.args[1].div(1_000_000_000).eq(5) ? changes.svg : changes.allSvg || '<image href="fallback"/>']);
        if (call.name === 'svgHashOf') return iface.encodeFunctionResult(call.name,
            [changes.svgHashOf || chain.evidence.products[call.args[0].toNumber() - 1].hash]);
        if (call.name === 'namesOf') return iface.encodeFunctionResult(call.name,
            ['', '', changes.productName || chain.evidence.products[call.args[1].div(1_000_000_000).toNumber() - 1].name]);
        return iface.encodeFunctionResult(call.name, [values[call.name]]);
    };
    return provider;
}

test('live runtime, configurator, writer and resolver storage are verified before advancing', async () => {
    const { chain } = fixture();
    const hash = ethers.utils.keccak256('0x6000');
    Object.assign(chain.evidence, { storageCodeHash: hash, replacementCodeHash: hash, guardCodeHash: hash });
    await adapter.assertDeployment(mockProvider(chain), chain);
    for (const changes of [{ code: '0x6001' }, { CONFIGURATOR: PREVIOUS }, { writer: PREVIOUS }, { SVG_STORAGE: PREVIOUS }]) {
        await assert.rejects(adapter.assertDeployment(mockProvider(chain, changes), chain));
    }
});

test('each participating Safe must retain the qualified owners and threshold', async () => {
    const { chain } = fixture(); chain.authority = { owners: [SAFE], threshold: '2' };
    await adapter.assertAuthority(mockProvider(chain), chain);
    await assert.rejects(adapter.assertAuthority(mockProvider(chain, { getOwners: [PREVIOUS] }), chain), /authority changed/);
    await assert.rejects(adapter.assertAuthority(mockProvider(chain, { getThreshold: 1 }), chain), /authority changed/);
});

test('final activation verification binds pointer, every setting/name/hash and zero mint/burn/custody', async () => {
    const { chain } = fixture(); chain.authority = { owners: [SAFE], threshold: '2' };
    const hash = ethers.utils.keccak256('0x6000');
    Object.assign(chain.evidence, { storageCodeHash: hash, replacementCodeHash: hash, guardCodeHash: hash });
    await adapter.assertSwitched(mockProvider(chain), chain);
    for (const changes of [{ tokenUriResolverOf: PREVIOUS }, { totalSupplyOf: 1 }, { numberOfBurnedFor: 1 },
        { balanceOf: 1 }, { svgDescription: 'different' }, { productName: 'different' }, { svgHashOf: ethers.utils.id('different') },
        { maxTierIdOf: 6 }]) await assert.rejects(adapter.assertSwitched(mockProvider(chain, changes), chain));
});

test('a completed resume cannot return success without final workflow verification', async () => {
    const shared = require('./propose-sphinx-airdrop');
    const originalResume = shared.resumePrepared, originalRead = shared.readPreparedArtifact;
    shared.resumePrepared = async () => ({ status: 'complete' });
    shared.readPreparedArtifact = () => ({ workflow: 'airdrop', segments: [] });
    try { await assert.rejects(adapter.resumePrepared({}, '/tmp/unused'), /Wrong prepared workflow/); }
    finally { shared.resumePrepared = originalResume; shared.readPreparedArtifact = originalRead; }
});


test('permissionless old artwork publication between roots preserves activation authority', async () => {
    const { chain } = fixture();
    const contents = '<path d="M1 1"/>';
    const rendered = '<svg width="400" height="400" viewBox="0 0 400 400" fill="white" xmlns="http://www.w3.org/2000/svg"><style>.o{fill:#050505;}.w{fill:#f9f9f9;}</style>' + contents + '</svg>';
    chain.evidence.products[4].hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(contents));
    const baseline = await upgrade.collect(mockProvider(chain, { tokenUriResolverOf: PREVIOUS }), HOOK, SAFE, 123);
    Object.assign(chain.evidence, baseline);
    const fresh = await adapter.assertCollectionFresh(mockProvider(chain, { tokenUriResolverOf: PREVIOUS, svg: rendered }), chain, 124);
    assert.deepEqual(fresh.inlineUpcs, [5]);
    assert.equal(fresh.publicationRequired[0].svgContents, contents);
    assert.notEqual(fresh.oldArtworkHash, baseline.oldArtworkHash);
    for (const changes of [{ svgDescription: 'changed' }, { productName: 'changed' }, { svgHashOf: ethers.utils.id('changed') },
        { totalSupplyOf: 1 }, { balanceOf: 1 }, { numberOfBurnedFor: 1 }, { maxTierIdOf: 6 }, { code: '0x6001' }, { hookTrustedForwarder: PREVIOUS }]) {
        await assert.rejects(adapter.assertCollectionFresh(mockProvider(chain, { tokenUriResolverOf: PREVIOUS, ...changes }), chain, 124));
    }
    await assert.rejects(adapter.assertCollectionFresh(mockProvider(chain,
        { tokenUriResolverOf: PREVIOUS, allSvg: '<image href="different"/>' }), chain, 124), /products changed/);
});

test('fresh resolver part replay uses canonical envelopes and verifies the reached stage', async () => {
    const original = qualifier.replayPreparedPart;
    const { chain } = fixture();
    chain.authority = { owners: [SAFE], threshold: '2' };
    const hash = ethers.utils.keccak256('0x6000');
    Object.assign(chain.evidence, { storageCodeHash: hash, replacementCodeHash: hash, guardCodeHash: hash });
    const artifact = { segments: [{}, {}], preparedChains: [chain] };
    let calls = 0;
    qualifier.replayPreparedPart = async (a, directory, part, workflow) => {
        assert.equal(a, artifact); assert.equal(directory, '/tmp/replay'); calls++;
        const config = { chainId: '1', safeAddress: SAFE, arbitraryChain: false,
            actionInputs: [{ ...chain.envelopes[part].transaction, txData: chain.envelopes[part].transaction.data, requireSuccess: true }] };
        const prepared = { ...chain, envelopes: [chain.envelopes[part]] };
        assert.equal(workflow.validatePrepared(config, prepared).size, 0);
        config.actionInputs[0].txData = '0x';
        assert.throws(() => workflow.validatePrepared(config, prepared), /canonical atomic Safe envelope/);
        const fork = { provider: mockProvider(chain), prepared, report: {} };
        await workflow.verifyFinal(fork);
        assert.equal(fork.report[part ? 'resolverUpgradeVerified' : 'resolverDeploymentVerified'], true);
        await assert.rejects(workflow.verifyFinal({ ...fork, provider: mockProvider(chain, { writer: PREVIOUS }) }));
        return { status: 'passed' };
    };
    try {
        assert.deepEqual(await adapter.replayPreparedPart(artifact, '/tmp/replay', 0), { status: 'passed' });
        assert.deepEqual(await adapter.replayPreparedPart(artifact, '/tmp/replay', 1), { status: 'passed' });
        assert.equal(calls, 2);
    } finally { qualifier.replayPreparedPart = original; }
});


test('Sphinx requires the guard after the deployment root as well as after activation', async () => {
    const { chain } = fixture(); chain.authority = { owners: [SAFE], threshold: '2' };
    const hash = ethers.utils.keccak256('0x6000');
    Object.assign(chain.evidence, { storageCodeHash: hash, replacementCodeHash: hash, guardCodeHash: hash });
    const absent = mockProvider(chain, { guardCode: '0x' });
    await assert.rejects(adapter.assertDeployment(absent, chain), /runtime changed/);
    await assert.rejects(adapter.assertSwitched(absent, chain), /runtime changed/);
    for (const changes of [{ guardCode: '0x6001' }, { code: '0x' }, { writer: PREVIOUS }, { CONFIGURATOR: PREVIOUS }]) {
        await assert.rejects(adapter.assertDeployment(mockProvider(chain, changes), chain));
    }
});

test('Sphinx collects guard creation in the deployment root and rejects altered guard grouping', () => {
    const utils = require('@sphinx-labs/plugins/dist/foundry/utils');
    const original = utils.findFullyQualifiedNameForInitCode;
    const { chain, build } = fixture();
    utils.findFullyQualifiedNameForInitCode = initCode => {
        const [name] = [...build.artifacts].find(([, artifact]) => initCode.startsWith(artifact.bytecode.object));
        return `${name === 'BannyResolverUpgradeGuard' ? 'script/helpers' : 'src'}/${name}.sol:${name}`;
    };
    try {
        const deploy = { batch: { transactions: chain.canonicalBatches[0] }, safeTransaction: chain.envelopes[0] };
        const switchBatch = { batch: { transactions: chain.canonicalBatches[1] }, safeTransaction: chain.envelopes[1] };
        assert.equal(adapter.actionFor(deploy, 0, {}).contracts.length, 3);
        assert.equal(adapter.actionFor(deploy, 0, {}).contracts[2].fullyQualifiedName,
            'script/helpers/BannyResolverUpgradeGuard.sol:BannyResolverUpgradeGuard');
        const existing = fixture();
        existing.chain.canonicalBatches[0].splice(2, 1);
        existing.chain.envelopes[0] = exporter.wrapBatch(existing.chain.canonicalBatches[0], existing.chain.envelopes[0], '').safeTransaction;
        adapter.assertFrozenCalls(existing.chain, existing.build);
        assert.equal(adapter.actionFor({ batch: { transactions: existing.chain.canonicalBatches[0] },
            safeTransaction: existing.chain.envelopes[0] }, 0, {}).contracts.length, 2);

        switchBatch.batch.transactions.unshift(chain.canonicalBatches[0][2]);
        assert.throws(() => adapter.actionFor(switchBatch, 1, {}), /guarded stage/);
        chain.evidence.guardStage = 'switch';
        assert.throws(() => adapter.assertFrozenCalls(chain, build), /Sphinx guard must deploy/);
        deploy.safeTransaction = { ...deploy.safeTransaction, stage: 'resolver-switch' };
        assert.throws(() => adapter.actionFor(deploy, 0, {}), /guarded stage/);
    } finally { utils.findFullyQualifiedNameForInitCode = original; }
});

test('a guard appearing after preparation refuses the stale deployment root before upload', async () => {
    const fs = require('node:fs'), path = require('node:path'), os = require('node:os'), Module = require('node:module');
    const shared = require('./propose-sphinx-airdrop');
    const { chain, build } = fixture();
    chain.authority = { owners: [SAFE], threshold: '2' };
    const provider = mockProvider(chain, { tokenUriResolverOf: PREVIOUS });
    Object.assign(chain.evidence, await upgrade.collect(provider, HOOK, SAFE, 123));
    chain.canonicalBatches[1][3].data = new ethers.utils.Interface(build.artifacts.get('BannyResolverUpgradeGuard').abi).encodeFunctionData('check',
        [HOOK, PREVIOUS, chain.evidence.replacement, chain.evidence.previousCodeHash, chain.evidence.replacementCodeHash, chain.evidence.configurationHash, 5]);
    chain.envelopes[1] = exporter.wrapBatch(chain.canonicalBatches[1], chain.envelopes[1], '').safeTransaction;
    provider.getBlockNumber = async () => 124;
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'guard-appeared-freshness-'));
    const filename = require.resolve('./propose-sphinx-resolver-upgrade');
    const loaded = new Module(filename, module); loaded.filename = filename; loaded.paths = module.paths;
    // Isolate the live freshness boundary. Canonical cryptographic/source validation has its separate regressions.
    loaded.require = name => name === './export-safe-airdrop' ? { ...exporter,
        readCompiledArtifact: contract => build.artifacts.get(contract) }
        : name === './propose-sphinx-airdrop' ? { ...shared, sourceIdentity: () => 'frozen',
            assertCanonicalActions: () => {}, providerFor: () => provider }
        : name === './prepare-resolver-upgrade' ? { ...upgrade, prepare: async options => {
            assert.equal(options.guardStage, 'deploy');
            // A fresh preparation omits the now-deployed, verified guard, changing the frozen root's calls.
            const calls = chain.canonicalBatches.map(batch => batch.slice()); calls[0].splice(2, 1);
            const files = calls.map((transactions, index) => {
                const file = path.join(options.output, `1-${index ? '02-configure-and-switch' : '01-deploy'}.json`);
                fs.writeFileSync(file, JSON.stringify({ transactions, meta: { name: 'fresh' } })); return file;
            });
            return { ...chain.evidence, files };
        } } : require(name);
    loaded._compile(fs.readFileSync(filename, 'utf8'), filename);
    try {
        fs.writeFileSync(path.join(directory, 'qualification.json'), JSON.stringify({ sourceSha256: {} }));
        await assert.rejects(loaded.exports.assertPreparedFresh({ workflow: adapter.WORKFLOW, inputIdentity: 'frozen',
            preparedChains: [chain], segments: [{}, {}] }, directory, 0), /Pending deployment\/configuration calls changed/);
        const observations = fs.readdirSync(directory).filter(file => file.startsWith('artwork-observation-'));
        assert.equal(observations.length, 1);
        await assert.rejects(loaded.exports.assertPreparedFresh({ workflow: adapter.WORKFLOW, inputIdentity: 'frozen',
            preparedChains: [chain], segments: [{}, {}] }, directory, 0), /Pending deployment\/configuration calls changed/);
        assert.equal(fs.readdirSync(directory).filter(file => file.startsWith('artwork-observation-')).length, 2);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
