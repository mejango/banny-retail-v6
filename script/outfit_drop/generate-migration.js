#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const createKeccakHash = require('keccak');

function toChecksumAddress(address) {
    if (!/^(0x)?[0-9a-f]{40}$/i.test(address)) {
        // Not a valid address format, return as is
        return address;
    }
    address = address.toLowerCase().replace('0x', '');
    const hash = createKeccakHash('keccak256').update(address).digest('hex');
    let checksumAddress = '0x';

    for (let i = 0; i < address.length; i++) {
        // If the i-th hex character is greater than 7, use the uppercase char, otherwise lowercase
        checksumAddress += parseInt(hash[i], 16) >= 8 ? address[i].toUpperCase() : address[i];
    }

    return checksumAddress;
}

// V4 to V5 migration script generator
// Generates contract-based migration scripts and chain-specific contracts from raw.json
// Note: Outfit IDs are generated automatically when minting in V5
// The system handles V4 to V5 category mapping internally

function generateMigrationScript() {
    // Generate contract-based migration script and chain-specific contracts from raw.json
    generateScriptForFile('raw.json', 'AirdropOutfits.s.sol');

    // Generate batch scripts for debugging
    generateBatchScripts('raw.json');

    // Generate chain-specific migration contracts
    generateChainSpecificContracts('raw.json');
}

function generateScriptForFile(inputFile, outputFile) {
    console.log(`\n=== Generating ${outputFile} from ${inputFile} ===`);

    // Load the raw data
    const rawDataPath = path.join(__dirname, inputFile);
    const rawData = JSON.parse(fs.readFileSync(rawDataPath, 'utf8'));

    const items = rawData.data.nfts.items;

    // Calculate tier IDs for each chain and chunks
    const ethereumItems = items.filter(item => item.chainId === 1);
    const optimismItems = items.filter(item => item.chainId === 10);
    const baseItems = items.filter(item => item.chainId === 8453);
    const arbitrumItems = items.filter(item => item.chainId === 42161);

    // Calculate chunk-specific tier IDs for Ethereum (6 chunks), Base (4 chunks), and Arbitrum (3 chunks)
    // Increased from 5/3 to 6/4 due to smaller BATCH_SIZE (100 vs 150)
    const ethereumChunks = splitBanniesIntoChunks(ethereumItems, 6);
    const baseChunks = splitBanniesIntoChunks(baseItems, 4);
    const arbitrumChunks = splitBanniesIntoChunks(arbitrumItems, 3);

    const ethereumTierIds = [];
    const ethereumChunkTierIds = [];
    ethereumChunks.forEach((chunk, index) => {
        const tierIdQuantities = new Map();
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        const tierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                tierIds.push(upc);
            }
        });
        ethereumChunkTierIds.push(tierIds);
        if (index === 0) ethereumTierIds.push(...tierIds);
    });
    
    // Collect all token IDs already processed in Ethereum chunks 1-6
    // These should NOT be included in MigrationContractEthereum7
    const ethereumProcessedTokenIds = new Set();
    ethereumChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const tokenId = item.metadata.tokenId;
            ethereumProcessedTokenIds.add(Number(tokenId));
        });
    });
    
    // Calculate UPC counts from CHUNKS ONLY (not all items) to determine starting unit numbers
    // This tells us how many tokens of each UPC were already minted in previous chunks
    const ethereumUpcCountsFromChunks = new Map();
    ethereumChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            ethereumUpcCountsFromChunks.set(upc, (ethereumUpcCountsFromChunks.get(upc) || 0) + 1);
        });
    });
    // Convert counts to starting unit numbers (1-indexed, so add 1)
    const ethereumUpcStartingUnitNumbers = new Map();
    ethereumUpcCountsFromChunks.forEach((count, upc) => {
        ethereumUpcStartingUnitNumbers.set(upc, count + 1);
    });
    // Calculate unused assets tier IDs for Ethereum (split into 2 chunks)
    const ethereumUnusedData = generateUnusedAssetsContract({ id: 1, name: 'Ethereum', numChunks: 6 }, ethereumItems, ethereumUpcStartingUnitNumbers, ethereumProcessedTokenIds);
    let ethereumUnusedTierIds7 = [];
    let ethereumUnusedTierIds8 = [];
    if (ethereumUnusedData && ethereumUnusedData.unusedItems.length > 0) {
        const allUnusedTierIds = [];
        ethereumUnusedData.unusedItems.forEach(item => {
            allUnusedTierIds.push(item.upc);
        });
        // Split into two chunks
        const midPoint = Math.ceil(allUnusedTierIds.length / 2);
        ethereumUnusedTierIds7 = allUnusedTierIds.slice(0, midPoint);
        ethereumUnusedTierIds8 = allUnusedTierIds.slice(midPoint);
        ethereumChunkTierIds.push(ethereumUnusedTierIds7);
        if (ethereumUnusedTierIds8.length > 0) {
            ethereumChunkTierIds.push(ethereumUnusedTierIds8);
        }
    }

    const baseTierIds = [];
    const baseChunkTierIds = [];
    baseChunks.forEach((chunk, index) => {
        const tierIdQuantities = new Map();
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        const tierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                tierIds.push(upc);
            }
        });
        baseChunkTierIds.push(tierIds);
        if (index === 0) baseTierIds.push(...tierIds);
    });
    
    // Collect all token IDs already processed in Base chunks 1-4
    // These should NOT be included in MigrationContractBase5
    const baseProcessedTokenIds = new Set();
    baseChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const tokenId = item.metadata.tokenId;
            baseProcessedTokenIds.add(Number(tokenId));
        });
    });
    
    // Calculate UPC counts from CHUNKS ONLY (not all items) to determine starting unit numbers
    // This tells us how many tokens of each UPC were already minted in previous chunks
    const baseUpcCountsFromChunks = new Map();
    baseChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            baseUpcCountsFromChunks.set(upc, (baseUpcCountsFromChunks.get(upc) || 0) + 1);
        });
    });
    // Convert counts to starting unit numbers (1-indexed, so add 1)
    const baseUpcStartingUnitNumbers = new Map();
    baseUpcCountsFromChunks.forEach((count, upc) => {
        baseUpcStartingUnitNumbers.set(upc, count + 1);
    });
    // Calculate unused assets tier IDs for Base
    const baseUnusedData = generateUnusedAssetsContract({ id: 8453, name: 'Base', numChunks: 4 }, baseItems, baseUpcStartingUnitNumbers, baseProcessedTokenIds);
    let baseUnusedTierIds = [];
    if (baseUnusedData && baseUnusedData.unusedItems && baseUnusedData.unusedItems.length > 0) {
        baseUnusedData.unusedItems.forEach(item => {
            baseUnusedTierIds.push(item.upc);
        });
        baseChunkTierIds.push(baseUnusedTierIds);
        console.log(`Added Base unused chunk with ${baseUnusedTierIds.length} tier IDs`);
    } else {
        console.log(`No Base unused items found (unusedData: ${!!baseUnusedData}, unusedItems: ${baseUnusedData?.unusedItems?.length || 0})`);
    }

    // Build tier ID arrays for single-contract chains
    const optimismTierIds = [];

    // Optimism - single contract
    {
        const tierIdQuantities = new Map();
        optimismItems.forEach(item => {
            const upc = item.metadata.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });

        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                optimismTierIds.push(upc);
            }
        });
    }

    // Arbitrum - 3 chunks (similar to Base)
    const arbitrumChunkTierIds = [];
    arbitrumChunks.forEach((chunk) => {
        const tierIdQuantities = new Map();
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        const tierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                tierIds.push(upc);
            }
        });
        arbitrumChunkTierIds.push(tierIds);
    });

    // Generate the contract-based migration script
    const script = generateContractVersion(items, { 
        ethereumTierIds, 
        ethereumChunkTierIds,
        optimismTierIds, 
        baseTierIds,
        baseChunkTierIds,
        arbitrumChunkTierIds 
    });

    // Write the script to file
    const outputPath = path.join(__dirname, '..', outputFile);
    fs.writeFileSync(outputPath, script);

    console.log(`Generated migration script with chain-specific filtering`);
    console.log(`Script written to: ${outputPath}`);
}

function generateBatchScripts(inputFile) {
    console.log(`\n=== Generating batch scripts from ${inputFile} ===`);

    // Load the raw data
    const rawDataPath = path.join(__dirname, inputFile);
    const rawData = JSON.parse(fs.readFileSync(rawDataPath, 'utf8'));

    const items = rawData.data.nfts.items;

    // Calculate tier IDs for each chain and chunks
    const ethereumItems = items.filter(item => item.chainId === 1);
    const optimismItems = items.filter(item => item.chainId === 10);
    const baseItems = items.filter(item => item.chainId === 8453);
    const arbitrumItems = items.filter(item => item.chainId === 42161);

    // Calculate chunk-specific tier IDs for Ethereum (6 chunks), Base (4 chunks), and Arbitrum (3 chunks)
    // Increased from 5/3 to 6/4 due to smaller BATCH_SIZE (100 vs 150)
    const ethereumChunks = splitBanniesIntoChunks(ethereumItems, 6);
    const baseChunks = splitBanniesIntoChunks(baseItems, 4);
    const arbitrumChunks = splitBanniesIntoChunks(arbitrumItems, 3);

    // Calculate tier IDs for each chunk
    const ethereumChunkTierIds = [];
    ethereumChunks.forEach((chunk) => {
        const tierIdQuantities = new Map();
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        const tierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                tierIds.push(upc);
            }
        });
        ethereumChunkTierIds.push(tierIds);
    });

    // Calculate unused assets for Ethereum (chunk 4)
    const ethereumProcessedTokenIds = new Set();
    ethereumChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const tokenId = item.metadata.tokenId;
            ethereumProcessedTokenIds.add(Number(tokenId));
        });
    });
    
    const ethereumUpcCountsFromChunks = new Map();
    ethereumChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            ethereumUpcCountsFromChunks.set(upc, (ethereumUpcCountsFromChunks.get(upc) || 0) + 1);
        });
    });
    const ethereumUpcStartingUnitNumbers = new Map();
    ethereumUpcCountsFromChunks.forEach((count, upc) => {
        ethereumUpcStartingUnitNumbers.set(upc, count + 1);
    });
    
    const ethereumUnusedContractData = generateUnusedAssetsContract(
        { id: 1, name: 'Ethereum', numChunks: 6 },
        ethereumItems,
        ethereumUpcStartingUnitNumbers,
        ethereumProcessedTokenIds
    );
    
    let ethereumChunk7TierIds = [];
    let ethereumChunk8TierIds = [];
    if (ethereumUnusedContractData && ethereumUnusedContractData.unusedItems.length > 0) {
        const tierIdQuantities = new Map();
        ethereumUnusedContractData.unusedItems.forEach(item => {
            const upc = item.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        const allTierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                allTierIds.push(upc);
            }
        });
        
        // Split into two chunks
        const midPoint = Math.ceil(allTierIds.length / 2);
        ethereumChunk7TierIds = allTierIds.slice(0, midPoint);
        ethereumChunk8TierIds = allTierIds.slice(midPoint);
    }

    const baseChunkTierIds = [];
    baseChunks.forEach((chunk) => {
        const tierIdQuantities = new Map();
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        const tierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                tierIds.push(upc);
            }
        });
        baseChunkTierIds.push(tierIds);
    });

    // Calculate unused assets for Base (chunk 3)
    const baseProcessedTokenIds = new Set();
    baseChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const tokenId = item.metadata.tokenId;
            baseProcessedTokenIds.add(Number(tokenId));
        });
    });
    
    const baseUpcCountsFromChunks = new Map();
    baseChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            baseUpcCountsFromChunks.set(upc, (baseUpcCountsFromChunks.get(upc) || 0) + 1);
        });
    });
    const baseUpcStartingUnitNumbers = new Map();
    baseUpcCountsFromChunks.forEach((count, upc) => {
        baseUpcStartingUnitNumbers.set(upc, count + 1);
    });
    
    const baseUnusedContractData = generateUnusedAssetsContract(
        { id: 8453, name: 'Base', numChunks: 4 },
        baseItems,
        baseUpcStartingUnitNumbers,
        baseProcessedTokenIds
    );
    
    let baseChunk3TierIds = null;
    if (baseUnusedContractData && baseUnusedContractData.unusedItems.length > 0) {
        const tierIdQuantities = new Map();
        baseUnusedContractData.unusedItems.forEach(item => {
            const upc = item.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        baseChunk3TierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                baseChunk3TierIds.push(upc);
            }
        });
    }

    // Calculate Optimism tier IDs
    const optimismTierIdQuantities = new Map();
    optimismItems.forEach(item => {
        const upc = item.metadata.upc;
        optimismTierIdQuantities.set(upc, (optimismTierIdQuantities.get(upc) || 0) + 1);
    });
    const optimismUniqueUpcs = Array.from(optimismTierIdQuantities.keys()).sort((a, b) => a - b);
    const optimismTierIds = [];
    optimismUniqueUpcs.forEach(upc => {
        const quantity = optimismTierIdQuantities.get(upc);
        for (let i = 0; i < quantity; i++) {
            optimismTierIds.push(upc);
        }
    });

    // Calculate Arbitrum chunk tier IDs (3 chunks)
    const arbitrumChunkTierIds = [];
    arbitrumChunks.forEach((chunk) => {
        const tierIdQuantities = new Map();
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        const tierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                tierIds.push(upc);
            }
        });
        arbitrumChunkTierIds.push(tierIds);
    });
    
    // Calculate unused assets for Arbitrum (chunk 4)
    const arbitrumProcessedTokenIds = new Set();
    arbitrumChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const tokenId = item.metadata.tokenId;
            arbitrumProcessedTokenIds.add(Number(tokenId));
        });
    });
    
    const arbitrumUpcCountsFromChunks = new Map();
    arbitrumChunks.forEach(chunk => {
        chunk.allItems.forEach(item => {
            const upc = item.metadata.upc;
            arbitrumUpcCountsFromChunks.set(upc, (arbitrumUpcCountsFromChunks.get(upc) || 0) + 1);
        });
    });
    const arbitrumUpcStartingUnitNumbers = new Map();
    arbitrumUpcCountsFromChunks.forEach((count, upc) => {
        arbitrumUpcStartingUnitNumbers.set(upc, count + 1);
    });
    
    const arbitrumUnusedContractData = generateUnusedAssetsContract(
        { id: 42161, name: 'Arbitrum', numChunks: 3 },
        arbitrumItems,
        arbitrumUpcStartingUnitNumbers,
        arbitrumProcessedTokenIds
    );
    
    let arbitrumChunk4TierIds = null;
    if (arbitrumUnusedContractData && arbitrumUnusedContractData.unusedItems.length > 0) {
        const tierIdQuantities = new Map();
        arbitrumUnusedContractData.unusedItems.forEach(item => {
            const upc = item.upc;
            tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
        });
        const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
        arbitrumChunk4TierIds = [];
        uniqueUpcs.forEach(upc => {
            const quantity = tierIdQuantities.get(upc);
            for (let i = 0; i < quantity; i++) {
                arbitrumChunk4TierIds.push(upc);
            }
        });
        arbitrumChunkTierIds.push(arbitrumChunk4TierIds);
        console.log(`Added Arbitrum unused chunk with ${arbitrumChunk4TierIds.length} tier IDs`);
    } else {
        console.log(`No Arbitrum unused items found (unusedData: ${!!arbitrumUnusedContractData}, unusedItems: ${arbitrumUnusedContractData?.unusedItems?.length || 0})`);
    }

    // Build transfer data functions for all batches
    const tierIds = {
        ethereumChunkTierIds: [...ethereumChunkTierIds, ethereumChunk7TierIds, ethereumChunk8TierIds],
        baseChunkTierIds,
        optimismTierIds,
        arbitrumChunkTierIds
    };

    // Generate transfer data functions (reuse from generateContractVersion logic)
    const chains = [
        { id: 1, name: 'Ethereum', numChunks: 6 },
        { id: 10, name: 'Optimism', numChunks: 1 },
        { id: 8453, name: 'Base', numChunks: 4 },
        { id: 42161, name: 'Arbitrum', numChunks: 3 }
    ];

    let allTransferDataFunctions = '';

    chains.forEach(chain => {
        const chainItems = items.filter(item => item.chainId === chain.id);
        if (chainItems.length === 0) return;

        if (chain.numChunks > 1) {
            const chunks = splitBanniesIntoChunks(chainItems, chain.numChunks);
            chunks.forEach((chunk, chunkIndex) => {
                const transferData = chunk.transferData;
                allTransferDataFunctions += `
    function _get${chain.name}TransferOwners${chunkIndex + 1}() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${transferData.length});
        `;

                transferData.forEach((data, index) => {
                    allTransferDataFunctions += `
        transferOwners[${index}] = ${toChecksumAddress(data.owner)};`;
                });

                allTransferDataFunctions += `
        return transferOwners;
    }
    `;
            });
            
            // Generate transfer data function for unused assets (Ethereum, Base, and Arbitrum)
            if (chain.id === 1 || chain.id === 8453 || chain.id === 42161) {
                const processedTokenIds = new Set();
                chunks.forEach(chunk => {
                    chunk.allItems.forEach(item => {
                        const tokenId = item.metadata.tokenId;
                        processedTokenIds.add(Number(tokenId));
                    });
                });
                
                const upcCountsFromChunks = new Map();
                chunks.forEach(chunk => {
                    chunk.allItems.forEach(item => {
                        const upc = item.metadata.upc;
                        upcCountsFromChunks.set(upc, (upcCountsFromChunks.get(upc) || 0) + 1);
                    });
                });
                const upcStartingUnitNumbers = new Map();
                upcCountsFromChunks.forEach((count, upc) => {
                    upcStartingUnitNumbers.set(upc, count + 1);
                });
                
                const unusedContractData = generateUnusedAssetsContract(chain, chainItems, upcStartingUnitNumbers, processedTokenIds);
                if (unusedContractData && unusedContractData.unusedItems.length > 0) {
                    const chunkIndex = chain.numChunks;
                    allTransferDataFunctions += `
    function _get${chain.name}TransferOwners${chunkIndex + 1}() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${unusedContractData.unusedItems.length});
        `;

                    unusedContractData.unusedItems.forEach((item, index) => {
                        allTransferDataFunctions += `
        transferOwners[${index}] = ${toChecksumAddress(item.owner)};`;
                    });

                    allTransferDataFunctions += `
        return transferOwners;
    }
    `;
                }
            }
        } else {
            const transferData = buildTransferDataForChain(chainItems);

            allTransferDataFunctions += `
    function _get${chain.name}TransferOwners() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${transferData.length});
        `;

            transferData.forEach((data, index) => {
                allTransferDataFunctions += `
        transferOwners[${index}] = ${toChecksumAddress(data.owner)};`;
            });

            allTransferDataFunctions += `
        return transferOwners;
    }
    `;
        }
    });

    // Generate Batch 1 script (Ethereum 1, Optimism, Base 1, Arbitrum 1)
    generateBatchScript(1, {
        ethereum: ethereumChunkTierIds[0],
        optimism: optimismTierIds,
        base: baseChunkTierIds[0],
        arbitrum: arbitrumChunkTierIds[0]
    }, allTransferDataFunctions, items);

    // Generate Batch 2 script (Ethereum 2, Base 2, Arbitrum 2)
    generateBatchScript(2, {
        ethereum: ethereumChunkTierIds[1],
        base: baseChunkTierIds[1],
        arbitrum: arbitrumChunkTierIds[1]
    }, allTransferDataFunctions, items);

    // Generate Batch 3 script (Ethereum 3, Base 3, Arbitrum 3)
    generateBatchScript(3, {
        ethereum: ethereumChunkTierIds[2],
        base: baseChunkTierIds[2],
        arbitrum: arbitrumChunkTierIds[2]
    }, allTransferDataFunctions, items);

    // Generate Batch 4 script (Ethereum 4, Base 4, Arbitrum 4 - unused assets)
    const batch4TierIds = {
        ethereum: ethereumChunkTierIds[3],
        base: baseChunkTierIds[3]
    };
    // Add Arbitrum 4 (unused assets) if it exists
    if (arbitrumChunkTierIds.length > 3 && arbitrumChunkTierIds[3] && arbitrumChunkTierIds[3].length > 0) {
        batch4TierIds.arbitrum = arbitrumChunkTierIds[3];
    }
    generateBatchScript(4, batch4TierIds, allTransferDataFunctions, items);

    // Generate Batch 5 script (Ethereum 5, Base 5 - unused assets)
    const batch5TierIds = {
        ethereum: ethereumChunkTierIds[4]
    };
    if (baseChunk3TierIds && baseChunk3TierIds.length > 0) {
        batch5TierIds.base = baseChunk3TierIds;
    }
    generateBatchScript(5, batch5TierIds, allTransferDataFunctions, items);

    // Generate Batch 6 script (Ethereum 6)
    generateBatchScript(6, {
        ethereum: ethereumChunkTierIds[5]
    }, allTransferDataFunctions, items);

    // Generate Batch 7 script (Ethereum 7 - unused assets part 1)
    if (ethereumChunk7TierIds.length > 0) {
        generateBatchScript(7, {
            ethereum: ethereumChunk7TierIds
        }, allTransferDataFunctions, items);
    }
    
    // Generate Batch 8 script (Ethereum 8 - unused assets part 2)
    if (ethereumChunk8TierIds.length > 0) {
        generateBatchScript(8, {
            ethereum: ethereumChunk8TierIds
        }, allTransferDataFunctions, items);
    }
}

