#!/usr/bin/env node
'use strict';

// Canonical Safe preparation supplies the calls; the shared adapter owns qualification and submission.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { parseArgs } = require('node:util');
const { ethers } = require('ethers');
const core = require('@sphinx-labs/core');
const utils = require('@sphinx-labs/plugins/dist/foundry/utils');
const { makeSphinxContext } = require('@sphinx-labs/plugins/dist/cli/context');
const { makeCLI } = require('@sphinx-labs/plugins/dist/cli/setup');
const shared = require('./propose-sphinx-airdrop');
const exporter = require('./export-safe-airdrop');
const upgrade = require('./prepare-resolver-upgrade');
const qualifier = require('./qualify-sphinx-airdrop');

const ROOT = path.resolve(__dirname, '../..');
const WORKFLOW = 'banny-resolver-upgrade-v2';
const CONTRACTS = [
    ['BannySvgStorage', 'src/BannySvgStorage.sol'],
    ['Banny721TokenUriResolver', 'src/Banny721TokenUriResolver.sol'],
    ['BannyResolverUpgradeGuard', 'script/helpers/BannyResolverUpgradeGuard.sol'],
];
const SOURCE_FILES = ['script/outfit_drop/propose-sphinx-resolver-upgrade.js',
    'script/outfit_drop/prepare-resolver-upgrade.js', 'script/AirdropV4Bannys.s.sol', ...CONTRACTS.map(([, source]) => source)];
const SETTINGS = ['owner', 'trustedForwarder', 'svgDescription', 'svgExternalUrl', 'svgBaseUri',
    'bannyBody', 'defaultNecklace', 'defaultMouth', 'defaultStandardEyes', 'defaultAlienEyes'];
const RESOLVER = new ethers.utils.Interface(['function setMetadata(string,string,string)',
    'function setSvgHashesOf(uint256[],bytes32[])', 'function setProductNames(uint256[],string[])']);
const STORAGE_ABI = ['function CONFIGURATOR() view returns(address)', 'function writer() view returns(address)',
    'function setWriter(address)'];
const SAFE_ABI = ['function getOwners() view returns(address[])', 'function getThreshold() view returns(uint256)'];
const sha256 = value => createHash('sha256').update(value).digest('hex');
const same = (a, b) => String(a).toLowerCase() === String(b).toLowerCase();
const resumeCommand = directory => shared.resumeCommand(directory).replace('propose-sphinx-airdrop.js', 'propose-sphinx-resolver-upgrade.js');

function readBuild() {
    const sources = new Map();
    const artifacts = new Map(CONTRACTS.map(([name, source]) => [name,
        exporter.readCompiledArtifact(name, source, ROOT, sources)]));
    return { artifacts, sources, identity: shared.sourceIdentity([], artifacts, sources) };
}

function actionFor(batch, index, configArtifacts) {
    const envelope = batch.safeTransaction;
    assert(['resolver-deploy', 'resolver-switch'].includes(envelope.stage), 'Unknown resolver upgrade stage');
    const contracts = batch.batch.transactions.filter(tx => same(tx.to, exporter.FACTORY)).map(tx => {
        const { create2Address: address, initCodeWithArgs } = core.decodeDeterministicDeploymentProxyData(tx.data);
        const fullyQualifiedName = utils.findFullyQualifiedNameForInitCode(initCodeWithArgs, configArtifacts);
        assert(CONTRACTS.some(([name, source]) => fullyQualifiedName === `${source}:${name}`), 'Unreviewed resolver deployment artifact');
        assert.equal(envelope.guardStage, 'deploy', 'Sphinx guard must deploy before the switch action');
        assert.equal(envelope.stage, 'resolver-deploy', 'Deployment outside its guarded stage');
        return { address, initCodeWithArgs, fullyQualifiedName };
    });
    return { actionType: core.ActionInputType.CALL, to: envelope.transaction.to, value: '0',
        txData: envelope.transaction.data, operation: envelope.transaction.operation,
        gas: '0', requireSuccess: true, index: String(index + 1), contracts,
        decodedAction: { referenceName: 'BannyResolverUpgrade', functionName: envelope.stage,
            address: envelope.transaction.to, value: '0', variables: { resolver: envelope.resolver, storage: envelope.storage } } };
}

