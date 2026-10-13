#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const { parseArgs } = require('node:util');
const { ethers } = require('ethers');
const { runtimeHash, immutableIds } = require('./prepare-resolver-upgrade');
const {
    DETERMINISTIC_DEPLOYMENT_PROXY_ADDRESS: FACTORY,
    MultiSendCallOnlyArtifact,
    getMultiSendCallOnlyAddress,
    getGnosisSafeProxyAddress,
} = require('@sphinx-labs/contracts');
const {
    buildContractsByChain,
    buildCombinedContractsByChain,
    bannyTargetTokenId,
    bannyBackgroundTokenId,
    bannyOutfitData,
    transferTokenIds,
    transferAllowResolverOwners,
    itemTokenId,
    loadRawItems,
    generateAirdropContract,
    generateCoverageReport,
    generateTopLevelScript,
    V6_MAINNET_HOOK,
    V4_HOOK,
    V4_RESOLVER,
    V4_RESOLVER_FALLBACK,
    ZERO_ADDRESS,
} = require('./generate-v6-airdrop');

const ROOT = path.resolve(__dirname, '../..');
const MULTISEND = getMultiSendCallOnlyAddress();
// Runtime of the canonical Arachnid deterministic deployment proxy used by Sphinx.
const FACTORY_CODE = '0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3';
const NETWORKS = {
    mainnets: [
        { chainId: 1, sourceChainId: 1, folder: 'ethereum', rpc: 'RPC_ETHEREUM_MAINNET' },
        { chainId: 10, sourceChainId: 10, folder: 'optimism', rpc: 'RPC_OPTIMISM_MAINNET' },
        { chainId: 8453, sourceChainId: 8453, folder: 'base', rpc: 'RPC_BASE_MAINNET' },
        { chainId: 42161, sourceChainId: 42161, folder: 'arbitrum', rpc: 'RPC_ARBITRUM_MAINNET' },
    ],
    testnets: [
        { chainId: 11155111, sourceChainId: 1, folder: 'sepolia', rpc: 'RPC_ETHEREUM_SEPOLIA' },
        { chainId: 11155420, sourceChainId: 10, folder: 'optimism_sepolia', rpc: 'RPC_OPTIMISM_SEPOLIA' },
        { chainId: 84532, sourceChainId: 8453, folder: 'base_sepolia', rpc: 'RPC_BASE_SEPOLIA' },
        { chainId: 421614, sourceChainId: 42161, folder: 'arbitrum_sepolia', rpc: 'RPC_ARBITRUM_SEPOLIA' },
    ],
};
const HOOK_INTERFACE = new ethers.utils.Interface(['function mintFor(uint16[] tierIds,address beneficiary)']);
const MAX_MINTS_PER_TRANSACTION = 40;
const MULTISEND_INTERFACE = new ethers.utils.Interface(MultiSendCallOnlyArtifact.abi);
const SAFE_TRANSACTION_FIELDS = ['to', 'value', 'data', 'operation', 'safeTxGas', 'baseGas', 'gasPrice', 'gasToken', 'refundReceiver'];
const SAFE_INTERFACE = new ethers.utils.Interface([
    'function getOwners() view returns(address[])',
    'function getThreshold() view returns(uint256)',
    'function nonce() view returns(uint256)',
    'function approvedHashes(address,bytes32) view returns(uint256)',
    'function getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256) view returns(bytes32)',
    'function approveHash(bytes32)',
    'function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)',
]);

function address(value, label) {
    if (!ethers.utils.isAddress(value) || value.toLowerCase() === ZERO_ADDRESS) {
        throw new Error(`Invalid ${label} address`);
    }
    return ethers.utils.getAddress(value);
}

function networksFor(profile, chainId) {
    if (!Object.hasOwn(NETWORKS, profile)) throw new Error('Choose --profile mainnets or testnets');
    const networks = NETWORKS[profile].filter(network => chainId === undefined || String(network.chainId) === String(chainId));
    if (!networks.length) throw new Error(`Chain ${chainId} is not in ${profile}`);
    return networks;
}

function readArtifact(plan, root = ROOT, sourceHashes = new Map()) {
    const source = `script/${plan.fileName}`;
    if (fs.existsSync(path.join(root, source)) && fs.readFileSync(path.join(root, source), 'utf8') !== generateAirdropContract(plan)) {
        throw new Error(`Stale generated ${plan.fileName}; run npm run generate:airdrop and forge build`);
    }
    return readCompiledArtifact(plan.contractName, source, root, sourceHashes);
}

function readCompiledArtifact(contractName, source, root = ROOT, sourceHashes = new Map()) {
    const filename = path.join(root, 'out', path.basename(source), `${contractName}.json`);
    if (!fs.existsSync(filename)) throw new Error(`Missing ${filename}; run forge build first`);
    const artifact = JSON.parse(fs.readFileSync(filename, 'utf8'));
    const metadata = artifact.metadata || JSON.parse(artifact.rawMetadata || '{}');
    if (metadata.settings?.compilationTarget?.[source] !== contractName || !metadata.sources?.[source]) {
        throw new Error(`Invalid compilation metadata for ${contractName}; run forge build`);
    }
    // Check all compiled inputs, including imports; timestamps cannot prove bytecode freshness.
    for (const [input, record] of Object.entries(metadata.sources)) {
        if (!sourceHashes.has(input)) {
            sourceHashes.set(input, ethers.utils.keccak256(fs.readFileSync(path.resolve(root, input))));
        }
        if (sourceHashes.get(input) !== record.keccak256) {
            throw new Error(`Stale ${contractName} artifact: ${input} changed; regenerate and run forge build`);
        }
    }
    const bytecode = artifact.bytecode?.object;
    const runtime = artifact.deployedBytecode?.object;
    if (!/^0x(?:[0-9a-fA-F]{2})+$/.test(bytecode || '') || !/^0x(?:[0-9a-fA-F]{2})+$/.test(runtime || '')) {
        throw new Error(`Missing or unlinked bytecode for ${contractName}; run forge build`);
    }
    if (ethers.utils.hexDataLength(runtime) > 24576) throw new Error(`${contractName} exceeds EIP-170 size limit`);
    return artifact;
}

