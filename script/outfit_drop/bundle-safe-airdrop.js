#!/usr/bin/env node

// Repackages reviewed consecutive migrations only after exact local-fork selection succeeds.
// All RPC calls in this exporter are read-only; signatures remain wallet actions on the Site.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { parseArgs } = require('node:util');
const { ethers } = require('ethers');
const { combineMigrationBatches, bindNonce, SAFE_TRANSACTION_FIELDS, writeExports } = require('./export-safe-airdrop');
const { gasBudget, minimumContiguousPartition, isGasExhaustion } = require('./simulate-safe-airdrop');

const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const json = filename => JSON.parse(fs.readFileSync(filename, 'utf8'));
const fields = [...SAFE_TRANSACTION_FIELDS, 'nonce'];
const types = { SafeTx: fields.map((name, index) => ({ name,
    type: ['address', 'uint256', 'bytes', 'uint8', 'uint256', 'uint256', 'uint256', 'address', 'address', 'uint256'][index] })) };
const safeAbi = new ethers.utils.Interface([
    'function nonce() view returns(uint256)', 'function getOwners() view returns(address[])',
    'function getThreshold() view returns(uint256)', 'function approvedHashes(address,bytes32) view returns(uint256)',
]);
const multicallAbi = ['function aggregate3(tuple(address target,bool allowFailure,bytes callData)[] calls) payable returns(tuple(bool success,bytes returnData)[])'];

function loadOriginalParts(chain, audit, sourceIndex) {
    return chain.proposals.map(proposal => {
        const read = (file, expected) => {
            const contents = fs.readFileSync(path.join(audit, file));
            assert.equal(sha256(contents), expected, `Changed audited source ${file}`);
            assert.equal(expected, sourceIndex.files[file], `Source outside original audit ${file}`);
            return JSON.parse(contents);
        };
        const original = read(proposal.source.nativeFile, proposal.source.nativeSha256);
        const batch = read(proposal.source.builderFile, proposal.source.builderSha256);
        for (const [field, value] of Object.entries(original)) {
            if (field !== 'transaction') assert.deepEqual(proposal[field], value, `Original proposal metadata changed: ${field}`);
        }
        for (const field of SAFE_TRANSACTION_FIELDS) assert.equal(String(proposal.transaction[field]).toLowerCase(),
            String(original.transaction[field]).toLowerCase(), `Original proposal field changed: ${field}`);
        assert.equal(ethers.utils._TypedDataEncoder.hash({ chainId: chain.chainId, verifyingContract: chain.safe }, types, proposal.transaction),
            proposal.safeTxHash, 'Original Site proposal hash changed');
        assert.deepEqual(proposal.expectedTokenIds, original.expectedTokenIds);
        assert.equal(proposal.order, original.order);
        return { batch, safeTransaction: original, originalProposal: proposal };
    });
}