function batchesFor(evidence) {
    return evidence.files.map(filename => {
        const batch = JSON.parse(fs.readFileSync(filename));
        const stage = filename.endsWith('-01-deploy.json') ? 'resolver-deploy' : 'resolver-switch';
        return exporter.wrapBatch(batch.transactions, { chainId: String(evidence.chainId), safe: evidence.safe,
            stage, guardStage: evidence.guardStage, resolver: evidence.replacement, storage: evidence.svgStorage }, batch.meta.name);
    });
}

function validatePrepared(config, prepared) {
    assert.equal(String(prepared.chainId), config.chainId, 'Prepared chain differs');
    assert(same(prepared.safe, config.safeAddress), 'Prepared Safe differs');
    assert.equal(config.arbitraryChain, false, 'Resolver roots must bind their chain');
    assert.deepEqual(prepared.envelopes.map(envelope => envelope.stage), ['resolver-deploy', 'resolver-switch'],
        'Resolver upgrade requires deployment followed by atomic configuration and switch');
    assert.equal(prepared.canonicalBatches.length, 2, 'Missing canonical resolver batches');
    prepared.canonicalBatches.forEach((transactions, index) => {
        const canonical = exporter.wrapBatch(transactions, prepared.envelopes[index], '').safeTransaction.transaction;
        assert.deepEqual(canonical, prepared.envelopes[index].transaction, 'Resolver envelope differs from its canonical calls');
        assert(transactions.length, 'Empty resolver batch');
        transactions.forEach(tx => assert.equal(tx.value, '0', 'Resolver call sends value'));
    });
    shared.assertActionsMatchEnvelopes(config.actionInputs, prepared.envelopes);
    return new Map();
}

function assertFrozenCalls(chain, build = readBuild()) {
    const evidence = chain.evidence;
    assert.equal(evidence.guardStage, 'deploy', 'Sphinx guard must deploy before the switch action');
    for (const envelope of chain.envelopes) assert.equal(envelope.guardStage, evidence.guardStage, 'Frozen guard stage differs');
    assert(Number.isSafeInteger(evidence.maxTierId) && evidence.maxTierId > 0 && evidence.maxTierId <= 1000,
        'Invalid frozen product count');
    assert.deepEqual(evidence.products.map(product => product.upc),
        Array.from({ length: evidence.maxTierId }, (_, index) => index + 1), 'Frozen product enumeration is incomplete');
    assert.equal(upgrade.configurationHash(evidence.settings, evidence.products, evidence.maxTierId), evidence.configurationHash,
        'Frozen resolver configuration differs');
    const storage = upgrade.deployment(build.artifacts.get('BannySvgStorage'), [chain.safe], 'bytecode-svg-storage');
    const s = evidence.settings;
    const replacement = upgrade.deployment(build.artifacts.get('Banny721TokenUriResolver'),
        [s.bannyBody, s.defaultNecklace, s.defaultMouth, s.defaultStandardEyes, s.defaultAlienEyes,
            s.owner, s.trustedForwarder, storage.address], 'bytecode-svg');
    const guard = upgrade.deployment(build.artifacts.get('BannyResolverUpgradeGuard'), [], 'before-mint-guard');
    assert(same(storage.address, evidence.svgStorage) && same(replacement.address, evidence.replacement)
        && same(guard.address, evidence.guard), 'Frozen resolver deployment identity differs');
    const deploymentCalls = [storage, replacement, guard].map(item => item.transaction);
    const binding = upgrade.storageBinding(storage.address, ethers.constants.AddressZero, replacement.address);
    const seen = new Set();
    for (const call of chain.canonicalBatches[0]) {
        const key = JSON.stringify(call);
        assert(!seen.has(key), 'Repeated resolver deployment call'); seen.add(key);
        assert([...deploymentCalls, binding].some(expected => JSON.stringify(call) === JSON.stringify(expected)),
            'Unexpected deployment or writer binding call');
    }
    const committed = evidence.products.filter(product => product.hash !== ethers.constants.HashZero);
    const names = evidence.products.filter(product => product.upc > 4);
    const tx = (to, data) => ({ to, value: '0', data, contractMethod: null, contractInputsValues: null });
    const expected = [
        tx(replacement.address, RESOLVER.encodeFunctionData('setMetadata', [s.svgDescription, s.svgExternalUrl, s.svgBaseUri])),
        tx(replacement.address, RESOLVER.encodeFunctionData('setSvgHashesOf', [committed.map(p => p.upc), committed.map(p => p.hash)])),
        tx(replacement.address, RESOLVER.encodeFunctionData('setProductNames', [names.map(p => p.upc), names.map(p => p.name)])),
        tx(guard.address, new ethers.utils.Interface(build.artifacts.get('BannyResolverUpgradeGuard').abi).encodeFunctionData('check',
            [chain.hook, evidence.previous, replacement.address, evidence.previousCodeHash, evidence.replacementCodeHash,
                evidence.configurationHash, evidence.maxTierId])),
        tx(chain.hook, new ethers.utils.Interface(['function setMetadata(string,string,string,string,address,uint256,bytes32)'])
            .encodeFunctionData('setMetadata', ['', '', '', '', replacement.address, 0, ethers.constants.HashZero])),
    ];
    assert.deepEqual(chain.canonicalBatches[1], expected, 'Atomic configuration/switch calls changed');
}

