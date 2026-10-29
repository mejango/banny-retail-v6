const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { test } = require('node:test');
const { ethers } = require('ethers');
const core = require('@sphinx-labs/core');
const contracts = require('@sphinx-labs/contracts');
const live = require('./qualify-resolver-live-rpc');
const adapter = require('./propose-sphinx-resolver-upgrade');
const { networksFor } = require('./export-safe-airdrop');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

function fixture() {
    const safe = '0x0000000000000000000000000000000000000001';
    const config = { safeAddress: safe, moduleAddress: '0x0000000000000000000000000000000000000002',
        executorAddress: contracts.getPermissionlessRelayAddress(), safeInitData: '0x', chainId: '11155111', nonce: '7',
        blockNumber: '100', blockGasLimit: '19922943', observedBlockGasLimit: '200000000', arbitraryChain: false,
        initialState: { isSafeDeployed: true, isModuleDeployed: true, isExecuting: false }, isSystemDeployed: true,
        libraries: [], gitCommit: null,
        newConfig: { projectName: 'banny-core', orgId: 'org', owners: [safe], threshold: '1', saltNonce: '0',
            mainnets: [], testnets: ['ethereum_sepolia'] },
        actionInputs: [10_000_000, 7_000_000].map((gas, index) => ({ index: String(index + 1),
            actionType: core.ActionInputType.CALL, to: safe, value: '0', gas: String(gas),
            txData: index ? '0x5678' : '0x1234', operation: 1, requireSuccess: true, contracts: [] })) };
    const chain = { chainId: 11155111, blockHash: ethers.utils.id('pinned'), blockTimestamp: 1791294816,
        network: networksFor('testnets', 11155111)[0] };
    const tree = contracts.makeSphinxMerkleTree(core.makeDeploymentData([config]));
    const module = new ethers.utils.Interface(require('@sphinx-labs/contracts/contract-artifacts/sphinx/SphinxModule.sol/SphinxModule.json').abi);
    const relay = new ethers.utils.Interface(['function exec(address,bytes)']);
    const report = { chain_id: config.chainId, block_number: 100, block_hash: chain.blockHash, base_timestamp: chain.blockTimestamp,
        simulated_block_interval_seconds: 1, safe, module: config.moduleAddress, executor: config.executorAddress,
        authorization_scope: live.AUTHORIZATION_SCOPE,
        execution_shape: 'one execution leaf per transaction; exact outer budgets required', final_merkle_root: tree.root,
        actions: config.actionInputs.map((action, index) => {
            const leaf = tree.leavesWithProofs.find(entry => Number(entry.leaf.index) === index + 1);
            return { index: index + 1, signed_inner_gas: Number(action.gas), outer_gas: Number(action.gas) + 1_000_000,
                calldata_hash: ethers.utils.keccak256(relay.encodeFunctionData('exec', [config.moduleAddress,
                    module.encodeFunctionData('execute', [[leaf]])])), initial_probe_attempts: 1, final_proof_attempts: 1 };
        }) };
    const result = { config: live.rustConfig(config, chain), report };
    const identity = { binary: '/fixture/bridge', binarySha256: hash('binary'), schemaVersion: 1,
        clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, sourceSha256: {} };
    return { config, chain, tree, result, identity };
}

test('bridge provenance binds compiled source rather than only a constant client revision', () => {
    const bridge = 'script/outfit_drop/live-rpc-bridge';
    const files = ['Cargo.toml', 'Cargo.lock', 'src/main.rs'];
    const sourceSha256 = Object.fromEntries(files.map(file => [
        `${bridge}/${file}`, hash(fs.readFileSync(path.join(__dirname, 'live-rpc-bridge', file))),
    ]));
    const version = { schemaVersion: 1, clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, bridgeVersion: '0.1.0',
        compiledSourceSha256: Object.fromEntries(files.map(file => [file, sourceSha256[`${bridge}/${file}`]])) };
    assert.doesNotThrow(() => live.assertCompiledVersion(version, sourceSha256));
    assert.throws(() => live.assertCompiledVersion({ ...version, verifierRevision: live.CLIENT_REVISION }, sourceSha256), /compiled source changed/);
    const stale = { ...version }; delete stale.compiledSourceSha256;
    assert.throws(() => live.assertCompiledVersion(stale, sourceSha256), /compiled source changed.*build:sphinx:live/);
    for (const file of files) {
        const changedDisk = { ...sourceSha256, [`${bridge}/${file}`]: hash(`changed ${file}`) };
        assert.throws(() => live.assertCompiledVersion(version, changedDisk), /compiled source changed/);
        const changedBinary = structuredClone(version);
        changedBinary.compiledSourceSha256[file] = hash(`stale ${file}`);
        assert.throws(() => live.assertCompiledVersion(changedBinary, sourceSha256), /compiled source changed/);
    }
    assert.throws(() => live.assertCompiledVersion(version, {}), /source hashes missing/);
});

