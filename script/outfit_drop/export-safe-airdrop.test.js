const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, after } = require('node:test');
const { execFileSync } = require('node:child_process');
const { ethers } = require('ethers');
const { MultiSendCallOnlyArtifact } = require('@sphinx-labs/contracts');
const generator = require('./generate-v6-airdrop');
const { prepareChain, buildBatch: buildExport, combineMigrationBatches, readArtifact, assertGeneratedSnapshot, networksFor, preflight, writeExports, defaultSafe, bindNonce,
    encodeApprovedExecution, prepareApprovedExecution, SAFE_TRANSACTION_FIELDS,
    partitionPlan, MAX_MINTS_PER_TRANSACTION, needsSetup, executorNeedsSetup,
    FACTORY, MULTISEND, NETWORKS } = require('./export-safe-airdrop');

const ROOT = path.resolve(__dirname, '../..');
const SAFE = defaultSafe();
const HOOK = generator.V6_MAINNET_HOOK;
const RESOLVER = '0x0000000000000000000000000000000000000002';
const STORE = '0x0000000000000000000000000000000000000003';
const PERMISSIONS = '0x0000000000000000000000000000000000000004';
const SVG_STORAGE = '0x0000000000000000000000000000000000000005';
const FORWARDER = '0x0000000000000000000000000000000000000006';
// Build a tiny genuine immutable-bearing artifact rather than bypassing the shared preflight gate.
const identityRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-resolver-identity-'));
fs.mkdirSync(path.join(identityRoot, 'src'));
fs.writeFileSync(path.join(identityRoot, 'foundry.toml'), '[profile.default]\nscript = "unused-script"\ntest = "unused-test"\nsolc = "0.8.28"\nbytecode_hash = "none"\nast = true\n');
fs.writeFileSync(path.join(identityRoot, 'src/Banny721TokenUriResolver.sol'), `pragma solidity ^0.8.28;
import {ERC2771Context} from "./ERC2771Context.sol";
import {BannySvgStorage} from "./BannySvgStorage.sol";
contract Banny721TokenUriResolver is ERC2771Context {
    BannySvgStorage public immutable SVG_STORAGE;
    constructor(address f, address s) ERC2771Context(f) { SVG_STORAGE = BannySvgStorage(s); }
}`);
fs.writeFileSync(path.join(identityRoot, 'src/ERC2771Context.sol'), `pragma solidity ^0.8.28;
contract ERC2771Context {
    address private immutable _trustedForwarder;
    constructor(address f) { _trustedForwarder = f; }
    function trustedForwarder() public view returns (address) { return _trustedForwarder; }
}`);
fs.writeFileSync(path.join(identityRoot, 'src/BannySvgStorage.sol'), `pragma solidity ^0.8.28;
contract BannySvgStorage {
    address public immutable CONFIGURATOR;
    constructor(address c) { CONFIGURATOR = c; }
}`);
execFileSync('forge', ['build'], { cwd: identityRoot, stdio: 'pipe' });
const { immutableIds } = require('./prepare-resolver-upgrade');
const identityIds = immutableIds(identityRoot);
const resolverArtifact = JSON.parse(fs.readFileSync(path.join(identityRoot, 'out/Banny721TokenUriResolver.sol/Banny721TokenUriResolver.json')));
const storageArtifact = JSON.parse(fs.readFileSync(path.join(identityRoot, 'out/BannySvgStorage.sol/BannySvgStorage.json')));
function fixtureRuntime(compiled, values) {
    const bytes = ethers.utils.arrayify(compiled.deployedBytecode.object);
    for (const [id, value] of Object.entries(values)) for (const { start } of compiled.deployedBytecode.immutableReferences[id]) {
        bytes.set(ethers.utils.arrayify(ethers.utils.hexZeroPad(value, 32)), start);
    }
    return ethers.utils.hexlify(bytes);
}
const resolverRuntime = fixtureRuntime(resolverArtifact, { [identityIds.forwarder]: FORWARDER, [identityIds.storage]: SVG_STORAGE });
const storageRuntime = fixtureRuntime(storageArtifact, { [identityIds.configurator]: SAFE });
// Operator authority reads retain the owning permission IDs.
fs.mkdirSync(path.join(identityRoot, 'node_modules/@bananapus/permission-ids-v6/src'), { recursive: true });
fs.copyFileSync(path.join(ROOT, 'node_modules/@bananapus/permission-ids-v6/src/JBPermissionIds.sol'),
    path.join(identityRoot, 'node_modules/@bananapus/permission-ids-v6/src/JBPermissionIds.sol'));
after(() => fs.rmSync(identityRoot, { recursive: true, force: true }));
const plans = generator.buildContractsByChain(generator.loadRawItems());
const helperPlans = generator.buildCombinedContractsByChain(generator.loadRawItems());
// Encoding tests use synthetic helpers; resolver preflight uses the genuine tiny Forge fixture above.
const artifact = {
    abi: [
        'function decorateBannys(address,address,address,address,address,bool,uint256[],uint256[],uint256[],uint256[],uint256[])',
        'function transferRegular(address,address,address,address,bool,address[],uint256[],uint256[],bool[])',
        'function requireNoBalance(address)',
    ],
    bytecode: { object: '0x60006000f3' },
    deployedBytecode: { object: '0x00' },
};
const executorArtifact = {
    abi: ['constructor(address safe,address implementation)', 'function execute(bytes[])'],
    bytecode: { object: '0x60016000f3' }, deployedBytecode: { object: '0x00' },
};
const identityOptions = { root: identityRoot, deployments: path.join(identityRoot, 'deployments') };
for (const network of Object.values(NETWORKS).flat()) {
    const folder = path.join(identityOptions.deployments, network.folder);
    fs.mkdirSync(folder, { recursive: true });
    fs.writeFileSync(path.join(folder, 'JB721TiersHook__ProjectBAN.json'), JSON.stringify({ address: HOOK }));
}
for (const helperPlan of Object.values(helperPlans).map(plans => plans[0])) {
    const source = `script/${helperPlan.fileName}`;
    const text = generator.generateAirdropContract(helperPlan);
    fs.mkdirSync(path.dirname(path.join(identityRoot, source)), { recursive: true });
    fs.writeFileSync(path.join(identityRoot, source), text);
    const folder = path.join(identityRoot, 'out', path.basename(source));
    fs.mkdirSync(folder, { recursive: true });
    fs.writeFileSync(path.join(folder, `${helperPlan.contractName}.json`), JSON.stringify({ ...artifact, metadata: {
        settings: { compilationTarget: { [source]: helperPlan.contractName } },
        sources: { [source]: { keccak256: ethers.utils.id(text) } },
    } }));
}
const migration = new ethers.utils.Interface(artifact.abi);
const executor = new ethers.utils.Interface(executorArtifact.abi);
const mint = new ethers.utils.Interface(['function mintFor(uint16[],address)']);
const multisend = new ethers.utils.Interface(MultiSendCallOnlyArtifact.abi);

