#!/usr/bin/env node

// Upstream RPCs are read-only. Every approval and execution uses our newly spawned loopback fork.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { ethers } = require('ethers');
const utils = require('@sphinx-labs/plugins/dist/foundry/utils');
const { decodeDeploymentInfo, makeNetworkConfig } = require('@sphinx-labs/plugins/dist/foundry/decode');
const { makeDeploymentData } = require('@sphinx-labs/core');
const { makeSphinxMerkleTree, SphinxLeafType } = require('@sphinx-labs/contracts');
const { NETWORKS, readArtifact } = require('./export-safe-airdrop');
const { buildContractsByChain, loadRawItems } = require('./generate-v6-airdrop');
const { startFork, receiptFor, impersonate, failureTrace, gasBudget, verifyRecipients } = require('./simulate-safe-airdrop');

async function main() {
    const [collectionFile, blockText, reportFile] = process.argv.slice(2);
    assert(collectionFile && reportFile && /^\d+$/.test(blockText || ''),
        'Usage: node diagnose-sphinx-airdrop.js COLLECTION_JSON PINNED_BLOCK REPORT_JSON');
    const blockNumber = Number(blockText);
    assert(Number.isSafeInteger(blockNumber) && blockNumber > 0);
    const source = fs.readFileSync(collectionFile, 'utf8');
    const info = decodeDeploymentInfo(source, utils.readInterface('out', 'SphinxPluginTypes'), blockNumber);
    const chainId = Number(info.chainId);
    const network = Object.values(NETWORKS).flat().find(entry => entry.chainId === chainId);
    assert(network && process.env[network.rpc], 'Set the collected chain RPC environment variable.');
    const config = makeNetworkConfig(info, true, {}, []);
    const tree = makeSphinxMerkleTree(makeDeploymentData([config]));
    const report = { startedAt: new Date().toISOString(), localForkOnly: true, status: 'running', chainId,
        blockNumber, collectionSha256: createHash('sha256').update(source).digest('hex'), root: tree.root,
        safe: info.safeAddress, module: info.moduleAddress, actions: [] };
    const save = () => fs.writeFileSync(path.resolve(reportFile), `${JSON.stringify(report, null, 2)}\n`);
    save();
    const { child, provider } = await startFork(process.env[network.rpc], chainId, blockNumber, { budgeted: true });
    try {
        assert(new URL(provider.connection.url).hostname === '127.0.0.1', 'Local writes require our loopback fork.');
        report.blockHash = (await provider.getBlock(blockNumber)).hash;
        const safe = new ethers.Contract(info.safeAddress,
            ['function getOwners() view returns(address[])', 'function getThreshold() view returns(uint256)',
                'function nonce() view returns(uint256)', 'function approveHash(bytes32)',
                'function isModuleEnabled(address) view returns(bool)'], provider);
        const artifact = require('@sphinx-labs/contracts/contract-artifacts/sphinx/SphinxModule.sol/SphinxModule.json');
        const module = new ethers.Contract(info.moduleAddress, artifact.abi, provider);
        const relay = new ethers.utils.Interface(['function exec(address,bytes)']);
        assert(await safe.isModuleEnabled(module.address), 'Collected module is not enabled on this Safe.');
        assert.equal(await module.safeProxy(), safe.address);
        assert.equal((await module.merkleRootNonce()).toString(), info.nonce, 'Collected module nonce changed.');
        assert.equal(await module.activeMerkleRoot(), ethers.constants.HashZero, 'An existing root is active.');
        const safeNonce = (await safe.nonce()).toString();
        const threshold = (await safe.getThreshold()).toNumber();
        const owners = [...await safe.getOwners()].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())).slice(0, threshold);
        assert.equal(owners.length, threshold);
        assert(owners.length > 0);
        for (const owner of owners) await impersonate(provider, owner);
        const digest = ethers.utils._TypedDataEncoder.hash({ name: 'Sphinx', version: await module.VERSION() },
            { MerkleRoot: [{ name: 'root', type: 'bytes32' }] }, { root: tree.root });
        for (const owner of owners) {
            const receipt = await receiptFor(provider, { from: owner, to: safe.address,
                data: safe.interface.encodeFunctionData('approveHash', [digest]), gas: '0x186a0' });
            assert.equal(receipt.status, 1, 'Local owner hash approval failed.');
        }
        const signatures = ethers.utils.hexConcat(owners.map(owner => ethers.utils.solidityPack(
            ['bytes32', 'bytes32', 'uint8'], [ethers.utils.hexZeroPad(owner, 32), ethers.constants.HashZero, 1])));
        const outerGas = gasBudget(chainId, info.blockGasLimit).budget;
        const send = data => receiptFor(provider, { from: owners[0], to: info.executorAddress,
            data: relay.encodeFunctionData('exec', [module.address, data]), gas: ethers.utils.hexValue(outerGas) });
        const approval = tree.leavesWithProofs.find(entry => entry.leaf.leafType === SphinxLeafType.APPROVE);
        assert.equal((await send(module.interface.encodeFunctionData('approve', [tree.root, approval, signatures]))).status, 1,
            'Local relay/module root approval failed.');
        assert.equal(await module.activeMerkleRoot(), tree.root);
        report.outerGasBudget = outerGas;
        for (const leaf of tree.leavesWithProofs.filter(entry => entry.leaf.leafType === SphinxLeafType.EXECUTE)) {
            const action = config.actionInputs[Number(leaf.leaf.index) - 1];
            const receipt = await send(module.interface.encodeFunctionData('execute', [[leaf]]));
            const events = receipt.logs.filter(log => log.address.toLowerCase() === module.address.toLowerCase())
                .map(log => module.interface.parseLog(log)).map(event => ({ name: event.name,
                    index: event.args[1]?.toString() }));
            const state = await module.merkleRootStates(tree.root);
            const record = { index: String(leaf.leaf.index), to: action.to, selector: action.txData.slice(0, 10),
                operation: action.operation, signedGas: action.gas, outerReceiptStatus: receipt.status,
                receiptGasUsed: receipt.gasUsed.toString(), events, rootStatus: Number(state.status),
                activeRoot: await module.activeMerkleRoot() };
            report.actions.push(record); save();
            console.log(`Leaf ${record.index}: receipt=${receipt.status}, root=${record.rootStatus}, gas=${record.receiptGasUsed}`);
            if (receipt.status !== 1 || Number(state.status) === 4) {
                report.status = 'action-failed'; report.firstFailureIndex = record.index;
                save();
                try { record.innerFailures = await failureTrace(provider, receipt.transactionHash); }
                catch (error) { record.traceError = error.code || 'Local trace unavailable'; }
                save(); break;
            }
            assert(events.some(event => event.name === 'SphinxActionSucceeded'), 'Missing action success event.');
        }
        if (report.status === 'running') {
            assert.equal(Number((await module.merkleRootStates(tree.root)).status), 2, 'Root did not complete.');
            report.status = 'collected-module-actions-passed';
        }
        // Bind original helper creation bytes to the same generator/final ownership checks as the Safe rehearsal.
        const sourceChainId = network.sourceChainId;
        const plans = Object.values(buildContractsByChain(loadRawItems())).flat().filter(plan => plan.chain.id === sourceChainId);
        const sourceHashes = new Map();
        report.migrations = [];
        for (const access of info.accountAccesses.filter(entry => String(entry.root.kind) === '4')) {
            const plan = plans.find(candidate => access.root.data.startsWith(readArtifact(candidate, undefined, sourceHashes).bytecode.object));
            assert(plan, 'Collected creation is not a current original airdrop helper.');
            const migration = config.actionInputs.find(action => action.to.toLowerCase() === access.root.account.toLowerCase()
                && action.txData.startsWith(ethers.utils.id('executeMigration(address,address,address,address,address,bool)').slice(0, 10)));
            assert(migration, 'Missing original helper migration call.');
            const [hook, resolver] = ethers.utils.defaultAbiCoder.decode(
                ['address', 'address', 'address', 'address', 'address', 'bool'], `0x${migration.txData.slice(10)}`);
            const nft = new ethers.Contract(hook, ['function balanceOf(address) view returns(uint256)'], provider);
            const outcome = { contractName: plan.contractName, helper: access.root.account,
                expectedNfts: plan.assignments.expectedTokenIds.length,
                helperBalance: (await nft.balanceOf(access.root.account)).toString() };
            if (report.status === 'collected-module-actions-passed') {
                await verifyRecipients(provider, { hook, resolver, helper: access.root.account }, plan);
                outcome.recipientsAndOutfitsVerified = true;
            }
            report.migrations.push(outcome);
        }
        assert.equal((await safe.nonce()).toString(), safeNonce, 'Module path changed ordinary Safe nonce.');
        report.safeNonce = safeNonce;
    } catch (error) {
        report.status = 'diagnostic-error';
        report.error = error.code ? `RPC or local transaction error (${error.code})` : error.message;
        throw error;
    } finally {
        report.finishedAt = new Date().toISOString(); save(); child.kill();
    }
    console.log(`Wrote ${path.resolve(reportFile)}; all writes occurred only on the local fork.`);
    if (report.status === 'action-failed') process.exitCode = 1;
}

if (require.main === module) main().catch(error => {
    console.error(error.code ? `RPC or local transaction error (${error.code})` : error.message);
    process.exitCode = 1;
});