function validateSelectionReport(chainId, sourceOrders, selection, parts) {
    const expected = gasBudget(chainId, selection.blockGasLimit);
    assert.equal(selection.gasBudget, expected.budget, 'Selection did not use the reviewed gas budget');
    assert.equal(selection.executionGasCap, expected.executionGasCap, 'Selection cap differs from reviewed chain limit');
    assert.equal(selection.headroomPercent, expected.headroomPercent, 'Selection headroom differs from reviewed policy');
    assert.equal(selection.transactionGasLimit, expected.budget, 'Selection outer gas limit differs from reviewed budget');
    let minimum;
    if (selection.proofKind === 'two-bundle-lower-bound') {
        assert.equal(selection.status, 'passed', 'Two-bundle certificate is incomplete');
        assert(parts?.length === sourceOrders.length, 'Certificate requires exact original source batches');
        const whole = selection.wholeCandidate;
        assert(whole && whole.success === false && whole.receiptStatus === 0, 'Whole-distribution failure lacks a reverted receipt');
        assert(ethers.utils.isHexString(whole.transactionHash, 32) && ethers.utils.isHexString(whole.blockHash, 32)
            && Number.isSafeInteger(whole.blockNumber) && whole.blockNumber > 0, 'Whole-distribution failure lacks a mined transaction/block identity');
        assert.equal(whole.simulationGasLimit, expected.budget, 'Whole-distribution candidate used a different gas budget');
        assert(isGasExhaustion(whole.failures || []), 'Whole-distribution candidate lacks traced gas exhaustion');
        assert(BigInt(whole.gasUsed) > 0n && BigInt(whole.gasUsed) <= BigInt(expected.budget), 'Whole-distribution gas evidence is invalid');
        assert.deepEqual(whole.sourceOrders, sourceOrders, 'Lower-bound candidate does not contain the whole distribution');
        assert.equal(String(whole.nonce), String(selection.migrationStartNonce), 'Whole candidate was not tested immediately after setup');
        assert.equal(String(whole.nonce), String(selection.bundles?.[0]?.nonce), 'Whole candidate and final sequence start at different nonces');
        const canonical = combineMigrationBatches(parts).safeTransaction;
        canonical.transaction.nonce = String(whole.nonce);
        assert.equal(whole.safeTransaction?.safe, canonical.safe, 'Whole candidate has a different Safe');
        assert.equal(String(whole.safeTransaction?.chainId), String(chainId), 'Whole candidate has a different chain');
        assert.deepEqual(whole.safeTransaction.expectedTokenIds, canonical.expectedTokenIds, 'Whole candidate changes NFT coverage');
        for (const field of fields) assert.equal(String(whole.safeTransaction.transaction[field]).toLowerCase(),
            String(canonical.transaction[field]).toLowerCase(), `Whole candidate differs from original calls: ${field}`);
        const hash = ethers.utils._TypedDataEncoder.hash({ chainId, verifyingContract: canonical.safe }, types, canonical.transaction);
        assert.equal(whole.safeTransactionHash, hash, 'Whole candidate hash differs from the original full distribution');
        assert.equal(whole.safeTransaction.safeTxHash, hash, 'Whole candidate envelope hash is not bound');
        const ranges = selection.minimality?.ranges;
        assert(Array.isArray(ranges) && ranges.length === 2 && ranges[0].start === 0 && ranges[1].end === sourceOrders.length
            && Number.isInteger(ranges[0].end) && ranges[0].end > 0 && ranges[0].end < sourceOrders.length
            && ranges[1].start === ranges[0].end, 'Certificate must cover exactly two consecutive nonempty ranges');
        minimum = { minimumTransactions: 2, ranges };
    } else {
        assert(selection.proofKind === undefined || selection.proofKind === 'complete-interval-graph', 'Unknown bundle proof kind');
        for (const edge of selection.probeEdges || []) {
            assert.equal(edge.simulationGasLimit, expected.budget, 'Candidate probe used a different gas budget');
            if (!edge.success) assert(isGasExhaustion(edge.failures || []), 'Rejected candidate lacks traced gas exhaustion');
        }
        minimum = minimumContiguousPartition(sourceOrders.length, selection.probeEdges || []);
    }
    assert.equal(selection.bundles.length, minimum.minimumTransactions, 'Selected bundle count is not minimal for the probe graph');
    assert.equal(selection.minimality?.minimumTransactions, minimum.minimumTransactions, 'Recorded minimum differs from recomputed proof');
    assert.deepEqual(selection.minimality.ranges, minimum.ranges, 'Recorded partition differs from recomputed proof');
    assert.deepEqual(selection.bundles.map(bundle => bundle.sourceOrders),
        minimum.ranges.map(({ start, end }) => sourceOrders.slice(start, end)), 'Selected source ranges differ from minimum proof');
    for (const bundle of selection.bundles) {
        assert.equal(bundle.simulationGasLimit, expected.budget, 'Final bundle was not tested at the reviewed gas budget');
        assert(BigInt(bundle.gasUsed) < BigInt(expected.budget), 'Final bundle lacks successful bounded gas proof');
    }
    return minimum;
}

function reviewedRunnerSources(archives = []) {
    return new Map([path.join(__dirname, 'simulate-safe-airdrop.js'), ...archives.map(file => path.resolve(file))].map(file => {
        const contents = fs.readFileSync(file);
        const keccak256 = ethers.utils.keccak256(contents);
        return [keccak256, { file: path.basename(file), sha256: sha256(contents), keccak256 }];
    }));
}