function buildBatch(input) {
    return buildExport({ ...input, plan: input.plan.slice ? input.plan : partitionPlan(input.plan)[0],
        helperPlan: helperPlans[input.plan.chain.id][0], executorArtifact });
}

test('partition preserves all original token IDs, recipients, per-tier order and complete bodies deterministically', () => {
    const componentSizes = new Map();
    let count = 0;
    for (const plan of Object.values(plans).flat()) {
        const slices = partitionPlan(plan);
        assert.deepEqual(partitionPlan(plan), slices);
        assert.deepEqual(slices.map(slice => slice.slice), slices.map((_, index) => index + 1));
        const minted = slices.flatMap(slice => slice.assignments.expectedTokenIds);
        assert.equal(new Set(minted).size, plan.assignments.expectedTokenIds.length);
        assert.deepEqual([...minted].sort((a, b) => a - b), [...plan.assignments.expectedTokenIds].sort((a, b) => a - b));
        for (const tier of new Set(plan.assignments.tierIds)) {
            const originalIds = plan.assignments.expectedTokenIds.filter((_, index) => plan.assignments.tierIds[index] === tier);
            const slicedIds = slices.flatMap(slice => slice.assignments.expectedTokenIds.filter((_, index) => slice.assignments.tierIds[index] === tier));
            assert.deepEqual(slicedIds, originalIds, `${plan.contractName}: tier ${tier} order changed`);
        }
        const transfers = slices.flatMap(slice => slice.transferItems);
        assert.equal(transfers.length, plan.transferItems.length);
        for (const entry of plan.transferItems) assert.equal(transfers.filter(candidate => candidate === entry).length, 1);
        assert.deepEqual(slices.flatMap(slice => slice.bannies).map(banny => banny.tokenId).sort((a, b) => a - b),
            plan.bannies.map(banny => banny.tokenId).sort((a, b) => a - b));
        for (const slice of slices) {
            assert(slice.assignments.tierIds.length > 0 && slice.assignments.tierIds.length <= MAX_MINTS_PER_TRANSACTION);
            for (const banny of slice.bannies) {
                for (const id of [banny.tokenId, ...banny.outfitIds, ...(banny.backgroundId ? [banny.backgroundId] : [])]) {
                    assert.equal(slice.assignments.v4ToV6TokenIds.get(id), plan.assignments.v4ToV6TokenIds.get(id));
                }
            }
        }
        componentSizes.set(plan.contractName, slices.flatMap(slice => slice.dependencyGroups.map(group => group.length)));
        count += slices.length;
    }
    assert.equal(count, 35);
    assert(componentSizes.get('AirdropV4BannysBase1').includes(36));
    assert(componentSizes.get('AirdropV4BannysEthereum4').includes(9));
    const plan = plans[1][0];
    const originalIds = [...plan.assignments.v4ToV6TokenIds.keys()];
    assert.throws(() => partitionPlan({ ...plan, bannies: [{ tokenId: originalIds[0], outfitIds: originalIds.slice(1), backgroundId: 0 }] }), /Indivisible body group/);
});

