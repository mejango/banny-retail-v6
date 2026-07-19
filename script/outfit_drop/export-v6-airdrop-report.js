#!/usr/bin/env node

const childProcess = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const {
    buildContractsByChain,
    CHAINS,
    itemCategory,
    itemOwner,
    itemProductName,
    itemTokenId,
    itemUpc,
    loadRawItems,
} = require('./generate-v6-airdrop');

const REPORT_DIR = path.join(__dirname, 'reports');
const WORKBOOK_PATH = path.join(REPORT_DIR, 'v6-airdrop-mints.xlsx');
const ALL_CHAINS_CSV_PATH = path.join(REPORT_DIR, 'v6-airdrop-mints-all-chains.csv');
const EXCLUDED_CSV_PATH = path.join(REPORT_DIR, 'v6-airdrop-excluded.csv');

const HEADERS = [
    'plain_english_result',
    'chain',
    'chain_id',
    'chunk',
    'contract',
    'chain_mint_number',
    'chunk_mint_number',
    'airdrop_type',
    'asset_category',
    'asset_category_id',
    'asset_product_name',
    'asset_upc',
    'v4_asset_token_id',
    'v6_asset_token_id',
    'recipient_address',
    'asset_source_owner_from_raw',
    'worn_by_banny_v4_token_id',
    'worn_by_banny_v6_token_id',
    'worn_by_banny_product_name',
    'outfitted_banny_recipient_address',
    'notes',
];

function itemKey(chainId, tokenId) {
    return `${chainId}:${tokenId}`;
}

function buildItemByKey(items) {
    const itemByKey = new Map();
    items.forEach(item => {
        itemByKey.set(itemKey(item.chainId, itemTokenId(item)), item);
    });
    return itemByKey;
}

function originalItem(itemByKey, chainId, tokenId, fallbackItem) {
    return itemByKey.get(itemKey(chainId, tokenId)) || fallbackItem;
}

function categoryName(item) {
    if (item && item.metadata && item.metadata.categoryName) {
        return item.metadata.categoryName;
    }

    const category = Number(item && (item.metadata ? item.metadata.category : item.category));
    if (category === 0) return 'Banny body';
    if (category === 1) return 'Background';
    if (!Number.isNaN(category)) return 'Outfit';
    return '';
}

function displayRecipient(address) {
    return address || 'No recipient';
}

function indefiniteArticle(phrase) {
    return /^[aeiou]/i.test(String(phrase).trim()) ? 'an' : 'a';
}

function humanList(items) {
    const filtered = items.filter(Boolean);
    if (filtered.length === 0) return '';
    if (filtered.length === 1) return filtered[0];
    if (filtered.length === 2) return `${filtered[0]} and ${filtered[1]}`;
    return `${filtered.slice(0, -1).join(', ')}, and ${filtered[filtered.length - 1]}`;
}

function productAndCategory(item) {
    const product = item && itemProductName(item);
    const category = categoryName(item);
    if (product && category) {
        return product.toLowerCase().endsWith(category.toLowerCase()) ? product : `${product} ${category}`;
    }
    return product || category || 'asset';
}

function itemProductNameOrFallback(item, fallback) {
    return item ? itemProductName(item) || fallback : fallback;
}

function wearingSummary({ banny, chain, itemByKey }) {
    const backgroundNames = [];
    const outfitNames = [];

    if (banny.backgroundId) {
        const backgroundItem = originalItem(itemByKey, chain.id, Number(banny.backgroundId), null);
        backgroundNames.push(itemProductNameOrFallback(backgroundItem, `background ${banny.backgroundId}`));
    }

    banny.outfitIds.forEach(outfitId => {
        const outfitItem = originalItem(itemByKey, chain.id, Number(outfitId), null);
        outfitNames.push(itemProductNameOrFallback(outfitItem, `outfit ${outfitId}`));
    });

    const clauses = [];
    if (backgroundNames.length) {
        clauses.push(`on ${humanList(backgroundNames)} background`);
    }
    if (outfitNames.length) {
        clauses.push(`wearing ${humanList(outfitNames)}`);
    }

    return clauses.length ? clauses.join(' ') : 'with no outfit';
}

function bannyResultSummary({ recipientAddress, banny, chain, itemByKey }) {
    const product = banny.productName || 'Banny';
    return `${displayRecipient(recipientAddress)} receives ${indefiniteArticle(product)} ${product} Banny ${wearingSummary({
        banny,
        chain,
        itemByKey,
    })}.`;
}

function standaloneResultSummary({ recipientAddress, item }) {
    const asset = productAndCategory(item);
    return `${displayRecipient(recipientAddress)} receives ${indefiniteArticle(asset)} ${asset} asset.`;
}

