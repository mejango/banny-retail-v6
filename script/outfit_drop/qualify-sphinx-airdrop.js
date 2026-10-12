#!/usr/bin/env node

// Qualification only. All approvals and execution are sent to forks spawned on loopback here.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { ethers } = require('ethers');
const { makeSphinxMerkleTree, SphinxLeafType } = require('@sphinx-labs/contracts');
const { makeDeploymentData, estimateGasViaManagedService, getMaxGasLimit,
    isActionTransactionBatchingEnabled } = require('@sphinx-labs/core');
const { startFork, receiptFor, impersonate, failureTrace, gasBudget, migrationPlan, verifyRecipients } = require('./simulate-safe-airdrop');
const { MAX_MINTS_PER_TRANSACTION } = require('./export-safe-airdrop');

const MODULE_ARTIFACT = require('@sphinx-labs/contracts/contract-artifacts/sphinx/SphinxModule.sol/SphinxModule.json');
const SAFE_ABI = [
    'function getOwners() view returns(address[])', 'function getThreshold() view returns(uint256)',
    'function nonce() view returns(uint256)', 'function approveHash(bytes32)',
    'function isModuleEnabled(address) view returns(bool)',
    'function execTransactionFromModule(address,uint256,bytes,uint8) returns(bool)',
];
const SAFE_INTERFACE = new ethers.utils.Interface(SAFE_ABI);
const RELAY = new ethers.utils.Interface(['function exec(address,bytes)']);
const MAX_WORD = `0x${'ff'.repeat(32)}`;
const MIN_HEADROOM = 120_000n;
const ROOT = path.resolve(__dirname, '../..');
const sha256 = value => createHash('sha256').update(value).digest('hex');
const sameAddress = (a, b) => String(a).toLowerCase() === String(b).toLowerCase();
const treeOf = configs => makeSphinxMerkleTree(makeDeploymentData(configs));
const executeLeaves = (tree, chainId) => tree.leavesWithProofs.filter(entry =>
    entry.leaf.leafType === SphinxLeafType.EXECUTE && String(entry.leaf.chainId) === String(chainId));

function actionDigest(action) {
    return ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint256', 'bytes', 'uint8', 'bool'],
        [action.to, action.value, action.txData, action.operation, action.requireSuccess]));
}

function outerBudget(config) {
    const budget = gasBudget(config.chainId, config.blockGasLimit).budget;
    return Number(BigInt(budget) < getMaxGasLimit(BigInt(config.blockGasLimit))
        ? BigInt(budget) : getMaxGasLimit(BigInt(config.blockGasLimit)));
}

function worstProofLeaf(config, action, proofDepth) {
    assert(Number.isInteger(proofDepth) && proofDepth >= 0 && proofDepth <= 32, 'Invalid Merkle proof depth.');
    return { leaf: { chainId: BigInt(config.chainId), index: BigInt(MAX_WORD), leafType: SphinxLeafType.EXECUTE,
        data: ethers.utils.defaultAbiCoder.encode(['address', 'uint256', 'uint256', 'bytes', 'uint8', 'bool'],
            [action.to, action.value, action.gas, action.txData, action.operation, action.requireSuccess]) },
    proof: Array(proofDepth).fill(MAX_WORD) };
}

function estimateBatch(config, leaves) {
    return estimateGasViaManagedService(config.moduleAddress, leaves, BigInt(config.chainId));
}

// Invert the installed singleton estimator using worst-case proof/index calldata. This is only
// a generous probe allowance; cold execution and the final exact root remain the acceptance gates.
function probeAllowance(config, action, proofDepth) {
    const budget = outerBudget(config);
    let low = 0;
    let high = budget;
    while (low < high) {
        const middle = Math.ceil((low + high) / 2);
        const estimate = estimateBatch(config, [worstProofLeaf(config, { ...action, gas: String(middle) }, proofDepth)]);
        // Gas-word zero-byte changes are bounded by 32 * 12 gas; this reserve exceeds that
        // variation including the SDK's 8% overhead, so the probe never depends on byte luck.
        if (estimate + 1024 <= budget) low = middle;
        else high = middle - 1;
    }
    assert(low > 0, 'Action calldata cannot fit the chain execution budget.');
    assert(estimateBatch(config, [worstProofLeaf(config, { ...action, gas: String(low) }, proofDepth)]) < budget);
    return String(low);
}