function verifyImplementationHashes(selection, runnerSources) {
    const runnerSource = runnerSources.get(selection.implementationHashes?.['simulate-safe-airdrop.js']);
    assert(runnerSource, 'Selection runner is neither current nor an explicitly supplied frozen source');
    for (const file of ['export-safe-airdrop.js', 'generate-v6-airdrop.js']) {
        assert.equal(selection.implementationHashes?.[file], ethers.utils.keccak256(fs.readFileSync(path.join(__dirname, file))),
            `Selection code changed after simulation: ${file}`);
    }
    return runnerSource;
}

async function checkUnexecuted(chain, provider) {
    assert.equal(Number(await provider.send('eth_chainId', [])), Number(chain.chainId), 'RPC chain mismatch');
    const block = await provider.getBlock(await provider.getBlockNumber() - 5);
    const at = { blockTag: block.number };
    const safe = new ethers.Contract(chain.safe, safeAbi, provider);
    const [nonce, owners, threshold, implementation, executor, multicallCode, safeCode, slot, singletonCode, multiSendCode] = await Promise.all([
        safe.nonce(at), safe.getOwners(at), safe.getThreshold(at),
        provider.getCode(chain.setup.implementation, block.number), provider.getCode(chain.setup.helper, block.number),
        provider.getCode(chain.multicallAddress, block.number),
        provider.getCode(chain.safe, block.number), provider.getStorageAt(chain.safe, 0, block.number),
        provider.getCode(chain.singleton, block.number), provider.getCode(chain.multiSendAddress, block.number),
    ]);
    assert.equal(nonce.toString(), chain.live.nonce, 'Safe nonce changed; re-audit before replacing distribution proposals');
    assert.equal(implementation, '0x', 'Setup already deployed; re-audit before replacing proposals');
    assert.equal(executor, '0x', 'Setup already deployed; re-audit before replacing proposals');
    assert.equal(threshold.toNumber(), chain.live.threshold, 'Safe threshold changed');
    assert.deepEqual([...owners].sort(), [...chain.live.owners].sort(), 'Safe owners changed');
    assert.equal(ethers.utils.keccak256(multicallCode), chain.multicallCodeHash);
    assert.equal(`0x${slot.slice(-40)}`.toLowerCase(), chain.singleton.toLowerCase(), 'Safe singleton changed');
    assert.equal(ethers.utils.keccak256(safeCode), chain.safeCodeHash);
    assert.equal(ethers.utils.keccak256(singletonCode), chain.singletonCodeHash);
    assert.equal(ethers.utils.keccak256(multiSendCode), chain.multiSendCodeHash);
    const multicall = new ethers.Contract(chain.multicallAddress, multicallAbi, provider);
    const calls = chain.proposals.flatMap(proposal => owners.map(owner => ({ target: chain.safe, allowFailure: false,
        callData: safeAbi.encodeFunctionData('approvedHashes', [owner, proposal.safeTxHash]) })));
    const results = await multicall.callStatic.aggregate3(calls, at);
    assert.equal(results.length, calls.length);
    for (const result of results) assert(result.success && safeAbi.decodeFunctionResult('approvedHashes', result.returnData)[0].isZero(),
        'An original distribution proposal has been approved; reconcile it before replacing proposals');
    if (chain.safePrefix) {
        let next = `https://api.safe.global/tx-service/${chain.safePrefix}/api/v1/safes/${chain.safe}/multisig-transactions/?executed=false&limit=100&ordering=nonce`;
        const transactions = [];
        for (let pages = 0; next; pages++) {
            assert(pages < 10 && new URL(next).hostname === 'api.safe.global', 'Unexpected Safe queue pagination');
            const response = await fetch(next, { signal: AbortSignal.timeout(30000) });
            assert.equal(response.status, 200, 'Cannot verify existing Safe queue');
            const page = await response.json();
            transactions.push(...page.results);
            next = page.next;
        }
        assert(transactions.some(tx => tx.safeTxHash === chain.setup.safeTxHash), 'Reviewed setup missing from queue');
        assert(!transactions.some(tx => BigInt(tx.nonce) > BigInt(chain.setup.transaction.nonce)),
            'A new transaction occupies a distribution nonce; reconcile the queue before bundling');
    }
    return { blockNumber: block.number, blockHash: block.hash, blockTimestamp: block.timestamp,
        nonce: nonce.toString(), originalApprovals: 0 };
}

