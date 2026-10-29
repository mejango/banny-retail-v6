const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { test } = require('node:test');
const { ethers } = require('ethers');
const { executeBatchActions, estimateGasViaManagedService, makeDeploymentData, getMaxGasLimit } = require('@sphinx-labs/core');
const { makeSphinxMerkleTree, SphinxLeafType } = require('@sphinx-labs/contracts');
const { buildContractsByChain, loadRawItems } = require('./generate-v6-airdrop');
const { actionDigest, outerBudget, capExecutionConfig, capLiveExecutionConfig, sdkExecutionBatches, localRelayBudget, worstProofLeaf, probeAllowance, coldAllowance, qualifiedAllowance, assertHeadroom, packSegments,
    safeFrames, measureSafeFrame, moduleEvents, assertActionEvents, captureFailure, validatePrepared,
    validateSeedCalibration, readCalibrationSeed, replayPreparedPart, latestReplayHeader } = require('./qualify-sphinx-airdrop');

const SAFE = '0x0000000000000000000000000000000000000001';
const MODULE = '0x0000000000000000000000000000000000000002';
const RELAY = '0x0000000000000000000000000000000000000003';
const TARGET = '0x0000000000000000000000000000000000000004';
const ROOT = `0x${'12'.repeat(32)}`;
const moduleFixture = { address: MODULE, interface: new ethers.utils.Interface(
    require('@sphinx-labs/contracts/contract-artifacts/sphinx/SphinxModule.sol/SphinxModule.json').abi) };
const safeInterface = new ethers.utils.Interface(['function execTransactionFromModule(address,uint256,bytes,uint8) returns(bool)']);
const headers = new Map([[1, '60000000'], [10, '40000000'], [8453, '400000000'], [11155111, '199804498'],
    [11155420, '40000000'], [84532, '1200000000'], [42161, '1125899906842624'], [421614, '1125899906842624']]);

function action(index = 1, gas = '6000000') {
    return { index: String(index), to: TARGET, value: '0', txData: `0x1234${index.toString(16).padStart(2, '0')}`,
        operation: 1, gas, requireSuccess: true };
}
function config(chainId, count = 1, gas = '6000000') {
    return { chainId: String(chainId), nonce: '8', safeAddress: SAFE, moduleAddress: MODULE, executorAddress: RELAY,
        blockGasLimit: headers.get(chainId), blockNumber: '123', arbitraryChain: false,
        actionInputs: Array.from({ length: count }, (_, index) => action(index + 1, gas)) };
}

test('live fork replay uses one raw finalized read and immediately rejects missing state; legacy stays latest', async () => {
    const rpcEnv = 'BANNY_HEADER_FIXTURE_RPC';
    const prior = process.env[rpcEnv];
    process.env[rpcEnv] = 'https://read-only.invalid';
    const calls = [];
    const block = { number: 123, hash: ROOT, gasLimit: ethers.BigNumber.from('200000000') };
    const provider = { getNetwork: async () => ({ chainId: 1 }),
        send: async (method, args) => { calls.push([method, args]); return { raw: true }; },
        formatter: { block: header => { assert.deepEqual(header, { raw: true }); return block; } },
        getBlock: async tag => { calls.push(['getBlock', tag]); return block; } };
    const chain = { chainId: 1, network: { rpc: rpcEnv } };
    const deps = { createProvider: () => provider };
    try {
        assert.equal((await latestReplayHeader(chain, { liveRpc: true }, deps)).block, block);
        assert.deepEqual(calls, [['eth_getBlockByNumber', ['finalized', false]]]);
        calls.length = 0;
        assert.equal((await latestReplayHeader(chain, {}, deps)).block, block);
        assert.deepEqual(calls, [['getBlock', 'latest']]);
        calls.length = 0;
        provider.send = async (method, args) => { calls.push([method, args]); return null; };
        provider.getBlock = async () => assert.fail('Live finalized reads must not invoke ethers null-header polling');
        await assert.rejects(latestReplayHeader(chain, { liveRpc: true }, deps), /Missing chain 1 finalized block/);
        assert.deepEqual(calls, [['eth_getBlockByNumber', ['finalized', false]]]);
    } finally {
        if (prior === undefined) delete process.env[rpcEnv]; else process.env[rpcEnv] = prior;
    }
});

test('cold allowance uses positive gross frame gas and existing Sphinx margin, not receipt gas', () => {
    assert.equal(coldAllowance('2500000'), '3120000');
    assert.equal(coldAllowance('1'), '120002');
    assert.throws(() => coldAllowance('0'), /positive/);
    assert.throws(() => coldAllowance('-1'), /positive/);
});

test('budget-qualified allowances report reduced margins and reject insufficient actual headroom', () => {
    assert.deepEqual(qualifiedAllowance('2500000', '14000000'), { requestedGas: '3120000', maximumGas: '14000000',
        signedGas: '3120000', headroom: '620000', budgetLimited: false });
    assert.deepEqual(qualifiedAllowance('12472825', '14580030'), { requestedGas: '15087390', maximumGas: '14580030',
        signedGas: '14580030', headroom: '2107205', budgetLimited: true });
    assert.equal(qualifiedAllowance('12533615', '14582766').headroom, '2049151');
    assert.equal(qualifiedAllowance('1000000', '1120000').headroom, '120000');
    assert.throws(() => qualifiedAllowance('1000000', '1119999'), /minimum cold headroom/);
    assert.equal(assertHeadroom('1120000', '1000000'), '120000');
    assert.throws(() => assertHeadroom('1120000', '1000001'), /insufficient measured/);
});