function coldAllowance(grossGas) {
    const gas = BigInt(grossGas);
    assert(gas > 0n, 'Cold Safe-frame gas must be positive.');
    // Preserve Sphinx's existing margin, but apply it to a separately executed cold action.
    return (MIN_HEADROOM + (gas * 12n + 9n) / 10n).toString();
}

function qualifiedAllowance(grossGas, maximumGas) {
    const requested = BigInt(coldAllowance(grossGas));
    const maximum = BigInt(maximumGas);
    const selected = requested < maximum ? requested : maximum;
    const headroom = selected - BigInt(grossGas);
    assert(headroom >= MIN_HEADROOM, 'Atomic shard cannot retain minimum cold headroom within the chain budget; split and requalify it.');
    return { requestedGas: requested.toString(), maximumGas: maximum.toString(), signedGas: selected.toString(),
        headroom: headroom.toString(), budgetLimited: selected < requested };
}

function assertHeadroom(signedGas, grossGas) {
    const headroom = BigInt(signedGas) - BigInt(grossGas);
    assert(headroom >= MIN_HEADROOM, 'Final signed action has insufficient measured execution headroom.');
    return headroom.toString();
}

function packSegments(configs, proofDepth) {
    const partsByChain = configs.map(config => {
        assert(config.actionInputs.length > 0, 'Cannot qualify an empty chain.');
        const parts = [];
        let pending = [];
        for (const action of config.actionInputs) {
            const leaf = worstProofLeaf(config, action, proofDepth);
            assert(estimateBatch(config, [leaf]) <= outerBudget(config), 'Buffered atomic shard exceeds the chain budget; split and requalify it.');
            const candidate = [...pending, action];
            if (pending.length &&
                estimateBatch(config, candidate.map(item => worstProofLeaf(config, item, proofDepth))) > outerBudget(config)) {
                parts.push(pending);
                pending = [action];
            } else pending = candidate;
        }
        if (pending.length) parts.push(pending);
        return parts;
    });
    const segments = Array.from({ length: Math.max(...partsByChain.map(parts => parts.length)) }, (_, segmentIndex) => {
        const networkConfigs = configs.flatMap((config, chainIndex) => {
            const actions = partsByChain[chainIndex][segmentIndex];
            return actions ? [{ ...config, nonce: (BigInt(config.nonce) + BigInt(segmentIndex)).toString(),
                actionInputs: actions.map((action, index) => ({ ...action, index: String(index + 1) })) }] : [];
        });
        const merkleTree = treeOf(networkConfigs);
        for (const config of networkConfigs) {
            const leaves = executeLeaves(merkleTree, config.chainId);
            assert(estimateBatch(config, leaves) <= outerBudget(config), 'Exact complete part exceeds the chain budget.');
        }
        return { networkConfigs, merkleTree };
    });
    for (const config of configs) {
        const flattened = segments.flatMap(segment => segment.networkConfigs.filter(network => network.chainId === config.chainId)
            .flatMap(network => network.actionInputs));
        assert.deepEqual(flattened.map(actionDigest), config.actionInputs.map(actionDigest), 'Segmentation changed canonical action bytes or order.');
        assert.deepEqual(flattened.map(action => action.gas), config.actionInputs.map(action => action.gas), 'Segmentation changed calibrated gas.');
    }
    return segments;
}

function safeFrames(trace, moduleAddress, safeAddress) {
    const frames = [];
    function visit(frame) {
        if (frame.type === 'CALL' && sameAddress(frame.from, moduleAddress) && sameAddress(frame.to, safeAddress)
            && frame.input?.startsWith(SAFE_INTERFACE.getSighash('execTransactionFromModule'))) frames.push(frame);
        for (const child of frame.calls || []) visit(child);
    }
    visit(trace);
    return frames;
}

