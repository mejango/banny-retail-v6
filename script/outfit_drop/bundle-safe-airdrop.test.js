const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { ethers } = require('ethers');
const { loadOriginalParts, validateSelectionReport, reviewedRunnerSources, verifyImplementationHashes } = require('./bundle-safe-airdrop');
const { SAFE_TRANSACTION_FIELDS, MULTISEND, combineMigrationBatches } = require('./export-safe-airdrop');

test('bundle input verification binds source bytes, context and original signed fields to the audit', () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-bundle-source-'));
    const safe = '0x1111111111111111111111111111111111111111';
    const fields = [...SAFE_TRANSACTION_FIELDS, 'nonce'];
    const types = { SafeTx: fields.map((name, index) => ({ name,
        type: ['address', 'uint256', 'bytes', 'uint8', 'uint256', 'uint256', 'uint256', 'address', 'address', 'uint256'][index] })) };
    const original = { chainId: '1', sourceChainId: 1, safe, helper: safe, stage: 'migration', order: 2,
        expectedTokenIds: [1000000001], transaction: { to: safe, value: '0', data: '0x1234', operation: 1,
            safeTxGas: '0', baseGas: '0', gasPrice: '0', gasToken: ethers.constants.AddressZero,
            refundReceiver: ethers.constants.AddressZero, nonce: null } };
    const builder = { chainId: '1', meta: { createdFromSafeAddress: safe }, transactions: [] };
    const index = { files: {} };
    const put = (file, value) => {
        const contents = JSON.stringify(value);
        fs.writeFileSync(path.join(directory, file), contents);
        return index.files[file] = crypto.createHash('sha256').update(contents).digest('hex');
    };
    try {
        const source = { nativeFile: 'source.safe-tx.json', nativeSha256: put('source.safe-tx.json', original),
            builderFile: 'source.json', builderSha256: put('source.json', builder) };
        const proposal = { ...original, transaction: { ...original.transaction, nonce: '18' }, source };
        proposal.safeTxHash = ethers.utils._TypedDataEncoder.hash({ chainId: 1, verifyingContract: safe }, types, proposal.transaction);
        const chain = { chainId: 1, safe, proposals: [proposal] };
        assert.deepEqual(loadOriginalParts(chain, directory, index), [{ batch: builder, safeTransaction: original, originalProposal: proposal }]);
        for (const mutate of [
            p => { p.helper = ethers.constants.AddressZero; },
            p => { p.expectedTokenIds = [1000000002]; },
            p => { p.transaction.data = '0xabcd'; },
            p => { p.transaction.nonce = '19'; },
            p => { p.safeTxHash = ethers.constants.HashZero; },
        ]) {
            const changed = structuredClone(chain);
            mutate(changed.proposals[0]);
            assert.throws(() => loadOriginalParts(changed, directory, index), /changed/);
        }
        const changedIndex = structuredClone(index);
        changedIndex.files[source.nativeFile] = 'wrong';
        assert.throws(() => loadOriginalParts(chain, directory, changedIndex), /outside original audit/);
        fs.appendFileSync(path.join(directory, source.builderFile), '\n');
        assert.throws(() => loadOriginalParts(chain, directory, index), /Changed audited source/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('bundle publication requires exact chain gas budgets and a complete recomputed minimum proof', () => {
    const budget = 15_938_355;
    const selection = {
        blockGasLimit: '60000000', gasBudget: budget, executionGasCap: 16_777_216,
        headroomPercent: 5, transactionGasLimit: budget,
        probeEdges: [
            { start: 0, end: 1, success: true, simulationGasLimit: budget },
            { start: 0, end: 2, success: false, simulationGasLimit: budget, failures: [{ error: 'OutOfGas', reason: '0x' }] },
            { start: 1, end: 2, success: true, simulationGasLimit: budget },
        ],
        minimality: { minimumTransactions: 2, ranges: [{ start: 0, end: 1 }, { start: 1, end: 2 }] },
        bundles: [
            { sourceOrders: [2], simulationGasLimit: budget, gasUsed: '12000000' },
            { sourceOrders: [3], simulationGasLimit: budget, gasUsed: '9000000' },
        ],
    };
    assert.equal(validateSelectionReport(1, [2, 3], selection).minimumTransactions, 2);
    for (const mutate of [
        s => { s.gasBudget++; },
        s => { s.executionGasCap++; },
        s => { s.headroomPercent = 0; },
        s => { s.transactionGasLimit++; },
        s => { s.probeEdges[0].simulationGasLimit++; },
        s => { s.probeEdges[1].failures = [{ error: 'Execution reverted', reason: 'wrong recipient' }]; },
        s => { s.probeEdges.pop(); },
        s => { s.probeEdges[1].success = true; },
        s => { s.bundles[1].simulationGasLimit++; },
        s => { s.bundles[1].sourceOrders = [4]; },
        s => { s.bundles[1].gasUsed = String(budget); },
    ]) {
        const changed = structuredClone(selection);
        mutate(changed);
        assert.throws(() => validateSelectionReport(1, [2, 3], changed));
    }
    assert.throws(() => validateSelectionReport(42161, [2, 3], selection), /budget/);
});

test('two-bundle certificate needs a real full-distribution gas failure and exact complete replay coverage', () => {
    const safe = '0x1111111111111111111111111111111111111111';
    const multisend = new ethers.utils.Interface(['function multiSend(bytes)']);
    const zero = ethers.constants.AddressZero;
    const parts = [0, 1].map(index => {
        const transactions = [{ to: safe, value: '0', data: '0x1234' }, { to: safe, value: '0', data: '0x5678' }];
        const packed = ethers.utils.hexConcat(transactions.map(tx => ethers.utils.solidityPack(
            ['uint8', 'address', 'uint256', 'uint256', 'bytes'], [0, tx.to, 0, 2, tx.data])));
        return { batch: { chainId: '42161', meta: { createdFromSafeAddress: safe }, transactions },
            safeTransaction: { chainId: '42161', sourceChainId: 42161, safe, hook: safe, resolver: safe,
                helper: safe, implementation: safe, helperContractName: 'Executor', implementationContractName: 'Implementation',
                stage: 'migration', order: index + 2, expectedTokenIds: [1000000001 + index],
                transaction: { to: MULTISEND, value: '0', data: multisend.encodeFunctionData('multiSend', [packed]),
                    operation: 1, safeTxGas: '0', baseGas: '0', gasPrice: '0', gasToken: zero, refundReceiver: zero, nonce: null } } };
    });
    const whole = combineMigrationBatches(parts).safeTransaction;
    whole.transaction.nonce = '10';
    const fields = [...SAFE_TRANSACTION_FIELDS, 'nonce'];
    const types = { SafeTx: fields.map((name, i) => ({ name,
        type: ['address', 'uint256', 'bytes', 'uint8', 'uint256', 'uint256', 'uint256', 'address', 'address', 'uint256'][i] })) };
    whole.safeTxHash = ethers.utils._TypedDataEncoder.hash({ chainId: 42161, verifyingContract: safe }, types, whole.transaction);
    const selection = { status: 'passed', proofKind: 'two-bundle-lower-bound', blockGasLimit: '60000000', gasBudget: 30400000,
        executionGasCap: 32000000, headroomPercent: 5, transactionGasLimit: 30400000, migrationStartNonce: '10',
        wholeCandidate: { sourceOrders: [2, 3], nonce: '10', safeTransactionHash: whole.safeTxHash, safeTransaction: whole,
            transactionHash: ethers.utils.id('mined whole candidate'), blockHash: ethers.utils.id('local receipt block'), blockNumber: 123,
            simulationGasLimit: 30400000, gasUsed: '30300000', receiptStatus: 0, success: false,
            failures: [{ error: 'OutOfGas', reason: '0x' }] },
        minimality: { minimumTransactions: 2, ranges: [{ start: 0, end: 1 }, { start: 1, end: 2 }] },
        bundles: [{ sourceOrders: [2], nonce: '10', simulationGasLimit: 30400000, gasUsed: '17000000' },
            { sourceOrders: [3], nonce: '11', simulationGasLimit: 30400000, gasUsed: '18000000' }] };
    assert.equal(validateSelectionReport(42161, [2, 3], selection, parts).minimumTransactions, 2);
    for (const mutate of [
        s => { s.status = 'running'; },
        s => { s.wholeCandidate.receiptStatus = undefined; },
        s => { delete s.wholeCandidate.transactionHash; },
        s => { s.wholeCandidate.blockHash = '0x1234'; },
        s => { s.wholeCandidate.blockNumber = 0; },
        s => { s.wholeCandidate.success = true; },
        s => { s.wholeCandidate.failures = [{ error: 'SERVER_ERROR', reason: 'timeout' }]; },
        s => { s.wholeCandidate.sourceOrders = [2]; },
        s => { s.wholeCandidate.nonce = '11'; },
        s => { s.wholeCandidate.safeTransaction.transaction.data = '0x1234'; },
        s => { s.wholeCandidate.safeTransactionHash = ethers.constants.HashZero; },
        s => { s.wholeCandidate.simulationGasLimit++; },
        s => { s.minimality.ranges[1].start = 0; },
        s => { s.bundles[1].sourceOrders = [2]; },
        s => { s.bundles.pop(); },
    ]) {
        const changed = structuredClone(selection);
        mutate(changed);
        assert.throws(() => validateSelectionReport(42161, [2, 3], changed, parts));
    }
    assert.throws(() => validateSelectionReport(42161, [2, 3], selection), /exact original/);
});

test('older runner proofs require an explicitly supplied exact archive while composer and generator stay current', () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-runner-source-'));
    try {
        const archived = path.join(directory, 'frozen-runner.js');
        fs.writeFileSync(archived, 'frozen reviewed runner');
        const hashes = Object.fromEntries(['export-safe-airdrop.js', 'generate-v6-airdrop.js'].map(file =>
            [file, ethers.utils.keccak256(fs.readFileSync(path.join(__dirname, file)))]));
        hashes['simulate-safe-airdrop.js'] = ethers.utils.keccak256(fs.readFileSync(archived));
        const report = { implementationHashes: hashes };
        assert.throws(() => verifyImplementationHashes(report, reviewedRunnerSources()), /explicitly supplied/);
        const archives = reviewedRunnerSources([archived]);
        assert.equal(verifyImplementationHashes(report, archives).file, 'frozen-runner.js');
        for (const file of ['export-safe-airdrop.js', 'generate-v6-airdrop.js']) {
            assert.throws(() => verifyImplementationHashes({ implementationHashes: { ...hashes, [file]: ethers.constants.HashZero } }, archives), /code changed/);
        }
        fs.writeFileSync(archived, 'modified archived source');
        assert.throws(() => verifyImplementationHashes(report, reviewedRunnerSources([archived])), /explicitly supplied/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