test('calibration reuse requires exact pinned context, root, complete ordered cold successes and positive frames', () => {
    const network = config(1, 2);
    const tree = makeSphinxMerkleTree(makeDeploymentData([network]));
    const current = { chainId: '1', blockNumber: 123, blockHash: ROOT, blockGasLimit: network.blockGasLimit,
        safe: SAFE, module: MODULE, relay: RELAY, safeNonce: '4', moduleNonce: '8', threshold: 2,
        outerGasBudget: outerBudget(network), anvilHardfork: 'osaka', runtimeKeccak256: { safe: ROOT, moduleProxy: ROOT, relay: ROOT } };
    const old = { localForkOnly: true, provisionalRoot: tree.root, chains: [{ ...current,
        calibration: network.actionInputs.map((tx, index) => ({ root: tree.root, mode: 'cold', indices: [index + 1],
            transactionHash: `0x${String(index + 1).repeat(64)}`, outerReceiptStatus: 1,
            rootStatus: index === 1 ? 2 : 1, activeRoot: index === 1 ? ethers.constants.HashZero : tree.root,
            events: [{ name: 'SphinxActionSucceeded', root: tree.root, index: String(index + 1) },
                ...(index === 1 ? [{ name: 'SphinxMerkleRootCompleted', root: tree.root }] : [])],
            actions: [{ index: index + 1, actionDigest: actionDigest(tx), signedGas: tx.gas, grossSafeGas: '2500000' }] })) }] };
    assert.equal(validateSeedCalibration(old, [network], tree, [current])[0].length, 2);
    const change = mutate => { const other = structuredClone(old); mutate(other.chains[0]); return other; };
    assert.throws(() => validateSeedCalibration(change(chain => { chain.blockHash = ethers.constants.HashZero; }), [network], tree, [current]), /blockHash/);
    assert.throws(() => validateSeedCalibration(change(chain => { chain.calibration.pop(); }), [network], tree, [current]), /coverage/);
    assert.throws(() => validateSeedCalibration(change(chain => { chain.calibration[0].actions[0].grossSafeGas = '0'; }), [network], tree, [current]), /positive/);
    assert.throws(() => validateSeedCalibration(change(chain => { chain.calibration[0].actions[0].actionDigest = ROOT; }), [network], tree, [current]), /action bytes/);
    assert.throws(() => validateSeedCalibration(change(chain => { chain.calibration[1].rootStatus = 1; }), [network], tree, [current]), /lifecycle/);
    assert.throws(() => validateSeedCalibration(change(chain => { chain.calibration[0].firstFailureIndex = '1'; }), [network], tree, [current]), /failed action/);
    assert.throws(() => validateSeedCalibration(change(chain => { chain.calibration[0].events[0].name = 'SphinxActionFailed'; }), [network], tree, [current]), /success events/);
    assert.throws(() => validateSeedCalibration({ ...old, provisionalRoot: ROOT }, [network], tree, [current]), /root differs/);
});

