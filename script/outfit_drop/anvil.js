'use strict';

const { spawn } = require('node:child_process');

/**
 * Every local Anvil these scripts use starts here. Unpruned, Anvil writes block states to
 * ~/.foundry/anvil/tmp and leaves them behind when stopped. Pruning keeps the newest 500 states
 * in memory (Anvil's default) and writes none to disk; traces only replay just-mined transactions.
 */
function spawnAnvil(args, { stdio = 'ignore', binary = 'anvil' } = {}) {
    return spawn(binary, [...args, '--prune-history', '500'], { stdio });
}

module.exports = { spawnAnvil };
