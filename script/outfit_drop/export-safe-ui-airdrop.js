#!/usr/bin/env node

// Rebinds the reviewed distributions to the batching contracts used by Safe's UI.
// Preparation and publication are separate: only successful exact replays produce a final manifest.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { parseArgs } = require('node:util');
const { ethers } = require('ethers');
const { bindNonce, SAFE_TRANSACTION_FIELDS, writeExports } = require('./export-safe-airdrop');
const { checkUnexecuted, reviewedRunnerSources, verifyImplementationHashes } = require('./bundle-safe-airdrop');
const { gasBudget } = require('./simulate-safe-airdrop');

const UI_WRAPPERS = {
    '1.4.1': { address: '0x9641d764fc13c8B624c04430C7356C1C7C8102e2', codeHash: '0xecd5bd14a08c5d2122379900b2f272bdf107a7e92423c10dd5fe3254386c9939' },
    '1.3.0': { address: '0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B', codeHash: '0xa9865ac2d9c7a1591619b188c4d88167b50df6cc0c5327fcbd1c8c75f7c066ad' },
};
const UI_CHAINS = [1, 10, 8453, 42161, 11155111, 84532];
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const json = value => `${JSON.stringify(value, null, 2)}\n`;
const readJson = file => JSON.parse(fs.readFileSync(file));
const multiSend = new ethers.utils.Interface(['function multiSend(bytes transactions)']);
const safeTypes = { SafeTx: [...SAFE_TRANSACTION_FIELDS, 'nonce'].map((name, index) => ({ name,
    type: ['address','uint256','bytes','uint8','uint256','uint256','uint256','address','address','uint256'][index] })) };

function validateBuilder(bytes, proposal, chain) {
    assert.equal(sha256(bytes), proposal.source.builderSha256, 'Builder source checksum changed');
    const builder = JSON.parse(bytes);
    assert.equal(String(builder.chainId), String(chain.chainId));
    assert.equal(builder.meta.createdFromSafeAddress.toLowerCase(), chain.safe.toLowerCase());
    const calls = builder.transactions.map(tx => {
        assert.equal(BigInt(tx.value), 0n, 'Airdrop inner call transfers ETH');
        assert(tx.operation === undefined || Number(tx.operation) === 0, 'Builder contains an inner delegatecall');
        return ethers.utils.solidityPack(['uint8','address','uint256','uint256','bytes'],
            [0, tx.to, 0, ethers.utils.arrayify(tx.data).length, tx.data]);
    });
    assert.equal(multiSend.decodeFunctionData('multiSend', proposal.transaction.data)[0].toLowerCase(),
        ethers.utils.hexConcat(calls).toLowerCase(), 'Builder calls differ from the reviewed Safe envelope');
    return builder;
}

function rewrap(proposal, chain, wrapper) {
    assert.equal(proposal.transaction.to.toLowerCase(), chain.multiSendAddress.toLowerCase());
    assert.equal(Number(proposal.transaction.operation), 1);
    const result = structuredClone(proposal);
    result.safeUiProvenance = { previousSafeTxHash: proposal.safeTxHash, previousSource: proposal.source,
        previousSimulation: proposal.simulation, previousMultiSendAddress: chain.multiSendAddress };
    result.transaction.to = wrapper.address;
    delete result.safeTxHash;
    delete result.approveHashTransaction;
    delete result.simulation;
    return result;
}

function validateInventory(inventory, sourceBytes, source) {
    assert.equal(inventory.manifestSha256, sha256(sourceBytes), 'Inventory audited a different source manifest');
    assert.equal(inventory.failures.length, 0, 'Inventory contains failed chain checks');
    assert(Date.now() - Date.parse(inventory.completedAt) < 30 * 60 * 1000, 'Refresh the read-only queue inventory before preparing');
    for (const chain of source.chains.filter(c => UI_CHAINS.includes(c.chainId))) {
        const live = inventory.chains.find(c => c.chainId === chain.chainId);
        assert(live && live.liveNonce === chain.live.nonce && !live.ownerDrift && live.threshold === 2);
        assert(!live.helperDeployed && !live.implementationDeployed, 'Setup has already executed');
        assert(live.onchainApprovals.every(a => a.kind === 'setup' || a.owners.length === 0), 'Existing distribution approvals must be reconciled');
        assert(!live.queuedTransactions.some(tx => tx.occupiesDistributionNonce || tx.exactCurrentHash || tx.sameDistributionCalldata.length),
            'Existing distribution queue entries must be reconciled');
        assert(live.queuedTransactions.some(tx => tx.isReviewedSetup), 'Reviewed setup missing from queue');
    }
}