function rowFromItem({
    chain,
    contract,
    chunkIndex,
    mintPositions,
    airdropType,
    item,
    v6TokenId,
    recipientAddress,
    banny,
    bannyV6TokenId,
    plainEnglishResult,
    notes = '',
}) {
    const mintPosition = mintPositions.get(String(v6TokenId));
    if (!mintPosition) {
        throw new Error(`No mint position for V6 token ${v6TokenId} in ${contract.contractName}`);
    }

    const tokenId = itemTokenId(item);
    const category = itemCategory(item);
    const bannyRecipient = banny ? banny.owner : '';

    return {
        plain_english_result: plainEnglishResult,
        chain: chain.name,
        chain_id: chain.id,
        chunk: chunkIndex,
        contract: contract.contractName,
        chain_mint_number: mintPosition.chainMintNumber,
        chunk_mint_number: mintPosition.chunkMintNumber,
        airdrop_type: airdropType,
        asset_category: categoryName(item),
        asset_category_id: Number.isNaN(category) ? '' : category,
        asset_product_name: itemProductName(item),
        asset_upc: itemUpc(item),
        v4_asset_token_id: tokenId,
        v6_asset_token_id: v6TokenId,
        recipient_address: recipientAddress,
        asset_source_owner_from_raw: itemOwner(item),
        worn_by_banny_v4_token_id: banny ? banny.tokenId : '',
        worn_by_banny_v6_token_id: banny ? bannyV6TokenId : '',
        worn_by_banny_product_name: banny ? banny.productName : '',
        outfitted_banny_recipient_address: bannyRecipient,
        notes,
    };
}

function buildRowsForChain(chain, contracts, itemByKey) {
    const rows = [];
    let chainMintNumber = 1;

    contracts.forEach((contract, contractIndex) => {
        const chunkIndex = contractIndex + 1;
        const mintPositions = new Map();

        contract.assignments.expectedTokenIds.forEach((tokenId, index) => {
            mintPositions.set(String(tokenId), {
                chainMintNumber: chainMintNumber++,
                chunkMintNumber: index + 1,
            });
        });

        const emittedV4TokenIds = new Set();

        contract.bannies.forEach(banny => {
            const bodyV4TokenId = Number(banny.tokenId);
            const bodyV6TokenId = contract.assignments.v4ToV6TokenIds.get(bodyV4TokenId);
            const bannySummary = bannyResultSummary({
                recipientAddress: banny.owner,
                banny,
                chain,
                itemByKey,
            });
            const bodyItem = originalItem(itemByKey, chain.id, bodyV4TokenId, {
                chainId: chain.id,
                tokenId: bodyV4TokenId,
                upc: banny.upc,
                category: 0,
                owner: banny.owner,
                productName: banny.productName,
            });

            rows.push(
                rowFromItem({
                    chain,
                    contract,
                    chunkIndex,
                    mintPositions,
                    airdropType: banny.backgroundId || banny.outfitIds.length ? 'outfitted_banny_body' : 'banny_body',
                    item: bodyItem,
                    v6TokenId: bodyV6TokenId,
                    recipientAddress: banny.owner,
                    banny,
                    bannyV6TokenId: bodyV6TokenId,
                    plainEnglishResult: bannySummary,
                    notes: banny.backgroundId || banny.outfitIds.length ? 'Body transferred after dressing.' : 'Body transferred naked.',
                }),
            );
            emittedV4TokenIds.add(bodyV4TokenId);

            if (banny.backgroundId) {
                const backgroundV4TokenId = Number(banny.backgroundId);
                const backgroundV6TokenId = contract.assignments.v4ToV6TokenIds.get(backgroundV4TokenId);
                const backgroundItem = originalItem(itemByKey, chain.id, backgroundV4TokenId, {
                    chainId: chain.id,
                    tokenId: backgroundV4TokenId,
                    category: 1,
                    owner: banny.owner,
                });

                rows.push(
                    rowFromItem({
                        chain,
                        contract,
                        chunkIndex,
                        mintPositions,
                        airdropType: 'worn_background',
                        item: backgroundItem,
                        v6TokenId: backgroundV6TokenId,
                        recipientAddress: banny.owner,
                        banny,
                        bannyV6TokenId: bodyV6TokenId,
                        plainEnglishResult: bannySummary,
                        notes: 'Background is worn by the Banny; the outfitted Banny is transferred to recipient.',
                    }),
                );
                emittedV4TokenIds.add(backgroundV4TokenId);
            }

            banny.outfitIds.forEach(outfitId => {
                const outfitV4TokenId = Number(outfitId);
                const outfitV6TokenId = contract.assignments.v4ToV6TokenIds.get(outfitV4TokenId);
                const outfitItem = originalItem(itemByKey, chain.id, outfitV4TokenId, {
                    chainId: chain.id,
                    tokenId: outfitV4TokenId,
                    owner: banny.owner,
                });

                rows.push(
                    rowFromItem({
                        chain,
                        contract,
                        chunkIndex,
                        mintPositions,
                        airdropType: 'worn_outfit',
                        item: outfitItem,
                        v6TokenId: outfitV6TokenId,
                        recipientAddress: banny.owner,
                        banny,
                        bannyV6TokenId: bodyV6TokenId,
                        plainEnglishResult: bannySummary,
                        notes: 'Outfit is worn by the Banny; the outfitted Banny is transferred to recipient.',
                    }),
                );
                emittedV4TokenIds.add(outfitV4TokenId);
            });
        });

        contract.transferItems.forEach(entry => {
            const v4TokenId = itemTokenId(entry.item);
            if (emittedV4TokenIds.has(v4TokenId)) {
                return;
            }

            const item = originalItem(itemByKey, chain.id, v4TokenId, entry.item);
            const v6TokenId = contract.assignments.v4ToV6TokenIds.get(v4TokenId);

            rows.push(
                rowFromItem({
                    chain,
                    contract,
                    chunkIndex,
                    mintPositions,
                    airdropType: contract.isUnused ? 'standalone_asset' : 'non_worn_transfer',
                    item,
                    v6TokenId,
                    recipientAddress: entry.owner,
                    plainEnglishResult: standaloneResultSummary({ recipientAddress: entry.owner, item }),
                    notes: 'Asset is not worn by a Banny and is transferred directly.',
                }),
            );
            emittedV4TokenIds.add(v4TokenId);
        });
    });

    return rows.sort((a, b) => Number(a.chain_mint_number) - Number(b.chain_mint_number));
}

