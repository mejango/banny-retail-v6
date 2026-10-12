const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { ethers } = require('ethers');
const { validateBuilder, rewrap, validateInventory, validateReplay, UI_WRAPPERS } = require('./export-safe-ui-airdrop');
const { gasBudget } = require('./simulate-safe-airdrop');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const address = '0x0000000000000000000000000000000000000001';
function fixture() {
    const builder = { chainId: '1', meta: { createdFromSafeAddress: address }, transactions: [{ to: address, value: '0', data: '0x12345678' }] };
    const bytes = Buffer.from(JSON.stringify(builder));
    const data = new ethers.utils.Interface(['function multiSend(bytes)']).encodeFunctionData('multiSend', [
        ethers.utils.solidityPack(['uint8','address','uint256','uint256','bytes'], [0, address, 0, 4, '0x12345678']),
    ]);
    const proposal = { safeTxHash: ethers.constants.HashZero, approveHashTransaction: { data: 'old' },
        transaction: { to: address, operation: 1, nonce: '12', data }, expectedTokenIds: [1000000001],
        source: { builderSha256: sha(bytes) }, simulation: { safeTransactionHash: ethers.constants.HashZero } };
    const chain = { chainId: 1, safe: address, multiSendAddress: address };
    return { builder, bytes, proposal, chain };
}
test('Safe UI rebinding preserves all reviewed calls, allocation, nonce, and provenance', () => {
    const { proposal, chain } = fixture(), before = structuredClone(proposal);
    const actual = rewrap(proposal, chain, UI_WRAPPERS['1.4.1']);
    assert.deepEqual(proposal, before);
    assert.deepEqual(actual.transaction, { ...proposal.transaction, to: UI_WRAPPERS['1.4.1'].address });
    assert.deepEqual(actual.expectedTokenIds, proposal.expectedTokenIds);
    assert.equal(actual.safeTxHash, undefined);
    assert.equal(actual.approveHashTransaction, undefined);
    assert.equal(actual.simulation, undefined);
    assert.deepEqual(actual.safeUiProvenance.previousSimulation, proposal.simulation);
    assert.throws(() => rewrap({ ...proposal, transaction: { ...proposal.transaction, operation: 0 } }, chain, UI_WRAPPERS['1.4.1']));
});
test('Builder validation rejects changed checksum, calls, Safe, chain, ETH, and delegatecalls', () => {
    const { builder, bytes, proposal, chain } = fixture();
    assert.deepEqual(validateBuilder(bytes, proposal, chain), builder);
    assert.throws(() => validateBuilder(Buffer.concat([bytes, Buffer.from(' ')]), proposal, chain));
    for (const change of [b => b.chainId = '10', b => b.meta.createdFromSafeAddress = ethers.constants.AddressZero,
        b => b.transactions[0].data = '0xdeadbeef', b => b.transactions[0].value = '1', b => b.transactions[0].operation = 1]) {
        const modified = structuredClone(builder); change(modified);
        const modifiedBytes = Buffer.from(JSON.stringify(modified));
        assert.throws(() => validateBuilder(modifiedBytes, { ...proposal, source: { builderSha256: sha(modifiedBytes) } }, chain));
    }
});
test('Preparation rejects stale or conflicting live authority and approvals inventory', () => {
    const sourceBytes = Buffer.from('source');
    const source = { chains: [{ chainId: 1, live: { nonce: '9' } }] };
    const live = { chainId: 1, liveNonce: '9', ownerDrift: false, threshold: 2, helperDeployed: false, implementationDeployed: false,
        onchainApprovals: [{ owners: [] }], queuedTransactions: [{ isReviewedSetup: true, sameDistributionCalldata: [] }] };
    const inventory = { manifestSha256: sha(sourceBytes), completedAt: new Date().toISOString(), failures: [], chains: [live] };
    validateInventory(inventory, sourceBytes, source);
    for (const change of [x => x.completedAt = '2000-01-01', x => x.chains[0].liveNonce = '10', x => x.chains[0].ownerDrift = true,
        x => x.chains[0].helperDeployed = true, x => x.chains[0].onchainApprovals[0].owners.push(address),
        x => x.chains[0].queuedTransactions[0].occupiesDistributionNonce = true]) {
        const modified = structuredClone(inventory); change(modified);
        assert.throws(() => validateInventory(modified, sourceBytes, source));
    }
});
test('Finalization binds successful reports to exact inputs, gas policy, outcomes, and rollback guards', () => {
    const chain = { chainId: 10, safe: address, safeVersion: '1.4.1', live: { nonce: '9', threshold: 2 }, proposals: [{}] };
    const budget = gasBudget(10, '60000000');
    const inputs = ['setup','migration'].map((stage,index) => {
        const envelope = { stage, safeTxHash: ethers.utils.hexZeroPad(ethers.utils.hexlify(index),32),
            transaction: { nonce: String(9 + index) }, expectedTokenIds: stage === 'migration' ? [1000000001] : [] };
        return { file: `${index}.safe-tx.json`, bytes: Buffer.from(JSON.stringify(envelope)), envelope };
    });
    const report = { status: 'passed', chainId: 10, safe: address, safeVersion: '1.4.1', threshold: 2,
        startNonce: '9', endNonce: '11', blockGasLimit: '60000000', gasBudget: budget.budget, transactionGasLimit: budget.budget,
        executionGasCap: budget.executionGasCap, headroomPercent: budget.headroomPercent, anvilHardfork: 'osaka', ethereumTransactionCapEnabled: true,
        failures: ['mint-drift','duplicate'].map(check => ({ check, reverted: true })),
        chunks: inputs.map(input => ({ file: input.file, fileKeccak256: ethers.utils.keccak256(input.bytes), stage: input.envelope.stage,
            nonce: input.envelope.transaction.nonce, safeTransactionHash: input.envelope.safeTxHash,
            tokenCount: input.envelope.expectedTokenIds.length, gasUsed: '1000000', recipientParity: true, helperBalance: '0' })) };
    validateReplay(chain, report, inputs);
    for (const change of [r => r.status = 'running', r => r.gasBudget++, r => r.chunks[1].safeTransactionHash = ethers.constants.HashZero,
        r => r.chunks[1].fileKeccak256 = ethers.constants.HashZero, r => r.chunks[1].nonce = '11',
        r => r.chunks[1].tokenCount = 2, r => r.chunks[1].recipientParity = false,
        r => r.chunks[1].helperBalance = '1', r => r.failures.pop()]) {
        const modified = structuredClone(report); change(modified);
        assert.throws(() => validateReplay(chain, modified, inputs));
    }
});
