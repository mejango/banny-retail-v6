'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { test, before, after } = require('node:test');
const { ethers } = require('ethers');
const core = require('@sphinx-labs/core');
const contracts = require('@sphinx-labs/contracts');
const owner = require('./qualify-chain-gas');
const live = require('./qualify-resolver-live-rpc');
const engine = require('./gas-proof-engine');
const rules = require('./gas-proof-policy');
const policyJson = require('./gas-proof-policy.json');
const { networksFor } = require('./export-safe-airdrop');
const { actionDigest } = require('./qualify-sphinx-airdrop');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const SAFE = '0x0000000000000000000000000000000000000001';
const MODULE = '0x0000000000000000000000000000000000000002';
const TARGET = '0x0000000000000000000000000000000000000003';
const stamp = 1793300000;
const oldClock = Date.now, oldEngineCheck = engine.assertGasProofEngineUnchanged;
before(() => {
    Date.now = () => stamp * 1000;
    engine.assertGasProofEngineUnchanged = (selected, identity) => { rules.assertGasProofEngineIdentity(selected, identity); return identity; };
});
after(() => { Date.now = oldClock; engine.assertGasProofEngineUnchanged = oldEngineCheck; });

function fixture(chainId = 1) {
    const config = { chainId: String(chainId), nonce: '8', safeAddress: SAFE, moduleAddress: MODULE,
        executorAddress: contracts.getPermissionlessRelayAddress(), safeInitData: '0x', arbitraryChain: false,
        blockNumber: '100', blockGasLimit: '19922943', observedBlockGasLimit: '60000000', libraries: [], gitCommit: null,
        initialState: { isSafeDeployed: true, isModuleDeployed: true, isExecuting: false }, isSystemDeployed: true,
        newConfig: { projectName: 'banny-core', orgId: 'org', owners: [SAFE], threshold: '1', saltNonce: '0', mainnets: ['ethereum'], testnets: [] },
        actionInputs: [1, 2].map(index => ({ index: String(index), actionType: core.ActionInputType.CALL, to: TARGET,
            value: '0', txData: `0x1234${index.toString(16).padStart(2, '0')}`, gas: '1000000', operation: 1, requireSuccess: true, contracts: [] })) };
    const chain = { chainId, blockHash: ethers.utils.id(`pin-${chainId}`), blockTimestamp: stamp,
        network: networksFor('mainnets', chainId)[0], authority: { owners: [SAFE], threshold: '1' },
        envelopes: [{ stage: 'setup', expectedTokenIds: [] }, { stage: 'migration', expectedTokenIds: [1, 2] }] };
    const selected = rules.gasProofPolicyForChain(chainId);
    const identity = selected.engine ? { binary: '/approved/anvil', platform: 'darwin', arch: 'arm64',
        release: selected.engine.release, tagCommit: selected.engine.tagCommit, version: 'approved',
        binarySha256: selected.engine.platforms['darwin-arm64'].binarySha256 } : undefined;
    const selection = { chainId: String(chainId), policy: selected,
        pin: { blockNumber: 100, blockHash: chain.blockHash, blockTimestamp: stamp, blockGasLimit: '60000000' },
        ...(identity ? { engine: identity, rpcConfig: policyJson.forks[chainId].rpcConfig, outerGas: 16_777_216 } : {}) };
    const prior = { chainId: String(chainId), safeNonce: '4', status: 'passed', runtimeKeccak256: { safe: 'safe', moduleProxy: 'module', relay: 'relay' } };
    return { config, chain, selection, prior };
}

function forkProof(f, tree) {
    return { format: owner.FORMAT, kind: 'exact-root-fork', status: 'passed', root: tree.root, selection: f.selection,
        engineRuntime: { network: f.chain.chainId === 8453 ? 'base' : 'ethereum', hardFork: f.chain.chainId === 8453 ? 'Cobalt' : 'Osaka',
            environment: { chainId: f.chain.chainId }, forkConfig: { forkBlockNumber: 100 } },
        engineOptions: engine.forkEngineOptions(f.selection.policy, f.selection.engine),
        runtimeKeccak256: f.prior.runtimeKeccak256, initialSafeNonce: '4', outerCaller: SAFE,
        completion: { status: 2, leavesExecuted: '3', activeRoot: ethers.constants.HashZero, moduleNonce: '9', safeNonce: '4' },
        postconditions: ['cold', 'sdk-singletons'].map(mode => ({ mode, recipientsAndOutfitsVerified: true, tokenCount: 2 })),
        records: ['cold', 'sdk-singletons'].flatMap(mode => f.config.actionInputs.map((action, i) => ({ root: tree.root,
            mode, indices: [i + 1], transactionHash: ethers.utils.id(`${mode}-${i}`), outerReceiptStatus: 1, receiptGasUsed: '1000000',
            rootStatus: i === 1 ? 2 : 1, activeRoot: i === 1 ? ethers.constants.HashZero : tree.root,
            events: [{ name: 'SphinxActionSucceeded', root: tree.root, index: String(i + 1) },
                ...(i === 1 ? [{ name: 'SphinxMerkleRootCompleted', root: tree.root }] : [])],
            transaction: { transactionHash: ethers.utils.id(`${mode}-${i}`), from: SAFE, to: f.config.executorAddress,
                value: '0', data: owner.calldataFor(f.config, tree, i + 1), gasLimit: '16777216',
                blockNumber: 103 + i, blockHash: ethers.utils.id(`block-${mode}-${i}`), blockTimestamp: stamp + i + 1 },
            actions: [{ index: i + 1, actionDigest: actionDigest(action), signedGas: action.gas, grossSafeGas: '800000', headroom: (BigInt(action.gas) - 800000n).toString() }] }))) };
}

