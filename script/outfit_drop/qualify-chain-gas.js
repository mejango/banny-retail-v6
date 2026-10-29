'use strict';

// Candidate sizing is shared; each chain's reviewed policy owns the final proof.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { ethers } = require('ethers');
const live = require('./qualify-resolver-live-rpc');
const policy = require('./gas-proof-policy');
const engine = require('./gas-proof-engine');
const ROOT = path.resolve(__dirname, '../..');
const FORMAT = 'banny-chain-gas-proof-v1';
const ESTIMATOR = 'chain-aware-current-client-v1';
const SOURCE_FILES = ['script/outfit_drop/qualify-chain-gas.js', 'script/outfit_drop/gas-proof-engine.js',
    'script/outfit_drop/gas-proof-policy.js', 'script/outfit_drop/gas-proof-policy.json', 'script/outfit_drop/anvil.js',
    'script/outfit_drop/qualify-sphinx-airdrop.js', 'script/outfit_drop/simulate-safe-airdrop.js', 'script/outfit_drop/propose-sphinx-airdrop.js'];
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const loadedSources = Object.fromEntries(SOURCE_FILES.map(file => [file, sha256(fs.readFileSync(path.join(ROOT, file)))]));
const MODULE = new ethers.utils.Interface(require('@sphinx-labs/contracts').SphinxModuleABI);
const RELAY = new ethers.utils.Interface(['function exec(address,bytes)']);
const zeroRoot = ethers.constants.HashZero;
const providerFor = chain => require('./propose-sphinx-airdrop').providerFor(chain);

function assertSources() {
    for (const [file, hash] of Object.entries(loadedSources)) {
        assert.equal(sha256(fs.readFileSync(path.join(ROOT, file))), hash, 'Loaded chain-proof source changed; restart');
    }
}

function assertPolicyBinding(selected, timestamp, now = Math.floor(Date.now() / 1000)) {
    assertSources();
    assert.equal(selected.policySha256, sha256(fs.readFileSync(path.join(__dirname, 'gas-proof-policy.json'))), 'Loaded gas-proof policy differs from disk');
    policy.assertGasProofPolicyWindow(selected, timestamp);
    policy.assertGasProofPolicyWindow(selected, now);
}

function pinFor(config, chain) {
    return { blockNumber: Number(config.blockNumber), blockHash: chain.blockHash,
        blockTimestamp: chain.blockTimestamp, blockGasLimit: String(config.observedBlockGasLimit || config.blockGasLimit) };
}

async function selectProof(config, chain, { provider = providerFor(chain), resolveEngine = engine.resolveGasProofEngine } = {}) {
    const selected = policy.gasProofPolicyForChain(config.chainId);
    assertPolicyBinding(selected, chain.blockTimestamp);
    const rpcConfig = selected.backend === 'exact-root-fork' ? await provider.send('eth_config', []) : undefined;
    const reviewed = policy.selectGasProofPolicy({ chainId: config.chainId, finalizedTimestamp: chain.blockTimestamp, rpcConfig });
    const selection = { chainId: String(config.chainId), policy: reviewed, pin: pinFor(config, chain) };
    if (reviewed.backend === 'exact-root-fork') {
        selection.rpcConfig = rpcConfig;
        selection.engine = resolveEngine(reviewed);
        selection.outerGas = require('./simulate-safe-airdrop').gasBudget(config.chainId, selection.pin.blockGasLimit,
            { liveRpc: true, blockTimestamp: chain.blockTimestamp }).outerGasCap;
    }
    return selection;
}

async function selectProofs(entries, chains) {
    return Promise.all(entries.map(entry => selectProof(entry.networkConfig,
        chains.find(chain => String(chain.chainId) === String(entry.networkConfig.chainId)))));
}

