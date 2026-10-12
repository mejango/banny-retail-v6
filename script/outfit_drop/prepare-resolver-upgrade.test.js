'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { ethers } = require('ethers');
const { configurationHash, runtimeHash, storageBinding, deployment, deploymentTransaction } = require('./prepare-resolver-upgrade');
const settings = { owner: '0x1111111111111111111111111111111111111111',
    trustedForwarder: '0x2222222222222222222222222222222222222222', svgDescription: 'description',
    svgExternalUrl: 'url', svgBaseUri: 'base', bannyBody: 'body', defaultNecklace: 'necklace',
    defaultMouth: 'mouth', defaultStandardEyes: 'eyes', defaultAlienEyes: 'alien' };
const products = [{ upc: 1, hash: ethers.utils.id('art'), name: 'product', svgHash: ethers.utils.id('fallback') }];
test('configuration binds settings, names and commitments, independent of publication', () => {
    const baseline = configurationHash(settings, products, 1);
    for (const key of Object.keys(settings)) {
        const value = key === 'owner' || key === 'trustedForwarder' ? '0x3333333333333333333333333333333333333333' : 'changed';
        assert.notEqual(configurationHash({ ...settings, [key]: value }, products, 1), baseline);
    }
    for (const change of [{ hash: ethers.utils.id('different') }, { name: 'different' }]) {
        assert.notEqual(configurationHash(settings, [{ ...products[0], ...change }], 1), baseline);
    }
    assert.notEqual(configurationHash(settings, products, 2), baseline);
    assert.equal(configurationHash(settings, [{ ...products[0], svgHash: ethers.utils.id('published') }], 1), baseline);
});
test('runtime hash patches every forwarder reference and rejects new immutable layouts', () => {
    const compiled = { deployedBytecode: { object: `0x00${'00'.repeat(32)}ff${'00'.repeat(32)}`,
        immutableReferences: { 123: [{ start: 1, length: 32 }, { start: 34, length: 32 }] } } };
    const encoded = ethers.utils.hexZeroPad(settings.trustedForwarder, 32).slice(2);
    assert.equal(runtimeHash(compiled, { 123: settings.trustedForwarder }), ethers.utils.keccak256(`0x00${encoded}ff${encoded}`));
    assert.throws(() => runtimeHash({ deployedBytecode: { ...compiled.deployedBytecode,
        immutableReferences: { ...compiled.deployedBytecode.immutableReferences, 456: [] } } }, { 123: settings.trustedForwarder }), /immutable layout/);
});

test('writer binding resumes unbound or matching storage and refuses another resolver', () => {
    const storage = settings.owner;
    const replacement = settings.trustedForwarder;
    const binding = storageBinding(storage, ethers.constants.AddressZero, replacement);
    assert.equal(binding.to, storage);
    assert.equal(binding.value, '0');
    const decoded = new ethers.utils.Interface(['function setWriter(address)']).decodeFunctionData('setWriter', binding.data);
    assert.equal(decoded[0], replacement);
    assert.equal(storageBinding(storage, replacement, replacement), null);
    assert.throws(() => storageBinding(storage, storage, replacement), /another writer/);
});
test('deployment resume checks exact runtime at the pinned block', async () => {
    const item = { address: settings.owner, transaction: { to: settings.owner, data: '0x1234' } };
    const code = '0x60006000';
    const provider = { getCode: async (address, block) => {
        assert.equal(address, item.address); assert.equal(block, 123); return code;
    } };
    assert.equal(await deploymentTransaction(provider, item, ethers.utils.keccak256(code), 123), null);
    await assert.rejects(deploymentTransaction(provider, item, ethers.utils.keccak256('0x00'), 123), /unexpected code/);
    assert.deepEqual(await deploymentTransaction({ getCode: async () => '0x' }, item, ethers.utils.keccak256(code), 123), item.transaction);
});
test('storage CREATE2 identity does not depend on the resolver while resolver identity binds storage', () => {
    const storageArtifact = { abi: ['constructor(address configurator)'], bytecode: { object: '0x60006000' } };
    const resolverArtifact = { abi: ['constructor(address owner,address storageAddress)'], bytecode: { object: '0x60006001' } };
    const storage = deployment(storageArtifact, [settings.owner], 'bytecode-svg-storage');
    const resolver = deployment(resolverArtifact, [settings.owner, storage.address], 'bytecode-svg');
    assert.notEqual(deployment(resolverArtifact, [settings.owner, settings.trustedForwarder], 'bytecode-svg').address, resolver.address);
    assert.deepEqual(deployment(storageArtifact, [settings.owner], 'bytecode-svg-storage'), storage);
    assert.notEqual(deployment(storageArtifact, [settings.trustedForwarder], 'bytecode-svg-storage').address, storage.address);
});