function generateBatchScript(batchNumber, tierIds, transferDataFunctions, items) {
    const scriptDir = path.join(__dirname, '..');
    const outputPath = path.join(scriptDir, `AirdropOutfitsBatch${batchNumber}.s.sol`);

    // Determine which chains this batch handles
    const hasEthereum = tierIds.ethereum && tierIds.ethereum.length > 0;
    const hasOptimism = tierIds.optimism && tierIds.optimism.length > 0;
    const hasBase = tierIds.base && tierIds.base.length > 0;
    const hasArbitrum = tierIds.arbitrum && tierIds.arbitrum.length > 0;

    // Determine which imports are needed
    let imports = '';
    if (hasEthereum) {
        // Ethereum batches 1-6 map to contracts 1-6, batch 7 (unused assets part 1) maps to contract 7, batch 8 (unused assets part 2) maps to contract 8
        const ethereumContractNum = (batchNumber === 7 || batchNumber === 8) ? batchNumber : batchNumber;
        imports += `import {MigrationContractEthereum${ethereumContractNum}} from "./MigrationContractEthereum${ethereumContractNum}.sol";\n`;
    }
    if (hasOptimism) {
        imports += `import {MigrationContractOptimism} from "./MigrationContractOptimism.sol";\n`;
    }
    if (hasBase) {
        // Base batches 1-4 map to contracts 1-4, batch 5 (unused assets) maps to contract 5
        const baseContractNum = batchNumber === 5 ? 5 : batchNumber;
        imports += `import {MigrationContractBase${baseContractNum}} from "./MigrationContractBase${baseContractNum}.sol";\n`;
    }
    if (hasArbitrum) {
        // Arbitrum batches 1-3 map to contracts 1-3, batch 4 (unused assets) maps to contract 4
        const arbitrumContractNum = batchNumber === 4 ? 4 : batchNumber;
        imports += `import {MigrationContractArbitrum${arbitrumContractNum}} from "./MigrationContractArbitrum${arbitrumContractNum}.sol";\n`;
    }

    // Generate run() function with only relevant chains
    let runFunction = `    function run() public sphinx {
        uint256 chainId = block.chainid;
        
        `;
    if (hasEthereum) {
        runFunction += `if (chainId == 1) {
            // Ethereum Mainnet
            _runEthereum();
        } else `;
    }
    if (hasOptimism) {
        runFunction += `if (chainId == 10) {
            // Optimism
            _runOptimism();
        } else `;
    }
    if (hasBase) {
        runFunction += `if (chainId == 8453) {
            // Base
            _runBase();
        } else `;
    }
    if (hasArbitrum) {
        runFunction += `if (chainId == 42161) {
            // Arbitrum
            _runArbitrum();
        } else `;
    }
    runFunction += `{
            revert("Unsupported chain for batch ${batchNumber}");
        }
    }`;

    // Generate chain-specific run functions
    let chainRunFunctions = '';
    if (hasEthereum) {
        chainRunFunctions += `
    function _runEthereum() internal {
        address hookAddress = ${toChecksumAddress('0xb4Ec363c2E7DB0cECA9AA1759338d7d1b49d1750')};
        address resolverAddress = ${toChecksumAddress('0x47c011146a4498a70e0bf2e4585acf9cade85954')};
        address v4HookAddress = ${toChecksumAddress('0x2da41cdc79ae49f2725ab549717b2dbcfc42b958')};
        address v4ResolverAddress = ${toChecksumAddress('0xa5f8911d4cfd60a6697479f078409434424fe666')};
        address terminalAddress = ${toChecksumAddress('0x2db6d704058e552defe415753465df8df0361846')};
        address v4ResolverFallback = ${toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3')};
        _processMigration(
            hookAddress,
            resolverAddress,
            v4HookAddress,
            v4ResolverAddress,
            terminalAddress,
            v4ResolverFallback,
            1
        );
    }
    
    `;
    }
    if (hasOptimism) {
        chainRunFunctions += `
    function _runOptimism() internal {
        address hookAddress = ${toChecksumAddress('0xb4Ec363c2E7DB0cECA9AA1759338d7d1b49d1750')};
        address resolverAddress = ${toChecksumAddress('0x47c011146a4498a70e0bf2e4585acf9cade85954')};
        address v4HookAddress = ${toChecksumAddress('0x2da41cdc79ae49f2725ab549717b2dbcfc42b958')};
        address v4ResolverAddress = ${toChecksumAddress('0xa5f8911d4cfd60a6697479f078409434424fe666')};
        address terminalAddress = ${toChecksumAddress('0x2db6d704058e552defe415753465df8df0361846')};
        address v4ResolverFallback = ${toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3')};
        _processMigration(
            hookAddress,
            resolverAddress,
            v4HookAddress,
            v4ResolverAddress,
            terminalAddress,
            v4ResolverFallback,
            10
        );
    }
    
    `;
    }
    if (hasBase) {
        chainRunFunctions += `
    function _runBase() internal {
        address hookAddress = ${toChecksumAddress('0xb4Ec363c2E7DB0cECA9AA1759338d7d1b49d1750')};
        address resolverAddress = ${toChecksumAddress('0x47c011146a4498a70e0bf2e4585acf9cade85954')};
        address v4HookAddress = ${toChecksumAddress('0x2da41cdc79ae49f2725ab549717b2dbcfc42b958')};
        address v4ResolverAddress = ${toChecksumAddress('0xa5f8911d4cfd60a6697479f078409434424fe666')};
        address terminalAddress = ${toChecksumAddress('0x2db6d704058e552defe415753465df8df0361846')};
        address v4ResolverFallback = ${toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3')};
        _processMigration(
            hookAddress,
            resolverAddress,
            v4HookAddress,
            v4ResolverAddress,
            terminalAddress,
            v4ResolverFallback,
            8453
        );
    }
    
    `;
    }
    if (hasArbitrum) {
        chainRunFunctions += `
    function _runArbitrum() internal {
        address hookAddress = ${toChecksumAddress('0xb4Ec363c2E7DB0cECA9AA1759338d7d1b49d1750')};
        address resolverAddress = ${toChecksumAddress('0x47c011146a4498a70e0bf2e4585acf9cade85954')};
        address v4HookAddress = ${toChecksumAddress('0x2da41cdc79ae49f2725ab549717b2dbcfc42b958')};
        address v4ResolverAddress = ${toChecksumAddress('0xa5f8911d4cfd60a6697479f078409434424fe666')};
        address terminalAddress = ${toChecksumAddress('0x2db6d704058e552defe415753465df8df0361846')};
        address v4ResolverFallback = ${toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3')};
        _processMigration(
            hookAddress,
            resolverAddress,
            v4HookAddress,
            v4ResolverAddress,
            terminalAddress,
            v4ResolverFallback,
            42161
        );
    }
    
    `;
    }

    // Generate _processMigration function with only relevant batches
    let processMigrationFunction = `
    function _processMigration(address hookAddress, address resolverAddress, address v4HookAddress, address v4ResolverAddress, address terminalAddress, address v4ResolverFallback, uint256 chainId) internal {
        // Validate addresses
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(terminalAddress != address(0), "Terminal address not set");
        
        IJBTerminal terminal = IJBTerminal(terminalAddress);
        JB721TiersHook hook = JB721TiersHook(hookAddress);
        
        // Get project ID from hook
        uint256 projectId = hook.PROJECT_ID();
        
        // Deploy the appropriate chain-specific migration contract with transfer data
        `;

    if (hasEthereum) {
        // Ethereum batches 1-6 map to contracts 1-6, batch 7 (unused assets part 1) maps to contract 7, batch 8 (unused assets part 2) maps to contract 8
        const ethereumContractNum = (batchNumber === 7 || batchNumber === 8) ? batchNumber : batchNumber;
        processMigrationFunction += `
        if (chainId == 1) {
            // Ethereum - Batch ${batchNumber} only
            uint16[] memory tierIds${ethereumContractNum} = new uint16[](${tierIds.ethereum.length});
            ${generateTierIdLoops(tierIds.ethereum, `tierIds${ethereumContractNum}`)}
            address[] memory transferOwners${ethereumContractNum} = _getEthereumTransferOwners${ethereumContractNum}();
            MigrationContractEthereum${ethereumContractNum} migrationContract${ethereumContractNum} = new MigrationContractEthereum${ethereumContractNum}(transferOwners${ethereumContractNum});
            console.log("Ethereum migration contract ${ethereumContractNum} deployed at:", address(migrationContract${ethereumContractNum}));
            
            // Mint chunk ${ethereumContractNum} assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                tierIds${ethereumContractNum},
                address(migrationContract${ethereumContractNum})
            );
            console.log("Minted", tierIds${ethereumContractNum}.length, "tokens to contract ${ethereumContractNum}");
            
            migrationContract${ethereumContractNum}.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            
        } else `;
    }

    if (hasOptimism) {
        processMigrationFunction += `
        if (chainId == 10) {
            // Optimism tier IDs
            uint16[] memory allTierIds = new uint16[](${tierIds.optimism.length});
            ${generateTierIdLoops(tierIds.optimism)}
            address[] memory transferOwners = _getOptimismTransferOwners();
            MigrationContractOptimism migrationContract = new MigrationContractOptimism(transferOwners);
            console.log("Optimism migration contract deployed at:", address(migrationContract));
            
            // Mint all assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                allTierIds,
                address(migrationContract)
            );
            console.log("Minted", allTierIds.length, "tokens to contract");
            
            migrationContract.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
        } else `;
    }

    if (hasBase) {
        // Base batches 1-4 map to contracts 1-4, batch 5 (unused assets) maps to contract 5
        const baseContractNum = batchNumber === 5 ? 5 : batchNumber;
        processMigrationFunction += `
        if (chainId == 8453) {
            // Base - Batch ${batchNumber} only
            uint16[] memory tierIds${baseContractNum} = new uint16[](${tierIds.base.length});
            ${generateTierIdLoops(tierIds.base, `tierIds${baseContractNum}`)}
            address[] memory transferOwners${baseContractNum} = _getBaseTransferOwners${baseContractNum}();
            MigrationContractBase${baseContractNum} migrationContract${baseContractNum} = new MigrationContractBase${baseContractNum}(transferOwners${baseContractNum});
            console.log("Base migration contract ${baseContractNum} deployed at:", address(migrationContract${baseContractNum}));
            
            // Mint chunk ${baseContractNum} assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                tierIds${baseContractNum},
                address(migrationContract${baseContractNum})
            );
            console.log("Minted", tierIds${baseContractNum}.length, "tokens to contract ${baseContractNum}");
            
            migrationContract${baseContractNum}.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            
        } else `;
    }

    if (hasArbitrum) {
        // Arbitrum batches 1-3 map to contracts 1-3, batch 4 (unused assets) maps to contract 4
        const arbitrumContractNum = batchNumber === 4 ? 4 : batchNumber;
        processMigrationFunction += `
        if (chainId == 42161) {
            // Arbitrum - Batch ${batchNumber} only
            uint16[] memory tierIds${arbitrumContractNum} = new uint16[](${tierIds.arbitrum.length});
            ${generateTierIdLoops(tierIds.arbitrum, `tierIds${arbitrumContractNum}`)}
            address[] memory transferOwners${arbitrumContractNum} = _getArbitrumTransferOwners${arbitrumContractNum}();
            MigrationContractArbitrum${arbitrumContractNum} migrationContract${arbitrumContractNum} = new MigrationContractArbitrum${arbitrumContractNum}(transferOwners${arbitrumContractNum});
            console.log("Arbitrum migration contract ${arbitrumContractNum} deployed at:", address(migrationContract${arbitrumContractNum}));
            
            // Mint chunk ${arbitrumContractNum} assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                tierIds${arbitrumContractNum},
                address(migrationContract${arbitrumContractNum})
            );
            console.log("Minted", tierIds${arbitrumContractNum}.length, "tokens to contract ${arbitrumContractNum}");
            
            migrationContract${arbitrumContractNum}.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            
        } else `;
    }

    processMigrationFunction += `
        {
            revert("Unsupported chain for contract deployment");
        }
    }`;

    // Generate helper functions (same for all batches)
    const helperFunctions = `
    function _mintViaPay(
        IJBTerminal terminal,
        JB721TiersHook hook,
        uint256 projectId,
        uint16[] memory tierIds,
        address beneficiary
    ) internal {
        uint256 totalTierIds = tierIds.length;
        
        // Process tier IDs in batches
        for (uint256 i = 0; i < totalTierIds; i += BATCH_SIZE) {
            uint256 batchSize = i + BATCH_SIZE > totalTierIds ? totalTierIds - i : BATCH_SIZE;
            uint16[] memory batchTierIds = new uint16[](batchSize);
            
            // Copy tier IDs for this batch
            for (uint256 j = 0; j < batchSize; j++) {
                batchTierIds[j] = tierIds[i + j];
            }
            
            // Build the metadata using the tiers to mint and the overspending flag
            bytes[] memory data = new bytes[](1);
            data[0] = abi.encode(false, batchTierIds);
            
            // Get the hook ID
            bytes4[] memory ids = new bytes4[](1);
            ids[0] = JBMetadataResolver.getId("pay", hook.METADATA_ID_TARGET());
            
            // Generate the metadata
            bytes memory hookMetadata = JBMetadataResolver.createMetadata(ids, data);
            
            // Calculate the amount needed for this batch
            uint256 batchAmount = _calculateTotalPriceForTiers(batchTierIds);
            
            // Pay the terminal to mint the NFTs for this batch
            terminal.pay{value: batchAmount}({
                projectId: projectId,
                amount: batchAmount,
                token: JBConstants.NATIVE_TOKEN,
                beneficiary: beneficiary,
                minReturnedTokens: 0,
                memo: "Airdrop mint",
                metadata: hookMetadata
            });
        }
    }
    
    function _getPriceForUPC(uint16 upc) internal pure returns (uint256) {
        // Price map: UPC -> price in wei
        // This is generated from raw.json prices
${generatePriceMap(items)}
    }
    
    function _calculateTotalPriceForTiers(uint16[] memory tierIds) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < tierIds.length; i++) {
            total += _getPriceForUPC(tierIds[i]);
        }
        return total;
    }`;

    // Filter transfer data functions to only include what's needed for this batch
    let batchTransferDataFunctions = '';
    if (hasEthereum) {
        // Ethereum batches 1-6 map to contracts 1-6, batch 7 (unused assets part 1) maps to contract 7, batch 8 (unused assets part 2) maps to contract 8
        const ethereumContractNum = (batchNumber === 7 || batchNumber === 8) ? batchNumber : batchNumber;
        const regex = new RegExp(`function _getEthereumTransferOwners${ethereumContractNum}\\(\\)[\\s\\S]*?return transferOwners;\\s*\\}`, 'g');
        const match = transferDataFunctions.match(regex);
        if (match) {
            batchTransferDataFunctions += match[0] + '\n    ';
        }
    }
    if (hasOptimism) {
        const regex = /function _getOptimismTransferOwners\(\)[\s\S]*?return transferOwners;\s*\}/g;
        const match = transferDataFunctions.match(regex);
        if (match) {
            batchTransferDataFunctions += match[0] + '\n    ';
        }
    }
    if (hasBase) {
        // Base batches 1-4 map to contracts 1-4, batch 5 (unused assets) maps to contract 5
        const baseContractNum = batchNumber === 5 ? 5 : batchNumber;
        const regex = new RegExp(`function _getBaseTransferOwners${baseContractNum}\\(\\)[\\s\\S]*?return transferOwners;\\s*\\}`, 'g');
        const match = transferDataFunctions.match(regex);
        if (match) {
            batchTransferDataFunctions += match[0] + '\n    ';
        }
    }
    if (hasArbitrum) {
        // Arbitrum batches 1-3 map to contracts 1-3, batch 4 (unused assets) maps to contract 4
        const arbitrumContractNum = batchNumber === 4 ? 4 : batchNumber;
        const regex = new RegExp(`function _getArbitrumTransferOwners${arbitrumContractNum}\\(\\)[\\s\\S]*?return transferOwners;\\s*\\}`, 'g');
        const match = transferDataFunctions.match(regex);
        if (match) {
            batchTransferDataFunctions += match[0] + '\n    ';
        }
    }

    const script = `// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
${imports}
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
import {IJBTerminal} from "@bananapus/core-v5/src/interfaces/IJBTerminal.sol";
import {JBConstants} from "@bananapus/core-v5/src/libraries/JBConstants.sol";
import {JBMetadataResolver} from "@bananapus/core-v5/src/libraries/JBMetadataResolver.sol";

contract AirdropOutfitsBatch${batchNumber}Script is Script, Sphinx {
    // Maximum tier IDs per batch to avoid metadata size limit (255 words max)
    // Each tier ID takes 1 word, plus overhead for array length, boolean, and metadata structure
    // Using 100 as a safe batch size to stay well under the limit
    uint256 private constant BATCH_SIZE = 100;
    
    function configureSphinx() public override {
        sphinxConfig.projectName = "banny-core";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = new string[](0);
    }

${runFunction}
${chainRunFunctions}
${processMigrationFunction}
${helperFunctions}${batchTransferDataFunctions}
}`;

    fs.writeFileSync(outputPath, script);
    console.log(`Generated batch ${batchNumber} script: ${outputPath}`);
}