function measureSafeFrame(frame, action) {
    assert(frame && !frame.error, 'Missing or failed module-to-Safe call frame.');
    assert.equal(frame.input.toLowerCase(), SAFE_INTERFACE.encodeFunctionData('execTransactionFromModule',
        [action.to, action.value, action.txData, action.operation]).toLowerCase(), 'Safe frame calldata differs from the signed action.');
    assert.equal(frame.output.toLowerCase(), ethers.utils.defaultAbiCoder.encode(['bool'], [true]), 'Safe returned false.');
    const used = BigInt(frame.gasUsed);
    assert(used > 0n && used <= BigInt(frame.gas), 'Invalid gross Safe frame gas.');
    assert.equal(BigInt(frame.gas), BigInt(action.gas), 'Module did not forward the signed allowance.');
    return used.toString();
}

function moduleEvents(receipt, module) {
    return receipt.logs.filter(log => sameAddress(log.address, module.address)).map(log => module.interface.parseLog(log))
        .map(event => ({ name: event.name, root: event.args[0], index: event.args[1]?.toString() }));
}

function assertActionEvents(receipt, module, root, indices) {
    const events = moduleEvents(receipt, module);
    assert.equal(receipt.status, 1, 'Relay/module transaction reverted.');
    assert(!events.some(event => ['SphinxActionFailed', 'SphinxMerkleRootFailed'].includes(event.name)), 'Sphinx action/root failed despite the outer receipt.');
    const success = events.filter(event => event.name === 'SphinxActionSucceeded');
    assert.deepEqual(success.map(event => event.index), indices.map(String), 'Missing or unexpected Sphinx action success indices.');
    for (const event of events) assert.equal(event.root, root, 'Event belongs to another root.');
    return events;
}

function validatePrepared(config, prepared) {
    assert(prepared && String(prepared.chainId) === String(config.chainId), 'Prepared chain missing.');
    assert(sameAddress(prepared.safe, config.safeAddress), 'Prepared Safe differs.');
    assert(!config.arbitraryChain, 'Airdrop roots must bind the destination chain.');
    assert.equal(config.actionInputs.length, prepared.envelopes.length, 'Canonical action count differs.');
    const plans = prepared.plans instanceof Map ? prepared.plans : new Map(prepared.plans.map(plan => [plan.contractName, plan]));
    const allIds = [];
    for (const [index, envelope] of prepared.envelopes.entries()) {
        assert(['setup', 'migration'].includes(envelope.stage), 'Unknown airdrop stage.');
        assert(!envelope.components, 'Use canonical atomic shards, not merged Safe bundles.');
        assert.equal(String(envelope.chainId), String(config.chainId));
        assert(sameAddress(envelope.safe, config.safeAddress));
        const action = config.actionInputs[index];
        assert.equal(action.requireSuccess, true, 'Airdrop actions must require success.');
        for (const [actionKey, envelopeKey] of [['to', 'to'], ['txData', 'data'], ['value', 'value'], ['operation', 'operation']]) {
            assert.equal(String(action[actionKey]).toLowerCase(), String(envelope.transaction[envelopeKey]).toLowerCase(), 'Sphinx action differs from its canonical atomic Safe envelope.');
        }
        if (envelope.stage === 'migration') {
            const plan = migrationPlan(envelope, plans);
            assert(plan.assignments.expectedTokenIds.length <= MAX_MINTS_PER_TRANSACTION, 'Atomic shard exceeds the reviewed mint limit.');
            allIds.push(...plan.assignments.expectedTokenIds);
        }
    }
    const expected = [...plans.values()].flatMap(plan => plan.assignments.expectedTokenIds);
    assert.equal(new Set(allIds).size, allIds.length, 'Repeated NFT allocation.');
    assert.deepEqual([...allIds].sort((a, b) => a - b), [...expected].sort((a, b) => a - b), 'Prepared shards omit or add NFT allocations.');
    return plans;
}

function safeError(error) {
    return error.code === 'ERR_ASSERTION' ? error.message : `Local qualification failed (${String(error.code || error.name || 'unknown').replace(/[^A-Za-z0-9_-]/g, '')}).`;
}

