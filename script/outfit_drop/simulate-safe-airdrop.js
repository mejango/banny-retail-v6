#!/usr/bin/env node

// Executes only on a newly spawned loopback Anvil fork. Upstream RPCs are read-only.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { ethers } = require('ethers');
const { buildContractsByChain, itemTokenId, loadRawItems } = require('./generate-v6-airdrop');
const { NETWORKS, partitionPlan, prepareApprovedExecution, combineMigrationBatches, SAFE_TRANSACTION_FIELDS } = require('./export-safe-airdrop');

const SAFE_ABI = [
    'function VERSION() view returns (string)',
    'function getOwners() view returns (address[])',
    'function getThreshold() view returns (uint256)',
    'function nonce() view returns (uint256)',
    'function approveHash(bytes32 hashToApprove)',
    'function getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256) view returns (bytes32)',
    'function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns (bool)',
    'event ExecutionSuccess(bytes32 txHash,uint256 payment)',
];
const HOOK_ABI = [
    'function balanceOf(address) view returns (uint256)',
    'function ownerOf(uint256) view returns (address)',
    'function mintFor(uint16[],address) returns (uint256[])',
];
const RESOLVER_ABI = ['function assetIdsOf(address,uint256) view returns (uint256,uint256[])'];
const SAFE_INTERFACE = new ethers.utils.Interface(SAFE_ABI);
const SUCCESS_INTERFACES = [SAFE_INTERFACE,
    new ethers.utils.Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)'])];
const HOOK_INTERFACE = new ethers.utils.Interface(HOOK_ABI);
// A conservative transaction ceiling, including on chains with larger block limits.
const GAS_CEILING = 16_777_216;
const pause = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

function readTransactions(directory, { loadBuilders = false } = {}) {
    const files = fs.readdirSync(directory, { recursive: true }).filter(file => file.endsWith('.safe-tx.json')).sort();
    assert(files.length > 0, 'No .safe-tx.json files found; export the airdrop first.');
    return files.map(file => {
        const contents = fs.readFileSync(path.join(directory, file));
        const envelope = { ...JSON.parse(contents.toString('utf8')), file, fileKeccak256: ethers.utils.keccak256(contents) };
        if (loadBuilders && envelope.stage === 'migration') {
            const builderFile = file.replace(/\.safe-tx\.json$/, '.json');
            const builderContents = fs.readFileSync(path.join(directory, builderFile));
            envelope.batchBuilder = JSON.parse(builderContents.toString('utf8'));
            envelope.builderFile = builderFile;
            envelope.builderFileKeccak256 = ethers.utils.keccak256(builderContents);
        }
        return envelope;
    });
}

function migrationPlan(envelope, plans) {
    if (envelope.components !== undefined) {
        assert.equal(envelope.stage, 'migration');
        assert.equal(envelope.contractName, 'BannyAirdropBundle');
        assert.equal(envelope.slice, 0);
        assert(Array.isArray(envelope.components) && envelope.components.length, 'Bundle needs original components.');
        const components = envelope.components.map((component, index) => {
            assert(!component.components, 'Nested migration bundles are not original slices.');
            for (const field of ['chainId', 'sourceChainId', 'safe', 'hook', 'resolver', 'helper', 'implementation']) {
                assert.equal(String(component[field]).toLowerCase(), String(envelope[field]).toLowerCase(), `Bundle component ${field} differs.`);
            }
            assert(Number.isInteger(component.order) && component.order > 0, 'Bundle component order is invalid.');
            assert.equal(component.order, envelope.components[0].order + index, 'Bundle components must be consecutive.');
            return { envelope: component, plan: migrationPlan(component, plans) };
        });
        const expectedTokenIds = components.flatMap(component => component.plan.assignments.expectedTokenIds);
        assert.equal(new Set(expectedTokenIds).size, expectedTokenIds.length, 'Bundle repeats token IDs.');
        assert.deepEqual(envelope.expectedTokenIds, expectedTokenIds, 'Bundle IDs differ from original components.');
        return { contractName: envelope.contractName, components, assignments: { expectedTokenIds,
            tierIds: components.flatMap(component => component.plan.assignments.tierIds) } };
    }
    const plan = plans.get(envelope.contractName);
    assert(plan, `Unknown migration contract ${envelope.contractName}`);
    assert.equal(Number(envelope.sourceChainId), plan.chain.id);
    assert.equal(envelope.stage, 'migration');
    const ids = envelope.expectedTokenIds;
    assert(Array.isArray(ids) && ids.length > 0, 'Migration must include its expected token IDs.');
    const selected = new Set(ids);
    assert.equal(selected.size, ids.length, 'Migration repeats a token ID.');
    const indices = plan.assignments.expectedTokenIds.flatMap((id, index) => selected.has(id) ? [index] : []);
    assert.deepEqual(indices.map(index => plan.assignments.expectedTokenIds[index]), ids, 'Migration IDs differ from original mint order.');
    const mapping = plan.assignments.v4ToV6TokenIds;
    const bannies = plan.bannies.filter(banny => selected.has(mapping.get(banny.tokenId)));
    for (const banny of bannies) {
        for (const asset of [...banny.outfitIds, ...(banny.backgroundId ? [banny.backgroundId] : [])]) {
            assert(selected.has(mapping.get(asset)), 'A dressed body and all its assets must remain in one atomic migration.');
        }
    }
    const canonical = partitionPlan(plan).find(slice => slice.slice === envelope.slice);
    assert(canonical, 'Unknown migration slice.');
    assert.deepEqual(ids, canonical.assignments.expectedTokenIds, 'Migration differs from the canonical exported slice.');
    return { ...plan, bannies,
        transferItems: plan.transferItems.filter(({ item }) => selected.has(mapping.get(itemTokenId(item)))),
        assignments: { ...plan.assignments, expectedTokenIds: ids,
            tierIds: indices.map(index => plan.assignments.tierIds[index]) },
    };
}