async function assertAuthority(provider, chain) {
    const safe = new ethers.Contract(chain.safe, SAFE_ABI, provider);
    const [owners, threshold] = await Promise.all([safe.getOwners(), safe.getThreshold()]);
    assert.deepEqual({ owners, threshold: threshold.toString() }, chain.authority, 'Safe authority changed');
}

async function assertDeployment(provider, chain) {
    const e = chain.evidence;
    for (const [address, expected] of [[e.svgStorage, e.storageCodeHash], [e.replacement, e.replacementCodeHash], [e.guard, e.guardCodeHash]]) {
        const code = await provider.getCode(address);
        assert.equal(ethers.utils.keccak256(code), expected, 'Resolver rollout runtime changed');
    }
    const storage = new ethers.Contract(e.svgStorage, STORAGE_ABI, provider);
    assert(same(await storage.CONFIGURATOR(), chain.safe), 'Storage configurator changed');
    assert(same(await storage.writer(), e.replacement), 'Storage writer changed');
    const resolver = new ethers.Contract(e.replacement, ['function SVG_STORAGE() view returns(address)'], provider);
    assert(same(await resolver.SVG_STORAGE(), e.svgStorage), 'Resolver storage changed');
}

async function assertSwitched(provider, chain) {
    await assertAuthority(provider, chain);
    await assertDeployment(provider, chain);
    // Publication caches are permissionless; activation verification binds their commitments instead.
    const hook = new ethers.Contract(chain.hook, ['function STORE() view returns(address)',
        'function balanceOf(address) view returns(uint256)'], provider);
    const store = new ethers.Contract(await hook.STORE(), ['function tokenUriResolverOf(address) view returns(address)',
        'function totalSupplyOf(address) view returns(uint256)', 'function maxTierIdOf(address) view returns(uint256)',
        'function numberOfBurnedFor(address,uint256) view returns(uint256)'], provider);
    assert(same(await store.tokenUriResolverOf(chain.hook), chain.evidence.replacement), 'Collection resolver was not switched');
    assert((await store.totalSupplyOf(chain.hook)).isZero(), 'Collection minted before verification');
    assert.equal((await store.maxTierIdOf(chain.hook)).toNumber(), chain.evidence.maxTierId, 'Product inventory changed');
    for (const address of [chain.evidence.previous, chain.evidence.replacement]) {
        assert((await hook.balanceOf(address)).isZero(), 'Resolver holds NFTs before distribution');
    }
    const resolver = new ethers.Contract(chain.evidence.replacement,
        SETTINGS.map(name => `function ${name}() view returns(${['owner', 'trustedForwarder'].includes(name) ? 'address' : 'string'})`)
            .concat(['function svgHashOf(uint256) view returns(bytes32)', 'function namesOf(address,uint256) view returns(string,string,string)']), provider);
    const settings = Object.fromEntries(await Promise.all(SETTINGS.map(async key => [key, await resolver[key]()] )));
    assert.deepEqual(settings, chain.evidence.settings, 'Active resolver settings changed');
    for (const product of chain.evidence.products) {
        assert.equal(await resolver.svgHashOf(product.upc), product.hash, 'Active artwork commitment changed');
        assert.equal((await resolver.namesOf(chain.hook, ethers.BigNumber.from(product.upc).mul(1_000_000_000).add(1)))[2],
            product.name, 'Active product name changed');
        assert((await store.numberOfBurnedFor(chain.hook, product.upc)).isZero(), 'Collection has mint/burn history');
    }
}

