// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractBase2 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[27] upc4;
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

        // Base migration chunk 2/4 - 27 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (27 items)
        sortedMintedIds.upc4[0] = 4_000_000_015; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_016; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_017; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_018; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_019; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_020; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_021; // Token ID: 4 * 1000000000 + 7
        sortedMintedIds.upc4[7] = 4_000_000_022; // Token ID: 4 * 1000000000 + 8
        sortedMintedIds.upc4[8] = 4_000_000_023; // Token ID: 4 * 1000000000 + 9
        sortedMintedIds.upc4[9] = 4_000_000_024; // Token ID: 4 * 1000000000 + 10
        sortedMintedIds.upc4[10] = 4_000_000_025; // Token ID: 4 * 1000000000 + 11
        sortedMintedIds.upc4[11] = 4_000_000_026; // Token ID: 4 * 1000000000 + 12
        sortedMintedIds.upc4[12] = 4_000_000_027; // Token ID: 4 * 1000000000 + 13
        sortedMintedIds.upc4[13] = 4_000_000_028; // Token ID: 4 * 1000000000 + 14
        sortedMintedIds.upc4[14] = 4_000_000_029; // Token ID: 4 * 1000000000 + 15
        sortedMintedIds.upc4[15] = 4_000_000_030; // Token ID: 4 * 1000000000 + 16
        sortedMintedIds.upc4[16] = 4_000_000_031; // Token ID: 4 * 1000000000 + 17
        sortedMintedIds.upc4[17] = 4_000_000_032; // Token ID: 4 * 1000000000 + 18
        sortedMintedIds.upc4[18] = 4_000_000_033; // Token ID: 4 * 1000000000 + 19
        sortedMintedIds.upc4[19] = 4_000_000_034; // Token ID: 4 * 1000000000 + 20
        sortedMintedIds.upc4[20] = 4_000_000_035; // Token ID: 4 * 1000000000 + 21
        sortedMintedIds.upc4[21] = 4_000_000_036; // Token ID: 4 * 1000000000 + 22
        sortedMintedIds.upc4[22] = 4_000_000_037; // Token ID: 4 * 1000000000 + 23
        sortedMintedIds.upc4[23] = 4_000_000_038; // Token ID: 4 * 1000000000 + 24
        sortedMintedIds.upc4[24] = 4_000_000_039; // Token ID: 4 * 1000000000 + 25
        sortedMintedIds.upc4[25] = 4_000_000_040; // Token ID: 4 * 1000000000 + 26
        sortedMintedIds.upc4[26] = 4_000_000_041; // Token ID: 4 * 1000000000 + 27
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_015; // Token ID (V4: 4000000015)
        generatedTokenIds[1] = 4_000_000_016; // Token ID (V4: 4000000016)
        generatedTokenIds[2] = 4_000_000_017; // Token ID (V4: 4000000017)
        generatedTokenIds[3] = 4_000_000_018; // Token ID (V4: 4000000018)
        generatedTokenIds[4] = 4_000_000_019; // Token ID (V4: 4000000019)
        generatedTokenIds[5] = 4_000_000_020; // Token ID (V4: 4000000020)
        generatedTokenIds[6] = 4_000_000_021; // Token ID (V4: 4000000021)
        generatedTokenIds[7] = 4_000_000_022; // Token ID (V4: 4000000022)
        generatedTokenIds[8] = 4_000_000_023; // Token ID (V4: 4000000023)
        generatedTokenIds[9] = 4_000_000_024; // Token ID (V4: 4000000024)
        generatedTokenIds[10] = 4_000_000_025; // Token ID (V4: 4000000025)
        generatedTokenIds[11] = 4_000_000_026; // Token ID (V4: 4000000026)
        generatedTokenIds[12] = 4_000_000_027; // Token ID (V4: 4000000027)
        generatedTokenIds[13] = 4_000_000_028; // Token ID (V4: 4000000028)
        generatedTokenIds[14] = 4_000_000_029; // Token ID (V4: 4000000029)
        generatedTokenIds[15] = 4_000_000_030; // Token ID (V4: 4000000030)
        generatedTokenIds[16] = 4_000_000_031; // Token ID (V4: 4000000031)
        generatedTokenIds[17] = 4_000_000_032; // Token ID (V4: 4000000032)
        generatedTokenIds[18] = 4_000_000_033; // Token ID (V4: 4000000033)
        generatedTokenIds[19] = 4_000_000_034; // Token ID (V4: 4000000034)
        generatedTokenIds[20] = 4_000_000_035; // Token ID (V4: 4000000035)
        generatedTokenIds[21] = 4_000_000_036; // Token ID (V4: 4000000036)
        generatedTokenIds[22] = 4_000_000_037; // Token ID (V4: 4000000037)
        generatedTokenIds[23] = 4_000_000_038; // Token ID (V4: 4000000038)
        generatedTokenIds[24] = 4_000_000_039; // Token ID (V4: 4000000039)
        generatedTokenIds[25] = 4_000_000_040; // Token ID (V4: 4000000040)
        generatedTokenIds[26] = 4_000_000_041; // Token ID (V4: 4000000041)

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

            IERC721(address(hook)).safeTransferFrom(address(this), transferOwners[i], tokenId);
            successfulTransfers++;
        }

        // Verify all expected items were processed (transferred or skipped as expected)
        require(successfulTransfers + skippedResolverOwned == transferOwners.length, "Not all items were processed");

        // Final verification: Ensure this contract no longer owns any tokens
        // This ensures all transfers completed successfully and no tokens were left behind
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");

        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)

        // // Collect unique owners
        // address[] memory uniqueOwners = new address[](1);

        // uniqueOwners[0] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](1);

        // uniqueTierIds[0] = 4;

        // // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)
        // MigrationHelper.verifyTierBalances(
        //     hookAddress,
        //     v4HookAddress,
        //     fallbackV4ResolverAddress,
        //     uniqueOwners,
        //     uniqueTierIds
        // );
    }
}
