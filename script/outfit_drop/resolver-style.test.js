'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '../..');
const files = [
  'src/Banny721TokenUriResolver.sol',
  'src/BannySvgStorage.sol',
  'script/helpers/BannyResolverUpgradeGuard.sol',
  'script/helpers/interfaces/IBannyUpgradeHook.sol',
  'script/helpers/interfaces/IBannyUpgradeResolver.sol',
  'script/helpers/interfaces/IBannyUpgradeStore.sol',
];
const sections = [
  'custom errors', 'public constants', 'internal constants', 'private constants',
  'public immutable stored properties', 'internal immutable stored properties',
  'public stored properties', 'internal stored properties', 'private stored properties',
  'transient stored properties', 'constructor', 'modifiers', 'receive / fallback',
  'external transactions', 'external views', 'public views', 'public transactions',
  'internal transactions', 'internal helpers', 'internal views', 'private helpers',
];

const resolverFunctionOrder = [
  "tokenUriOf", "assetIdsOf", "namesOf", "svgOf",
  "userOf", "wearerOf", "_bannyBodySvgOf", "_categoryNameOf",
  "_checkIfSenderIsOwner", "_contextSuffixLength", "_encodeTokenUri", "_fillsFor",
  "_fullNameOf", "_isInArray", "_layeredSvg", "_mannequinBannySvg",
  "_msgData", "_msgSender", "_outfitContentsFor", "_productNameOf",
  "_productOfTokenId", "_revertIfBodyLocked", "_sortOutfitsByCategory", "_storeOf",
  "_svgOf", "_validateCategoryExclusivity", "decorateBannyWith", "lockOutfitChangesFor",
  "onERC721Received", "setMetadata", "setProductNames", "setSvgContentsOf",
  "setSvgHashesOf", "_decorateBannyWithBackground", "_decorateBannyWithOutfits", "_storeOutfitsWithRetained",
  "_transferFrom", "_tryTransferFrom",
];

// This gate covers the resolver rollout's ordinary Solidity declarations; it is not a general Solidity parser.
for (const file of files) {
  const isResolver = file.endsWith('Banny721TokenUriResolver.sol');
  const scope = isResolver ? 'existing function layout and new NatSpec' : 'ordered sections/functions and full NatSpec';
  test(`${file}: ${scope}`, () => {
    const source = fs.readFileSync(path.join(root, file), 'utf8');
    assert.equal((source.match(/^\s*(?:contract|interface) \w+/gm) || []).length, 1, 'one type per file');
    if (isResolver) {
      // Keep this contract's established function layout; full section ordering applies to the new types below.
      const names = [...source.matchAll(/^    function (\w+)\(/gm)].map(match => match[1]);
      assert.deepEqual(names.filter(name => resolverFunctionOrder.includes(name)), resolverFunctionOrder, 'existing function layout');
      assert.doesNotMatch(source, /new BannySvgStorage\s*\(/, 'deployment scripts create storage');
      const constructor = source.match(/((?:    \/\/\/[^\n]*\n)+)    constructor\(([^]*?)\)\n/);
      assert(constructor, 'documented constructor');
      assert.match(constructor[1], /@notice\s+\S/, 'constructor notice');
      for (const param of constructor[2].split(',')) {
        const name = param.trim().split(/\s+/).at(-1);
        assert.match(constructor[1], new RegExp(`@param ${name}\\s+\\S`), `constructor parameter ${name}`);
      }
    }
    const banners = [...source.matchAll(/^    \/\/ -+ ([\w /]+?) -+ \/\//gm)];
    const numbered = banners.map(match => sections.indexOf(match[1])).filter(index => index !== -1);
    if (!isResolver) assert.deepEqual(numbered, [...numbered].sort((a, b) => a - b), 'section order');
    const functions = [...source.matchAll(/((?:    \/\/\/[^\n]*\n)+)    function (\w+)\(([^)]*)\)([^;{]*)(?:[;{])/g)];
    assert.equal(functions.length, (source.match(/^    function /gm) || []).length, 'every function has NatSpec');
    const groups = new Map();
    for (const match of functions) {
      const [, doc, name, params, signature] = match;
      // Validate additions without requiring unrelated edits to existing resolver functions.
      if (isResolver && resolverFunctionOrder.includes(name)) continue;
      const visibility = signature.match(/\b(external|public|internal|private)\b/)[1];
      const view = /\b(view|pure)\b/.test(signature);
      const expected = `${visibility} ${view ? 'views' : 'transactions'}`;
      if (file.startsWith('src/') || file.endsWith('BannyResolverUpgradeGuard.sol')) {
        const section = banners.filter(banner => banner.index < match.index).at(-1)?.[1];
        assert.equal(section, expected, `${name} belongs in ${expected}`);
      }
      const group = groups.get(expected) || [];
      group.push(name);
      groups.set(expected, group);
      assert.match(doc, /@notice\s+\S/, `${name} notice`);
      for (const param of params.split(',').filter(param => param.trim())) {
        const paramName = param.trim().split(/\s+/).at(-1);
        assert.match(doc, new RegExp(`@param ${paramName}\\s+\\S`), `${name} parameter ${paramName}`);
      }
      const returns = signature.match(/returns\s*\(([^)]*)\)/)?.[1];
      for (const value of returns?.split(',') || []) {
        assert.match(value.trim(), /\s+\w+$/, `${name} named return`);
        const returnName = value.trim().split(/\s+/).at(-1);
        assert.match(doc, new RegExp(`@return ${returnName}\\s+\\S`), `${name} return ${returnName}`);
      }
    }
    for (const names of groups.values()) assert.deepEqual(names, [...names].sort(), 'alphabetical functions');
  });
}