test('calibration seed binds archived measuring sources and current input identity', () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-calibration-test-'));
    try {
        const sourceDirectory = path.join(directory, 'source');
        fs.mkdirSync(path.join(sourceDirectory, 'script/outfit_drop'), { recursive: true });
        const qualifier = 'script/outfit_drop/qualify-sphinx-airdrop.js';
        const exporter = 'script/outfit_drop/export-safe-airdrop.js';
        const digest = text => createHash('sha256').update(text).digest('hex');
        for (const file of [qualifier, exporter]) fs.writeFileSync(path.join(sourceDirectory, file), file);
        const oldSources = { [qualifier]: digest(qualifier), [exporter]: digest(exporter) };
        const currentSources = { ...oldSources, [qualifier]: digest('reviewed new policy') };
        const reportFile = path.join(directory, 'old-report.json');
        const inputsFile = path.join(directory, 'old-inputs.json');
        const inputs = { inputIdentity: 'a'.repeat(64), rawItemsSha256: 'b'.repeat(64), sources: {}, artifacts: {}, chains: [] };
        fs.writeFileSync(reportFile, JSON.stringify({ sourceSha256: oldSources }));
        fs.writeFileSync(inputsFile, JSON.stringify(inputs));
        fs.writeFileSync(path.join(directory, 'inputs.json'), JSON.stringify(inputs));
        const seed = { reportFile, inputsFile, sourceDirectory };
        assert.equal(readCalibrationSeed(seed, directory, currentSources).provenance.inputIdentity, inputs.inputIdentity);
        assert.throws(() => readCalibrationSeed(seed, directory, { ...currentSources, [exporter]: digest('changed') }), /dependency changed/);
        fs.writeFileSync(path.join(directory, 'inputs.json'), JSON.stringify({ ...inputs, inputIdentity: 'c'.repeat(64) }));
        assert.throws(() => readCalibrationSeed(seed, directory, currentSources), /source\/input identity differs/);
        fs.writeFileSync(path.join(directory, 'inputs.json'), JSON.stringify(inputs));
        fs.writeFileSync(path.join(sourceDirectory, qualifier), 'changed archive');
        assert.throws(() => readCalibrationSeed(seed, directory, currentSources), /Archived calibration source/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('generous probes fit actual SDK singleton estimates and all eight chain execution budgets', () => {
    for (const chainId of headers.keys()) {
        const network = config(chainId);
        const tx = { ...action(), txData: `0x${'ff'.repeat(5000)}` };
        const allowance = probeAllowance(network, tx, 7);
        const leaf = worstProofLeaf(network, { ...tx, gas: allowance }, 7);
        assert(BigInt(allowance) > 10_000_000n);
        assert(estimateGasViaManagedService(MODULE, [leaf], BigInt(chainId)) < outerBudget(network));
        assert.equal(outerBudget(network), [42161, 421614].includes(chainId) ? 30_400_000 : 15_938_355);
    }
    assert.throws(() => outerBudget({ ...config(1), blockGasLimit: '1000000' }), /below/);
});

test('consecutive bounded parts preserve all action bytes and nonce order, including Arbitrum', () => {
    const configs = [config(8453, 8), config(1, 3, '7000000'), config(42161, 5, '10000000')];
    const original = JSON.stringify(configs);
    const parts = packSegments(configs, 5);
    assert.equal(parts.length, 4);
    for (const network of configs) {
        const own = parts.flatMap(part => part.networkConfigs.filter(entry => entry.chainId === network.chainId));
        assert.deepEqual(own.map(entry => entry.nonce), own.map((_, index) => String(8 + index)));
        assert.deepEqual(own.flatMap(entry => entry.actionInputs.map(actionDigest)), network.actionInputs.map(actionDigest));
        assert.deepEqual(own.flatMap(entry => entry.actionInputs.map(tx => tx.gas)), network.actionInputs.map(tx => tx.gas));
    }
    for (const part of parts) {
        assert.deepEqual(part.merkleTree, makeSphinxMerkleTree(makeDeploymentData(part.networkConfigs)));
        for (const network of part.networkConfigs) {
            assert.equal(network.blockGasLimit, headers.get(Number(network.chainId)));
            const leaves = part.merkleTree.leavesWithProofs.filter(entry =>
                entry.leaf.leafType === SphinxLeafType.EXECUTE && String(entry.leaf.chainId) === network.chainId);
            assert(estimateGasViaManagedService(MODULE, leaves, BigInt(network.chainId)) <= outerBudget(network));
            assert.deepEqual(network.actionInputs.map(tx => tx.index), network.actionInputs.map((_, index) => String(index + 1)));
        }
    }
    assert.equal(JSON.stringify(configs), original, 'Segment construction must not mutate collected input.');
    assert(parts.flatMap(part => part.networkConfigs).filter(entry => entry.chainId === '42161').length > 1,
        'Arbitrum must also bound the complete part, even when SDK batching is disabled.');
});

test('cannot silently clamp an oversized buffered shard to a cap', () => {
    assert.throws(() => packSegments([config(8453, 1, '16000000')], 3), /split and requalify/);
    assert.throws(() => packSegments([config(42161, 1, '30400000')], 3), /split and requalify/);
});

test('one proposal preserves action bytes, gas and nonce while the installed SDK selects bounded execution transactions', async () => {
    for (const chainId of headers.keys()) {
        const network = config(chainId, 5, '7000000');
        const original = structuredClone(network);
        assert(packSegments([network], 4).length > 1, 'Default distribution roots must remain bounded.');
        const capped = capExecutionConfig(network);
        assert.equal(capped.observedBlockGasLimit, network.blockGasLimit);
        assert(BigInt(capped.blockGasLimit) <= BigInt(network.blockGasLimit));
        assert(getMaxGasLimit(BigInt(capped.blockGasLimit)) <= BigInt(outerBudget(network)));
        const parts = packSegments([capped], 4, () => { throw new Error('No stage partitioning in one-root mode.'); },
            { multipleExecutionTransactions: true });
        assert.equal(parts.length, 1);
        const frozen = parts[0].networkConfigs[0];
        assert.equal(frozen.nonce, '8');
        assert.deepEqual(frozen.actionInputs, network.actionInputs);
        assert.equal(parts[0].merkleTree.root, makeSphinxMerkleTree(makeDeploymentData([network])).root,
            'Execution ceiling must not change the signed action/root.');
        const leaves = parts[0].merkleTree.leavesWithProofs.filter(entry => entry.leaf.leafType === SphinxLeafType.EXECUTE);
        assert(estimateGasViaManagedService(MODULE, leaves, BigInt(chainId)) > outerBudget(capped),
            'The total proposal exceeds one execution transaction.');
        const batches = await sdkExecutionBatches(frozen, leaves);
        assert(batches.length > 1);
        assert.deepEqual(batches.flat(), leaves);
        for (const batch of batches) assert(estimateGasViaManagedService(MODULE, batch, BigInt(chainId)) <= outerBudget(capped));
        assert.deepEqual(network, original, 'Execution policy must not mutate the observed configuration.');
    }
});

test('live SDK model fits buffered singleton estimates without changing signed or observed limits', async () => {
    for (const chainId of headers.keys()) {
        const raw = config(chainId, 2, '14000000');
        raw.actionInputs[0].txData = `0x${'ff'.repeat(5000)}`;
        const before = structuredClone(raw);
        const live = capLiveExecutionConfig(raw, 7);
        assert.equal(live.observedBlockGasLimit, raw.blockGasLimit);
        assert(BigInt(live.blockGasLimit) <= BigInt(raw.blockGasLimit));
        assert.deepEqual(live.actionInputs, raw.actionInputs);
        const tree = makeSphinxMerkleTree(makeDeploymentData([live]));
        assert.equal(tree.root, makeSphinxMerkleTree(makeDeploymentData([raw])).root);
        const leaves = tree.leavesWithProofs.filter(entry => entry.leaf.leafType === SphinxLeafType.EXECUTE);
        for (const tx of raw.actionInputs) assert(estimateGasViaManagedService(MODULE,
            [worstProofLeaf(live, tx, 7)], BigInt(chainId)) < Number(getMaxGasLimit(BigInt(live.blockGasLimit))));
        assert.equal(packSegments([live], 7, undefined, { multipleExecutionTransactions: true, liveRpc: true }).length, 1);
        assert.deepEqual((await sdkExecutionBatches(live, leaves, { liveRpc: true })).map(batch => batch.length), [1, 1]);
        assert.equal(localRelayBudget(live, { liveRpc: true }), [42161, 421614].includes(chainId) ? 32_000_000 : 16_777_216);
        assert.equal(localRelayBudget(live), outerBudget(live));
        assert.deepEqual(raw, before);
    }
    assert.equal(capExecutionConfig(config(1, 2, '0')).actionInputs[0].gas, '0', 'Initial legacy calibration context accepts unmeasured actions.');
    assert.throws(() => capLiveExecutionConfig(config(1, 2, '0'), 3), /signed gas exceeds/);
    assert.throws(() => capLiveExecutionConfig(config(1, 1, '16000000'), 3), /signed gas exceeds/);
    assert.throws(() => capLiveExecutionConfig({ ...config(1, 1, '15000000'), blockGasLimit: '16000000' }, 7),
        /cannot fit the observed header/);
    const raw = config(1, 2, '1000000');
    const oversized = { ...capLiveExecutionConfig(raw, 3), blockGasLimit: raw.blockGasLimit };
    const tree = makeSphinxMerkleTree(makeDeploymentData([oversized]));
    assert.deepEqual((await sdkExecutionBatches(oversized,
        tree.leavesWithProofs.filter(entry => entry.leaf.leafType === SphinxLeafType.EXECUTE), { liveRpc: true }))
        .map(batch => batch.length), [1, 1], 'Explicit dispatch remains singleton even when the model admits batching.');
});

test('SDK batches compatible small actions together and refuses unproven or oversized execution settings', async () => {
    const raw = config(84532, 2, '1000000');
    const capped = capExecutionConfig(raw);
    const tree = makeSphinxMerkleTree(makeDeploymentData([capped]));
    const leaves = tree.leavesWithProofs.filter(entry => entry.leaf.leafType === SphinxLeafType.EXECUTE);
    assert.equal((await sdkExecutionBatches(capped, leaves)).length, 1, 'Use SDK grouping when the batch fits.');
    await assert.rejects(sdkExecutionBatches(raw, leaves), /needs the observed/);
    await assert.rejects(sdkExecutionBatches({ ...capped, blockGasLimit: raw.blockGasLimit }, leaves), /reviewed transaction budget/);
    assert.throws(() => capExecutionConfig(capped), /already capped/);
    assert.throws(() => packSegments([raw], 3, undefined, { multipleExecutionTransactions: true }), /needs the observed/);
    assert.throws(() => packSegments([capExecutionConfig(config(84532, 1, '16000000'))], 3, undefined,
        { multipleExecutionTransactions: true }), /split and requalify/);
    await assert.rejects(sdkExecutionBatches({ ...capped, observedBlockGasLimit: '18000000', blockGasLimit: '19922943' }, leaves),
        /exceeds the observed/);
});

test('cold measurement selects the outer module-to-Safe call and checks exact signed bytes, output and gas', () => {
    const tx = action();
    const frame = { type: 'CALL', from: MODULE, to: SAFE, gas: ethers.utils.hexValue(Number(tx.gas)), gasUsed: '0x2625a0',
        input: safeInterface.encodeFunctionData('execTransactionFromModule', [tx.to, tx.value, tx.txData, tx.operation]),
        output: ethers.utils.defaultAbiCoder.encode(['bool'], [true]),
        calls: [{ type: 'DELEGATECALL', from: SAFE, to: TARGET, gasUsed: '0x1', input: '0x' }] };
    const trace = { type: 'CALL', from: RELAY, to: MODULE, calls: [frame] };
    assert.deepEqual(safeFrames(trace, MODULE, SAFE), [frame]);
    assert.equal(measureSafeFrame(frame, tx), '2500000');
    assert.throws(() => measureSafeFrame({ ...frame, output: ethers.utils.defaultAbiCoder.encode(['bool'], [false]) }, tx), /returned false/);
    assert.throws(() => measureSafeFrame({ ...frame, gas: '0x1' }, tx), /Invalid gross/);
    assert.throws(() => measureSafeFrame({ ...frame, gas: ethers.utils.hexValue(Number(tx.gas) - 1) }, tx), /forward/);
    assert.throws(() => measureSafeFrame({ ...frame, gasUsed: '0x0' }, tx), /Invalid gross/);
    assert.throws(() => measureSafeFrame({ ...frame, error: 'out of gas' }, tx), /failed/);
    assert.throws(() => measureSafeFrame(frame, { ...tx, txData: '0x0000' }), /calldata differs/);
});

function event(name, index, root = ROOT) {
    const encoded = moduleFixture.interface.encodeEventLog(moduleFixture.interface.getEvent(name), index === undefined ? [root] : [root, index]);
    return { address: MODULE, ...encoded };
}

test('outer success cannot mask an inner failure, and first failure events remain available before validation', () => {
    const failed = { status: 1, logs: [event('SphinxActionSucceeded', 1), event('SphinxActionFailed', 2), event('SphinxMerkleRootFailed', 2)] };
    const persisted = moduleEvents(failed, moduleFixture);
    assert.equal(persisted.find(item => item.name === 'SphinxActionFailed').index, '2');
    assert.throws(() => assertActionEvents(failed, moduleFixture, ROOT, [1, 2]), /despite the outer receipt/);
    assert.deepEqual(persisted.map(item => item.name), ['SphinxActionSucceeded', 'SphinxActionFailed', 'SphinxMerkleRootFailed']);
    const success = { status: 1, logs: [event('SphinxActionSucceeded', 1), event('SphinxActionSucceeded', 2), event('SphinxMerkleRootCompleted')] };
    assert.equal(assertActionEvents(success, moduleFixture, ROOT, [1, 2]).length, 3);
    assert.throws(() => assertActionEvents(success, moduleFixture, ROOT, [2, 1]), /indices/);
    assert.throws(() => assertActionEvents({ ...success, status: 0 }, moduleFixture, ROOT, [1, 2]), /reverted/);
    assert.throws(() => assertActionEvents(success, moduleFixture, `0x${'34'.repeat(32)}`, [1, 2]), /another root/);
});

test('failure checkpoint retains the original index and nested cause even when tracing is unavailable', async () => {
    const primary = Object.assign(new Error('Sphinx action/root failed despite the outer receipt.'), { code: 'ERR_ASSERTION' });
    const record = { transactionHash: ROOT, firstFailureIndex: '2', events: [{ name: 'SphinxActionFailed', index: '2' }] };
    const snapshots = [];
    const save = () => snapshots.push(JSON.parse(JSON.stringify(record)));
    await captureFailure({ send: async () => { throw Object.assign(new Error('https://private-rpc.invalid/secret'), { code: 'NETWORK_ERROR' }); } }, record, primary, save);
    assert.equal(snapshots[0].failure, primary.message, 'Save the primary failure before attempting tracing.');
    assert.equal(record.firstFailureIndex, '2');
    assert.equal(record.failure, primary.message);
    assert.match(record.traceError, /NETWORK_ERROR/);
    assert(!JSON.stringify(record).includes('secret'));
    const traced = { transactionHash: ROOT, firstFailureIndex: '2' };
    await captureFailure({ send: async () => ({ calls: [{ to: TARGET, error: 'out of gas', output: '0x' }] }) }, traced, primary, () => {});
    assert.equal(traced.failure, primary.message);
    assert.deepEqual(traced.innerFailures, [{ to: TARGET, error: 'out of gas', reason: '0x' }]);
});

test('qualification binds action bytes to canonical source slice metadata and refuses missing or repeated allocations', () => {
    const plan = buildContractsByChain(loadRawItems())[10][0];
    const network = config(10);
    const tx = network.actionInputs[0];
    const envelope = { chainId: '10', sourceChainId: 10, safe: SAFE, stage: 'migration',
        contractName: plan.contractName, slice: 1, expectedTokenIds: plan.assignments.expectedTokenIds,
        transaction: { to: tx.to, data: tx.txData, value: tx.value, operation: tx.operation } };
    const prepared = { chainId: 10, safe: SAFE, plans: [plan], envelopes: [envelope] };
    assert.equal(validatePrepared(network, prepared).size, 1);
    assert.throws(() => validatePrepared({ ...network, actionInputs: [{ ...tx, txData: '0x5678' }] }, prepared), /differs from its canonical/);
    assert.throws(() => validatePrepared({ ...network, actionInputs: [{ ...tx, requireSuccess: false }] }, prepared), /require success/);
    assert.throws(() => validatePrepared(network, { ...prepared, envelopes: [{ ...envelope, expectedTokenIds: envelope.expectedTokenIds.slice(1) }] }), /canonical exported slice/);
    assert.throws(() => validatePrepared({ ...network, actionInputs: [tx, tx] }, { ...prepared, envelopes: [envelope, envelope] }), /Repeated NFT/);
    assert.throws(() => validatePrepared(network, { ...prepared, envelopes: [{ ...envelope, components: [envelope] }] }), /not merged/);
});


test('explicit stage boundaries preserve exact actions even when stages fit together', () => {
    const network = config(8453, 2, '1000000');
    assert.equal(packSegments([network], 3).length, 1);
    let called = 0;
    const parts = packSegments([network], 3, (pending, action, current) => {
        called++;
        assert.equal(current, network);
        assert.equal(pending.length, 1);
        assert.equal(action, network.actionInputs[1]);
        return true;
    });
    assert.equal(called, 1);
    assert.equal(parts.length, 2);
    assert.deepEqual(parts.map(part => part.networkConfigs[0].nonce), ['8', '9']);
    assert.deepEqual(parts.flatMap(part => part.networkConfigs[0].actionInputs.map(actionDigest)), network.actionInputs.map(actionDigest));
    assert.throws(() => packSegments([config(8453, 1, '16000000')], 3, () => true), /split and requalify/);
});

function replayFixture({ multipleExecutionTransactions = false, liveRpc = false, gas = '1000000' } = {}) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-replay-test-'));
    const first = multipleExecutionTransactions ? (liveRpc ? capLiveExecutionConfig(config(1), 3) : capExecutionConfig(config(1))) : config(1);
    const rawSecond = { ...config(1, 2, gas), nonce: '9' };
    const second = multipleExecutionTransactions ? (liveRpc ? capLiveExecutionConfig(rawSecond, 3) : capExecutionConfig(rawSecond)) : rawSecond;
    const segments = [first, second].map(network => ({ networkConfigs: [network],
        merkleTree: JSON.parse(JSON.stringify(makeSphinxMerkleTree(makeDeploymentData([network])),
            (_, value) => typeof value === 'bigint' ? value.toString() : value)) }));
    const artifact = { segments, preparedChains: [{ chainId: 1, safe: SAFE, blockHash: ROOT,
        authority: { owners: [SAFE], threshold: '1' },
        network: { rpc: 'REPLAY_TEST_RPC' }, envelopes: [first.actionInputs[0], ...second.actionInputs].map((tx, index) =>
            ({ stage: 'migration', chainId: '1', safe: SAFE, expectedTokenIds: [index + 1],
                transaction: { to: tx.to, data: tx.txData, value: tx.value, operation: tx.operation } })) }] };
    const runtimes = { safe: ROOT, moduleProxy: ROOT, relay: ROOT };
    fs.writeFileSync(path.join(directory, 'qualification.json'), JSON.stringify({ status: 'passed', sourceSha256: {},
        executionPolicy: liveRpc ? 'live-explicit-singletons-v2' : multipleExecutionTransactions ? 'sdk-bounded-transactions-v1' : undefined,
        chains: [{ chainId: '1', runtimeKeccak256: runtimes }] }));
    const calls = [];
    let moduleNonce = '9';
    let safeNonce = '4';
    const context = { safeNonce: '4', initialSnapshot: 'snapshot',
        module: { merkleRootNonce: async () => moduleNonce }, safe: { nonce: async () => safeNonce, getOwners: async () => [SAFE] },
        provider: { send: async (method, args) => { calls.push([method, args]); moduleNonce = '9'; return true; },
            removeAllListeners: () => calls.push(['cleanup']) }, child: { kill: () => calls.push(['kill']) } };
    const workflow = {
        multipleExecutionTransactions, liveRpc,
        validatePrepared: () => new Map(),
        verifyFinal: async fork => { calls.push(['verify', fork.prepared.envelopes.flatMap(item => item.expectedTokenIds)]); },
        replayDependencies: {
            readHeader: async () => { calls.push(['header']); return { rpcUrl: 'https://read-only.invalid',
                block: { number: 456, hash: ROOT, gasLimit: ethers.BigNumber.from('50000000') } }; },
            openContext: async (entry, prepared, report, validate, options) => {
                assert.equal(Boolean(options.liveRpc), liveRpc);
                assert.equal(entry.networkConfig.blockNumber, '456');
                assert.equal(entry.networkConfig.blockGasLimit, multipleExecutionTransactions ? second.blockGasLimit : '50000000');
                if (multipleExecutionTransactions) assert.equal(entry.networkConfig.observedBlockGasLimit, '50000000');
                assert.deepEqual(entry.networkConfig.actionInputs, second.actionInputs);
                assert.equal(entry.networkConfig.nonce, '9');
                calls.push(['open']);
                Object.assign(context, { liveRpc: options.liveRpc, config: entry.networkConfig, prepared, report, plans: validate(entry.networkConfig, prepared) });
                report.runtimeKeccak256 = runtimes; report.threshold = 1;
                return context;
            },
            executeRoot: async (fork, network, tree, mode, records, save) => {
                calls.push([mode]);
                assert.equal(tree.root, artifact.segments[1].merkleTree.root);
                assert.deepEqual(network.actionInputs.map(tx => tx.gas), [gas, gas]);
                records.push({ mode, root: tree.root, events: [{ name: 'SphinxMerkleRootCompleted' }],
                    actions: network.actionInputs.map(tx => ({ signedGas: tx.gas, grossSafeGas: '800000',
                        headroom: assertHeadroom(tx.gas, '800000') })) });
                moduleNonce = '10'; save();
            },
        },
    };
    return { directory, artifact, workflow, context, calls, setSafeNonce: value => { safeNonce = value; } };
}

test('fresh replay preserves frozen root/actions/gas and verifies only this part in cold and restored full modes', async () => {
    const fixture = replayFixture();
    try {
        const original = structuredClone(fixture.artifact);
        const { report, reportFile } = await replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow);
        assert.equal(report.status, 'passed');
        assert.deepEqual(fixture.artifact, original);
        assert.deepEqual(fixture.calls, [['header'], ['open'], ['cold'], ['verify', [2, 3]],
            ['evm_revert', ['snapshot']], ['full-part'], ['verify', [2, 3]], ['cleanup'], ['kill']]);
        assert.equal(report.chains[0].finalModuleNonce, '10');
        assert.deepEqual(JSON.parse(fs.readFileSync(reportFile)).chains[0].records.map(record => record.mode), ['cold', 'full-part']);
        const again = await replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow);
        assert.notEqual(again.reportFile, reportFile, 'Retain every replay attempt.');
    } finally { fs.rmSync(fixture.directory, { recursive: true, force: true }); }
});