function assertGeneratedSnapshot(plans, items, root = ROOT) {
    // Recipient addresses live in the top-level script, not in the helper's compiled source.
    const expected = generateTopLevelScript(plans, generateCoverageReport(plans, items));
    if (fs.readFileSync(path.join(root, 'script/AirdropV4Bannys.s.sol'), 'utf8') !== expected) {
        throw new Error('Stale generated airdrop snapshot; run npm run generate:airdrop and forge build');
    }
}

function partitionPlan(plan) {
    // A body and everything it wears must migrate together. Original per-tier mint order adds dependencies
    // between these groups; strongly connected groups cannot be split without changing assigned token IDs.
    const groups = plan.bannies.map(banny => [banny.tokenId, ...banny.outfitIds,
        ...(banny.backgroundId ? [banny.backgroundId] : [])]);
    const groupOf = new Map();
    for (const [index, ids] of groups.entries()) for (const id of ids) {
        if (groupOf.has(id)) throw new Error('Asset appears in multiple body groups');
        if (!plan.assignments.v4ToV6TokenIds.has(id)) throw new Error('Body asset missing from original assignments');
        groupOf.set(id, index);
    }
    for (const id of plan.assignments.v4ToV6TokenIds.keys()) if (!groupOf.has(id)) {
        groupOf.set(id, groups.length);
        groups.push([id]);
    }
    const originalByTarget = new Map([...plan.assignments.v4ToV6TokenIds].map(([original, target]) => [target, original]));
    if (originalByTarget.size !== plan.assignments.expectedTokenIds.length) throw new Error('Duplicate original token assignments');
    const edges = groups.map(() => new Set());
    const previousByTier = new Map();
    plan.assignments.expectedTokenIds.forEach((target, index) => {
        const group = groupOf.get(originalByTarget.get(target));
        const tier = plan.assignments.tierIds[index];
        if (group === undefined) throw new Error('Missing original token assignment');
        if (previousByTier.has(tier) && previousByTier.get(tier) !== group) edges[previousByTier.get(tier)].add(group);
        previousByTier.set(tier, group);
    });
    const indices = new Map();
    const low = new Map();
    const stack = [];
    const onStack = new Set();
    const components = [];
    let nextIndex = 0;
    function visit(group) {
        indices.set(group, nextIndex);
        low.set(group, nextIndex++);
        stack.push(group);
        onStack.add(group);
        for (const next of edges[group]) {
            if (!indices.has(next)) {
                visit(next);
                low.set(group, Math.min(low.get(group), low.get(next)));
            } else if (onStack.has(next)) low.set(group, Math.min(low.get(group), indices.get(next)));
        }
        if (low.get(group) === indices.get(group)) {
            const component = [];
            let member;
            do {
                member = stack.pop();
                onStack.delete(member);
                component.push(member);
            } while (member !== group);
            components.push(component.sort((a, b) => a - b));
        }
    }
    groups.forEach((_, index) => { if (!indices.has(index)) visit(index); });
    const componentOf = new Map(components.flatMap((component, index) => component.map(group => [group, index])));
    const prerequisites = components.map(() => new Set());
    edges.forEach((targets, from) => targets.forEach(to => {
        if (componentOf.get(from) !== componentOf.get(to)) prerequisites[componentOf.get(to)].add(componentOf.get(from));
    }));
    const remaining = new Set(components.map((_, index) => index));
    const batches = [];
    let pending = [];
    let count = 0;
    while (remaining.size) {
        const ready = [...remaining].filter(index => [...prerequisites[index]].every(dependency => !remaining.has(dependency)))
            .sort((a, b) => components[a][0] - components[b][0]);
        if (!ready.length) throw new Error('Unresolved mint-order dependencies');
        const index = ready[0];
        const ids = components[index].flatMap(group => groups[group]);
        if (ids.length > MAX_MINTS_PER_TRANSACTION) throw new Error(`Indivisible body group has ${ids.length} tokens; exceeds verified slice limit`);
        if (count + ids.length > MAX_MINTS_PER_TRANSACTION) {
            batches.push(pending);
            pending = [];
            count = 0;
        }
        pending.push(ids);
        count += ids.length;
        remaining.delete(index);
    }
    if (pending.length) batches.push(pending);
    return batches.map((dependencyGroups, index) => {
        const included = new Set(dependencyGroups.flat());
        const mintIndices = plan.assignments.expectedTokenIds.map((target, index) => ({ target, index }))
            .filter(({ target }) => included.has(originalByTarget.get(target)));
        return {
            ...plan, slice: index + 1, dependencyGroups,
            bannies: plan.bannies.filter(banny => included.has(banny.tokenId)),
            allItems: plan.allItems.filter(item => included.has(itemTokenId(item))),
            transferItems: plan.transferItems.filter(entry => included.has(itemTokenId(entry.item))),
            assignments: {
                ...plan.assignments,
                tierIds: mintIndices.map(({ index }) => plan.assignments.tierIds[index]),
                expectedTokenIds: mintIndices.map(({ target }) => target),
                v4ToV6TokenIds: new Map([...plan.assignments.v4ToV6TokenIds].filter(([original]) => included.has(original))),
            },
        };
    });
}

