#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const {
    buildContractsByChain,
    CHAINS,
    itemOwner,
    itemProductName,
    itemTokenId,
    loadRawItems,
} = require('./generate-v6-airdrop');

const REPORT_DIR = path.join(__dirname, 'reports');
const REPORT_PATH = path.join(REPORT_DIR, 'v6-airdrop-recipient-safety.csv');
const ERC721_RECEIVED_SELECTOR = '0x150b7a02';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const RPC_ENV_BY_CHAIN_ID = {
    1: 'RPC_ETHEREUM_MAINNET',
    10: 'RPC_OPTIMISM_MAINNET',
    8453: 'RPC_BASE_MAINNET',
    42161: 'RPC_ARBITRUM_MAINNET',
};

function loadDotEnv() {
    const envPath = path.join(__dirname, '..', '..', '.env');
    if (!fs.existsSync(envPath)) return;

    const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
    lines.forEach(line => {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) return;

        const match = trimmed.match(/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
        if (!match) return;

        const [, key, rawValue] = match;
        if (process.env[key]) return;

        let value = rawValue.trim();
        if (
            (value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))
        ) {
            value = value.slice(1, -1);
        }
        process.env[key] = value;
    });
}

function normalizeAddress(address) {
    return String(address || '').toLowerCase();
}

function isZeroAddress(address) {
    return normalizeAddress(address) === ZERO_ADDRESS;
}

function padAddress(address) {
    return normalizeAddress(address).replace(/^0x/, '').padStart(64, '0');
}

function padUint(value) {
    return BigInt(value).toString(16).padStart(64, '0');
}

function encodeOnERC721ReceivedCall() {
    return [
        ERC721_RECEIVED_SELECTOR,
        padAddress(ZERO_ADDRESS),
        padAddress(ZERO_ADDRESS),
        padUint(1),
        padUint(128),
        padUint(0),
    ].join('');
}

function decodeStringResult(hex) {
    if (!hex || hex === '0x') return '';
    const data = hex.slice(2);
    if (data.length < 128) return '';

    const offset = Number.parseInt(data.slice(0, 64), 16);
    const lengthOffset = offset * 2;
    if (!Number.isFinite(offset) || data.length < lengthOffset + 64) return '';

    const length = Number.parseInt(data.slice(lengthOffset, lengthOffset + 64), 16);
    const stringStart = lengthOffset + 64;
    const stringHex = data.slice(stringStart, stringStart + length * 2);
    if (!Number.isFinite(length) || stringHex.length === 0) return '';

    return Buffer.from(stringHex, 'hex').toString('utf8');
}

function isPlausibleAddressArrayResult(hex) {
    if (!hex || hex === '0x') return false;
    const data = hex.slice(2);
    if (data.length < 128) return false;

    const offset = Number.parseInt(data.slice(0, 64), 16);
    if (offset !== 32) return false;

    const length = Number.parseInt(data.slice(64, 128), 16);
    if (!Number.isFinite(length) || length > 100) return false;

    return data.length >= 128 + length * 64;
}

function itemLabel(item) {
    const productName = itemProductName(item);
    const tokenId = itemTokenId(item);
    return productName ? `${productName} (V4 ${tokenId})` : `V4 ${tokenId}`;
}

function collectRecipients(contractsByChain) {
    const recipientsByChain = new Map();

    function chainRecipients(chain) {
        if (!recipientsByChain.has(chain.id)) {
            recipientsByChain.set(chain.id, new Map());
        }
        return recipientsByChain.get(chain.id);
    }

    function addReceipt({ chain, address, receiptType, label }) {
        if (!address || isZeroAddress(address)) return;

        const key = normalizeAddress(address);
        const recipients = chainRecipients(chain);
        if (!recipients.has(key)) {
            recipients.set(key, {
                chain,
                address,
                bodyReceipts: 0,
                directAssetReceipts: 0,
                labels: new Set(),
            });
        }

        const recipient = recipients.get(key);
        if (receiptType === 'body') {
            recipient.bodyReceipts++;
        } else if (receiptType === 'direct_asset') {
            recipient.directAssetReceipts++;
        }
        recipient.labels.add(label);
    }

    Object.values(contractsByChain).flat().forEach(contract => {
        const bannyByTokenId = new Map();
        contract.bannies.forEach(banny => {
            bannyByTokenId.set(Number(banny.tokenId), banny);
        });

        contract.transferItems.forEach(({ item, owner }) => {
            const tokenId = itemTokenId(item);
            const banny = bannyByTokenId.get(tokenId);

            addReceipt({
                chain: contract.chain,
                address: owner,
                receiptType: banny ? 'body' : 'direct_asset',
                label: banny ? `${banny.productName || 'Banny'} body V4 ${banny.tokenId}` : itemLabel(item),
            });
        });
    });

    return recipientsByChain;
}

