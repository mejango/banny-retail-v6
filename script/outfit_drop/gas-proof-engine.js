'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { assertGasProofEngineIdentity, gasProofPolicyForChain } = require('./gas-proof-policy');

function resolveBinary(binary, env) {
    assert(typeof binary === 'string' && binary.length > 0, 'Missing fork engine binary');
    let candidate;
    if (path.isAbsolute(binary) || binary.includes(path.sep)) candidate = path.resolve(binary);
    else {
        // The first existing PATH entry owns the decision, including broken symlinks
        // or non-executables. Never silently replace a preferred engine with another.
        for (const directory of (env.PATH || '').split(path.delimiter)) {
            const entry = path.resolve(directory || '.', binary);
            try { fs.lstatSync(entry); candidate = entry; break; }
            catch (error) { if (error.code !== 'ENOENT') throw error; }
        }
    }
    assert(candidate, 'Fork engine was not found on PATH');
    const real = fs.realpathSync(candidate);
    assert(fs.statSync(real).isFile(), 'Fork engine is not a regular file');
    fs.accessSync(real, fs.constants.R_OK | fs.constants.X_OK);
    return real;
}

function hashBinary(binary) {
    return createHash('sha256').update(fs.readFileSync(binary)).digest('hex');
}

function resolveGasProofEngine(selected, { binary = process.env.BANNY_AIRDROP_ANVIL || 'anvil', env = process.env } = {}) {
    const absolute = resolveBinary(binary, env);
    const binarySha256 = hashBinary(absolute);
    const machine = { platform: process.platform, arch: process.arch };
    // Authenticate bytes before invoking them. These expected version fields are
    // replaced by actual --version output and checked again below.
    assertGasProofEngineIdentity(selected, { ...machine, binarySha256,
        release: selected.engine?.release, tagCommit: selected.engine?.tagCommit });
    const version = execFileSync(absolute, ['--version'], { env, encoding: 'utf8', timeout: 5000,
        maxBuffer: 16 * 1024, stdio: ['ignore', 'pipe', 'pipe'] }).trim();
    const release = /^anvil Version: (\d+\.\d+\.\d+)$/m.exec(version);
    const commit = /^Commit SHA: ([a-f0-9]{40})$/m.exec(version);
    assert(release && commit, 'Fork engine version output is not recognized');
    const identity = { binary: absolute, binarySha256, ...machine,
        release: `v${release[1]}`, tagCommit: commit[1], version };
    assertGasProofEngineIdentity(selected, identity);
    assert.equal(hashBinary(absolute), binarySha256, 'Fork engine binary changed during version verification');
    return identity;
}

function assertGasProofEngineUnchanged(selected, identity) {
    assertGasProofEngineIdentity(selected, identity);
    assert(path.isAbsolute(identity.binary), 'Fork engine identity requires an absolute binary path');
    const actual = resolveGasProofEngine(selected, { binary: identity.binary });
    assert.deepEqual(actual, identity, 'Fork engine identity changed');
    return actual;
}

function assertGasProofNodeInfo(selected, nodeInfo, { chainId, blockNumber }) {
    assert.deepEqual(selected, gasProofPolicyForChain(selected.chainId), 'Gas-proof policy identity changed');
    const number = Number(chainId);
    const pin = Number(blockNumber);
    assert(Number.isSafeInteger(number) && number > 0 && number === selected.chainId, 'Fork engine chain differs from policy');
    assert(Number.isSafeInteger(pin) && pin >= 0, 'Invalid fork engine block pin');
    const base = selected.hardfork?.startsWith('base:');
    const hardfork = base ? selected.hardfork.slice('base:'.length) : selected.hardfork;
    assert(typeof hardfork === 'string' && hardfork.length > 0, 'Missing reviewed engine hardfork');
    assert.equal(nodeInfo.network, base ? 'base' : 'ethereum', 'Fork engine network differs from policy');
    assert.equal(nodeInfo.hardFork.toLowerCase(), hardfork.toLowerCase(), 'Fork engine hardfork differs from policy');
    assert.equal(nodeInfo.environment.chainId, number, 'Fork engine chain differs from pin');
    assert.equal(nodeInfo.forkConfig.forkBlockNumber, pin, 'Fork engine block differs from pin');
    // Never persist forkUrl: it can include provider credentials.
    return { network: nodeInfo.network, hardFork: nodeInfo.hardFork,
        environment: { chainId: number }, forkConfig: { forkBlockNumber: pin } };
}

function forkEngineOptions(selected, identity) {
    assertGasProofEngineIdentity(selected, identity);
    assert(path.isAbsolute(identity.binary), 'Fork engine identity requires an absolute binary path');
    return { binary: identity.binary, hardfork: selected.hardfork, noStorageCaching: true };
}

module.exports = { resolveGasProofEngine, assertGasProofEngineUnchanged, assertGasProofNodeInfo, forkEngineOptions };