function wrapBatch(transactions, metadata, name) {
    const packed = ethers.utils.hexConcat(transactions.map(tx => ethers.utils.solidityPack(
        ['uint8', 'address', 'uint256', 'uint256', 'bytes'],
        [0, tx.to, tx.value, ethers.utils.hexDataLength(tx.data), tx.data],
    )));
    return {
        batch: {
            version: '1.0', chainId: metadata.chainId, createdAt: 0,
            meta: { name, description: 'Execute files in order. Keep each migration batch atomic.', createdFromSafeAddress: metadata.safe },
            transactions,
        },
        safeTransaction: {
            ...metadata,
            transaction: {
                to: transactions.length === 1 ? transactions[0].to : MULTISEND,
                value: '0',
                data: transactions.length === 1 ? transactions[0].data : MULTISEND_INTERFACE.encodeFunctionData('multiSend', [packed]),
                operation: transactions.length === 1 ? 0 : 1,
                safeTxGas: '0', baseGas: '0', gasPrice: '0', gasToken: ZERO_ADDRESS, refundReceiver: ZERO_ADDRESS,
                nonce: null,
            },
        },
    };
}

function combineMigrationBatches(parts, { order, name } = {}) {
    if (!Array.isArray(parts) || !parts.length) throw new Error('A migration bundle needs at least one original batch');
    const first = parts[0].safeTransaction;
    const commonFields = ['chainId', 'sourceChainId', 'safe', 'hook', 'resolver', 'helper', 'implementation',
        'helperContractName', 'implementationContractName'];
    const ids = [];
    const transactions = [];
    for (const [index, part] of parts.entries()) {
        const envelope = part.safeTransaction;
        if (!envelope || envelope.stage !== 'migration' || envelope.components) {
            throw new Error('Bundle only original migration batches; setup and nested bundles are separate');
        }
        for (const field of commonFields) {
            if (envelope[field] === undefined || String(envelope[field]).toLowerCase() !== String(first[field]).toLowerCase()) {
                throw new Error(`Migration bundle has different ${field}`);
            }
        }
        if (!Number.isInteger(envelope.order) || envelope.order < 1 || envelope.order !== first.order + index) {
            throw new Error('Migration bundle source batches must be consecutive and ordered');
        }
        if (!Array.isArray(envelope.expectedTokenIds) || !envelope.expectedTokenIds.length
            || envelope.expectedTokenIds.some(id => !Number.isSafeInteger(id) || id < 1)) {
            throw new Error('Migration bundle source has invalid token IDs');
        }
        const batch = part.batch;
        if (!batch || String(batch.chainId) !== String(first.chainId)
            || batch.meta?.createdFromSafeAddress?.toLowerCase() !== first.safe.toLowerCase()
            || !Array.isArray(batch.transactions) || batch.transactions.length !== 2) {
            throw new Error('Migration bundle source Builder context differs from its envelope');
        }
        if (batch.transactions.some(tx => String(tx.value) !== '0' || tx.operation !== undefined && tx.operation !== 0)) {
            throw new Error('Migration bundle source calls must be zero-value CALLs');
        }
        const canonical = wrapBatch(batch.transactions, envelope, '').safeTransaction.transaction;
        for (const field of SAFE_TRANSACTION_FIELDS) {
            if (String(envelope.transaction?.[field]).toLowerCase() !== String(canonical[field]).toLowerCase()) {
                throw new Error(`Migration bundle source Builder and envelope differ: ${field}`);
            }
        }
        ids.push(...envelope.expectedTokenIds);
        transactions.push(...batch.transactions);
    }
    if (new Set(ids).size !== ids.length) throw new Error('Migration bundle repeats token IDs');
    const { transaction, safeTxHash, approveHashTransaction, ...metadata } = first;
    const bundleOrder = order ?? first.order;
    if (!Number.isInteger(bundleOrder) || bundleOrder < 1) throw new Error('Invalid migration bundle order');
    return wrapBatch(transactions, {
        ...metadata, order: bundleOrder, contractName: 'BannyAirdropBundle', chunk: null, slice: 0,
        expectedTokenIds: ids, components: parts.map(part => structuredClone(part.safeTransaction)),
    }, name || `Banny V4 airdrop: ${first.chainId} distribution batches ${first.order}-${parts.at(-1).safeTransaction.order}`);
}