function collectKnownLabels() {
    const labels = new Map();
    const deploymentRoot = path.join(__dirname, '..', '..', '..', 'deploy-all-v6', 'deployments');

    if (!fs.existsSync(deploymentRoot)) return labels;

    fs.readdirSync(deploymentRoot, { withFileTypes: true })
        .filter(entry => entry.isDirectory())
        .forEach(dir => {
            const chainDir = path.join(deploymentRoot, dir.name);
            fs.readdirSync(chainDir)
                .filter(file => file.endsWith('.json'))
                .forEach(file => {
                    try {
                        const artifact = JSON.parse(fs.readFileSync(path.join(chainDir, file), 'utf8'));
                        if (!artifact.address) return;
                        const key = `${dir.name}:${normalizeAddress(artifact.address)}`;
                        labels.set(key, file.replace(/\.json$/, ''));
                    } catch (_) {
                        // Ignore non-standard artifacts.
                    }
                });
        });

    return labels;
}

function deploymentFolderForChain(chainId) {
    if (chainId === 1) return 'ethereum';
    if (chainId === 10) return 'optimism';
    if (chainId === 8453) return 'base';
    if (chainId === 42161) return 'arbitrum';
    return '';
}

async function rpcBatch(rpcUrl, requests) {
    const response = await fetch(rpcUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(requests),
    });

    if (!response.ok) {
        throw new Error(`RPC HTTP ${response.status}`);
    }

    const body = await response.json();
    if (!Array.isArray(body)) {
        throw new Error('RPC endpoint did not return a batch response');
    }

    const results = new Map();
    body.forEach(result => {
        if (result.error) {
            throw new Error(result.error.message || 'RPC batch item failed');
        }
        results.set(result.id, result.result);
    });

    return requests.map(request => results.get(request.id));
}

async function rpcBatchWithFallback(rpcUrl, requests) {
    try {
        return await rpcBatch(rpcUrl, requests);
    } catch (_) {
        const results = [];
        for (const request of requests) {
            results.push((await rpcBatch(rpcUrl, [request]))[0]);
        }
        return results;
    }
}

async function rpcCall(rpcUrl, method, params) {
    const [result] = await rpcBatchWithFallback(rpcUrl, [{ jsonrpc: '2.0', id: 1, method, params }]);
    return result;
}

async function checkChainRecipients(chain, recipients, knownLabels) {
    const rpcEnv = RPC_ENV_BY_CHAIN_ID[chain.id];
    const rpcUrl = process.env[rpcEnv];
    if (!rpcUrl) {
        throw new Error(`${rpcEnv} is not set`);
    }

    const entries = Array.from(recipients.values());
    const codeRequests = entries.map((entry, index) => ({
        jsonrpc: '2.0',
        id: index + 1,
        method: 'eth_getCode',
        params: [entry.address, 'latest'],
    }));
    const codes = await rpcBatchWithFallback(rpcUrl, codeRequests);

    for (let i = 0; i < entries.length; i++) {
        entries[i].code = codes[i] || '0x';
        entries[i].isContract = entries[i].code !== '0x';
    }

    const contractEntries = entries.filter(entry => entry.isContract);
    const receiverData = encodeOnERC721ReceivedCall();

    for (const entry of contractEntries) {
        try {
            entry.onERC721ReceivedResult = await rpcCall(rpcUrl, 'eth_call', [
                { to: entry.address, data: receiverData },
                'latest',
            ]);
            entry.canReceiveERC721 =
                String(entry.onERC721ReceivedResult || '').slice(0, 10).toLowerCase() === ERC721_RECEIVED_SELECTOR;
        } catch (error) {
            entry.onERC721ReceivedResult = `reverted: ${error.message}`;
            entry.canReceiveERC721 = false;
        }

        try {
            const versionResult = await rpcCall(rpcUrl, 'eth_call', [{ to: entry.address, data: '0xffa1ad74' }, 'latest']);
            entry.safeVersion = decodeStringResult(versionResult);
        } catch (_) {
            entry.safeVersion = '';
        }

        try {
            const ownersResult = await rpcCall(rpcUrl, 'eth_call', [{ to: entry.address, data: '0xa0e67e2b' }, 'latest']);
            entry.isSafeLike = isPlausibleAddressArrayResult(ownersResult);
        } catch (_) {
            entry.isSafeLike = false;
        }

        const folder = deploymentFolderForChain(chain.id);
        entry.knownDeployment = knownLabels.get(`${folder}:${normalizeAddress(entry.address)}`) || '';
    }

    return entries;
}

