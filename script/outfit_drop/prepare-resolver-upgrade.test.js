'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { ethers } = require('ethers');
const { configurationHash, runtimeHash, storageBinding, deployment, deploymentTransaction } = require('./prepare-resolver-upgrade');
const settings = { owner: '0x1111111111111111111111111111111111111111',
    trustedForwarder: '0x2222222222222222222222222222222222222222', svgDescription: 'description',
    svgExternalUrl: 'url', svgBaseUri: 'base', bannyBody: 'body', defaultNecklace: 'necklace',
    defaultMouth: 'mouth', defaultStandardEyes: 'eyes', defaultAlienEyes: 'alien' };
const products = [{ upc: 1, hash: ethers.utils.id('art'), name: 'product', svgHash: ethers.utils.id('fallback') }];
test('configuration binds settings, names and commitments, independent of publication', () => {
    const baseline = configurationHash(settings, products, 1);
    for (const key of Object.keys(settings)) {
        const value = key === 'owner' || key === 'trustedForwarder' ? '0x3333333333333333333333333333333333333333' : 'changed';
        assert.notEqual(configurationHash({ ...settings, [key]: value }, products, 1), baseline);
    }
    for (const change of [{ hash: ethers.utils.id('different') }, { name: 'different' }]) {
        assert.notEqual(configurationHash(settings, [{ ...products[0], ...change }], 1), baseline);
    }
    assert.notEqual(configurationHash(settings, products, 2), baseline);
    assert.equal(configurationHash(settings, [{ ...products[0], svgHash: ethers.utils.id('published') }], 1), baseline);
});
test('runtime hash patches every forwarder reference and rejects new immutable layouts', () => {
    const compiled = { deployedBytecode: { object: `0x00${'00'.repeat(32)}ff${'00'.repeat(32)}`,
        immutableReferences: { 123: [{ start: 1, length: 32 }, { start: 34, length: 32 }] } } };
    const encoded = ethers.utils.hexZeroPad(settings.trustedForwarder, 32).slice(2);
    assert.equal(runtimeHash(compiled, { 123: settings.trustedForwarder }), ethers.utils.keccak256(`0x00${encoded}ff${encoded}`));
    assert.throws(() => runtimeHash({ deployedBytecode: { ...compiled.deployedBytecode,
        immutableReferences: { ...compiled.deployedBytecode.immutableReferences, 456: [] } } }, { 123: settings.trustedForwarder }), /immutable layout/);
});

test('writer binding resumes unbound or matching storage and refuses another resolver', () => {
    const storage = settings.owner;
    const replacement = settings.trustedForwarder;
    const binding = storageBinding(storage, ethers.constants.AddressZero, replacement);
    assert.equal(binding.to, storage);
    assert.equal(binding.value, '0');
    const decoded = new ethers.utils.Interface(['function setWriter(address)']).decodeFunctionData('setWriter', binding.data);
    assert.equal(decoded[0], replacement);
    assert.equal(storageBinding(storage, replacement, replacement), null);
    assert.throws(() => storageBinding(storage, storage, replacement), /another writer/);
});
test('deployment resume checks exact runtime at the pinned block', async () => {
    const item = { address: settings.owner, transaction: { to: settings.owner, data: '0x1234' } };
    const code = '0x60006000';
    const provider = { getCode: async (address, block) => {
        assert.equal(address, item.address); assert.equal(block, 123); return code;
    } };
    assert.equal(await deploymentTransaction(provider, item, ethers.utils.keccak256(code), 123), null);
    await assert.rejects(deploymentTransaction(provider, item, ethers.utils.keccak256('0x00'), 123), /unexpected code/);
    assert.deepEqual(await deploymentTransaction({ getCode: async () => '0x' }, item, ethers.utils.keccak256(code), 123), item.transaction);
});
test('storage CREATE2 identity does not depend on the resolver while resolver identity binds storage', () => {
    const storageArtifact = { abi: ['constructor(address configurator)'], bytecode: { object: '0x60006000' } };
    const resolverArtifact = { abi: ['constructor(address owner,address storageAddress)'], bytecode: { object: '0x60006001' } };
    const storage = deployment(storageArtifact, [settings.owner], 'bytecode-svg-storage');
    const resolver = deployment(resolverArtifact, [settings.owner, storage.address], 'bytecode-svg');
    assert.notEqual(deployment(resolverArtifact, [settings.owner, settings.trustedForwarder], 'bytecode-svg').address, resolver.address);
    assert.deepEqual(deployment(storageArtifact, [settings.owner], 'bytecode-svg-storage'), storage);
    assert.notEqual(deployment(storageArtifact, [settings.trustedForwarder], 'bytecode-svg-storage').address, storage.address);
});