test('all 70 migration slices encode separate setup and Safe-bound atomic recipient actions', () => {
    let total = 0;
    const helpers = new Set();
    for (const [profile, networks] of Object.entries(NETWORKS)) for (const network of networks) {
        for (const [index, original] of plans[network.sourceChainId].entries()) for (const plan of partitionPlan(original)) {
            const input = { plan, artifact, profile, chainId: network.chainId, safe: SAFE, hook: HOOK,
                resolver: RESOLVER, chunk: index + 1 };
            const result = buildBatch(input);
            assert.deepEqual(buildBatch(input), result);
            const { batch, safeTransaction, setup } = result;
            assert.equal(batch.chainId, String(network.chainId));
            assert.equal(batch.meta.createdFromSafeAddress, SAFE);
            assert.deepEqual(batch.transactions.map(tx => tx.to), [HOOK, safeTransaction.helper]);
            assert.equal(safeTransaction.stage, 'migration');
            assert.equal(safeTransaction.slice, plan.slice);
            assert.deepEqual(safeTransaction.expectedTokenIds, plan.assignments.expectedTokenIds);
            assert.equal(setup.safeTransaction.stage, 'setup');
            assert.deepEqual(setup.safeTransaction.expectedTokenIds, []);
            assert(setup.batch.transactions.every(tx => tx.to === FACTORY));
            const predicted = setup.batch.transactions.map(deploy => {
                const salt = ethers.utils.hexDataSlice(deploy.data, 0, 32);
                const initCode = ethers.utils.hexDataSlice(deploy.data, 32);
                return ethers.utils.getCreate2Address(FACTORY, salt, ethers.utils.keccak256(initCode));
            });
            assert.deepEqual(predicted, [safeTransaction.implementation, safeTransaction.helper]);
            const wrapperInit = ethers.utils.hexDataSlice(setup.batch.transactions[1].data, 32);
            const constructorArgs = ethers.utils.hexDataSlice(wrapperInit, ethers.utils.hexDataLength(executorArtifact.bytecode.object));
            assert.deepEqual(Array.from(ethers.utils.defaultAbiCoder.decode(['address', 'address'], constructorArgs)),
                [SAFE, safeTransaction.implementation]);
            helpers.add(safeTransaction.helper);
            const [tiers, beneficiary] = mint.decodeFunctionData('mintFor', batch.transactions[0].data);
            assert.deepEqual(tiers, plan.assignments.tierIds);
            assert.equal(beneficiary, safeTransaction.helper);
            const [calls] = executor.decodeFunctionData('execute', batch.transactions[1].data);
            assert.equal(calls.length, plan.bannies.length ? 3 : 2);
            const transfer = migration.decodeFunctionData('transferRegular', calls.at(-2));
            assert.deepEqual(transfer.slice(0, 5), [HOOK, generator.V4_HOOK, generator.V4_RESOLVER,
                generator.V4_RESOLVER_FALLBACK, profile === 'mainnets']);
            assert.deepEqual(transfer[5], plan.transferItems.map(entry => ethers.utils.getAddress(entry.owner)));
            assert.deepEqual(transfer[6].map(id => id.toNumber()), plan.transferItems.map(entry => plan.assignments.v4ToV6TokenIds.get(generator.itemTokenId(entry.item))));
            assert.deepEqual(transfer[7].map(id => id.toNumber()), plan.transferItems.map(entry => generator.itemTokenId(entry.item)));
            assert.deepEqual(transfer[8], plan.transferItems.map(entry => Boolean(entry.allowResolverOwner)));
            assert.equal(migration.decodeFunctionData('requireNoBalance', calls.at(-1))[0], HOOK);
            if (plan.bannies.length) {
                const decorate = migration.decodeFunctionData('decorateBannys', calls[0]);
                assert.deepEqual(decorate.slice(0, 6), [HOOK, RESOLVER, generator.V4_HOOK, generator.V4_RESOLVER,
                    generator.V4_RESOLVER_FALLBACK, profile === 'mainnets']);
                assert.deepEqual(decorate[6].map(id => id.toNumber()), plan.bannies.map(banny => banny.tokenId));
                assert.deepEqual(decorate[7].map(id => id.toNumber()), plan.bannies.map(banny => plan.assignments.v4ToV6TokenIds.get(banny.tokenId)));
                assert.deepEqual(decorate[8].map(id => id.toNumber()), plan.bannies.map(banny => banny.backgroundId ? plan.assignments.v4ToV6TokenIds.get(banny.backgroundId) : 0));
                for (const [i, banny] of plan.bannies.entries()) {
                    assert.deepEqual(decorate[10].slice(decorate[9][i].toNumber(), decorate[9][i + 1].toNumber()).map(id => id.toNumber()),
                        banny.outfitIds.map(id => plan.assignments.v4ToV6TokenIds.get(id)));
                }
            }
            for (const output of [result, setup]) {
                const tx = output.safeTransaction.transaction;
                assert.equal(tx.to, MULTISEND);
                assert.equal(tx.operation, 1);
                assert.equal(tx.nonce, null);
                const [packed] = multisend.decodeFunctionData('multiSend', tx.data);
                let offset = 0;
                for (const call of output.batch.transactions) {
                    assert.equal(ethers.utils.hexDataSlice(packed, offset, offset + 1), '0x00');
                    assert.equal(ethers.utils.getAddress(ethers.utils.hexDataSlice(packed, offset + 1, offset + 21)), call.to);
                    assert.equal(ethers.BigNumber.from(ethers.utils.hexDataSlice(packed, offset + 21, offset + 53)).toString(), '0');
                    const length = ethers.BigNumber.from(ethers.utils.hexDataSlice(packed, offset + 53, offset + 85)).toNumber();
                    assert.equal(ethers.utils.hexDataSlice(packed, offset + 85, offset + 85 + length), call.data);
                    offset += 85 + length;
                }
                assert.equal(offset, ethers.utils.hexDataLength(packed));
            }
            total++;
        }
    }
    assert.equal(total, 70);
    assert.equal(helpers.size, 8);
});