function validateCoverage(envelopes, plans) {
    const migrations = envelopes.filter(envelope => envelope.stage === 'migration');
    assert(migrations.length > 0, 'No migration stages found.');
    assert(envelopes.every(envelope => ['prerequisite', 'setup', 'migration'].includes(envelope.stage)), 'Re-export obsolete batches before simulating.');
    let phase = -1;
    for (const envelope of envelopes) {
        const next = ['prerequisite', 'setup', 'migration'].indexOf(envelope.stage);
        assert(next >= phase, 'Prerequisites and setup must precede migration.');
        phase = next;
    }
    const sourceChain = Number(migrations[0].sourceChainId);
    const expected = [...plans.values()].filter(plan => plan.chain.id === sourceChain).flatMap(plan => plan.assignments.expectedTokenIds);
    const actual = migrations.flatMap(envelope => migrationPlan(envelope, plans).assignments.expectedTokenIds);
    assert.equal(new Set(actual).size, actual.length, 'Migration stages repeat token IDs.');
    assert.deepEqual([...actual].sort((a, b) => a - b), [...expected].sort((a, b) => a - b), 'Migration stages omit or add tokens.');
    const previousByTier = new Map();
    for (const id of actual) {
        const tier = Math.floor(id / 1_000_000_000);
        assert.equal(id % 1_000_000_000, (previousByTier.get(tier) || 0) + 1, 'Migration order changes original per-tier token IDs.');
        previousByTier.set(tier, id % 1_000_000_000);
    }
    return migrations;
}

async function unusedPort() {
    const server = net.createServer();
    await new Promise((resolve, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolve));
    const { port } = server.address();
    await new Promise(resolve => server.close(resolve));
    return port;
}

async function startFork(rpcUrl, chainId, blockNumber, { budgeted = false } = {}) {
    const port = await unusedPort();
    const child = spawn('anvil', [
        '--quiet', '--host', '127.0.0.1', '--port', String(port), '--accounts', '0',
        '--fork-url', rpcUrl, '--fork-block-number', String(blockNumber), '--chain-id', String(chainId),
        ...(budgeted ? ['--hardfork', 'osaka', ...(!isArbitrum(chainId) ? ['--enable-tx-gas-limit'] : [])] : []),
    ], { stdio: 'ignore' });
    const provider = new ethers.providers.StaticJsonRpcProvider(`http://127.0.0.1:${port}`, chainId);
    provider.pollingInterval = 100;
    let startError;
    child.on('error', error => { startError = error; });
    try {
        for (let attempt = 0; attempt < 300; attempt++) {
            if (startError) throw new Error('Could not start Anvil; install Foundry and make anvil available on PATH.');
            assert(child.exitCode === null, 'Anvil exited while opening the fork. Check the RPC and pinned block.');
            try {
                assert.equal(Number(await provider.send('eth_chainId', [])), chainId);
                return { child, provider };
            } catch (_) {
                await pause(100);
            }
        }
        throw new Error('Anvil did not become ready within 30 seconds.');
    } catch (error) {
        child.kill();
        throw error;
    }
}

async function receiptFor(provider, transaction) {
    const hash = await provider.send('eth_sendTransaction', [transaction]);
    for (let attempt = 0; attempt < 600; attempt++) {
        const receipt = await provider.getTransactionReceipt(hash);
        if (receipt) return receipt;
        await pause(100);
    }
    throw new Error(`Local fork transaction ${hash} did not mine within 60 seconds.`);
}

async function impersonate(provider, owner) {
    await provider.send('anvil_impersonateAccount', [owner]);
    await provider.send('anvil_setBalance', [owner, ethers.utils.hexValue(ethers.utils.parseEther('100'))]);
}

