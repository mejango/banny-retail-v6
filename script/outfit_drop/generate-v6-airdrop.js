#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const {
    generateTierIdLoops,
    generateUnusedAssetsContract,
    splitBanniesIntoChunks,
    toChecksumAddress,
} = require('./generate-migration');

const ONE_BILLION = 1_000_000_000;
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const V6_MAINNET_HOOK = toChecksumAddress('0x37e35937ecF949d7a44a9Fe878107DE264618B8f');
const V4_HOOK = toChecksumAddress('0x2da41CdC79Ae49F2725AB549717B2DBcfc42b958');
const V4_RESOLVER = toChecksumAddress('0xa5F8911d4CFd60a6697479f078409434424fe666');
const V4_RESOLVER_FALLBACK = toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3');

const CHAINS = [
    { id: 1, name: 'Ethereum', numChunks: 6 },
    { id: 10, name: 'Optimism', numChunks: 1 },
    { id: 8453, name: 'Base', numChunks: 5 },
    { id: 42161, name: 'Arbitrum', numChunks: 3 },
];

const DEFAULT_SCRIPT_BASE_NAME = 'AirdropV4Bannys';
const COMBINED_SCRIPT_BASE_NAME = 'AirdropV4BannysCombined';
const COMBINED_MAINNETS_SCRIPT_BASE_NAME = 'AirdropV4BannysCombinedMainnets';
const COMBINED_TESTNETS_SCRIPT_BASE_NAME = 'AirdropV4BannysCombinedTestnets';

const V4_RESOLVER_OWNERS = new Set([V4_RESOLVER.toLowerCase(), V4_RESOLVER_FALLBACK.toLowerCase()]);

function isCombined(options = {}) {
    return options.combined || options.unchunked;
}

function scriptBaseName(options = {}) {
    if (!isCombined(options)) {
        return DEFAULT_SCRIPT_BASE_NAME;
    }
    if (options.networkProfile === 'mainnets') {
        return COMBINED_MAINNETS_SCRIPT_BASE_NAME;
    }
    if (options.networkProfile === 'testnets') {
        return COMBINED_TESTNETS_SCRIPT_BASE_NAME;
    }
    return COMBINED_SCRIPT_BASE_NAME;
}

function scriptFileName(options = {}) {
    return `${scriptBaseName(options)}.s.sol`;
}

function scriptContractName(options = {}) {
    return `${scriptBaseName(options)}Script`;
}

function itemOwner(item) {
    return toChecksumAddress(item.owner || (item.wallet ? item.wallet.address : ZERO_ADDRESS));
}

function itemTokenId(item) {
    return Number(item.metadata ? item.metadata.tokenId : item.tokenId);
}

function itemUpc(item) {
    return Number(item.metadata ? item.metadata.upc : item.upc);
}

function itemCategory(item) {
    return Number(item.metadata ? item.metadata.category : item.category);
}

function itemProductName(item) {
    return item.metadata ? item.metadata.productName : '';
}

function itemWornByBannyBodyId(item) {
    return Number(item.metadata ? item.metadata.wornByBannyBodyId || 0 : item.wornByBannyBodyId || 0);
}

function itemCoverageKey(item) {
    return `${item.chainId}:${itemTokenId(item)}`;
}

function startingUnitNumbersFromCounts(upcCounts) {
    const startingUnitNumbers = new Map();
    upcCounts.forEach((count, upc) => {
        startingUnitNumbers.set(upc, count + 1);
    });
    return startingUnitNumbers;
}

function updateUpcCounts(upcCounts, chunkUpcCounts) {
    chunkUpcCounts.forEach((count, upc) => {
        upcCounts.set(upc, (upcCounts.get(upc) || 0) + count);
    });
}

function buildMintAssignments(items, upcStartingUnitNumbers = new Map()) {
    const tierIdQuantities = new Map();
    items.forEach(item => {
        const upc = itemUpc(item);
        tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
    });

    const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
    const tierIds = [];
    const expectedTokenIds = [];
    const v4ToV6TokenIds = new Map();
    const chunkUpcCounts = new Map();

    uniqueUpcs.forEach(upc => {
        const upcItems = items.filter(item => itemUpc(item) === upc);
        const startingUnitNumber = upcStartingUnitNumbers.get(upc) || 1;

        upcItems.forEach((item, index) => {
            const unitNumber = startingUnitNumber + index;
            const tokenId = upc * ONE_BILLION + unitNumber;
            tierIds.push(upc);
            expectedTokenIds.push(tokenId);
            v4ToV6TokenIds.set(itemTokenId(item), tokenId);
            chunkUpcCounts.set(upc, (chunkUpcCounts.get(upc) || 0) + 1);
        });
    });

    return {
        tierIdQuantities,
        tierIds,
        expectedTokenIds,
        v4ToV6TokenIds,
        chunkUpcCounts,
    };
}

function bannyFromItem(item) {
    return {
        tokenId: itemTokenId(item),
        upc: itemUpc(item),
        backgroundId: Number(item.metadata.backgroundId || 0),
        outfitIds: (item.metadata.outfitIds || []).map(Number),
        owner: itemOwner(item),
        productName: itemProductName(item),
    };
}

function buildSingleChainChunk(chainItems) {
    const bannyItems = chainItems.filter(item => itemCategory(item) === 0);
    const outfitItems = chainItems.filter(item => itemCategory(item) !== 0 && itemCategory(item) !== 1);
    const backgroundItems = chainItems.filter(item => itemCategory(item) === 1);
    const bannies = bannyItems.map(bannyFromItem);
    const bannyByTokenId = new Map(bannyItems.map(item => [itemTokenId(item), item]));

    const usedOutfitIds = new Set();
    const usedBackgroundIds = new Set();
    bannies.forEach(banny => {
        if (banny.backgroundId !== 0) {
            usedBackgroundIds.add(banny.backgroundId);
        }
        banny.outfitIds.forEach(outfitId => usedOutfitIds.add(outfitId));
    });

    const transferData = [];
    [...bannyItems, ...outfitItems, ...backgroundItems].forEach(item => {
        const owner = itemOwner(item);
        const tokenId = itemTokenId(item);
        if (owner === ZERO_ADDRESS) {
            return;
        }
        if (usedOutfitIds.has(tokenId) || usedBackgroundIds.has(tokenId)) {
            return;
        }

        if (itemCategory(item) !== 0 && V4_RESOLVER_OWNERS.has(owner.toLowerCase())) {
            const recipientBodyTokenId = itemWornByBannyBodyId(item);
            const recipientBody = bannyByTokenId.get(recipientBodyTokenId);
            if (!recipientBody) {
                throw new Error(
                    `Cannot infer recipient for resolver-owned standalone token ${tokenId}; missing body ${recipientBodyTokenId}`,
                );
            }

            transferData.push({
                item: {
                    ...item,
                    owner: itemOwner(recipientBody),
                    originalOwner: owner,
                    allowResolverOwner: true,
                    resolverStrandedStandaloneTransfer: true,
                    recipientBodyTokenId,
                },
                owner: itemOwner(recipientBody),
                allowResolverOwner: true,
            });
            return;
        }

        transferData.push({ item, owner });
    });

    return {
        bannies,
        allItems: chainItems,
        transferData,
    };
}