function buildTransferDataForChain(chainItems) {
    // Process data for this chain
    const bannys = [];
    const outfits = [];
    const backgrounds = [];

    chainItems.forEach(item => {
        const tokenId = item.metadata.tokenId;
        const upc = item.metadata.upc;
        const category = item.metadata.category;
        const owner = toChecksumAddress(item.owner || (item.wallet ? item.wallet.address : '0x0000000000000000000000000000000000000000'));
        const productName = item.metadata.productName;

        if (category === 0) {
            // Banny body
            bannys.push({
                tokenId,
                upc,
                backgroundId: item.metadata.backgroundId || 0,
                outfitIds: item.metadata.outfitIds || [],
                owner,
                productName
            });
        } else if (category === 1) {
            // Background
            backgrounds.push({
                tokenId,
                upc,
                owner,
                productName
            });
        } else {
            // Outfit
            outfits.push({
                tokenId,
                upc,
                category,
                owner,
                productName
            });
        }
    });

    // Collect all outfitIds and backgroundIds that are being used
    const usedOutfitIds = new Set();
    const usedBackgroundIds = new Set();

    bannys.forEach(banny => {
        if (banny.backgroundId && banny.backgroundId !== 0) {
            usedBackgroundIds.add(banny.backgroundId);
        }
        banny.outfitIds.forEach(outfitId => {
            usedOutfitIds.add(outfitId);
        });
    });

    // Build transfer data array
    const allItems = [...bannys, ...outfits, ...backgrounds];
    const transferData = [];

    allItems.forEach((item, index) => {
        // Skip if owner is zero address
        if (item.owner === '0x0000000000000000000000000000000000000000') {
            return;
        }

        // Skip if this is an outfit being worn
        if (item.tokenId && usedOutfitIds.has(item.tokenId)) {
            return;
        }

        // Skip if this is a background being used
        if (item.tokenId && usedBackgroundIds.has(item.tokenId)) {
            return;
        }

        transferData.push({
            owner: item.owner
        });
    });

    return transferData;
}

function generateTierIdLoops(tierIds, varName = 'allTierIds') {
    // Group consecutive tier IDs to create efficient for loops
    const groups = [];
    let currentGroup = null;

    tierIds.forEach((tierId, index) => {
        if (currentGroup && currentGroup.tierId === tierId) {
            currentGroup.count++;
        } else {
            if (currentGroup) groups.push(currentGroup);
            currentGroup = { tierId, startIndex: index, count: 1 };
        }
    });
    if (currentGroup) groups.push(currentGroup);

    let loops = '';
    groups.forEach(group => {
        loops += `
            // Add ${group.count} instances of tier ID ${group.tierId}
            for (uint256 i = 0; i < ${group.count}; i++) {
                ${varName}[${group.startIndex} + i] = ${group.tierId};
            }`;
    });

    return loops;
}

function generateTierBalanceVerification(transferData, tierIdQuantities) {
    // Collect unique owners from transferData
    const uniqueOwners = new Set();
    transferData.forEach(data => {
        uniqueOwners.add(data.owner);
    });
    const ownersArray = Array.from(uniqueOwners);
    
    // Collect unique tier IDs from tierIdQuantities
    const uniqueTierIds = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
    
    if (ownersArray.length === 0 || uniqueTierIds.length === 0) {
        return ''; // No verification needed if no owners or tier IDs
    }
    
    let code = `
        // Collect unique owners
        address[] memory uniqueOwners = new address[](${ownersArray.length});
        `;
    ownersArray.forEach((owner, idx) => {
        code += `
        uniqueOwners[${idx}] = ${toChecksumAddress(owner)};`;
    });
    
    code += `
        
        // Collect unique tier IDs
        uint256[] memory uniqueTierIds = new uint256[](${uniqueTierIds.length});
        `;
    uniqueTierIds.forEach((tierId, idx) => {
        code += `
        uniqueTierIds[${idx}] = ${tierId};`;
    });
    
    code += `
        
        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)
        MigrationHelper.verifyTierBalances(
            hookAddress,
            v4HookAddress,
            fallbackV4ResolverAddress,
            uniqueOwners,
            uniqueTierIds
        );`;
    
    return code;
}

function generatePriceMap(items) {
    // Create a map of UPC to price from raw.json
    const upcToPrice = new Map();
    items.forEach(item => {
        const upc = item.metadata.upc;
        const price = item.metadata.price;
        if (!upcToPrice.has(upc)) {
            upcToPrice.set(upc, price);
        }
    });

    // Generate a helper function that returns price for a given UPC
    const sortedUpcs = Array.from(upcToPrice.keys()).sort((a, b) => a - b);
    let code = '';

    if (sortedUpcs.length > 0) {
        sortedUpcs.forEach(upc => {
            const price = upcToPrice.get(upc);
            code += `\n        if (upc == ${upc}) return ${price};`;
        });
        code += '\n        return 0;';
    } else {
        code = '        return 0;';
    }

    return code;
}

