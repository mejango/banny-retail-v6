const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { ethers } = require('ethers');
const { buildContractsByChain, loadRawItems, itemTokenId } = require('./generate-v6-airdrop');
const { migrationPlan, validateCoverage, hasExecutionSuccess, readTransactions, gasBudget, simulationPolicy,
    minimumContiguousPartition, assertBoundHash, verifyRecipients, isGasExhaustion, requireGasExhaustedCandidate } = require('./simulate-safe-airdrop');
const { partitionPlan } = require('./export-safe-airdrop');

const byChain = buildContractsByChain(loadRawItems());
const plans = new Map(Object.values(byChain).flat().map(plan => [plan.contractName, plan]));
const envelopeFor = plan => ({ contractName: plan.contractName, sourceChainId: plan.chain.id,
    stage: 'migration', slice: plan.slice, expectedTokenIds: [...plan.assignments.expectedTokenIds] });

test('fork verification uses original generator coverage and rejects missing, repeated or reordered IDs', () => {
    for (const chainPlans of Object.values(byChain)) {
        const envelopes = chainPlans.flatMap(plan => partitionPlan(plan).map(envelopeFor));
        assert.equal(validateCoverage(envelopes, plans).length, envelopes.length);
        assert.throws(() => validateCoverage([...envelopes, envelopes[0]], plans), /repeat token IDs/);
        const missing = structuredClone(envelopes);
        missing[0].expectedTokenIds.pop();
        assert.throws(() => validateCoverage(missing, plans));
        const reordered = structuredClone(envelopes);
        reordered[0].expectedTokenIds.reverse();
        assert.throws(() => validateCoverage(reordered, plans), /original mint order/);
    }
});

test('a sliced migration cannot separate a body from its worn assets', () => {
    const plan = partitionPlan(byChain[1][0])[0];
    const banny = plan.bannies.find(body => body.outfitIds.length > 0);
    const mapping = plan.assignments.v4ToV6TokenIds;
    const envelope = envelopeFor(plan);
    const subset = migrationPlan(envelope, plans);
    assert(subset.bannies.some(body => body.tokenId === banny.tokenId));
    envelope.expectedTokenIds = envelope.expectedTokenIds.filter(id => id !== mapping.get(banny.outfitIds[0]));
    assert.throws(() => migrationPlan(envelope, plans), /all its assets/);
});

test('reordering locally valid slices cannot change the original per-tier issuance sequence', () => {
    const envelopes = byChain[1].flatMap(plan => partitionPlan(plan).map(envelopeFor));
    [envelopes[0], envelopes[1]] = [envelopes[1], envelopes[0]];
    assert.throws(() => validateCoverage(envelopes, plans), /per-tier token IDs/);
});

test('Safe success requires the exact emitting Safe and hash across installed 1.3 and 1.4 event ABIs', () => {
    const { ethers } = require('ethers');
    const safe = '0x1111111111111111111111111111111111111111';
    const hash = ethers.utils.id('approved transaction');
    for (const artifact of ['v1.3.0/GnosisSafe.sol/GnosisSafe.json', 'v1.4.1/Safe.sol/Safe.json']) {
        const { abi } = require(`@sphinx-labs/contracts/contract-artifacts/gnosis-safe/${artifact}`);
        const iface = new ethers.utils.Interface(abi);
        const log = { ...iface.encodeEventLog(iface.getEvent('ExecutionSuccess'), [hash, 0]), address: safe };
        assert(hasExecutionSuccess({ logs: [log] }, safe, hash));
        assert(!hasExecutionSuccess({ logs: [log] }, ethers.constants.AddressZero, hash));
        assert(!hasExecutionSuccess({ logs: [log] }, safe, ethers.constants.HashZero));
    }
});

const originalsFor = chainId => byChain[chainId].flatMap(plan => partitionPlan(plan).map(envelopeFor))
    .map((envelope, index) => ({ ...envelope, order: index + 2 }));
const bundleFor = components => ({ ...components[0], contractName: 'BannyAirdropBundle', slice: 0, chunk: null,
    expectedTokenIds: components.flatMap(component => component.expectedTokenIds), components });