async function captureFailure(provider, record, error, save) {
    record.failure = safeError(error);
    save();
    try { record.innerFailures = await failureTrace(provider, record.transactionHash); }
    catch (traceError) { record.traceError = safeError(traceError); }
    save();
}

async function openContext(entry, prepared, report) {
    const config = entry.networkConfig;
    const plans = validatePrepared(config, prepared);
    const pin = Number(config.blockNumber);
    assert(Number.isSafeInteger(pin) && pin > 0, 'A pinned block is required.');
    const { child, provider } = await startFork(entry.rpcUrl, Number(config.chainId), pin, { budgeted: true });
    try {
        assert.equal(new URL(provider.connection.url).hostname, '127.0.0.1', 'Writes require our loopback fork.');
        const block = await provider.getBlock(pin);
        assert(/^0x[\da-f]{64}$/i.test(prepared.blockHash || ''), 'Prepared chain needs its collected block hash.');
        assert.equal(block.hash.toLowerCase(), prepared.blockHash.toLowerCase(), 'Pinned block hash changed.');
        assert.equal(block.gasLimit.toString(), String(config.blockGasLimit), 'Collected block gas limit differs from the real pinned header.');
        const safe = new ethers.Contract(config.safeAddress, SAFE_ABI, provider);
        const module = new ethers.Contract(config.moduleAddress, MODULE_ARTIFACT.abi, provider);
        assert(await safe.isModuleEnabled(module.address), 'Sphinx module is not enabled.');
        assert(sameAddress(await module.safeProxy(), safe.address), 'Module binds another Safe.');
        assert.equal((await module.merkleRootNonce()).toString(), String(config.nonce), 'Module nonce changed.');
        assert.equal(await module.activeMerkleRoot(), ethers.constants.HashZero, 'A Sphinx root is already active.');
        assert.notEqual(await provider.getCode(config.executorAddress), '0x', 'Configured relay has no code.');
        const threshold = (await safe.getThreshold()).toNumber();
        const owners = [...await safe.getOwners()].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())).slice(0, threshold);
        assert(threshold > 0 && owners.length === threshold, 'Invalid Safe threshold.');
        for (const owner of owners) await impersonate(provider, owner);
        const safeNonce = (await safe.nonce()).toString();
        const context = { config, prepared, plans, child, provider, safe, module, owners, safeNonce, report,
            initialSnapshot: await provider.send('evm_snapshot', []) };
        Object.assign(report, { chainId: String(config.chainId), blockNumber: pin, blockHash: block.hash,
            blockGasLimit: block.gasLimit.toString(), safe: safe.address, module: module.address, relay: config.executorAddress,
            safeNonce, moduleNonce: config.nonce, threshold, outerGasBudget: outerBudget(config), anvilHardfork: 'osaka',
            batchingEnabled: isActionTransactionBatchingEnabled(BigInt(config.chainId)), calibration: [], final: [] });
        report.runtimeKeccak256 = Object.fromEntries(await Promise.all([
            ['safe', config.safeAddress], ['moduleProxy', config.moduleAddress], ['relay', config.executorAddress],
        ].map(async ([name, address]) => [name, ethers.utils.keccak256(await provider.getCode(address))])));
        return context;
    } catch (error) { child.kill(); throw error; }
}

async function relaySend(context, data) {
    assert.equal(new URL(context.provider.connection.url).hostname, '127.0.0.1');
    return receiptFor(context.provider, { from: context.owners[0], to: context.config.executorAddress,
        data: RELAY.encodeFunctionData('exec', [context.module.address, data]), gas: ethers.utils.hexValue(outerBudget(context.config)) });
}