function write(directory, label, value) {
    const bytes = JSON.stringify(value); const filename = `${label}-${hash(bytes)}.json`;
    fs.writeFileSync(path.join(directory, filename), bytes); return { filename, sha256: hash(bytes) };
}

test('backend is selected before execution and RPC failure never selects a fork', async () => {
    const f = fixture(); const calls = [];
    const provider = { send: async method => { calls.push(method); return policyJson.forks[1].rpcConfig; } };
    const selected = await owner.selectProof(f.config, f.chain, { provider,
        resolveEngine: policy => { calls.push('engine'); assert.equal(policy.backend, 'exact-root-fork'); return f.selection.engine; } });
    assert.deepEqual(selected, f.selection); assert.deepEqual(calls, ['eth_config', 'engine']);
    await assert.rejects(owner.selectProof(f.config, f.chain, { provider: { send: async () => { throw Error('RPC failure'); } },
        resolveEngine: () => assert.fail('No fallback engine after config failure') }), /RPC failure/);
    const rpc = fixture(10);
    assert.equal((await owner.selectProof(rpc.config, rpc.chain, { provider: { send: async () => assert.fail('No fork config for strict RPC') } })).policy.backend, 'live-rpc');
    assert.throws(() => owner.assertPolicyBinding(f.selection.policy, stamp, f.selection.policy.validUntil), /outside/);
});

test('typed fork evidence binds both full modes, exact gas, root, lifecycle, engine and every postcondition', () => {
    for (const chainId of [1, 8453]) {
        const f = fixture(chainId), tree = contracts.makeSphinxMerkleTree(core.makeDeploymentData([f.config]));
        const proof = forkProof(f, tree);
        const validated = owner.validateForkProof(proof, f.config, f.chain, tree, f.selection, f.prior);
        assert.equal(validated.proofBackend, 'exact-root-fork'); assert.equal(validated.actions.length, 2);
        const oversized = fixture(chainId); oversized.config.actionInputs[0].gas = '16000000';
        const oversizedTree = contracts.makeSphinxMerkleTree(core.makeDeploymentData([oversized.config]));
        assert.throws(() => owner.validateForkProof(forkProof(oversized, oversizedTree), oversized.config, oversized.chain,
            oversizedTree, oversized.selection, oversized.prior), /signed gas exceeds/);
        for (const change of [p => { p.root = ethers.constants.HashZero; }, p => { p.engineRuntime.hardFork = 'Beryl'; },
            p => { p.records.pop(); }, p => { p.postconditions.pop(); }, p => { p.completion.moduleNonce = '8'; },
            p => { p.records[0].transaction.gasLimit = '16777217'; }, p => { p.records[0].transaction.data = '0x'; },
            p => { p.records[0].receiptGasUsed = '16777217'; }, p => { p.records[0].actions[0].grossSafeGas = '0'; },
            p => { p.records[1].transaction.transactionHash = p.records[0].transaction.transactionHash; p.records[1].transactionHash = p.records[0].transactionHash; },
            p => { p.records[1].transaction.blockNumber = p.records[0].transaction.blockNumber; },
            p => { p.records[0].transaction.blockTimestamp = stamp - 1; }, p => { p.records[0].events[0].index = '2'; }]) {
            const changed = structuredClone(proof); change(changed);
            assert.throws(() => owner.validateForkProof(changed, f.config, f.chain, tree, f.selection, f.prior));
        }
    }
});