async function prepare({ source: sourceFile, inventory: inventoryFile, prerequisites, out }) {
    const sourcePath = path.resolve(sourceFile), directory = path.dirname(sourcePath), output = path.resolve(out);
    const sourceBytes = fs.readFileSync(sourcePath), source = JSON.parse(sourceBytes), inventory = readJson(inventoryFile);
    validateInventory(inventory, sourceBytes, source);
    const result = structuredClone(source), files = new Map();
    const add = (file, contents) => { files.set(path.join(output, file), contents); return sha256(contents); };
    const evidence = { status: 'prepared-awaiting-exact-replay', createdAt: new Date().toISOString(),
        sourceManifestSha256: sha256(sourceBytes), inventorySha256: sha256(fs.readFileSync(inventoryFile)),
        exporterSha256: sha256(fs.readFileSync(__filename)), chains: [] };
    add('source-proposals.json', sourceBytes.toString());
    add('source-inventory.json', fs.readFileSync(inventoryFile).toString());
    add('source/export-safe-ui-airdrop.js', fs.readFileSync(__filename).toString());
    for (const chain of result.chains) {
        if (!UI_CHAINS.includes(chain.chainId)) continue;
        const original = source.chains.find(c => c.chainId === chain.chainId);
        const wrapper = UI_WRAPPERS[chain.safeVersion];
        assert(wrapper, `Unreviewed Safe version ${chain.safeVersion}`);
        const provider = new ethers.providers.StaticJsonRpcProvider({ url: chain.rpcUrl, timeout: 30000 }, chain.chainId);
        assert.equal(Number(await provider.send('eth_chainId', [])), chain.chainId);
        const block = await provider.getBlock('latest');
        assert.equal(ethers.utils.keccak256(await provider.getCode(wrapper.address, block.number)), wrapper.codeHash,
            'Safe UI batching contract runtime differs from reviewed deployment');
        const safe = new ethers.Contract(chain.safe, ['function VERSION() view returns(string)', 'function nonce() view returns(uint256)'], provider);
        assert.equal(await safe.VERSION({ blockTag: block.number }), chain.safeVersion);
        assert.equal((await safe.nonce({ blockTag: block.number })).toString(), chain.live.nonce);
        const proofs = [];
        for (const [index, proposal] of original.proposals.entries()) {
            const builderBytes = fs.readFileSync(path.join(directory, proposal.source.builderFile));
            validateBuilder(builderBytes, proposal, original);
            const originalNative = fs.readFileSync(path.join(directory, proposal.source.nativeFile));
            assert.equal(sha256(originalNative), proposal.source.nativeSha256, 'Native source checksum changed');
            const rebound = await bindNonce(rewrap(proposal, original, wrapper), proposal.transaction.nonce, provider);
            assert.equal(ethers.utils._TypedDataEncoder.hash({ chainId: chain.chainId, verifyingContract: chain.safe }, safeTypes, rebound.transaction), rebound.safeTxHash);
            assert.notEqual(rebound.safeTxHash, proposal.safeTxHash);
            const stem = `${chain.chainId}/${String(index + 2).padStart(2, '0')}-distribution-${index + 1}-nonce-${proposal.transaction.nonce}`;
            const builderFile = `${stem}.json`, nativeFile = `${stem}.safe-tx.json`;
            rebound.source = { ...proposal.source, builderFile, nativeFile, builderSha256: add(builderFile, builderBytes.toString()) };
            delete rebound.source.nativeSha256;
            rebound.source.nativeSha256 = add(nativeFile, json(rebound));
            chain.proposals[index] = rebound;
            proofs.push({ index: index + 1, nonce: String(rebound.transaction.nonce), previousHash: proposal.safeTxHash,
                safeTxHash: rebound.safeTxHash, builderFile, builderSha256: rebound.source.builderSha256,
                nativeFile, nativeSha256: rebound.source.nativeSha256 });
        }
        // Preserve the already queued prerequisite/setup inputs byte for byte for the exact replay.
        const prefixDirectory = path.join(path.resolve(prerequisites), String(chain.chainId));
        for (const file of fs.readdirSync(prefixDirectory).filter(file => file.endsWith('.safe-tx.json'))) {
            const bytes = fs.readFileSync(path.join(prefixDirectory, file)), envelope = JSON.parse(bytes);
            if (envelope.stage === 'migration') continue;
            const expected = envelope.stage === 'setup' ? chain.setup : chain.predecessors.find(p => p.safeTxHash === envelope.safeTxHash);
            assert(expected, 'Unreviewed prerequisite in replay inputs');
            assert.equal(expected.safeTxHash, envelope.safeTxHash);
            assert.deepEqual(expected.transaction, envelope.transaction);
            add(`${chain.chainId}/${file}`, bytes.toString());
        }
        chain.multiSendAddress = wrapper.address;
        chain.multiSendCodeHash = wrapper.codeHash;
        evidence.chains.push({ chainId: chain.chainId, safeVersion: chain.safeVersion, wrapper,
            blockNumber: block.number, blockHash: block.hash, unchangedSetupHash: chain.setup.safeTxHash, proposals: proofs });
        console.log(`${chain.name}: prepared ${proofs.length} Safe UI envelopes`);
    }
    result.safeUiExport = evidence;
    add('prepared-proposals.json', json(result));
    add('preparation.json', json(evidence));
    writeExports(files);
    console.log(`Prepared exact replay inputs at ${output}; no final manifest or transaction submission.`);
}

