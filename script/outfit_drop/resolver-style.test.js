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

// This gate covers the resolver rollout's ordinary Solidity declarations; it is not a general Solidity parser.
for (const file of files) {
  test(`${file}: ordered sections/functions and complete new function NatSpec`, () => {
    const source = fs.readFileSync(path.join(root, file), 'utf8');
    assert.equal((source.match(/^\s*(?:contract|interface) \w+/gm) || []).length, 1, 'one type per file');
    const banners = [...source.matchAll(/^    \/\/ -+ ([\w /]+?) -+ \/\//gm)];
    const numbered = banners.map(match => sections.indexOf(match[1])).filter(index => index !== -1);
    assert.deepEqual(numbered, [...numbered].sort((a, b) => a - b), 'section order');
    const functions = [...source.matchAll(/((?:    \/\/\/[^\n]*\n)+)    function (\w+)\(([^)]*)\)([^;{]*)(?:[;{])/g)];
    assert.equal(functions.length, (source.match(/^    function /gm) || []).length, 'every function has NatSpec');
    const groups = new Map();
    for (const match of functions) {
      const [, doc, name, params, signature] = match;
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
      // Existing resolver documentation is outside this correction; all added helpers and new types are covered.
      if (file.endsWith('Banny721TokenUriResolver.sol') && !['_hasStoredSvg', '_storedSvgOf', '_storeSvg'].includes(name)) continue;
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