async function assertSelectionFresh(selection, chain, { provider = providerFor(chain) } = {}) {
    assertPolicyBinding(selection.policy, selection.pin.blockTimestamp);
    if (selection.policy.backend !== 'exact-root-fork') return;
    policy.selectGasProofPolicy({ chainId: selection.chainId, finalizedTimestamp: selection.pin.blockTimestamp,
        rpcConfig: await provider.send('eth_config', []) });
    const header = await provider.send('eth_getBlockByNumber', [ethers.utils.hexValue(selection.pin.blockNumber), false]);
    assert(header && header.hash === selection.pin.blockHash, 'Fork proof public header changed');
    assert.equal(Number(BigInt(header.timestamp)), selection.pin.blockTimestamp, 'Fork proof public timestamp changed');
    assert.equal(BigInt(header.gasLimit).toString(), selection.pin.blockGasLimit, 'Fork proof public gas limit changed');
    engine.assertGasProofEngineUnchanged(selection.policy, selection.engine);
}

function forkOptions(selection) {
    if (selection.policy.backend !== 'exact-root-fork') return undefined;
    assertPolicyBinding(selection.policy, selection.pin.blockTimestamp);
    engine.assertGasProofEngineUnchanged(selection.policy, selection.engine);
    return engine.forkEngineOptions(selection.policy, selection.engine);
}

async function assertForkContext(context) {
    const selection = context.chainProof;
    if (selection?.policy.backend !== 'exact-root-fork') return;
    engine.assertGasProofEngineUnchanged(selection.policy, selection.engine);
    context.report.engineRuntime = engine.assertGasProofNodeInfo(selection.policy,
        await context.provider.send('anvil_nodeInfo', []), { chainId: context.config.chainId, blockNumber: context.config.blockNumber });
}

async function captureForkTransaction(context, receipt, requested) {
    const tx = await context.provider.getTransaction(receipt.transactionHash);
    assert(tx && requested, 'Fork proof lacks its actual/requested transaction');
    assert.equal(tx.hash, receipt.transactionHash, 'Fork transaction hash changed');
    assert.equal(tx.blockNumber, receipt.blockNumber, 'Fork transaction mined block changed');
    assert.equal(BigInt(requested.gas), BigInt(context.chainProof.outerGas), 'Fork requested gas differs from policy');
    for (const field of ['from', 'to']) assert.equal(tx[field].toLowerCase(), requested[field].toLowerCase(), `Fork transaction ${field} changed`);
    assert.equal(tx.data.toLowerCase(), requested.data.toLowerCase(), 'Fork transaction calldata changed');
    assert.equal(tx.value.toString(), BigInt(requested.value || 0).toString(), 'Fork transaction value changed');
    assert.equal(tx.gasLimit.toString(), BigInt(requested.gas).toString(), 'Fork transaction gas limit changed');
    const block = await context.provider.getBlock(receipt.blockNumber);
    assert(block && block.hash === receipt.blockHash && tx.blockHash === receipt.blockHash, 'Fork transaction receipt/header binding changed');
    assertPolicyBinding(context.chainProof.policy, block.timestamp);
    return { transactionHash: receipt.transactionHash, from: tx.from, to: tx.to, value: tx.value.toString(),
        data: tx.data, gasLimit: tx.gasLimit.toString(), blockNumber: receipt.blockNumber, blockHash: receipt.blockHash,
        blockTimestamp: block.timestamp };
}

function markPostconditions(context, mode) {
    if (context.chainProof?.policy.backend !== 'exact-root-fork') return;
    assert.equal(context.report.recipientsAndOutfitsVerified, true, 'Fork proof needs complete distribution postconditions');
    (context.report.forkPostconditions ||= []).push({ mode, recipientsAndOutfitsVerified: true, tokenCount: context.report.tokenCount });
}

function calldataFor(config, tree, index) {
    const leaf = tree.leavesWithProofs.find(entry => String(entry.leaf.chainId) === String(config.chainId)
        && Number(entry.leaf.index) === index && Number(entry.leaf.leafType) === 1);
    assert(leaf, 'Fork proof is missing its exact execution leaf');
    return RELAY.encodeFunctionData('exec', [config.moduleAddress, MODULE.encodeFunctionData('execute', [[leaf]])]);
}