function makeTransferItems(transferData) {
    return transferData.map(entry => ({
        item: entry.item,
        owner: toChecksumAddress(entry.owner),
        allowResolverOwner: Boolean(entry.allowResolverOwner || entry.item.allowResolverOwner),
    }));
}

function makeUnusedTransferItems(unusedItems) {
    return unusedItems.map(item => ({
        item,
        owner: toChecksumAddress(item.owner),
        allowResolverOwner: Boolean(item.allowResolverOwner),
    }));
}

function makeContractName(chain, index) {
    return index === null ? `AirdropV4Bannys${chain.name}` : `AirdropV4Bannys${chain.name}${index}`;
}

function makeFileName(contractName) {
    return `${contractName}.sol`;
}

function contractSuffix(contract) {
    const defaultPrefix = `${DEFAULT_SCRIPT_BASE_NAME}${contract.chain.name}`;
    const combinedPrefix = `${COMBINED_SCRIPT_BASE_NAME}${contract.chain.name}`;

    if (contract.contractName === defaultPrefix || contract.contractName === combinedPrefix) {
        return '';
    }
    if (contract.contractName.startsWith(defaultPrefix)) {
        return contract.contractName.slice(defaultPrefix.length);
    }
    if (contract.contractName.startsWith(combinedPrefix)) {
        return contract.contractName.slice(combinedPrefix.length);
    }

    return contract.contractName.replace(/[^a-zA-Z0-9_]/g, '');
}

function makeRegularContractPlan(chain, chunk, index, upcStartingUnitNumbers) {
    const assignments = buildMintAssignments(chunk.allItems, upcStartingUnitNumbers);
    const contractName = makeContractName(chain, chain.numChunks === 1 ? null : index);

    return {
        chain,
        contractName,
        fileName: makeFileName(contractName),
        isUnused: false,
        bannies: chunk.bannies,
        allItems: chunk.allItems,
        transferItems: makeTransferItems(chunk.transferData),
        assignments,
    };
}

function makeUnusedContractPlan(chain, unusedItems, index, upcStartingUnitNumbers) {
    const chainScopedUnusedItems = unusedItems.map(item => ({ ...item, chainId: chain.id }));
    const assignments = buildMintAssignments(chainScopedUnusedItems, upcStartingUnitNumbers);
    const contractName = makeContractName(chain, index);

    return {
        chain,
        contractName,
        fileName: makeFileName(contractName),
        isUnused: true,
        bannies: [],
        allItems: chainScopedUnusedItems,
        transferItems: makeUnusedTransferItems(chainScopedUnusedItems),
        assignments,
    };
}

function resolverStrandedStandaloneTransfersForChain(chainItems, processedTokenIds) {
    const bannies = chainItems.filter(item => itemCategory(item) === 0);
    const bodyByTokenId = new Map(bannies.map(banny => [itemTokenId(banny), banny]));
    const usedOutfitIds = new Set();
    const usedBackgroundIds = new Set();

    bannies.forEach(banny => {
        const body = bannyFromItem(banny);
        if (body.backgroundId !== 0) {
            usedBackgroundIds.add(body.backgroundId);
        }
        body.outfitIds.forEach(outfitId => usedOutfitIds.add(outfitId));
    });

    return chainItems.flatMap(item => {
        const category = itemCategory(item);
        if (category === 0) {
            return [];
        }

        const tokenId = itemTokenId(item);
        if (processedTokenIds.has(tokenId)) {
            return [];
        }

        const owner = itemOwner(item);
        if (!V4_RESOLVER_OWNERS.has(owner.toLowerCase())) {
            return [];
        }

        if (category === 1 ? usedBackgroundIds.has(tokenId) : usedOutfitIds.has(tokenId)) {
            return [];
        }

        const recipientBodyTokenId = itemWornByBannyBodyId(item);
        const recipientBody = bodyByTokenId.get(recipientBodyTokenId);
        if (!recipientBody) {
            throw new Error(
                `Cannot infer recipient for resolver-owned standalone token ${tokenId}; missing body ${recipientBodyTokenId}`,
            );
        }

        return [
            {
                ...item,
                owner: itemOwner(recipientBody),
                originalOwner: owner,
                allowResolverOwner: true,
                resolverStrandedStandaloneTransfer: true,
                recipientBodyTokenId,
            },
        ];
    });
}