function generateTokenIdArray(chainItems, transferData, tierIdQuantities, upcStartingUnitNumbers = new Map()) {
    // Build allItems array in transfer order (bannys, outfits, backgrounds)
    const bannys = [];
    const outfits = [];
    const backgrounds = [];
    // IMPORTANT: We determine which assets are worn/used by looking at outfitIds and backgroundId
    // on Banny body entries (category === 0). We do NOT use wornByBannyBodyId from outfit/background
    // entries as it is not reliable in raw.json.
    const usedOutfitIds = new Set();
    const usedBackgroundIds = new Set();

    chainItems.forEach(item => {
        const tokenId = item.metadata.tokenId;
        const upc = item.metadata.upc;
        const category = item.metadata.category;
        const owner = toChecksumAddress(item.owner || (item.wallet ? item.wallet.address : '0x0000000000000000000000000000000000000000'));
        const productName = item.metadata.productName;

        if (category === 0) {
            bannys.push({
                tokenId,
                upc,
                backgroundId: item.metadata.backgroundId || 0,
                outfitIds: item.metadata.outfitIds || [],
                owner,
                productName
            });
            if (item.metadata.backgroundId && item.metadata.backgroundId !== 0) {
                usedBackgroundIds.add(item.metadata.backgroundId);
            }
            (item.metadata.outfitIds || []).forEach(outfitId => {
                usedOutfitIds.add(outfitId);
            });
        } else if (category === 1) {
            backgrounds.push({
                tokenId,
                upc,
                owner,
                productName
            });
        } else {
            outfits.push({
                tokenId,
                upc,
                category,
                owner,
                productName
            });
        }
    });

    // Build itemsForTransfer in the same order as transferData
    const allItemsOrdered = [...bannys, ...outfits, ...backgrounds];
    const itemsForTransfer = [];

    allItemsOrdered.forEach(item => {
        // Skip if owner is zero address
        if (item.owner === '0x0000000000000000000000000000000000000000') {
            return;
        }

        // Skip if this is an outfit being worn
        if (item.tokenId && usedOutfitIds.has(item.tokenId)) {
            return;
        }

        // Skip if this is a background being used
        if (item.tokenId && usedBackgroundIds.has(item.tokenId)) {
            return;
        }

        itemsForTransfer.push(item);
    });

    // Build tier ID array in mint order (sorted by UPC) to determine unit numbers
    const tierIdQuantitiesForMinting = new Map();
    chainItems.forEach(item => {
        const upc = item.metadata.upc;
        tierIdQuantitiesForMinting.set(upc, (tierIdQuantitiesForMinting.get(upc) || 0) + 1);
    });

    const uniqueUpcs = Array.from(tierIdQuantitiesForMinting.keys()).sort((a, b) => a - b);
    const tierIdsInMintOrder = [];
    uniqueUpcs.forEach(upc => {
        const quantity = tierIdQuantitiesForMinting.get(upc);
        for (let i = 0; i < quantity; i++) {
            tierIdsInMintOrder.push(upc);
        }
    });

    // Build mapping of items to their token IDs based on mint order
    // Token IDs follow the formula: upc * 1000000000 + unitNumber
    // where unitNumber is incremented per UPC (starting from 1)

    // Create a map from V4 tokenId to its token ID using the formula
    const v4TokenIdToTokenId = new Map();
    const upcCounters = new Map();

    tierIdsInMintOrder.forEach((upc) => {
        const counter = (upcCounters.get(upc) || 0) + 1;
        upcCounters.set(upc, counter);

        // Find the V4 token ID that corresponds to this mint position
        const upcItems = chainItems.filter(item => item.metadata.upc === upc);
        // Sort by original order in chainItems to maintain consistency
        const sortedUpcItems = [...upcItems].sort((a, b) => {
            return chainItems.indexOf(a) - chainItems.indexOf(b);
        });

        if (counter <= sortedUpcItems.length) {
            const item = sortedUpcItems[counter - 1];
            if (item) {
                // Calculate token ID: upc * 1000000000 + unitNumber
                // unitNumber = startingUnitNumber (from previous chunks) + counter - 1
                const startingUnitNumber = upcStartingUnitNumbers.get(upc) || 1;
                const unitNumber = startingUnitNumber + counter - 1;
                const v5TokenId = upc * 1000000000 + unitNumber;
                v4TokenIdToTokenId.set(item.metadata.tokenId, v5TokenId);
            }
        }
    });

    // Generate token IDs for each item in transfer order using the formula
    // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
    // Outfits/backgrounds being worn may have different IDs, but they're not transferred.
    let code = '';

    itemsForTransfer.forEach((item, index) => {
        const v4TokenId = item.tokenId;
        const tokenId = v4TokenIdToTokenId.get(v4TokenId);

        if (tokenId) {
            code += `\n        generatedTokenIds[${index}] = ${tokenId}; // Token ID (V4: ${v4TokenId})`;
        } else {
            // Fallback: use V4 token ID (shouldn't happen)
            code += `\n        generatedTokenIds[${index}] = ${v4TokenId}; // Fallback: V4 token ID`;
        }
    });

    return code;
}