async function executeSafe(provider, envelope, owners, gasLimit) {
    const safe = new ethers.Contract(envelope.safe, SAFE_ABI, provider);
    const nonce = await safe.nonce();
    if (envelope.transaction.nonce !== null) assert.equal(nonce.toString(), String(envelope.transaction.nonce));
    const fields = SAFE_TRANSACTION_FIELDS.map(field => envelope.transaction[field]);
    const hash = await safe.getTransactionHash(...fields, nonce);
    assertBoundHash(envelope, hash);
    for (const owner of owners) {
        const receipt = await receiptFor(provider, {
            from: owner, to: envelope.safe,
            data: SAFE_INTERFACE.encodeFunctionData('approveHash', [hash]), gas: '0x186a0',
        });
        assert.equal(receipt.status, 1, 'Local Safe hash approval failed.');
    }
    const prepared = await prepareApprovedExecution({
        ...envelope, transaction: { ...envelope.transaction, nonce: nonce.toString() }, safeTxHash: hash,
    }, provider);
    const receipt = await receiptFor(provider, {
        from: owners[0], ...prepared.transaction, value: ethers.utils.hexValue(ethers.BigNumber.from(prepared.transaction.value)),
        gas: ethers.utils.hexValue(gasLimit),
    });
    const success = hasExecutionSuccess(receipt, envelope.safe, hash);
    return { receipt, success, nonce: nonce.toString(), hash,
        safeTransaction: { ...envelope, transaction: { ...envelope.transaction, nonce: nonce.toString() }, safeTxHash: hash,
            approveHashTransaction: { to: envelope.safe, value: '0', data: SAFE_INTERFACE.encodeFunctionData('approveHash', [hash]) } } };
}

function assertBoundHash(envelope, hash) {
    if (envelope.safeTxHash !== undefined) {
        assert(envelope.transaction.nonce !== null && envelope.transaction.nonce !== undefined, 'A supplied Safe hash must have a bound nonce.');
        assert.equal(envelope.safeTxHash.toLowerCase(), hash.toLowerCase(), 'Supplied Safe transaction hash differs from exact execution.');
    }
}

function unbound(envelope) {
    const { safeTxHash, approveHashTransaction, ...rest } = envelope;
    return { ...rest, transaction: { ...rest.transaction, nonce: null } };
}

function hasExecutionSuccess(receipt, safe, hash) {
    return receipt.logs.some(log => log.address.toLowerCase() === safe.toLowerCase()
        && SUCCESS_INTERFACES.some(iface => {
            try {
                const parsed = iface.parseLog(log);
                return parsed.name === 'ExecutionSuccess' && parsed.args.txHash === hash;
            } catch (_) { return false; }
        }));
}

async function failureTrace(provider, hash) {
    const trace = await provider.send('debug_traceTransaction', [hash, { tracer: 'callTracer' }]);
    const failures = [];
    function visit(call) {
        if (call.error) {
            let reason = call.output || '0x';
            if (reason.startsWith('0x08c379a0')) {
                try { [reason] = ethers.utils.defaultAbiCoder.decode(['string'], `0x${reason.slice(10)}`); } catch (_) { /* retain revert bytes */ }
            }
            failures.push({ to: call.to, error: call.error, reason });
        }
        for (const inner of call.calls || []) visit(inner);
    }
    visit(trace);
    return failures;
}

async function ownersOf(hook, tokenIds) {
    const owners = [];
    for (const id of tokenIds) {
        try { owners.push((await hook.ownerOf(id)).toLowerCase()); }
        catch (error) {
            if (error.code !== 'CALL_EXCEPTION') throw error;
            owners.push(null);
        }
    }
    return owners;
}

async function expectAtomicFailure(provider, envelope, plan, owners, gasLimit, label) {
    const safe = new ethers.Contract(envelope.safe, SAFE_ABI, provider);
    const hook = new ethers.Contract(envelope.hook, HOOK_ABI, provider);
    const before = {
        nonce: (await safe.nonce()).toString(),
        helperCode: await provider.getCode(envelope.helper),
        balance: (await hook.balanceOf(envelope.helper)).toString(),
        owners: await ownersOf(hook, plan.assignments.expectedTokenIds),
    };
    // Adversarial ordering uses the fork's current nonce; a bound proposal's old nonce is not the failure under test.
    const execution = await executeSafe(provider, unbound(envelope), owners, gasLimit);
    assert.equal(execution.receipt.status, 0, `${label}: transaction should revert.`);
    assert.equal(execution.success, false, `${label}: unexpected ExecutionSuccess.`);
    assert.equal((await safe.nonce()).toString(), before.nonce, `${label}: Safe nonce changed.`);
    assert.equal(await provider.getCode(envelope.helper), before.helperCode, `${label}: deployment was not atomic.`);
    assert.equal((await hook.balanceOf(envelope.helper)).toString(), before.balance, `${label}: helper balance changed.`);
    assert.deepEqual(await ownersOf(hook, plan.assignments.expectedTokenIds), before.owners, `${label}: token owners changed.`);
    console.log(`  ${label}: atomic revert verified (${execution.receipt.gasUsed} gas)`);
    return { check: label, reverted: true, gasUsed: execution.receipt.gasUsed.toString() };
}