test('version metadata remains bound to the binary hashed before its asynchronous execution', async () => {
    const bridge = 'script/outfit_drop/live-rpc-bridge';
    const version = { schemaVersion: 1, clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, bridgeVersion: '0.1.0',
        compiledSourceSha256: Object.fromEntries(['Cargo.toml', 'Cargo.lock', 'src/main.rs'].map(file =>
            [file, hash(fs.readFileSync(path.join(__dirname, 'live-rpc-bridge', file)))])) };
    let reads = 0, current = hash('original binary');
    const readBinarySha256 = binary => {
        assert(binary.endsWith(`${bridge}/target/debug/banny-resolver-live-rpc-bridge`));
        reads++; return current;
    };
    const stable = await live.provenance({ readBinarySha256, run: async (_binary, args) => {
        assert.deepEqual(args, ['--version']); assert.equal(reads, 1); return version;
    } });
    assert.equal(stable.binarySha256, hash('original binary'));
    assert.equal(reads, 2);
    reads = 0;
    await assert.rejects(live.provenance({ readBinarySha256, run: async () => {
        assert.equal(reads, 1);
        current = hash('replacement after version execution');
        // The old process still returns matching metadata, but its path now names another binary.
        return version;
    } }), /binary changed while checking version provenance/);
    assert.equal(reads, 2);
});

test('resolver bridge wire preserves exact SDK leaf bytes and rejects an Anvil estimator', () => {
    const { config, chain, tree } = fixture();
    const wire = live.rustConfig(config, chain);
    assert.equal(wire.chain_id, '0xaa36a7');
    assert.equal(wire.action_inputs[0].operation, 'DelegateCall');
    assert.equal(wire.action_inputs[0].action_type, 'Call');
    const projected = live.rustTree(tree);
    const rustFixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'live-rpc-bridge/tests/sdk-wire.json')));
    assert.deepEqual(rustFixture.networks[0].config, wire, 'Rust oracle drifted from the installed SDK fixture');
    assert.deepEqual(rustFixture.tree, projected, 'Rust oracle no longer matches SDK leaf bytes/proofs');
    assert.equal(projected.root, tree.root);
    assert.deepEqual(projected.leaves_with_proofs.map(entry => entry.leaf.data), tree.leavesWithProofs.map(entry => entry.leaf.data));
    assert.deepEqual(projected.leaves_with_proofs.map(entry => entry.proof), tree.leavesWithProofs.map(entry => entry.proof));
    assert.deepEqual(adapter.resolverArgs(['propose', '--gas-estimator', 'live-rpc', '--dry-run']), ['propose', '--dry-run']);
    assert.deepEqual(adapter.resolverArgs(['resume', '--gas-estimator=live-rpc', 'directory']), ['resume', 'directory']);
    assert.throws(() => adapter.resolverArgs(['propose', '--gas-estimator', 'anvil']), /no Anvil fallback/);
});

