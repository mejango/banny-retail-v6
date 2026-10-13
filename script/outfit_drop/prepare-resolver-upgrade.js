#!/usr/bin/env node
'use strict';
// Read-only preparation. The two Safe Builder files execute in order; configuration and switch form one atomic batch.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { ethers } = require('ethers');
const ROOT = path.resolve(__dirname, '../..');
const FACTORY = '0x4e59b44847b379578588920cA78FbF26c0B4956C';
const SETTINGS = ['owner', 'trustedForwarder', 'svgDescription', 'svgExternalUrl', 'svgBaseUri',
    'bannyBody', 'defaultNecklace', 'defaultMouth', 'defaultStandardEyes', 'defaultAlienEyes'];
const RESOLVER_ABI = SETTINGS.map(name => `function ${name}() view returns(${['owner', 'trustedForwarder'].includes(name) ? 'address' : 'string'})`).concat([
    'function svgHashOf(uint256) view returns(bytes32)',
    'function namesOf(address,uint256) view returns(string,string,string)',
    'function svgOf(address,uint256,bool,bool) view returns(string)',
    'function setMetadata(string,string,string)',
    'function setProductNames(uint256[],string[])',
    'function setSvgHashesOf(uint256[],bytes32[])',
]);
const SVG_STORAGE_ABI = ['function CONFIGURATOR() view returns(address)', 'function writer() view returns(address)',
    'function setWriter(address)'];
const HOOK_ABI = ['function trustedForwarder() view returns(address)', 'function STORE() view returns(address)', 'function owner() view returns(address)',
    'function projectId() view returns(uint256)', 'function PERMISSIONS() view returns(address)',
    'function balanceOf(address) view returns(uint256)', 'function setMetadata(string,string,string,string,address,uint256,bytes32)'];
const STORE_ABI = ['function tokenUriResolverOf(address) view returns(address)',
    'function totalSupplyOf(address) view returns(uint256)', 'function maxTierIdOf(address) view returns(uint256)',
    'function numberOfBurnedFor(address,uint256) view returns(uint256)'];
let reviewedBuild;
const immutableIdCache = new Map();
const tx = (to, data) => ({ to, value: '0', data, contractMethod: null, contractInputsValues: null });

function artifact(name, root = ROOT) {
    return JSON.parse(fs.readFileSync(path.join(root, 'out', `${name}.sol`, `${name}.json`)));
}

function configurationHash(settings, products, maxTierId) {
    const abi = ethers.utils.defaultAbiCoder;
    let digest = ethers.utils.keccak256(abi.encode(['address', 'address', ...Array(8).fill('string'), 'uint256'],
        [...SETTINGS.map(key => settings[key]), maxTierId]));
    for (const product of products) {
        digest = ethers.utils.keccak256(abi.encode(['bytes32', 'uint256', 'bytes32', 'string'],
            [digest, product.upc, product.hash, product.name]));
    }
    return digest;
}

function artworkHash(products) {
    let digest = ethers.constants.HashZero;
    for (const product of products) {
        digest = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['bytes32', 'uint256', 'bytes32'],
            [digest, product.upc, product.svgHash]));
    }
    return digest;
}

// svgOf wraps published asset contents. Only recover a preimage when its exact bytes match the commitment.
function publicationEvidence(hash, svg) {
    const prefix = '<svg width="400" height="400" viewBox="0 0 400 400" fill="white" xmlns="http://www.w3.org/2000/svg"><style>.o{fill:#050505;}.w{fill:#f9f9f9;}</style>';
    const contents = svg.startsWith(prefix) && svg.endsWith('</svg>') ? svg.slice(prefix.length, -6) : null;
    const svgContents = contents !== null && ethers.utils.keccak256(ethers.utils.toUtf8Bytes(contents)) === hash ? contents : null;
    return { inline: hash !== ethers.constants.HashZero && (svgContents !== null || !svg.includes('<image href="')),
        renderedSvg: svg, svgContents };
}