async function verifyRecipients(provider, envelope, plan) {
    if (plan.components) {
        for (const component of plan.components) await verifyRecipients(provider, component.envelope, component.plan);
        return;
    }
    const hook = new ethers.Contract(envelope.hook, HOOK_ABI, provider);
    const resolver = new ethers.Contract(envelope.resolver, RESOLVER_ABI, provider);
    const mapping = plan.assignments.v4ToV6TokenIds;
    const transfers = new Map(plan.transferItems.map(({ item, owner }) => [mapping.get(itemTokenId(item)), owner]));
    const actual = await ownersOf(hook, plan.assignments.expectedTokenIds);
    const expected = plan.assignments.expectedTokenIds.map(id => (transfers.get(id) || envelope.resolver).toLowerCase());
    assert.deepEqual(actual, expected, `${plan.contractName}: final token ownership differs from generator.`);
    assert.equal((await hook.balanceOf(envelope.helper)).toString(), '0', 'Helper retained tokens.');
    for (const banny of plan.bannies) {
        const assets = await resolver.assetIdsOf(envelope.hook, mapping.get(banny.tokenId));
        assert.equal(assets[0].toString(), String(banny.backgroundId ? mapping.get(banny.backgroundId) : 0));
        assert.deepEqual(assets[1].map(id => id.toString()), banny.outfitIds.map(id => String(mapping.get(id))));
    }
}

async function rehearseStages(provider, envelopes, plans, owners, gasLimit, report, { includeEnvelopes = false } = {}) {
    const first = envelopes[0];
    const migrations = envelopes.filter(envelope => envelope.stage === 'migration');
    const firstMigration = migrations[0];
    const safe = new ethers.Contract(first.safe, SAFE_ABI, provider);
    for (const envelope of envelopes) {
        assert.equal(envelope.safe, first.safe);
        if (envelope === firstMigration) {
            // All setup stages must already have run. Choose a later slice that actually needs an earlier mint.
            const dependent = migrations.slice(1).find(candidate => {
                const minima = new Map();
                for (const id of candidate.expectedTokenIds) {
                    const tier = Math.floor(id / 1_000_000_000);
                    minima.set(tier, Math.min(minima.get(tier) || Infinity, id % 1_000_000_000));
                }
                return [...minima.values()].some(unit => unit > 1);
            });
            if (dependent) {
                const snapshot = await provider.send('evm_snapshot', []);
                report.failures.push(await expectAtomicFailure(provider, dependent, migrationPlan(dependent, plans), owners, gasLimit, 'out-of-order'));
                assert(await provider.send('evm_revert', [snapshot]));
            }
            const snapshot = await provider.send('evm_snapshot', []);
            await impersonate(provider, first.safe);
            const tier = migrationPlan(firstMigration, plans).assignments.tierIds[0];
            const drift = await receiptFor(provider, {
                from: first.safe, to: firstMigration.hook,
                data: HOOK_INTERFACE.encodeFunctionData('mintFor', [[tier], owners[0]]), gas: '0x1e8480',
            });
            assert.equal(drift.status, 1, 'Could not construct the local mint-drift test.');
            report.failures.push(await expectAtomicFailure(provider, firstMigration, migrationPlan(firstMigration, plans), owners, gasLimit, 'mint-drift'));
            assert(await provider.send('evm_revert', [snapshot]));
        }
        const execution = await executeSafe(provider, envelope, owners, gasLimit);
        if (execution.receipt.status !== 1) {
            throw new Error(`${envelope.contractName}: Safe transaction reverted using ${execution.receipt.gasUsed} gas: ${JSON.stringify(await failureTrace(provider, execution.receipt.transactionHash))}`);
        }
        assert(execution.success, `${envelope.contractName}: no matching Safe ExecutionSuccess event.`);
        const plan = envelope.stage === 'migration' ? migrationPlan(envelope, plans) : null;
        if (plan) await verifyRecipients(provider, envelope, plan);
        else if (envelope.stage === 'setup') {
            assert.notEqual(await provider.getCode(envelope.helper), '0x', 'Setup did not deploy the helper.');
            assert(envelope.implementation, 'Setup must identify its migration implementation.');
            assert.notEqual(await provider.getCode(envelope.implementation), '0x', 'Setup did not deploy the migration implementation.');
            const executor = new ethers.Contract(envelope.helper, [
                'function SAFE() view returns(address)', 'function IMPLEMENTATION() view returns(address)',
            ], provider);
            assert.equal((await executor.SAFE()).toLowerCase(), envelope.safe.toLowerCase(), 'Executor authority differs from the Safe.');
            assert.equal((await executor.IMPLEMENTATION()).toLowerCase(), envelope.implementation.toLowerCase(), 'Executor implementation differs from the reviewed helper.');
            assert.equal((await new ethers.Contract(envelope.hook, HOOK_ABI, provider).balanceOf(envelope.helper)).toString(), '0');
        }
        report.chunks.push({ file: envelope.file, fileKeccak256: envelope.fileKeccak256,
            contractName: envelope.contractName, stage: envelope.stage, slice: envelope.slice,
            nonce: execution.nonce, safeTransactionHash: execution.hash,
            gasUsed: execution.receipt.gasUsed.toString(), tokenCount: plan ? plan.assignments.expectedTokenIds.length : 0,
            recipientParity: envelope.stage !== 'prerequisite', helperBalance: envelope.stage === 'prerequisite' ? null : '0',
            ...(includeEnvelopes ? { safeTransaction: execution.safeTransaction } : {}) });
        console.log(`  ${envelope.contractName} ${envelope.stage}${envelope.slice ? ` ${envelope.slice}` : ''}: ${execution.receipt.gasUsed} gas, ${plan ? plan.assignments.expectedTokenIds.length : 0} tokens verified`);
        if (envelope === firstMigration) {
            report.failures.push(await expectAtomicFailure(provider, envelope, plan, owners, gasLimit, 'duplicate'));
        }
    }
    // Later slices must not disturb the recipient/custody and dressing results of earlier slices.
    for (const envelope of migrations) await verifyRecipients(provider, envelope, migrationPlan(envelope, plans));
    report.endNonce = (await safe.nonce()).toString();
    assert.equal(BigInt(report.endNonce) - BigInt(report.startNonce), BigInt(envelopes.length), 'Safe nonce advanced outside the reviewed stages.');
}