function buildBatch({ plan, helperPlan, artifact, executorArtifact, profile, chainId, safe, hook, resolver, chunk, order = 1 }) {
    const network = networksFor(profile, chainId)[0];
    if (network.sourceChainId !== plan.chain.id) throw new Error('Plan does not match destination chain');
    safe = address(safe, 'Safe');
    hook = address(hook, 'hook');
    resolver = address(resolver, 'resolver');
    if (profile === 'mainnets' && hook !== V6_MAINNET_HOOK) throw new Error('Unexpected mainnet V6 hook');
    if (!Number.isInteger(chunk) || chunk < 1 || !plan.assignments.tierIds.length) throw new Error('Empty or invalid chunk');
    const owners = plan.transferItems.map(entry => address(entry.owner, 'recipient'));
    const initCode = new ethers.ContractFactory(artifact.abi, artifact.bytecode.object).getDeployTransaction().data;
    if (ethers.utils.hexDataLength(initCode) > 49152) throw new Error(`${plan.contractName} exceeds EIP-3860 initcode limit`);
    // Include context in the salt so another profile/Safe cannot reserve this helper address accidentally.
    const salt = ethers.utils.id(`banny-v4-safe-airdrop-v2:${chainId}:${safe}:${hook}:${helperPlan.contractName}`);
    const implementation = ethers.utils.getCreate2Address(FACTORY, salt, ethers.utils.keccak256(initCode));
    const executorInitCode = new ethers.ContractFactory(executorArtifact.abi, executorArtifact.bytecode.object)
        .getDeployTransaction(safe, implementation).data;
    if (ethers.utils.hexDataLength(executorInitCode) > 49152) throw new Error('SafeAirdropExecutor exceeds EIP-3860 initcode limit');
    const executorSalt = ethers.utils.id(`banny-v4-safe-airdrop-executor-v1:${chainId}:${safe}:${hook}:${implementation}`);
    const helper = ethers.utils.getCreate2Address(FACTORY, executorSalt, ethers.utils.keccak256(executorInitCode));
    const iface = new ethers.utils.Interface(artifact.abi);
    const common = [hook, V4_HOOK, V4_RESOLVER, V4_RESOLVER_FALLBACK, profile === 'mainnets'];
    const calls = [];
    if (plan.bannies.length) {
        const outfits = bannyOutfitData(plan);
        calls.push(iface.encodeFunctionData('decorateBannys', [
            hook, resolver, ...common.slice(1), plan.bannies.map(banny => banny.tokenId),
            plan.bannies.map(banny => bannyTargetTokenId(plan, banny)),
            plan.bannies.map(banny => bannyBackgroundTokenId(plan, banny)), outfits.offsets, outfits.tokenIds,
        ]));
    }
    calls.push(iface.encodeFunctionData('transferRegular', [
        ...common, owners, transferTokenIds(plan.transferItems, plan.assignments.v4ToV6TokenIds, true),
        transferTokenIds(plan.transferItems, plan.assignments.v4ToV6TokenIds, false), transferAllowResolverOwners(plan.transferItems),
    ]));
    calls.push(iface.encodeFunctionData('requireNoBalance', [hook]));
    const executorInterface = new ethers.utils.Interface(executorArtifact.abi);
    const transactions = [
        { to: hook, value: '0', data: HOOK_INTERFACE.encodeFunctionData('mintFor', [plan.assignments.tierIds, helper]) },
        { to: helper, value: '0', data: executorInterface.encodeFunctionData('execute', [calls]) },
    ];
    const metadata = { chainId: String(chainId), sourceChainId: plan.chain.id, safe, hook, resolver, helper, chunk,
        contractName: plan.contractName, helperContractName: 'SafeAirdropExecutor', implementation,
        implementationContractName: helperPlan.contractName,
        slice: plan.slice, expectedTokenIds: plan.assignments.expectedTokenIds, stage: 'migration', order };
    return {
        ...wrapBatch(transactions, metadata, `Banny V4 airdrop: ${network.folder} chunk ${chunk} slice ${plan.slice}`),
        setup: wrapBatch([
            { to: FACTORY, value: '0', data: ethers.utils.hexConcat([salt, initCode]) },
            { to: FACTORY, value: '0', data: ethers.utils.hexConcat([executorSalt, executorInitCode]) },
        ],
            { ...metadata, stage: 'setup', slice: 0, expectedTokenIds: [], order: 1 }, `Banny V4 airdrop: ${network.folder} helper setup`),
    };
}

function needsSetup(code, artifact) {
    if (code === '0x') return true;
    if (code.toLowerCase() !== artifact.deployedBytecode.object.toLowerCase()) throw new Error('Existing helper bytecode does not match compiled artifact');
    return false;
}

async function executorNeedsSetup(code, artifact, safe, implementation, executor, provider) {
    if (code === '0x') return true;
    const actual = ethers.utils.arrayify(code);
    const expected = ethers.utils.arrayify(artifact.deployedBytecode.object);
    for (const { start, length } of Object.values(artifact.deployedBytecode.immutableReferences || {}).flat()) {
        actual.fill(0, start, start + length);
        expected.fill(0, start, start + length);
    }
    if (ethers.utils.hexlify(actual) !== ethers.utils.hexlify(expected)) throw new Error('Existing executor bytecode does not match compiled artifact');
    const contract = new ethers.Contract(executor, ['function SAFE() view returns(address)', 'function IMPLEMENTATION() view returns(address)'], provider);
    const [actualSafe, actualImplementation] = await Promise.all([contract.SAFE(), contract.IMPLEMENTATION()]);
    if (actualSafe.toLowerCase() !== safe.toLowerCase() || actualImplementation.toLowerCase() !== implementation.toLowerCase()) {
        throw new Error('Existing executor has different Safe or implementation');
    }
    return false;
}

function defaultSafe(root = ROOT) {
    const lock = JSON.parse(fs.readFileSync(path.join(root, 'sphinx.lock'), 'utf8'));
    const config = lock.projects?.['banny-core']?.defaultSafe;
    if (!config) throw new Error('No banny-core Safe in sphinx.lock; pass --safe explicitly');
    return getGnosisSafeProxyAddress(config.owners, config.threshold, config.saltNonce);
}