function validateReplay(chain, report, inputs) {
    assert.equal(report.status, 'passed', 'Exact Safe UI replay did not pass');
    assert.equal(report.chainId, chain.chainId);
    assert.equal(report.safe.toLowerCase(), chain.safe.toLowerCase());
    assert.equal(report.safeVersion, chain.safeVersion);
    assert.equal(report.threshold, chain.live.threshold);
    assert.equal(String(report.startNonce), String(chain.live.nonce));
    const budget = gasBudget(chain.chainId, report.blockGasLimit);
    assert.equal(report.gasBudget, budget.budget, 'Replay used the wrong execution budget');
    assert.equal(report.transactionGasLimit, budget.budget);
    assert.equal(report.executionGasCap, budget.executionGasCap);
    assert.equal(report.headroomPercent, budget.headroomPercent);
    assert.equal(report.anvilHardfork, 'osaka');
    assert.equal(report.ethereumTransactionCapEnabled, ![42161,421614].includes(chain.chainId));
    assert.equal(report.chunks.length, inputs.length, 'Replay did not execute every exact input');
    assert.equal(BigInt(report.endNonce) - BigInt(report.startNonce), BigInt(inputs.length));
    for (const [index, input] of inputs.entries()) {
        const chunk = report.chunks[index], envelope = input.envelope;
        assert.equal(chunk.file, input.file, 'Replay input order/file differs');
        assert.equal(chunk.fileKeccak256, ethers.utils.keccak256(input.bytes), 'Replay input bytes changed');
        assert.equal(chunk.stage, envelope.stage);
        assert.equal(String(chunk.nonce), String(envelope.transaction.nonce));
        assert.equal(chunk.safeTransactionHash, envelope.safeTxHash, 'Replay executed a different Safe hash');
        assert.equal(chunk.tokenCount, envelope.stage === 'migration' ? envelope.expectedTokenIds.length : 0);
        assert(BigInt(chunk.gasUsed) > 0n && BigInt(chunk.gasUsed) < BigInt(budget.budget), 'Replay lacks bounded successful gas use');
        if (envelope.stage !== 'prerequisite') {
            assert.equal(chunk.recipientParity, true, 'Replay lacks final recipient/outfit checks');
            assert.equal(chunk.helperBalance, '0', 'Replay left NFTs in the helper');
        }
    }
    const guards = chain.proposals.length > 1 ? ['out-of-order','mint-drift','duplicate'] : ['mint-drift','duplicate'];
    assert.deepEqual(report.failures.map(f => f.check).sort(), guards.sort());
    assert(report.failures.every(f => f.reverted === true), 'Replay lacks rollback guards');
}