function makeChainPlan(items, chain) {
    const chainItems = items.filter(item => item.chainId === chain.id);
    if (chainItems.length === 0) {
        return [];
    }

    const contracts = [];
    const upcCounts = new Map();

    if (chain.numChunks === 1) {
        const chunk = buildSingleChainChunk(chainItems);
        const contract = makeRegularContractPlan(chain, chunk, null, new Map());
        contracts.push(contract);
        updateUpcCounts(upcCounts, contract.assignments.chunkUpcCounts);
        return contracts;
    }

    const chunks = splitBanniesIntoChunks(chainItems, chain.numChunks);
    chunks.forEach((chunk, index) => {
        const upcStartingUnitNumbers = startingUnitNumbersFromCounts(upcCounts);
        const contract = makeRegularContractPlan(chain, chunk, index + 1, upcStartingUnitNumbers);
        contracts.push(contract);
        updateUpcCounts(upcCounts, contract.assignments.chunkUpcCounts);
    });

    const processedTokenIds = new Set();
    chunks.forEach(chunk => {
        chunk.allItems.forEach(item => processedTokenIds.add(itemTokenId(item)));
    });

    const unusedData = generateUnusedAssetsContract(
        chain,
        chainItems,
        startingUnitNumbersFromCounts(upcCounts),
        processedTokenIds,
        chunks.reduce((total, chunk) => total + chunk.allItems.length, 0),
    );

    const resolverStrandedStandaloneTransfers = resolverStrandedStandaloneTransfersForChain(chainItems, processedTokenIds);
    const unusedItems = [...(unusedData ? unusedData.unusedItems : []), ...resolverStrandedStandaloneTransfers];

    if (unusedItems.length === 0) {
        return contracts;
    }

    if (chain.id === 1) {
        const midPoint = Math.ceil(unusedItems.length / 2);
        const unusedItems7 = unusedItems.slice(0, midPoint);
        const unusedItems8 = unusedItems.slice(midPoint);

        const contract7 = makeUnusedContractPlan(chain, unusedItems7, 7, startingUnitNumbersFromCounts(upcCounts));
        contracts.push(contract7);
        updateUpcCounts(upcCounts, contract7.assignments.chunkUpcCounts);

        if (unusedItems8.length > 0) {
            const contract8 = makeUnusedContractPlan(chain, unusedItems8, 8, startingUnitNumbersFromCounts(upcCounts));
            contracts.push(contract8);
            updateUpcCounts(upcCounts, contract8.assignments.chunkUpcCounts);
        }
    } else {
        const contract = makeUnusedContractPlan(
            chain,
            unusedItems,
            chain.numChunks + 1,
            startingUnitNumbersFromCounts(upcCounts),
        );
        contracts.push(contract);
        updateUpcCounts(upcCounts, contract.assignments.chunkUpcCounts);
    }

    return contracts;
}

function mergeAssignments(contracts) {
    const tierIdQuantities = new Map();
    const chunkUpcCounts = new Map();
    const tierIds = [];
    const expectedTokenIds = [];
    const v4ToV6TokenIds = new Map();

    contracts.forEach(contract => {
        contract.assignments.tierIdQuantities.forEach((count, upc) => {
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + count);
        });
        contract.assignments.chunkUpcCounts.forEach((count, upc) => {
            chunkUpcCounts.set(upc, (chunkUpcCounts.get(upc) || 0) + count);
        });
        tierIds.push(...contract.assignments.tierIds);
        expectedTokenIds.push(...contract.assignments.expectedTokenIds);
        contract.assignments.v4ToV6TokenIds.forEach((v6TokenId, v4TokenId) => {
            const previousTokenId = v4ToV6TokenIds.get(v4TokenId);
            if (previousTokenId && previousTokenId !== v6TokenId) {
                throw new Error(`Conflicting V6 token ID assignment for V4 token ${v4TokenId}`);
            }
            v4ToV6TokenIds.set(v4TokenId, v6TokenId);
        });
    });

    return {
        tierIdQuantities,
        tierIds,
        expectedTokenIds,
        v4ToV6TokenIds,
        chunkUpcCounts,
    };
}

function mergeChainContracts(chain, contracts) {
    const regularContracts = contracts.filter(contract => !contract.isUnused);
    const unusedContracts = contracts.filter(contract => contract.isUnused);
    const regularTransferItems = regularContracts.flatMap(contract => contract.transferItems);
    const unusedTransferItems = unusedContracts.flatMap(contract => contract.transferItems);
    const contractName = `${COMBINED_SCRIPT_BASE_NAME}${chain.name}`;

    return {
        chain,
        contractName,
        fileName: makeFileName(contractName),
        isMerged: true,
        isUnused: false,
        bannies: regularContracts.flatMap(contract => contract.bannies),
        allItems: contracts.flatMap(contract => contract.allItems),
        transferItems: [...regularTransferItems, ...unusedTransferItems],
        regularTransferItems,
        unusedTransferItems,
        assignments: mergeAssignments(contracts),
    };
}

function makeCombinedChainPlan(items, chain) {
    const contracts = makeChainPlan(items, chain);
    if (contracts.length === 0) {
        return [];
    }
    return [mergeChainContracts(chain, contracts)];
}

function generateAddressArrayFunction(functionName, transferItems) {
    let code = `    function ${functionName}() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${transferItems.length});
`;

    transferItems.forEach((entry, index) => {
        code += `        transferOwners[${index}] = ${toChecksumAddress(entry.owner)};\n`;
    });

    code += `        return transferOwners;
    }
`;
    return code;
}

function generateUint256ArrayFunction(functionName, values) {
    let code = `    function ${functionName}() internal pure returns (uint256[] memory values) {
        values = new uint256[](${values.length});
`;

    values.forEach((value, index) => {
        code += `        values[${index}] = ${value};\n`;
    });

    code += `        return values;
    }
`;
    return code;
}

function generateBoolArrayFunction(functionName, values) {
    let code = `    function ${functionName}() internal pure returns (bool[] memory values) {
        values = new bool[](${values.length});
`;

    values.forEach((value, index) => {
        if (value) {
            code += `        values[${index}] = true;\n`;
        }
    });

    code += `        return values;
    }
`;
    return code;
}

function transferOwnerFunctionName(contract) {
    if (contract.chain.numChunks === 1) {
        return `_get${contract.chain.name}TransferOwners`;
    }

    const suffix = contractSuffix(contract);
    return `_get${contract.chain.name}TransferOwners${suffix}`;
}

function mergedDataFunctionName(contract, label) {
    return `_${label}${contract.chain.name}${contractSuffix(contract)}`;
}

function transferTokenIds(transferItems, v4ToV6TokenIds, useTargetIds) {
    return transferItems.map(entry => {
        const v4TokenId = itemTokenId(entry.item);
        const targetTokenId = v4ToV6TokenIds.get(v4TokenId);
        const value = useTargetIds ? targetTokenId : v4TokenId;
        if (!value) {
            throw new Error(`No V6 token ID assignment found for V4 token ${v4TokenId}`);
        }
        return value;
    });
}

function transferAllowResolverOwners(transferItems) {
    return transferItems.map(entry => Boolean(entry.allowResolverOwner));
}

function bannyTargetTokenId(contract, banny) {
    const v6BodyId = contract.assignments.v4ToV6TokenIds.get(banny.tokenId);
    if (!v6BodyId) {
        throw new Error(`No V6 token ID assignment found for V4 body ${banny.tokenId}`);
    }
    return v6BodyId;
}

function bannyBackgroundTokenId(contract, banny) {
    if (banny.backgroundId === 0) {
        return 0;
    }

    const v6BackgroundId = contract.assignments.v4ToV6TokenIds.get(banny.backgroundId);
    if (!v6BackgroundId) {
        throw new Error(`No V6 token ID assignment found for V4 background ${banny.backgroundId}`);
    }
    return v6BackgroundId;
}