function generateContractVersion(items, tierIds = null) {
    // Calculate tier IDs for each chain if not provided
    if (!tierIds) {
        const ethereumItems = items.filter(item => item.chainId === 1);
        const optimismItems = items.filter(item => item.chainId === 10);
        const baseItems = items.filter(item => item.chainId === 8453);
        const arbitrumItems = items.filter(item => item.chainId === 42161);

        const ethereumTierIds = [];
        const optimismTierIds = [];
        const baseTierIds = [];
        const arbitrumTierIds = [];

        // Build tier ID arrays for each chain
        [ethereumItems, optimismItems, baseItems, arbitrumItems].forEach((chainItems, index) => {
            const tierIdQuantities = new Map();
            chainItems.forEach(item => {
                const upc = item.metadata.upc;
                tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
            });

            const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);
            const tierIds = [];
            uniqueUpcs.forEach(upc => {
                const quantity = tierIdQuantities.get(upc);
                for (let i = 0; i < quantity; i++) {
                    tierIds.push(upc);
                }
            });

            if (index === 0) ethereumTierIds.push(...tierIds);
            else if (index === 1) optimismTierIds.push(...tierIds);
            else if (index === 2) baseTierIds.push(...tierIds);
            else if (index === 3) arbitrumTierIds.push(...tierIds);
        });

        tierIds = { ethereumTierIds, optimismTierIds, baseTierIds, arbitrumTierIds };
    }

    // Process transfer data for each chain and chunks
    const chains = [
        { id: 1, name: 'Ethereum', numChunks: 6 },
        { id: 10, name: 'Optimism', numChunks: 1 },
        { id: 8453, name: 'Base', numChunks: 4 },
        { id: 42161, name: 'Arbitrum', numChunks: 3 }
    ];

    let transferDataFunctions = '';

    chains.forEach(chain => {
        const chainItems = items.filter(item => item.chainId === chain.id);
        if (chainItems.length === 0) return;

        if (chain.numChunks > 1) {
            // Split into chunks and generate transfer data for each chunk
            const chunks = splitBanniesIntoChunks(chainItems, chain.numChunks);
            chunks.forEach((chunk, chunkIndex) => {
                const transferData = chunk.transferData;
                transferDataFunctions += `
    function _get${chain.name}TransferOwners${chunkIndex + 1}() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${transferData.length});
        `;

                transferData.forEach((data, index) => {
                    transferDataFunctions += `
        transferOwners[${index}] = ${toChecksumAddress(data.owner)};`;
                });

                transferDataFunctions += `
        return transferOwners;
    }
    `;
            });
            
            // Generate transfer data function for unused assets (Ethereum, Base, and Arbitrum)
            if (chain.id === 1 || chain.id === 8453 || chain.id === 42161) {
                // Collect all token IDs already processed in chunks 1-3 (or 1-2 for Base)
                const processedTokenIds = new Set();
                chunks.forEach(chunk => {
                    chunk.allItems.forEach(item => {
                        const tokenId = item.metadata.tokenId;
                        processedTokenIds.add(Number(tokenId));
                    });
                });
                
                // Calculate UPC counts from CHUNKS ONLY (not all items) to determine starting unit numbers
                // This tells us how many tokens of each UPC were already minted in previous chunks
                const upcCountsFromChunks = new Map();
                chunks.forEach(chunk => {
                    chunk.allItems.forEach(item => {
                        const upc = item.metadata.upc;
                        upcCountsFromChunks.set(upc, (upcCountsFromChunks.get(upc) || 0) + 1);
                    });
                });
                // Convert counts to starting unit numbers (1-indexed, so add 1)
                // If 6 tokens were minted, the next one should be unit number 7
                const upcStartingUnitNumbers = new Map();
                upcCountsFromChunks.forEach((count, upc) => {
                    upcStartingUnitNumbers.set(upc, count + 1);
                });
                
                const unusedContractData = generateUnusedAssetsContract(chain, chainItems, upcStartingUnitNumbers, processedTokenIds);
                if (unusedContractData && unusedContractData.unusedItems.length > 0) {
                    // For Ethereum, split unused assets into two contracts (7 and 8)
                    if (chain.id === 1) {
                        const midPoint = Math.ceil(unusedContractData.unusedItems.length / 2);
                        const unusedItems7 = unusedContractData.unusedItems.slice(0, midPoint);
                        const unusedItems8 = unusedContractData.unusedItems.slice(midPoint);
                        
                        // Generate function 7
                        transferDataFunctions += `
    function _get${chain.name}TransferOwners7() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${unusedItems7.length});
        `;

                        unusedItems7.forEach((item, index) => {
                            transferDataFunctions += `
        transferOwners[${index}] = ${toChecksumAddress(item.owner)};`;
                        });

                        transferDataFunctions += `
        return transferOwners;
    }
    `;
                        
                        // Generate function 8 if there are items for contract 8
                        if (unusedItems8.length > 0) {
                            transferDataFunctions += `
    function _get${chain.name}TransferOwners8() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${unusedItems8.length});
        `;

                            unusedItems8.forEach((item, index) => {
                                transferDataFunctions += `
        transferOwners[${index}] = ${toChecksumAddress(item.owner)};`;
                            });

                            transferDataFunctions += `
        return transferOwners;
    }
    `;
                        }
                    } else {
                        // For other chains (Base, Arbitrum), generate single function
                        const chunkIndex = chain.numChunks;
                        transferDataFunctions += `
    function _get${chain.name}TransferOwners${chunkIndex + 1}() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${unusedContractData.unusedItems.length});
        `;

                        unusedContractData.unusedItems.forEach((item, index) => {
                            transferDataFunctions += `
        transferOwners[${index}] = ${toChecksumAddress(item.owner)};`;
                        });

                        transferDataFunctions += `
        return transferOwners;
    }
    `;
                    }
                }
            }
        } else {
            // Single contract (no splitting)
        const transferData = buildTransferDataForChain(chainItems);

        transferDataFunctions += `
    function _get${chain.name}TransferOwners() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](${transferData.length});
        `;

        transferData.forEach((data, index) => {
            transferDataFunctions += `
        transferOwners[${index}] = ${toChecksumAddress(data.owner)};`;
        });

        transferDataFunctions += `
        return transferOwners;
    }
    `;
        }
    });

    // Generate a contract-based version that deploys a migration contract
    // and makes a single call to it
    return `// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MigrationContractEthereum1} from "./MigrationContractEthereum1.sol";
import {MigrationContractEthereum2} from "./MigrationContractEthereum2.sol";
import {MigrationContractEthereum3} from "./MigrationContractEthereum3.sol";
import {MigrationContractEthereum4} from "./MigrationContractEthereum4.sol";
import {MigrationContractEthereum5} from "./MigrationContractEthereum5.sol";
import {MigrationContractEthereum6} from "./MigrationContractEthereum6.sol";
import {MigrationContractEthereum7} from "./MigrationContractEthereum7.sol";
import {MigrationContractEthereum8} from "./MigrationContractEthereum8.sol";
import {MigrationContractOptimism} from "./MigrationContractOptimism.sol";
import {MigrationContractBase1} from "./MigrationContractBase1.sol";
import {MigrationContractBase2} from "./MigrationContractBase2.sol";
import {MigrationContractBase3} from "./MigrationContractBase3.sol";
import {MigrationContractBase4} from "./MigrationContractBase4.sol";
import {MigrationContractBase5} from "./MigrationContractBase5.sol";
import {MigrationContractArbitrum1} from "./MigrationContractArbitrum1.sol";
import {MigrationContractArbitrum2} from "./MigrationContractArbitrum2.sol";
import {MigrationContractArbitrum3} from "./MigrationContractArbitrum3.sol";
import {MigrationContractArbitrum4} from "./MigrationContractArbitrum4.sol";

import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
import {IJBTerminal} from "@bananapus/core-v5/src/interfaces/IJBTerminal.sol";
import {JBConstants} from "@bananapus/core-v5/src/libraries/JBConstants.sol";
import {JBMetadataResolver} from "@bananapus/core-v5/src/libraries/JBMetadataResolver.sol";

contract AirdropOutfitsScript is Script, Sphinx {
    // Maximum tier IDs per batch to avoid metadata size limit (255 words max)
    // Each tier ID takes 1 word, plus overhead for array length, boolean, and metadata structure
    // Using 100 as a safe batch size to stay well under the limit
    uint256 private constant BATCH_SIZE = 100;
    function configureSphinx() public override {
        sphinxConfig.projectName = "banny-core";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = new string[](0);
    }

    function run() public sphinx {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) {
            // Ethereum Mainnet
            _runEthereum();
        } else if (chainId == 10) {
            // Optimism
            _runOptimism();
        } else if (chainId == 8453) {
            // Base
            _runBase();
        } else if (chainId == 42161) {
            // Arbitrum
            _runArbitrum();
        } else {
            revert("Unsupported chain");
        }
    }
    
    function _runEthereum() internal {
        address hookAddress = ${toChecksumAddress('0xb4Ec363c2E7DB0cECA9AA1759338d7d1b49d1750')};
        address resolverAddress = ${toChecksumAddress('0x47c011146a4498a70e0bf2e4585acf9cade85954')};
        address v4HookAddress = ${toChecksumAddress('0x2da41cdc79ae49f2725ab549717b2dbcfc42b958')};
        address v4ResolverAddress = ${toChecksumAddress('0xa5f8911d4cfd60a6697479f078409434424fe666')};
        address terminalAddress = ${toChecksumAddress('0x2db6d704058e552defe415753465df8df0361846')};
        address v4ResolverFallback = ${toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3')};
        _processMigration(
            hookAddress,
            resolverAddress,
            v4HookAddress,
            v4ResolverAddress,
            terminalAddress,
            v4ResolverFallback,
            1
        );
    }
    
    function _runOptimism() internal {
        address hookAddress = ${toChecksumAddress('0xb4Ec363c2E7DB0cECA9AA1759338d7d1b49d1750')};
        address resolverAddress = ${toChecksumAddress('0x47c011146a4498a70e0bf2e4585acf9cade85954')};
        address v4HookAddress = ${toChecksumAddress('0x2da41cdc79ae49f2725ab549717b2dbcfc42b958')};
        address v4ResolverAddress = ${toChecksumAddress('0xa5f8911d4cfd60a6697479f078409434424fe666')};
        address terminalAddress = ${toChecksumAddress('0x2db6d704058e552defe415753465df8df0361846')};
        address v4ResolverFallback = ${toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3')};
        _processMigration(
            hookAddress,
            resolverAddress,
            v4HookAddress,
            v4ResolverAddress,
            terminalAddress,
            v4ResolverFallback,
            10
        );
    }
    
    function _runBase() internal {
        address hookAddress = ${toChecksumAddress('0xb4Ec363c2E7DB0cECA9AA1759338d7d1b49d1750')};
        address resolverAddress = ${toChecksumAddress('0x47c011146a4498a70e0bf2e4585acf9cade85954')};
        address v4HookAddress = ${toChecksumAddress('0x2da41cdc79ae49f2725ab549717b2dbcfc42b958')};
        address v4ResolverAddress = ${toChecksumAddress('0xa5f8911d4cfd60a6697479f078409434424fe666')};
        address terminalAddress = ${toChecksumAddress('0x2db6d704058e552defe415753465df8df0361846')};
        address v4ResolverFallback = ${toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3')};
        _processMigration(
            hookAddress,
            resolverAddress,
            v4HookAddress,
            v4ResolverAddress,
            terminalAddress,
            v4ResolverFallback,
            8453
        );
    }
    
    function _runArbitrum() internal {
        address hookAddress = ${toChecksumAddress('0xb4Ec363c2E7DB0cECA9AA1759338d7d1b49d1750')};
        address resolverAddress = ${toChecksumAddress('0x47c011146a4498a70e0bf2e4585acf9cade85954')};
        address v4HookAddress = ${toChecksumAddress('0x2da41cdc79ae49f2725ab549717b2dbcfc42b958')};
        address v4ResolverAddress = ${toChecksumAddress('0xa5f8911d4cfd60a6697479f078409434424fe666')};
        address terminalAddress = ${toChecksumAddress('0x2db6d704058e552defe415753465df8df0361846')};
        address v4ResolverFallback = ${toChecksumAddress('0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3')};
        _processMigration(
            hookAddress,
            resolverAddress,
            v4HookAddress,
            v4ResolverAddress,
            terminalAddress,
            v4ResolverFallback,
            42161
        );
    }
    
    function _processMigration(address hookAddress, address resolverAddress, address v4HookAddress, address v4ResolverAddress, address terminalAddress, address v4ResolverFallback, uint256 chainId) internal {
        // Validate addresses
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(terminalAddress != address(0), "Terminal address not set");
        
        IJBTerminal terminal = IJBTerminal(terminalAddress);
        JB721TiersHook hook = JB721TiersHook(hookAddress);
        
        // Get project ID from hook
        uint256 projectId = hook.PROJECT_ID();
        
        // Deploy the appropriate chain-specific migration contract with transfer data
        if (chainId == 1) {
            // Ethereum - 6 chunks (plus optional unused assets chunks 7 and 8)
            ${(() => {
                const regularChunks = tierIds.ethereumChunkTierIds.slice(0, 6);
                const unusedChunk7 = tierIds.ethereumChunkTierIds.length > 6 ? tierIds.ethereumChunkTierIds[6] : null;
                const unusedChunk8 = tierIds.ethereumChunkTierIds.length > 7 ? tierIds.ethereumChunkTierIds[7] : null;
                let code = '';
                
                // Generate code for regular chunks (1-6)
                regularChunks.forEach((chunkTierIds, chunkIndex) => {
                    const varName = `tierIds${chunkIndex + 1}`;
                    code += `
            // Deploy and execute contract ${chunkIndex + 1}
            uint16[] memory ${varName} = new uint16[](${chunkTierIds.length});
            ${generateTierIdLoops(chunkTierIds, varName)}
            address[] memory transferOwners${chunkIndex + 1} = _getEthereumTransferOwners${chunkIndex + 1}();
            MigrationContractEthereum${chunkIndex + 1} migrationContract${chunkIndex + 1} = new MigrationContractEthereum${chunkIndex + 1}(transferOwners${chunkIndex + 1});
            console.log("Ethereum migration contract ${chunkIndex + 1} deployed at:", address(migrationContract${chunkIndex + 1}));
            
            // Mint chunk ${chunkIndex + 1} assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                ${varName},
                address(migrationContract${chunkIndex + 1})
            );
            console.log("Minted", ${varName}.length, "tokens to contract ${chunkIndex + 1}");
            
            migrationContract${chunkIndex + 1}.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            `;
                });
                
                // Generate code for unused assets chunk 7 if it exists
                if (unusedChunk7 && unusedChunk7.length > 0) {
                    code += `
            // Deploy and execute contract 7 (unused outfits/backgrounds - part 1)
            uint16[] memory tierIds7 = new uint16[](${unusedChunk7.length});
            ${generateTierIdLoops(unusedChunk7, 'tierIds7')}
            address[] memory transferOwners7 = _getEthereumTransferOwners7();
            MigrationContractEthereum7 migrationContract7 = new MigrationContractEthereum7(transferOwners7);
            console.log("Ethereum migration contract 7 deployed at:", address(migrationContract7));
            
            // Mint chunk 7 assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                tierIds7,
                address(migrationContract7)
            );
            console.log("Minted", tierIds7.length, "tokens to contract 7");
            
            migrationContract7.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            `;
                }
                
                // Generate code for unused assets chunk 8 if it exists
                if (unusedChunk8 && unusedChunk8.length > 0) {
                    code += `
            // Deploy and execute contract 8 (unused outfits/backgrounds - part 2)
            uint16[] memory tierIds8 = new uint16[](${unusedChunk8.length});
            ${generateTierIdLoops(unusedChunk8, 'tierIds8')}
            address[] memory transferOwners8 = _getEthereumTransferOwners8();
            MigrationContractEthereum8 migrationContract8 = new MigrationContractEthereum8(transferOwners8);
            console.log("Ethereum migration contract 8 deployed at:", address(migrationContract8));
            
            // Mint chunk 8 assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                tierIds8,
                address(migrationContract8)
            );
            console.log("Minted", tierIds8.length, "tokens to contract 8");
            
            migrationContract8.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            `;
                }
                
                return code;
            })()}
        } else if (chainId == 10) {
            // Optimism tier IDs
            uint16[] memory allTierIds = new uint16[](${tierIds.optimismTierIds.length});
            ${generateTierIdLoops(tierIds.optimismTierIds)}
            address[] memory transferOwners = _getOptimismTransferOwners();
            MigrationContractOptimism migrationContract = new MigrationContractOptimism(transferOwners);
            console.log("Optimism migration contract deployed at:", address(migrationContract));
            
            // Mint all assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                allTierIds,
                address(migrationContract)
            );
            console.log("Minted", allTierIds.length, "tokens to contract");
            
            migrationContract.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
        } else if (chainId == 8453) {
            // Base - 4 chunks (plus optional unused assets chunk)
            ${(() => {
                // Ensure baseChunkTierIds exists and has the correct structure
                const baseChunks = (tierIds && tierIds.baseChunkTierIds) ? tierIds.baseChunkTierIds : [];
                const regularChunks = baseChunks.slice(0, 4);
                const hasUnusedChunk = baseChunks.length > 4;
                const unusedChunk = hasUnusedChunk ? baseChunks[4] : null;
                let code = '';
                
                // Generate code for regular chunks (1-4)
                regularChunks.forEach((chunkTierIds, chunkIndex) => {
                    const varName = `tierIds${chunkIndex + 1}`;
                    code += `
            // Deploy and execute contract ${chunkIndex + 1}
            uint16[] memory ${varName} = new uint16[](${chunkTierIds.length});
            ${generateTierIdLoops(chunkTierIds, varName)}
            address[] memory transferOwners${chunkIndex + 1} = _getBaseTransferOwners${chunkIndex + 1}();
            MigrationContractBase${chunkIndex + 1} migrationContract${chunkIndex + 1} = new MigrationContractBase${chunkIndex + 1}(transferOwners${chunkIndex + 1});
            console.log("Base migration contract ${chunkIndex + 1} deployed at:", address(migrationContract${chunkIndex + 1}));
            
            // Mint chunk ${chunkIndex + 1} assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                ${varName},
                address(migrationContract${chunkIndex + 1})
            );
            console.log("Minted", ${varName}.length, "tokens to contract ${chunkIndex + 1}");
            
            migrationContract${chunkIndex + 1}.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            `;
                });
                
                // Generate code for unused assets chunk (5) if it exists
                if (hasUnusedChunk && unusedChunk && unusedChunk.length > 0) {
                    code += `
            // Deploy and execute contract 5 (unused outfits/backgrounds)
            uint16[] memory tierIds5 = new uint16[](${unusedChunk.length});
            ${generateTierIdLoops(unusedChunk, 'tierIds5')}
            address[] memory transferOwners5 = _getBaseTransferOwners5();
            MigrationContractBase5 migrationContract5 = new MigrationContractBase5(transferOwners5);
            console.log("Base migration contract 5 deployed at:", address(migrationContract5));
            
            // Mint chunk 5 assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                tierIds5,
                address(migrationContract5)
            );
            console.log("Minted", tierIds5.length, "tokens to contract 5");
            
            migrationContract5.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            `;
                }
                
                return code;
            })()}
        } else if (chainId == 42161) {
            // Arbitrum - 3 chunks (plus optional unused assets chunk)
            ${(() => {
                // Ensure arbitrumChunkTierIds exists and has the correct structure
                const arbitrumChunks = (tierIds && tierIds.arbitrumChunkTierIds) ? tierIds.arbitrumChunkTierIds : [];
                const regularChunks = arbitrumChunks.slice(0, 3);
                const hasUnusedChunk = arbitrumChunks.length > 3;
                const unusedChunk = hasUnusedChunk ? arbitrumChunks[3] : null;
                let code = '';
                
                // Generate code for regular chunks (1-3)
                regularChunks.forEach((chunkTierIds, chunkIndex) => {
                    const varName = `tierIds${chunkIndex + 1}`;
                    code += `
            // Deploy and execute contract ${chunkIndex + 1}
            uint16[] memory ${varName} = new uint16[](${chunkTierIds.length});
            ${generateTierIdLoops(chunkTierIds, varName)}
            address[] memory transferOwners${chunkIndex + 1} = _getArbitrumTransferOwners${chunkIndex + 1}();
            MigrationContractArbitrum${chunkIndex + 1} migrationContract${chunkIndex + 1} = new MigrationContractArbitrum${chunkIndex + 1}(transferOwners${chunkIndex + 1});
            console.log("Arbitrum migration contract ${chunkIndex + 1} deployed at:", address(migrationContract${chunkIndex + 1}));
            
            // Mint chunk ${chunkIndex + 1} assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                ${varName},
                address(migrationContract${chunkIndex + 1})
            );
            console.log("Minted", ${varName}.length, "tokens to contract ${chunkIndex + 1}");
            
            migrationContract${chunkIndex + 1}.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            `;
                });
                
                // Generate code for unused assets chunk (4) if it exists
                if (hasUnusedChunk && unusedChunk && unusedChunk.length > 0) {
                    code += `
            // Deploy and execute contract 4 (unused outfits/backgrounds)
            uint16[] memory tierIds4 = new uint16[](${unusedChunk.length});
            ${generateTierIdLoops(unusedChunk, 'tierIds4')}
            address[] memory transferOwners4 = _getArbitrumTransferOwners4();
            MigrationContractArbitrum4 migrationContract4 = new MigrationContractArbitrum4(transferOwners4);
            console.log("Arbitrum migration contract 4 deployed at:", address(migrationContract4));
            
            // Mint chunk 4 assets to the contract address via pay()
            _mintViaPay(
                terminal,
                hook,
                projectId,
                tierIds4,
                address(migrationContract4)
            );
            console.log("Minted", tierIds4.length, "tokens to contract 4");
            
            migrationContract4.executeMigration(hookAddress, resolverAddress, v4HookAddress, v4ResolverAddress, v4ResolverFallback);
            `;
                }
                
                return code;
            })()}
        } else {
            revert("Unsupported chain for contract deployment");
        }
    }
    
    function _mintViaPay(
        IJBTerminal terminal,
        JB721TiersHook hook,
        uint256 projectId,
        uint16[] memory tierIds,
        address beneficiary
    ) internal {
        uint256 totalTierIds = tierIds.length;
        
        // Process tier IDs in batches
        for (uint256 i = 0; i < totalTierIds; i += BATCH_SIZE) {
            uint256 batchSize = i + BATCH_SIZE > totalTierIds ? totalTierIds - i : BATCH_SIZE;
            uint16[] memory batchTierIds = new uint16[](batchSize);
            
            // Copy tier IDs for this batch
            for (uint256 j = 0; j < batchSize; j++) {
                batchTierIds[j] = tierIds[i + j];
            }
            
            // Build the metadata using the tiers to mint and the overspending flag
            bytes[] memory data = new bytes[](1);
            data[0] = abi.encode(false, batchTierIds);
            
            // Get the hook ID
            bytes4[] memory ids = new bytes4[](1);
            ids[0] = JBMetadataResolver.getId("pay", hook.METADATA_ID_TARGET());
            
            // Generate the metadata
            bytes memory hookMetadata = JBMetadataResolver.createMetadata(ids, data);
            
            // Calculate the amount needed for this batch
            uint256 batchAmount = _calculateTotalPriceForTiers(batchTierIds);
            
            // Pay the terminal to mint the NFTs for this batch
            terminal.pay{value: batchAmount}({
                projectId: projectId,
                amount: batchAmount,
                token: JBConstants.NATIVE_TOKEN,
                beneficiary: beneficiary,
                minReturnedTokens: 0,
                memo: "Airdrop mint",
                metadata: hookMetadata
            });
        }
    }
    
    function _getPriceForUPC(uint16 upc) internal pure returns (uint256) {
        // Price map: UPC -> price in wei
        // This is generated from raw.json prices
${generatePriceMap(items)}
    }
    
    function _calculateTotalPriceForTiers(uint16[] memory tierIds) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < tierIds.length; i++) {
            total += _getPriceForUPC(tierIds[i]);
        }
        return total;
    }${transferDataFunctions}
}`;
}

// Split bannies into chunks and collect their dependencies (outfits/backgrounds)
function splitBanniesIntoChunks(chainItems, numChunks) {
    // First, extract all bannies
    const bannys = [];
    chainItems.forEach(item => {
        if (item.metadata.category === 0) {
            bannys.push({
                tokenId: item.metadata.tokenId,
                upc: item.metadata.upc,
                backgroundId: item.metadata.backgroundId || 0,
                outfitIds: item.metadata.outfitIds || [],
                owner: toChecksumAddress(item.owner || (item.wallet ? item.wallet.address : '0x0000000000000000000000000000000000000000')),
                productName: item.metadata.productName
            });
        }
    });

    // Split bannies into chunks
    const chunks = [];
    const chunkSize = Math.ceil(bannys.length / numChunks);
    
    for (let i = 0; i < numChunks; i++) {
        const startIdx = i * chunkSize;
        const endIdx = Math.min(startIdx + chunkSize, bannys.length);
        const bannyChunk = bannys.slice(startIdx, endIdx);
        
        // Collect all outfit and background IDs needed by this chunk
        const neededOutfitIds = new Set();
        const neededBackgroundIds = new Set();
        const neededBannyTokenIds = new Set();
        
        bannyChunk.forEach(banny => {
            neededBannyTokenIds.add(banny.tokenId);
            if (banny.backgroundId && banny.backgroundId !== 0) {
                neededBackgroundIds.add(banny.backgroundId);
            }
            banny.outfitIds.forEach(outfitId => {
                neededOutfitIds.add(outfitId);
            });
        });
        
        // Find all items that belong to this chunk:
        // 1. Banny bodies in the chunk
        // 2. Outfits needed by those bannies
        // 3. Backgrounds needed by those bannies
        const chunkItems = chainItems.filter(item => {
            const tokenId = item.metadata.tokenId;
            return neededBannyTokenIds.has(tokenId) || 
                   neededOutfitIds.has(tokenId) || 
                   neededBackgroundIds.has(tokenId);
        });
        
        // Build transfer data for this chunk (items that need to be transferred)
        // IMPORTANT: We determine which assets are worn/used by looking at outfitIds and backgroundId
        // on Banny body entries (category === 0). We do NOT use wornByBannyBodyId from outfit/background
        // entries as it is not reliable in raw.json.
        const usedOutfitIds = new Set();
        const usedBackgroundIds = new Set();
        
        bannyChunk.forEach(banny => {
            if (banny.backgroundId && banny.backgroundId !== 0) {
                usedBackgroundIds.add(banny.backgroundId);
            }
            banny.outfitIds.forEach(outfitId => {
                usedOutfitIds.add(outfitId);
            });
        });
        
        const transferData = [];
        chunkItems.forEach(item => {
            const owner = toChecksumAddress(item.owner || (item.wallet ? item.wallet.address : '0x0000000000000000000000000000000000000000'));
            if (owner === '0x0000000000000000000000000000000000000000') {
                return;
            }
            
            // Skip outfits being worn
            if (item.metadata.tokenId && usedOutfitIds.has(item.metadata.tokenId)) {
                return;
            }
            
            // Skip backgrounds being used
            if (item.metadata.tokenId && usedBackgroundIds.has(item.metadata.tokenId)) {
                return;
            }
            
            transferData.push({
                item: item,
                owner: owner
            });
        });
        
        chunks.push({
            bannies: bannyChunk,
            allItems: chunkItems,
            transferData: transferData
        });
    }
    
    return chunks;
}