test('native bundles flatten consecutive original calls without changing bytes, mint order or Safe authority', () => {
    const parts = plans[1].slice(0, 2).flatMap((original, chunk) => partitionPlan(original).map(plan =>
        buildBatch({ plan, artifact, profile: 'mainnets', chainId: 1, safe: SAFE,
            hook: HOOK, resolver: RESOLVER, chunk: chunk + 1 })));
    parts.forEach((part, index) => { part.safeTransaction.order = index + 2; });
    // A previously bound source must not leak its old hash or nonce into the new bundle.
    parts[0].safeTransaction.transaction.nonce = '18';
    parts[0].safeTransaction.safeTxHash = ethers.utils.id('old source hash');
    parts[0].safeTransaction.approveHashTransaction = { data: '0x1234' };
    const original = JSON.stringify(parts);
    const bundled = combineMigrationBatches(parts, { order: 2 });
    assert.equal(JSON.stringify(parts), original, 'Bundling modified source files.');
    assert.deepEqual(bundled.batch.transactions, parts.flatMap(part => part.batch.transactions));
    assert.deepEqual(bundled.safeTransaction.expectedTokenIds, parts.flatMap(part => part.safeTransaction.expectedTokenIds));
    assert.deepEqual(bundled.safeTransaction.components, parts.map(part => part.safeTransaction));
    assert.equal(bundled.safeTransaction.transaction.nonce, null);
    assert.equal(bundled.safeTransaction.safeTxHash, undefined);
    assert.equal(bundled.safeTransaction.approveHashTransaction, undefined);
    assert.equal(bundled.safeTransaction.safe, SAFE);
    assert.equal(bundled.safeTransaction.transaction.to, MULTISEND);
    assert.equal(bundled.safeTransaction.transaction.operation, 1);
    const packedParts = parts.map(part => multisend.decodeFunctionData('multiSend', part.safeTransaction.transaction.data)[0]);
    assert.equal(multisend.decodeFunctionData('multiSend', bundled.safeTransaction.transaction.data)[0], ethers.utils.hexConcat(packedParts));
    for (const field of ['value', 'safeTxGas', 'baseGas', 'gasPrice']) assert.equal(bundled.safeTransaction.transaction[field], '0');
    for (const field of ['gasToken', 'refundReceiver']) assert.equal(bundled.safeTransaction.transaction[field], generator.ZERO_ADDRESS);
    assert.deepEqual(combineMigrationBatches([parts[0]]).safeTransaction.transaction,
        { ...parts[0].safeTransaction.transaction, nonce: null });

    assert.throws(() => combineMigrationBatches([]), /at least one/);
    assert.throws(() => combineMigrationBatches([parts[0].setup]), /original migration/);
    assert.throws(() => combineMigrationBatches([bundled]), /nested bundles/);
    assert.throws(() => combineMigrationBatches([parts[1], parts[0]]), /consecutive/);
    assert.throws(() => combineMigrationBatches([parts[0], parts[2]]), /consecutive/);
    for (const field of ['chainId', 'sourceChainId', 'safe', 'hook', 'resolver', 'helper', 'implementation']) {
        const changed = structuredClone(parts);
        changed[1].safeTransaction[field] = field.endsWith('Id') ? '123' : PERMISSIONS;
        assert.throws(() => combineMigrationBatches(changed), /different/);
    }
    for (const change of [
        p => { p[1].batch.transactions[0].data = '0x1234'; },
        p => { p[1].safeTransaction.transaction.data = '0x1234'; },
        p => { p[1].safeTransaction.transaction.safeTxGas = '1'; },
        p => { p[1].batch.transactions[0].value = '1'; },
        p => { p[1].batch.transactions[0].operation = 1; },
        p => { p[1].safeTransaction.expectedTokenIds[0] = p[0].safeTransaction.expectedTokenIds[0]; },
    ]) {
        const changed = structuredClone(parts);
        change(changed);
        assert.throws(() => combineMigrationBatches(changed), /differ|zero-value|repeats/);
    }
});

test('invalid destinations and profiles cannot produce a batch', () => {
    const input = { plan: plans[1][0], artifact, profile: 'testnets', chainId: 11155111, safe: SAFE,
        hook: HOOK, resolver: RESOLVER, chunk: 1 };
    for (const profile of [undefined, '', 'mainnet', 'toString', '__proto__']) {
        assert.throws(() => buildBatch({ ...input, profile }), /Choose --profile/);
    }
    assert.throws(() => networksFor('mainnets', 11155111), /not in mainnets/);
    assert.throws(() => buildBatch({ ...input, chainId: 84532 }), /does not match/);
    for (const field of ['safe', 'hook', 'resolver']) {
        assert.throws(() => buildBatch({ ...input, [field]: generator.ZERO_ADDRESS }), /Invalid/);
        assert.throws(() => buildBatch({ ...input, [field]: 'broken' }), /Invalid/);
    }
    assert.throws(() => buildBatch({ ...input, profile: 'mainnets', chainId: 1, hook: RESOLVER }), /Unexpected mainnet/);
    assert.throws(() => buildBatch({ ...input, artifact: { ...artifact, bytecode: { object: `0x${'00'.repeat(49153)}` } } }), /initcode limit/);
});

test('missing artifacts, changed generated plans and changed compiled inputs fail closed', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-safe-artifact-'));
    const plan = plans[1][0];
    const source = `script/${plan.fileName}`;
    const sourceText = generator.generateAirdropContract(plan);
    const file = path.join(root, 'out', plan.fileName, `${plan.contractName}.json`);
    try {
        assert.throws(() => readArtifact(plan, root), /Missing.*forge build/);
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.mkdirSync(path.join(root, 'script'));
        fs.writeFileSync(path.join(root, source), sourceText);
        const fixture = { ...artifact, metadata: {
            settings: { compilationTarget: { [source]: plan.contractName } },
            sources: { [source]: { keccak256: ethers.utils.id(sourceText) } },
        } };
        fs.writeFileSync(file, JSON.stringify(fixture));
        assert.deepEqual(readArtifact(plan, root), fixture);
        fs.appendFileSync(path.join(root, source), '\n// drift');
        assert.throws(() => readArtifact(plan, root), /Stale generated/);
        fs.writeFileSync(path.join(root, source), sourceText);
        fixture.metadata.sources[source].keccak256 = ethers.constants.HashZero;
        fs.writeFileSync(file, JSON.stringify(fixture));
        assert.throws(() => readArtifact(plan, root), /Stale.*artifact/);
        fixture.metadata.sources[source].keccak256 = ethers.utils.id(sourceText);
        fixture.deployedBytecode = { object: `0x${'00'.repeat(24577)}` };
        fs.writeFileSync(file, JSON.stringify(fixture));
        assert.throws(() => readArtifact(plan, root), /EIP-170/);
    } finally {
        fs.rmSync(root, { recursive: true, force: true });
    }
});

test('recipient-only snapshot drift is rejected even when helper Solidity is unchanged', () => {
    const items = generator.loadRawItems();
    const original = generator.buildContractsByChain(items);
    assertGeneratedSnapshot(original, items);
    const changed = generator.buildContractsByChain(items);
    changed[1][0].transferItems[0].owner = RESOLVER;
    assert.equal(generator.generateAirdropContract(original[1][0]), generator.generateAirdropContract(changed[1][0]));
    assert.throws(() => assertGeneratedSnapshot(changed, items), /Stale generated airdrop snapshot/);
});