function bannyOutfitData(contract) {
    const offsets = [0];
    const tokenIds = [];

    contract.bannies.forEach(banny => {
        banny.outfitIds.forEach(v4OutfitId => {
            const v6OutfitId = contract.assignments.v4ToV6TokenIds.get(v4OutfitId);
            if (!v6OutfitId) {
                throw new Error(`No V6 token ID assignment found for V4 outfit ${v4OutfitId}`);
            }
            tokenIds.push(v6OutfitId);
        });
        offsets.push(tokenIds.length);
    });

    return { offsets, tokenIds };
}

function generateMergedDataFunctions(contract) {
    const bannyV4TokenIds = contract.bannies.map(banny => banny.tokenId);
    const bannyTargetTokenIds = contract.bannies.map(banny => bannyTargetTokenId(contract, banny));
    const bannyBackgroundTokenIds = contract.bannies.map(banny => bannyBackgroundTokenId(contract, banny));
    const outfits = bannyOutfitData(contract);
    const regularTargetTokenIds = transferTokenIds(contract.regularTransferItems, contract.assignments.v4ToV6TokenIds, true);
    const regularV4TokenIds = transferTokenIds(contract.regularTransferItems, contract.assignments.v4ToV6TokenIds, false);
    const regularAllowResolverOwners = transferAllowResolverOwners(contract.regularTransferItems);
    const unusedTargetTokenIds = transferTokenIds(contract.unusedTransferItems, contract.assignments.v4ToV6TokenIds, true);
    const unusedV4TokenIds = transferTokenIds(contract.unusedTransferItems, contract.assignments.v4ToV6TokenIds, false);
    const unusedAllowResolverOwners = transferAllowResolverOwners(contract.unusedTransferItems);

    return [
        generateUint256ArrayFunction(
            mergedDataFunctionName(contract, 'expectedTokenIds'),
            contract.assignments.expectedTokenIds,
        ),
        generateUint256ArrayFunction(mergedDataFunctionName(contract, 'bannyV4TokenIds'), bannyV4TokenIds),
        generateUint256ArrayFunction(mergedDataFunctionName(contract, 'bannyTargetTokenIds'), bannyTargetTokenIds),
        generateUint256ArrayFunction(
            mergedDataFunctionName(contract, 'bannyBackgroundTokenIds'),
            bannyBackgroundTokenIds,
        ),
        generateUint256ArrayFunction(mergedDataFunctionName(contract, 'bannyOutfitOffsets'), outfits.offsets),
        generateUint256ArrayFunction(mergedDataFunctionName(contract, 'bannyOutfitTokenIds'), outfits.tokenIds),
        generateUint256ArrayFunction(mergedDataFunctionName(contract, 'regularTargetTokenIds'), regularTargetTokenIds),
        generateUint256ArrayFunction(mergedDataFunctionName(contract, 'regularV4TokenIds'), regularV4TokenIds),
        generateBoolArrayFunction(
            mergedDataFunctionName(contract, 'regularAllowResolverOwners'),
            regularAllowResolverOwners,
        ),
        generateUint256ArrayFunction(mergedDataFunctionName(contract, 'unusedTargetTokenIds'), unusedTargetTokenIds),
        generateUint256ArrayFunction(mergedDataFunctionName(contract, 'unusedV4TokenIds'), unusedV4TokenIds),
        generateBoolArrayFunction(
            mergedDataFunctionName(contract, 'unusedAllowResolverOwners'),
            unusedAllowResolverOwners,
        ),
    ].join('\n');
}

function sphinxNetworkConfig(options = {}) {
    if (options.networkProfile === 'mainnets') {
        return `        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = new string[](0);`;
    }
    if (options.networkProfile === 'testnets') {
        return `        sphinxConfig.mainnets = new string[](0);
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];`;
    }

    return `        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];`;
}