function generateChainSpecificContracts(inputFile) {
    console.log(`\n=== Generating chain-specific migration contracts from ${inputFile} ===`);

    // Load the raw data
    const rawDataPath = path.join(__dirname, inputFile);
    const rawData = JSON.parse(fs.readFileSync(rawDataPath, 'utf8'));

    const items = rawData.data.nfts.items;

    const chains = [
        { id: 1, name: 'Ethereum', fileName: 'MigrationContractEthereum.sol', numChunks: 6 },
        { id: 10, name: 'Optimism', fileName: 'MigrationContractOptimism.sol', numChunks: 1 },
        { id: 8453, name: 'Base', fileName: 'MigrationContractBase.sol', numChunks: 4 },
        { id: 42161, name: 'Arbitrum', fileName: 'MigrationContractArbitrum.sol', numChunks: 3 },
    ];

    // Track total items processed per chain for verification
    const chainTotals = new Map();
    
    chains.forEach(chain => {
        const chainItems = items.filter(item => item.chainId === chain.id);
        console.log(`Processing chain ${chain.id} (${chain.name}): ${chainItems.length} items`);
        
        // Store total items for this chain
        chainTotals.set(chain.id, { total: chainItems.length, processed: 0 });

        if (chainItems.length === 0) {
            console.log(`Skipping ${chain.name} - no items found`);
            return;
        }

        if (chain.numChunks > 1) {
            // Split into multiple contracts
            const chunks = splitBanniesIntoChunks(chainItems, chain.numChunks);
            
            // Calculate starting unitNumber for each UPC across chunks
            // Token IDs follow: upc * 1000000000 + unitNumber
            // unitNumber is incremented per UPC globally across all chunks
            const upcCounts = new Map(); // Map<upc, count> - tracks how many items of each UPC were minted in previous chunks
            
            chunks.forEach((chunk, chunkIndex) => {
                // Calculate starting unitNumbers for each UPC in this chunk
                const upcStartingUnitNumbers = new Map(); // Map<upc, startingUnitNumber>
                
                // Count items per UPC in this chunk
                const chunkUpcCounts = new Map();
                chunk.allItems.forEach(item => {
                    const upc = item.metadata.upc;
                    chunkUpcCounts.set(upc, (chunkUpcCounts.get(upc) || 0) + 1);
                });
                
                // Set starting unitNumber for each UPC (1 + count from previous chunks)
                chunkUpcCounts.forEach((count, upc) => {
                    const previousCount = upcCounts.get(upc) || 0;
                    upcStartingUnitNumbers.set(upc, previousCount + 1);
                });
                
                const contract = generateChunkContract(chain, chainItems, chunk, chunkIndex + 1, chain.numChunks, upcStartingUnitNumbers);
                
                // Update UPC counts for next chunk
                chunkUpcCounts.forEach((count, upc) => {
                    upcCounts.set(upc, (upcCounts.get(upc) || 0) + count);
                });
                
                // Write the contract to file
                const fileName = chain.fileName.replace('.sol', `${chunkIndex + 1}.sol`);
                const outputPath = path.join(__dirname, '..', fileName);
                fs.writeFileSync(outputPath, contract);
                
                console.log(`Generated ${fileName} with ${chunk.bannies.length} Bannys to dress, ${chunk.allItems.length} items to transfer`);
                
                // Track items processed in this chunk
                const chainTotal = chainTotals.get(chain.id);
                chainTotal.processed += chunk.allItems.length;
            });
            
            // Generate unused assets contract for Ethereum and Base
            if ((chain.id === 1 || chain.id === 8453 || chain.id === 42161) && chain.numChunks > 1) {
                // Collect all token IDs already processed in chunks 1-3 (or 1-2 for Base)
                const processedTokenIds = new Set();
                chunks.forEach(chunk => {
                    chunk.allItems.forEach(item => {
                        const tokenId = item.metadata.tokenId;
                        processedTokenIds.add(Number(tokenId));
                    });
                });
                
                // Calculate UPC counts from CHUNKS ONLY (not all items) to determine starting unit numbers
                // This tells us how many tokens of each UPC were already minted in previous chunks
                const upcCountsFromChunks = new Map();
                chunks.forEach(chunk => {
                    chunk.allItems.forEach(item => {
                        const upc = item.metadata.upc;
                        upcCountsFromChunks.set(upc, (upcCountsFromChunks.get(upc) || 0) + 1);
                    });
                });
                // Convert counts to starting unit numbers (1-indexed, so add 1)
                // If 6 tokens were minted, the next one should be unit number 7
                const upcStartingUnitNumbersMap = new Map();
                upcCountsFromChunks.forEach((count, upc) => {
                    upcStartingUnitNumbersMap.set(upc, count + 1);
                });
                
                // Calculate total items processed in chunks for filtered count
                let totalProcessedInChunks = 0;
                chunks.forEach(chunk => {
                    totalProcessedInChunks += chunk.allItems.length;
                });
                
                const unusedContractData = generateUnusedAssetsContract(chain, chainItems, upcStartingUnitNumbersMap, processedTokenIds, totalProcessedInChunks);
                
                if (unusedContractData && unusedContractData.unusedItems.length > 0) {
                    // For Ethereum, split unused assets into two contracts (7 and 8)
                    if (chain.id === 1) {
                        const midPoint = Math.ceil(unusedContractData.unusedItems.length / 2);
                        const unusedItems7 = unusedContractData.unusedItems.slice(0, midPoint);
                        const unusedItems8 = unusedContractData.unusedItems.slice(midPoint);
                        
                        // Generate contract 7
                        const contract7 = generateUnusedAssetsContractFromItems(chain, unusedItems7, upcStartingUnitNumbersMap, 7);
                        const fileName7 = chain.fileName.replace('.sol', '7.sol');
                        const outputPath7 = path.join(__dirname, '..', fileName7);
                        fs.writeFileSync(outputPath7, contract7);
                        console.log(`Generated ${fileName7} with ${unusedItems7.length} unused outfits/backgrounds to transfer`);
                        
                        // Update UPC starting numbers for contract 8
                        const upcCountsFromContract7 = new Map();
                        unusedItems7.forEach(item => {
                            const upc = item.upc;
                            upcCountsFromContract7.set(upc, (upcCountsFromContract7.get(upc) || 0) + 1);
                        });
                        const upcStartingUnitNumbersFor8 = new Map(upcStartingUnitNumbersMap);
                        upcCountsFromContract7.forEach((count, upc) => {
                            const currentStart = upcStartingUnitNumbersFor8.get(upc) || 1;
                            upcStartingUnitNumbersFor8.set(upc, currentStart + count);
                        });
                        
                        // Generate contract 8
                        if (unusedItems8.length > 0) {
                            const contract8 = generateUnusedAssetsContractFromItems(chain, unusedItems8, upcStartingUnitNumbersFor8, 8);
                            const fileName8 = chain.fileName.replace('.sol', '8.sol');
                            const outputPath8 = path.join(__dirname, '..', fileName8);
                            fs.writeFileSync(outputPath8, contract8);
                            console.log(`Generated ${fileName8} with ${unusedItems8.length} unused outfits/backgrounds to transfer`);
                        }
                        
                        // Track unused items processed
                        const chainTotal = chainTotals.get(chain.id);
                        chainTotal.processed += unusedContractData.unusedItems.length;
                    } else {
                        // For other chains (Base, Arbitrum), generate single contract
                        const fileName = chain.fileName.replace('.sol', `${chain.numChunks + 1}.sol`);
                        const outputPath = path.join(__dirname, '..', fileName);
                        fs.writeFileSync(outputPath, unusedContractData.contract);
                        
                        console.log(`Generated ${fileName} with ${unusedContractData.unusedItems.length} unused outfits/backgrounds to transfer`);
                        
                        // Track unused items processed
                        const chainTotal = chainTotals.get(chain.id);
                        chainTotal.processed += unusedContractData.unusedItems.length;
                    }
                    
                    // Report filtered items for debugging
                    if (unusedContractData.filteredCount > 0) {
                        console.log(`  (${unusedContractData.filteredCount} items filtered out: resolver-owned, zero-address, or already processed)`);
                        if (unusedContractData.filteredItems && unusedContractData.filteredItems.length > 0) {
                            console.log(`  Filtered items details:`);
                            unusedContractData.filteredItems.forEach(item => {
                                const reasons = item.reasons.join(', ');
                                console.log(`    - Token ID: ${item.tokenId}, UPC: ${item.upc}, Category: ${item.category}, Owner: ${item.owner}, Reasons: ${reasons}`);
                            });
                        }
                    }
                } else {
                    console.log(`No unused assets found for ${chain.name}, skipping unused assets contract`);
                }
            }
        } else {
            // Single contract (no splitting)
        const contract = generateSingleChainContract(chain, chainItems);

        // Write the contract to file
        const outputPath = path.join(__dirname, '..', chain.fileName);
        fs.writeFileSync(outputPath, contract);

        console.log(`Generated ${chain.fileName} with ${chainItems.length} items`);
        
        // Track items processed
        const chainTotal = chainTotals.get(chain.id);
        chainTotal.processed += chainItems.length;
        }
    });
    
    // Verify all items from raw.json were processed
    console.log(`\n=== Verification Summary ===`);
    let allChainsValid = true;
    chainTotals.forEach((totals, chainId) => {
        const chain = chains.find(c => c.id === chainId);
        const chainName = chain ? chain.name : `Chain ${chainId}`;
        if (totals.total !== totals.processed) {
            console.error(`❌ ${chainName}: Expected ${totals.total} items, but processed ${totals.processed} items`);
            allChainsValid = false;
        } else {
            console.log(`✅ ${chainName}: All ${totals.total} items accounted for`);
        }
    });
    
    if (!allChainsValid) {
        console.error(`\n⚠️  WARNING: Some items from raw.json were not processed!`);
        process.exit(1);
    } else {
        console.log(`\n✅ All items from raw.json are accounted for across all migration contracts`);
    }
}