function mockProvider({ chainId = 11155111, owner = SAFE, authorized = false, missingCode, factoryCode,
    resolverOwner = SAFE, configurator = SAFE, writer = RESOLVER, resolverForwarder = FORWARDER, oldResolver = false,
    owners = [SAFE], threshold = 1, nonce = 17, approvedOwners = [], executorSafe = SAFE, implementation = STORE, codeOverrides = {} } = {}) {
    const provider = new ethers.providers.StaticJsonRpcProvider(undefined, { chainId: 11155111, name: 'fixture' });
    const reads = new ethers.utils.Interface([
        'function getThreshold() view returns(uint256)', 'function getOwners() view returns(address[])',
        'function owner() view returns(address)', 'function STORE() view returns(address)',
        'function projectId() view returns(uint256)', 'function PERMISSIONS() view returns(address)',
        'function tokenUriResolverOf(address) view returns(address)',
        'function SVG_STORAGE() view returns(address)', 'function trustedForwarder() view returns(address)',
        'function CONFIGURATOR() view returns(address)', 'function writer() view returns(address)',
        'function hasPermission(address,address,uint256,uint256,bool,bool) view returns(bool)',
        'function nonce() view returns(uint256)',
        'function approvedHashes(address,bytes32) view returns(uint256)',
        'function SAFE() view returns(address)', 'function IMPLEMENTATION() view returns(address)',
        'function getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256) view returns(bytes32)',
    ]);
    const codes = {
        [FACTORY.toLowerCase()]: factoryCode || '0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3',
        [MULTISEND.toLowerCase()]: MultiSendCallOnlyArtifact.deployedBytecode,
        [RESOLVER.toLowerCase()]: resolverRuntime, [SVG_STORAGE.toLowerCase()]: storageRuntime,
        ...Object.fromEntries(Object.entries(codeOverrides).map(([address, code]) => [address.toLowerCase(), code])),
    };
    provider.send = async (method, params) => {
        if (method === 'eth_chainId') return ethers.utils.hexValue(chainId);
        if (method === 'eth_getCode') return params[0].toLowerCase() === missingCode?.toLowerCase() ? '0x' : codes[params[0].toLowerCase()] || '0x01';
        assert.equal(method, 'eth_call');
        const call = reads.parseTransaction(params[0]);
        if (oldResolver && call.name === 'SVG_STORAGE') return '0x';
        const results = { SVG_STORAGE, trustedForwarder: params[0].to.toLowerCase() === RESOLVER.toLowerCase() ? resolverForwarder : FORWARDER, CONFIGURATOR: configurator, writer, getThreshold: threshold, getOwners: owners, nonce, owner: params[0].to.toLowerCase() === RESOLVER.toLowerCase() ? resolverOwner : owner, STORE, projectId: 69, PERMISSIONS,
            tokenUriResolverOf: RESOLVER, hasPermission: authorized, SAFE: executorSafe, IMPLEMENTATION: implementation };
        if (call.name === 'hasPermission') {
            assert.deepEqual(call.args.slice(0, 2), [SAFE, owner]);
            assert.deepEqual(call.args.slice(2).map(value => value.toString()), ['69', '26', 'true', 'true']);
        }
        if (call.name === 'getTransactionHash') return reads.encodeFunctionResult(call.name, [ethers.utils.keccak256(params[0].data)]);
        if (call.name === 'approvedHashes') return reads.encodeFunctionResult(call.name, [
            approvedOwners.some(owner => owner.toLowerCase() === call.args[0].toLowerCase()) ? 1 : 0,
        ]);
        return reads.encodeFunctionResult(call.name, [results[call.name]]);
    };
    return provider;
}

function chainPreparationFixture(network, profile) {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-safe-prepare-'));
    for (const entry of ['src', 'out', 'foundry.toml', 'node_modules']) {
        fs.cpSync(path.join(identityRoot, entry), path.join(root, entry), { recursive: true });
    }
    const deployments = path.join(root, 'deployments');
    const helperPlan = helperPlans[network.sourceChainId][0];
    const source = `script/${helperPlan.fileName}`;
    const sourceText = generator.generateAirdropContract(helperPlan);
    const compiled = { ...artifact, metadata: {
        settings: { compilationTarget: { [source]: helperPlan.contractName } },
        sources: { [source]: { keccak256: ethers.utils.id(sourceText) } },
    } };
    const write = (filename, contents) => {
        fs.mkdirSync(path.dirname(filename), { recursive: true });
        fs.writeFileSync(filename, contents);
    };
    write(path.join(root, source), sourceText);
    write(path.join(root, 'out', path.basename(source), `${helperPlan.contractName}.json`), JSON.stringify(compiled));
    write(path.join(deployments, network.folder, 'JB721TiersHook__ProjectBAN.json'), JSON.stringify({ address: HOOK }));
    const first = buildExport({ plan: partitionPlan(plans[network.sourceChainId][0])[0], helperPlan,
        artifact: compiled, executorArtifact, profile, chainId: network.chainId, safe: SAFE,
        hook: HOOK, resolver: RESOLVER, chunk: 1 });
    const { helper, implementation } = first.safeTransaction;
    const provider = mockProvider({ chainId: network.chainId, implementation,
        codeOverrides: { [helper]: '0x', [implementation]: '0x' } });
    return { root, first, provider, input: { network, profile, safe: SAFE, provider, root, deployments,
        plans, helperPlans, executorArtifact } };
}