test('live caps may change at estimation, while final proof freezes every signed field', () => {
    const { config, chain, tree, result } = fixture();
    assert.deepEqual(live.validateResult(result, config, chain, 'final', tree), config);
    const estimate = structuredClone(result);
    estimate.config.action_inputs[0].gas = '0xb71b00'; // 12,000,000
    estimate.report.actions[0].signed_inner_gas = 12_000_000;
    estimate.report.actions[0].outer_gas = 13_000_000;
    estimate.report.final_merkle_root = null;
    assert.equal(live.validateResult(estimate, config, chain, 'estimate').actionInputs[0].gas, '12000000');
    // A validated state reservoir is separate from the signed execution cap.
    estimate.report.actions[0].outer_gas = 40_000_000;
    assert.equal(live.validateResult(estimate, config, chain, 'estimate').actionInputs[0].gas, '12000000');
    const { gasBudget } = require('./simulate-safe-airdrop');
    assert.deepEqual(gasBudget(config.chainId, config.observedBlockGasLimit),
        { executionGasCap: 16_777_216, budget: 15_938_355, headroomPercent: 5 });
    assert.equal(gasBudget(config.chainId, config.observedBlockGasLimit, { liveRpc: true, blockTimestamp: chain.blockTimestamp }).outerGasCap, 200_000_000);
    assert.throws(() => live.validateResult(estimate, config, chain, 'final', tree), /frozen signed gas/);
    for (const change of [r => { r.config.nonce = '0x8'; }, r => { r.config.action_inputs[1].tx_data = '0x'; },
        r => { r.config.action_inputs.reverse(); }, r => { r.config.safe_address = r.config.module_address; },
        r => { r.report.block_hash = ethers.constants.HashZero; }, r => { r.report.block_number++; },
        r => { r.report.base_timestamp++; }, r => { r.report.module = r.report.safe; },
        r => { r.report.actions[0].outer_gas = 200_000_001; }, r => { r.report.actions[0].outer_gas = 0; },
        r => { r.report.actions[0].signed_inner_gas++; }, r => { r.report.actions[1].calldata_hash = ethers.constants.HashZero; },
        r => { r.report.final_merkle_root = ethers.constants.HashZero; }, r => { r.report.actions[0].final_proof_attempts = 0; }]) {
        const changed = structuredClone(result); change(changed);
        assert.throws(() => live.validateResult(changed, config, chain, 'final', tree));
    }
});