function generateTopLevelScript(contractsByChain, coverageReport, options = {}) {
    const allContracts = Object.values(contractsByChain).flat();
    const imports = allContracts
        .map(contract => `import {${contract.contractName}} from "./${contract.fileName}";`)
        .join('\n');

    let transferOwnerFunctions = '';
    let mergedDataFunctions = '';
    allContracts.forEach(contract => {
        transferOwnerFunctions += `\n${generateAddressArrayFunction(transferOwnerFunctionName(contract), contract.transferItems)}`;
        if (contract.isMerged) {
            mergedDataFunctions += `\n${generateMergedDataFunctions(contract)}`;
        }
    });

    const chainRunFunctions = CHAINS.map(chain => {
        const contracts = contractsByChain[chain.id] || [];
        if (contracts.length === 0) {
            return '';
        }

        let body = `    function _run${chain.name}() internal {
        JB721TiersHook hook = _v6Hook();
        address hookAddress = address(hook);
        address resolverAddress = _resolverOf(hook);
        bool verifyV4State = _shouldVerifyV4State();
        uint256 chunkFilter = _chunkFilter();
        uint256 maxChunkFilter = _maxChunkFilter();
        _requireValidChunkFilters(chunkFilter, maxChunkFilter, ${contracts.length});
`;

        contracts.forEach((contract, chunkIndex) => {
            const suffix = contractSuffix(contract);
            const tierIdsVar = `tierIds${suffix}`;
            const ownersVar = `transferOwners${suffix}`;
            const migrationVar = `migration${suffix}`;
            if (contract.isMerged) {
                body += `
        if (_shouldRunChunk(chunkFilter, maxChunkFilter, ${chunkIndex + 1})) {
            uint16[] memory ${tierIdsVar} = new uint16[](${contract.assignments.tierIds.length});
${generateTierIdLoops(contract.assignments.tierIds, tierIdsVar)}
            address[] memory ${ownersVar} = ${transferOwnerFunctionName(contract)}();
            ${contract.contractName} ${migrationVar} = new ${contract.contractName}();
            uint256[] memory mintedTokenIds = hook.mintFor(${tierIdsVar}, address(${migrationVar}));
            ${migrationVar}.requireMintedTokenIds(mintedTokenIds, ${mergedDataFunctionName(contract, 'expectedTokenIds')}());
            ${migrationVar}.decorateBannys(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                ${mergedDataFunctionName(contract, 'bannyV4TokenIds')}(),
                ${mergedDataFunctionName(contract, 'bannyTargetTokenIds')}(),
                ${mergedDataFunctionName(contract, 'bannyBackgroundTokenIds')}(),
                ${mergedDataFunctionName(contract, 'bannyOutfitOffsets')}(),
                ${mergedDataFunctionName(contract, 'bannyOutfitTokenIds')}()
            );
            ${migrationVar}.transferRegular(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                ${ownersVar},
                ${mergedDataFunctionName(contract, 'regularTargetTokenIds')}(),
                ${mergedDataFunctionName(contract, 'regularV4TokenIds')}(),
                ${mergedDataFunctionName(contract, 'regularAllowResolverOwners')}()
            );
            ${migrationVar}.transferUnused(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                ${ownersVar},
                ${contract.regularTransferItems.length},
                ${mergedDataFunctionName(contract, 'unusedTargetTokenIds')}(),
                ${mergedDataFunctionName(contract, 'unusedV4TokenIds')}(),
                ${mergedDataFunctionName(contract, 'unusedAllowResolverOwners')}()
            );
            ${migrationVar}.requireNoBalance(hookAddress);
            console.log("${contract.contractName} migrated", mintedTokenIds.length, "tokens");
        }
`;
                return;
            }

            body += `
        if (_shouldRunChunk(chunkFilter, maxChunkFilter, ${chunkIndex + 1})) {
            uint16[] memory ${tierIdsVar} = new uint16[](${contract.assignments.tierIds.length});
${generateTierIdLoops(contract.assignments.tierIds, tierIdsVar)}
            address[] memory ${ownersVar} = ${transferOwnerFunctionName(contract)}();
            ${contract.contractName} ${migrationVar} = new ${contract.contractName}(${ownersVar});
            uint256[] memory mintedTokenIds = hook.mintFor(${tierIdsVar}, address(${migrationVar}));
            ${migrationVar}.requireMintedTokenIds(mintedTokenIds);
            ${migrationVar}.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("${contract.contractName} migrated", mintedTokenIds.length, "tokens");
        }
`;
        });

        body += `    }
`;
        return body;
    }).join('\n');

    return `// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, stdJson} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
${imports}
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";

contract ${scriptContractName(options)} is Script, Sphinx {
    using stdJson for string;

    address private constant V6_MAINNET_HOOK = ${V6_MAINNET_HOOK};
    address private constant V4_HOOK = ${V4_HOOK};
    address private constant V4_RESOLVER = ${V4_RESOLVER};
    address private constant V4_RESOLVER_FALLBACK = ${V4_RESOLVER_FALLBACK};

    JB721TiersHook private v6Hook;

    ${coverageReport}

    function configureSphinx() public override {
        sphinxConfig.projectName = vm.envOr("BANNY_AIRDROP_SPHINX_PROJECT", string("banny-core"));
${sphinxNetworkConfig(options)}
    }

    function run() public {
        v6Hook = JB721TiersHook(_deploymentAddressOf("JB721TiersHook__ProjectBAN"));
        if (_shouldVerifyV4State()) {
            require(address(v6Hook) == V6_MAINNET_HOOK, "Unexpected mainnet V6 hook");
        }
        deploy();
    }

    function deploy() public sphinx {
        _run();
    }

    function _run() internal {
        uint256 chainId = _sourceChainId();

        if (chainId == 1) {
            _runEthereum();
        } else if (chainId == 10) {
            _runOptimism();
        } else if (chainId == 8453) {
            _runBase();
        } else if (chainId == 42161) {
            _runArbitrum();
        } else {
            revert("Unsupported chain");
        }
    }

    function _sourceChainId() internal view returns (uint256) {
        uint256 chainId = block.chainid;

        if (chainId == 1 || chainId == 11155111) return 1;
        if (chainId == 10 || chainId == 11155420) return 10;
        if (chainId == 8453 || chainId == 84532) return 8453;
        if (chainId == 42161 || chainId == 421614) return 42161;

        revert("Unsupported chain");
    }

    function _shouldVerifyV4State() internal view returns (bool) {
        uint256 chainId = block.chainid;
        return chainId == 1 || chainId == 10 || chainId == 8453 || chainId == 42161;
    }

    function _v6Hook() internal view returns (JB721TiersHook) {
        require(address(v6Hook) != address(0), "V6 hook not set");
        return v6Hook;
    }

    function _resolverOf(JB721TiersHook hook) internal view returns (address resolverAddress) {
        resolverAddress = address(hook.STORE().tokenUriResolverOf(address(hook)));
        require(resolverAddress != address(0), "V6 resolver not set");
    }

    function _deploymentAddressOf(string memory name) internal view returns (address addr) {
        string memory root = vm.envOr("BANNY_AIRDROP_DEPLOYMENTS_PATH", string("../deploy-all-v6/deployments/"));
        string memory path = string.concat(root, _chainFolder(), "/", name, ".json");
        string memory json = vm.readFile(path);
        addr = json.readAddress(".address");
        require(addr != address(0), "Missing deployment address");
    }

    function _chainFolder() internal view returns (string memory) {
        if (block.chainid == 1) return "ethereum";
        if (block.chainid == 11155111) return "sepolia";
        if (block.chainid == 10) return "optimism";
        if (block.chainid == 11155420) return "optimism_sepolia";
        if (block.chainid == 8453) return "base";
        if (block.chainid == 84532) return "base_sepolia";
        if (block.chainid == 42161) return "arbitrum";
        if (block.chainid == 421614) return "arbitrum_sepolia";
        revert("Unsupported chain");
    }

    function _chunkFilter() internal view returns (uint256) {
        return vm.envOr("BANNY_AIRDROP_CHUNK", uint256(0));
    }

    function _maxChunkFilter() internal view returns (uint256) {
        return vm.envOr("BANNY_AIRDROP_MAX_CHUNK", uint256(0));
    }

    function _requireValidChunkFilters(uint256 chunkFilter, uint256 maxChunkFilter, uint256 maxChunk) internal pure {
        require(chunkFilter == 0 || maxChunkFilter == 0, "Choose exact chunk or max chunk");
        require(chunkFilter <= maxChunk, "Invalid BANNY_AIRDROP_CHUNK");
        require(maxChunkFilter <= maxChunk, "Invalid BANNY_AIRDROP_MAX_CHUNK");
    }

    function _shouldRunChunk(uint256 chunkFilter, uint256 maxChunkFilter, uint256 chunk) internal pure returns (bool) {
        if (chunkFilter != 0) return chunkFilter == chunk;
        if (maxChunkFilter != 0) return chunk <= maxChunkFilter;
        return true;
    }

${chainRunFunctions}
${transferOwnerFunctions}
${mergedDataFunctions}
}
`;
}