test('one-root replay retains the uploaded SDK ceiling and qualifies SDK batches against fresh observed headers', async () => {
    const fixture = replayFixture({ multipleExecutionTransactions: true, gas: '8000000' });
    try {
        const before = structuredClone(fixture.artifact);
        const { report } = await replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow);
        assert.equal(report.status, 'passed');
        assert.equal(report.executionPolicy, 'sdk-bounded-transactions-v1');
        assert.equal(report.chains[0].blockGasLimit, '50000000', 'Report actual fresh chain header.');
        assert.equal(report.chains[0].sdkBlockGasLimit, before.segments[1].networkConfigs[0].blockGasLimit);
        assert.deepEqual(fixture.artifact, before);
        assert(fixture.calls.some(call => call[0] === 'sdk-batches'));
        assert(!fixture.calls.some(call => call[0] === 'full-part'));
        await assert.rejects(replayPreparedPart(fixture.artifact, fixture.directory, 1,
            { ...fixture.workflow, multipleExecutionTransactions: false }), /execution policy changed/);
        fixture.workflow.replayDependencies.readHeader = async () => ({ rpcUrl: 'https://read-only.invalid',
            block: { number: 457, hash: ROOT, gasLimit: ethers.BigNumber.from('19000000') } });
        await assert.rejects(replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow),
            /SDK execution ceiling exceeds the observed/);
    } finally { fs.rmSync(fixture.directory, { recursive: true, force: true }); }
});

