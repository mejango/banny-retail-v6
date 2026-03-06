// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractArbitrum2 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[4] upc4;
        uint256[1] upc6;
        uint256[1] upc10;
        uint256[1] upc11;
        uint256[1] upc19;
        uint256[1] upc20;
        uint256[1] upc28;
        uint256[1] upc31;
        uint256[1] upc49;
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

        // Arbitrum migration chunk 2/3 - 12 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (4 items)
        sortedMintedIds.upc4[0] = 4_000_000_003; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_004; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_005; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_006; // Token ID: 4 * 1000000000 + 4
        // Populate UPC 6 minted tokenIds (1 items)
        sortedMintedIds.upc6[0] = 6_000_000_001; // Token ID: 6 * 1000000000 + 1
        // Populate UPC 10 minted tokenIds (1 items)
        sortedMintedIds.upc10[0] = 10_000_000_001; // Token ID: 10 * 1000000000 + 1
        // Populate UPC 11 minted tokenIds (1 items)
        sortedMintedIds.upc11[0] = 11_000_000_001; // Token ID: 11 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (1 items)
        sortedMintedIds.upc19[0] = 19_000_000_002; // Token ID: 19 * 1000000000 + 1
        // Populate UPC 20 minted tokenIds (1 items)
        sortedMintedIds.upc20[0] = 20_000_000_001; // Token ID: 20 * 1000000000 + 1
        // Populate UPC 28 minted tokenIds (1 items)
        sortedMintedIds.upc28[0] = 28_000_000_001; // Token ID: 28 * 1000000000 + 1
        // Populate UPC 31 minted tokenIds (1 items)
        sortedMintedIds.upc31[0] = 31_000_000_001; // Token ID: 31 * 1000000000 + 1
        // Populate UPC 49 minted tokenIds (1 items)
        sortedMintedIds.upc49[0] = 49_000_000_001; // Token ID: 49 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 4000000003 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 11_000_000_001; // V4: 11000000001 -> V5: 11000000001
            outfitIds[1] = 19_000_000_002; // V4: 19000000003 -> V5: 19000000002
            outfitIds[2] = 28_000_000_001; // V4: 28000000001 -> V5: 28000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_003, 6_000_000_001, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_003
            );
        }

        // Dress Banny 4000000004 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 10_000_000_001; // V4: 10000000001 -> V5: 10000000001
            outfitIds[1] = 20_000_000_001; // V4: 20000000001 -> V5: 20000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_004, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_004
            );
        }

        // Dress Banny 4000000005 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 31_000_000_001; // V4: 31000000001 -> V5: 31000000001
            outfitIds[1] = 49_000_000_001; // V4: 49000000002 -> V5: 49000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_005, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_005
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_003; // Token ID (V4: 4000000003)
        generatedTokenIds[1] = 4_000_000_004; // Token ID (V4: 4000000004)
        generatedTokenIds[2] = 4_000_000_005; // Token ID (V4: 4000000005)
        generatedTokenIds[3] = 4_000_000_006; // Token ID (V4: 4000000006)

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
        // address[] memory uniqueOwners = new address[](4);

        // uniqueOwners[0] = 0x08B3e694caA2F1fcF8eF71095CED1326f3454B89;
        // uniqueOwners[1] = 0x9fDf876a50EA8f95017dCFC7709356887025B5BB;
        // uniqueOwners[2] = 0x187089B33E5812310Ed32A57F53B3fAD0383a19D;
        // uniqueOwners[3] = 0xc6404f24DB2f573F07F3A60758765caad198c0c3;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](9);

        // uniqueTierIds[0] = 4;
        // uniqueTierIds[1] = 6;
        // uniqueTierIds[2] = 10;
        // uniqueTierIds[3] = 11;
        // uniqueTierIds[4] = 19;
        // uniqueTierIds[5] = 20;
        // uniqueTierIds[6] = 28;
        // uniqueTierIds[7] = 31;
        // uniqueTierIds[8] = 49;

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