function generateExpectedMintCheck(expectedTokenIds) {
    let code = `    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == ${expectedTokenIds.length}, "Minted token count mismatch");
`;

    expectedTokenIds.forEach((tokenId, index) => {
        code += `        require(mintedTokenIds[${index}] == ${tokenId}, "Minted token ID mismatch");\n`;
    });

    code += `    }
`;
    return code;
}

function generateTokenArrayAssignments(varName, transferItems, v4ToV6TokenIds, useTargetIds) {
    let code = '';
    transferItems.forEach((entry, index) => {
        const v4TokenId = itemTokenId(entry.item);
        const targetTokenId = v4ToV6TokenIds.get(v4TokenId);
        const value = useTargetIds ? targetTokenId : v4TokenId;
        if (!value) {
            throw new Error(`No V6 token ID assignment found for V4 token ${v4TokenId}`);
        }
        code += `        ${varName}[${index}] = ${value}; // V4 ${v4TokenId}\n`;
    });
    return code;
}

function generateBoolArrayAssignments(varName, transferItems, propertyName) {
    let code = '';
    transferItems.forEach((entry, index) => {
        if (entry[propertyName]) {
            code += `        ${varName}[${index}] = true;\n`;
        }
    });
    return code;
}

function generateOutfitAssignments(outfitIds, v4ToV6TokenIds) {
    let code = '';
    outfitIds.forEach((v4OutfitId, index) => {
        const v6OutfitId = v4ToV6TokenIds.get(v4OutfitId);
        if (!v6OutfitId) {
            throw new Error(`No V6 token ID assignment found for V4 outfit ${v4OutfitId}`);
        }
        code += `            outfitIds[${index}] = ${v6OutfitId}; // V4 ${v4OutfitId}\n`;
    });
    return code;
}

function generateDressCalls(contract) {
    let code = '';

    contract.bannies.forEach(banny => {
        const v6BodyId = contract.assignments.v4ToV6TokenIds.get(banny.tokenId);
        if (!v6BodyId) {
            throw new Error(`No V6 token ID assignment found for V4 body ${banny.tokenId}`);
        }

        code += `
        {
            require(${v6BodyId} == ${banny.tokenId}, "Body token ID changed");
`;

        if (banny.backgroundId !== 0 || banny.outfitIds.length !== 0) {
            const v6BackgroundId =
                banny.backgroundId === 0 ? 0 : contract.assignments.v4ToV6TokenIds.get(banny.backgroundId);
            if (banny.backgroundId !== 0 && !v6BackgroundId) {
                throw new Error(`No V6 token ID assignment found for V4 background ${banny.backgroundId}`);
            }

            code += `            // Dress Banny ${banny.tokenId} (${banny.productName})
            uint256[] memory outfitIds = new uint256[](${banny.outfitIds.length});
${generateOutfitAssignments(banny.outfitIds, contract.assignments.v4ToV6TokenIds)}
            resolver.decorateBannyWith(address(hook), ${v6BodyId}, ${v6BackgroundId}, outfitIds);
`;
        }

        code += `            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    ${banny.tokenId}
                );
            }
        }
`;
    });

    return code;
}

function generateCoverageReport(contractsByChain, items) {
    const coveredTokenIds = new Set();
    Object.values(contractsByChain).flat().forEach(contract => {
        contract.allItems.forEach(item => coveredTokenIds.add(itemCoverageKey(item)));
    });

    const missingItems = items.filter(item => !coveredTokenIds.has(itemCoverageKey(item)));
    if (missingItems.length === 0) {
        return '// All raw.json items are minted by this script.';
    }

    const rows = missingItems.map(item => {
        const metadata = item.metadata;
        return `// Excluded by inherited resolver-owned/unused filtering: chain ${item.chainId}, token ${metadata.tokenId}, UPC ${metadata.upc}, category ${metadata.category}, owner ${itemOwner(item)}.`;
    });

    return rows.join('\n');
}

function generateRegularExecute(contract) {
    const transferCount = contract.transferItems.length;

    return `    function executeMigration(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        IERC721 v4Hook = IERC721(v4HookAddress);
        Banny721TokenUriResolver resolver = Banny721TokenUriResolver(resolverAddress);
        Banny721TokenUriResolver v4Resolver = Banny721TokenUriResolver(v4ResolverAddress);
        Banny721TokenUriResolver fallbackV4Resolver = Banny721TokenUriResolver(fallbackV4ResolverAddress);

        token.setApprovalForAll(address(resolver), true);
${generateDressCalls(contract)}
        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
${generateTokenArrayAssignments('targetTokenIds', contract.transferItems, contract.assignments.v4ToV6TokenIds, true)}
${generateTokenArrayAssignments('v4TokenIds', contract.transferItems, contract.assignments.v4ToV6TokenIds, false)}
${generateBoolArrayAssignments('allowResolverOwners', contract.transferItems, 'allowResolverOwner')}
        uint256 successfulTransfers;

        for (uint256 i; i < transferOwners.length; i++) {
            uint256 targetTokenId = targetTokenIds[i];
            uint256 v4TokenId = v4TokenIds[i];
            address expectedOwner = transferOwners[i];

            if (verifyV4State) {
                address v4Owner = v4Hook.ownerOf(v4TokenId);

                if (v4Owner == address(v4ResolverAddress)) {
                    require(allowResolverOwners[i], "Token owned by main resolver in V4 - should not be standalone");
                } else if (v4Owner == address(fallbackV4ResolverAddress)) {
                    require(
                        expectedOwner != address(v4ResolverAddress)
                            && expectedOwner != address(fallbackV4ResolverAddress),
                        "Fallback resolver owner cannot receive standalone token"
                    );
                } else {
                    require(v4Owner == expectedOwner, "V4/V6 ownership mismatch for token");
                }
            }

            require(token.ownerOf(targetTokenId) == address(this), "Contract does not own token");
            token.safeTransferFrom(address(this), expectedOwner, targetTokenId);
            successfulTransfers++;
        }

        require(successfulTransfers == ${transferCount}, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }
`;
}