function isArbitrum(chainId) {
    return [42161, 421614].includes(Number(chainId));
}

function gasBudget(chainId, blockGasLimit) {
    const executionGasCap = isArbitrum(chainId) ? 32_000_000 : GAS_CEILING;
    const budget = Math.floor(executionGasCap * 95 / 100);
    if (blockGasLimit !== undefined) assert(BigInt(blockGasLimit.toString()) >= BigInt(budget), 'Fork block gas limit is below the required selection budget.');
    return { executionGasCap, budget, headroomPercent: 5 };
}

function simulationPolicy(envelopes, chainId, blockGasLimit, { selection = false, twoBundleSplit } = {}) {
    selection ||= twoBundleSplit !== undefined;
    const budget = selection || envelopes.some(envelope => envelope.components !== undefined)
        ? gasBudget(chainId, blockGasLimit) : null;
    return { selection, budget, gasLimit: budget ? budget.budget : Math.min(ethers.BigNumber.from(blockGasLimit).toNumber(), GAS_CEILING) };
}

// Every interval is required: gas feasibility is not assumed to be monotonic.
function minimumContiguousPartition(count, edges) {
    assert(Number.isInteger(count) && count > 0 && count <= 18, 'Selection supports 1 to 18 original migration shards.');
    const byRange = new Map();
    for (const edge of edges) {
        assert(Number.isInteger(edge.start) && Number.isInteger(edge.end) && edge.start >= 0
            && edge.start < edge.end && edge.end <= count && typeof edge.success === 'boolean', 'Invalid probe edge.');
        const key = `${edge.start}:${edge.end}`;
        assert(!byRange.has(key), 'Repeated probe edge.');
        byRange.set(key, edge);
    }
    assert.equal(byRange.size, count * (count + 1) / 2, 'Minimum proof requires every contiguous interval.');
    const minimum = Array(count + 1).fill(Infinity);
    const previous = Array(count + 1).fill(null);
    minimum[0] = 0;
    for (let end = 1; end <= count; end++) {
        for (let start = 0; start < end; start++) {
            if (byRange.get(`${start}:${end}`).success && minimum[start] + 1 < minimum[end]) {
                minimum[end] = minimum[start] + 1;
                previous[end] = start;
            }
        }
    }
    assert(Number.isFinite(minimum[count]), 'No complete contiguous partition fits the execution gas budget.');
    const ranges = [];
    for (let end = count; end > 0; end = previous[end]) ranges.unshift({ start: previous[end], end });
    return { minimumTransactions: minimum[count], ranges, minimumByPrefix: minimum.map(value => Number.isFinite(value) ? value : null) };
}

function implementationHashes() {
    return Object.fromEntries(['simulate-safe-airdrop.js', 'export-safe-airdrop.js', 'generate-v6-airdrop.js']
        .map(file => [file, ethers.utils.keccak256(fs.readFileSync(path.join(__dirname, file)))]));
}

function isGasExhaustion(failures) {
    const outOfGas = failure => /out.?of.?gas|gas.?exhaust|insufficient.?gas/i.test(failure.error);
    // Revert text can be arbitrary contract data. Only tracer error types establish exhaustion.
    return failures.some(outOfGas) && failures.every(failure => outOfGas(failure)
        || failure.reason === '0x' || failure.reason === 'GS013');
}