test('canonical chain preparation preserves all eight ordered exports and byte fixtures', async () => {
    // Captured from the pre-extraction CLI using these RPC/artifact fixtures.
    const originalDigests = {
        1: '0x15fc63a36859bb8889a8ba5456ff694c239b1a67d829fedf0f005247fe2412d5',
        10: '0x82604401c75afd98c596de85d186bbf255a7d8eb86281a797cab927149f6dbb0',
        8453: '0xa67f8ec8b7df634220732588ae313fcb8bd76fdb3670efd3c8492870b9155c76',
        42161: '0xbfdb5e76e5161c84a5ea0f9332015d9d7359c15f5f3a4d60f4b4254c9d8e0949',
        11155111: '0x660d2c198d3b65d09ff52b973cdc9da579d525fe81e20161f0bf95d281b4f2f0',
        11155420: '0xb7822aef1e20f765dc602a7aa47d44e7bdf129bbb58655b21e7ef5d7cd5ff7ed',
        84532: '0x2714a007132d6003644f6a43bbe25aa30622347c5fe36dae1ba5710d8e0f23c5',
        421614: '0x00c11066beeed162cf02af2705fbc1324a887a1d44926c1949935b82beb50cea',
    };
    for (const [profile, networks] of Object.entries(NETWORKS)) for (const network of networks) {
        const fixture = chainPreparationFixture(network, profile);
        try {
            const { chain, batches } = await prepareChain(fixture.input);
            const expectedCount = { 1: 18, 10: 1, 8453: 8, 42161: 8 }[network.sourceChainId];
            assert.equal(batches.length, expectedCount + 1);
            assert.equal(batches[0].safeTransaction.stage, 'setup');
            assert.equal(batches[0].batch.transactions.length, 2);
            assert.deepEqual(batches.map(part => part.safeTransaction.order), batches.map((_, index) => index + 1));
            assert.deepEqual(batches.slice(1).flatMap(part => part.safeTransaction.expectedTokenIds).sort((a, b) => a - b),
                plans[network.sourceChainId].flatMap(plan => plan.assignments.expectedTokenIds).sort((a, b) => a - b));
            const files = Object.fromEntries(batches.flatMap(part => [
                [part.builderFile, `${JSON.stringify(part.batch, null, 2)}\n`],
                [part.safeTransactionFile, `${JSON.stringify(part.safeTransaction, null, 2)}\n`],
            ]));
            files['manifest.json'] = `${JSON.stringify({ profile, safe: SAFE, status: 'prepared; not signed or submitted', chains: [chain] }, null, 2)}\n`;
            const digest = ethers.utils.id(JSON.stringify(files));
            assert.equal(digest, originalDigests[network.chainId]);
        } finally { fs.rmSync(fixture.root, { recursive: true, force: true }); }
    }
});

test('chain preparation preserves partial setup omission, runtime checks and nonce binding', async () => {
    const fixture = chainPreparationFixture(NETWORKS.mainnets[1], 'mainnets');
    try {
        const { helper, implementation } = fixture.first.safeTransaction;
        for (const present of [[false, false], [true, false], [false, true], [true, true]]) {
            const provider = mockProvider({ chainId: 10, implementation, nonce: 17, codeOverrides: {
                [implementation]: present[0] ? artifact.deployedBytecode.object : '0x',
                [helper]: present[1] ? executorArtifact.deployedBytecode.object : '0x',
            } });
            const result = await prepareChain({ ...fixture.input, provider, startNonce: '17' });
            const missingCalls = fixture.first.setup.batch.transactions.filter((_, index) => !present[index]);
            const setup = result.batches.find(part => part.safeTransaction.stage === 'setup');
            if (missingCalls.length) {
                assert.deepEqual(setup.batch.transactions, missingCalls);
                assert.equal(setup.safeTransaction.transaction.operation, missingCalls.length === 1 ? 0 : 1);
            } else assert.equal(setup, undefined);
            for (const [index, part] of result.batches.entries()) {
                assert.equal(part.safeTransaction.transaction.nonce, String(17 + index));
                assert.equal(part.safeTransaction.safeTxHash,
                    (await bindNonce(part.safeTransaction, 17 + index, provider)).safeTxHash);
                assert.equal(part.safeTransaction.order, index + 1);
            }
        }
        await assert.rejects(prepareChain({ ...fixture.input, startNonce: '16' }), /already executed/);
        await assert.rejects(prepareChain({ ...fixture.input, provider: mockProvider({ chainId: 10,
            codeOverrides: { [implementation]: '0x1234', [helper]: '0x' } }) }), /bytecode does not match/);
        await assert.rejects(prepareChain({ ...fixture.input, provider: mockProvider({ chainId: 10,
            implementation, executorSafe: RESOLVER,
            codeOverrides: { [implementation]: '0x', [helper]: executorArtifact.deployedBytecode.object } }) }), /different Safe or implementation/);
    } finally { fs.rmSync(fixture.root, { recursive: true, force: true }); }
});

test('preflight checks destination RPC, deployed infrastructure and owner/operator authority', async () => {
    const input = { network: NETWORKS.testnets[0], safe: SAFE, hook: HOOK, root: identityRoot };
    assert.equal((await preflight({ ...input, provider: mockProvider() })).resolver, RESOLVER);
    assert.equal((await preflight({ ...input, provider: mockProvider({ owner: RESOLVER, authorized: true }) })).threshold, '1');
    await assert.rejects(preflight({ ...input, provider: mockProvider({ owner: RESOLVER }) }), /neither hook owner nor authorized/);
    await assert.rejects(preflight({ ...input, provider: mockProvider({ chainId: 1 }) }), /RPC chain mismatch/);
    await assert.rejects(preflight({ ...input, provider: mockProvider({ factoryCode: '0x00' }) }), /Unexpected deterministic/);
    for (const missingCode of [FACTORY, MULTISEND, SAFE, HOOK, RESOLVER, SVG_STORAGE]) {
        await assert.rejects(preflight({ ...input, provider: mockProvider({ missingCode }) }), /No deployed contract|Resolver is not deployed|SVG storage is not deployed/);
    }
});