async function main() {
    const { values } = parseArgs({ options: {
        source: { type: 'string' }, audit: { type: 'string' }, report: { type: 'string', multiple: true }, out: { type: 'string' },
        'runner-source': { type: 'string', multiple: true },
    } });
    assert(values.source && values.audit && values.report?.length && values.out,
        'Use --source <original Site manifest> --audit <original audit directory> --report <passed fork report> (repeatable) --out <new directory>');
    const sourceBytes = fs.readFileSync(path.resolve(values.source));
    const source = JSON.parse(sourceBytes);
    const audit = path.resolve(values.audit);
    const indexBytes = fs.readFileSync(path.join(audit, 'sha256-index.json'));
    assert.equal(sha256(indexBytes), source.sourceAuditIndexSha256, 'Original audit index changed');
    const sourceIndex = JSON.parse(indexBytes);
    const runnerSources = reviewedRunnerSources(values['runner-source']);
    const selections = new Map();
    const reports = values.report.map(filename => {
        const contents = fs.readFileSync(path.resolve(filename)), report = JSON.parse(contents);
        assert.equal(report.status, 'passed', 'Bundle selection report must have passed');
        assert.equal(report.localForkOnly, true, 'Report must prove local-fork execution');
        for (const chain of report.chains) {
            assert(!selections.has(Number(chain.chainId)), 'Duplicate chain selection report');
            assert(chain.bundles?.length, 'Report does not include native bundle selection');
            selections.set(Number(chain.chainId), chain);
        }
        return { file: path.basename(filename), sha256: sha256(contents) };
    });
    assert.equal(selections.size, source.chains.length, 'Every chain needs a bundle report');
    const output = path.resolve(values.out), files = new Map();
    files.set(path.join(output, 'source-proposals.json'), sourceBytes.toString('utf8'));
    const add = (filename, value) => {
        const contents = `${JSON.stringify(value, null, 2)}\n`;
        files.set(path.join(output, filename), contents);
        return sha256(contents);
    };
    const evidence = { sourceProposalSha256: sha256(sourceBytes), reports, runnerSources: [...runnerSources.values()], chains: [] };
    const bundled = structuredClone(source);
    bundled.checkedAt = new Date().toISOString();
    bundled.bundling = { sourceProposalSha256: sha256(sourceBytes), originalProposalCount: source.chains.reduce((n, c) => n + c.proposals.length, 0),
        policy: 'Consecutive original migrations; exact fork-tested native Safe MultiSend bundles', reports,
        runnerSources: [...runnerSources.values()] };
    for (const chain of bundled.chains) {
        const parts = loadOriginalParts(chain, audit, sourceIndex);
        const selection = selections.get(Number(chain.chainId));
        validateSelectionReport(chain.chainId, parts.map(part => part.safeTransaction.order), selection, parts);
        const runnerSource = verifyImplementationHashes(selection, runnerSources);
        const gasEvidence = { blockNumber: selection.blockNumber, blockHash: selection.blockHash,
            gasLimit: selection.gasBudget, executionGasCap: selection.executionGasCap,
            headroomPercent: selection.headroomPercent, executionProof: selection.executionProof,
            proofKind: selection.proofKind || 'complete-interval-graph', minimalityScope: selection.minimality.scope,
            gasBudgetKind: selection.ethereumTransactionCapEnabled ? 'outer-transaction' : 'evm-execution-excluding-nitro-posting' };
        assert.deepEqual(selection.bundles.flatMap(bundle => bundle.sourceOrders), parts.map(part => part.safeTransaction.order),
            'Selected bundles must cover every original source batch exactly once and in order');
        const provider = new ethers.providers.StaticJsonRpcProvider({ url: chain.rpcUrl, timeout: 30000 }, chain.chainId);
        try {
            const live = await checkUnexecuted(chain, provider);
            const proposals = [];
            for (const [index, chosen] of selection.bundles.entries()) {
                const selected = chosen.sourceOrders.map(order => parts.find(part => part.safeTransaction.order === order));
                assert(selected.every(Boolean), 'Unknown original source order');
                const result = combineMigrationBatches(selected, { order: index + 2, name: `Banny V4 airdrop: ${chain.name} distribution ${index + 1}/${selection.bundles.length}` });
                const nonce = BigInt(chain.setup.transaction.nonce) + BigInt(index + 1);
                assert.equal(String(chosen.nonce), nonce.toString(), 'Fork bundle nonce differs from reviewed setup sequence');
                const bound = await bindNonce(result.safeTransaction, nonce.toString(), provider);
                assert.equal(bound.safeTxHash, chosen.safeTransactionHash, 'Export differs from exact fork-executed Safe transaction');
                assert.equal(ethers.utils._TypedDataEncoder.hash({ chainId: chain.chainId, verifyingContract: chain.safe }, types, bound.transaction), bound.safeTxHash);
                assert.equal(chosen.tokenCount, bound.expectedTokenIds.length, 'Fork token count differs from bundled allocation');
                assert.equal(chosen.recipientParity, true, 'Fork report lacks complete recipient verification');
                assert.equal(chosen.helperBalance, '0', 'Fork helper retained NFTs');
                assert(Number.isSafeInteger(Number(chosen.simulationGasLimit)) && BigInt(chosen.gasUsed) < BigInt(chosen.simulationGasLimit),
                    'Bundle lacks successful bounded outer-gas proof');
                const stem = `${chain.chainId}/${String(index + 2).padStart(2, '0')}-distribution-${index + 1}`;
                const builderFile = `${stem}.json`, nativeFile = `${stem}.safe-tx.json`;
                const builderSha256 = add(builderFile, result.batch);
                const proposal = { ...bound, index: index + 1, mintCount: bound.expectedTokenIds.length,
                    name: `Distribution ${index + 1}/${selection.bundles.length}`,
                    source: { nativeFile, builderFile, builderSha256, calldataKeccak256: ethers.utils.keccak256(bound.transaction.data),
                        originalOrders: chosen.sourceOrders, originalProposalHashes: selected.map(part => part.originalProposal.safeTxHash) },
                    simulation: { ...gasEvidence, gasUsed: String(chosen.gasUsed), safeTransactionHash: chosen.safeTransactionHash } };
                // The file omits its own checksum to avoid a self-referential manifest.
                const nativeSha256 = add(nativeFile, proposal);
                proposals.push({ ...proposal, source: { ...proposal.source, nativeSha256 } });
            }
            assert.deepEqual(proposals.flatMap(proposal => proposal.expectedTokenIds), chain.proposals.flatMap(proposal => proposal.expectedTokenIds));
            const setupFile = `${chain.chainId}/01-setup.safe-tx.json`;
            add(setupFile, chain.setup);
            evidence.chains.push({ chainId: chain.chainId, live, originalCount: chain.proposals.length, bundleCount: proposals.length,
                simulation: gasEvidence, proofKind: selection.proofKind || 'complete-interval-graph', runnerSource,
                originalOrders: parts.map(part => part.safeTransaction.order), unchangedSetupHash: chain.setup.safeTxHash,
                nftCount: proposals.reduce((n, proposal) => n + proposal.mintCount, 0), bundleHashes: proposals.map(proposal => proposal.safeTxHash) });
            chain.proposals = proposals;
            chain.live = { ...chain.live, blockNumber: live.blockNumber, blockHash: live.blockHash, blockTimestamp: live.blockTimestamp };
            console.log(`${chain.name}: ${parts.length} original distributions -> ${proposals.length} verified native Safe bundles`);
        } finally { provider.removeAllListeners(); }
    }
    bundled.bundling.proposalCount = bundled.chains.reduce((n, chain) => n + chain.proposals.length, 0);
    add('proposals.json', bundled);
    add('verification.json', evidence);
    writeExports(files);
    console.log(`Wrote ${output}. No signatures, queue submissions or onchain transactions sent.`);
}

if (require.main === module) main().catch(error => {
    console.error(error.code && !String(error.code).startsWith('ERR_ASSERTION')
        ? `Bundle export failed (${error.code}); check read-only RPC connectivity and source files.` : error.message);
    process.exitCode = 1;
});

module.exports = { loadOriginalParts, validateSelectionReport, reviewedRunnerSources, verifyImplementationHashes, checkUnexecuted };
