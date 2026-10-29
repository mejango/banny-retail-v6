'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { gasProofPolicyForChain, selectGasProofPolicy, assertGasProofPolicyWindow,
    assertGasProofEngineIdentity, usesStateGasReservoir } = require('./gas-proof-policy');
const bytes = fs.readFileSync(path.join(__dirname, 'gas-proof-policy.json'));
const fixture = JSON.parse(bytes);
const timestamp = 1793290000;
const rpcConfig = chainId => structuredClone(fixture.forks[chainId].rpcConfig);
const select = (chainId, overrides = {}) => selectGasProofPolicy({ chainId, finalizedTimestamp: timestamp,
    replayEndTimestamp: timestamp + 3600, rpcConfig: rpcConfig(chainId), ...overrides });

test('proof backend is selected by reviewed chain identity before any RPC result', () => {
    for (const chainId of [10, 11155111, 11155420, 42161, 421614, 84532]) {
        const expected = gasProofPolicyForChain(chainId);
        assert.equal(expected.backend, 'live-rpc');
        assert.equal(selectGasProofPolicy({ chainId, finalizedTimestamp: timestamp }).backend, 'live-rpc');
    }
    for (const [chainId, hardfork] of [[1, 'osaka'], [8453, 'base:Cobalt']]) {
        const selected = select(chainId);
        assert.equal(selected.backend, 'exact-root-fork');
        assert.equal(selected.hardfork, hardfork);
        assert.equal(selected.engine.release, 'v1.8.6');
        assert.equal(selected.engine.tagCommit, '6bad0a66de7c83f7b33695044138f0f5fa4c5990');
        assert.equal(selected.policySha256, createHash('sha256').update(bytes).digest('hex'));
        assert.equal(selected.validUntil, fixture.reviewExpiresAt);
    }
    for (const chainId of [0, -1, 5, 137, 1.5, NaN, Infinity, undefined, null, true, {}]) {
        assert.throws(() => gasProofPolicyForChain(chainId), /Invalid|No reviewed/);
    }
});

test('fork proof rejects missing RPC configuration and every current configuration drift', () => {
    for (const chainId of [1, 8453]) {
        for (const mutate of [
            config => { config.current.forkId = '0x00000000'; },
            config => { config.current.chainId = '0x2'; },
            config => { config.current.activationTime++; },
            config => { config.current.blobSchedule.max++; },
            config => { delete config.current.precompiles.P256VERIFY; },
            config => { config.current.precompiles.unknown = '0x0000000000000000000000000000000000000001'; },
            config => { delete config.current.systemContracts.HISTORY_STORAGE_ADDRESS; },
            config => { config.next = null; config.last = {}; },
            config => { config.unreviewed = true; },
        ]) {
            const config = rpcConfig(chainId);
            mutate(config);
            assert.throws(() => select(chainId, { rpcConfig: config }), /eth_config differs/);
        }
        assert.throws(() => select(chainId, { rpcConfig: undefined }), /eth_config differs/);
    }
    const base = rpcConfig(8453);
    delete base.current.precompiles.ActivationRegistry;
    assert.throws(() => select(8453, { rpcConfig: base }), /eth_config differs/);
    const next = rpcConfig(8453);
    next.next.activationTime++;
    assert.throws(() => select(8453, { rpcConfig: next }), /eth_config differs/);
});

test('fork window includes its reviewed activation and rejects expiration or crossing', () => {
    for (const chainId of [1, 8453]) {
        const selected = gasProofPolicyForChain(chainId);
        assert.equal(select(chainId, { finalizedTimestamp: selected.validFrom,
            replayEndTimestamp: selected.validFrom }).validFrom, selected.validFrom);
        for (const bad of [selected.validFrom - 1, selected.validUntil, selected.validUntil + 1, undefined, NaN, 1.5]) {
            assert.throws(() => assertGasProofPolicyWindow(selected, bad), /timestamp|window/);
        }
        assert.throws(() => select(chainId, { replayEndTimestamp: selected.validUntil }), /window/);
        assert.throws(() => select(chainId, { replayEndTimestamp: timestamp - 1 }), /before its finalized pin/);
        assert.throws(() => assertGasProofPolicyWindow({ ...selected, hardfork: 'latest' }, timestamp), /identity changed/);
        assert.throws(() => assertGasProofPolicyWindow({ ...selected, validUntil: selected.validUntil + 1 }, timestamp), /identity changed/);
    }
});

test('reviewed Ethereum BPO2 configuration stays distinct from its Osaka engine', () => {
    assert.equal(fixture.forks[1].rpcConfig.current.forkId, '0x07c9462e');
    assert.equal(fixture.forks[1].rpcConfig.current.activationTime, 1767747671);
    assert.equal(fixture.forks[1].rpcConfig.current.blobSchedule.max, 21);
    assert.equal(fixture.forks[8453].rpcConfig.current.forkId, '0x68647e86');
    assert.equal(fixture.forks[8453].rpcConfig.next.forkId, '0x169d85a3');
    assert.equal(fixture.forks[8453].rpcConfig.next.activationTime, fixture.reviewExpiresAt);
});

test('Sepolia reservoir predicate preserves existing activation and excludes production chains', () => {
    const activation = fixture.sepoliaStateGasActivation;
    assert.equal(usesStateGasReservoir(11155111, activation - 1), false);
    assert.equal(usesStateGasReservoir('11155111', activation), true);
    assert.equal(usesStateGasReservoir(11155111, activation + 1), true);
    for (const chainId of [1, 10, 8453, 42161, 11155420, 421614, 84532]) {
        assert.equal(usesStateGasReservoir(chainId, activation + 1), false);
    }
    for (const bad of [undefined, NaN, Infinity, String(activation), activation + 0.5]) {
        assert.equal(usesStateGasReservoir(11155111, bad), false);
    }
});

test('fork engine trust rejects unreviewed binary hashes, platforms and version identities', () => {
    const selected = select(1);
    const actual = { platform: 'darwin', arch: 'arm64', release: 'v1.8.6',
        tagCommit: fixture.engine.tagCommit,
        binarySha256: fixture.engine.platforms['darwin-arm64'].binarySha256 };
    assert.deepEqual(assertGasProofEngineIdentity(selected, actual), fixture.engine.platforms['darwin-arm64']);
    for (const changed of [{ platform: 'linux' }, { arch: 'x64' }, { release: 'v1.6.0' },
        { tagCommit: '0'.repeat(40) }, { binarySha256: '0'.repeat(64) }]) {
        assert.throws(() => assertGasProofEngineIdentity(selected, { ...actual, ...changed }), /reviewed/);
    }
    selected.engine.platforms['darwin-arm64'].binarySha256 = '0'.repeat(64);
    assert.throws(() => assertGasProofEngineIdentity(selected, actual), /identity changed/);
    assert.equal(gasProofPolicyForChain(1).engine.platforms['darwin-arm64'].binarySha256, actual.binarySha256);
    assert.throws(() => assertGasProofEngineIdentity(gasProofPolicyForChain(11155111), actual), /Only fork proofs/);
});