test('live replay preserves model ceiling while keeping exact root and local allocation separate', async () => {
    const fixture = replayFixture({ multipleExecutionTransactions: true, liveRpc: true, gas: '14000000' });
    try {
        const before = structuredClone(fixture.artifact);
        const result = await replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow);
        assert.equal(result.report.executionPolicy, 'live-explicit-singletons-v2');
        assert(fixture.calls.some(call => call[0] === 'sdk-singletons'));
        assert(!fixture.calls.some(call => call[0] === 'sdk-batches'));
        assert.equal(result.report.status, 'passed');
        assert.deepEqual(fixture.artifact, before);
        assert.equal(localRelayBudget(fixture.context.config, fixture.context), 16_777_216);
        const pathToReport = path.join(fixture.directory, 'qualification.json');
        const original = JSON.parse(fs.readFileSync(pathToReport));
        original.executionPolicy = 'sdk-bounded-transactions-v1';
        fs.writeFileSync(pathToReport, JSON.stringify(original));
        await assert.rejects(replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow), /execution policy changed/);
    } finally { fs.rmSync(fixture.directory, { recursive: true, force: true }); }
});

test('fresh replay keeps inner failure evidence and closes forks without running or verifying later modes', async () => {
    const fixture = replayFixture();
    try {
        fixture.workflow.replayDependencies.executeRoot = async (_, __, tree, mode, records, save) => {
            records.push({ mode, root: tree.root, firstFailureIndex: '2', events: [{ name: 'SphinxActionFailed', index: '2' }] });
            save(); assert.fail('Injected executor balance blocks frozen root.');
        };
        await assert.rejects(replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow), /executor balance/);
        const folder = fs.readdirSync(fixture.directory).find(name => name.startsWith('replay-part-'));
        const report = JSON.parse(fs.readFileSync(path.join(fixture.directory, folder, 'replay.json')));
        assert.equal(report.status, 'failed');
        assert.equal(report.chains[0].records[0].firstFailureIndex, '2');
        assert.deepEqual(fixture.calls, [['header'], ['open'], ['cleanup'], ['kill']]);
    } finally { fs.rmSync(fixture.directory, { recursive: true, force: true }); }
});