async function assertCollectionFresh(provider, chain, block) {
    const fresh = await upgrade.collect(provider, chain.hook, chain.safe, block);
    for (const key of ['previous', 'previousCodeHash', 'configurationHash', 'maxTierId', 'hookTrustedForwarder']) {
        assert.equal(fresh[key], chain.evidence[key], `Collection ${key} changed before resolver activation`);
    }
    assert.deepEqual(fresh.settings, chain.evidence.settings, 'Resolver settings changed');
    // Only correctly committed artwork may change without fresh action qualification. All other product fields remain pinned.
    const authority = product => {
        const { renderedSvg, svgContents, inline, ...bound } = product;
        if (product.hash !== ethers.constants.HashZero) delete bound.svgHash;
        return bound;
    };
    assert.deepEqual(fresh.products.map(authority), chain.evidence.products.map(authority), 'Resolver products changed');
    return fresh;
}

async function assertPreparedFresh(artifact, directory, part) {
    assert.equal(artifact.workflow, WORKFLOW, 'Wrong prepared workflow');
    assert.equal(artifact.segments.length, 1, 'Resolver upgrade requires one proposal; do not reuse two-root preparations');
    shared.assertCanonicalActions(artifact);
    const report = JSON.parse(fs.readFileSync(path.join(directory, 'qualification.json')));
    for (const [file, hash] of Object.entries(report.sourceSha256)) {
        assert.equal(sha256(fs.readFileSync(path.join(ROOT, file))), hash, 'Qualified workflow source changed; requalify');
    }
    const build = readBuild();
    assert.equal(build.identity, artifact.inputIdentity, 'Resolver compiler/source identity changed');
    for (const chain of artifact.preparedChains) {
        assertFrozenCalls(chain, build);
        const provider = shared.providerFor(chain);
        assert.equal(String((await provider.getNetwork()).chainId), String(chain.chainId), 'RPC chain changed');
        if (part >= artifact.segments.length) { await assertSwitched(provider, chain); continue; }
        await assertAuthority(provider, chain);
        const block = await provider.getBlockNumber();
        const fresh = await assertCollectionFresh(provider, chain, block);
        // Refresh appearance evidence before submission without changing signed calls.
        const observation = fs.mkdtempSync(path.join(directory, `artwork-observation-${chain.chainId}-`));
        fs.writeFileSync(path.join(observation, 'evidence.json'),
            `${JSON.stringify({ chainId: chain.chainId, blockNumber: block, previous: fresh.previous,
                oldArtworkHash: fresh.oldArtworkHash, products: fresh.products, ...upgrade.artworkRecovery(fresh.products) }, null, 2)}\n`);
        // Fresh preparation also proves omitted existing deployments and writer binding remain valid.
        const temp = fs.mkdtempSync(path.join(directory, 'fresh-'));
        try {
            const evidence = await upgrade.prepare({ provider, hook: chain.hook, safe: chain.safe, output: temp, guardStage: 'deploy' });
            assert.deepEqual(batchesFor(evidence).map(batch => batch.batch.transactions), chain.canonicalBatches,
                'Pending deployment/configuration calls changed');
        } finally { fs.rmSync(temp, { recursive: true, force: true }); }
    }
}