function generateUnusedExecute(contract) {
    const transferCount = contract.transferItems.length;

    return `    function executeMigration(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        IERC721 v4Hook = IERC721(v4HookAddress);

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
${generateTokenArrayAssignments('targetTokenIds', contract.transferItems, contract.assignments.v4ToV6TokenIds, true)}
${generateTokenArrayAssignments('v4TokenIds', contract.transferItems, contract.assignments.v4ToV6TokenIds, false)}
${generateBoolArrayAssignments('allowResolverOwners', contract.transferItems, 'allowResolverOwner')}
        uint256 successfulTransfers;

        for (uint256 i; i < transferOwners.length; i++) {
            uint256 targetTokenId = targetTokenIds[i];
            uint256 v4TokenId = v4TokenIds[i];
            address expectedOwner = transferOwners[i];

            if (verifyV4State) {
                address v4Owner = v4Hook.ownerOf(v4TokenId);

                if (v4Owner == address(v4ResolverAddress)) {
                    require(allowResolverOwners[i], "Token owned by main resolver in V4 - should not be standalone");
                } else if (v4Owner == address(fallbackV4ResolverAddress)) {
                    require(
                        expectedOwner != address(v4ResolverAddress)
                            && expectedOwner != address(fallbackV4ResolverAddress),
                        "Fallback resolver owner cannot receive standalone token"
                    );
                } else {
                    require(v4Owner == expectedOwner, "V4/V6 ownership mismatch for token");
                }
            }

            require(token.ownerOf(targetTokenId) == address(this), "Contract does not own token");
            token.safeTransferFrom(address(this), expectedOwner, targetTokenId);
            successfulTransfers++;
        }

        require(successfulTransfers == ${transferCount}, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }
`;
}

function generateMergedExecute(contract) {
    return `    function decorateBannys(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State,
        uint256[] calldata bannyV4TokenIds,
        uint256[] calldata bannyTargetTokenIds,
        uint256[] calldata bannyBackgroundTokenIds,
        uint256[] calldata bannyOutfitOffsets,
        uint256[] calldata bannyOutfitTokenIds
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        require(
            bannyV4TokenIds.length == bannyTargetTokenIds.length
                && bannyV4TokenIds.length == bannyBackgroundTokenIds.length
                && bannyOutfitOffsets.length == bannyV4TokenIds.length + 1,
            "Banny data length mismatch"
        );

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        Banny721TokenUriResolver resolver = Banny721TokenUriResolver(resolverAddress);
        Banny721TokenUriResolver v4Resolver = Banny721TokenUriResolver(v4ResolverAddress);
        Banny721TokenUriResolver fallbackV4Resolver = Banny721TokenUriResolver(fallbackV4ResolverAddress);

        token.setApprovalForAll(address(resolver), true);

        for (uint256 i; i < bannyV4TokenIds.length; i++) {
            uint256 bannyTargetTokenId = bannyTargetTokenIds[i];
            require(bannyTargetTokenId == bannyV4TokenIds[i], "Body token ID changed");
            uint256 outfitStart = bannyOutfitOffsets[i];
            uint256 outfitEnd = bannyOutfitOffsets[i + 1];
            require(outfitEnd >= outfitStart && outfitEnd <= bannyOutfitTokenIds.length, "Banny outfit offset mismatch");
            uint256 outfitCount = outfitEnd - outfitStart;

            if (bannyBackgroundTokenIds[i] != 0 || outfitCount != 0) {
                uint256[] memory outfitTokenIds = new uint256[](outfitCount);
                for (uint256 j; j < outfitCount; j++) {
                    outfitTokenIds[j] = bannyOutfitTokenIds[outfitStart + j];
                }
                resolver.decorateBannyWith(
                    address(hook), bannyTargetTokenId, bannyBackgroundTokenIds[i], outfitTokenIds
                );
            }

            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    bannyV4TokenIds[i]
                );
            }
        }
    }

    function transferRegular(
        address hookAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State,
        address[] calldata transferOwners,
        uint256[] calldata regularTargetTokenIds,
        uint256[] calldata regularV4TokenIds,
        bool[] calldata regularAllowResolverOwners
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        require(regularTargetTokenIds.length == regularV4TokenIds.length, "Regular transfer data mismatch");
        require(regularTargetTokenIds.length == regularAllowResolverOwners.length, "Regular resolver data mismatch");
        require(transferOwners.length >= regularTargetTokenIds.length, "Transfer owner count mismatch");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        IERC721 v4Hook = IERC721(v4HookAddress);

        uint256 successfulRegularTransfers;

        for (uint256 i; i < regularTargetTokenIds.length; i++) {
            address expectedOwner = transferOwners[i];

            if (verifyV4State) {
                _verifyStandaloneV4Owner(
                    v4Hook,
                    regularV4TokenIds[i],
                    expectedOwner,
                    v4ResolverAddress,
                    fallbackV4ResolverAddress,
                    regularAllowResolverOwners[i]
                );
            }

            require(token.ownerOf(regularTargetTokenIds[i]) == address(this), "Contract does not own token");
            token.safeTransferFrom(address(this), expectedOwner, regularTargetTokenIds[i]);
            successfulRegularTransfers++;
        }

        require(
            successfulRegularTransfers == regularTargetTokenIds.length,
            "Not all regular items were transferred"
        );
    }

    function transferUnused(
        address hookAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State,
        address[] calldata transferOwners,
        uint256 ownerOffset,
        uint256[] calldata unusedTargetTokenIds,
        uint256[] calldata unusedV4TokenIds,
        bool[] calldata unusedAllowResolverOwners
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        require(unusedTargetTokenIds.length == unusedV4TokenIds.length, "Unused transfer data mismatch");
        require(unusedTargetTokenIds.length == unusedAllowResolverOwners.length, "Unused resolver data mismatch");
        require(transferOwners.length >= ownerOffset + unusedTargetTokenIds.length, "Transfer owner count mismatch");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        IERC721 v4Hook = IERC721(v4HookAddress);

        uint256 successfulUnusedTransfers;

        for (uint256 i; i < unusedTargetTokenIds.length; i++) {
            address expectedOwner = transferOwners[ownerOffset + i];

            if (verifyV4State) {
                _verifyStandaloneV4Owner(
                    v4Hook,
                    unusedV4TokenIds[i],
                    expectedOwner,
                    v4ResolverAddress,
                    fallbackV4ResolverAddress,
                    unusedAllowResolverOwners[i]
                );
            }

            require(token.ownerOf(unusedTargetTokenIds[i]) == address(this), "Contract does not own token");
            token.safeTransferFrom(address(this), expectedOwner, unusedTargetTokenIds[i]);
            successfulUnusedTransfers++;
        }

        require(successfulUnusedTransfers == unusedTargetTokenIds.length, "Not all unused items were transferred");
    }

    function requireNoBalance(address hookAddress) external view {
        JB721TiersHook hook = JB721TiersHook(hookAddress);
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

    function _verifyStandaloneV4Owner(
        IERC721 v4Hook,
        uint256 v4TokenId,
        address expectedOwner,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool allowResolverOwner
    )
        private
        view
    {
        address v4Owner = v4Hook.ownerOf(v4TokenId);

        if (v4Owner == address(v4ResolverAddress)) {
            require(allowResolverOwner, "Token owned by main resolver in V4 - should not be standalone");
        } else if (v4Owner == address(fallbackV4ResolverAddress)) {
            require(
                expectedOwner != address(v4ResolverAddress) && expectedOwner != address(fallbackV4ResolverAddress),
                "Fallback resolver owner cannot receive standalone token"
            );
        } else {
            require(v4Owner == expectedOwner, "V4/V6 ownership mismatch for token");
        }
    }
`;
}

