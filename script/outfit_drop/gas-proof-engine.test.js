'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { gasProofPolicyForChain } = require('./gas-proof-policy');
const { resolveGasProofEngine, assertGasProofEngineUnchanged, assertGasProofNodeInfo,
    forkEngineOptions } = require('./gas-proof-engine');
const selected = gasProofPolicyForChain(1);
const identity = { binary: '/reviewed/anvil', platform: 'darwin', arch: 'arm64',
    release: selected.engine.release, tagCommit: selected.engine.tagCommit,
    binarySha256: selected.engine.platforms['darwin-arm64'].binarySha256, version: 'unused' };

function temporary(t) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-fork-engine-'));
    t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
    return directory;
}

test('an untrusted executable is never run, including through PATH', t => {
    const directory = temporary(t);
    const marker = path.join(directory, 'executed');
    const binary = path.join(directory, 'anvil');
    fs.writeFileSync(binary, `#!/bin/sh\ntouch '${marker}'\n`, { mode: 0o700 });
    for (const candidate of [binary, 'anvil']) {
        assert.throws(() => resolveGasProofEngine(selected,
            { binary: candidate, env: { PATH: directory } }), /reviewed/);
        assert.equal(fs.existsSync(marker), false);
    }
});

test('a broken preferred binary and broken first PATH entry never fall through', t => {
    const directory = temporary(t);
    const first = path.join(directory, 'first');
    const second = path.join(directory, 'second');
    fs.mkdirSync(first); fs.mkdirSync(second);
    fs.symlinkSync(path.join(directory, 'missing'), path.join(first, 'anvil'));
    fs.writeFileSync(path.join(second, 'anvil'), '#!/bin/sh\nexit 0\n', { mode: 0o700 });
    assert.throws(() => resolveGasProofEngine(selected,
        { binary: 'anvil', env: { PATH: `${first}${path.delimiter}${second}` } }), /ENOENT/);
    assert.throws(() => resolveGasProofEngine(selected,
        { binary: path.join(directory, 'missing'), env: { PATH: second } }), /ENOENT/);
    assert.throws(() => resolveGasProofEngine(selected, { binary: 'anvil', env: { PATH: '' } }), /not found/);
});

test('engine identity and fork options reject unreviewed versions, policy drift and relative paths', () => {
    assert.deepEqual(forkEngineOptions(selected, identity),
        { binary: identity.binary, hardfork: 'osaka', noStorageCaching: true });
    for (const changed of [{ release: 'v1.6.0' }, { tagCommit: '0'.repeat(40) },
        { binarySha256: '0'.repeat(64) }, { arch: 'x64' }]) {
        assert.throws(() => assertGasProofEngineUnchanged(selected, { ...identity, ...changed }), /reviewed/);
    }
    assert.throws(() => assertGasProofEngineUnchanged(selected,
        { ...identity, binary: 'anvil' }), /absolute/);
    assert.throws(() => forkEngineOptions({ ...selected, hardfork: 'latest' }, identity), /identity changed/);
});

test('actual node metadata binds engine network, hardfork, chain and finalized pin without leaking URL', () => {
    for (const [chainId, hardFork, network] of [[1, 'Osaka', 'ethereum'], [8453, 'Cobalt', 'base']]) {
        const policy = gasProofPolicyForChain(chainId);
        const node = { hardFork, network, environment: { chainId },
            forkConfig: { forkBlockNumber: 12345, forkUrl: 'https://secret.invalid/provider-key' } };
        const expected = { hardFork, network, environment: { chainId }, forkConfig: { forkBlockNumber: 12345 } };
        assert.deepEqual(assertGasProofNodeInfo(policy, node, { chainId, blockNumber: 12345 }), expected);
        for (const changed of [
            { hardFork: 'Amsterdam' }, { network: 'other' }, { environment: { chainId: 2 } },
            { forkConfig: { forkBlockNumber: 12346 } },
        ]) {
            assert.throws(() => assertGasProofNodeInfo(policy, { ...node, ...changed },
                { chainId, blockNumber: 12345 }), /differs/);
        }
        assert.throws(() => assertGasProofNodeInfo({ ...policy, hardfork: 'latest' }, node,
            { chainId, blockNumber: 12345 }), /identity changed/);
        assert.throws(() => assertGasProofNodeInfo(policy, node,
            { chainId: 2, blockNumber: 12345 }), /differs/);
    }
});

test('reviewed binary resolves to an absolute authenticated identity and remains unchanged',
    { skip: !process.env.BANNY_TEST_REVIEWED_ANVIL }, () => {
        const actual = resolveGasProofEngine(selected, { binary: process.env.BANNY_TEST_REVIEWED_ANVIL });
        assert(path.isAbsolute(actual.binary));
        assert.equal(actual.binarySha256, identity.binarySha256);
        assert.deepEqual(assertGasProofEngineUnchanged(selected, actual), actual);
        assert.throws(() => assertGasProofEngineUnchanged(selected,
            { ...actual, version: 'different version output' }), /identity changed/);
    });