function generateChunkContract(chain, chainItems, chunk, chunkIndex, totalChunks, upcStartingUnitNumbers = new Map()) {
    const bannys = chunk.bannies;
    const chunkItems = chunk.allItems;
    const transferData = chunk.transferData;
    
    // Calculate tier ID quantities for this chunk only
    const tierIdQuantities = new Map();
    chunkItems.forEach(item => {
        const upc = item.metadata.upc;
        tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
    });

    let contract = `// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContract${chain.name}${chunkIndex} {
    address[] private transferOwners;
    
    constructor(address[] memory _transferOwners) {
        transferOwners = _transferOwners;
    }
    
    function executeMigration(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress
    ) external {
        
        // Validate addresses
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        
        JB721TiersHook hook = JB721TiersHook(hookAddress);
        Banny721TokenUriResolver resolver = Banny721TokenUriResolver(resolverAddress);
        IERC721 v4Hook = IERC721(v4HookAddress);
        Banny721TokenUriResolver v4Resolver = Banny721TokenUriResolver(v4ResolverAddress);
        Banny721TokenUriResolver fallbackV4Resolver = Banny721TokenUriResolver(fallbackV4ResolverAddress);
        
        // ${chain.name} migration chunk ${chunkIndex}/${totalChunks} - ${chunkItems.length} items
        
        // Step 1: Assets are already minted to this contract by the deployer
        `;

    // Generate struct definition for minted token IDs
    const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);

    // Generate struct definition at contract level
    let structDefinition = `
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
`;

    uniqueUpcs.forEach(upc => {
        const quantity = tierIdQuantities.get(upc);
        structDefinition += `        uint256[${quantity}] upc${upc};\n`;
    });

    structDefinition += `    }
    
    `;

    // Insert struct definition into contract
    const contractStart = `contract MigrationContract${chain.name}${chunkIndex} {`;
    const replacement = `${contractStart}${structDefinition}address[] private transferOwners;`;
    contract = contract.replace(`${contractStart}\n    address[] private transferOwners;`, replacement);

    contract += `
        
        // Assets are already minted to this contract by the deployer
        `;

    // Build mapping of items to their token IDs based on mint order
    // Token IDs follow the formula: upc * 1000000000 + unitNumber
    // where unitNumber is incremented per UPC (starting from 1)
    // We need to track which items of each UPC are minted in this chunk and assign unitNumbers
    
    // Build tier ID array in the same order as it will be minted (matching tierIds array generation)
    const tierIdsInMintOrder = [];
    uniqueUpcs.forEach(upc => {
        const quantity = tierIdQuantities.get(upc);
        for (let i = 0; i < quantity; i++) {
            tierIdsInMintOrder.push(upc);
        }
    });
    
    // Map each tier ID position to the actual V4 token ID and calculate the token ID
    // Token ID = upc * 1000000000 + unitNumber (where unitNumber is 1-indexed per UPC, globally across chunks)
    const v4TokenIdToTokenId = new Map(); // Map<v4TokenId, v5TokenId>
    const upcCounters = new Map();
    
    tierIdsInMintOrder.forEach((upc) => {
        const counter = (upcCounters.get(upc) || 0) + 1;
        upcCounters.set(upc, counter);
        
        // Find the V4 token ID that corresponds to this mint position
        const upcItems = chunkItems.filter(item => item.metadata.upc === upc);
        // Sort by original order in chunkItems to maintain consistency
        const sortedUpcItems = [...upcItems].sort((a, b) => {
            return chunkItems.indexOf(a) - chunkItems.indexOf(b);
        });
        
        if (counter <= sortedUpcItems.length) {
            const item = sortedUpcItems[counter - 1];
            if (item) {
                // Calculate token ID: upc * 1000000000 + unitNumber
                // unitNumber = startingUnitNumber (from previous chunks) + counter - 1
                const startingUnitNumber = upcStartingUnitNumbers.get(upc) || 1;
                const unitNumber = startingUnitNumber + counter - 1;
                const v5TokenId = upc * 1000000000 + unitNumber;
                v4TokenIdToTokenId.set(item.metadata.tokenId, v5TokenId);
            }
        }
    });
    
    // Build UPC to token IDs mapping (in the order items will be minted)
    const upcTokenIds = new Map(); // Map<upc, Array<tokenId>>
    uniqueUpcs.forEach(upc => {
        upcTokenIds.set(upc, []);
    });
    
    // Populate in mint order (same as tierIdsInMintOrder)
    upcCounters.clear();
    tierIdsInMintOrder.forEach((upc) => {
        const counter = (upcCounters.get(upc) || 0) + 1;
        upcCounters.set(upc, counter);
        
        const upcItems = chunkItems.filter(item => item.metadata.upc === upc);
        const sortedUpcItems = [...upcItems].sort((a, b) => {
            return chunkItems.indexOf(a) - chunkItems.indexOf(b);
        });
        
        if (counter <= sortedUpcItems.length) {
            const item = sortedUpcItems[counter - 1];
            if (item) {
                const tokenId = v4TokenIdToTokenId.get(item.metadata.tokenId);
                if (tokenId && upcTokenIds.has(upc)) {
                    upcTokenIds.get(upc).push(tokenId);
                }
            }
        }
    });

    // Create a mapping from UPC to minted tokenIds for dressing
    const upcToMintedIds = new Map();

    contract += `
        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;
        `;
    
    // Populate sortedMintedIds with token IDs using the formula
    uniqueUpcs.forEach(upc => {
        const tokenIds = upcTokenIds.get(upc) || [];
        const quantity = tokenIds.length;
        if (quantity > 0) {
            contract += `
        // Populate UPC ${upc} minted tokenIds (${quantity} items)`;
            tokenIds.forEach((tokenId, index) => {
                contract += `
            sortedMintedIds.upc${upc}[${index}] = ${tokenId}; // Token ID: ${upc} * 1000000000 + ${index + 1}`;
            });
        }
        upcToMintedIds.set(upc, `sortedMintedIds.upc${upc}`);
    });

    // Always add approval for decorating
    contract += `
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);
        `;

    contract += `
        // Step 2: Process each Banny body and dress them
        `;

    // Add Banny dressing calls
    bannys.forEach((banny, index) => {
        if (banny.outfitIds.length > 0 || (banny.backgroundId && banny.backgroundId !== 0)) {
            contract += `
        // Dress Banny ${banny.tokenId} (${banny.productName})
        {
            uint256[] memory outfitIds = new uint256[](${banny.outfitIds.length});
            `;

            banny.outfitIds.forEach((v4OutfitId, outfitIndex) => {
                // Find the token ID for this outfit using the formula
                const tokenId = v4TokenIdToTokenId.get(v4OutfitId);
                if (tokenId) {
                    contract += `            outfitIds[${outfitIndex}] = ${tokenId}; // V4: ${v4OutfitId} -> V5: ${tokenId}\n`;
                } else {
                    // Fallback: use V4 token ID (shouldn't happen if outfit is in chunk)
                    contract += `            outfitIds[${outfitIndex}] = ${v4OutfitId}; // Fallback: V4 token ID (outfit not found in chunk)\n`;
                }
            });

            // Find the token ID for the background using the formula
            let v5BackgroundId = 0;
            if (banny.backgroundId && banny.backgroundId !== 0) {
                const bgTokenId = v4TokenIdToTokenId.get(banny.backgroundId);
                if (bgTokenId) {
                    v5BackgroundId = bgTokenId;
                } else {
                    v5BackgroundId = banny.backgroundId; // Fallback
                }
            }

            // Get token ID for the banny body using the formula
            const bannyTokenId = v4TokenIdToTokenId.get(banny.tokenId) || banny.tokenId;

            contract += `
            resolver.decorateBannyWith(
                address(hook),
                ${bannyTokenId},
                ${v5BackgroundId},
                outfitIds
            );
            `;

            contract += `
            MigrationHelper.verifyV4AssetMatch(
                resolver,
                v4Resolver,
                fallbackV4Resolver,
                address(hook),
                v4HookAddress,
                ${banny.tokenId}
            );
            `;

            contract += `
        }
        `;
        }
    });

    contract += `
        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);
        ${generateTokenIdArray(chunkItems, transferData, tierIdQuantities, upcStartingUnitNumbers)}
        
        uint256 successfulTransfers = 0;
        uint256 skippedResolverOwned = 0;
        
        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 tokenId = generatedTokenIds[i];
            // Verify V4 ownership before transferring V5
            address v4Owner = v4Hook.ownerOf(tokenId);
            require(v4Owner == transferOwners[i] || v4Owner == address(fallbackV4ResolverAddress), "V4/V5 ownership mismatch for token");
            
            // Skip transfer if V4 owner is the resolver (resolver holds these tokens, we shouldn't transfer to resolver)
            if (v4Owner == address(v4ResolverAddress) || v4Owner == address(fallbackV4ResolverAddress)) {
                // Token is held by resolver, skip transfer
                skippedResolverOwned++;
                continue;
            }
            
            IERC721(address(hook)).safeTransferFrom(
                address(this), 
                transferOwners[i], 
                tokenId
            );
            successfulTransfers++;
        }
        
        // Verify all expected items were processed (transferred or skipped as expected)
        require(
            successfulTransfers + skippedResolverOwned == transferOwners.length,
            "Not all items were processed"
        );
        
        // Final verification: Ensure this contract no longer owns any tokens
        // This ensures all transfers completed successfully and no tokens were left behind
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
        
        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)
        ${generateTierBalanceVerification(transferData, tierIdQuantities)}
    }
}`;

    // Fix indentation issues
    contract = contract.replace(/^                        outfitIds\[0\] =/gm, '            outfitIds[0] =');
    contract = contract.replace(/^                    }$/gm, '        }'); // Fix struct closing bracket indentation

    return contract;
}

function generateSingleChainContract(chain, chainItems) {
    // Process data for this chain
    const bannys = [];
    const outfits = [];
    const backgrounds = [];
    const tierIdQuantities = new Map(); // Map UPC to quantity needed
    const transferData = []; // Array of {tokenIndex, owner} for transfers

    chainItems.forEach(item => {
        const tokenId = item.metadata.tokenId;
        const upc = item.metadata.upc;
        const category = item.metadata.category;
        const categoryName = item.metadata.categoryName;
        const owner = toChecksumAddress(item.owner || (item.wallet ? item.wallet.address : '0x0000000000000000000000000000000000000000'));
        const productName = item.metadata.productName;

        // Count how many of each UPC we need
        tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);

        if (category === 0) {
            // Banny body
            bannys.push({
                tokenId,
                upc,
                backgroundId: item.metadata.backgroundId || 0,
                outfitIds: item.metadata.outfitIds || [],
                owner,
                productName
            });
        } else if (category === 1) {
            // Background
            backgrounds.push({
                tokenId,
                upc,
                owner,
                productName
            });
        } else {
            // Outfit
            outfits.push({
                tokenId,
                upc,
                category,
                categoryName,
                owner,
                productName
            });
        }
    });

    // Collect all outfitIds and backgroundIds that are being used
    // IMPORTANT: We determine which assets are worn/used by looking at outfitIds and backgroundId
    // on Banny body entries (category === 0). We do NOT use wornByBannyBodyId from outfit/background
    // entries as it is not reliable in raw.json.
    const usedOutfitIds = new Set();
    const usedBackgroundIds = new Set();

    bannys.forEach(banny => {
        if (banny.backgroundId && banny.backgroundId !== 0) {
            usedBackgroundIds.add(banny.backgroundId);
        }
        banny.outfitIds.forEach(outfitId => {
            usedOutfitIds.add(outfitId);
        });
    });

    // Build transfer data array
    const allItems = [...bannys, ...outfits, ...backgrounds];
    let transferIndex = 0;

    allItems.forEach((item, index) => {
        // Skip if owner is zero address
        if (item.owner === '0x0000000000000000000000000000000000000000') {
            return;
        }

        // Skip if this is an outfit being worn
        if (item.tokenId && usedOutfitIds.has(item.tokenId)) {
            return;
        }

        // Skip if this is a background being used
        if (item.tokenId && usedBackgroundIds.has(item.tokenId)) {
            return;
        }

        transferData.push({
            tokenIndex: transferIndex,
            owner: item.owner
        });
        transferIndex++;
    });

    let contract = `// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContract${chain.name} {
    address[] private transferOwners;
    
    constructor(address[] memory _transferOwners) {
        transferOwners = _transferOwners;
    }
    
    function executeMigration(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress
    ) external {
        
        // Validate addresses
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        Banny721TokenUriResolver resolver = Banny721TokenUriResolver(resolverAddress);
        IERC721 v4Hook = IERC721(v4HookAddress);
        Banny721TokenUriResolver v4Resolver = Banny721TokenUriResolver(v4ResolverAddress);
        Banny721TokenUriResolver fallbackV4Resolver = Banny721TokenUriResolver(fallbackV4ResolverAddress);
        
        // ${chain.name} migration - ${chainItems.length} items
        
        // Step 1: Assets are already minted to this contract by the deployer
        `;

    // Generate struct definition for minted token IDs
    const uniqueUpcs = Array.from(tierIdQuantities.keys()).sort((a, b) => a - b);

    // Generate struct definition at contract level
    let structDefinition = `
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
`;

    uniqueUpcs.forEach(upc => {
        const quantity = tierIdQuantities.get(upc);
        structDefinition += `        uint256[${quantity}] upc${upc};\n`;
    });

    structDefinition += `    }
    
    `;

    // Insert struct definition into contract
    const contractStart = `contract MigrationContract${chain.name} {`;
    const replacement = `${contractStart}${structDefinition}address[] private transferOwners;`;
    contract = contract.replace(`${contractStart}\n    address[] private transferOwners;`, replacement);

    contract += `
        
        // Assets are already minted to this contract by the deployer
        `;

    // Create a mapping from UPC to minted tokenIds for dressing
    const upcToMintedIds = new Map();

    contract += `
        // Create and populate the struct
        // Token IDs are generated as: UPC * 1000000000 + unitNumber (where unitNumber starts at 1)
        MintedIds memory sortedMintedIds;
        `;

    uniqueUpcs.forEach(upc => {
        const quantity = tierIdQuantities.get(upc);
        contract += `
        // Populate UPC ${upc} minted tokenIds (${quantity} items)
        for (uint256 i = 0; i < ${quantity}; i++) {
            sortedMintedIds.upc${upc}[i] = ${upc} * 1000000000 + (i + 1);
        }`;
        upcToMintedIds.set(upc, `sortedMintedIds.upc${upc}`);
    });

    // Check if there are any outfits or backgrounds that need approval
    const hasOutfitsOrBackgrounds = bannys.some(banny =>
        (banny.outfitIds && banny.outfitIds.length > 0) ||
        (banny.backgroundId && banny.backgroundId !== 0)
    );

    // Generate approval code using setApprovalForAll
    if (hasOutfitsOrBackgrounds) {
        contract += `
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);
        `;
    }

    contract += `
        // Step 2: Process each Banny body and dress them
        `;

    // Add Banny dressing calls
    bannys.forEach((banny, index) => {
        if (banny.outfitIds.length > 0) {
            contract += `
        // Dress Banny ${banny.tokenId} (${banny.productName})
        {
            uint256[] memory outfitIds = new uint256[](${banny.outfitIds.length});
            `;

            banny.outfitIds.forEach((v4OutfitId, outfitIndex) => {
                // Find which UPC this V4 outfitId corresponds to
                const matchingItem = chainItems.find(item => item.metadata.tokenId === v4OutfitId);
                if (matchingItem) {
                    const upc = matchingItem.metadata.upc;
                    const upcArrayName = upcToMintedIds.get(upc);
                    // Find the index of this specific outfitId within its UPC
                    const upcItems = chainItems.filter(item => item.metadata.upc === upc);
                    const itemIndex = upcItems.findIndex(item => item.metadata.tokenId === v4OutfitId);

                contract += `            outfitIds[${outfitIndex}] = ${upcArrayName}[${itemIndex}]; // V4: ${v4OutfitId} -> V5: ${upcArrayName}[${itemIndex}]\n`;
                } else {
                    // Fallback to V4 outfitId if we can't find the mapping
                    contract += `            outfitIds[${outfitIndex}] = ${v4OutfitId}; // Fallback: using V4 outfitId\n`;
                }
            });

            // Map backgroundId to V5 minted tokenId
            let v5BackgroundId = banny.backgroundId;
            if (banny.backgroundId && banny.backgroundId !== 0) {
                const backgroundItem = chainItems.find(item => item.metadata.tokenId === banny.backgroundId);
                if (backgroundItem) {
                    const upc = backgroundItem.metadata.upc;
                    const upcArrayName = upcToMintedIds.get(upc);
                    const upcItems = chainItems.filter(item => item.metadata.upc === upc);
                    const itemIndex = upcItems.findIndex(item => item.metadata.tokenId === banny.backgroundId);
                    v5BackgroundId = `${upcArrayName}[${itemIndex}]`;
                }
            }

            contract += `
            resolver.decorateBannyWith(
                address(hook),
                ${banny.tokenId},
                ${v5BackgroundId},
                outfitIds
            );
            `;
            
            contract += `
            MigrationHelper.verifyV4AssetMatch(
                resolver,
                v4Resolver,
                fallbackV4Resolver,
                address(hook),
                v4HookAddress,
                ${banny.tokenId}
            );
            `;

            contract += `
        }
        `;
        }
    });

    contract += `
        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);
        ${generateTokenIdArray(chainItems, transferData, tierIdQuantities)}
        
        uint256 successfulTransfers = 0;
        uint256 skippedResolverOwned = 0;
        
        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 tokenId = generatedTokenIds[i];
            // Verify V4 ownership before transferring V5
            address v4Owner = v4Hook.ownerOf(tokenId);
            require(v4Owner == transferOwners[i] || v4Owner == address(fallbackV4ResolverAddress), "V4/V5 ownership mismatch for token");
            
            // Skip transfer if V4 owner is the resolver (resolver holds these tokens, we shouldn't transfer to resolver)
            if (v4Owner == address(v4ResolverAddress) || v4Owner == address(fallbackV4ResolverAddress)) {
                // Token is held by resolver, skip transfer
                skippedResolverOwned++;
                continue;
            }
            
            IERC721(address(hook)).transferFrom(
                address(this), 
                transferOwners[i], 
                tokenId
            );
            successfulTransfers++;
        }
        
        // Verify all expected items were processed (transferred or skipped as expected)
        require(
            successfulTransfers + skippedResolverOwned == transferOwners.length,
            "Not all items were processed"
        );
        
        // Final verification: Ensure this contract no longer owns any tokens
        // This ensures all transfers completed successfully and no tokens were left behind
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
        
        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)
        ${generateTierBalanceVerification(transferData, tierIdQuantities)}
    }
}`;

    // Fix indentation issues
    contract = contract.replace(/^                        outfitIds\[0\] =/gm, '            outfitIds[0] =');
    contract = contract.replace(/^                    }$/gm, '        }'); // Fix struct closing bracket indentation

    return contract;
}

