'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { ethers } = require('ethers');
const { configurationHash, runtimeHash } = require('./prepare-resolver-upgrade');
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