async function approveRoot(context, config, tree) {
    const { provider, safe, module, owners } = context;
    assert.equal((await module.merkleRootNonce()).toString(), config.nonce, 'Wrong segment module nonce.');
    assert.equal(await module.activeMerkleRoot(), ethers.constants.HashZero, 'Previous segment did not clear its root.');
    const digest = ethers.utils._TypedDataEncoder.hash({ name: 'Sphinx', version: await module.VERSION() },
        { MerkleRoot: [{ name: 'root', type: 'bytes32' }] }, { root: tree.root });
    for (const owner of owners) {
        const receipt = await receiptFor(provider, { from: owner, to: safe.address,
            data: safe.interface.encodeFunctionData('approveHash', [digest]), gas: '0x186a0' });
        assert.equal(receipt.status, 1, 'Local owner root-hash approval failed.');
    }
    const signatures = ethers.utils.hexConcat(owners.map(owner => ethers.utils.solidityPack(['bytes32', 'bytes32', 'uint8'],
        [ethers.utils.hexZeroPad(owner, 32), ethers.constants.HashZero, 1])));
    const approval = tree.leavesWithProofs.find(entry => entry.leaf.leafType === SphinxLeafType.APPROVE && String(entry.leaf.chainId) === String(config.chainId));
    assert(approval, 'Missing exact chain approval leaf.');
    assert.equal((await relaySend(context, module.interface.encodeFunctionData('approve', [tree.root, approval, signatures]))).status, 1, 'Root approval reverted.');
    assert.equal(await module.activeMerkleRoot(), tree.root);
}

async function executeRoot(context, config, tree, mode, records, save, requireHeadroom = true) {
    await approveRoot(context, config, tree);
    const { provider, module } = context;
    const leaves = executeLeaves(tree, config.chainId);
    const batches = mode === 'cold' ? leaves.map(leaf => [leaf]) : [leaves];
    const measured = [];
    for (const batch of batches) {
        const indices = batch.map(entry => Number(entry.leaf.index));
        const receipt = await relaySend(context, module.interface.encodeFunctionData('execute', [batch]));
        const record = { root: tree.root, mode, indices, transactionHash: receipt.transactionHash,
            outerReceiptStatus: receipt.status, receiptGasUsed: receipt.gasUsed.toString() };
        records.push(record);
        record.events = moduleEvents(receipt, module);
        record.firstFailureIndex = record.events.find(event => event.name === 'SphinxActionFailed')?.index;
        save();
        try {
            const currentState = await module.merkleRootStates(tree.root);
            record.rootStatus = Number(currentState.status);
            record.activeRoot = await module.activeMerkleRoot(); save();
            assertActionEvents(receipt, module, tree.root, indices);
            const trace = await provider.send('debug_traceTransaction', [receipt.transactionHash, { tracer: 'callTracer' }]);
            const frames = safeFrames(trace, module.address, context.safe.address);
            assert.equal(frames.length, batch.length, 'Missing or ambiguous module-to-Safe trace frames.');
            record.actions = frames.map((frame, index) => {
                const action = config.actionInputs[indices[index] - 1];
                const grossGas = measureSafeFrame(frame, action);
                return { index: indices[index], actionDigest: actionDigest(action), signedGas: action.gas, grossSafeGas: grossGas,
                    headroom: (BigInt(action.gas) - BigInt(grossGas)).toString() };
            });
            save();
            if (requireHeadroom) for (const action of record.actions) assertHeadroom(action.signedGas, action.grossSafeGas);
            measured.push(...record.actions);
            console.log(`Sphinx ${config.chainId} ${mode}: leaves ${indices.join(',')} passed (${receipt.gasUsed} receipt gas).`);
        } catch (error) { await captureFailure(provider, record, error, save); throw error; }
    }
    const state = await module.merkleRootStates(tree.root);
    assert.equal(Number(state.status), 2, 'Sphinx root did not complete.');
    assert.equal(state.leavesExecuted.toString(), String(leaves.length + 1), 'Wrong executed leaf count.');
    assert.equal(await module.activeMerkleRoot(), ethers.constants.HashZero);
    assert.equal((await context.safe.nonce()).toString(), context.safeNonce, 'Module execution changed ordinary Safe nonce.');
    return measured;
}

async function allContexts(contexts, fn) {
    const results = await Promise.allSettled(contexts.map(fn));
    const failure = results.find(result => result.status === 'rejected');
    if (failure) throw failure.reason;
    return results.map(result => result.value);
}

