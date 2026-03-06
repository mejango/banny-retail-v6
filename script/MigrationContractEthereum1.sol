// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractEthereum1 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[1] upc1;
        uint256[6] upc2;
        uint256[13] upc3;
        uint256[3] upc5;
        uint256[3] upc6;
        uint256[2] upc7;
        uint256[1] upc10;
        uint256[2] upc14;
        uint256[1] upc17;
        uint256[1] upc18;
        uint256[3] upc19;
        uint256[1] upc21;
        uint256[1] upc23;
        uint256[1] upc25;
        uint256[3] upc26;
        uint256[2] upc31;
        uint256[2] upc32;
        uint256[4] upc35;
        uint256[1] upc37;
        uint256[1] upc39;
        uint256[3] upc43;
        uint256[2] upc44;
        uint256[1] upc46;
        uint256[1] upc47;
        uint256[1] upc48;
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

        // Ethereum migration chunk 1/6 - 60 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 1 minted tokenIds (1 items)
        sortedMintedIds.upc1[0] = 1_000_000_001; // Token ID: 1 * 1000000000 + 1
        // Populate UPC 2 minted tokenIds (6 items)
        sortedMintedIds.upc2[0] = 2_000_000_001; // Token ID: 2 * 1000000000 + 1
        sortedMintedIds.upc2[1] = 2_000_000_002; // Token ID: 2 * 1000000000 + 2
        sortedMintedIds.upc2[2] = 2_000_000_003; // Token ID: 2 * 1000000000 + 3
        sortedMintedIds.upc2[3] = 2_000_000_004; // Token ID: 2 * 1000000000 + 4
        sortedMintedIds.upc2[4] = 2_000_000_005; // Token ID: 2 * 1000000000 + 5
        sortedMintedIds.upc2[5] = 2_000_000_006; // Token ID: 2 * 1000000000 + 6
        // Populate UPC 3 minted tokenIds (13 items)
        sortedMintedIds.upc3[0] = 3_000_000_001; // Token ID: 3 * 1000000000 + 1
        sortedMintedIds.upc3[1] = 3_000_000_002; // Token ID: 3 * 1000000000 + 2
        sortedMintedIds.upc3[2] = 3_000_000_003; // Token ID: 3 * 1000000000 + 3
        sortedMintedIds.upc3[3] = 3_000_000_004; // Token ID: 3 * 1000000000 + 4
        sortedMintedIds.upc3[4] = 3_000_000_005; // Token ID: 3 * 1000000000 + 5
        sortedMintedIds.upc3[5] = 3_000_000_006; // Token ID: 3 * 1000000000 + 6
        sortedMintedIds.upc3[6] = 3_000_000_007; // Token ID: 3 * 1000000000 + 7
        sortedMintedIds.upc3[7] = 3_000_000_008; // Token ID: 3 * 1000000000 + 8
        sortedMintedIds.upc3[8] = 3_000_000_009; // Token ID: 3 * 1000000000 + 9
        sortedMintedIds.upc3[9] = 3_000_000_010; // Token ID: 3 * 1000000000 + 10
        sortedMintedIds.upc3[10] = 3_000_000_011; // Token ID: 3 * 1000000000 + 11
        sortedMintedIds.upc3[11] = 3_000_000_012; // Token ID: 3 * 1000000000 + 12
        sortedMintedIds.upc3[12] = 3_000_000_013; // Token ID: 3 * 1000000000 + 13
        // Populate UPC 5 minted tokenIds (3 items)
        sortedMintedIds.upc5[0] = 5_000_000_001; // Token ID: 5 * 1000000000 + 1
        sortedMintedIds.upc5[1] = 5_000_000_002; // Token ID: 5 * 1000000000 + 2
        sortedMintedIds.upc5[2] = 5_000_000_003; // Token ID: 5 * 1000000000 + 3
        // Populate UPC 6 minted tokenIds (3 items)
        sortedMintedIds.upc6[0] = 6_000_000_001; // Token ID: 6 * 1000000000 + 1
        sortedMintedIds.upc6[1] = 6_000_000_002; // Token ID: 6 * 1000000000 + 2
        sortedMintedIds.upc6[2] = 6_000_000_003; // Token ID: 6 * 1000000000 + 3
        // Populate UPC 7 minted tokenIds (2 items)
        sortedMintedIds.upc7[0] = 7_000_000_001; // Token ID: 7 * 1000000000 + 1
        sortedMintedIds.upc7[1] = 7_000_000_002; // Token ID: 7 * 1000000000 + 2
        // Populate UPC 10 minted tokenIds (1 items)
        sortedMintedIds.upc10[0] = 10_000_000_001; // Token ID: 10 * 1000000000 + 1
        // Populate UPC 14 minted tokenIds (2 items)
        sortedMintedIds.upc14[0] = 14_000_000_001; // Token ID: 14 * 1000000000 + 1
        sortedMintedIds.upc14[1] = 14_000_000_002; // Token ID: 14 * 1000000000 + 2
        // Populate UPC 17 minted tokenIds (1 items)
        sortedMintedIds.upc17[0] = 17_000_000_001; // Token ID: 17 * 1000000000 + 1
        // Populate UPC 18 minted tokenIds (1 items)
        sortedMintedIds.upc18[0] = 18_000_000_001; // Token ID: 18 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (3 items)
        sortedMintedIds.upc19[0] = 19_000_000_001; // Token ID: 19 * 1000000000 + 1
        sortedMintedIds.upc19[1] = 19_000_000_002; // Token ID: 19 * 1000000000 + 2
        sortedMintedIds.upc19[2] = 19_000_000_003; // Token ID: 19 * 1000000000 + 3
        // Populate UPC 21 minted tokenIds (1 items)
        sortedMintedIds.upc21[0] = 21_000_000_001; // Token ID: 21 * 1000000000 + 1
        // Populate UPC 23 minted tokenIds (1 items)
        sortedMintedIds.upc23[0] = 23_000_000_001; // Token ID: 23 * 1000000000 + 1
        // Populate UPC 25 minted tokenIds (1 items)
        sortedMintedIds.upc25[0] = 25_000_000_001; // Token ID: 25 * 1000000000 + 1
        // Populate UPC 26 minted tokenIds (3 items)
        sortedMintedIds.upc26[0] = 26_000_000_001; // Token ID: 26 * 1000000000 + 1
        sortedMintedIds.upc26[1] = 26_000_000_002; // Token ID: 26 * 1000000000 + 2
        sortedMintedIds.upc26[2] = 26_000_000_003; // Token ID: 26 * 1000000000 + 3
        // Populate UPC 31 minted tokenIds (2 items)
        sortedMintedIds.upc31[0] = 31_000_000_001; // Token ID: 31 * 1000000000 + 1
        sortedMintedIds.upc31[1] = 31_000_000_002; // Token ID: 31 * 1000000000 + 2
        // Populate UPC 32 minted tokenIds (2 items)
        sortedMintedIds.upc32[0] = 32_000_000_001; // Token ID: 32 * 1000000000 + 1
        sortedMintedIds.upc32[1] = 32_000_000_002; // Token ID: 32 * 1000000000 + 2
        // Populate UPC 35 minted tokenIds (4 items)
        sortedMintedIds.upc35[0] = 35_000_000_001; // Token ID: 35 * 1000000000 + 1
        sortedMintedIds.upc35[1] = 35_000_000_002; // Token ID: 35 * 1000000000 + 2
        sortedMintedIds.upc35[2] = 35_000_000_003; // Token ID: 35 * 1000000000 + 3
        sortedMintedIds.upc35[3] = 35_000_000_004; // Token ID: 35 * 1000000000 + 4
        // Populate UPC 37 minted tokenIds (1 items)
        sortedMintedIds.upc37[0] = 37_000_000_001; // Token ID: 37 * 1000000000 + 1
        // Populate UPC 39 minted tokenIds (1 items)
        sortedMintedIds.upc39[0] = 39_000_000_001; // Token ID: 39 * 1000000000 + 1
        // Populate UPC 43 minted tokenIds (3 items)
        sortedMintedIds.upc43[0] = 43_000_000_001; // Token ID: 43 * 1000000000 + 1
        sortedMintedIds.upc43[1] = 43_000_000_002; // Token ID: 43 * 1000000000 + 2
        sortedMintedIds.upc43[2] = 43_000_000_003; // Token ID: 43 * 1000000000 + 3
        // Populate UPC 44 minted tokenIds (2 items)
        sortedMintedIds.upc44[0] = 44_000_000_001; // Token ID: 44 * 1000000000 + 1
        sortedMintedIds.upc44[1] = 44_000_000_002; // Token ID: 44 * 1000000000 + 2
        // Populate UPC 46 minted tokenIds (1 items)
        sortedMintedIds.upc46[0] = 46_000_000_001; // Token ID: 46 * 1000000000 + 1
        // Populate UPC 47 minted tokenIds (1 items)
        sortedMintedIds.upc47[0] = 47_000_000_001; // Token ID: 47 * 1000000000 + 1
        // Populate UPC 48 minted tokenIds (1 items)
        sortedMintedIds.upc48[0] = 48_000_000_001; // Token ID: 48 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 1000000001 (Alien)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 7_000_000_002; // V4: 7000000002 -> V5: 7000000002
            outfitIds[1] = 17_000_000_001; // V4: 17000000001 -> V5: 17000000001
            outfitIds[2] = 26_000_000_003; // V4: 26000000004 -> V5: 26000000003
            outfitIds[3] = 46_000_000_001; // V4: 46000000001 -> V5: 46000000001

            resolver.decorateBannyWith(address(hook), 1_000_000_001, 5_000_000_001, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 1_000_000_001
            );
        }

        // Dress Banny 2000000002 (Pink)
        {
            uint256[] memory outfitIds = new uint256[](5);
            outfitIds[0] = 7_000_000_001; // V4: 7000000001 -> V5: 7000000001
            outfitIds[1] = 14_000_000_002; // V4: 14000000003 -> V5: 14000000002
            outfitIds[2] = 19_000_000_002; // V4: 19000000012 -> V5: 19000000002
            outfitIds[3] = 26_000_000_002; // V4: 26000000003 -> V5: 26000000002
            outfitIds[4] = 35_000_000_004; // V4: 35000000006 -> V5: 35000000004

            resolver.decorateBannyWith(address(hook), 2_000_000_002, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 2_000_000_002
            );
        }

        // Dress Banny 2000000004 (Pink)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 18_000_000_001; // V4: 18000000002 -> V5: 18000000001

            resolver.decorateBannyWith(address(hook), 2_000_000_004, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 2_000_000_004
            );
        }

        // Dress Banny 2000000005 (Pink)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 21_000_000_001; // V4: 21000000001 -> V5: 21000000001

            resolver.decorateBannyWith(address(hook), 2_000_000_005, 5_000_000_002, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 2_000_000_005
            );
        }

        // Dress Banny 2000000006 (Pink)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 19_000_000_003; // V4: 19000000019 -> V5: 19000000003
            outfitIds[1] = 25_000_000_001; // V4: 25000000009 -> V5: 25000000001

            resolver.decorateBannyWith(address(hook), 2_000_000_006, 5_000_000_003, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 2_000_000_006
            );
        }

        // Dress Banny 3000000001 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 14_000_000_001; // V4: 14000000001 -> V5: 14000000001
            outfitIds[1] = 26_000_000_001; // V4: 26000000001 -> V5: 26000000001
            outfitIds[2] = 35_000_000_001; // V4: 35000000001 -> V5: 35000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_001, 6_000_000_001, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_001
            );
        }

        // Dress Banny 3000000003 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 10_000_000_001; // V4: 10000000005 -> V5: 10000000001
            outfitIds[1] = 44_000_000_001; // V4: 44000000003 -> V5: 44000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_003, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_003
            );
        }

        // Dress Banny 3000000006 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 32_000_000_001; // V4: 32000000001 -> V5: 32000000001
            outfitIds[1] = 44_000_000_002; // V4: 44000000004 -> V5: 44000000002

            resolver.decorateBannyWith(address(hook), 3_000_000_006, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_006
            );
        }

        // Dress Banny 3000000007 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 31_000_000_001; // V4: 31000000003 -> V5: 31000000001
            outfitIds[1] = 47_000_000_001; // V4: 47000000003 -> V5: 47000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_007, 6_000_000_002, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_007
            );
        }

        // Dress Banny 3000000009 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 35_000_000_002; // V4: 35000000002 -> V5: 35000000002
            outfitIds[1] = 43_000_000_001; // V4: 43000000005 -> V5: 43000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_009, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_009
            );
        }

        // Dress Banny 3000000010 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 32_000_000_002; // V4: 32000000002 -> V5: 32000000002
            outfitIds[1] = 35_000_000_003; // V4: 35000000004 -> V5: 35000000003
            outfitIds[2] = 48_000_000_001; // V4: 48000000001 -> V5: 48000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_010, 6_000_000_003, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_010
            );
        }

        // Dress Banny 3000000011 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 23_000_000_001; // V4: 23000000001 -> V5: 23000000001
            outfitIds[1] = 39_000_000_001; // V4: 39000000001 -> V5: 39000000001
            outfitIds[2] = 43_000_000_002; // V4: 43000000006 -> V5: 43000000002

            resolver.decorateBannyWith(address(hook), 3_000_000_011, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_011
            );
        }

        // Dress Banny 3000000013 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 19_000_000_001; // V4: 19000000008 -> V5: 19000000001
            outfitIds[1] = 31_000_000_002; // V4: 31000000006 -> V5: 31000000002
            outfitIds[2] = 37_000_000_001; // V4: 37000000001 -> V5: 37000000001
            outfitIds[3] = 43_000_000_003; // V4: 43000000007 -> V5: 43000000003

            resolver.decorateBannyWith(address(hook), 3_000_000_013, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_013
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 1_000_000_001; // Token ID (V4: 1000000001)
        generatedTokenIds[1] = 2_000_000_001; // Token ID (V4: 2000000001)
        generatedTokenIds[2] = 2_000_000_002; // Token ID (V4: 2000000002)
        generatedTokenIds[3] = 2_000_000_003; // Token ID (V4: 2000000003)
        generatedTokenIds[4] = 2_000_000_004; // Token ID (V4: 2000000004)
        generatedTokenIds[5] = 2_000_000_005; // Token ID (V4: 2000000005)
        generatedTokenIds[6] = 2_000_000_006; // Token ID (V4: 2000000006)
        generatedTokenIds[7] = 3_000_000_001; // Token ID (V4: 3000000001)
        generatedTokenIds[8] = 3_000_000_002; // Token ID (V4: 3000000002)
        generatedTokenIds[9] = 3_000_000_003; // Token ID (V4: 3000000003)
        generatedTokenIds[10] = 3_000_000_004; // Token ID (V4: 3000000004)
        generatedTokenIds[11] = 3_000_000_005; // Token ID (V4: 3000000005)
        generatedTokenIds[12] = 3_000_000_006; // Token ID (V4: 3000000006)
        generatedTokenIds[13] = 3_000_000_007; // Token ID (V4: 3000000007)
        generatedTokenIds[14] = 3_000_000_008; // Token ID (V4: 3000000008)
        generatedTokenIds[15] = 3_000_000_009; // Token ID (V4: 3000000009)
        generatedTokenIds[16] = 3_000_000_010; // Token ID (V4: 3000000010)
        generatedTokenIds[17] = 3_000_000_011; // Token ID (V4: 3000000011)
        generatedTokenIds[18] = 3_000_000_012; // Token ID (V4: 3000000012)
        generatedTokenIds[19] = 3_000_000_013; // Token ID (V4: 3000000013)

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
        // address[] memory uniqueOwners = new address[](19);

        // uniqueOwners[0] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        // uniqueOwners[1] = 0xA2Fa6144168751D116336B58C5288feaF8bb12C1;
        // uniqueOwners[2] = 0x63A2368F4B509438ca90186cb1C15156713D5834;
        // uniqueOwners[3] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        // uniqueOwners[4] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        // uniqueOwners[5] = 0x5dee86b297755b3F2ce65e09BA3A700579A9020B;
        // uniqueOwners[6] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        // uniqueOwners[7] = 0xa13d49fCbf79EAF6A0a58cBDD3361422DB4eAfF1;
        // uniqueOwners[8] = 0x516cAfD745Ec780D20f61c0d71fe258eA765222D;
        // uniqueOwners[9] = 0x126eeFa566ABF5aC3EfDAeF52d79E962CFFdB448;
        // uniqueOwners[10] = 0x289715fFBB2f4b482e2917D2f183FeAb564ec84F;
        // uniqueOwners[11] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        // uniqueOwners[12] = 0x1786D033D5CbCC235B673e872c7613c2F83DA583;
        // uniqueOwners[13] = 0x38EED3CCeED88f380E436eb21811250797c453C5;
        // uniqueOwners[14] = 0xE16a238d207B9ac8B419C7A866b0De013c73357B;
        // uniqueOwners[15] = 0x0b2c9E0ee3057f4B9b0c2e42894a3D5A9B32b5Af;
        // uniqueOwners[16] = 0x0Cb1D93daEc77Df2ED7Db31C040Fd2174452bD9F;
        // uniqueOwners[17] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        // uniqueOwners[18] = 0x6a099Bb96DDF3963d5AddCAbDC0221914cF80b1F;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](25);

        // uniqueTierIds[0] = 1;
        // uniqueTierIds[1] = 2;
        // uniqueTierIds[2] = 3;
        // uniqueTierIds[3] = 5;
        // uniqueTierIds[4] = 6;
        // uniqueTierIds[5] = 7;
        // uniqueTierIds[6] = 10;
        // uniqueTierIds[7] = 14;
        // uniqueTierIds[8] = 17;
        // uniqueTierIds[9] = 18;
        // uniqueTierIds[10] = 19;
        // uniqueTierIds[11] = 21;
        // uniqueTierIds[12] = 23;
        // uniqueTierIds[13] = 25;
        // uniqueTierIds[14] = 26;
        // uniqueTierIds[15] = 31;
        // uniqueTierIds[16] = 32;
        // uniqueTierIds[17] = 35;
        // uniqueTierIds[18] = 37;
        // uniqueTierIds[19] = 39;
        // uniqueTierIds[20] = 43;
        // uniqueTierIds[21] = 44;
        // uniqueTierIds[22] = 46;
        // uniqueTierIds[23] = 47;
        // uniqueTierIds[24] = 48;

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
