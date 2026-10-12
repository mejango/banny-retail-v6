#!/usr/bin/env node
'use strict';

// Real transaction receipts, including calldata and event costs. All writes stay on a fresh loopback Anvil.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const { spawn } = require('node:child_process');
const { ethers } = require('ethers');
const { gasBudget } = require('./simulate-safe-airdrop');

const ROOT = path.resolve(__dirname, '../..');
const { executionGasCap: CAP, budget: BUDGET } = gasBudget(1);

async function qualify(settingsFile, outputFile, imageFile) {
    const captured = JSON.parse(fs.readFileSync(settingsFile));
    const snapshot = captured.chains ? captured.chains[0] : captured;
    const settings = snapshot.settingsRaw || snapshot.settings;
    const assets = JSON.parse(fs.readFileSync(path.join(ROOT, 'test/fixtures/banny-svg-originals.json'))).assets;
    const artifact = JSON.parse(fs.readFileSync(path.join(ROOT, 'out/Banny721TokenUriResolver.sol/Banny721TokenUriResolver.json')));
    assert(ethers.utils.hexDataLength(artifact.deployedBytecode.object) <= 24_576, 'Resolver exceeds EIP-170');
    const server = net.createServer();
    await new Promise((resolve, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolve));
    const port = server.address().port;
    await new Promise(resolve => server.close(resolve));
    const child = spawn('anvil', ['--silent', '--host', '127.0.0.1', '--port', String(port),
        '--chain-id', '31337', '--hardfork', 'osaka', '--enable-tx-gas-limit', '--gas-limit', String(CAP)],
    { stdio: 'ignore' });
    let spawnError;
    child.on('error', error => { spawnError = error; });
    const provider = new ethers.providers.JsonRpcProvider(`http://127.0.0.1:${port}`);
    const report = { localOnly: true, hardfork: 'osaka', cap: CAP, budget: BUDGET, assets: [] };
    try {
        for (let attempt = 0; ; ++attempt) {
            if (spawnError) throw spawnError;
            try { await provider.getBlockNumber(); break; }
            catch (error) {
                if (attempt === 100 || child.exitCode !== null) throw new Error('Local Anvil did not start');
                await new Promise(resolve => setTimeout(resolve, 100));
            }
        }
        await provider.send('anvil_impersonateAccount', [settings.owner]);
        await provider.send('anvil_setBalance', [settings.owner, ethers.utils.hexValue(ethers.utils.parseEther('1000'))]);
        const owner = provider.getSigner(settings.owner);
        const publisher = provider.getSigner(1);
        const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode.object, owner);
        const args = ['bannyBody', 'defaultNecklace', 'defaultMouth', 'defaultStandardEyes', 'defaultAlienEyes']
            .map(field => settings[field]);
        const resolver = await factory.deploy(...args, settings.owner, settings.trustedForwarder, { gasLimit: BUDGET });
        const deployment = await resolver.deployTransaction.wait();
        assert.equal(deployment.status, 1);
        report.deploymentGas = deployment.gasUsed.toString();
        await (await resolver.setSvgHashesOf(assets.map(asset => asset.upc), assets.map(asset => asset.svgHash),
            { gasLimit: BUDGET })).wait();
        const store = new ethers.Contract(await resolver.SVG_STORAGE(),
            ['function read(uint256) view returns(bytes)', 'function WRITER() view returns(address)'], provider);
        assert.equal((await store.WRITER()).toLowerCase(), resolver.address.toLowerCase());
        for (const asset of assets) {
            const bytes = ethers.utils.toUtf8Bytes(asset.svgString);
            assert.equal(bytes.length, asset.bytes);
            assert.equal(ethers.utils.keccak256(bytes), asset.svgHash);
            assert.equal(asset.svgHash, snapshot.products.find(product => product.upc === asset.upc).hash,
                'Artwork does not match the observed collection commitment');
            const transaction = await resolver.connect(publisher).setSvgContentsOf([asset.upc], [asset.svgString],
                { gasLimit: BUDGET });
            const receipt = await transaction.wait();
            assert.equal(receipt.status, 1, `Failed publication UPC ${asset.upc}`);
            assert(receipt.gasUsed.lte(BUDGET), `Exceeded budget UPC ${asset.upc}`);
            assert.equal(await store.read(asset.upc), ethers.utils.hexlify(bytes), `Changed artwork UPC ${asset.upc}`);
            const event = receipt.logs.filter(log => log.address.toLowerCase() === resolver.address.toLowerCase())
                .map(log => resolver.interface.parseLog(log)).find(event => event.name === 'SetSvgContent');
            assert(event, 'Missing publication event');
            assert.equal(event.args.svgContent, asset.svgString);
            assert.equal(event.args.caller.toLowerCase(), (await publisher.getAddress()).toLowerCase());
            report.assets.push({ upc: asset.upc, name: asset.name, bytes: asset.bytes,
                hash: asset.svgHash, receiptGas: receipt.gasUsed.toString(), status: receipt.status });
            console.log(`UPC ${asset.upc}: ${asset.bytes} bytes, ${receipt.gasUsed} total gas, exact original verified`);
        }
        assert.equal(report.assets.length, 64);
        if (imageFile) {
            // The production resolver and original templates/art, with the existing test hook modelling ownership.
            const deployMock = async (name, args = []) => {
                const mock = JSON.parse(fs.readFileSync(path.join(ROOT, 'out/Banny721TokenUriResolver.t.sol', `${name}.json`)));
                const contract = await new ethers.ContractFactory(mock.abi, mock.bytecode.object, publisher).deploy(...args);
                await contract.deployTransaction.wait();
                return contract;
            };
            const mockStore = await deployMock('MockStore');
            const mockHook = await deployMock('MockHook', [mockStore.address]);
            const zero = input => input.type === 'tuple' ? Object.fromEntries(input.components.map(c => [c.name, zero(c)]))
                : input.type === 'bool' ? false : input.type === 'address' ? ethers.constants.AddressZero
                    : input.type === 'bytes32' ? ethers.constants.HashZero : input.type === 'string' ? '' : 0;
            const tierShape = mockStore.interface.getFunction('setTier').inputs[2];
            const outfits = [7_000_000_002, 17_000_000_001, 26_000_000_003, 46_000_000_001];
            const ids = [1_000_000_001, 5_000_000_001, ...outfits];
            const categories = { 1: 0, 5: 1, 7: 2, 17: 8, 26: 11, 46: 13 };
            for (const id of ids) {
                const upc = Math.floor(id / 1_000_000_000);
                const category = categories[upc];
                const tier = { ...zero(tierShape), id: upc, category };
                await (await mockStore.setTier(mockHook.address, id, tier)).wait();
                await (await mockHook.setTier(id, upc, category)).wait();
                await (await mockHook.setOwner(id, await publisher.getAddress())).wait();
            }
            await (await mockHook.setApprovalForAll(resolver.address, true)).wait();
            await (await resolver.connect(publisher).decorateBannyWith(mockHook.address, ids[0], ids[1], outfits)).wait();
            const images = [];
            for (const tokenId of ids.slice(0, 2)) {
                const uri = await resolver.tokenUriOf(mockHook.address, tokenId);
                const metadata = JSON.parse(Buffer.from(uri.split(',')[1], 'base64'));
                const categoryName = snapshot.products.find(p => p.upc === Math.floor(tokenId / 1_000_000_000)).category;
                if (categoryName !== undefined) assert.equal(metadata.categoryName, categoryName);
                const svg = Buffer.from(metadata.image.split(',')[1], 'base64').toString();
                assert(!svg.includes('<image href="'), 'Published artwork still contains external image references');
                images.push({ tokenId, image: metadata.image, svg });
            }
            fs.writeFileSync(imageFile, JSON.stringify({ mockOwnership: true, productionResolver: true, images }, null, 2) + '\n');
            report.imageSampleCount = images.length;
        }
        report.status = 'passed';
        report.maximumReceiptGas = Math.max(...report.assets.map(asset => Number(asset.receiptGas)));
        if (outputFile) fs.writeFileSync(outputFile, JSON.stringify(report, null, 2) + '\n');
        console.log(`All 64 originals passed; maximum total gas ${report.maximumReceiptGas}/${BUDGET}.`);
        return report;
    } finally {
        provider.removeAllListeners();
        child.kill();
    }
}

if (require.main === module) {
    const [settingsFile, outputFile, imageFile] = process.argv.slice(2);
    if (!settingsFile) throw new Error('Usage: node qualify-svg-publication.js SETTINGS_SNAPSHOT.json [REPORT.json] [IMAGES.json]');
    qualify(settingsFile, outputFile, imageFile).catch(error => { console.error(error.message); process.exitCode = 1; });
}

module.exports = { qualify, CAP, BUDGET };