async function requireGasExhaustedCandidate(provider, executionPromise) {
    // Execution/receipt/trace transport failures propagate; they never establish a gas lower bound.
    const execution = await executionPromise;
    const receipt = execution.receipt;
    assert(receipt && Number.isInteger(receipt.blockNumber) && receipt.blockNumber > 0 && ethers.utils.isHexString(receipt.blockHash, 32)
        && ethers.utils.isHexString(receipt.transactionHash, 32), 'Whole candidate needs a mined receipt.');
    assert.equal(receipt.status, 0, 'Whole candidate must revert to establish the two-bundle lower bound.');
    assert.equal(execution.success, false, 'Whole candidate unexpectedly emitted Safe ExecutionSuccess.');
    const failures = await failureTrace(provider, receipt.transactionHash);
    assert(isGasExhaustion(failures), 'Whole candidate failed without traced gas exhaustion.');
    return { nonce: execution.nonce, safeTransactionHash: execution.hash, safeTransaction: execution.safeTransaction,
        transactionHash: receipt.transactionHash, blockHash: receipt.blockHash, blockNumber: receipt.blockNumber, receiptStatus: receipt.status,
        gasUsed: receipt.gasUsed.toString(), success: false, failures };
}

async function selectOnFork(provider, envelopes, plans, owners, gasLimit, report, { twoBundleSplit, onProgress } = {}) {
    const migrations = validateCoverage(envelopes, plans);
    assert(migrations.length <= 18, 'Selection supports at most 18 original migration shards.');
    const parts = migrations.map(envelope => {
        const { batchBuilder, file, fileKeccak256, builderFile, builderFileKeccak256, ...safeTransaction } = envelope;
        assert(batchBuilder, `Missing sibling Builder JSON for ${envelope.file}.`);
        assert(!envelope.components, 'Selection requires original migration shards.');
        return { batch: batchBuilder, safeTransaction, sourceProof: { file, fileKeccak256, builderFile, builderFileKeccak256 } };
    });
    // Validate every source pair and continuity before local execution.
    combineMigrationBatches(parts);
    if (twoBundleSplit !== undefined) assert(Number.isInteger(twoBundleSplit) && twoBundleSplit > 0
        && twoBundleSplit < parts.length, 'Two-bundle split must leave a nonempty original-shard range on each side.');
    const setup = envelopes.filter(envelope => envelope.stage !== 'migration');
    if (setup.length) await rehearseStages(provider, setup, plans, owners, gasLimit, report);
    const safe = new ethers.Contract(envelopes[0].safe, SAFE_ABI, provider);
    report.migrationStartNonce = (await safe.nonce()).toString();
    const initial = await provider.send('evm_snapshot', []);
    let minimum;
    if (twoBundleSplit !== undefined) {
        report.proofKind = 'two-bundle-lower-bound';
        const whole = combineMigrationBatches(parts);
        report.wholeCandidate = { sourceOrders: parts.map(part => part.safeTransaction.order), simulationGasLimit: gasLimit,
            ...await requireGasExhaustedCandidate(provider, executeSafe(provider, whole.safeTransaction, owners, gasLimit)) };
        assert.equal(report.wholeCandidate.nonce, report.migrationStartNonce, 'Whole candidate did not use the exact post-setup nonce.');
        await onProgress?.(report);
        minimum = { minimumTransactions: 2, ranges: [{ start: 0, end: twoBundleSplit }, { start: twoBundleSplit, end: parts.length }] };
    } else {
        report.probeEdges = [];
        for (let start = 0; start < parts.length; start++) {
            let prefix = await provider.send('evm_snapshot', []);
            for (let end = start + 1; end <= parts.length; end++) {
                const candidate = combineMigrationBatches(parts.slice(start, end));
                const execution = await executeSafe(provider, candidate.safeTransaction, owners, gasLimit);
                const success = execution.receipt.status === 1 && execution.success;
                let failures;
                if (!success) {
                    failures = await failureTrace(provider, execution.receipt.transactionHash);
                    // A transport error never reaches here. An unexpected semantic revert is not a gas bound.
                    assert(isGasExhaustion(failures),
                        `Candidate ${start}:${end} failed without traced gas exhaustion: ${JSON.stringify(failures)}`);
                }
                report.probeEdges.push({ start, end, success, simulationGasLimit: gasLimit,
                    nonce: execution.nonce, safeTransactionHash: execution.hash,
                    gasUsed: execution.receipt.gasUsed.toString(), ...(failures ? { failures } : {}) });
                console.log(`  probe [${start}, ${end}): ${success ? 'fits' : 'gas exhausted'} at ${gasLimit} outer gas`);
                assert(await provider.send('evm_revert', [prefix]), 'Could not restore canonical prefix after probe.');
                prefix = await provider.send('evm_snapshot', []);
            }
            // Canonical prefix state is always built from the original shards, independently of candidate feasibility.
            const advance = await executeSafe(provider, unbound(parts[start].safeTransaction), owners, gasLimit);
            assert.equal(advance.receipt.status, 1, 'Original shard cannot advance canonical prefix at the gas budget.');
            assert(advance.success, 'Original shard lacks matching Safe ExecutionSuccess.');
        }
        minimum = minimumContiguousPartition(parts.length, report.probeEdges);
        report.minimality = { ...minimum, originalShardCount: parts.length, completeIntervalCount: report.probeEdges.length,
            scope: 'Exact minimum for the complete interval graph probed on canonical original-shard prefix states; the selected partition is independently replayed at its actual nonces. Does not assume callback state equivalence for alternative bundled prefixes.' };
    }
    assert(await provider.send('evm_revert', [initial]), 'Could not restore the exact post-setup state.');
    assert.equal((await safe.nonce()).toString(), report.migrationStartNonce);
    const bundles = minimum.ranges.map(({ start, end }, index) => {
        const combined = combineMigrationBatches(parts.slice(start, end), { order: migrations[0].order + index });
        return { start, end, sourceOrders: parts.slice(start, end).map(part => part.safeTransaction.order),
            sourceFiles: parts.slice(start, end).map(part => part.sourceProof), ...combined };
    });
    const finalEnvelopes = bundles.map(bundle => bundle.safeTransaction);
    validateCoverage(finalEnvelopes, plans);
    const final = { startNonce: report.migrationStartNonce, failures: [], chunks: [] };
    await rehearseStages(provider, finalEnvelopes, plans, owners, gasLimit, final, { includeEnvelopes: true });
    report.failures.push(...final.failures);
    report.bundles = bundles.map((bundle, index) => ({ ...bundle, ...final.chunks[index], simulationGasLimit: gasLimit }));
    assert.equal(report.bundles[0].nonce, report.migrationStartNonce, 'Final first bundle did not use the exact post-setup nonce.');
    report.chunks.push(...final.chunks.map(({ safeTransaction, ...chunk }) => chunk));
    report.endNonce = final.endNonce;
    assert.equal(BigInt(report.endNonce) - BigInt(report.migrationStartNonce), BigInt(bundles.length), 'Migration nonce advancement differs from selected bundle count.');
    assert.equal(BigInt(report.endNonce) - BigInt(report.startNonce), BigInt(setup.length + bundles.length), 'Safe nonce advanced outside setup and selected bundles.');
    if (twoBundleSplit !== undefined) report.minimality = { ...minimum, originalShardCount: parts.length,
        scope: 'Minimum 2 established by failure of the whole distribution at the exact post-setup state and successful exact two-bundle replay.' };
    return report;
}

