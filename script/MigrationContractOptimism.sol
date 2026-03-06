// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractOptimism {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[2] upc3;
        uint256[3] upc4;
        uint256[1] upc11;
        uint256[1] upc17;
        uint256[1] upc19;
        uint256[1] upc25;
        uint256[1] upc44;
        uint256[1] upc47;
    }

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
    )
        external
    {
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

        // Optimism migration - 11 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs are generated as: UPC * 1000000000 + unitNumber (where unitNumber starts at 1)
        MintedIds memory sortedMintedIds;

        // Populate UPC 3 minted tokenIds (2 items)
        for (uint256 i = 0; i < 2; i++) {
            sortedMintedIds.upc3[i] = 3 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 4 minted tokenIds (3 items)
        for (uint256 i = 0; i < 3; i++) {
            sortedMintedIds.upc4[i] = 4 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 11 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc11[i] = 11 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 17 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc17[i] = 17 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 19 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc19[i] = 19 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 25 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc25[i] = 25 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 44 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc44[i] = 44 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 47 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc47[i] = 47 * 1_000_000_000 + (i + 1);
        }
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 3000000001 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = sortedMintedIds.upc11[0]; // V4: 11000000001 -> V5: sortedMintedIds.upc11[0]
            outfitIds[1] = sortedMintedIds.upc19[0]; // V4: 19000000001 -> V5: sortedMintedIds.upc19[0]
            outfitIds[2] = sortedMintedIds.upc25[0]; // V4: 25000000001 -> V5: sortedMintedIds.upc25[0]
            outfitIds[3] = sortedMintedIds.upc44[0]; // V4: 44000000001 -> V5: sortedMintedIds.upc44[0]

            resolver.decorateBannyWith(address(hook), 3_000_000_001, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_001
            );
        }

        // Dress Banny 4000000001 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = sortedMintedIds.upc47[0]; // V4: 47000000001 -> V5: sortedMintedIds.upc47[0]

            resolver.decorateBannyWith(address(hook), 4_000_000_001, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_001
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 3_000_000_001; // Token ID (V4: 3000000001)
        generatedTokenIds[1] = 3_000_000_002; // Token ID (V4: 3000000002)
        generatedTokenIds[2] = 4_000_000_001; // Token ID (V4: 4000000001)
        generatedTokenIds[3] = 4_000_000_002; // Token ID (V4: 4000000002)
        generatedTokenIds[4] = 4_000_000_003; // Token ID (V4: 4000000003)
        generatedTokenIds[5] = 17_000_000_001; // Token ID (V4: 17000000001)

        uint256 successfulTransfers = 0;
        uint256 skippedResolverOwned = 0;

        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 tokenId = generatedTokenIds[i];
            // Verify V4 ownership before transferring V5
            address v4Owner = v4Hook.ownerOf(tokenId);
            require(
                v4Owner == transferOwners[i] || v4Owner == address(fallbackV4ResolverAddress),
                "V4/V5 ownership mismatch for token"
            );

            // Skip transfer if V4 owner is the resolver (resolver holds these tokens, we shouldn't transfer to
            // resolver)
            if (v4Owner == address(v4ResolverAddress) || v4Owner == address(fallbackV4ResolverAddress)) {
                // Token is held by resolver, skip transfer
                skippedResolverOwned++;
                continue;
            }

            IERC721(address(hook)).transferFrom(address(this), transferOwners[i], tokenId);
            successfulTransfers++;
        }

        // Verify all expected items were processed (transferred or skipped as expected)
        require(successfulTransfers + skippedResolverOwned == transferOwners.length, "Not all items were processed");

        // Final verification: Ensure this contract no longer owns any tokens
        // This ensures all transfers completed successfully and no tokens were left behind
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");

        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)

        // Collect unique owners
        address[] memory uniqueOwners = new address[](5);

        uniqueOwners[0] = 0x25910143C255828F623786f46fe9A8941B7983bB;
        uniqueOwners[1] = 0x292ff025168D2B51f0Ef49f164D281c36761BA2b;
        uniqueOwners[2] = 0xA7a5A2745f10D5C23d75a6fd228A408cEDe1CAE5;
        uniqueOwners[3] = 0x57700212B1cB7b67bD7DF3801DA43CA634513fE0;
        uniqueOwners[4] = 0xA2Fa6144168751D116336B58C5288feaF8bb12C1;

        // Collect unique tier IDs
        uint256[] memory uniqueTierIds = new uint256[](8);

        uniqueTierIds[0] = 3;
        uniqueTierIds[1] = 4;
        uniqueTierIds[2] = 11;
        uniqueTierIds[3] = 17;
        uniqueTierIds[4] = 19;
        uniqueTierIds[5] = 25;
        uniqueTierIds[6] = 44;
        uniqueTierIds[7] = 47;

        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)
        MigrationHelper.verifyTierBalances(
            hookAddress, v4HookAddress, fallbackV4ResolverAddress, uniqueOwners, uniqueTierIds
        );
    }
}