test('preparation preserves publication evidence, separates native/Sphinx guard stages and rejects forwarder drift', async () => {
    const fs = require('node:fs'), path = require('node:path'), os = require('node:os'), Module = require('node:module');
    const contents = '<image href="inline-asset"/>';
    const hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(contents));
    const svg = '<svg width="400" height="400" viewBox="0 0 400 400" fill="white" xmlns="http://www.w3.org/2000/svg"><style>.o{fill:#050505;}.w{fill:#f9f9f9;}</style>' + contents + '</svg>';
    const compiled = { abi: ['constructor(string,string,string,string,string,address,address,address)'], bytecode: { object: '0x6000' },
        deployedBytecode: { object: '0x' + '00'.repeat(64), immutableReferences: { 1: [{ start: 0, length: 32 }], 2: [{ start: 32, length: 32 }] } } };
    const storage = { abi: ['constructor(address)'], bytecode: { object: '0x6001' },
        deployedBytecode: { object: '0x' + '00'.repeat(32), immutableReferences: { 3: [{ start: 0, length: 32 }] } } };
    const guard = { abi: ['function check(address,address,address,bytes32,bytes32,bytes32,uint256)'],
        bytecode: { object: '0x6002' }, deployedBytecode: { object: '0x6002' } };
    const filename = require.resolve('./prepare-resolver-upgrade');
    const loaded = new Module(filename, module); loaded.filename = filename; loaded.paths = module.paths;
    let inspections = 0;
    let ids = { forwarder: '1', storage: '2', configurator: '3' };
    let renumberDuringInspection = false;
    const regroup = (forwarder, svgStorage, configurator) => {
        ids = { forwarder, storage: svgStorage, configurator };
        compiled.deployedBytecode.immutableReferences = { [forwarder]: [{ start: 0, length: 32 }], [svgStorage]: [{ start: 32, length: 32 }] };
        storage.deployedBytecode.immutableReferences = { [configurator]: [{ start: 0, length: 32 }] };
    };
    loaded.require = name => name === 'node:child_process' ? { execFileSync: (_, args) => {
        inspections++;
        if (renumberDuringInspection) { regroup('20', '21', '22'); renumberDuringInspection = false; }
        return args[1] === 'BannySvgStorage'
            ? `function getter_fun_CONFIGURATOR_1() { loadimmutable("${ids.configurator}")\n}`
            : `function fun_trustedForwarder_1() { loadimmutable("${ids.forwarder}")\n}\nfunction getter_fun_SVG_STORAGE_1() { loadimmutable("${ids.storage}")\n}`;
    } }        : name === 'node:fs' ? { ...fs, readFileSync: (file, ...args) => String(file).endsWith('Banny721TokenUriResolver.json') ? JSON.stringify(compiled)
            : String(file).endsWith('BannySvgStorage.json') ? JSON.stringify(storage)
            : String(file).endsWith('BannyResolverUpgradeGuard.json') ? JSON.stringify(guard) : fs.readFileSync(file, ...args) } : require(name);
    loaded._compile(fs.readFileSync(filename, 'utf8'), filename);
    const hook = '0x3333333333333333333333333333333333333333', previous = '0x4444444444444444444444444444444444444444';
    const iface = new ethers.utils.Interface(['function STORE() view returns(address)', 'function owner() view returns(address)',
        'function projectId() view returns(uint256)', 'function PERMISSIONS() view returns(address)', 'function balanceOf(address) view returns(uint256)',
        'function tokenUriResolverOf(address) view returns(address)', 'function totalSupplyOf(address) view returns(uint256)',
        'function maxTierIdOf(address) view returns(uint256)', 'function numberOfBurnedFor(address,uint256) view returns(uint256)',
        'function svgHashOf(uint256) view returns(bytes32)', 'function namesOf(address,uint256) view returns(string,string,string)',
        'function svgOf(address,uint256,bool,bool) view returns(string)',
        ...Object.entries(settings).filter(([name]) => name !== 'owner').map(([name, value]) =>
            `function ${name}() view returns(${ethers.utils.isAddress(value) ? 'address' : 'string'})`)]);
    const values = { STORE: hook, owner: settings.owner, projectId: 1, PERMISSIONS: hook, balanceOf: 0,
        tokenUriResolverOf: previous, totalSupplyOf: 0, maxTierIdOf: 1, numberOfBurnedFor: 0,
        svgHashOf: hash, namesOf: ['', '', 'product'], svgOf: svg, ...settings };
    const provider = new ethers.providers.StaticJsonRpcProvider('http://127.0.0.1:1', { chainId: 1, name: 'local' });
    provider.getBlock = async () => ({ hash: ethers.utils.id('block') });
    provider.send = async name => { assert.equal(name, 'eth_chainId'); return '0x1'; };
    provider.perform = async (method, args) => {
        if (method === 'getCode') return [previous.toLowerCase(), '0x4e59b44847b379578588920ca78fbf26c0b4956c'].includes(args.address.toLowerCase()) ? '0x6000' : '0x';
        assert.equal(method, 'call');
        const call = iface.parseTransaction({ data: args.transaction.data });
        if (call.name === 'trustedForwarder' && args.transaction.to.toLowerCase() === hook.toLowerCase() && values.hookTrustedForwarder)
            return iface.encodeFunctionResult(call.name, [values.hookTrustedForwarder]);
        return iface.encodeFunctionResult(call.name, Array.isArray(values[call.name]) ? values[call.name] : [values[call.name]]);
    };
    const output = fs.mkdtempSync(path.join(os.tmpdir(), 'resolver-inline-preparation-'));
    try {
        const evidence = await loaded.exports.prepare({ provider, hook, safe: settings.owner, output, block: 123 });
        assert.deepEqual(evidence.inlineUpcs, [1]);
        assert.equal(evidence.publicationRequired[0].svgContents, contents);
        assert.match(evidence.instruction, /renderedSvg includes a wrapper/);
        const deploy = JSON.parse(fs.readFileSync(evidence.files[0])).transactions;
        const configure = JSON.parse(fs.readFileSync(evidence.files[1])).transactions;
        const guardDeployment = loaded.exports.deployment(guard, [], 'before-mint-guard').transaction;
        assert.deepEqual(configure[0], guardDeployment);
        assert(!deploy.some(call => call.data === guardDeployment.data));
        assert.equal(configure.at(-2).to, evidence.guard);
        assert.equal(configure.at(-1).to, hook);
        assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output, '1-evidence.json'))).publicationRequired, evidence.publicationRequired);
        assert.equal(evidence.guardStage, 'switch');
        const sphinxOutput = path.join(output, 'sphinx');
        const sphinx = await loaded.exports.prepare({ provider, hook, safe: settings.owner, output: sphinxOutput, block: 123, guardStage: 'deploy' });
        assert.equal(sphinx.guardStage, 'deploy');
        const sphinxDeploy = JSON.parse(fs.readFileSync(sphinx.files[0])).transactions;
        const sphinxSwitch = JSON.parse(fs.readFileSync(sphinx.files[1])).transactions;
        assert(sphinxDeploy.some(call => call.data === guardDeployment.data));
        assert(!sphinxSwitch.some(call => call.data === guardDeployment.data));
        for (const guardStage of ['unknown', '', null]) {
            await assert.rejects(loaded.exports.prepare({ provider, hook, safe: settings.owner, output: '/tmp/unused', guardStage }), /Guard stage/);
        }
        const root = path.resolve(__dirname, '../..');
        const before = inspections;
        assert.deepEqual(loaded.exports.immutableIds(root), { forwarder: '1', storage: '2', configurator: '3' });
        assert.equal(inspections, before, 'unchanged current layout reuses inspection');
        regroup('10', '11', '12');
        renumberDuringInspection = true;
        assert.deepEqual(loaded.exports.immutableIds(root), { forwarder: '20', storage: '21', configurator: '22' });
        assert.equal(inspections, before + 2, 'regrouped AST IDs invalidate the cache');
        assert.deepEqual(loaded.exports.immutableIds(root), { forwarder: '20', storage: '21', configurator: '22' });
        assert.equal(inspections, before + 2, 'post-inspect grouping is cached');
        values.hookTrustedForwarder = settings.owner;
        await assert.rejects(loaded.exports.prepare({ provider, hook, safe: settings.owner, output: '/tmp/unused', block: 123 }), /trusted forwarder differs from hook/);

    } finally { fs.rmSync(output, { recursive: true, force: true }); }
});