test('distribution replay rebuilds frozen plan names and validates a selected slice without requiring previous allocations', async () => {
    const fixture = replayFixture();
    try {
        const { partitionPlan } = require('./export-safe-airdrop');
        const plan = buildContractsByChain(loadRawItems())[1][0];
        const slices = partitionPlan(plan);
        const chain = fixture.artifact.preparedChains[0];
        chain.network.sourceChainId = 1; chain.planNames = [plan.contractName];
        for (const [index, slice] of slices.entries()) Object.assign(chain.envelopes[index], {
            contractName: plan.contractName, sourceChainId: 1, slice: slice.slice,
            expectedTokenIds: slice.assignments.expectedTokenIds });
        Object.assign(chain.envelopes[2], { stage: 'setup', expectedTokenIds: [] });
        delete fixture.workflow.validatePrepared;
        fixture.workflow.verifyFinal = async context => {
            assert.equal(context.plans.size, 1);
            assert.deepEqual(context.prepared.envelopes.flatMap(item => item.expectedTokenIds), slices[1].assignments.expectedTokenIds);
        };
        const result = await replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow);
        assert.equal(result.report.status, 'passed');
        chain.envelopes[1].expectedTokenIds = slices[0].assignments.expectedTokenIds;
        await assert.rejects(replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow), /canonical exported slice/);
    } finally { fs.rmSync(fixture.directory, { recursive: true, force: true }); }
});

