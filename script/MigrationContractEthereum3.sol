// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractEthereum3 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[20] upc4;
        uint256[1] upc5;
        uint256[1] upc6;
        uint256[4] upc10;
        uint256[1] upc15;
        uint256[1] upc18;
        uint256[3] upc19;
        uint256[1] upc20;
        uint256[2] upc25;
        uint256[1] upc26;
        uint256[2] upc31;
        uint256[1] upc35;
        uint256[1] upc42;
        uint256[1] upc43;
        uint256[1] upc44;
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

        // Ethereum migration chunk 3/6 - 42 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (20 items)
        sortedMintedIds.upc4[0] = 4_000_000_008; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_009; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_010; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_011; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_012; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_013; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_014; // Token ID: 4 * 1000000000 + 7
        sortedMintedIds.upc4[7] = 4_000_000_015; // Token ID: 4 * 1000000000 + 8
        sortedMintedIds.upc4[8] = 4_000_000_016; // Token ID: 4 * 1000000000 + 9
        sortedMintedIds.upc4[9] = 4_000_000_017; // Token ID: 4 * 1000000000 + 10
        sortedMintedIds.upc4[10] = 4_000_000_018; // Token ID: 4 * 1000000000 + 11
        sortedMintedIds.upc4[11] = 4_000_000_019; // Token ID: 4 * 1000000000 + 12
        sortedMintedIds.upc4[12] = 4_000_000_020; // Token ID: 4 * 1000000000 + 13
        sortedMintedIds.upc4[13] = 4_000_000_021; // Token ID: 4 * 1000000000 + 14
        sortedMintedIds.upc4[14] = 4_000_000_022; // Token ID: 4 * 1000000000 + 15
        sortedMintedIds.upc4[15] = 4_000_000_023; // Token ID: 4 * 1000000000 + 16
        sortedMintedIds.upc4[16] = 4_000_000_024; // Token ID: 4 * 1000000000 + 17
        sortedMintedIds.upc4[17] = 4_000_000_025; // Token ID: 4 * 1000000000 + 18
        sortedMintedIds.upc4[18] = 4_000_000_026; // Token ID: 4 * 1000000000 + 19
        sortedMintedIds.upc4[19] = 4_000_000_027; // Token ID: 4 * 1000000000 + 20
        // Populate UPC 5 minted tokenIds (1 items)
        sortedMintedIds.upc5[0] = 5_000_000_005; // Token ID: 5 * 1000000000 + 1
        // Populate UPC 6 minted tokenIds (1 items)
        sortedMintedIds.upc6[0] = 6_000_000_006; // Token ID: 6 * 1000000000 + 1
        // Populate UPC 10 minted tokenIds (4 items)
        sortedMintedIds.upc10[0] = 10_000_000_002; // Token ID: 10 * 1000000000 + 1
        sortedMintedIds.upc10[1] = 10_000_000_003; // Token ID: 10 * 1000000000 + 2
        sortedMintedIds.upc10[2] = 10_000_000_004; // Token ID: 10 * 1000000000 + 3
        sortedMintedIds.upc10[3] = 10_000_000_005; // Token ID: 10 * 1000000000 + 4
        // Populate UPC 15 minted tokenIds (1 items)
        sortedMintedIds.upc15[0] = 15_000_000_002; // Token ID: 15 * 1000000000 + 1
        // Populate UPC 18 minted tokenIds (1 items)
        sortedMintedIds.upc18[0] = 18_000_000_002; // Token ID: 18 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (3 items)
        sortedMintedIds.upc19[0] = 19_000_000_005; // Token ID: 19 * 1000000000 + 1
        sortedMintedIds.upc19[1] = 19_000_000_006; // Token ID: 19 * 1000000000 + 2
        sortedMintedIds.upc19[2] = 19_000_000_007; // Token ID: 19 * 1000000000 + 3
        // Populate UPC 20 minted tokenIds (1 items)
        sortedMintedIds.upc20[0] = 20_000_000_001; // Token ID: 20 * 1000000000 + 1
        // Populate UPC 25 minted tokenIds (2 items)
        sortedMintedIds.upc25[0] = 25_000_000_004; // Token ID: 25 * 1000000000 + 1
        sortedMintedIds.upc25[1] = 25_000_000_005; // Token ID: 25 * 1000000000 + 2
        // Populate UPC 26 minted tokenIds (1 items)
        sortedMintedIds.upc26[0] = 26_000_000_004; // Token ID: 26 * 1000000000 + 1
        // Populate UPC 31 minted tokenIds (2 items)
        sortedMintedIds.upc31[0] = 31_000_000_003; // Token ID: 31 * 1000000000 + 1
        sortedMintedIds.upc31[1] = 31_000_000_004; // Token ID: 31 * 1000000000 + 2
        // Populate UPC 35 minted tokenIds (1 items)
        sortedMintedIds.upc35[0] = 35_000_000_005; // Token ID: 35 * 1000000000 + 1
        // Populate UPC 42 minted tokenIds (1 items)
        sortedMintedIds.upc42[0] = 42_000_000_002; // Token ID: 42 * 1000000000 + 1
        // Populate UPC 43 minted tokenIds (1 items)
        sortedMintedIds.upc43[0] = 43_000_000_004; // Token ID: 43 * 1000000000 + 1
        // Populate UPC 44 minted tokenIds (1 items)
        sortedMintedIds.upc44[0] = 44_000_000_003; // Token ID: 44 * 1000000000 + 1
        // Populate UPC 49 minted tokenIds (1 items)
        sortedMintedIds.upc49[0] = 49_000_000_002; // Token ID: 49 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 4000000009 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10_000_000_002; // V4: 10000000001 -> V5: 10000000002
            outfitIds[1] = 19_000_000_005; // V4: 19000000002 -> V5: 19000000005
            outfitIds[2] = 25_000_000_004; // V4: 25000000002 -> V5: 25000000004
            outfitIds[3] = 43_000_000_004; // V4: 43000000003 -> V5: 43000000004

            resolver.decorateBannyWith(address(hook), 4_000_000_009, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_009
            );
        }

        // Dress Banny 4000000010 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10_000_000_003; // V4: 10000000002 -> V5: 10000000003
            outfitIds[1] = 18_000_000_002; // V4: 18000000001 -> V5: 18000000002
            outfitIds[2] = 20_000_000_001; // V4: 20000000001 -> V5: 20000000001
            outfitIds[3] = 44_000_000_003; // V4: 44000000001 -> V5: 44000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_010, 5_000_000_005, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_010
            );
        }

        // Dress Banny 4000000013 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 31_000_000_003; // V4: 31000000002 -> V5: 31000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_013, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_013
            );
        }

        // Dress Banny 4000000014 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10_000_000_004; // V4: 10000000006 -> V5: 10000000004
            outfitIds[1] = 19_000_000_006; // V4: 19000000004 -> V5: 19000000006
            outfitIds[2] = 25_000_000_005; // V4: 25000000003 -> V5: 25000000005
            outfitIds[3] = 49_000_000_002; // V4: 49000000001 -> V5: 49000000002

            resolver.decorateBannyWith(address(hook), 4_000_000_014, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_014
            );
        }

        // Dress Banny 4000000015 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 15_000_000_002; // V4: 15000000001 -> V5: 15000000002
            outfitIds[1] = 26_000_000_004; // V4: 26000000002 -> V5: 26000000004

            resolver.decorateBannyWith(address(hook), 4_000_000_015, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_015
            );
        }

        // Dress Banny 4000000016 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 10_000_000_005; // V4: 10000000007 -> V5: 10000000005

            resolver.decorateBannyWith(address(hook), 4_000_000_016, 6_000_000_006, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_016
            );
        }

        // Dress Banny 4000000019 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19_000_000_007; // V4: 19000000005 -> V5: 19000000007
            outfitIds[1] = 35_000_000_005; // V4: 35000000003 -> V5: 35000000005
            outfitIds[2] = 42_000_000_002; // V4: 42000000002 -> V5: 42000000002

            resolver.decorateBannyWith(address(hook), 4_000_000_019, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_019
            );
        }

        // Dress Banny 4000000023 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 31_000_000_004; // V4: 31000000007 -> V5: 31000000004

            resolver.decorateBannyWith(address(hook), 4_000_000_023, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_023
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_008; // Token ID (V4: 4000000008)
        generatedTokenIds[1] = 4_000_000_009; // Token ID (V4: 4000000009)
        generatedTokenIds[2] = 4_000_000_010; // Token ID (V4: 4000000010)
        generatedTokenIds[3] = 4_000_000_011; // Token ID (V4: 4000000011)
        generatedTokenIds[4] = 4_000_000_012; // Token ID (V4: 4000000012)
        generatedTokenIds[5] = 4_000_000_013; // Token ID (V4: 4000000013)
        generatedTokenIds[6] = 4_000_000_014; // Token ID (V4: 4000000014)
        generatedTokenIds[7] = 4_000_000_015; // Token ID (V4: 4000000015)
        generatedTokenIds[8] = 4_000_000_016; // Token ID (V4: 4000000016)
        generatedTokenIds[9] = 4_000_000_017; // Token ID (V4: 4000000017)
        generatedTokenIds[10] = 4_000_000_018; // Token ID (V4: 4000000018)
        generatedTokenIds[11] = 4_000_000_019; // Token ID (V4: 4000000019)
        generatedTokenIds[12] = 4_000_000_020; // Token ID (V4: 4000000020)
        generatedTokenIds[13] = 4_000_000_021; // Token ID (V4: 4000000021)
        generatedTokenIds[14] = 4_000_000_022; // Token ID (V4: 4000000022)
        generatedTokenIds[15] = 4_000_000_023; // Token ID (V4: 4000000023)
        generatedTokenIds[16] = 4_000_000_024; // Token ID (V4: 4000000024)
        generatedTokenIds[17] = 4_000_000_025; // Token ID (V4: 4000000025)
        generatedTokenIds[18] = 4_000_000_026; // Token ID (V4: 4000000026)
        generatedTokenIds[19] = 4_000_000_027; // Token ID (V4: 4000000027)

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
        // address[] memory uniqueOwners = new address[](14);

        // uniqueOwners[0] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        // uniqueOwners[1] = 0x5706d5aD7A68bf8692bD341234bE44ca7Bf2f654;
        // uniqueOwners[2] = 0x679d87D8640e66778c3419D164998E720D7495f6;
        // uniqueOwners[3] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        // uniqueOwners[4] = 0x4A290F18c35bBFE97B2557cf765De9387726dE39;
        // uniqueOwners[5] = 0x25171bD3cD3231c3057c96F38E32E3bA6681497a;
        // uniqueOwners[6] = 0xa7226e53F3100C093A0a5BCb6E3D0976EB3db1D6;
        // uniqueOwners[7] = 0x76A6D08b82034b397E7e09dAe4377C18F132BbB8;
        // uniqueOwners[8] = 0x809C9f8dd8CA93A41c3adca4972Fa234C28F7714;
        // uniqueOwners[9] = 0x126eeFa566ABF5aC3EfDAeF52d79E962CFFdB448;
        // uniqueOwners[10] = 0x77fb4fa1ABA92576942aD34BC47834059b84e693;
        // uniqueOwners[11] = 0x08cEb8Bba685ee708C9c4c65576837cbE19B9dea;
        // uniqueOwners[12] = 0x690C01b4b1389D9D9265820F77DCbD2A6Ad04e6c;
        // uniqueOwners[13] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](16);

        // uniqueTierIds[0] = 4;
        // uniqueTierIds[1] = 5;
        // uniqueTierIds[2] = 6;
        // uniqueTierIds[3] = 10;
        // uniqueTierIds[4] = 15;
        // uniqueTierIds[5] = 18;
        // uniqueTierIds[6] = 19;
        // uniqueTierIds[7] = 20;
        // uniqueTierIds[8] = 25;
        // uniqueTierIds[9] = 26;
        // uniqueTierIds[10] = 31;
        // uniqueTierIds[11] = 35;
        // uniqueTierIds[12] = 42;
        // uniqueTierIds[13] = 43;
        // uniqueTierIds[14] = 44;
        // uniqueTierIds[15] = 49;

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