function validateSeedCalibration(seedReport, configs, tree, currentChains) {
    assert.equal(seedReport.localForkOnly, true, 'Calibration seed must come from loopback qualification.');
    assert.equal(seedReport.provisionalRoot, tree.root, 'Calibration seed provisional root differs.');
    assert.deepEqual(seedReport.chains.map(chain => chain.chainId), configs.map(config => String(config.chainId)), 'Calibration seed chain coverage differs.');
    return configs.map((config, chainIndex) => {
        const old = seedReport.chains[chainIndex];
        const current = currentChains[chainIndex];
        for (const field of ['chainId', 'blockNumber', 'blockHash', 'blockGasLimit', 'safe', 'module', 'relay',
            'safeNonce', 'moduleNonce', 'threshold', 'outerGasBudget', 'anvilHardfork']) {
            assert.equal(old[field], current[field], `Calibration seed ${field} differs.`);
        }
        assert.deepEqual(old.runtimeKeccak256, current.runtimeKeccak256, 'Calibration seed runtime differs.');
        assert.equal(old.calibration.length, config.actionInputs.length, 'Calibration seed action coverage differs.');
        const seen = new Set();
        return old.calibration.map((record, index) => {
            assert.equal(record.root, tree.root);
            assert.equal(record.mode, 'cold');
            assert.equal(record.outerReceiptStatus, 1);
            assert(!record.failure && !record.firstFailureIndex, 'Calibration seed contains a failed action.');
            assert(/^0x[\da-f]{64}$/i.test(record.transactionHash) && !seen.has(record.transactionHash), 'Invalid or repeated calibration transaction.');
            seen.add(record.transactionHash);
            assert.deepEqual(record.indices, [index + 1], 'Calibration seed action order differs.');
            assert.equal(record.actions.length, 1, 'Calibration seed must contain separate cold measurements.');
            const action = config.actionInputs[index];
            const measured = record.actions[0];
            assert.equal(measured.index, index + 1);
            assert.equal(measured.actionDigest, actionDigest(action), 'Calibration seed action bytes differ.');
            assert.equal(measured.signedGas, action.gas, 'Calibration seed probe allowance differs.');
            assert(BigInt(measured.grossSafeGas) > 0n && BigInt(measured.grossSafeGas) <= BigInt(measured.signedGas), 'Calibration seed needs positive successful gross frame gas.');
            const last = index === config.actionInputs.length - 1;
            assert.equal(record.rootStatus, last ? 2 : 1, 'Calibration seed root lifecycle differs.');
            assert.equal(record.activeRoot, last ? ethers.constants.HashZero : tree.root);
            assert.deepEqual(record.events.map(event => event.name), last
                ? ['SphinxActionSucceeded', 'SphinxMerkleRootCompleted'] : ['SphinxActionSucceeded'], 'Calibration seed success events differ.');
            assert.equal(record.events[0].index, String(index + 1));
            for (const event of record.events) assert.equal(event.root, tree.root);
            return measured;
        });
    });
}

// Internal verification continuation only: no CLI/env bypass. The unchanged signed input,
// complete cold lifecycle and archived measuring implementation must all remain attributable.
function readCalibrationSeed(seed, reportDirectory, sourceSha256) {
    const bytes = fs.readFileSync(seed.reportFile);
    const inputBytes = fs.readFileSync(seed.inputsFile);
    const old = JSON.parse(bytes);
    const inputs = JSON.parse(inputBytes);
    assert.deepEqual(inputs, JSON.parse(fs.readFileSync(path.join(reportDirectory, 'inputs.json'))), 'Calibration seed source/input identity differs.');
    assert(/^[\da-f]{64}$/i.test(inputs.inputIdentity || ''), 'Calibration seed input identity is missing.');
    assert.deepEqual(Object.keys(old.sourceSha256).sort(), Object.keys(sourceSha256).sort(), 'Calibration seed source coverage differs.');
    const revised = new Set(['script/outfit_drop/qualify-sphinx-airdrop.js', 'script/outfit_drop/propose-sphinx-airdrop.js']);
    for (const [file, hash] of Object.entries(old.sourceSha256)) {
        assert.equal(sha256(fs.readFileSync(path.join(seed.sourceDirectory, file))), hash, 'Archived calibration source differs.');
        if (!revised.has(file)) assert.equal(sourceSha256[file], hash, 'Calibration dependency changed; measure again.');
    }
    return { old, provenance: { reportFile: path.resolve(seed.reportFile), reportSha256: sha256(bytes),
        inputsSha256: sha256(inputBytes), inputIdentity: inputs.inputIdentity,
        sourceDirectory: path.resolve(seed.sourceDirectory), sourceSha256: old.sourceSha256 } };
}