test('fresh replay rejects changed runtimes, failed restore, nonce drift and lower fresh block budgets', async () => {
    for (const failure of ['runtime', 'restore', 'nonce', 'budget', 'authority']) {
        const fixture = replayFixture();
        try {
            if (failure === 'runtime') {
                const open = fixture.workflow.replayDependencies.openContext;
                fixture.workflow.replayDependencies.openContext = async (...args) => {
                    const context = await open(...args); context.report.runtimeKeccak256 = {}; return context;
                };
            } else if (failure === 'restore') fixture.context.provider.send = async () => false;
            else if (failure === 'nonce') fixture.setSafeNonce('5');
            else if (failure === 'authority') fixture.context.safe.getOwners = async () => [TARGET];
            else fixture.workflow.replayDependencies.readHeader = async () => ({ rpcUrl: 'https://read-only.invalid',
                block: { number: 456, hash: ROOT, gasLimit: ethers.BigNumber.from('1000000') } });
            await assert.rejects(replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow),
                failure === 'runtime' ? /runtime changed/ : failure === 'restore' ? /restore/ : failure === 'nonce' ? /Safe nonce/
                    : failure === 'authority' ? /authority changed/ : /below/);
            if (failure !== 'budget') assert.deepEqual(fixture.calls.slice(-2), [['cleanup'], ['kill']]);
        } finally { fs.rmSync(fixture.directory, { recursive: true, force: true }); }
    }
});