function writeFile(directory, label, value) {
    const bytes = `${JSON.stringify(value, null, 2)}\n`, hash = sha256(bytes);
    const filename = `${label}-${hash}.json`;
    fs.writeFileSync(path.join(directory, filename), bytes, { flag: 'wx', mode: 0o444 });
    return { filename, sha256: hash };
}

function assertSelection(config, chain, selection) {
    assert.equal(selection.chainId, String(config.chainId), 'Proof selection chain changed');
    assert.deepEqual(selection.pin, pinFor(config, chain), 'Proof selection pin changed');
    assertPolicyBinding(selection.policy, chain.blockTimestamp);
    policy.selectGasProofPolicy({ chainId: config.chainId, finalizedTimestamp: chain.blockTimestamp, rpcConfig: selection.rpcConfig });
    if (selection.policy.backend === 'exact-root-fork') {
        engine.assertGasProofEngineUnchanged(selection.policy, selection.engine);
        assert.equal(selection.outerGas, require('./simulate-safe-airdrop').gasBudget(config.chainId, selection.pin.blockGasLimit,
            { liveRpc: true, blockTimestamp: chain.blockTimestamp }).outerGasCap, 'Fork proof outer budget changed');
    }
}

function validateForkProof(proof, config, chain, tree, selection, priorChain) {
    assert.equal(proof.format, FORMAT, 'Fork proof format changed');
    assert.equal(proof.kind, 'exact-root-fork', 'Fork proof kind changed');
    assert.equal(proof.status, 'passed', 'Fork proof is unfinished');
    assert.equal(proof.root, tree.root, 'Fork proof root changed');
    assert.deepEqual(proof.selection, selection, 'Fork proof policy/engine/pin changed');
    assertSelection(config, chain, selection);
    assert.deepEqual(proof.engineOptions, engine.forkEngineOptions(selection.policy, selection.engine), 'Fork proof engine options changed');
    engine.assertGasProofNodeInfo(selection.policy, proof.engineRuntime, { chainId: config.chainId, blockNumber: config.blockNumber });
    assert.deepEqual(proof.runtimeKeccak256, priorChain.runtimeKeccak256, 'Fork proof contract runtime changed');
    assert.equal(proof.initialSafeNonce, priorChain.safeNonce, 'Fork proof initial Safe nonce changed');
    assert.deepEqual(proof.completion, { status: 2, leavesExecuted: String(config.actionInputs.length + 1), activeRoot: zeroRoot,
        moduleNonce: (BigInt(config.nonce) + 1n).toString(), safeNonce: proof.initialSafeNonce }, 'Fork proof completion/nonce changed');
    assert.equal(proof.outerCaller.toLowerCase(), [...chain.authority.owners].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()))[0].toLowerCase(), 'Fork proof synthetic caller changed');
    const expectedCount = chain.envelopes.reduce((count, envelope) => count + envelope.expectedTokenIds.length, 0);
    assert.deepEqual(proof.postconditions, ['cold', 'sdk-singletons'].map(mode => ({ mode,
        recipientsAndOutfitsVerified: true, tokenCount: expectedCount })), 'Fork proof omitted a mode or distribution postconditions');
    const qualifier = require('./qualify-sphinx-airdrop');
    const limits = require('./simulate-safe-airdrop').gasBudget(config.chainId, selection.pin.blockGasLimit);
    for (const action of config.actionInputs) assert(BigInt(action.gas) > 0n && BigInt(action.gas) <= BigInt(limits.budget),
        'Fork proof signed gas exceeds the reviewed execution budget');
    for (const mode of ['cold', 'sdk-singletons']) {
        const records = proof.records.filter(record => record.mode === mode);
        assert.equal(records.length, config.actionInputs.length, 'Fork proof omitted execution records');
        const seenTransactions = new Set();
        let previousBlock = Number(config.blockNumber);
        for (const [position, action] of config.actionInputs.entries()) {
            const index = position + 1, record = records[position], last = index === config.actionInputs.length;
            assert.equal(record.root, tree.root); assert.deepEqual(record.indices, [index]);
            assert.equal(record.outerReceiptStatus, 1);
            assert(BigInt(record.receiptGasUsed) > 0n && BigInt(record.receiptGasUsed) <= BigInt(selection.outerGas), 'Fork receipt gas exceeds exact outer limit');
            assert(!record.failure && !record.firstFailureIndex, 'Fork proof contains an action failure');
            assert.equal(record.rootStatus, last ? 2 : 1, 'Fork proof root lifecycle changed');
            assert.equal(record.activeRoot, last ? zeroRoot : tree.root, 'Fork proof active root changed');
            assert.deepEqual(record.events.map(event => event.name), last
                ? ['SphinxActionSucceeded', 'SphinxMerkleRootCompleted'] : ['SphinxActionSucceeded']);
            assert.equal(record.events[0].index, String(index));
            for (const event of record.events) assert.equal(event.root, tree.root);
            const tx = record.transaction;
            assert(tx && tx.transactionHash === record.transactionHash && /^0x[\da-f]{64}$/i.test(tx.transactionHash), 'Fork proof transaction hash changed');
            assert(!seenTransactions.has(tx.transactionHash), 'Fork proof repeats a transaction'); seenTransactions.add(tx.transactionHash);
            assert.equal(tx.to.toLowerCase(), config.executorAddress.toLowerCase());
            assert.equal(tx.from.toLowerCase(), proof.outerCaller.toLowerCase());
            assert.equal(tx.data.toLowerCase(), calldataFor(config, tree, index).toLowerCase(), 'Fork proof calldata changed');
            assert.equal(tx.value, '0'); assert.equal(tx.gasLimit, String(selection.outerGas), 'Fork proof exact outer gas changed');
            assert(Number.isSafeInteger(tx.blockNumber) && tx.blockNumber > previousBlock && /^0x[\da-f]{64}$/i.test(tx.blockHash), 'Fork proof mined block/order is invalid');
            previousBlock = tx.blockNumber;
            assert(tx.blockTimestamp >= chain.blockTimestamp, 'Fork proof timestamp predates its pin');
            policy.assertGasProofPolicyWindow(selection.policy, tx.blockTimestamp);
            assert.equal(record.actions.length, 1);
            const measured = record.actions[0];
            assert.equal(measured.index, index); assert.equal(measured.actionDigest, qualifier.actionDigest(action));
            assert.equal(measured.signedGas, action.gas);
            assert(BigInt(measured.grossSafeGas) > 0n && BigInt(measured.grossSafeGas) <= BigInt(measured.signedGas), 'Fork proof gross frame gas is invalid');
            assert.equal(measured.headroom, qualifier.assertHeadroom(measured.signedGas, measured.grossSafeGas));
        }
    }
    assert.equal(proof.records.length, 2 * config.actionInputs.length, 'Fork proof has unsupported execution modes');
    return { chainId: String(config.chainId), proofBackend: 'exact-root-fork', safe: config.safeAddress,
        module: config.moduleAddress, executor: config.executorAddress, validFrom: selection.policy.validFrom,
        validUntil: selection.policy.validUntil, hardfork: selection.policy.hardfork,
        actions: config.actionInputs.map((action, i) => ({ index: i + 1, signedInnerGas: Number(action.gas),
            outerGas: selection.outerGas, calldataHash: ethers.utils.keccak256(calldataFor(config, tree, i + 1)) })) };
}