test('fork transaction readback rejects changed sender, destination, value, calldata, gas or receipt binding', async () => {
    const f = fixture(); const receipt = { transactionHash: ethers.utils.id('tx'), blockNumber: 101, blockHash: ethers.utils.id('block') };
    const requested = { from: SAFE, to: f.config.executorAddress, value: '0x0', data: '0x1234', gas: '0x1000000' };
    const actual = { ...requested, hash: receipt.transactionHash, blockNumber: receipt.blockNumber, data: requested.data, gasLimit: ethers.BigNumber.from(requested.gas), value: ethers.BigNumber.from(0), blockHash: receipt.blockHash };
    let tx = actual, block = { hash: receipt.blockHash, timestamp: stamp + 1 };
    const context = { chainProof: f.selection, provider: { getTransaction: async () => tx, getBlock: async () => block } };
    assert.equal((await owner.captureForkTransaction(context, receipt, requested)).gasLimit, '16777216');
    for (const change of [{ from: TARGET }, { to: TARGET }, { value: ethers.BigNumber.from(1) }, { data: '0x' },
        { gasLimit: ethers.BigNumber.from(16_777_215) }, { hash: ethers.constants.HashZero }, { blockNumber: 999 }, { blockHash: ethers.constants.HashZero }]) {
        tx = { ...actual, ...change }; await assert.rejects(owner.captureForkTransaction(context, receipt, requested));
    }
    tx = actual; block = { ...block, hash: ethers.constants.HashZero };
    await assert.rejects(owner.captureForkTransaction(context, receipt, requested));
});

test('loaded policy bytes cannot certify changed disk policy', () => {
    const f = fixture(), read = fs.readFileSync;
    try {
        fs.readFileSync = (file, ...args) => String(file).endsWith('/gas-proof-policy.json') ? Buffer.from('changed') : read(file, ...args);
        assert.throws(() => owner.assertPolicyBinding(f.selection.policy, stamp), /source changed|differs from disk/);
    } finally { fs.readFileSync = read; }
});

test('mixed handoff exposes backend and bounded validity and is not a Rust-shaped fork response', () => {
    const f = fixture(), tree = contracts.makeSphinxMerkleTree(core.makeDeploymentData([f.config]));
    const proof = forkProof(f, tree), normalized = owner.validateForkProof(proof, f.config, f.chain, tree, f.selection, f.prior);
    assert.equal(proof.response, undefined); assert.equal(proof.rpcEvidence, undefined);
    const handoff = owner.handoffTemplate({ segments: [{ merkleTree: tree }], qualificationSha256: 'qualified' }, [normalized]);
    assert.equal(handoff.schemaVersion, 2); assert.equal(handoff.acknowledged, false);
    assert.equal(handoff.networks[0].proofBackend, 'exact-root-fork'); assert.equal(handoff.networks[0].validUntil, f.selection.policy.validUntil);
    assert.equal(handoff.approvalGasQualified, false);
});

function mixedFixture(directory) {
    const fork = fixture(1), rpc = fixture(10), configs = [fork.config, rpc.config], chains = [fork.chain, rpc.chain];
    const tree = contracts.makeSphinxMerkleTree(core.makeDeploymentData(configs));
    const nativeIdentity = { binary: '/fixture/bridge', binarySha256: hash('bridge'), schemaVersion: 1,
        clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, sourceSha256: {} };
    const report = { chain_id: '10', block_number: 100, block_hash: rpc.chain.blockHash, base_timestamp: stamp,
        simulated_block_interval_seconds: 1, safe: SAFE, module: MODULE, executor: rpc.config.executorAddress,
        authorization_scope: live.AUTHORIZATION_SCOPE, execution_shape: 'one execution leaf per transaction; exact outer budgets required',
        final_merkle_root: tree.root, actions: rpc.config.actionInputs.map((action, i) => ({ index: i + 1,
            signed_inner_gas: Number(action.gas), outer_gas: 2_000_000,
            calldata_hash: ethers.utils.keccak256(owner.calldataFor(rpc.config, tree, i + 1)), final_proof_attempts: 1 })) };
    const request = { schemaVersion: 1, clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, mode: 'final',
        networks: [{ rpcEnv: rpc.chain.network.rpc, expectedBlockHash: rpc.chain.blockHash, expectedBlockTimestamp: stamp,
            config: live.rustConfig(rpc.config, rpc.chain), report: { ...report, final_merkle_root: null } }], tree: live.rustTree(tree) };
    const rpcEvidence = write(directory, 'rpc-evidence', { status: 'passed', identity: nativeIdentity,
        request: write(directory, 'rpc-request', request), response: { results: [{ config: live.rustConfig(rpc.config, rpc.chain), report }] } });
    const q = { status: 'passed', gasEstimator: owner.ESTIMATOR, sourceSha256: Object.fromEntries(owner.SOURCE_FILES.map(file =>
        [file, hash(fs.readFileSync(path.resolve(__dirname, '../..', file)))])), nativeSizing: { identity: nativeIdentity },
        proofSelections: [fork.selection, rpc.selection], chains: [fork.prior, rpc.prior],
        finalProofs: [{ chainId: '1', file: write(directory, 'fork', forkProof(fork, tree)) },
            { chainId: '10', file: write(directory, 'rpc-wrapper', { format: owner.FORMAT, kind: 'live-rpc', status: 'passed',
                root: tree.root, selection: rpc.selection, rpcEvidence }) }] };
    fs.writeFileSync(path.join(directory, 'qualification.json'), JSON.stringify(q));
    return { artifact: { preparedChains: chains, segments: [{ networkConfigs: configs, merkleTree: tree }],
        qualificationSha256: hash(fs.readFileSync(path.join(directory, 'qualification.json'))) }, q, nativeIdentity, rpcReport: report,
    };
}