function artworkRecovery(products) {
    return { inlineUpcs: products.filter(product => product.inline).map(product => product.upc),
        publicationRequired: products.filter(product => product.inline).map(({ upc, hash, svgContents }) =>
            ({ upc, hash, svgContents })),
        instruction: 'Inline artwork is appearance evidence, not switch authority. Republish each exact original preimage on the replacement using setSvgContentsOf after its commitments are configured. Verify keccak256(UTF-8 bytes) equals hash first; renderedSvg includes a wrapper and is not publication calldata. If svgContents is null, recover the exact preimage from the old resolver SetSvgContent event or the original asset source. Verify replacement rendering separately; activation alone does not establish artwork parity.' };
}

function immutableLayoutKey(root) {
    return JSON.stringify([path.resolve(root), ...['Banny721TokenUriResolver', 'BannySvgStorage'].map(name => {
        const compiled = artifact(name, root);
        return [compiled.deployedBytecode.object, compiled.deployedBytecode.immutableReferences];
    })]);
}

function immutableIds(root = ROOT) {
    const key = immutableLayoutKey(root);
    if (immutableIdCache.has(key)) return { ...immutableIdCache.get(key) };
    // Official compiler IR identifies the immutable declarations; numeric AST IDs change between compilations.
    const ir = execFileSync('forge', ['inspect', 'Banny721TokenUriResolver', 'ir'], { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
    const forwarderBody = ir.match(/function fun_trustedForwarder_\d+\([^]*?\n\s*}/)?.[0];
    const storageBody = ir.match(/function getter_fun_SVG_STORAGE_\d+\([^]*?\n\s*}/)?.[0];
    const forwarder = forwarderBody?.match(/loadimmutable\("(\d+)"\)/)?.[1];
    const storage = storageBody?.match(/loadimmutable\("(\d+)"\)/)?.[1];
    if (!forwarder || !storage || forwarder === storage) throw new Error('Cannot identify resolver immutables');
    const storageIr = execFileSync('forge', ['inspect', 'BannySvgStorage', 'ir'], { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
    const configurator = storageIr.match(/function getter_fun_CONFIGURATOR_\d+\([^]*?\n\s*}/)?.[0]?.match(/loadimmutable\("(\d+)"\)/)?.[1];
    if (!configurator) throw new Error('Cannot identify storage configurator immutable');
    const ids = { forwarder, storage, configurator };
    const resolverKeys = Object.keys(artifact('Banny721TokenUriResolver', root).deployedBytecode.immutableReferences).sort();
    const storageKeys = Object.keys(artifact('BannySvgStorage', root).deployedBytecode.immutableReferences).sort();
    if (resolverKeys.join(',') !== [forwarder, storage].sort().join(',') || storageKeys.join(',') !== configurator) {
        throw new Error('Inspection changed immutable declaration IDs; rebuild before preparing');
    }
    // Inspection can rebuild and renumber AST IDs. Cache only against the artifacts left by those inspections.
    immutableIdCache.set(immutableLayoutKey(root), ids);
    return { ...ids };
}

function runtimeHash(compiled, values) {
    let runtime = compiled.deployedBytecode.object.replace(/^0x/, '');
    const references = compiled.deployedBytecode.immutableReferences || {};
    if (Object.keys(references).sort().join(',') !== Object.keys(values).sort().join(',')) {
        throw new Error('Contract immutable layout changed; review runtime patching');
    }
    for (const [id, value] of Object.entries(values)) {
        const encoded = ethers.utils.hexZeroPad(value, 32).slice(2).toLowerCase();
        for (const reference of references[id]) {
            if (reference.length !== 32) throw new Error('Unsupported immutable width');
            runtime = runtime.slice(0, reference.start * 2) + encoded + runtime.slice((reference.start + 32) * 2);
        }
    }
    return ethers.utils.keccak256(`0x${runtime}`);
}

async function deploymentTransaction(provider, item, expectedCodeHash, block) {
    const code = await provider.getCode(item.address, block);
    if (code === '0x') return item.transaction;
    if (ethers.utils.keccak256(code) !== expectedCodeHash) throw new Error('Predicted deployment has unexpected code');
    return null;
}

function storageBinding(storageAddress, writer, replacement) {
    if (writer.toLowerCase() === replacement.toLowerCase()) return null;
    if (writer !== ethers.constants.AddressZero) throw new Error('Storage is bound to another writer');
    return tx(storageAddress, new ethers.utils.Interface(SVG_STORAGE_ABI).encodeFunctionData('setWriter', [replacement]));
}

function deployment(compiled, args, label) {
    const initCode = new ethers.ContractFactory(compiled.abi, compiled.bytecode.object).getDeployTransaction(...args).data;
    const salt = ethers.utils.id(`banny-resolver-upgrade-v1:${label}`);
    return { address: ethers.utils.getCreate2Address(FACTORY, salt, ethers.utils.keccak256(initCode)),
        transaction: tx(FACTORY, ethers.utils.hexConcat([salt, initCode])), initCodeHash: ethers.utils.keccak256(initCode) };
}

async function collect(provider, hook, safe, block) {
    const override = { blockTag: block };
    const h = new ethers.Contract(hook, HOOK_ABI, provider);
    const [storeAddress, hookOwner, projectId, permissionsAddress, hookTrustedForwarder] = await Promise.all([
        h.STORE(override), h.owner(override), h.projectId(override), h.PERMISSIONS(override), h.trustedForwarder(override),
    ]);
    if (hookOwner.toLowerCase() !== safe.toLowerCase()) {
        const source = fs.readFileSync(path.join(ROOT, 'node_modules/@bananapus/permission-ids-v6/src/JBPermissionIds.sol'), 'utf8');
        const id = source.match(/\bSET_721_METADATA\s*=\s*(\d+)\s*;/)?.[1];
        if (!id) throw new Error('Missing SET_721_METADATA permission');
        const permissions = new ethers.Contract(permissionsAddress,
            ['function hasPermission(address,address,uint256,uint256,bool,bool) view returns(bool)'], provider);
        if (!await permissions.hasPermission(safe, hookOwner, projectId, id, true, true, override)) throw new Error('Safe cannot switch resolver');
    }
    const store = new ethers.Contract(storeAddress, STORE_ABI, provider);
    const [previous, supply, maximum] = await Promise.all([store.tokenUriResolverOf(hook, override),
        store.totalSupplyOf(hook, override), store.maxTierIdOf(hook, override)]);
    if (!supply.isZero()) throw new Error('Collection already minted; cannot use before-mint rollout');
    if (!(await h.balanceOf(previous, override)).isZero()) throw new Error('Old resolver has custody');
    const resolver = new ethers.Contract(previous, RESOLVER_ABI, provider);
    const settings = Object.fromEntries(await Promise.all(SETTINGS.map(async key => [key, await resolver[key](override)])));
    if (settings.trustedForwarder.toLowerCase() !== hookTrustedForwarder.toLowerCase()) throw new Error('Resolver trusted forwarder differs from hook; cannot prepare an upgrade that distribution will reject');
    if (settings.owner.toLowerCase() !== safe.toLowerCase()) throw new Error('Safe is not resolver owner');
    const maxTierId = Number(maximum);
    if (!Number.isSafeInteger(maxTierId) || maxTierId > 1000) throw new Error('Unexpected product count; review enumeration');
    const products = [];
    for (let first = 1; first <= maxTierId; first += 8) {
        const batch = await Promise.all(Array.from({ length: Math.min(8, maxTierId - first + 1) }, async (_, index) => {
            const upc = first + index;
            const id = ethers.BigNumber.from(upc).mul(1_000_000_000).add(1);
            const [hash, names, svg, burned] = await Promise.all([resolver.svgHashOf(upc, override),
                resolver.namesOf(hook, id, override), resolver.svgOf(hook, id, false, false, override),
                store.numberOfBurnedFor(hook, upc, override)]);
            if (!burned.isZero()) throw new Error(`UPC ${upc} has mint/burn history; cannot use before-mint rollout`);
            // Record rendering evidence; published content is excluded from configuration authority.
            return { upc, hash, name: names[2], burned: burned.toString(),
                svgHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(svg)), ...publicationEvidence(hash, svg) };
        }));
        products.push(...batch);
    }

    return { previous, settings, products, maxTierId, hookTrustedForwarder, ...artworkRecovery(products),
        configurationHash: configurationHash(settings, products, maxTierId), oldArtworkHash: artworkHash(products),
        previousCodeHash: ethers.utils.keccak256(await provider.getCode(previous, block)) };
}

function writeExclusive(filename, value) {
    fs.writeFileSync(filename, `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx' });
}

async function prepare({ provider, hook, safe, output, block, guardStage = 'switch' }) {
    if (!['deploy', 'switch'].includes(guardStage)) throw new Error('Guard stage must be deploy or switch');
    hook = ethers.utils.getAddress(hook); safe = ethers.utils.getAddress(safe);
    block ??= await provider.getBlockNumber();
    const header = await provider.getBlock(block);
    const chainId = Number(await provider.send('eth_chainId', []));
    const state = await collect(provider, hook, safe, block);
    if (await provider.getCode(FACTORY, block) === '0x') throw new Error('Deterministic factory unavailable');
    if (!reviewedBuild) {
        const ids = immutableIds();
        reviewedBuild = { ids, compiled: artifact('Banny721TokenUriResolver'), guardArtifact: artifact('BannyResolverUpgradeGuard'), storageArtifact: artifact('BannySvgStorage') };
    }
    const { ids, compiled, guardArtifact, storageArtifact } = reviewedBuild;
    const s = state.settings;
    const storage = deployment(storageArtifact, [safe], 'bytecode-svg-storage');
    const replacement = deployment(compiled, [s.bannyBody, s.defaultNecklace, s.defaultMouth,
        s.defaultStandardEyes, s.defaultAlienEyes, s.owner, s.trustedForwarder, storage.address], 'bytecode-svg');
    const guard = deployment(guardArtifact, [], 'before-mint-guard');
    const storageAddress = storage.address;
    const storageCodeHash = runtimeHash(storageArtifact, { [ids.configurator]: safe });
    const replacementCodeHash = runtimeHash(compiled, { [ids.forwarder]: s.trustedForwarder, [ids.storage]: storageAddress });
    const guardCodeHash = ethers.utils.keccak256(guardArtifact.deployedBytecode.object);
    const deployed = [];
    for (const [item, expected] of [[storage, storageCodeHash], [replacement, replacementCodeHash]]) {
        const transaction = await deploymentTransaction(provider, item, expected, block);
        if (transaction) deployed.push(transaction);
    }
    const guardDeployment = await deploymentTransaction(provider, guard, guardCodeHash, block);
    if (guardStage === 'deploy' && guardDeployment) deployed.push(guardDeployment);
    let storageWriter = ethers.constants.AddressZero;
    if (await provider.getCode(storageAddress, block) !== '0x') {
        const existingStorage = new ethers.Contract(storageAddress, SVG_STORAGE_ABI, provider);
        const [configurator, writer] = await Promise.all([existingStorage.CONFIGURATOR({ blockTag: block }), existingStorage.writer({ blockTag: block })]);
        if (configurator.toLowerCase() !== safe.toLowerCase()) throw new Error('Storage configurator changed');
        storageWriter = writer;
    }
    const binding = storageBinding(storageAddress, storageWriter, replacement.address);
    if (binding) deployed.push(binding);
    if (replacement.address.toLowerCase() === state.previous.toLowerCase()) throw new Error('Replacement equals current resolver');
    const iface = new ethers.utils.Interface(RESOLVER_ABI);
    const committed = state.products.filter(product => product.hash !== ethers.constants.HashZero);
    const names = state.products.filter(product => product.upc > 4);
    if (await provider.getCode(replacement.address, block) !== '0x') {
        const current = new ethers.Contract(replacement.address, RESOLVER_ABI, provider);
        if ((await current.owner({ blockTag: block })).toLowerCase() !== safe.toLowerCase()) throw new Error('Replacement owner changed');
        for (const product of state.products) {
            const existing = await current.svgHashOf(product.upc, { blockTag: block });
            if (existing !== ethers.constants.HashZero) throw new Error('Replacement already configured; review a fresh deployment salt instead of reusing it');
        }
    }

    const configure = [
        tx(replacement.address, iface.encodeFunctionData('setMetadata', [s.svgDescription, s.svgExternalUrl, s.svgBaseUri])),
        tx(replacement.address, iface.encodeFunctionData('setSvgHashesOf', [committed.map(p => p.upc), committed.map(p => p.hash)])),
        tx(replacement.address, iface.encodeFunctionData('setProductNames', [names.map(p => p.upc), names.map(p => p.name)])),
    ];
    const switchCalls = [tx(guard.address, new ethers.utils.Interface(guardArtifact.abi).encodeFunctionData('check',
        [hook, state.previous, replacement.address, state.previousCodeHash, replacementCodeHash, state.configurationHash, state.maxTierId])),
    tx(hook, new ethers.utils.Interface(HOOK_ABI).encodeFunctionData('setMetadata',
        ['', '', '', '', replacement.address, 0, ethers.constants.HashZero]))];
    if (fs.existsSync(output) && fs.readdirSync(output).length) throw new Error('Choose an empty output directory; reviewed exports are immutable');
    fs.mkdirSync(output, { recursive: true });
    const files = [];
    for (const [stage, transactions] of [['01-deploy', deployed], ['02-configure-and-switch', [...(guardStage === 'switch' && guardDeployment ? [guardDeployment] : []), ...configure, ...switchCalls]]]) {
        if (!transactions.length) continue;
        const filename = path.join(output, `${chainId}-${stage}.json`);
        writeExclusive(filename, { version: '1.0', chainId: String(chainId), createdAt: Date.now(),
            meta: { name: `Banny resolver upgrade, ${stage}`, description: 'Execute stages in order. Keep the switch calls in one atomic batch.',
                txBuilderVersion: '1.18.0', createdFromSafeAddress: safe, createdFromOwnerAddress: '' }, transactions });
        files.push(filename);
    }
    const evidence = { chainId, guardStage, blockNumber: block, blockHash: header.hash, hook, safe, ...state,
        replacement: replacement.address, svgStorage: storageAddress, storageCodeHash, storageInitCodeHash: storage.initCodeHash, storageWriter, replacementCodeHash, resolverInitCodeHash: replacement.initCodeHash,
        guard: guard.address, guardCodeHash, guardInitCodeHash: guard.initCodeHash, files, submitted: false };
    writeExclusive(path.join(output, `${chainId}-evidence.json`), evidence);
    return evidence;
}

if (require.main === module) {
    const args = process.argv.slice(2); const options = {};
    for (let i = 0; i < args.length; i += 2) {
        if (!['--rpc-env', '--hook', '--safe', '--out', '--block'].includes(args[i]) || !args[i + 1]) throw new Error('Use --rpc-env NAME --hook ADDRESS --safe ADDRESS --out NEW_DIRECTORY [--block NUMBER]');
        options[args[i].slice(2)] = args[i + 1];
    }
    if (!['rpc-env', 'hook', 'safe', 'out'].every(key => options[key])) throw new Error('Missing required option');
    const url = process.env[options['rpc-env']]; if (!url) throw new Error('RPC environment variable missing');
    prepare({ provider: new ethers.providers.JsonRpcProvider({ url, timeout: 30000 }), hook: options.hook,
        safe: options.safe, output: path.resolve(options.out), block: options.block === undefined ? undefined : Number(options.block) })
        .then(result => console.log(`Prepared ${result.chainId}: ${result.files.length} stages in ${options.out}. No transaction sent.`))
        .catch(error => { console.error(String(error.code || error.message || 'Preparation failed').replace(/https?:\/\/\S+/g, '[redacted URL]')); process.exitCode = 1; });
}
module.exports = { prepare, collect, configurationHash, artworkHash, runtimeHash, storageBinding, deployment, deploymentTransaction, immutableIds, publicationEvidence, artworkRecovery };