test('bundles retain each canonical original slice, coverage, context and per-tier order', () => {
    for (const chain of Object.keys(byChain)) {
        const originals = originalsFor(chain);
        const bundle = bundleFor(originals);
        assert.equal(migrationPlan(bundle, plans).components.length, originals.length);
        assert.equal(validateCoverage([bundle], plans).length, 1);
        const corrupt = structuredClone(bundle);
        corrupt.components[0].slice = 999;
        assert.throws(() => migrationPlan(corrupt, plans), /Unknown migration slice/);
        const missing = structuredClone(bundle);
        missing.expectedTokenIds.pop();
        assert.throws(() => migrationPlan(missing, plans), /IDs differ/);
        const mixed = structuredClone(bundle);
        mixed.components[0].helper = '0x1111111111111111111111111111111111111111';
        assert.throws(() => migrationPlan(mixed, plans), /helper differs/);
        const nested = structuredClone(bundle);
        nested.components[0].components = [];
        assert.throws(() => migrationPlan(nested, plans), /Nested/);
        if (originals.length > 1) {
            const reversed = bundleFor([...originals].reverse());
            assert.throws(() => migrationPlan(reversed, plans), /consecutive/);
            const incomplete = bundleFor(originals.slice(1));
            assert.throws(() => validateCoverage([incomplete], plans), /omit or add/);
        }
    }
});

test('queued prerequisites run before setup and never weaken migration coverage', () => {
    const migration = bundleFor(originalsFor(10));
    const prefix = [{ stage: 'prerequisite' }, { stage: 'setup' }];
    assert.equal(validateCoverage([...prefix, migration], plans).length, 1);
    assert.throws(() => validateCoverage([migration, ...prefix], plans), /must precede/);
    assert.throws(() => validateCoverage([...prefix.reverse(), migration], plans), /must precede/);
    assert.throws(() => validateCoverage([{ stage: 'unknown' }, migration], plans), /obsolete/);
});

test('exact outer gas budgets reserve 5 percent and do not depend on refunded receipt gas', () => {
    for (const chainId of [1, 10, 8453, 11155111, 11155420, 84532]) {
        assert.deepEqual(gasBudget(chainId), { executionGasCap: 16_777_216, budget: 15_938_355, headroomPercent: 5 });
    }
    for (const chainId of [42161, 421614]) {
        assert.deepEqual(gasBudget(chainId), { executionGasCap: 32_000_000, budget: 30_400_000, headroomPercent: 5 });
        assert.throws(() => gasBudget(chainId, 30_399_999), /below/);
        assert.equal(gasBudget(chainId, ethers.BigNumber.from(32_000_000)).budget, 30_400_000);
    }
});

test('final bundle replay uses chain budgets without selecting a new partition or changing legacy replay', () => {
    const originals = originalsFor(1);
    const bundles = [bundleFor(originals)];
    for (const chainId of [1, 10, 8453, 11155111, 84532, 42161, 421614]) {
        const expected = gasBudget(chainId);
        const replay = simulationPolicy(bundles, chainId, 60_000_000);
        assert.equal(replay.selection, false, 'Final bundles must stay on the exact rehearsal path.');
        assert.deepEqual(replay.budget, expected);
        assert.equal(replay.gasLimit, expected.budget);
        const search = simulationPolicy(originals, chainId, 60_000_000, { selection: true });
        assert.equal(search.selection, true);
        assert.deepEqual(search.budget, replay.budget);
        const lowerBound = simulationPolicy(originals, chainId, 60_000_000, { twoBundleSplit: 4 });
        assert.equal(lowerBound.selection, true);
        assert.deepEqual(lowerBound.budget, replay.budget);
        assert.deepEqual(simulationPolicy(originals, chainId, 60_000_000), { selection: false, budget: null, gasLimit: 16_777_216 });
        assert.deepEqual(simulationPolicy(originals, chainId, 12_000_000), { selection: false, budget: null, gasLimit: 12_000_000 });
        assert.throws(() => simulationPolicy(bundles, chainId, expected.budget - 1), /below/);
        assert.throws(() => simulationPolicy(bundles, chainId, 'invalid block gas limit'));
    }
    for (const components of [null, [], {}]) {
        assert.throws(() => validateCoverage([{ ...bundles[0], components }], plans), /original components/);
    }
});

function edgesFor(count, fits) {
    return Array.from({ length: count }, (_, start) => Array.from({ length: count - start }, (_, offset) => ({
        start, end: start + offset + 1, success: fits(start, start + offset + 1),
    }))).flat();
}

test('minimum partition uses complete interval evidence and beats greedy longest-first', () => {
    const fits = new Set(['0:1', '0:2', '1:2', '1:4', '2:3', '3:4']);
    const edges = edgesFor(4, (start, end) => fits.has(`${start}:${end}`));
    assert.deepEqual(minimumContiguousPartition(4, edges), { minimumTransactions: 2,
        ranges: [{ start: 0, end: 1 }, { start: 1, end: 4 }], minimumByPrefix: [0, 1, 1, 2, 2] });
    assert.throws(() => minimumContiguousPartition(4, edges.slice(1)), /every contiguous interval/);
    assert.throws(() => minimumContiguousPartition(4, [...edges, edges[0]]), /Repeated/);
    assert.throws(() => minimumContiguousPartition(19, []), /1 to 18/);
    assert.throws(() => minimumContiguousPartition(2, edgesFor(2, () => false)), /No complete/);
});