test('mixed evidence preserves strict RPC validation and rejects backend/root/coverage downgrades', async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-mixed-proof-'));
    try {
        const f = mixedFixture(directory), deps = { readProvenance: async () => f.nativeIdentity };
        const verified = await owner.assertEvidence(f.artifact, directory, deps);
        assert.deepEqual(verified.proofs.map(proof => proof.proofBackend), ['exact-root-fork', 'live-rpc']);
        const wrapper = live.readEvidence(directory, f.q.finalProofs[1].file);
        const wrong = { ...wrapper, kind: 'exact-root-fork' };
        f.q.finalProofs[1].file = write(directory, 'wrong-kind', wrong);
        fs.writeFileSync(path.join(directory, 'qualification.json'), JSON.stringify(f.q));
        f.artifact.qualificationSha256 = hash(fs.readFileSync(path.join(directory, 'qualification.json')));
        await assert.rejects(owner.assertEvidence(f.artifact, directory, deps));
        f.q.finalProofs[1].file = write(directory, 'restored-wrapper', wrapper);
        const evidence = live.readEvidence(directory, wrapper.rpcEvidence);
        evidence.response.results[0].report.actions[0].calldata_hash = ethers.constants.HashZero;
        wrapper.rpcEvidence = write(directory, 'tampered-rpc', evidence);
        f.q.finalProofs[1].file = write(directory, 'tampered-wrapper', wrapper);
        fs.writeFileSync(path.join(directory, 'qualification.json'), JSON.stringify(f.q));
        f.artifact.qualificationSha256 = hash(fs.readFileSync(path.join(directory, 'qualification.json')));
        await assert.rejects(owner.assertEvidence(f.artifact, directory, deps), /calldata hash changed/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('mixed replay keeps RPC-before-local ordering, default postconditions and exact fresh fork coverage/budgets', async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-mixed-replay-'));
    try {
        const f = mixedFixture(directory), prior = await owner.assertEvidence(f.artifact, directory,
            { readProvenance: async () => f.nativeIdentity });
        const calls = [];
        const deps = { verifyEvidence: async () => prior,
            replayRpc: async (artifact, dir, options) => {
                calls.push('rpc'); assert.equal(dir, directory);
                assert.deepEqual(artifact.segments[0].networkConfigs.map(c => c.chainId), ['10']);
                assert.equal(artifact.segments[0].merkleTree.root, f.artifact.segments[0].merkleTree.root);
                assert.deepEqual((await options.verifyEvidence()).reports, [f.rpcReport]);
            },
            replayLocal: async (artifact, dir, part, options) => {
                calls.push('local'); assert.equal(artifact, f.artifact); assert.equal(dir, directory); assert.equal(part, 0);
                assert.deepEqual(options, { multipleExecutionTransactions: true, liveRpc: true, chainAware: true });
                assert.equal(options.validatePrepared, undefined); assert.equal(options.verifyFinal, undefined);
                return { report: { status: 'passed', forkProofs: [{ normalized: prior.proofs[0] }] } };
            } };
        await owner.replay(f.artifact, directory, 0, deps); assert.deepEqual(calls, ['rpc', 'local']);
        await assert.rejects(owner.replay(f.artifact, directory, 0, { ...deps,
            replayRpc: async () => { throw Error('strict RPC failed'); }, replayLocal: async () => assert.fail('No local fallback') }), /strict RPC failed/);
        for (const proofResult of [[], [{ normalized: { ...prior.proofs[0], actions: [] } }],
            [{ normalized: prior.proofs[0] }, { normalized: prior.proofs[0] }]]) {
            await assert.rejects(owner.replay(f.artifact, directory, 0, { ...deps,
                replayLocal: async () => ({ report: { status: 'passed', forkProofs: proofResult } }) }), /coverage changed|frozen outer budgets/);
        }
        const changed = structuredClone(prior.proofs[0]); changed.actions[0].outerGas--;
        await assert.rejects(owner.replay(f.artifact, directory, 0, { ...deps,
            replayLocal: async () => ({ report: { status: 'passed', forkProofs: [{ normalized: changed }] } }) }), /frozen outer budgets/);
        await assert.rejects(owner.replay(f.artifact, directory, 0, { ...deps,
            replayLocal: async () => ({ report: { status: 'running', forkProofs: [] } }) }), /unfinished/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