async function preflight({ network, safe, hook, provider, root = ROOT }) {
    const rpcChainId = Number(await provider.send('eth_chainId', []));
    if (rpcChainId !== network.chainId) throw new Error(`RPC chain mismatch: expected ${network.chainId}, got ${rpcChainId}`);
    const codeAddresses = [FACTORY, MULTISEND, safe, hook];
    const codes = await Promise.all(codeAddresses.map(target => provider.getCode(target)));
    for (let i = 0; i < codes.length; i++) {
        if (codes[i] === '0x') throw new Error(`No deployed contract at ${codeAddresses[i]} on ${network.chainId}`);
    }
    if (codes[0].toLowerCase() !== FACTORY_CODE) throw new Error('Unexpected deterministic deployment proxy code');
    if (codes[1].toLowerCase() !== MultiSendCallOnlyArtifact.deployedBytecode.toLowerCase()) {
        throw new Error('Unexpected MultiSendCallOnly code');
    }
    const safeContract = new ethers.Contract(safe, [
        'function getThreshold() view returns(uint256)',
        'function getOwners() view returns(address[])',
    ], provider);
    const hookContract = new ethers.Contract(hook, [
        'function owner() view returns(address)',
        'function STORE() view returns(address)',
        'function trustedForwarder() view returns(address)',
        'function projectId() view returns(uint256)',
        'function PERMISSIONS() view returns(address)',
    ], provider);
    const [threshold, owners, owner, store] = await Promise.all([
        safeContract.getThreshold(), safeContract.getOwners(), hookContract.owner(), hookContract.STORE(),
    ]);
    if (threshold.isZero() || threshold.gt(owners.length)) throw new Error('Invalid Safe threshold');
    if (owner.toLowerCase() !== safe.toLowerCase()) {
        const [projectId, permissionsAddress] = await Promise.all([hookContract.projectId(), hookContract.PERMISSIONS()]);
        const permissionSource = fs.readFileSync(path.join(root, 'node_modules/@bananapus/permission-ids-v6/src/JBPermissionIds.sol'), 'utf8');
        const mintPermission = permissionSource.match(/\bMINT_721\s*=\s*(\d+)\s*;/)?.[1];
        if (!mintPermission) throw new Error('Cannot read MINT_721 permission ID');
        const permissions = new ethers.Contract(permissionsAddress, [
            'function hasPermission(address,address,uint256,uint256,bool,bool) view returns(bool)',
        ], provider);
        if (!await permissions.hasPermission(safe, owner, projectId, mintPermission, true, true)) {
            throw new Error(`Safe ${safe} is neither hook owner nor authorized MINT_721 operator on ${network.chainId}`);
        }
    }
    const storeContract = new ethers.Contract(address(store, 'store'), [
        'function tokenUriResolverOf(address) view returns(address)',
    ], provider);
    const resolver = address(await storeContract.tokenUriResolverOf(hook), 'resolver');
    const resolverCode = await provider.getCode(resolver);
    if (resolverCode === '0x') throw new Error('Resolver is not deployed');
    const replacement = new ethers.Contract(resolver, [
        'function SVG_STORAGE() view returns(address)', 'function owner() view returns(address)',
        'function trustedForwarder() view returns(address)',
    ], provider);
    const [storageAddress, resolverOwner, forwarder, hookForwarder] = await Promise.all([
        replacement.SVG_STORAGE().catch(error => {
            if (error.code === 'CALL_EXCEPTION') throw new Error('Replacement resolver is not active: active resolver has no SVG_STORAGE binding');
            throw error;
        }), replacement.owner(), replacement.trustedForwarder(), hookContract.trustedForwarder(),
    ]);
    if (forwarder.toLowerCase() !== hookForwarder.toLowerCase()) throw new Error('Replacement trusted forwarder differs from hook');
    const svgStorage = address(storageAddress, 'SVG storage');
    if (resolverOwner.toLowerCase() !== safe.toLowerCase()) throw new Error('Safe is not replacement resolver owner');
    const storageCode = await provider.getCode(svgStorage);
    if (storageCode === '0x') throw new Error('SVG storage is not deployed');
    const storageContract = new ethers.Contract(svgStorage, [
        'function CONFIGURATOR() view returns(address)', 'function writer() view returns(address)',
    ], provider);
    const [configurator, writer] = await Promise.all([storageContract.CONFIGURATOR(), storageContract.writer()]);
    if (configurator.toLowerCase() !== safe.toLowerCase()) throw new Error('Safe is not SVG storage configurator');
    if (writer.toLowerCase() !== resolver.toLowerCase()) throw new Error('SVG storage writer is not active resolver');
    // Both native and Sphinx distributions require the reviewed bytecode-storage replacement.
    // Validate transitive sources before deriving immutable IDs from the same build.
    const sources = new Map();
    readCompiledArtifact('Banny721TokenUriResolver', 'src/Banny721TokenUriResolver.sol', root, sources);
    readCompiledArtifact('BannySvgStorage', 'src/BannySvgStorage.sol', root, sources);
    const ids = immutableIds(root);
    const compiled = readCompiledArtifact('Banny721TokenUriResolver', 'src/Banny721TokenUriResolver.sol', root);
    const storageArtifact = readCompiledArtifact('BannySvgStorage', 'src/BannySvgStorage.sol', root);
    const resolverHash = runtimeHash(compiled, { [ids.forwarder]: hookForwarder, [ids.storage]: svgStorage });
    if (ethers.utils.keccak256(resolverCode) !== resolverHash) throw new Error('Active resolver runtime is not the reviewed replacement');
    if (ethers.utils.keccak256(storageCode) !== runtimeHash(storageArtifact, { [ids.configurator]: safe })) {
        throw new Error('SVG storage runtime does not match reviewed artifact');
    }
    return { resolver, threshold: threshold.toString(), owners };
}