test('minimum DP matches exhaustive partitions for every four-shard feasibility matrix', () => {
    const all = edgesFor(4, () => false);
    for (let mask = 0; mask < 2 ** all.length; mask++) {
        const edges = all.map((edge, index) => ({ ...edge, success: Boolean(mask & (1 << index)) }));
        const success = new Set(edges.filter(edge => edge.success).map(edge => `${edge.start}:${edge.end}`));
        function brute(start) {
            if (start === 4) return 0;
            return Math.min(...Array.from({ length: 4 - start }, (_, i) => start + i + 1)
                .map(end => success.has(`${start}:${end}`) ? 1 + brute(end) : Infinity));
        }
        const expected = brute(0);
        if (Number.isFinite(expected)) assert.equal(minimumContiguousPartition(4, edges).minimumTransactions, expected);
        else assert.throws(() => minimumContiguousPartition(4, edges), /No complete/);
    }
});

test('normal execution rejects a supplied stale or unbound Safe transaction hash', () => {
    const hash = ethers.utils.id('exact bound transaction');
    assertBoundHash({ transaction: { nonce: '18' }, safeTxHash: hash }, hash);
    assertBoundHash({ transaction: { nonce: null } }, hash);
    assert.throws(() => assertBoundHash({ transaction: { nonce: '18' }, safeTxHash: ethers.constants.HashZero }, hash), /differs from exact execution/);
    assert.throws(() => assertBoundHash({ transaction: { nonce: null }, safeTxHash: hash }, hash), /bound nonce/);
});

test('only traced gas exhaustion establishes infeasibility, never semantic revert text', () => {
    const exhausted = { error: 'EvmError: OutOfGas', reason: '0x' };
    assert(isGasExhaustion([exhausted, { error: 'execution reverted', reason: 'GS013' }]));
    assert(!isGasExhaustion([{ error: 'execution reverted', reason: 'out of gas' }]));
    assert(!isGasExhaustion([exhausted, { error: 'execution reverted', reason: 'Wrong owner' }]));
    assert(!isGasExhaustion([]));
});

test('whole-distribution lower bound requires mined failure and real gas exhaustion', async () => {
    const hash = ethers.utils.id('whole distribution');
    const receipt = { status: 0, transactionHash: hash, blockHash: ethers.utils.id('mined block'), blockNumber: 10,
        gasUsed: ethers.BigNumber.from(29_950_000) };
    const execution = { receipt, success: false, nonce: '18', hash,
        safeTransaction: { transaction: { nonce: '18' }, safeTxHash: hash } };
    const exhausted = { error: 'out of gas', output: '0x' };
    const revert = reason => ({ error: 'execution reverted', output: ethers.utils.hexConcat([
        '0x08c379a0', ethers.utils.defaultAbiCoder.encode(['string'], [reason]),
    ]) });
    let trace = { ...revert('GS013'), calls: [exhausted] };
    let traceCalls = 0;
    const provider = { send: async (method, args) => {
        traceCalls++;
        assert.equal(method, 'debug_traceTransaction');
        assert.equal(args[0], hash);
        return trace;
    } };
    const certificate = await requireGasExhaustedCandidate(provider, Promise.resolve(execution));
    assert.equal(certificate.receiptStatus, 0);
    assert.equal(certificate.success, false);
    assert.equal(certificate.nonce, '18');
    assert.equal(certificate.safeTransactionHash, hash);
    assert.deepEqual(certificate.safeTransaction, execution.safeTransaction);
    assert.equal(certificate.gasUsed, '29950000');
    assert.equal(certificate.blockNumber, receipt.blockNumber);
    assert.equal(certificate.blockHash, receipt.blockHash);
    assert.equal(certificate.transactionHash, receipt.transactionHash);
    assert(isGasExhaustion(certificate.failures));
    for (const invalid of [
        { ...execution, receipt: undefined },
        { ...execution, receipt: { ...receipt, blockNumber: null } },
        { ...execution, receipt: { ...receipt, blockHash: null } },
        { ...execution, receipt: { ...receipt, status: 1 } },
        { ...execution, success: true },
    ]) {
        const before = traceCalls;
        await assert.rejects(requireGasExhaustedCandidate(provider, invalid));
        assert.equal(traceCalls, before, 'Invalid receipt must never reach gas classification.');
    }
    for (trace of [revert('out of gas'), {}, { ...revert('wrong recipient'), calls: [exhausted] }]) {
        await assert.rejects(requireGasExhaustedCandidate(provider, execution), /without traced gas exhaustion/);
    }
    for (const code of ['TIMEOUT', 'NETWORK_ERROR']) {
        const error = Object.assign(new Error(`${code}: unavailable pinned state`), { code });
        const before = traceCalls;
        await assert.rejects(requireGasExhaustedCandidate(provider, Promise.reject(error)), actual => actual === error);
        assert.equal(traceCalls, before, 'Execution/RPC failures must never count as gas exhaustion.');
        await assert.rejects(requireGasExhaustedCandidate({ send: async () => { throw error; } }, execution), actual => actual === error);
    }
});