function csvEscape(value) {
    const stringValue = value === null || value === undefined ? '' : String(value);
    if (/[",\r\n]/.test(stringValue)) {
        return `"${stringValue.replace(/"/g, '""')}"`;
    }
    return stringValue;
}

function writeCsv(filePath, rows) {
    const lines = [HEADERS.join(',')];
    rows.forEach(row => {
        lines.push(HEADERS.map(header => csvEscape(row[header])).join(','));
    });
    fs.writeFileSync(filePath, `${lines.join('\n')}\n`);
}

function xmlEscape(value) {
    return String(value === null || value === undefined ? '' : value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');
}

function columnName(index) {
    let n = index + 1;
    let name = '';
    while (n > 0) {
        const remainder = (n - 1) % 26;
        name = String.fromCharCode(65 + remainder) + name;
        n = Math.floor((n - 1) / 26);
    }
    return name;
}

function worksheetXml(rows) {
    const allRows = [HEADERS, ...rows.map(row => HEADERS.map(header => row[header]))];
    const rowXml = allRows
        .map((row, rowIndex) => {
            const cellXml = row
                .map((value, columnIndex) => {
                    const ref = `${columnName(columnIndex)}${rowIndex + 1}`;
                    return `<c r="${ref}" t="inlineStr"><is><t>${xmlEscape(value)}</t></is></c>`;
                })
                .join('');
            return `<row r="${rowIndex + 1}">${cellXml}</row>`;
        })
        .join('');

    const lastColumn = columnName(HEADERS.length - 1);
    const lastRow = Math.max(allRows.length, 1);
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <dimension ref="A1:${lastColumn}${lastRow}"/>
  <sheetViews><sheetView workbookViewId="0"/></sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <sheetData>${rowXml}</sheetData>
</worksheet>`;
}

function writeFileEnsuringDir(filePath, content) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, content);
}

function writeWorkbook(sheetRowsByName) {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'banny-v6-airdrop-report-'));
    const sheetNames = Object.keys(sheetRowsByName);

    try {
        writeFileEnsuringDir(
            path.join(tempDir, '[Content_Types].xml'),
            `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
${sheetNames
    .map((_, index) => `  <Override PartName="/xl/worksheets/sheet${index + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`)
    .join('\n')}
</Types>`,
        );

        writeFileEnsuringDir(
            path.join(tempDir, '_rels/.rels'),
            `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>`,
        );

        writeFileEnsuringDir(
            path.join(tempDir, 'docProps/core.xml'),
            `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Banny V6 Airdrop Mints</dc:title>
  <dc:creator>export-v6-airdrop-report.js</dc:creator>
  <cp:lastModifiedBy>export-v6-airdrop-report.js</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">${new Date().toISOString()}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">${new Date().toISOString()}</dcterms:modified>
</cp:coreProperties>`,
        );

        writeFileEnsuringDir(
            path.join(tempDir, 'docProps/app.xml'),
            `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Codex</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant><vt:variant><vt:i4>${sheetNames.length}</vt:i4></vt:variant></vt:vector></HeadingPairs>
  <TitlesOfParts><vt:vector size="${sheetNames.length}" baseType="lpstr">${sheetNames.map(name => `<vt:lpstr>${xmlEscape(name)}</vt:lpstr>`).join('')}</vt:vector></TitlesOfParts>
</Properties>`,
        );

        writeFileEnsuringDir(
            path.join(tempDir, 'xl/workbook.xml'),
            `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
${sheetNames.map((name, index) => `    <sheet name="${xmlEscape(name)}" sheetId="${index + 1}" r:id="rId${index + 1}"/>`).join('\n')}
  </sheets>
</workbook>`,
        );

        writeFileEnsuringDir(
            path.join(tempDir, 'xl/_rels/workbook.xml.rels'),
            `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${sheetNames
    .map((_, index) => `  <Relationship Id="rId${index + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${index + 1}.xml"/>`)
    .join('\n')}
</Relationships>`,
        );

        sheetNames.forEach((name, index) => {
            writeFileEnsuringDir(path.join(tempDir, `xl/worksheets/sheet${index + 1}.xml`), worksheetXml(sheetRowsByName[name]));
        });

        if (fs.existsSync(WORKBOOK_PATH)) {
            fs.unlinkSync(WORKBOOK_PATH);
        }
        childProcess.execFileSync('zip', ['-q', '-r', WORKBOOK_PATH, '[Content_Types].xml', '_rels', 'docProps', 'xl'], {
            cwd: tempDir,
        });
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true });
    }
}

function reportFileName(chain) {
    return `v6-airdrop-mints-${chain.name.toLowerCase()}.csv`;
}

function buildExcludedRows(items, contractsByChain) {
    const coveredTokenIds = new Set();
    Object.values(contractsByChain).flat().forEach(contract => {
        contract.allItems.forEach(item => coveredTokenIds.add(itemKey(contract.chain.id, itemTokenId(item))));
    });

    return items
        .filter(item => !coveredTokenIds.has(itemKey(item.chainId, itemTokenId(item))))
        .map(item => ({
            plain_english_result: `No V6 mint: ${productAndCategory(item)} was excluded by inherited resolver-owned/unused filtering.`,
            chain: CHAINS.find(chain => chain.id === item.chainId)?.name || '',
            chain_id: item.chainId,
            chunk: '',
            contract: '',
            chain_mint_number: '',
            chunk_mint_number: '',
            airdrop_type: 'excluded',
            asset_category: categoryName(item),
            asset_category_id: itemCategory(item),
            asset_product_name: itemProductName(item),
            asset_upc: itemUpc(item),
            v4_asset_token_id: itemTokenId(item),
            v6_asset_token_id: '',
            recipient_address: '',
            asset_source_owner_from_raw: itemOwner(item),
            worn_by_banny_v4_token_id: '',
            worn_by_banny_v6_token_id: '',
            worn_by_banny_product_name: '',
            outfitted_banny_recipient_address: '',
            notes: 'Not minted by the V6 airdrop script; excluded by inherited resolver-owned/unused filtering.',
        }));
}

function main() {
    const items = loadRawItems();
    const contractsByChain = buildContractsByChain(items);
    const itemByKey = buildItemByKey(items);

    fs.mkdirSync(REPORT_DIR, { recursive: true });

    const sheetRowsByName = {};
    const allRows = [];
    const counts = [];

    CHAINS.forEach(chain => {
        const contracts = contractsByChain[chain.id] || [];
        const rows = buildRowsForChain(chain, contracts, itemByKey);
        sheetRowsByName[chain.name] = rows;
        allRows.push(...rows);
        writeCsv(path.join(REPORT_DIR, reportFileName(chain)), rows);
        counts.push(`${chain.name}: ${rows.length} mints`);
    });

    const excludedRows = buildExcludedRows(items, contractsByChain);
    const workbookRowsByName = {
        'All Chains': allRows,
        ...sheetRowsByName,
        Excluded: excludedRows,
    };
    writeCsv(ALL_CHAINS_CSV_PATH, allRows);
    writeCsv(EXCLUDED_CSV_PATH, excludedRows);
    writeWorkbook(workbookRowsByName);

    console.log('Wrote V6 airdrop mint reports:');
    counts.forEach(count => console.log(`  ${count}`));
    console.log(`  excluded: ${excludedRows.length} raw item(s)`);
    console.log(`  ${path.relative(process.cwd(), WORKBOOK_PATH)}`);
    console.log(`  ${path.relative(process.cwd(), ALL_CHAINS_CSV_PATH)}`);
    CHAINS.forEach(chain => console.log(`  ${path.relative(process.cwd(), path.join(REPORT_DIR, reportFileName(chain)))}`));
    console.log(`  ${path.relative(process.cwd(), EXCLUDED_CSV_PATH)}`);
}

main();