function generateUnusedAssetsContract(chain, chainItems, upcStartingUnitNumbers = new Map(), processedTokenIds = new Set(), totalProcessedInChunks = 0) {
    // Process data for this chain
    const bannys = [];
    const outfits = [];
    const backgrounds = [];
    
    chainItems.forEach(item => {
        const tokenId = item.metadata.tokenId;
        const upc = item.metadata.upc;
        const category = item.metadata.category;
        const owner = toChecksumAddress(item.owner || (item.wallet ? item.wallet.address : '0x0000000000000000000000000000000000000000'));
        
        if (category === 0) {
            // Banny body
            bannys.push({
                tokenId,
                upc,
                backgroundId: item.metadata.backgroundId || 0,
                outfitIds: item.metadata.outfitIds || [],
                owner
            });
        } else if (category === 1) {
            // Background
            backgrounds.push({
                tokenId,
                upc,
                owner
            });
        } else {
            // Outfit
            outfits.push({
                tokenId,
                upc,
                category,
                owner
            });
        }
    });
    
    // Collect all outfitIds and backgroundIds that are being used
    // IMPORTANT: We determine which assets are worn/used by looking at outfitIds and backgroundId
    // on Banny body entries (category === 0). We do NOT use wornByBannyBodyId from outfit/background
    // entries as it is not reliable in raw.json.
    const usedOutfitIds = new Set();
    const usedBackgroundIds = new Set();
    
    bannys.forEach(banny => {
        if (banny.backgroundId && banny.backgroundId !== 0) {
            // Ensure consistent type (number) for Set comparison
            usedBackgroundIds.add(Number(banny.backgroundId));
        }
        banny.outfitIds.forEach(outfitId => {
            // Ensure consistent type (number) for Set comparison
            usedOutfitIds.add(Number(outfitId));
        });
    });
    
    // V4 resolver addresses - items owned by these are being worn/used, so exclude them
    const v4ResolverAddress = '0xa5F8911d4CFd60a6697479f078409434424fe666';
    const v4ResolverFallback = '0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3';
    
    // Find unused outfits and backgrounds
    // Also filter out items owned by resolver (these are being worn/used)
    // AND filter out items already processed in chunks 1-3 (or 1-2 for Base)
    // Track filtered items for logging
    const filteredItems = [];
    
    const unusedOutfits = outfits.filter(outfit => {
        const tokenId = Number(outfit.tokenId);
        const owner = outfit.owner.toLowerCase();
        const reasons = [];
        
        if (usedOutfitIds.has(tokenId)) {
            reasons.push('being-worn');
        }
        if (processedTokenIds.has(tokenId)) {
            reasons.push('already-processed');
        }
        if (owner === '0x0000000000000000000000000000000000000000') {
            reasons.push('zero-address');
        }
        if (owner === v4ResolverAddress.toLowerCase()) {
            reasons.push('resolver-owned');
        }
        if (owner === v4ResolverFallback.toLowerCase()) {
            reasons.push('resolver-owned');
        }
        
        if (reasons.length > 0) {
            filteredItems.push({
                tokenId: outfit.tokenId,
                upc: outfit.upc,
                owner: outfit.owner,
                category: 'outfit',
                reasons: reasons
            });
            return false;
        }
        return true;
    });
    
    const unusedBackgrounds = backgrounds.filter(bg => {
        const tokenId = Number(bg.tokenId);
        const owner = bg.owner.toLowerCase();
        const reasons = [];
        
        if (usedBackgroundIds.has(tokenId)) {
            reasons.push('being-worn');
        }
        if (processedTokenIds.has(tokenId)) {
            reasons.push('already-processed');
        }
        if (owner === '0x0000000000000000000000000000000000000000') {
            reasons.push('zero-address');
        }
        if (owner === v4ResolverAddress.toLowerCase()) {
            reasons.push('resolver-owned');
        }
        if (owner === v4ResolverFallback.toLowerCase()) {
            reasons.push('resolver-owned');
        }
        
        if (reasons.length > 0) {
            filteredItems.push({
                tokenId: bg.tokenId,
                upc: bg.upc,
                owner: bg.owner,
                category: 'background',
                reasons: reasons
            });
            return false;
        }
        return true;
    });
    
    const unusedItems = [...unusedOutfits, ...unusedBackgrounds];
    
    // Filter out items with zero address owners (already filtered above, but keeping for clarity)
    const unusedItemsWithOwners = unusedItems.filter(item => 
        item.owner !== '0x0000000000000000000000000000000000000000'
    );
    
    // Calculate how many items were filtered out
    // Total items in raw.json for this chain = chainItems.length
    // Processed in chunks = totalProcessedInChunks (passed as parameter)
    // Unused items = unusedItemsWithOwners.length
    // Filtered = total - processed in chunks - unused items
    const filteredCount = chainItems.length - totalProcessedInChunks - unusedItemsWithOwners.length;
    
    // Validate that all items have valid token IDs
    // If a token ID is in raw.json but doesn't exist in V4, this indicates a data issue
    const invalidItems = unusedItemsWithOwners.filter(item => {
        // Token IDs should be positive numbers
        const tokenId = Number(item.tokenId);
        return !tokenId || tokenId <= 0 || isNaN(tokenId);
    });
    
    if (invalidItems.length > 0) {
        console.error(`ERROR: Found ${invalidItems.length} items with invalid token IDs in unused assets:`);
        invalidItems.forEach(item => {
            console.error(`  - Token ID: ${item.tokenId}, UPC: ${item.upc}, Owner: ${item.owner}`);
        });
        throw new Error(`Invalid token IDs found in unused assets. This indicates a data issue in raw.json.`);
    }
    
    if (unusedItemsWithOwners.length === 0) {
        return null; // No unused assets to migrate
    }
    
    // Sort unused items by UPC to match mint order (same as in generateTokenIdArrayForUnused)
    // This ensures transferOwners and token IDs are in the same order
    const sortedUnusedItems = [...unusedItemsWithOwners].sort((a, b) => {
        if (a.upc !== b.upc) {
            return a.upc - b.upc;
        }
        // Within same UPC, maintain original order
        return unusedItemsWithOwners.indexOf(a) - unusedItemsWithOwners.indexOf(b);
    });
    
    // Calculate tier ID quantities for unused items
    const tierIdQuantities = new Map();
    sortedUnusedItems.forEach(item => {
        const upc = item.upc;
        tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
    });
    
    // Build transfer data array (in sorted order to match token ID order)
    const transferData = sortedUnusedItems.map((item, index) => ({
        tokenIndex: index,
        owner: item.owner,
        tokenId: item.tokenId,
        upc: item.upc
    }));
    
    let contract = `// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

/// @notice Migration contract for ${chain.name} to handle standalone outfits and backgrounds
/// that are not worn/used by any banny. These assets are minted to this contract
/// and then transferred directly to their owners.
contract MigrationContract${chain.name}${chain.numChunks + 1} {
    address[] private transferOwners;
    
    constructor(address[] memory _transferOwners) {
        transferOwners = _transferOwners;
    }
    
    function executeMigration(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress
    ) external {
        
        // Validate addresses
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        
        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 v4Hook = IERC721(v4HookAddress);
        
        // ${chain.name} migration - Standalone outfits and backgrounds (${unusedItemsWithOwners.length} items)
        // These are assets that are NOT being worn/used by any banny
        
        // Assets are already minted to this contract by the deployer
        // V5 token IDs are calculated based on mint order (continuing from previous chunks)
        // V4 token IDs are the original token IDs from V4
        
        // Generate token IDs - store both V5 minted token IDs and original V4 token IDs
        uint256[] memory v5TokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        ${generateTokenIdArrayForUnused(sortedUnusedItems, tierIdQuantities, upcStartingUnitNumbers)}
        
        uint256 successfulTransfers = 0;
        
        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 v5TokenId = v5TokenIds[i];
            uint256 v4TokenId = v4TokenIds[i];
            
            // Verify V4 ownership using the original V4 token ID
            // This will revert if the token doesn't exist, which indicates a data issue
            address v4Owner = v4Hook.ownerOf(v4TokenId);
            address expectedOwner = transferOwners[i];
            
            // If V4 owner is the main resolver, this token is being worn/used and shouldn't be in unused assets contract
            require(
                v4Owner != address(v4ResolverAddress),
                "Token owned by main resolver in V4 - should not be in unused assets contract"
            );
            
            // Special case: If V4 owner is the fallback resolver BUT expected owner is NOT a resolver,
            // this is valid - the asset is being worn in V4 but we're minting directly to the actual owner in V5
            // raw.json already accounts for this and has the correct owner
            if (v4Owner == address(fallbackV4ResolverAddress)) {
                // Allow if expected owner is not a resolver (we're minting directly to owner in V5)
                require(
                    expectedOwner != address(v4ResolverAddress) && expectedOwner != address(fallbackV4ResolverAddress),
                    "Token owned by fallback resolver in V4 but expected owner is also a resolver - should not be in unused assets contract"
                );
                // Skip ownership verification in this case - we trust raw.json
            } else {
                // For all other cases, verify V4 owner matches expected owner
                require(v4Owner == expectedOwner, "V4/V5 ownership mismatch for token");
            }
            
            // Verify this contract owns the V5 token before transferring
            require(hook.ownerOf(v5TokenId) == address(this), "Contract does not own token");
            
            // Transfer using the minted V5 token ID
            IERC721(address(hook)).safeTransferFrom(
                address(this), 
                transferOwners[i], 
                v5TokenId
            );
            successfulTransfers++;
        }
        
        // Verify all expected items were transferred
        require(
            successfulTransfers == transferOwners.length,
            "Not all items were transferred"
        );
        
        // Final verification: Ensure this contract no longer owns any tokens
        // This ensures all transfers completed successfully and no tokens were left behind
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
        
        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)
        ${generateTierBalanceVerification(transferData, tierIdQuantities)}
    }
}`;
    
    return {
        contract,
        transferData,
        tierIdQuantities,
        unusedItems: sortedUnusedItems,
        filteredCount: filteredCount,
        filteredItems: filteredItems
    };
}

function generateUnusedAssetsContractFromItems(chain, unusedItems, upcStartingUnitNumbers, contractNumber) {
    if (unusedItems.length === 0) {
        return null;
    }
    
    // Sort unused items by UPC to match mint order
    const sortedUnusedItems = [...unusedItems].sort((a, b) => {
        if (a.upc !== b.upc) {
            return a.upc - b.upc;
        }
        return unusedItems.indexOf(a) - unusedItems.indexOf(b);
    });
    
    // Calculate tier ID quantities for unused items
    const tierIdQuantities = new Map();
    sortedUnusedItems.forEach(item => {
        const upc = item.upc;
        tierIdQuantities.set(upc, (tierIdQuantities.get(upc) || 0) + 1);
    });
    
    // Build transfer data array
    const transferData = sortedUnusedItems.map((item, index) => ({
        tokenIndex: index,
        owner: item.owner,
        tokenId: item.tokenId,
        upc: item.upc
    }));
    
    let contract = `// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

/// @notice Migration contract for ${chain.name} to handle standalone outfits and backgrounds
/// that are not worn/used by any banny. These assets are minted to this contract
/// and then transferred directly to their owners.
contract MigrationContract${chain.name}${contractNumber} {
    address[] private transferOwners;
    
    constructor(address[] memory _transferOwners) {
        transferOwners = _transferOwners;
    }
    
    function executeMigration(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress
    ) external {
        
        // Validate addresses
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        
        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 v4Hook = IERC721(v4HookAddress);
        
        // ${chain.name} migration - Standalone outfits and backgrounds (${sortedUnusedItems.length} items)
        // These are assets that are NOT being worn/used by any banny
        
        // Assets are already minted to this contract by the deployer
        // V5 token IDs are calculated based on mint order (continuing from previous chunks)
        // V4 token IDs are the original token IDs from V4
        
        // Generate token IDs - store both V5 minted token IDs and original V4 token IDs
        uint256[] memory v5TokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        ${generateTokenIdArrayForUnused(sortedUnusedItems, tierIdQuantities, upcStartingUnitNumbers)}
        
        uint256 successfulTransfers = 0;
        
        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 v5TokenId = v5TokenIds[i];
            uint256 v4TokenId = v4TokenIds[i];
            
            // Verify V4 ownership using the original V4 token ID
            address v4Owner = v4Hook.ownerOf(v4TokenId);
            address expectedOwner = transferOwners[i];
            
            require(
                v4Owner != address(v4ResolverAddress),
                "Token owned by main resolver in V4 - should not be in unused assets contract"
            );
            
            if (v4Owner == address(fallbackV4ResolverAddress)) {
                require(
                    expectedOwner != address(v4ResolverAddress) && expectedOwner != address(fallbackV4ResolverAddress),
                    "Token owned by fallback resolver in V4 but expected owner is also a resolver - should not be in unused assets contract"
                );
            } else {
                require(v4Owner == expectedOwner, "V4/V5 ownership mismatch for token");
            }
            
            require(hook.ownerOf(v5TokenId) == address(this), "Contract does not own token");
            
            IERC721(address(hook)).safeTransferFrom(
                address(this), 
                transferOwners[i], 
                v5TokenId
            );
            successfulTransfers++;
        }
        
        require(
            successfulTransfers == transferOwners.length,
            "Not all items were transferred"
        );
        
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
        
        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)
        ${generateTierBalanceVerification(transferData, tierIdQuantities)}
    }
}`;
    
    return contract;
}

function generateTokenIdArrayForUnused(unusedItems, tierIdQuantities, upcStartingUnitNumbers) {
    // Build mapping from unused items to their minted token IDs
    // Tokens are minted in UPC-sorted order, and token IDs continue from previous chunks
    // Formula: upc * 1000000000 + unitNumber (where unitNumber continues from previous chunks)
    const upcCounters = new Map();
    const itemToMintedTokenId = new Map();
    
    // Sort unused items by UPC to match mint order
    // Note: unusedItems should already be sorted when passed in, but we sort again to be safe
    const sortedByUpc = [...unusedItems].sort((a, b) => {
        if (a.upc !== b.upc) {
            return a.upc - b.upc;
        }
        // Within same UPC, maintain original order from the passed array
        return unusedItems.indexOf(a) - unusedItems.indexOf(b);
    });
    
    // Calculate minted token IDs based on mint order
    sortedByUpc.forEach(item => {
        const upc = item.upc;
        const counter = (upcCounters.get(upc) || 0) + 1;
        upcCounters.set(upc, counter);
        
        // Calculate the actual minted token ID
        // unitNumber = startingUnitNumber (from previous chunks) + counter - 1
        const startingUnitNumber = upcStartingUnitNumbers.get(upc) || 1;
        const unitNumber = startingUnitNumber + counter - 1;
        const mintedTokenId = upc * 1000000000 + unitNumber;
        
        // Map the original item to its minted token ID
        itemToMintedTokenId.set(item, mintedTokenId);
    });
    
    // Generate code in the order of sortedByUpc (mint order) to match token ID calculation
    // Store both V5 minted token IDs and original V4 token IDs
    let code = '';
    sortedByUpc.forEach((item, index) => {
        const mintedTokenId = itemToMintedTokenId.get(item);
        const v4TokenId = item.tokenId;
        
        if (mintedTokenId) {
            // Store both V5 minted token ID and original V4 token ID
            code += `        v5TokenIds[${index}] = ${mintedTokenId}; // Minted V5 Token ID\n`;
            code += `        v4TokenIds[${index}] = ${v4TokenId}; // Original V4 Token ID\n`;
        } else {
            // Fallback: use V4 token ID for both (shouldn't happen)
            code += `        v5TokenIds[${index}] = ${v4TokenId}; // Fallback: V4 token ID\n`;
            code += `        v4TokenIds[${index}] = ${v4TokenId}; // Fallback: V4 token ID\n`;
        }
    });
    
    return code;
}

// Run the script generation
generateMigrationScript();