async function finalize({ prepared, source: sourceFile, report: reportFiles, out }) {
    const inputDirectory = path.resolve(prepared), output = path.resolve(out);
    const sourceBytes = fs.readFileSync(path.join(inputDirectory, 'source-proposals.json')), source = JSON.parse(sourceBytes);
    const candidate = readJson(path.join(inputDirectory, 'prepared-proposals.json'));
    const preparation = readJson(path.join(inputDirectory, 'preparation.json'));
    assert.equal(sha256(sourceBytes), preparation.sourceManifestSha256);
    const originalDirectory = path.dirname(path.resolve(sourceFile));
    assert.equal(sha256(fs.readFileSync(path.resolve(sourceFile))), preparation.sourceManifestSha256);
    assert.equal(sha256(fs.readFileSync(path.join(inputDirectory, 'source/export-safe-ui-airdrop.js'))), preparation.exporterSha256);
    assert.equal(sha256(fs.readFileSync(path.join(inputDirectory, 'source-inventory.json'))), preparation.inventorySha256);
    assert.deepEqual(candidate.safeUiExport, preparation);
    assert.deepEqual(candidate.chains.map(c => c.chainId), source.chains.map(c => c.chainId));
    const selections = new Map(), files = new Map(), runnerSources = reviewedRunnerSources();
    const add = (file, value) => { files.set(path.join(output, file), value); return sha256(value); };
    const reports = reportFiles.map(file => {
        const bytes = fs.readFileSync(path.resolve(file)), report = JSON.parse(bytes);
        assert.equal(report.status, 'passed'); assert.equal(report.localForkOnly, true);
        for (const chain of report.chains) { assert(!selections.has(chain.chainId)); selections.set(chain.chainId, chain); }
        add(`reports/${path.basename(file)}`, bytes.toString());
        return { file: path.basename(file), sha256: sha256(bytes) };
    });
    assert.deepEqual([...selections.keys()].sort((a,b) => a-b), [...UI_CHAINS].sort((a,b) => a-b));
    const verification = { status: 'passed', checkedAt: new Date().toISOString(), sourceManifestSha256: sha256(sourceBytes),
        preparationSha256: sha256(fs.readFileSync(path.join(inputDirectory, 'preparation.json'))),
        exporterSha256: sha256(fs.readFileSync(__filename)), reports, chains: [] };
    const codeProof = [];
    add('source-proposals.json', sourceBytes.toString());
    add('source/export-safe-ui-airdrop.js', fs.readFileSync(__filename).toString());
    for (const chain of candidate.chains) {
        const original = source.chains.find(c => c.chainId === chain.chainId);
        if (!UI_CHAINS.includes(chain.chainId)) {
            assert.deepEqual(chain, original, 'Unsupported testnet Site flow changed');
            for (const proposal of chain.proposals) for (const kind of ['builder', 'native']) {
                const bytes = fs.readFileSync(path.join(originalDirectory, proposal.source[`${kind}File`]));
                assert.equal(sha256(bytes), proposal.source[`${kind}Sha256`]);
                add(proposal.source[`${kind}File`], bytes.toString());
            }
            continue;
        }
        assert.deepEqual({ ...chain, proposals: [], multiSendAddress: original.multiSendAddress, multiSendCodeHash: original.multiSendCodeHash },
            { ...original, proposals: [] }, 'Prepared chain changed beyond distribution wrapper/proposals');
        assert.deepEqual(chain.setup, original.setup); assert.deepEqual(chain.predecessors, original.predecessors);
        assert.equal(chain.proposals.length, original.proposals.length);
        const wrapper = UI_WRAPPERS[chain.safeVersion];
        assert.equal(chain.multiSendAddress, wrapper.address); assert.equal(chain.multiSendCodeHash, wrapper.codeHash);
        const inputs = fs.readdirSync(path.join(inputDirectory, String(chain.chainId))).filter(f => f.endsWith('.safe-tx.json')).map(file => {
            const bytes = fs.readFileSync(path.join(inputDirectory, String(chain.chainId), file));
            return { file, bytes, envelope: JSON.parse(bytes) };
        }).sort((a,b) => a.envelope.order - b.envelope.order);
        const replay = selections.get(chain.chainId);
        validateReplay(chain, replay, inputs);
        const runnerSource = verifyImplementationHashes(replay, runnerSources);
        const provider = new ethers.providers.StaticJsonRpcProvider({ url: chain.rpcUrl, timeout: 30000 }, chain.chainId);
        // All prior shard/bundle hashes and newly prepared UI hashes must remain unapproved/unqueued.
        const approvalCandidates = [...original.proposals, ...chain.proposals,
            ...original.proposals.flatMap(p => p.source.originalProposalHashes.map(safeTxHash => ({ safeTxHash })))];
        const approvalProposals = [...new Map(approvalCandidates.map(p => [p.safeTxHash.toLowerCase(), p])).values()];
        const live = await checkUnexecuted({ ...chain, proposals: approvalProposals }, provider);
        const code = await provider.getCode(wrapper.address, live.blockNumber);
        assert.equal(ethers.utils.keccak256(code), wrapper.codeHash);
        codeProof.push({ chainId: chain.chainId, address: wrapper.address, code, codeHash: wrapper.codeHash, blockNumber: live.blockNumber });
        for (const [index, proposal] of chain.proposals.entries()) {
            const old = original.proposals[index], preparedProof = preparation.chains.find(c => c.chainId === chain.chainId).proposals[index];
            const builderBytes = fs.readFileSync(path.join(inputDirectory, proposal.source.builderFile));
            validateBuilder(builderBytes, old, original);
            const expected = rewrap(old, original, wrapper);
            assert.deepEqual(proposal.transaction, expected.transaction, 'Prepared transaction changed beyond batching address');
            for (const key of Object.keys(expected).filter(key => !['source','transaction'].includes(key))) assert.deepEqual(proposal[key], expected[key]);
            const bound = await bindNonce(proposal, proposal.transaction.nonce, provider);
            assert.equal(bound.safeTxHash, proposal.safeTxHash); assert.equal(proposal.safeTxHash, preparedProof.safeTxHash);
            assert.deepEqual(bound.approveHashTransaction, proposal.approveHashTransaction);
            assert.equal(ethers.utils._TypedDataEncoder.hash({ chainId: chain.chainId, verifyingContract: chain.safe }, safeTypes, proposal.transaction), proposal.safeTxHash);
            const chunk = replay.chunks.find(c => c.safeTransactionHash === proposal.safeTxHash);
            assert(chunk && chunk.stage === 'migration');
            const input = inputs.find(i => i.envelope.safeTxHash === proposal.safeTxHash);
            assert(input && sha256(input.bytes) === proposal.source.nativeSha256);
            assert.equal(proposal.source.nativeSha256, preparedProof.nativeSha256);
            const withoutSelfChecksum = structuredClone(proposal);
            delete withoutSelfChecksum.source.nativeSha256;
            assert.deepEqual(input.envelope, withoutSelfChecksum, 'Prepared replay metadata differs from candidate');
            proposal.source = { ...old.source, nativeFile: old.source.nativeFile, builderFile: old.source.builderFile,
                builderSha256: add(old.source.builderFile, builderBytes.toString()) };
            delete proposal.source.nativeSha256;
            proposal.simulation = { blockNumber: replay.blockNumber, blockHash: replay.blockHash, gasLimit: replay.gasBudget,
                executionGasCap: replay.executionGasCap, headroomPercent: replay.headroomPercent, executionProof: replay.executionProof,
                proofKind: 'exact-safe-ui-wrapper-replay', gasBudgetKind: replay.ethereumTransactionCapEnabled ? 'outer-transaction' : 'evm-execution-excluding-nitro-posting',
                gasUsed: chunk.gasUsed, safeTransactionHash: chunk.safeTransactionHash };
            proposal.source.nativeSha256 = add(proposal.source.nativeFile, json(proposal));
        }
        add(`${chain.chainId}/01-setup.safe-tx.json`, json(chain.setup));
        chain.live = { ...chain.live, blockNumber: live.blockNumber, blockHash: live.blockHash, blockTimestamp: live.blockTimestamp };
        verification.chains.push({ chainId: chain.chainId, live, wrapper, runnerSource, unchangedSetupHash: chain.setup.safeTxHash,
            proposalCount: chain.proposals.length, nftCount: chain.proposals.reduce((n,p) => n+p.mintCount,0),
            hashes: chain.proposals.map(p => p.safeTxHash), simulationBlockNumber: replay.blockNumber });
        console.log(`${chain.name}: final replay and live guards passed for ${chain.proposals.length} uploads`);
    }
    candidate.checkedAt = verification.checkedAt;
    candidate.approvalMethod = 'Safe UI queue signatures on Ethereum, Optimism, Base, Arbitrum, Sepolia and Base Sepolia; onchain approveHash on OP Sepolia and Arbitrum Sepolia';
    candidate.safeUiExport = { ...preparation, status: 'passed', finalVerification: verification };
    add('proposals.json', json(candidate)); add('verification.json', json(verification)); add('wrapper-code-proof.json', json(codeProof));
    writeExports(files);
    console.log(`Wrote ${output}; unchanged upload bytes and exact replayed Safe UI hashes. No signatures or submissions.`);
}

async function main() {
    const { values } = parseArgs({ options: { source: { type: 'string' }, inventory: { type: 'string' },
        prerequisites: { type: 'string' }, out: { type: 'string' }, prepared: { type: 'string' }, report: { type: 'string', multiple: true } } });
    if (values.prepared) { assert(values.source && values.report?.length && values.out, 'Finalization requires --prepared, --source, --report and --out'); return finalize(values); }
    assert(values.source && values.inventory && values.prerequisites && values.out,
        'Use --source <bundled proposals.json> --inventory <fresh inventory.json> --prerequisites <original exact replay input directory> --out <fresh directory>');
    await prepare(values);
}
if (require.main === module) main().catch(error => { console.error(error.code && !String(error.code).startsWith('ERR_ASSERTION')
    ? `Safe UI export failed (${error.code}); check source files and read-only RPC connectivity.` : error.message); process.exitCode = 1; });
module.exports = { UI_WRAPPERS, UI_CHAINS, validateBuilder, rewrap, validateInventory, validateReplay, prepare, finalize };