test('immutable live evidence and exact-root executor acknowledgement gate submission', async () => {
    const { config, chain, tree, result, identity } = fixture();
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-evidence-'));
    try {
        const proved = await live.qualify('final', [config], [chain], directory, { identity,
            readBinarySha256: () => identity.binarySha256,
            reports: [{ ...result.report, final_merkle_root: null }], tree,
            run: async (_binary, _args, input) => {
                const request = JSON.parse(input);
                assert(!input.includes('https://'));
                assert.equal(request.networks[0].rpcEnv, chain.network.rpc);
                assert.deepEqual(request.tree, live.rustTree(tree));
                return { schemaVersion: 1, clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, results: [result] };
            } });
        const qualification = { status: 'passed', gasEstimator: 'live-rpc',
            liveRpc: { identity, final: { files: proved.files } } };
        fs.writeFileSync(path.join(directory, 'qualification.json'), JSON.stringify(qualification));
        const artifact = { segments: [{ networkConfigs: [config], merkleTree: tree }], preparedChains: [chain],
            qualificationSha256: hash(fs.readFileSync(path.join(directory, 'qualification.json'))) };
        const dependencies = { readProvenance: async () => identity };
        await assert.rejects(live.assertHandoff(artifact, directory, dependencies), /acknowledgement required/);
        const template = live.handoffTemplate(artifact, directory, [result.report]);
        const handoff = path.join(directory, 'executor-handoff.json');
        fs.writeFileSync(handoff, JSON.stringify(template));
        await assert.rejects(live.assertHandoff(artifact, directory, dependencies), /must be handed to the executor/);
        fs.writeFileSync(handoff, JSON.stringify({ ...template, acknowledged: true }));
        assert.equal((await live.assertHandoff(artifact, directory, dependencies)).filename, handoff);
        for (const change of [h => { h.root = ethers.constants.HashZero; },
            h => { h.networks[0].actions[0].outerGas++; }, h => { h.approvalGasQualified = true; },
            h => { h.qualificationSha256 = hash('other'); }]) {
            const h = structuredClone({ ...template, acknowledged: true }); change(h);
            fs.writeFileSync(handoff, JSON.stringify(h));
            await assert.rejects(live.assertHandoff(artifact, directory, dependencies), /exact qualified root and budgets/);
        }
        await assert.rejects(live.assertEvidence(artifact, directory, {
            readProvenance: async () => ({ ...identity, binarySha256: hash('other binary') }),
        }), /source or binary changed/);
        const file = path.join(directory, proved.files[0].filename);
        fs.chmodSync(file, 0o600); fs.appendFileSync(file, ' ');
        await assert.rejects(live.assertEvidence(artifact, directory, dependencies), /checksum changed/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('failed live calls retain failure evidence and cannot select local fallback caps', async () => {
    const { config, chain, identity } = fixture();
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-failed-'));
    try {
        const original = JSON.stringify(config);
        await assert.rejects(live.qualify('estimate', [config], [chain], directory,
            { identity, readBinarySha256: () => identity.binarySha256, run: async () => {
                throw Object.assign(new Error('provider echoed secret-api-key'), { code: 'SERVER_ERROR' });
            } }), error => {
                assert(!error.message.includes('secret-api-key'));
                return error.message.includes('Live qualification failed');
            });
        assert.equal(JSON.stringify(config), original);
        const failure = fs.readdirSync(directory).find(name => name.startsWith('live-rpc-estimate-failed-'));
        const evidence = fs.readFileSync(path.join(directory, failure), 'utf8');
        assert.equal(JSON.parse(evidence).status, 'failed');
        assert(!evidence.includes('secret-api-key'));
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

module.exports = { fixture };

test('binary replacement before or during a live call cannot produce accepted proof evidence', async () => {
    for (const when of ['before', 'during']) {
        const { config, chain, result, identity } = fixture();
        const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-binary-drift-'));
        try {
            let calls = 0, reads = 0;
            await assert.rejects(live.qualify('estimate', [config], [chain], directory, {
                identity,
                readBinarySha256: () => ++reads === 1 && when === 'during' ? identity.binarySha256 : hash('replacement'),
                run: async () => { calls++; return { schemaVersion: 1, clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, results: [result] }; },
            }), /binary changed/);
            assert.equal(calls, when === 'before' ? 0 : 1);
            const entries = fs.readdirSync(directory).filter(name => !name.includes('-request-'));
            assert.equal(entries.length, 1);
            assert.equal(JSON.parse(fs.readFileSync(path.join(directory, entries[0]))).status, 'failed');
        } finally { fs.rmSync(directory, { recursive: true, force: true }); }
    }
});

test('fresh replay keeps the original qualified binary identity across asynchronous header reads', async () => {
    for (const changedResult of [false, true]) {
        const { config, chain, tree, result, identity } = fixture();
        const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-replay-identity-'));
        try {
            const artifact = { segments: [{ networkConfigs: [config], merkleTree: tree }], preparedChains: [chain] };
            const dependencies = {
                verifyEvidence: async () => ({ qualification: { liveRpc: { identity } }, reports: [result.report] }),
                createProvider: () => ({ getNetwork: async () => ({ chainId: chain.chainId }),
                    send: async () => ({ number: 100, hash: chain.blockHash, timestamp: chain.blockTimestamp,
                        gasLimit: ethers.BigNumber.from(config.observedBlockGasLimit) }), formatter: { block: value => value } }),
                runQualify: async (_mode, _configs, _chains, _directory, options) => {
                    assert.equal(options.allowOuterSeedRetry, false);
                    assert.deepEqual(options.identity, identity, 'Header reads must not replace the qualified identity');
                    return { identity: changedResult ? { ...identity, binarySha256: hash('replacement') } : identity,
                        reports: [result.report], files: [] };
                },
            };
            if (changedResult) await assert.rejects(live.replay(artifact, directory, dependencies), /identity differs/);
            else assert.deepEqual((await live.replay(artifact, directory, dependencies)).identity, identity);
            const replayDir = fs.readdirSync(directory).find(name => name.startsWith('live-rpc-replay-'));
            assert.equal(JSON.parse(fs.readFileSync(path.join(directory, replayDir, 'replay.json'))).status,
                changedResult ? 'failed' : 'passed');
        } finally { fs.rmSync(directory, { recursive: true, force: true }); }
    }
});

test('higher total gas needs the pinned Sepolia activation, independently of the SDK model', () => {
    const { gasBudget } = require('./simulate-safe-airdrop');
    const { config, chain, tree, result } = fixture();
    const options = timestamp => ({ liveRpc: true, blockTimestamp: timestamp });
    assert.equal(gasBudget(11155111, 200_000_000, options(1791294815)).outerGasCap, 16_777_216);
    assert.equal(gasBudget(11155111, 200_000_000, options(1791294816)).outerGasCap, 200_000_000);
    assert.equal(gasBudget(11155111, 5_000_000_000, options(1791294816)).outerGasCap, 0xffff_ffff);
    assert.equal(gasBudget(11155111, 200_000_000, { liveRpc: true }).outerGasCap, 16_777_216);
    for (const id of [1, 10, 8453, 11155420, 84532]) assert.equal(gasBudget(id, 200_000_000, options(chain.blockTimestamp)).outerGasCap, 16_777_216);
    for (const id of [42161, 421614]) assert.equal(gasBudget(id, 200_000_000, options(chain.blockTimestamp)).outerGasCap, 32_000_000);
    assert.equal(live.rustConfig(config, chain).block_gas_limit, '0xbebc200');
    assert.equal(live.rustConfig(config, { ...chain, blockTimestamp: 1791294815 }).block_gas_limit, '0x1000000');
    const before = structuredClone(config);
    const lowReport = structuredClone(result);
    const beforeChain = { ...chain, blockTimestamp: 1791294815 };
    lowReport.config = live.rustConfig(config, beforeChain);
    lowReport.report.base_timestamp = beforeChain.blockTimestamp;
    lowReport.report.actions[0].outer_gas = 40_000_000;
    assert.throws(() => live.validateResult(lowReport, config, beforeChain, 'final', tree), /total gas ceiling/);
    assert.deepEqual(config, before, 'Rust physical ceiling must not mutate uploaded SDK model metadata');
});

test('shared live wire preserves mixed multi-action airdrop calls and exact SDK root bytes', () => {
    const { config, chain } = fixture();
    config.actionInputs = Array.from({ length: 19 }, (_, index) => ({ ...config.actionInputs[index % 2],
        index: String(index + 1), operation: index % 2, txData: `0x${(index + 1).toString(16).padStart(2, '0')}` }));
    const wire = live.rustConfig(config, chain);
    assert.equal(wire.action_inputs.length, 19);
    assert.deepEqual(wire.action_inputs.map(a => a.operation), config.actionInputs.map(a => a.operation ? 'DelegateCall' : 'Call'));
    const tree = contracts.makeSphinxMerkleTree(core.makeDeploymentData([config]));
    assert.deepEqual(live.rustTree(tree).leaves_with_proofs.map(x => x.leaf.data), tree.leavesWithProofs.map(x => x.leaf.data));
    for (const mutate of [c => { c.actionInputs = []; }, c => { c.actionInputs[0].operation = 2; },
        c => { c.actionInputs[1].index = '3'; }, c => { c.actionInputs[0].value = '1'; },
        c => { c.actionInputs[0].requireSuccess = false; }]) {
        const changed = structuredClone(config); mutate(changed);
        assert.throws(() => live.rustConfig(changed, chain));
    }
});

test('binary clamp errors expose only validated numeric hints, never raw provider diagnostics', () => {
    const error = live.binaryFailure(1, 'simulation action 2 with 1 preceding actions changed outer gas: requested 16000000, effective 12000000; https://provider.invalid/secret-api-key');
    assert(error instanceof live.LiveGasClampError);
    assert.deepEqual(error.hint, { actionIndex: 2, precedingActions: 1, requestedOuterGas: 16_000_000, effectiveOuterGas: 12_000_000 });
    assert(!error.message.includes('secret-api-key'));
    assert(!error.message.includes('https://'));
    assert(!(live.binaryFailure(1, 'action 2 with 1 preceding actions changed outer gas: requested 9007199254740992, effective 12000000') instanceof live.LiveGasClampError));
    assert(!(live.binaryFailure(1, 'changed outer gas: requested 16000000, effective 12000000') instanceof live.LiveGasClampError));
    assert(!(live.binaryFailure(1, 'action 2 with 1 preceding actions: unrelated error; changed outer gas: requested 16000000, effective 12000000') instanceof live.LiveGasClampError));
    for (const field of ['actionIndex', 'precedingActions', 'requestedOuterGas', 'effectiveOuterGas']) {
        assert.throws(() => new live.LiveGasClampError({ ...error.hint, [field]: -1 }));
        assert.throws(() => new live.LiveGasClampError({ ...error.hint, [field]: 1.5 }));
    }
});

test('opt-in final proof reissues the full unchanged request with one outer seed and retains rejected evidence', async () => {
    const { config, chain, tree, result, identity } = fixture();
    const reports = [{ ...structuredClone(result.report), final_merkle_root: null }];
    const original = structuredClone({ config, tree, reports });
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-outer-seed-'));
    const requests = [];
    try {
        const proved = await live.qualify('final', [config], [chain], directory, {
            reports, tree, identity, allowOuterSeedRetry: true, readBinarySha256: () => identity.binarySha256,
            run: async (_binary, _args, input) => {
                const request = JSON.parse(input); requests.push(request);
                if (requests.length === 1) throw new live.LiveGasClampError({ actionIndex: 2, precedingActions: 1,
                    requestedOuterGas: 16_000_000, effectiveOuterGas: 12_000_000 });
                const response = structuredClone(result); response.report.actions[1].outer_gas = 12_000_000;
                return { schemaVersion: 1, clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, results: [response] };
            },
        });
        assert.equal(requests.length, 2);
        const expected = structuredClone(requests[0]); expected.networks[0].report.actions[1].outer_gas = 12_000_000;
        assert.deepEqual(requests[1], expected, 'Only one outer seed may change; full config/tree/prefix stays intact');
        assert.deepEqual(requests[1].tree, live.rustTree(tree));
        assert.deepEqual(requests[1].networks[0].config, live.rustConfig(config, chain));
        assert.equal(requests[1].networks[0].config.action_inputs.length, 2);
        const accepted = live.readEvidence(directory, proved.files[0]);
        assert.deepEqual(live.readEvidence(directory, accepted.request), requests[1]);
        assert.equal(accepted.rejectedAttempts.length, 1);
        const rejected = live.readEvidence(directory, accepted.rejectedAttempts[0]);
        assert.equal(rejected.status, 'failed');
        assert.equal(rejected.gasClamp.effectiveOuterGas, 12_000_000);
        assert.deepEqual(live.readEvidence(directory, rejected.request), requests[0]);
        assert.deepEqual({ config, tree, reports }, original);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('outer seed adaptation rejects disabled, estimate, unknown, malformed and non-progressing failures', async () => {
    const cases = [
        { defaultDisabled: true }, { enabled: false }, { mode: 'estimate' }, { error: Object.assign(new Error('secret-api-key'), { code: 'SERVER_ERROR' }) },
        { hint: { actionIndex: 3 } }, { hint: { precedingActions: 0 } },
        { hint: { effectiveOuterGas: 8_000_000 } }, { hint: { effectiveOuterGas: 16_000_000 } },
        { seed: 6_000_000, hint: { effectiveOuterGas: 7_000_000 } },
        { hint: { requestedOuterGas: 300_000_000 } },
        { hint: { effectiveOuterGas: 201_000_000, requestedOuterGas: 300_000_000 } },
    ];
    for (const item of cases) {
        const { config, chain, tree, result, identity } = fixture();
        const reports = [{ ...structuredClone(result.report), final_merkle_root: null }];
        if (item.seed) reports[0].actions[1].outer_gas = item.seed;
        const before = structuredClone(reports);
        const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-outer-reject-'));
        let calls = 0;
        try {
            await assert.rejects(live.qualify(item.mode || 'final', [config], [chain], directory, {
                ...(item.mode === 'estimate' ? {} : { reports, tree }), identity,
                ...(item.defaultDisabled ? {} : { allowOuterSeedRetry: item.enabled !== false }),
                readBinarySha256: () => identity.binarySha256,
                run: async () => { calls++; throw item.error || new live.LiveGasClampError({ actionIndex: 2, precedingActions: 1,
                    requestedOuterGas: 16_000_000, effectiveOuterGas: 12_000_000, ...item.hint }); },
            }), error => error instanceof live.LiveQualificationError && !error.message.includes('secret-api-key'));
            assert.equal(calls, 1);
            assert.deepEqual(reports, before);
            assert(!fs.readdirSync(directory).some(file => file.startsWith('live-rpc-final-') && !file.includes('-request-') && !file.includes('-failed-')));
        } finally { fs.rmSync(directory, { recursive: true, force: true }); }
    }
});

test('outer seed retry stops after three adjustments and never bypasses final proof validation', async () => {
    for (const kind of ['bounded', 'repeated', 'bad-proof']) {
        const { config, chain, tree, result, identity } = fixture();
        const reports = [{ ...structuredClone(result.report), final_merkle_root: null }];
        const before = structuredClone(reports);
        const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-outer-bound-'));
        let calls = 0;
        try {
            await assert.rejects(live.qualify('final', [config], [chain], directory, {
                reports, tree, identity, allowOuterSeedRetry: true, readBinarySha256: () => identity.binarySha256,
                run: async () => {
                    calls++;
                    if (kind === 'bad-proof' && calls === 2) {
                        const response = structuredClone(result); response.report.final_merkle_root = ethers.constants.HashZero;
                        return { schemaVersion: 1, clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, results: [response] };
                    }
                    throw new live.LiveGasClampError({ actionIndex: 2, precedingActions: 1,
                        requestedOuterGas: 20_000_000, effectiveOuterGas: kind === 'repeated' ? 9_000_000 : 8_000_000 + calls * 1_000_000 });
                },
            }), /Live qualification failed/);
            assert.equal(calls, kind === 'bounded' ? 4 : 2);
            assert.equal(fs.readdirSync(directory).filter(file => file.startsWith('live-rpc-final-failed-')).length, calls);
            assert.deepEqual(reports, before);
        } finally { fs.rmSync(directory, { recursive: true, force: true }); }
    }
});

test('frozen replay cannot adapt outer budgets even if a fresh strict proof returns a different allowance', async () => {
    const { config, chain, tree, result, identity } = fixture();
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-frozen-outer-'));
    try {
        const artifact = { segments: [{ networkConfigs: [config], merkleTree: tree }], preparedChains: [chain] };
        const changed = structuredClone(result.report); changed.actions[1].outer_gas++;
        await assert.rejects(live.replay(artifact, directory, {
            verifyEvidence: async () => ({ qualification: { liveRpc: { identity } }, reports: [result.report] }),
            createProvider: () => ({ getNetwork: async () => ({ chainId: chain.chainId }),
                send: async () => ({ number: 100, hash: chain.blockHash, timestamp: chain.blockTimestamp,
                    gasLimit: ethers.BigNumber.from(config.observedBlockGasLimit) }), formatter: { block: value => value } }),
            runQualify: async (_mode, _configs, _chains, _directory, options) => {
                assert.equal(options.allowOuterSeedRetry, false);
                return { identity, reports: [changed], files: [] };
            },
        }), /changed exact outer budgets/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('outer seed rounding leaves allowance headroom and retains an exact fallback after a rounded seed fails', async () => {
    const { config, chain, tree, result, identity } = fixture();
    const reports = [{ ...structuredClone(result.report), final_merkle_root: null }];
    const before = structuredClone(reports);
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-live-rounded-seed-'));
    const requestedSeeds = [];
    try {
        const proved = await live.qualify('final', [config], [chain], directory, {
            reports, tree, identity, allowOuterSeedRetry: true, readBinarySha256: () => identity.binarySha256,
            run: async (_binary, _args, input) => {
                const request = JSON.parse(input); requestedSeeds.push(request.networks[0].report.actions[1].outer_gas);
                if (requestedSeeds.length <= 2) throw new live.LiveGasClampError({ actionIndex: 2, precedingActions: 1,
                    requestedOuterGas: requestedSeeds.length === 1 ? 31_870_112 : 48_000_000, effectiveOuterGas: 24_861_101 });
                const response = structuredClone(result); response.report.actions[1].outer_gas = 24_861_101;
                return { schemaVersion: 1, clientRevision: live.CLIENT_REVISION, verifierRevision: live.VERIFIER_REVISION, results: [response] };
            },
        });
        assert.deepEqual(requestedSeeds, [8_000_000, 24_000_000, 24_861_101]);
        assert.equal(live.readEvidence(directory, proved.files[0]).rejectedAttempts.length, 2);
        assert.deepEqual(reports, before);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