function writeExports(files) {
    // Compare every destination before writing any file, so a changed payload cannot silently replace review evidence.
    for (const [filename, contents] of files) {
        if (fs.existsSync(filename) && fs.readFileSync(filename, 'utf8') !== contents) {
            throw new Error(`Refusing to overwrite different export: ${filename}; choose a new --out directory`);
        }
    }
    for (const [filename, contents] of files) {
        fs.mkdirSync(path.dirname(filename), { recursive: true });
        if (!fs.existsSync(filename)) fs.writeFileSync(filename, contents, { flag: 'wx' });
    }
}

async function bindNonce(envelope, nonce, provider) {
    const safe = new ethers.Contract(envelope.safe, SAFE_INTERFACE, provider);
    const tx = { ...envelope.transaction, nonce: ethers.BigNumber.from(nonce).toString() };
    const safeTxHash = await safe.getTransactionHash(...SAFE_TRANSACTION_FIELDS.map(field => tx[field]), tx.nonce);
    return {
        ...envelope,
        transaction: tx,
        safeTxHash,
        approveHashTransaction: { to: envelope.safe, value: '0', data: safe.interface.encodeFunctionData('approveHash', [safeTxHash]) },
    };
}

function encodeApprovedExecution(envelope, owners) {
    const sortedOwners = owners.map(owner => address(owner, 'approving owner'))
        .sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
    if (!sortedOwners.length || new Set(sortedOwners).size !== sortedOwners.length) {
        throw new Error('Execution requires distinct approving owners');
    }
    // Safe v=1 signatures reference approvals stored onchain; no private keys are used here.
    const signatures = ethers.utils.hexConcat(sortedOwners.map(owner => ethers.utils.hexConcat([
        ethers.utils.hexZeroPad(owner, 32), ethers.constants.HashZero, '0x01',
    ])));
    return {
        to: address(envelope.safe, 'Safe'),
        value: '0',
        data: SAFE_INTERFACE.encodeFunctionData('execTransaction', [
            ...SAFE_TRANSACTION_FIELDS.map(field => envelope.transaction[field]), signatures,
        ]),
    };
}

function assertApprovedCallBindings(envelope, hook, resolver, helperArtifact) {
    const tx = envelope.transaction;
    let calls = [tx];
    if (Number(tx.operation) === 1) {
        if (tx.to.toLowerCase() !== MULTISEND.toLowerCase()) throw new Error('Approved exporter transaction has unexpected delegatecall target');
        const [packed] = MULTISEND_INTERFACE.decodeFunctionData('multiSend', tx.data);
        const size = ethers.utils.hexDataLength(packed);
        calls = [];
        for (let offset = 0; offset < size;) {
            if (size - offset < 85) throw new Error('Truncated approved MultiSend call');
            const operation = Number(ethers.utils.hexDataSlice(packed, offset, offset + 1));
            const to = ethers.utils.getAddress(ethers.utils.hexDataSlice(packed, offset + 1, offset + 21));
            const value = ethers.BigNumber.from(ethers.utils.hexDataSlice(packed, offset + 21, offset + 53));
            const length = ethers.BigNumber.from(ethers.utils.hexDataSlice(packed, offset + 53, offset + 85)).toNumber();
            if (length > size - offset - 85) throw new Error('Truncated approved MultiSend calldata');
            calls.push({ to, value, operation, data: ethers.utils.hexDataSlice(packed, offset + 85, offset + 85 + length) });
            offset += 85 + length;
        }
    }
    const execute = new ethers.utils.Interface(['function execute(bytes[])']);
    const helper = new ethers.utils.Interface(helperArtifact.abi);
    const same = (actual, expected) => actual.toLowerCase() === expected.toLowerCase();
    const beneficiaries = new Set();
    for (const call of calls) {
        if (Number(call.operation) !== 0 || !ethers.BigNumber.from(call.value).isZero()) {
            throw new Error('Approved exporter call must use CALL without ETH');
        }
        if (same(call.to, FACTORY)) continue;
        if (call.data.startsWith(HOOK_INTERFACE.getSighash('mintFor'))) {
            if (!same(call.to, hook)) throw new Error('Signed mint hook differs from canonical hook');
            const [, beneficiary] = HOOK_INTERFACE.decodeFunctionData('mintFor', call.data);
            beneficiaries.add(beneficiary.toLowerCase());
        } else if (call.data.startsWith(execute.getSighash('execute'))) {
            if (!beneficiaries.has(call.to.toLowerCase())) throw new Error('Signed executor is not a signed mint beneficiary');
            const [inner] = execute.decodeFunctionData('execute', call.data);
            for (const data of inner) {
                const parsed = helper.parseTransaction({ data });
                if (!['decorateBannys', 'transferRegular', 'requireNoBalance'].includes(parsed.name)) {
                    throw new Error('Approved exporter transaction contains an unexpected helper call');
                }
                if (!same(parsed.args[0], hook)) throw new Error('Signed helper hook differs from canonical hook');
                if (parsed.name === 'decorateBannys' && !same(parsed.args[1], resolver)) {
                    throw new Error('Signed decoration resolver differs from active replacement');
                }
            }
        } else throw new Error('Approved exporter transaction contains an unexpected call');
    }
}

