'use strict';

const { spawn } = require('node:child_process');

/** Every local Anvil these scripts use starts here. */
function spawnAnvil(args, { stdio = 'ignore' } = {}) {
    return spawn('anvil', args, { stdio });
}

module.exports = { spawnAnvil };