const replayPreparedPart = (artifact, directory, part) => qualifier.replayPreparedPart(artifact, directory, part, {
    multipleExecutionTransactions: true, validatePrepared,
    verifyFinal: async fork => {
        await assertSwitched(fork.provider, fork.prepared); fork.report.resolverUpgradeVerified = true;
    },
});
const assertReady = (artifact, directory, progress, part) =>
    shared.assertReadyToSubmit(artifact, directory, progress, part, assertPreparedFresh, replayPreparedPart);

const resolveCompilerArtifacts = shared.resolveCompilerArtifacts;

async function collectAndQualify(scriptPath, calldata, safe, rpcUrls, pluginInterface,
    foundryToml, projectRoot, getConfigArtifacts, context, targetContract, spinner) {
    assert.equal(path.resolve(projectRoot), ROOT, 'Run from the Banny repository');
    assert.equal(path.resolve(ROOT, scriptPath), path.join(ROOT, 'script/AirdropV4Bannys.s.sol'), 'Use the original Sphinx project script');
    assert.equal(calldata, ethers.utils.id('run()').slice(0, 10), 'Resolver proposal supports run() only');
    let build = readBuild();
    await shared.ensureBuildInfo(getConfigArtifacts, {}, ROOT, () => {
        const s = Array(5).fill('');
        return [new ethers.ContractFactory(build.artifacts.get('BannySvgStorage').abi,
            build.artifacts.get('BannySvgStorage').bytecode.object).getDeployTransaction(safe).data,
        new ethers.ContractFactory(build.artifacts.get('Banny721TokenUriResolver').abi,
            build.artifacts.get('Banny721TokenUriResolver').bytecode.object).getDeployTransaction(...s, safe, safe, safe).data,
        build.artifacts.get('BannyResolverUpgradeGuard').bytecode.object];
    });
    build = readBuild();
    fs.mkdirSync(path.join(ROOT, 'safe-airdrop'), { recursive: true });
    const reportDir = fs.mkdtempSync(path.join(ROOT, 'safe-airdrop', 'resolver-sphinx-'));
    const entries = [], preparedChains = [], batches = [];
    for (const rpcUrl of rpcUrls) {
        const { provider, chainId, profile, network, block, entry } = await shared.collectNetworkContext({
            scriptPath, safe, rpcUrl, pluginInterface, targetContract, reportDir });
        assert(!preparedChains.some(chain => chain.chainId === chainId), 'Duplicate resolver chain');
        const hook = exporter.readHookAddress(network);
        const evidence = await upgrade.prepare({ provider, hook, safe, output: path.join(reportDir, String(chainId)), block: block.number, guardStage: 'deploy' });
        const prepared = batchesFor(evidence);
        assert.deepEqual(prepared.map(batch => batch.safeTransaction.stage), ['resolver-deploy', 'resolver-switch'],
            'Fresh resolver workflow requires both stages; reconcile existing deployments before proposing');
        const safeContract = new ethers.Contract(safe, SAFE_ABI, provider);
        const [owners, threshold] = await Promise.all([safeContract.getOwners(), safeContract.getThreshold()]);
        const chain = { chainId, blockHash: block.hash, network, profile, safe, hook, evidence,
            authority: { owners, threshold: threshold.toString() }, plans: [],
            envelopes: prepared.map(batch => batch.safeTransaction), canonicalBatches: prepared.map(batch => batch.batch.transactions) };
        assertFrozenCalls(chain, build);
        preparedChains.push(chain); entries.push(entry); batches.push(prepared);
        spinner?.info(`Prepared resolver upgrade for ${network.folder} at block ${block.number}.`);
    }
    const initCodes = batches.flat().flatMap(batch => batch.batch.transactions.filter(tx => same(tx.to, exporter.FACTORY))
        .map(tx => core.decodeDeterministicDeploymentProxyData(tx.data).initCodeWithArgs));
    const { configArtifacts, buildInfos } = await resolveCompilerArtifacts(getConfigArtifacts, initCodes, build.identity,
        () => readBuild().identity);
    entries.forEach((entry, index) => { entry.networkConfig.actionInputs = batches[index].map((batch, actionIndex) => actionFor(batch, actionIndex, configArtifacts)); });
    await context.assertNoLinkedLibraries(scriptPath, foundryToml.cachePath, foundryToml.artifactFolder, projectRoot, targetContract);
    fs.writeFileSync(path.join(reportDir, 'inputs.json'), JSON.stringify({ workflow: WORKFLOW, inputIdentity: build.identity,
        sources: Object.fromEntries(build.sources), artifacts: Object.fromEntries([...build.artifacts].map(([name, artifact]) => [name, sha256(JSON.stringify(artifact))])),
        chains: preparedChains }, null, 2));
    const qualified = await qualifier.qualifyProfile(entries, preparedChains, reportDir, undefined, {
        validatePrepared, multipleExecutionTransactions: true, sourceFiles: SOURCE_FILES,
        verifyFinal: async fork => { await assertSwitched(fork.provider, fork.prepared); fork.report.resolverUpgradeVerified = true; },
    });
    assert.equal(qualified.segments.length, 1, 'Resolver upgrade must have exactly one approved root');
    return { ...qualified, entries, preparedChains, configArtifacts, buildInfos, reportDir, inputIdentity: build.identity };
}