async function prepareApprovedExecution(envelope, provider, { root = ROOT, deployments } = {}) {
    if (envelope.transaction?.nonce === null || envelope.transaction?.nonce === undefined
        || !ethers.utils.isHexString(envelope.safeTxHash, 32)) {
        throw new Error('Execution requires a nonce-bound .safe-tx.json with safeTxHash');
    }
    if (String(Number(await provider.send('eth_chainId', []))) !== String(envelope.chainId)) {
        throw new Error('Execution RPC chain mismatch');
    }
    const safeAddress = address(envelope.safe, 'Safe');
    const safe = new ethers.Contract(safeAddress, SAFE_INTERFACE, provider);
    const tx = envelope.transaction;
    const [nonce, owners, threshold, hash] = await Promise.all([
        safe.nonce(), safe.getOwners(), safe.getThreshold(),
        safe.getTransactionHash(...SAFE_TRANSACTION_FIELDS.map(field => tx[field]), tx.nonce),
    ]);
    if (!nonce.eq(tx.nonce)) throw new Error('Safe nonce does not match this proposal; execute earlier chunks first or inspect prior execution');
    if (hash.toLowerCase() !== envelope.safeTxHash.toLowerCase()) throw new Error('Safe transaction hash mismatch; proposal fields changed');
    if (threshold.isZero() || threshold.gt(owners.length)) throw new Error('Invalid Safe threshold');
    const approvals = await Promise.all(owners.map(owner => safe.approvedHashes(owner, hash)));
    const approvingOwners = owners.filter((_, index) => !approvals[index].isZero())
        .sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
    if (approvingOwners.length < threshold.toNumber()) {
        throw new Error(`Only ${approvingOwners.length}/${threshold.toString()} current Safe owners have approved this hash`);
    }
    // Stage labels are unsigned metadata. Gate setup too, so relabeling a signed migration cannot bypass resolver-first.
    const network = Object.values(NETWORKS).flat().find(item => String(item.chainId) === String(envelope.chainId));
    if (!network) throw new Error('Unsupported proposal chain');
    const hook = readHookAddress(network, { root, deployments });
    if (hook.toLowerCase() !== address(envelope.hook, 'proposal hook').toLowerCase()) throw new Error('Proposal hook differs from canonical hook');
    const { resolver } = await preflight({ network, safe: safeAddress, hook, provider, root });
    if (resolver.toLowerCase() !== address(envelope.resolver, 'proposal resolver').toLowerCase()) {
        throw new Error('Approved proposal resolver differs from active replacement');
    }
    const helperPlan = buildCombinedContractsByChain(loadRawItems())[network.sourceChainId][0];
    assertApprovedCallBindings(envelope, hook, resolver, readArtifact(helperPlan, root));
    // Removed owners' approvals do not count. Include exactly the current threshold to keep calldata small.
    const selected = approvingOwners.slice(0, threshold.toNumber());
    return {
        chainId: String(envelope.chainId), safe: safeAddress, safeTxHash: hash, nonce: nonce.toString(),
        approvingOwners: selected,
        transaction: encodeApprovedExecution(envelope, selected),
    };
}

function readHookAddress(network, { root = ROOT,
    deployments = path.resolve(root, process.env.BANNY_AIRDROP_DEPLOYMENTS_PATH || '../deploy-all-v6/deployments') } = {}) {
    return address(JSON.parse(fs.readFileSync(
        path.join(deployments, network.folder, 'JB721TiersHook__ProjectBAN.json'), 'utf8',
    )).address, 'hook');
}

// Canonical per-chain preparation shared by unsigned export transports. Provider reads,
// setup omission and optional Safe nonce binding retain the CLI's existing behavior.
async function prepareChain({ network, profile, safe, provider, root = ROOT,
    deployments,
    plans, helperPlans, executorArtifact, sourceHashes = new Map(), startNonce }) {
    const batches = [];
    const hook = readHookAddress(network, { root, deployments });
    const { resolver, threshold, owners } = await preflight({ network, safe, hook, provider, root });
    if (startNonce !== undefined) {
        const safeContract = new ethers.Contract(safe, ['function nonce() view returns(uint256)'], provider);
        if (ethers.BigNumber.from(startNonce).lt(await safeContract.nonce())) throw new Error('Start nonce is already executed');
    }
    const chain = { chainId: network.chainId, folder: network.folder, hook, resolver, threshold, owners, transactions: [] };
    const helperPlan = helperPlans[network.sourceChainId][0];
    const artifact = readArtifact(helperPlan, root, sourceHashes);
    let order = 0;
    let setupChecked = false;
    const append = async prepared => {
        prepared.safeTransaction.order = ++order;
        const safeTransaction = startNonce === undefined ? prepared.safeTransaction
            : await bindNonce(prepared.safeTransaction, ethers.BigNumber.from(startNonce).add(order - 1), provider);
        const { stage, chunk, slice, contractName, helper, expectedTokenIds } = safeTransaction;
        const name = stage === 'setup' ? 'setup' : `${contractName}-slice${slice}`;
        const stem = `${network.chainId}/${String(order).padStart(2, '0')}-${name}`;
        batches.push({ batch: prepared.batch, safeTransaction, builderFile: `${stem}.json`, safeTransactionFile: `${stem}.safe-tx.json` });
        chain.transactions.push({ order, stage, chunk, slice, contractName, helper, mintCount: expectedTokenIds.length,
            builderFile: `${stem}.json`, safeTransactionFile: `${stem}.safe-tx.json` });
    };
    for (const [index, plan] of plans[network.sourceChainId].entries()) {
        for (const slice of partitionPlan(plan)) {
            const prepared = buildBatch({ plan: slice, helperPlan, artifact, executorArtifact,
                profile, chainId: network.chainId, safe, hook, resolver, chunk: index + 1 });
            if (!setupChecked) {
                const { helper, implementation } = prepared.safeTransaction;
                const [implementationCode, executorCode] = await Promise.all([provider.getCode(implementation), provider.getCode(helper)]);
                const missingImplementation = needsSetup(implementationCode, artifact);
                const missingExecutor = await executorNeedsSetup(executorCode, executorArtifact, safe, implementation, helper, provider);
                const setupCalls = prepared.setup.batch.transactions.filter((_, index) => index === 0 ? missingImplementation : missingExecutor);
                if (setupCalls.length) await append(wrapBatch(setupCalls, prepared.setup.safeTransaction, prepared.setup.batch.meta.name));
                setupChecked = true;
            }
            await append(prepared);
        }
    }
    return { chain, batches };
}