test('selection reads exact sibling Builder and envelope hashes without requiring a prerequisite Builder', () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'safe-bundle-input-'));
    try {
        const input = JSON.stringify({ stage: 'migration', chainId: '1' });
        const builder = JSON.stringify({ transactions: [{ data: '0xabcd' }] });
        fs.writeFileSync(path.join(directory, '02.safe-tx.json'), input);
        fs.writeFileSync(path.join(directory, '02.json'), builder);
        fs.writeFileSync(path.join(directory, '00.safe-tx.json'), JSON.stringify({ stage: 'prerequisite' }));
        const [prerequisite, migration] = readTransactions(directory, { loadBuilders: true });
        assert.equal(prerequisite.batchBuilder, undefined);
        assert.deepEqual(migration.batchBuilder, JSON.parse(builder));
        assert.equal(migration.fileKeccak256, ethers.utils.keccak256(Buffer.from(input)));
        assert.equal(migration.builderFileKeccak256, ethers.utils.keccak256(Buffer.from(builder)));
        assert.equal(migration.builderFile, '02.json');
        fs.unlinkSync(path.join(directory, '02.json'));
        assert.throws(() => readTransactions(directory, { loadBuilders: true }), /ENOENT/);
        assert.equal(readTransactions(directory).length, 2);
    } finally {
        fs.rmSync(directory, { recursive: true, force: true });
    }
});

test('bundle final verification checks every original recipient, outfit and empty helper', async () => {
    const hook = '0x1111111111111111111111111111111111111111';
    const resolver = '0x2222222222222222222222222222222222222222';
    const helper = '0x3333333333333333333333333333333333333333';
    const originals = originalsFor(1).slice(0, 2).map(envelope => ({ ...envelope, hook, resolver, helper }));
    const bundle = bundleFor(originals);
    const selected = migrationPlan(bundle, plans);
    const iface = new ethers.utils.Interface(['function ownerOf(uint256) view returns(address)',
        'function balanceOf(address) view returns(uint256)', 'function assetIdsOf(address,uint256) view returns(uint256,uint256[])']);
    const expectedOwners = new Map();
    const expectedAssets = new Map();
    for (const { plan } of selected.components) {
        const mapping = plan.assignments.v4ToV6TokenIds;
        for (const id of plan.assignments.expectedTokenIds) expectedOwners.set(String(id), resolver);
        for (const { item, owner } of plan.transferItems) expectedOwners.set(String(mapping.get(itemTokenId(item))), owner);
        for (const banny of plan.bannies) expectedAssets.set(String(mapping.get(banny.tokenId)), [
            banny.backgroundId ? mapping.get(banny.backgroundId) : 0, banny.outfitIds.map(id => mapping.get(id)),
        ]);
    }
    const checkedOwners = new Set();
    const checkedAssets = new Set();
    let corruption;
    const provider = { _isProvider: true, resolveName: async name => name, call: async transaction => {
        const parsed = iface.parseTransaction(transaction);
        if (parsed.name === 'ownerOf') {
            const id = parsed.args[0].toString();
            checkedOwners.add(id);
            return iface.encodeFunctionResult(parsed.name, [corruption === 'owner' ? ethers.constants.AddressZero : expectedOwners.get(id)]);
        }
        if (parsed.name === 'balanceOf') return iface.encodeFunctionResult(parsed.name, [corruption === 'balance' ? 1 : 0]);
        const id = parsed.args[1].toString();
        checkedAssets.add(id);
        return iface.encodeFunctionResult(parsed.name, corruption === 'outfit' ? [999, []] : expectedAssets.get(id));
    } };
    await verifyRecipients(provider, bundle, selected);
    assert.equal(checkedOwners.size, bundle.expectedTokenIds.length);
    assert.equal(checkedAssets.size, expectedAssets.size);
    assert(checkedAssets.size > 0);
    for (corruption of ['owner', 'balance', 'outfit']) await assert.rejects(verifyRecipients(provider, bundle, selected));
});