test('fresh replay rejects tree tampering before opening any fork', async () => {
    const fixture = replayFixture();
    try {
        fixture.artifact.segments[1].networkConfigs[0].actionInputs[0].gas = '1100000';
        await assert.rejects(replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow), /tree changed/);
        assert.deepEqual(fixture.calls, []);
    } finally { fs.rmSync(fixture.directory, { recursive: true, force: true }); }
});

test('sanitized live failures remain actionable while arbitrary provider errors remain withheld', async () => {
    const { LiveQualificationError } = require('./qualify-resolver-live-rpc');
    const record = { transactionHash: ROOT };
    await captureFailure({ send: async () => { throw new Error('secret RPC response'); } }, record,
        new LiveQualificationError('Live qualification failed: requested64000000, effective50000000; evidence retained'), () => {});
    assert.match(record.failure, /requested64000000, effective50000000/);
    assert(!JSON.stringify(record).includes('secret RPC response'));
});

test('explicit live dispatch keeps heterogeneous leaves singleton when the legacy SDK groups smaller actions', async () => {
    const raw = config(1, 3, '14000000');
    raw.actionInputs[1].gas = '1000000';
    raw.actionInputs[2].gas = '2000000';
    const before = structuredClone(raw);
    const live = capLiveExecutionConfig(raw, 4);
    const tree = makeSphinxMerkleTree(makeDeploymentData([live]));
    const leaves = tree.leavesWithProofs.filter(entry => entry.leaf.leafType === SphinxLeafType.EXECUTE);
    let next = 1n;
    const model = { activeMerkleRoot: async () => tree.root,
        merkleRootStates: async () => ({ status: next === 4n ? 2 : 1, leavesExecuted: next }),
        getAddress: async () => MODULE };
    const legacy = await executeBatchActions(leaves, model, BigInt(live.blockGasLimit), {}, 0,
        async batch => { next += BigInt(batch.length); return { status: 1 }; }, estimateGasViaManagedService,
        { deployment: { chainId: live.chainId } });
    assert(legacy.batches.some(batch => batch.length > 1), 'The actual legacy SDK must reproduce the smaller-leaf grouping.');
    assert.deepEqual(legacy.batches.flat(), leaves);
    const explicit = await sdkExecutionBatches(live, leaves, { liveRpc: true });
    assert.deepEqual(explicit.map(batch => batch.map(entry => Number(entry.leaf.index))), [[1], [2], [3]]);
    assert.deepEqual(explicit.flat(), leaves);
    assert.deepEqual(live.actionInputs, before.actionInputs, 'Transaction policy must not alter signed gas or canonical bytes.');
    assert.equal(tree.root, makeSphinxMerkleTree(makeDeploymentData([before])).root);
    assert.deepEqual(raw, before);
    await assert.rejects(sdkExecutionBatches(live, [leaves[0], leaves[2]], { liveRpc: true }), /not contiguous/);
});

test('chain-aware fresh replay selects policy before the fork and records both mode postconditions exactly once', async () => {
    const owner = require('./qualify-chain-gas');
    const fixture = replayFixture({ multipleExecutionTransactions: true, liveRpc: true, gas: '14000000' });
    const oldSelect = owner.selectProof, oldWrite = owner.writeForkProof;
    const selected = { chainId: '1', policy: { backend: 'exact-root-fork' }, engine: { binarySha256: 'engine' } };
    try {
        const qfile = path.join(fixture.directory, 'qualification.json');
        const q = JSON.parse(fs.readFileSync(qfile)); q.proofSelections = [selected]; fs.writeFileSync(qfile, JSON.stringify(q));
        fixture.workflow.chainAware = true;
        const header = fixture.workflow.replayDependencies.readHeader;
        fixture.workflow.replayDependencies.readHeader = async (...args) => { const result = await header(...args); result.block.timestamp = 1793300000; return result; };
        owner.selectProof = async (_config, chain) => { assert.equal(chain.blockTimestamp, 1793300000); fixture.calls.push(['select-policy']); return selected; };
        const open = fixture.workflow.replayDependencies.openContext;
        fixture.workflow.replayDependencies.openContext = async (...args) => {
            assert.equal(args[4].chainProof, selected); assert(fixture.calls.some(call => call[0] === 'select-policy'));
            const context = await open(...args); context.chainProof = selected; return context;
        };
        const verify = fixture.workflow.verifyFinal;
        fixture.workflow.verifyFinal = async context => { await verify(context); context.report.recipientsAndOutfitsVerified = true; context.report.tokenCount = 2; };
        owner.writeForkProof = async (context, _config, _chain, _tree, _directory, records) => {
            assert.deepEqual(context.report.forkPostconditions.map(item => item.mode), ['cold', 'sdk-singletons']);
            assert.deepEqual(records.map(item => item.mode), ['cold', 'sdk-singletons']);
            return { normalized: { chainId: '1', actions: [] } };
        };
        const result = await replayPreparedPart(fixture.artifact, fixture.directory, 1, fixture.workflow);
        assert.equal(result.report.status, 'passed'); assert.equal(result.report.forkProofs.length, 1);
        assert.equal(fixture.calls.filter(call => call[0] === 'verify').length, 2);
    } finally { owner.selectProof = oldSelect; owner.writeForkProof = oldWrite; fs.rmSync(fixture.directory, { recursive: true, force: true }); }
});