function normalizeRpc(report) {
    return { chainId: report.chain_id, proofBackend: 'live-rpc', safe: report.safe, module: report.module, executor: report.executor,
        actions: report.actions.map(action => ({ index: action.index, signedInnerGas: action.signed_inner_gas,
            outerGas: action.outer_gas, calldataHash: action.calldata_hash })) };
}

async function qualifyRpc(configs, chains, selections, tree, directory, sizing) {
    const indices = configs.map((_, index) => index).filter(index => selections[index].policy.backend === 'live-rpc');
    if (!indices.length) return [];
    const proved = await live.qualify('final', indices.map(i => configs[i]), chains, directory, {
        reports: indices.map(i => sizing.reports[i]), tree, identity: sizing.identity, allowOuterSeedRetry: true });
    return indices.map((i, n) => ({ chainId: String(configs[i].chainId), file: writeFile(directory, `chain-rpc-proof-${configs[i].chainId}`,
        { format: FORMAT, kind: 'live-rpc', status: 'passed', root: tree.root, selection: selections[i], rpcEvidence: proved.files[n] }) }));
}

async function writeForkProof(context, config, chain, tree, directory, records) {
    await assertForkContext(context);
    await assertSelectionFresh(context.chainProof, chain);
    const observedRuntime = Object.fromEntries(await Promise.all([['safe', config.safeAddress], ['moduleProxy', config.moduleAddress],
        ['relay', config.executorAddress]].map(async ([name, address]) => [name, ethers.utils.keccak256(await context.provider.getCode(address))])));
    assert.deepEqual(observedRuntime, context.report.runtimeKeccak256, 'Fork proof contract runtime changed after execution');
    const state = await context.module.merkleRootStates(tree.root);
    const proof = { format: FORMAT, kind: 'exact-root-fork', status: 'passed', root: tree.root,
        selection: context.chainProof, engineRuntime: context.report.engineRuntime,
        engineOptions: engine.forkEngineOptions(context.chainProof.policy, context.chainProof.engine),
        runtimeKeccak256: context.report.runtimeKeccak256, outerCaller: context.owners[0], initialSafeNonce: context.safeNonce,
        completion: { status: Number(state.status), leavesExecuted: state.leavesExecuted.toString(),
            activeRoot: await context.module.activeMerkleRoot(), moduleNonce: (await context.module.merkleRootNonce()).toString(),
            safeNonce: (await context.safe.nonce()).toString() },
        records, postconditions: context.report.forkPostconditions };
    const normalized = validateForkProof(proof, config, chain, tree, context.chainProof, context.report);
    return { chainId: String(config.chainId), file: writeFile(directory, `chain-fork-proof-${config.chainId}`, proof), normalized };
}