async function main() {
    const { values } = parseArgs({ options: {
        profile: { type: 'string' }, chain: { type: 'string' }, safe: { type: 'string' }, out: { type: 'string' },
        'start-nonce': { type: 'string' },
        'approved-execution': { type: 'string' },
    } });
    if (values['approved-execution']) {
        if (values.profile || values.chain || values.safe || values['start-nonce'] !== undefined) {
            throw new Error('--approved-execution only accepts --out; chain, Safe and nonce come from the approved proposal');
        }
        const filename = path.resolve(ROOT, values['approved-execution']);
        const envelope = JSON.parse(fs.readFileSync(filename, 'utf8'));
        const network = Object.values(NETWORKS).flat().find(network => String(network.chainId) === String(envelope.chainId));
        if (!network) throw new Error('Unsupported proposal chain');
        const rpc = process.env[network.rpc];
        if (!rpc) throw new Error(`Missing ${network.rpc}; load .env before preparing execution`);
        const provider = new ethers.providers.JsonRpcProvider({ url: rpc, timeout: 30000 });
        const execution = await prepareApprovedExecution(envelope, provider);
        const output = values.out ? path.resolve(ROOT, values.out) : `${filename.replace(/\.json$/, '')}.execution.json`;
        writeExports(new Map([[output, `${JSON.stringify(execution, null, 2)}\n`]]));
        console.log(`Wrote ${output}. Unsigned execution transaction only; nothing signed or broadcast.`);
        return;
    }
    const networks = networksFor(values.profile, values.chain);
    const startNonce = values['start-nonce'];
    if (startNonce !== undefined && (!values.chain || !/^(0|[1-9]\d*)$/.test(startNonce))) {
        throw new Error('--start-nonce requires --chain and a nonnegative integer; inspect pending proposals before choosing it');
    }
    const safe = address(values.safe || defaultSafe(), 'Safe');
    const output = path.resolve(ROOT, values.out || path.join('safe-airdrop', values.profile));
    const items = loadRawItems();
    const plans = buildContractsByChain(items);
    const helperPlans = buildCombinedContractsByChain(items);
    assertGeneratedSnapshot(plans, items);
    const sourceHashes = new Map();
    const executorArtifact = readCompiledArtifact('SafeAirdropExecutor', 'script/helpers/SafeAirdropExecutor.sol', ROOT, sourceHashes);
    const files = new Map();
    const manifest = { profile: values.profile, safe, status: 'prepared; not signed or submitted', chains: [] };
    const add = (filename, value) => files.set(path.join(output, filename), `${JSON.stringify(value, null, 2)}\n`);
    for (const network of networks) {
        const rpc = process.env[network.rpc];
        if (!rpc) throw new Error(`Missing ${network.rpc}; load .env before exporting`);
        const provider = new ethers.providers.JsonRpcProvider({ url: rpc, timeout: 30000 });
        const { chain, batches } = await prepareChain({ network, profile: values.profile, safe, provider,
            plans, helperPlans, executorArtifact, sourceHashes, startNonce });
        for (const prepared of batches) {
            add(prepared.builderFile, prepared.batch);
            add(prepared.safeTransactionFile, prepared.safeTransaction);
        }
        manifest.chains.push(chain);
        console.log(`Prepared ${network.folder}: ${chain.transactions.length} ordered Safe transactions for ${safe} (${chain.threshold}/${chain.owners.length}).`);
    }
    add('manifest.json', manifest);
    writeExports(files);
    console.log(`Wrote ${output}. No transactions signed, submitted or broadcast. Choose queue nonces before signing.`);
}

if (require.main === module) {
    main().catch(error => {
        // RPC errors may embed credential-bearing URLs; never print the provider's full error object.
        console.error(error.code ? `Export failed (${error.code}); check RPC connectivity and contract reads.` : error.message);
        process.exitCode = 1;
    });
}

module.exports = { readHookAddress, prepareChain, wrapBatch, buildBatch, combineMigrationBatches, readArtifact, readCompiledArtifact, assertGeneratedSnapshot, networksFor, preflight, writeExports, defaultSafe,
    bindNonce, encodeApprovedExecution, prepareApprovedExecution, partitionPlan, needsSetup, MAX_MINTS_PER_TRANSACTION,
    executorNeedsSetup, SAFE_TRANSACTION_FIELDS, FACTORY, MULTISEND, NETWORKS };