test('shared distribution preflight rejects old resolvers, unsafe bindings and executable drift', async () => {
    const input = { network: NETWORKS.testnets[0], safe: SAFE, hook: HOOK, root: identityRoot };
    await assert.rejects(preflight({ ...input, provider: mockProvider({ oldResolver: true }) }), /Replacement resolver is not active/);
    await assert.rejects(preflight({ ...input, provider: mockProvider({ writer: HOOK }) }), /writer is not active resolver/);
    await assert.rejects(preflight({ ...input, provider: mockProvider({ configurator: HOOK }) }), /not SVG storage configurator/);
    await assert.rejects(preflight({ ...input, provider: mockProvider({ resolverOwner: HOOK }) }), /not replacement resolver owner/);
    // A genuine clone's getter agrees with its malicious immutable: runtime self-consistency alone is insufficient.
    await assert.rejects(preflight({ ...input, provider: mockProvider({ resolverForwarder: HOOK,
        codeOverrides: { [RESOLVER]: fixtureRuntime(resolverArtifact, { [identityIds.forwarder]: HOOK, [identityIds.storage]: SVG_STORAGE }) },
    }) }), /trusted forwarder differs from hook/);
    for (const [target, code, message] of [
        [RESOLVER, `${resolverRuntime.slice(0, -2)}00`, /resolver runtime/],
        [SVG_STORAGE, `${storageRuntime.slice(0, -2)}00`, /storage runtime/],
        [RESOLVER, fixtureRuntime(resolverArtifact, { [identityIds.forwarder]: HOOK, [identityIds.storage]: SVG_STORAGE }), /resolver runtime/],
        [SVG_STORAGE, fixtureRuntime(storageArtifact, { [identityIds.configurator]: HOOK }), /storage runtime/],
    ]) await assert.rejects(preflight({ ...input, provider: mockProvider({ codeOverrides: { [target]: code } }) }), message);
    assert.equal((await preflight({ ...input, provider: mockProvider() })).resolver, RESOLVER);
});

test('shared distribution preflight requires fresh resolver and storage build inputs', async () => {
    const fixture = chainPreparationFixture(NETWORKS.mainnets[1], 'mainnets');
    try {
        const storageSource = path.join(fixture.root, 'src/BannySvgStorage.sol');
        fs.appendFileSync(storageSource, '\n// source drift\n');
        // The typed storage import makes its source part of the resolver compilation too.
        await assert.rejects(prepareChain(fixture.input), /Stale Banny721TokenUriResolver artifact: src\/BannySvgStorage\.sol changed/);
        fs.rmSync(path.join(fixture.root, 'out/Banny721TokenUriResolver.sol/Banny721TokenUriResolver.json'));
        await assert.rejects(prepareChain(fixture.input), /Missing .*Banny721TokenUriResolver.*run forge build/);
    } finally { fs.rmSync(fixture.root, { recursive: true, force: true }); }
});

test('resume omits deployed setup only after runtime and immutable authority validation', async () => {
    assert.equal(needsSetup('0x', artifact), true);
    assert.equal(needsSetup(artifact.deployedBytecode.object, artifact), false);
    assert.throws(() => needsSetup('0x01', artifact), /bytecode does not match/);
    const compiled = { deployedBytecode: { object: `0x60${'00'.repeat(64)}61`,
        immutableReferences: { safe: [{ start: 1, length: 32 }], implementation: [{ start: 33, length: 32 }] } } };
    const deployed = `0x60${ethers.utils.hexZeroPad(SAFE, 32).slice(2)}${ethers.utils.hexZeroPad(STORE, 32).slice(2)}61`;
    const check = (code, provider = mockProvider()) => executorNeedsSetup(code, compiled, SAFE, STORE, PERMISSIONS, provider);
    assert.equal(await check('0x'), true);
    assert.equal(await check(deployed), false);
    await assert.rejects(check(`${deployed.slice(0, -2)}62`), /bytecode does not match/);
    await assert.rejects(check(deployed, mockProvider({ executorSafe: RESOLVER })), /different Safe or implementation/);
    await assert.rejects(check(deployed, mockProvider({ implementation: RESOLVER })), /different Safe or implementation/);
});

test('explicit nonce binds approval calldata to the same Safe transaction and hash', async () => {
    const { safeTransaction } = buildBatch({ plan: plans[1][0], artifact, profile: 'testnets', chainId: 11155111,
        safe: SAFE, hook: HOOK, resolver: RESOLVER, chunk: 1 });
    const bound = await bindNonce(safeTransaction, 17, mockProvider());
    const next = await bindNonce(safeTransaction, 18, mockProvider());
    assert.equal(bound.transaction.nonce, '17');
    assert.notEqual(bound.safeTxHash, next.safeTxHash);
    assert.equal(safeTransaction.transaction.nonce, null);
    assert.equal(bound.approveHashTransaction.to, SAFE);
    const iface = new ethers.utils.Interface(['function approveHash(bytes32)']);
    assert.equal(iface.decodeFunctionData('approveHash', bound.approveHashTransaction.data)[0], bound.safeTxHash);
});

test('approved execution requires the bound current nonce and unchanged hash', async () => {
    const { safeTransaction } = buildBatch({ plan: plans[1][0], artifact, profile: 'testnets', chainId: 11155111,
        safe: SAFE, hook: HOOK, resolver: RESOLVER, chunk: 1 });
    const provider = mockProvider({ approvedOwners: [SAFE] });
    const bound = await bindNonce(safeTransaction, 17, provider);
    await assert.rejects(prepareApprovedExecution(safeTransaction, provider), /nonce-bound/);
    await assert.rejects(prepareApprovedExecution(bound, mockProvider({ chainId: 1 })), /RPC chain mismatch/);
    await assert.rejects(prepareApprovedExecution(bound, mockProvider({ nonce: 18 })), /nonce does not match/);
    await assert.rejects(prepareApprovedExecution({ ...bound, safeTxHash: ethers.constants.HashZero }, provider), /hash mismatch/);
    await assert.rejects(prepareApprovedExecution({ ...bound, transaction: { ...bound.transaction, data: '0x1234' } }, provider), /hash mismatch/);
    await assert.rejects(prepareApprovedExecution(bound, mockProvider()), /Only 0\/1/);
});