async function qualifyProfile(entries, preparedChains, reportDirectory, calibrationSeed) {
    assert(Array.isArray(entries) && entries.length > 0 && entries.length <= 4, 'Qualify one network profile at a time.');
    assert.equal(new Set(entries.map(entry => String(entry.networkConfig.chainId))).size, entries.length, 'Repeated chain.');
    fs.mkdirSync(reportDirectory, { recursive: true });
    const reportFile = path.join(reportDirectory, 'qualification.json');
    assert(!fs.existsSync(reportFile), 'Preserve earlier qualification; use a new report directory.');
    const sourceFiles = ['script/outfit_drop/qualify-sphinx-airdrop.js', 'script/outfit_drop/propose-sphinx-airdrop.js',
        'script/outfit_drop/simulate-safe-airdrop.js', 'script/outfit_drop/export-safe-airdrop.js', 'script/outfit_drop/generate-v6-airdrop.js',
        'node_modules/@sphinx-labs/core/dist/actions/execute.js', 'node_modules/@sphinx-labs/core/dist/networks.js',
        'node_modules/@sphinx-labs/core/dist/tasks/index.js', 'node_modules/@sphinx-labs/contracts/dist/merkle-tree.js',
        'node_modules/@sphinx-labs/contracts/contract-artifacts/sphinx/SphinxModule.sol/SphinxModule.json'];
    const report = { startedAt: new Date().toISOString(), status: 'running', localForkOnly: true,
        sourceSha256: Object.fromEntries(sourceFiles.map(file => [file, sha256(fs.readFileSync(path.join(ROOT, file)))])),
        chains: entries.map(() => ({})), segments: [],
        limitations: 'Local Osaka EVM qualification. Arbitrum proof excludes Nitro posting fees and Nitro-specific execution behavior. Hosted executor must preserve the submitted signed actions and supported SDK batching policy.' };
    const save = () => fs.writeFileSync(reportFile, `${JSON.stringify(report, null, 2)}\n`);
    const contexts = [];
    save();
    try {
        await allContexts(entries, async (entry, index) => {
            const context = await openContext(entry, preparedChains.find(chain => String(chain.chainId) === String(entry.networkConfig.chainId)), report.chains[index]);
            contexts.push(context); save();
        });
        contexts.sort((a, b) => entries.findIndex(entry => String(entry.networkConfig.chainId) === String(a.config.chainId))
            - entries.findIndex(entry => String(entry.networkConfig.chainId) === String(b.config.chainId)));
        const proofDepth = Math.ceil(Math.log2(entries.reduce((sum, entry) => sum + entry.networkConfig.actionInputs.length + 1, 0)));
        const provisional = contexts.map(context => ({ ...context.config, actionInputs: context.config.actionInputs.map(action =>
            ({ ...action, gas: probeAllowance(context.config, action, proofDepth) })) }));
        const provisionalTree = treeOf(provisional);
        report.provisionalRoot = provisionalTree.root; save();
        let measurements;
        if (calibrationSeed) {
            const seed = readCalibrationSeed(calibrationSeed, reportDirectory, report.sourceSha256);
            measurements = validateSeedCalibration(seed.old, provisional, provisionalTree, report.chains);
            report.calibrationReuse = seed.provenance;
            for (const [index, context] of contexts.entries()) context.report.calibration = seed.old.chains[index].calibration;
            save();
        } else {
            measurements = await allContexts(contexts, async context => {
                const config = provisional.find(item => item.chainId === context.config.chainId);
                const actions = await executeRoot(context, config, provisionalTree, 'cold', context.report.calibration, save, false);
                assert(await context.provider.send('evm_revert', [context.initialSnapshot]), 'Cannot restore pre-calibration state.');
                return actions;
            });
        }
        const calibrated = contexts.map((context, chainIndex) => {
            context.report.allowances = measurements[chainIndex].map(measured => ({ index: measured.index,
                actionDigest: measured.actionDigest, grossSafeGas: measured.grossSafeGas,
                ...qualifiedAllowance(measured.grossSafeGas, measured.signedGas) }));
            return { ...context.config, actionInputs: context.config.actionInputs.map((action, index) =>
                ({ ...action, gas: context.report.allowances[index].signedGas })) };
        });
        save();
        for (const [index, config] of calibrated.entries()) assert.deepEqual(config.actionInputs.map(actionDigest),
            contexts[index].config.actionInputs.map(actionDigest), 'Calibration changed canonical action bytes or order.');
        const segments = packSegments(calibrated, proofDepth);
        report.segments = segments.map((segment, index) => ({ index, root: segment.merkleTree.root,
            chains: segment.networkConfigs.map(config => ({ chainId: config.chainId, moduleNonce: config.nonce,
                actions: config.actionInputs.map(action => ({ digest: actionDigest(action), signedGas: action.gas })) })) }));
        save();
        for (const [index, segment] of segments.entries()) {
            await allContexts(contexts.filter(context => segment.networkConfigs.some(config => config.chainId === context.config.chainId)), async context => {
                const config = segment.networkConfigs.find(item => item.chainId === context.config.chainId);
                const snapshot = await context.provider.send('evm_snapshot', []);
                const records = [];
                context.report.final.push({ segment: index, root: segment.merkleTree.root, records }); save();
                await executeRoot(context, config, segment.merkleTree, 'cold', records, save);
                if (config.actionInputs.length > 1) {
                    assert(await context.provider.send('evm_revert', [snapshot]), 'Cannot restore pre-segment state.');
                    await executeRoot(context, config, segment.merkleTree, 'full-part', records, save);
                }
            });
        }
        await allContexts(contexts, async context => {
            for (const envelope of context.prepared.envelopes.filter(item => item.stage === 'migration')) {
                await verifyRecipients(context.provider, envelope, migrationPlan(envelope, context.plans));
            }
            context.report.recipientsAndOutfitsVerified = true;
            context.report.tokenCount = context.prepared.envelopes.reduce((sum, envelope) => sum + envelope.expectedTokenIds.length, 0);
            context.report.finalModuleNonce = (await context.module.merkleRootNonce()).toString();
            const segmentCount = segments.filter(segment => segment.networkConfigs.some(config => config.chainId === context.config.chainId)).length;
            assert.equal(context.report.finalModuleNonce, (BigInt(context.config.nonce) + BigInt(segmentCount)).toString(), 'Final module nonce differs from the qualified segment sequence.');
            context.report.status = 'passed'; save();
        });
        // Do not certify a run whose local implementation changed while its forks were executing.
        for (const [file, hash] of Object.entries(report.sourceSha256)) assert.equal(sha256(fs.readFileSync(path.join(ROOT, file))), hash, 'Qualification source changed during execution.');
        report.status = 'passed'; report.finishedAt = new Date().toISOString(); save();
        return { segments, report };
    } catch (error) {
        report.status = 'failed'; report.error = safeError(error); report.finishedAt = new Date().toISOString(); save();
        throw new Error(report.error);
    } finally {
        for (const context of contexts) { context.provider.removeAllListeners(); context.child.kill(); }
    }
}

module.exports = { qualifyProfile, actionDigest, outerBudget, worstProofLeaf, probeAllowance, coldAllowance, qualifiedAllowance, assertHeadroom,
    packSegments, safeFrames, measureSafeFrame, moduleEvents, assertActionEvents, captureFailure, validatePrepared, validateSeedCalibration, readCalibrationSeed };
