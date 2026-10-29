'use strict';

// Reviewed chain rules select the proof before execution, never after an RPC failure.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const policyBytes = fs.readFileSync(path.join(__dirname, 'gas-proof-policy.json'));
const policy = JSON.parse(policyBytes);
const policySha256 = createHash('sha256').update(policyBytes).digest('hex');

function chainNumber(chainId) {
    assert(typeof chainId === 'number' || typeof chainId === 'string', 'Invalid gas-proof chain ID');
    const number = Number(chainId);
    assert(Number.isSafeInteger(number) && number > 0, 'Invalid gas-proof chain ID');
    return number;
}

function gasProofPolicyForChain(chainId) {
    const number = chainNumber(chainId);
    const fork = policy.forks[number];
    assert(fork || policy.liveRpcChainIds.includes(number), `No reviewed gas-proof policy for chain ${number}`);
    if (!fork) return { chainId: number, backend: 'live-rpc', policySha256 };
    // ETH BPO2 changes the blob schedule while the execution engine remains Osaka.
    // Base's next known activation and the explicit review expiry both bound use.
    return {
        chainId: number,
        backend: 'exact-root-fork',
        policySha256,
        hardfork: fork.hardfork,
        validFrom: fork.rpcConfig.current.activationTime,
        validUntil: Math.min(policy.reviewExpiresAt, fork.rpcConfig.next?.activationTime ?? Infinity),
        engine: structuredClone(policy.engine),
    };
}

function assertGasProofPolicyWindow(selected, timestamp) {
    const reviewed = gasProofPolicyForChain(selected.chainId);
    assert.deepEqual(selected, reviewed, 'Gas-proof policy identity changed');
    assert(Number.isSafeInteger(timestamp) && timestamp > 0, 'Gas-proof timestamp must be a positive integer');
    if (reviewed.backend === 'exact-root-fork') {
        assert(timestamp >= reviewed.validFrom && timestamp < reviewed.validUntil,
            `Chain ${reviewed.chainId} is outside the reviewed fork-proof window`);
    }
    return reviewed;
}

function selectGasProofPolicy({ chainId, finalizedTimestamp, replayEndTimestamp = finalizedTimestamp, rpcConfig }) {
    const selected = gasProofPolicyForChain(chainId);
    assertGasProofPolicyWindow(selected, finalizedTimestamp);
    assertGasProofPolicyWindow(selected, replayEndTimestamp);
    assert(replayEndTimestamp >= finalizedTimestamp, 'Gas-proof replay ends before its finalized pin');
    if (selected.backend === 'exact-root-fork') {
        // Require the complete current/next/last configuration, including Base's
        // native precompiles. A fork ID or a guessed hardfork name is insufficient.
        assert.deepEqual(rpcConfig, policy.forks[selected.chainId].rpcConfig,
            `Chain ${selected.chainId} eth_config differs from the reviewed fork policy`);
    }
    return selected;
}

function assertGasProofEngineIdentity(selected, identity) {
    const reviewed = gasProofPolicyForChain(selected.chainId);
    assert.deepEqual(selected, reviewed, 'Gas-proof policy identity changed');
    assert.equal(reviewed.backend, 'exact-root-fork', 'Only fork proofs use the reviewed execution engine');
    const trusted = reviewed.engine.platforms[`${identity.platform}-${identity.arch}`];
    assert(trusted, 'No reviewed fork engine for this platform');
    assert.equal(identity.release, reviewed.engine.release, 'Fork engine release differs from reviewed policy');
    assert.equal(identity.tagCommit, reviewed.engine.tagCommit, 'Fork engine commit differs from reviewed policy');
    assert.equal(identity.binarySha256, trusted.binarySha256, 'Fork engine binary differs from reviewed policy');
    return trusted;
}

// Existing Geth Sepolia schedule, pinned at d68cf359f9876a58fa41c1beab28cd05bc9df9a0.
function usesStateGasReservoir(chainId, timestamp) {
    return Number(chainId) === 11155111 && Number.isSafeInteger(timestamp)
        && timestamp >= policy.sepoliaStateGasActivation;
}

module.exports = { gasProofPolicyForChain, selectGasProofPolicy, assertGasProofPolicyWindow,
    assertGasProofEngineIdentity, usesStateGasReservoir };