function generateDynamicExpectedMintCheck() {
    return `    function requireMintedTokenIds(
        uint256[] calldata mintedTokenIds,
        uint256[] calldata expectedTokenIds
    )
        external
        pure
    {
        require(mintedTokenIds.length == expectedTokenIds.length, "Minted token count mismatch");
        for (uint256 i; i < expectedTokenIds.length; i++) {
            require(mintedTokenIds[i] == expectedTokenIds[i], "Minted token ID mismatch");
        }
    }
`;
}

function generateAirdropContract(contract) {
    const constructorCode = contract.isMerged
        ? ''
        : `    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == ${contract.transferItems.length}, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }
`;
    const mintCheck = contract.isMerged
        ? generateDynamicExpectedMintCheck()
        : generateExpectedMintCheck(contract.assignments.expectedTokenIds);
    const execute = contract.isMerged
        ? generateMergedExecute(contract)
        : contract.isUnused
          ? generateUnusedExecute(contract)
          : generateRegularExecute(contract);

    return `// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract ${contract.contractName} {
${constructorCode}

${mintCheck}

${execute}
}
`;
}

function topLevelScriptOptions(options = {}) {
    if (isCombined(options) && !options.networkProfile) {
        return [
            { ...options, networkProfile: 'mainnets' },
            { ...options, networkProfile: 'testnets' },
        ];
    }

    return [options];
}

function writeGeneratedFiles(contractsByChain, items, options = {}) {
    const scriptDir = path.join(__dirname, '..');
    const coverageReport = generateCoverageReport(contractsByChain, items);

    topLevelScriptOptions(options).forEach(topLevelOptions => {
        const topLevelScript = generateTopLevelScript(contractsByChain, coverageReport, topLevelOptions);
        fs.writeFileSync(path.join(scriptDir, scriptFileName(topLevelOptions)), topLevelScript);
    });

    Object.values(contractsByChain).flat().forEach(contract => {
        fs.writeFileSync(path.join(scriptDir, contract.fileName), generateAirdropContract(contract));
    });
}

function summarize(contractsByChain, items, options = {}) {
    const mode = isCombined(options) ? 'combined' : 'chunked';
    console.log(`\n=== V6 airdrop generation summary (${mode}) ===`);
    Object.entries(contractsByChain).forEach(([chainId, contracts]) => {
        const minted = contracts.reduce((total, contract) => total + contract.assignments.tierIds.length, 0);
        const transferred = contracts.reduce((total, contract) => total + contract.transferItems.length, 0);
        console.log(
            `${contracts[0].chain.name} (${chainId}): ${contracts.length} contracts, ${minted} mints, ${transferred} direct transfers`,
        );
    });

    const coveredTokenIds = new Set();
    Object.values(contractsByChain).flat().forEach(contract => {
        contract.allItems.forEach(item => coveredTokenIds.add(itemCoverageKey(item)));
    });
    const missingItems = items.filter(item => !coveredTokenIds.has(itemCoverageKey(item)));
    if (missingItems.length > 0) {
        console.log(`${missingItems.length} raw item(s) excluded by inherited resolver-owned/unused filtering.`);
    }
}

function generate(options = {}) {
    const items = loadRawItems();
    const contractsByChain = isCombined(options) ? buildCombinedContractsByChain(items) : buildContractsByChain(items);

    writeGeneratedFiles(contractsByChain, items, options);
    summarize(contractsByChain, items, options);
    return { contractsByChain, items };
}

function loadRawItems() {
    const rawDataPath = path.join(__dirname, 'raw.json');
    const rawData = JSON.parse(fs.readFileSync(rawDataPath, 'utf8'));
    return rawData.data.nfts.items;
}

function buildContractsByChain(items) {
    const contractsByChain = {};
    CHAINS.forEach(chain => {
        contractsByChain[chain.id] = makeChainPlan(items, chain);
    });
    return contractsByChain;
}

function buildCombinedContractsByChain(items) {
    const contractsByChain = {};
    CHAINS.forEach(chain => {
        contractsByChain[chain.id] = makeCombinedChainPlan(items, chain);
    });
    return contractsByChain;
}

function cliNetworkProfile() {
    if (process.env.BANNY_AIRDROP_NETWORK_PROFILE === 'mainnets' || process.argv.includes('--mainnets')) {
        return 'mainnets';
    }
    if (process.env.BANNY_AIRDROP_NETWORK_PROFILE === 'testnets' || process.argv.includes('--testnets')) {
        return 'testnets';
    }
    return undefined;
}

function cliOptions() {
    return {
        combined:
            process.env.BANNY_AIRDROP_COMBINED === '1'
            || process.env.BANNY_AIRDROP_UNCHUNKED === '1'
            || process.argv.includes('--combined')
            || process.argv.includes('--unchunked'),
        networkProfile: cliNetworkProfile(),
    };
}

if (require.main === module) {
    generate(cliOptions());
}

module.exports = {
    buildContractsByChain,
    buildCombinedContractsByChain,
    buildUnchunkedContractsByChain: buildCombinedContractsByChain,
    CHAINS,
    generate,
    itemCategory,
    itemCoverageKey,
    itemOwner,
    itemProductName,
    itemTokenId,
    itemUpc,
    loadRawItems,
    makeChainPlan,
    ZERO_ADDRESS,
};