function makePropose(context, options = {}) {
    return shared.makeAirdropPropose(context, { prepare: collectAndQualify, assertReady,
        workflowTag: WORKFLOW, label: 'Resolver upgrade', resumeCommand, ...options });
}

async function resumePrepared(context, directory, args = {}, options = {}) {
    const result = await shared.resumePrepared(context, directory, args, { assertReady, assertFresh: assertPreparedFresh,
        workflowTag: WORKFLOW, label: 'Resolver upgrade', resumeCommand, ...options });
    if (result.status === 'complete') {
        const artifact = shared.readPreparedArtifact(path.resolve(directory));
        await assertPreparedFresh(artifact, path.resolve(directory), artifact.segments.length);
    }
    return result;
}

if (require.main === module) {
    const context = makeSphinxContext();
    if (process.argv[2] === 'resume') {
        const { values, positionals } = parseArgs({ args: process.argv.slice(3), allowPositionals: true,
            options: { 'dry-run': { type: 'boolean' }, confirm: { type: 'boolean' } } });
        assert.equal(positionals.length, 1, 'Use resume PREPARED_DIRECTORY [--dry-run] [--confirm]');
        resumePrepared(context, positionals[0], { isDryRun: Boolean(values['dry-run']), confirm: Boolean(values.confirm) })
            .catch(error => { console.error(shared.safeError(error).message); process.exitCode = 1; });
    } else {
        assert(['propose', '--help', '-h'].includes(process.argv[2]), 'Use propose script/AirdropV4Bannys.s.sol --networks <profile>');
        context.propose = makePropose(context);
        makeCLI(process.argv.slice(2), context);
    }
}

module.exports = { WORKFLOW, actionFor, batchesFor, validatePrepared, assertFrozenCalls, assertAuthority,
    assertDeployment, assertSwitched, assertCollectionFresh, assertPreparedFresh, collectAndQualify, makePropose, resumePrepared, readBuild,
    resolveCompilerArtifacts, replayPreparedPart };