async function selectBundles(envelopes, plans, rpcUrl, requestedBlock, options = {}) {
    return simulateChain(envelopes, plans, rpcUrl, requestedBlock, { ...options, selection: true });
}

async function simulateChain(envelopes, plans, rpcUrl, requestedBlock, { selection = false, twoBundleSplit, onProgress } = {}) {
    const first = envelopes[0];
    validateCoverage(envelopes, plans);
    const chainId = Number(first.chainId);
    const remote = new ethers.providers.StaticJsonRpcProvider(rpcUrl, chainId);
    assert.equal(Number(await remote.send('eth_chainId', [])), chainId, 'RPC chain does not match exported chain.');
    const blockNumber = requestedBlock || Math.max(1, (await remote.getBlockNumber()) - 5);
    const forkBlock = await remote.getBlock(blockNumber);
    assert(forkBlock, `Fork block ${blockNumber} is unavailable.`);
    const policy = simulationPolicy(envelopes, chainId, forkBlock.gasLimit, { selection, twoBundleSplit });
    selection = policy.selection;
    const { budget, gasLimit } = policy;
    const { child, provider } = await startFork(rpcUrl, chainId, blockNumber, { budgeted: Boolean(budget) });
    let report;
    try {
        const safe = new ethers.Contract(first.safe, SAFE_ABI, provider);
        const threshold = (await safe.getThreshold()).toNumber();
        const owners = [...await safe.getOwners()].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())).slice(0, threshold);
        assert.equal(owners.length, threshold);
        assert(threshold > 0, 'Safe threshold is zero.');
        for (const owner of owners) await impersonate(provider, owner);
        report = { chainId, blockNumber, blockHash: forkBlock.hash, safe: first.safe, threshold, status: 'running',
            safeVersion: await safe.VERSION(), implementationHashes: implementationHashes(),
            startNonce: (await safe.nonce()).toString(), blockGasLimit: forkBlock.gasLimit.toString(),
            transactionGasLimit: gasLimit, failures: [], chunks: [] };
        if (budget) {
            report.gasBudget = gasLimit;
            report.executionGasCap = budget.executionGasCap;
            report.headroomPercent = budget.headroomPercent;
            report.executionProof = isArbitrum(chainId)
                ? 'Local Osaka EVM execution only, with the Ethereum transaction cap disabled and the explicit Arbitrum gas budget enforced; excludes Nitro L1-data posting fees and Nitro-specific execution behavior.'
                : 'Local fork EVM execution under the exact outer gas budget; receipt gas after refunds is not used to infer fit.';
            report.anvilHardfork = 'osaka';
            report.ethereumTransactionCapEnabled = !isArbitrum(chainId);
        }
        await onProgress?.(report);
        console.log(`${chainId}: fork block ${blockNumber}, Safe threshold ${threshold}, ${envelopes.length} stages`);
        if (selection) await selectOnFork(provider, envelopes, plans, owners, gasLimit, report, { twoBundleSplit, onProgress });
        else await rehearseStages(provider, envelopes, plans, owners, gasLimit, report);
        report.status = 'passed';
        return report;
    } catch (error) {
        if (report) {
            report.status = 'failed';
            report.error = publicError(error);
            await onProgress?.(report);
        }
        throw error;
    } finally {
        provider.removeAllListeners();
        child.kill();
    }
}