async function assertEvidence(artifact, directory, { readProvenance = live.provenance } = {}) {
    assertSources();
    const bytes = fs.readFileSync(path.join(directory, 'qualification.json'));
    assert.equal(sha256(bytes), artifact.qualificationSha256, 'Chain qualification checksum changed');
    const q = JSON.parse(bytes);
    assert.equal(q.status, 'passed'); assert.equal(q.gasEstimator, ESTIMATOR, 'Chain proof estimator changed');
    for (const file of SOURCE_FILES) assert.equal(q.sourceSha256[file], loadedSources[file], 'Chain proof source coverage/identity changed');
    for (const [file, hash] of Object.entries(q.sourceSha256)) assert.equal(sha256(fs.readFileSync(path.join(ROOT, file))), hash, 'Qualified chain-proof source changed');
    assert.equal(artifact.segments.length, 1); const segment = artifact.segments[0];
    assert.deepEqual(await readProvenance(), q.nativeSizing.identity, 'Current sizing provenance changed');
    assert.equal(q.finalProofs.length, segment.networkConfigs.length, 'Missing chain proofs');
    assert.deepEqual(q.finalProofs.map(proof => proof.chainId), segment.networkConfigs.map(config => String(config.chainId)), 'Chain proof coverage/order changed');
    const proofs = segment.networkConfigs.map((config, index) => {
        const chain = artifact.preparedChains.find(item => String(item.chainId) === String(config.chainId));
        const selection = q.proofSelections[index]; assertSelection(config, chain, selection);
        assert.equal(q.chains.find(item => item.chainId === String(config.chainId)).status, 'passed', 'Chain postconditions are unfinished');
        const proof = live.readEvidence(directory, q.finalProofs[index].file);
        assert.equal(proof.format, FORMAT); assert.equal(proof.kind, selection.policy.backend); assert.equal(proof.status, 'passed');
        assert.equal(proof.root, segment.merkleTree.root); assert.deepEqual(proof.selection, selection);
        if (proof.kind === 'exact-root-fork') return validateForkProof(proof, config, chain, segment.merkleTree, selection,
            q.chains.find(item => item.chainId === String(config.chainId)));
        return normalizeRpc(live.assertChainEvidence(config, chain, segment.merkleTree, q.nativeSizing.identity, directory, proof.rpcEvidence));
    });
    return { qualification: q, proofs };
}