function csvEscape(value) {
    const stringValue = value === null || value === undefined ? '' : String(value);
    if (/[",\r\n]/.test(stringValue)) {
        return `"${stringValue.replace(/"/g, '""')}"`;
    }
    return stringValue;
}

function writeReport(rows) {
    const headers = [
        'chain',
        'chain_id',
        'recipient_address',
        'recipient_kind',
        'can_receive_erc721',
        'contract_label',
        'safe_version',
        'body_receipts',
        'direct_asset_receipts',
        'total_receipts',
        'example_assets',
        'on_erc721_received_result',
    ];

    fs.mkdirSync(REPORT_DIR, { recursive: true });
    fs.writeFileSync(
        REPORT_PATH,
        `${headers.join(',')}\n${rows
            .map(row => headers.map(header => csvEscape(row[header])).join(','))
            .join('\n')}\n`,
    );
}

async function main() {
    loadDotEnv();

    const items = loadRawItems();
    const contractsByChain = buildContractsByChain(items);
    const recipientsByChain = collectRecipients(contractsByChain);
    const knownLabels = collectKnownLabels();
    const reportRows = [];
    const unsafe = [];
    let totalRecipients = 0;
    let totalContracts = 0;
    let totalReceipts = 0;

    for (const chain of CHAINS) {
        const recipients = recipientsByChain.get(chain.id) || new Map();
        const checked = await checkChainRecipients(chain, recipients, knownLabels);
        totalRecipients += checked.length;

        const chainContracts = checked.filter(entry => entry.isContract);
        totalContracts += chainContracts.length;
        totalReceipts += checked.reduce((sum, entry) => sum + entry.bodyReceipts + entry.directAssetReceipts, 0);

        checked.forEach(entry => {
            const contractLabel =
                entry.knownDeployment
                || (entry.safeVersion ? 'Safe wallet' : '')
                || (entry.isSafeLike ? 'Safe-like wallet' : '')
                || (entry.isContract ? 'ERC721 receiver-capable contract' : '');
            if (entry.isContract && !entry.canReceiveERC721) {
                unsafe.push(entry);
            }

            reportRows.push({
                chain: chain.name,
                chain_id: chain.id,
                recipient_address: entry.address,
                recipient_kind: entry.isContract ? 'contract' : 'EOA/no-code',
                can_receive_erc721: entry.isContract ? String(entry.canReceiveERC721) : 'n/a',
                contract_label: contractLabel,
                safe_version: entry.safeVersion || '',
                body_receipts: entry.bodyReceipts,
                direct_asset_receipts: entry.directAssetReceipts,
                total_receipts: entry.bodyReceipts + entry.directAssetReceipts,
                example_assets: Array.from(entry.labels).slice(0, 6).join('; '),
                on_erc721_received_result: entry.isContract ? entry.onERC721ReceivedResult : '',
            });
        });

        console.log(
            `${chain.name}: ${checked.length} unique recipients, ${chainContracts.length} contracts, ${
                chainContracts.filter(entry => entry.canReceiveERC721).length
            } ERC721 receiver-capable contracts.`,
        );
    }

    reportRows.sort((a, b) => {
        if (a.chain_id !== b.chain_id) return Number(a.chain_id) - Number(b.chain_id);
        return String(a.recipient_address).localeCompare(String(b.recipient_address));
    });
    writeReport(reportRows);

    console.log(`Checked ${totalRecipients} unique recipient addresses across ${totalReceipts} final transfers.`);
    console.log(`Contract recipients: ${totalContracts}. Unsafe contract recipients: ${unsafe.length}.`);
    console.log(`Wrote ${REPORT_PATH}`);

    if (unsafe.length > 0) {
        unsafe.forEach(entry => {
            console.error(
                `UNSAFE ${entry.chain.name} ${entry.address}: ${entry.bodyReceipts} bodies, ${entry.directAssetReceipts} direct assets`,
            );
        });
        process.exitCode = 1;
    }
}

main().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
});
