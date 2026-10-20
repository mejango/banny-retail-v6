'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawnAnvil } = require('./anvil');

test('local Anvil writes no block state to disk and keeps recent history', async () => {
    const server = net.createServer();
    await new Promise((resolve, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolve));
    const { port } = server.address();
    await new Promise(resolve => server.close(resolve));
    // Unpruned, Anvil writes hundreds of states into the cache path for 1,000 blocks.
    const cache = fs.mkdtempSync(path.join(os.tmpdir(), 'anvil-cache-'));
    const child = spawnAnvil(['--host', '127.0.0.1', '--port', String(port), '--cache-path', cache, '--silent']);
    const stopped = new Promise(resolve => { child.once('exit', resolve); child.once('error', resolve); });
    const stop = async () => { if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL'); await stopped; };
    const rpc = async (method, params = []) => (await fetch(`http://127.0.0.1:${port}`, { method: 'POST',
        headers: { 'content-type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) })).json();
    try {
        for (let attempt = 0; attempt < 100; attempt++) {
            try { await rpc('eth_chainId'); break; } catch { await new Promise(resolve => setTimeout(resolve, 30)); }
        }
        assert.equal((await rpc('anvil_mine', ['0x3e8'])).result, null);
        // Bare --prune-history would keep no history at all.
        assert.equal(typeof (await rpc('eth_getBalance', ['0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', '0x258'])).result, 'string');
        await stop();
        assert.deepEqual(fs.readdirSync(cache, { recursive: true }), []);
    } finally {
        await stop();
        fs.rmSync(cache, { recursive: true, force: true });
    }
});

test('outfit-drop scripts start Anvil only through the helper', () => {
    const direct = fs.readdirSync(__dirname).filter(file => file.endsWith('.js') && !['anvil.js', 'anvil.test.js'].includes(file))
        .filter(file => /spawn(Sync)?\(\s*['"]anvil['"]/.test(fs.readFileSync(path.join(__dirname, file), 'utf8')));
    assert.deepEqual(direct, []);
});