test('approved execution gates signed migrations and unsigned stage relabeling on the active replacement', async () => {
    const { safeTransaction, setup } = buildBatch({ plan: plans[1][0], artifact, profile: 'testnets', chainId: 11155111,
        safe: SAFE, hook: HOOK, resolver: RESOLVER, chunk: 1 });
    const provider = mockProvider({ approvedOwners: [SAFE] });
    const bound = await bindNonce(safeTransaction, 17, provider);
    for (const stage of ['migration', 'setup', undefined]) {
        const relabeled = { ...bound, stage };
        await assert.rejects(prepareApprovedExecution(relabeled, mockProvider({ approvedOwners: [SAFE], oldResolver: true }),
            identityOptions), /Replacement resolver is not active/);
        await assert.rejects(prepareApprovedExecution(relabeled, mockProvider({ approvedOwners: [SAFE], writer: HOOK }),
            identityOptions), /writer is not active resolver/);
    }
    await assert.rejects(prepareApprovedExecution({ ...bound, resolver: HOOK }, provider, identityOptions),
        /proposal resolver differs from active replacement/);
    await assert.rejects(prepareApprovedExecution({ ...bound, hook: STORE }, provider, identityOptions),
        /Proposal hook differs from canonical hook/);
    const oldResolver = HOOK;
    const old = buildBatch({ plan: plans[1][0], artifact, profile: 'testnets', chainId: 11155111,
        safe: SAFE, hook: HOOK, resolver: oldResolver, chunk: 1 }).safeTransaction;
    const oldBound = await bindNonce(old, 17, provider);
    await assert.rejects(prepareApprovedExecution({ ...oldBound, resolver: RESOLVER, stage: 'setup' }, provider, identityOptions),
        /Signed decoration resolver differs from active replacement/);
    const execution = await prepareApprovedExecution(bound, provider, identityOptions);
    assert.equal(execution.safeTxHash, bound.safeTxHash);
    const setupBound = await bindNonce(setup.safeTransaction, 17, provider);
    assert.equal((await prepareApprovedExecution(setupBound, provider, identityOptions)).safeTxHash, setupBound.safeTxHash);
});

test('execution uses current approved owners, sorted signatures and every exact approved transaction field', async () => {
    const { safeTransaction } = buildBatch({ plan: plans[1][0], artifact, profile: 'testnets', chainId: 11155111,
        safe: SAFE, hook: HOOK, resolver: RESOLVER, chunk: 1 });
    // Distinct nonzero field values expose any accidental omission or replacement during encoding.
    safeTransaction.transaction = { ...safeTransaction.transaction, value: '123', safeTxGas: '456', baseGas: '789',
        gasPrice: '42', gasToken: STORE, refundReceiver: RESOLVER };
    const provider = mockProvider({ owners: [SAFE, STORE, RESOLVER], threshold: 2,
        approvedOwners: [SAFE, RESOLVER, PERMISSIONS] });
    const bound = await bindNonce(safeTransaction, 17, provider);
    await assert.rejects(prepareApprovedExecution(bound, mockProvider({ owners: [SAFE, STORE, RESOLVER],
        threshold: 2, approvedOwners: [RESOLVER, PERMISSIONS] })), /Only 1\/2/);
    const execution = await prepareApprovedExecution(bound, provider, identityOptions);
    assert.deepEqual(execution.approvingOwners, [RESOLVER, SAFE]);
    assert.equal(execution.safeTxHash, bound.safeTxHash);
    assert.equal(execution.nonce, '17');
    assert.equal(execution.transaction.to, SAFE);
    assert.equal(execution.transaction.value, '0');
    const iface = new ethers.utils.Interface([
        'function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)',
    ]);
    const decoded = iface.decodeFunctionData('execTransaction', execution.transaction.data);
    assert.deepEqual(decoded.slice(0, 9).map(value => value.toString()),
        SAFE_TRANSACTION_FIELDS.map(field => bound.transaction[field].toString()));
    const signatures = decoded[9];
    assert.equal(ethers.utils.hexDataLength(signatures), 130);
    for (const [index, owner] of execution.approvingOwners.entries()) {
        const offset = index * 65;
        assert.equal(ethers.utils.getAddress(ethers.utils.hexDataSlice(signatures, offset + 12, offset + 32)), owner);
        assert.equal(ethers.utils.hexDataSlice(signatures, offset + 32, offset + 64), ethers.constants.HashZero);
        assert.equal(ethers.utils.hexDataSlice(signatures, offset + 64, offset + 65), '0x01');
    }
    assert.deepEqual(encodeApprovedExecution(bound, [SAFE, RESOLVER]), execution.transaction);
    assert.throws(() => encodeApprovedExecution(bound, [SAFE, SAFE.toLowerCase()]), /distinct approving owners/);
});

test('exports are reproducible and conflicting destinations fail before any new file is written', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-safe-output-'));
    try {
        const first = path.join(root, 'first.json');
        const second = path.join(root, 'second.json');
        writeExports(new Map([[first, 'original\n']]));
        writeExports(new Map([[first, 'original\n']]));
        assert.throws(() => writeExports(new Map([[second, 'new\n'], [first, 'changed\n']])), /Refusing to overwrite/);
        assert.equal(fs.readFileSync(first, 'utf8'), 'original\n');
        assert(!fs.existsSync(second));
    } finally {
        fs.rmSync(root, { recursive: true, force: true });
    }
});
