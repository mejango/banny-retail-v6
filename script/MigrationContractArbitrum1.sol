// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractArbitrum1 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[2] upc3;
        uint256[2] upc4;
        uint256[1] upc5;
        uint256[1] upc19;
        uint256[1] upc25;
        uint256[1] upc38;
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

        // Arbitrum migration chunk 1/3 - 9 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 3 minted tokenIds (2 items)
        sortedMintedIds.upc3[0] = 3_000_000_001; // Token ID: 3 * 1000000000 + 1
        sortedMintedIds.upc3[1] = 3_000_000_002; // Token ID: 3 * 1000000000 + 2
        // Populate UPC 4 minted tokenIds (2 items)
        sortedMintedIds.upc4[0] = 4_000_000_001; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_002; // Token ID: 4 * 1000000000 + 2
        // Populate UPC 5 minted tokenIds (1 items)
        sortedMintedIds.upc5[0] = 5_000_000_001; // Token ID: 5 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (1 items)
        sortedMintedIds.upc19[0] = 19_000_000_001; // Token ID: 19 * 1000000000 + 1
        // Populate UPC 25 minted tokenIds (1 items)
        sortedMintedIds.upc25[0] = 25_000_000_001; // Token ID: 25 * 1000000000 + 1
        // Populate UPC 38 minted tokenIds (1 items)
        sortedMintedIds.upc38[0] = 38_000_000_001; // Token ID: 38 * 1000000000 + 1
        // Populate UPC 47 minted tokenIds (1 items)
        sortedMintedIds.upc47[0] = 47_000_000_001; // Token ID: 47 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 3000000001 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 19_000_000_001; // V4: 19000000001 -> V5: 19000000001
            outfitIds[1] = 25_000_000_001; // V4: 25000000001 -> V5: 25000000001
            outfitIds[2] = 38_000_000_001; // V4: 38000000001 -> V5: 38000000001
            outfitIds[3] = 47_000_000_001; // V4: 47000000001 -> V5: 47000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_001, 5_000_000_001, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_001
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 3_000_000_001; // Token ID (V4: 3000000001)
        generatedTokenIds[1] = 3_000_000_002; // Token ID (V4: 3000000002)
        generatedTokenIds[2] = 4_000_000_001; // Token ID (V4: 4000000001)
        generatedTokenIds[3] = 4_000_000_002; // Token ID (V4: 4000000002)

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

        // uniqueOwners[0] = 0x2aa64E6d80390F5C017F0313cB908051BE2FD35e;
        // uniqueOwners[1] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        // uniqueOwners[2] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        // uniqueOwners[3] = 0xfD282d9f4d06C4BDc6a41af1Ae920A0AD70D18a3;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](7);

        // uniqueTierIds[0] = 3;
        // uniqueTierIds[1] = 4;
        // uniqueTierIds[2] = 5;
        // uniqueTierIds[3] = 19;
        // uniqueTierIds[4] = 25;
        // uniqueTierIds[5] = 38;
        // uniqueTierIds[6] = 47;

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
