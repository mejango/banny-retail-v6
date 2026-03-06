// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractArbitrum3 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[3] upc4;
        uint256[1] upc5;
        uint256[1] upc10;
        uint256[1] upc20;
        uint256[1] upc28;
        uint256[1] upc43;
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

        // Arbitrum migration chunk 3/3 - 8 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (3 items)
        sortedMintedIds.upc4[0] = 4_000_000_007; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_008; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_009; // Token ID: 4 * 1000000000 + 3
        // Populate UPC 5 minted tokenIds (1 items)
        sortedMintedIds.upc5[0] = 5_000_000_002; // Token ID: 5 * 1000000000 + 1
        // Populate UPC 10 minted tokenIds (1 items)
        sortedMintedIds.upc10[0] = 10_000_000_002; // Token ID: 10 * 1000000000 + 1
        // Populate UPC 20 minted tokenIds (1 items)
        sortedMintedIds.upc20[0] = 20_000_000_002; // Token ID: 20 * 1000000000 + 1
        // Populate UPC 28 minted tokenIds (1 items)
        sortedMintedIds.upc28[0] = 28_000_000_002; // Token ID: 28 * 1000000000 + 1
        // Populate UPC 43 minted tokenIds (1 items)
        sortedMintedIds.upc43[0] = 43_000_000_001; // Token ID: 43 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 4000000007 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 10_000_000_002; // V4: 10000000002 -> V5: 10000000002
            outfitIds[1] = 20_000_000_002; // V4: 20000000002 -> V5: 20000000002
            outfitIds[2] = 43_000_000_001; // V4: 43000000001 -> V5: 43000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_007, 5_000_000_002, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_007
            );
        }

        // Dress Banny 4000000009 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 28_000_000_002; // V4: 28000000002 -> V5: 28000000002

            resolver.decorateBannyWith(address(hook), 4_000_000_009, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_009
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_007; // Token ID (V4: 4000000007)
        generatedTokenIds[1] = 4_000_000_008; // Token ID (V4: 4000000008)
        generatedTokenIds[2] = 4_000_000_009; // Token ID (V4: 4000000009)

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
        // address[] memory uniqueOwners = new address[](2);

        // uniqueOwners[0] = 0xB2d3900807094D4Fe47405871B0C8AdB58E10D42;
        // uniqueOwners[1] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](6);

        // uniqueTierIds[0] = 4;
        // uniqueTierIds[1] = 5;
        // uniqueTierIds[2] = 10;
        // uniqueTierIds[3] = 20;
        // uniqueTierIds[4] = 28;
        // uniqueTierIds[5] = 43;

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