async function main() {
    const args = process.argv.slice(2);
    const directory = args.shift();
    assert(directory && !directory.startsWith('-'), 'Usage: node simulate-safe-airdrop.js <export-profile-directory> [--chain ID] [--block NUMBER] [--select-bundles | --two-bundle-split N] [--report FILE]');
    const options = {};
    while (args.length) {
        const option = args.shift();
        if (option === '--select-bundles') {
            options[option] = true;
            continue;
        }
        assert(['--chain', '--block', '--report', '--two-bundle-split'].includes(option), `Unknown option ${option}`);
        assert(args.length && !args[0].startsWith('--'), `Missing value for ${option}`);
        options[option] = args.shift();
    }
    for (const option of ['--chain', '--block', '--two-bundle-split']) {
        if (options[option]) assert(/^[1-9][0-9]*$/.test(options[option]), `${option} must be a positive integer.`);
    }
    assert(!options['--block'] || options['--chain'], '--block requires --chain so the pin applies to one chain.');
    const selection = Boolean(options['--select-bundles'] || options['--two-bundle-split']);
    assert(!selection || options['--report'], 'Bundle selection requires an explicit --report destination.');
    const all = readTransactions(path.resolve(directory), { loadBuilders: selection });
    const selected = all.filter(envelope => !options['--chain'] || String(envelope.chainId) === options['--chain']);
    assert(selected.length > 0, 'No transactions match the selected chain.');
    const plans = new Map(Object.values(buildContractsByChain(loadRawItems())).flat().map(plan => [plan.contractName, plan]));
    const chainIds = [...new Set(selected.map(envelope => String(envelope.chainId)))];
    const report = { simulatedAt: new Date().toISOString(), localForkOnly: true, status: 'running', expectedChainIds: chainIds, chains: [] };
    const reportPath = path.resolve(options['--report'] || path.join(directory, 'simulation.json'));
    const save = () => fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
    save();
    try {
        for (const chainId of chainIds) {
            report.activeChainId = chainId;
            save();
            const envelopes = selected.filter(envelope => String(envelope.chainId) === chainId).sort((a, b) => a.order - b.order);
            const rpcEnv = Object.values(NETWORKS).flat().find(network => String(network.chainId) === chainId)?.rpc;
            assert(rpcEnv, `Unsupported chain ${chainId}`);
            assert(process.env[rpcEnv], `Set ${rpcEnv} before running the fork simulation.`);
            const index = report.chains.length;
            report.chains[index] = await simulateChain(envelopes, plans, process.env[rpcEnv], Number(options['--block']) || undefined,
                { selection, twoBundleSplit: options['--two-bundle-split'] ? Number(options['--two-bundle-split']) : undefined,
                    onProgress: chain => { report.chains[index] = chain; save(); } });
            save();
        }
        report.status = 'passed';
        delete report.activeChainId;
    } catch (error) {
        report.status = 'failed';
        report.error = publicError(error);
        throw error;
    } finally {
        save();
    }
    console.log(`Wrote ${reportPath}; all transactions were executed only on local Anvil forks.`);
}

function publicError(error) {
    // Provider errors may contain credentials and huge calldata; expose only the direct validation message.
    return error.code && !String(error.code).startsWith('ERR_ASSERTION')
        ? `Fork RPC or transaction failed (${error.code}). Check RPC availability and exported chain state.`
        : error.message;
}

if (require.main === module) main().catch(error => {
    console.error(publicError(error));
    process.exitCode = 1;
});

module.exports = { readTransactions, simulateChain, selectBundles, gasBudget, simulationPolicy, minimumContiguousPartition,
    verifyRecipients, migrationPlan, validateCoverage, hasExecutionSuccess, assertBoundHash, isGasExhaustion, requireGasExhaustedCandidate,
    startFork, receiptFor, impersonate, failureTrace };