function handoffTemplate(artifact, proofs) {
    return { schemaVersion: 2, root: artifact.segments[0].merkleTree.root, qualificationSha256: artifact.qualificationSha256,
        acknowledged: false, executionShape: 'one execution leaf per transaction', approvalGasQualified: false,
        networks: proofs, acknowledgement: 'The executor must apply this exact root, per-action outer gas and singleton shape. Fork proofs are valid only in their stated review windows; execute before expiry or requalify. Synthetic approvals do not qualify owner signatures, approval gas, relay funding or hosted execution.' };
}

async function assertHandoff(artifact, directory) {
    const { proofs } = await assertEvidence(artifact, directory);
    const filename = path.resolve(process.env.BANNY_SPHINX_EXECUTOR_HANDOFF_FILE || path.join(directory, 'executor-handoff.json'));
    const actual = JSON.parse(fs.readFileSync(filename));
    assert.equal(actual.acknowledged, true, 'Exact chain-proof executor handoff acknowledgement required');
    assert.deepEqual({ ...actual, acknowledged: false }, handoffTemplate(artifact, proofs), 'Executor handoff proof/backend/budgets changed');
    return { filename, sha256: sha256(fs.readFileSync(filename)) };
}

async function replay(artifact, directory, part, { verifyEvidence = assertEvidence, replayRpc = live.replay,
    replayLocal = (...args) => require('./qualify-sphinx-airdrop').replayPreparedPart(...args) } = {}) {
    const prior = await verifyEvidence(artifact, directory);
    const segment = artifact.segments[0];
    const indices = segment.networkConfigs.map((_, i) => i).filter(i => prior.qualification.proofSelections[i].policy.backend === 'live-rpc');
    if (indices.length) {
        const rpcArtifact = { ...artifact, segments: [{ ...segment, networkConfigs: indices.map(i => segment.networkConfigs[i]) }] };
        await replayRpc(rpcArtifact, directory, { verifyEvidence: async () => ({ qualification: { liveRpc: { identity: prior.qualification.nativeSizing.identity } },
            reports: indices.map(i => live.assertChainEvidence(segment.networkConfigs[i],
                artifact.preparedChains.find(chain => String(chain.chainId) === String(segment.networkConfigs[i].chainId)), segment.merkleTree,
                prior.qualification.nativeSizing.identity, directory, live.readEvidence(directory, prior.qualification.finalProofs[i].file).rpcEvidence)) }) });
    }
    const local = await replayLocal(artifact, directory, part,
        { multipleExecutionTransactions: true, liveRpc: true, chainAware: true });
    assert.equal(local.report.status, 'passed', 'Fresh chain replay is unfinished');
    const expectedForks = prior.proofs.filter(proof => proof.proofBackend === 'exact-root-fork').map(proof => proof.chainId).sort();
    assert.deepEqual((local.report.forkProofs || []).map(item => item.normalized.chainId).sort(), expectedForks,
        'Fresh fork proof coverage changed');
    for (const item of local.report.forkProofs || []) {
        const old = prior.proofs.find(proof => proof.chainId === item.normalized.chainId);
        assert.deepEqual(item.normalized.actions, old.actions, 'Fresh fork proof changed frozen outer budgets or canonical actions');
    }
    await verifyEvidence(artifact, directory);
    return local;
}

module.exports = { FORMAT, ESTIMATOR, SOURCE_FILES, assertSources, assertPolicyBinding, selectProof, selectProofs, assertSelectionFresh,
    forkOptions, assertForkContext, captureForkTransaction, markPostconditions, calldataFor, validateForkProof, normalizeRpc,
    qualifyRpc, writeForkProof, assertEvidence, handoffTemplate, assertHandoff, replay };
