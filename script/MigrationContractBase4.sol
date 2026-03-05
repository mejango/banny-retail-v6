// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractBase4 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[26] upc4;
        uint256[2] upc5;
        uint256[1] upc10;
        uint256[1] upc13;
        uint256[2] upc19;
        uint256[1] upc20;
        uint256[2] upc25;
        uint256[1] upc27;
        uint256[1] upc28;
        uint256[1] upc35;
        uint256[1] upc38;
        uint256[1] upc39;
        uint256[1] upc41;
        uint256[3] upc43;
        uint256[1] upc44;
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

        // Base migration chunk 4/4 - 46 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (26 items)
        sortedMintedIds.upc4[0] = 4_000_000_069; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_070; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_071; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_072; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_073; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_074; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_075; // Token ID: 4 * 1000000000 + 7
        sortedMintedIds.upc4[7] = 4_000_000_076; // Token ID: 4 * 1000000000 + 8
        sortedMintedIds.upc4[8] = 4_000_000_077; // Token ID: 4 * 1000000000 + 9
        sortedMintedIds.upc4[9] = 4_000_000_078; // Token ID: 4 * 1000000000 + 10
        sortedMintedIds.upc4[10] = 4_000_000_079; // Token ID: 4 * 1000000000 + 11
        sortedMintedIds.upc4[11] = 4_000_000_080; // Token ID: 4 * 1000000000 + 12
        sortedMintedIds.upc4[12] = 4_000_000_081; // Token ID: 4 * 1000000000 + 13
        sortedMintedIds.upc4[13] = 4_000_000_082; // Token ID: 4 * 1000000000 + 14
        sortedMintedIds.upc4[14] = 4_000_000_083; // Token ID: 4 * 1000000000 + 15
        sortedMintedIds.upc4[15] = 4_000_000_084; // Token ID: 4 * 1000000000 + 16
        sortedMintedIds.upc4[16] = 4_000_000_085; // Token ID: 4 * 1000000000 + 17
        sortedMintedIds.upc4[17] = 4_000_000_086; // Token ID: 4 * 1000000000 + 18
        sortedMintedIds.upc4[18] = 4_000_000_087; // Token ID: 4 * 1000000000 + 19
        sortedMintedIds.upc4[19] = 4_000_000_088; // Token ID: 4 * 1000000000 + 20
        sortedMintedIds.upc4[20] = 4_000_000_089; // Token ID: 4 * 1000000000 + 21
        sortedMintedIds.upc4[21] = 4_000_000_090; // Token ID: 4 * 1000000000 + 22
        sortedMintedIds.upc4[22] = 4_000_000_091; // Token ID: 4 * 1000000000 + 23
        sortedMintedIds.upc4[23] = 4_000_000_092; // Token ID: 4 * 1000000000 + 24
        sortedMintedIds.upc4[24] = 4_000_000_093; // Token ID: 4 * 1000000000 + 25
        sortedMintedIds.upc4[25] = 4_000_000_094; // Token ID: 4 * 1000000000 + 26
        // Populate UPC 5 minted tokenIds (2 items)
        sortedMintedIds.upc5[0] = 5_000_000_002; // Token ID: 5 * 1000000000 + 1
        sortedMintedIds.upc5[1] = 5_000_000_003; // Token ID: 5 * 1000000000 + 2
        // Populate UPC 10 minted tokenIds (1 items)
        sortedMintedIds.upc10[0] = 10_000_000_005; // Token ID: 10 * 1000000000 + 1
        // Populate UPC 13 minted tokenIds (1 items)
        sortedMintedIds.upc13[0] = 13_000_000_001; // Token ID: 13 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (2 items)
        sortedMintedIds.upc19[0] = 19_000_000_006; // Token ID: 19 * 1000000000 + 1
        sortedMintedIds.upc19[1] = 19_000_000_007; // Token ID: 19 * 1000000000 + 2
        // Populate UPC 20 minted tokenIds (1 items)
        sortedMintedIds.upc20[0] = 20_000_000_001; // Token ID: 20 * 1000000000 + 1
        // Populate UPC 25 minted tokenIds (2 items)
        sortedMintedIds.upc25[0] = 25_000_000_007; // Token ID: 25 * 1000000000 + 1
        sortedMintedIds.upc25[1] = 25_000_000_008; // Token ID: 25 * 1000000000 + 2
        // Populate UPC 27 minted tokenIds (1 items)
        sortedMintedIds.upc27[0] = 27_000_000_001; // Token ID: 27 * 1000000000 + 1
        // Populate UPC 28 minted tokenIds (1 items)
        sortedMintedIds.upc28[0] = 28_000_000_006; // Token ID: 28 * 1000000000 + 1
        // Populate UPC 35 minted tokenIds (1 items)
        sortedMintedIds.upc35[0] = 35_000_000_001; // Token ID: 35 * 1000000000 + 1
        // Populate UPC 38 minted tokenIds (1 items)
        sortedMintedIds.upc38[0] = 38_000_000_002; // Token ID: 38 * 1000000000 + 1
        // Populate UPC 39 minted tokenIds (1 items)
        sortedMintedIds.upc39[0] = 39_000_000_001; // Token ID: 39 * 1000000000 + 1
        // Populate UPC 41 minted tokenIds (1 items)
        sortedMintedIds.upc41[0] = 41_000_000_001; // Token ID: 41 * 1000000000 + 1
        // Populate UPC 43 minted tokenIds (3 items)
        sortedMintedIds.upc43[0] = 43_000_000_004; // Token ID: 43 * 1000000000 + 1
        sortedMintedIds.upc43[1] = 43_000_000_005; // Token ID: 43 * 1000000000 + 2
        sortedMintedIds.upc43[2] = 43_000_000_006; // Token ID: 43 * 1000000000 + 3
        // Populate UPC 44 minted tokenIds (1 items)
        sortedMintedIds.upc44[0] = 44_000_000_003; // Token ID: 44 * 1000000000 + 1
        // Populate UPC 48 minted tokenIds (1 items)
        sortedMintedIds.upc48[0] = 48_000_000_001; // Token ID: 48 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 4000000073 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10_000_000_005; // V4: 10000000007 -> V5: 10000000005
            outfitIds[1] = 19_000_000_006; // V4: 19000000006 -> V5: 19000000006
            outfitIds[2] = 25_000_000_007; // V4: 25000000006 -> V5: 25000000007
            outfitIds[3] = 43_000_000_004; // V4: 43000000005 -> V5: 43000000004

            resolver.decorateBannyWith(address(hook), 4_000_000_073, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_073
            );
        }

        // Dress Banny 4000000079 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 27_000_000_001; // V4: 27000000001 -> V5: 27000000001
            outfitIds[1] = 38_000_000_002; // V4: 38000000002 -> V5: 38000000002
            outfitIds[2] = 48_000_000_001; // V4: 48000000001 -> V5: 48000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_079, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_079
            );
        }

        // Dress Banny 4000000080 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 13_000_000_001; // V4: 13000000001 -> V5: 13000000001
            outfitIds[1] = 20_000_000_001; // V4: 20000000001 -> V5: 20000000001
            outfitIds[2] = 44_000_000_003; // V4: 44000000004 -> V5: 44000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_080, 5_000_000_002, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_080
            );
        }

        // Dress Banny 4000000081 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 19_000_000_007; // V4: 19000000008 -> V5: 19000000007
            outfitIds[1] = 25_000_000_008; // V4: 25000000007 -> V5: 25000000008
            outfitIds[2] = 35_000_000_001; // V4: 35000000002 -> V5: 35000000001
            outfitIds[3] = 43_000_000_005; // V4: 43000000006 -> V5: 43000000005

            resolver.decorateBannyWith(address(hook), 4_000_000_081, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_081
            );
        }

        // Dress Banny 4000000082 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 43_000_000_006; // V4: 43000000007 -> V5: 43000000006

            resolver.decorateBannyWith(address(hook), 4_000_000_082, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_082
            );
        }

        // Dress Banny 4000000084 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 39_000_000_001; // V4: 39000000001 -> V5: 39000000001
            outfitIds[1] = 41_000_000_001; // V4: 41000000001 -> V5: 41000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_084, 5_000_000_003, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_084
            );
        }

        // Dress Banny 4000000085 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 28_000_000_006; // V4: 28000000008 -> V5: 28000000006

            resolver.decorateBannyWith(address(hook), 4_000_000_085, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_085
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_069; // Token ID (V4: 4000000069)
        generatedTokenIds[1] = 4_000_000_070; // Token ID (V4: 4000000070)
        generatedTokenIds[2] = 4_000_000_071; // Token ID (V4: 4000000071)
        generatedTokenIds[3] = 4_000_000_072; // Token ID (V4: 4000000072)
        generatedTokenIds[4] = 4_000_000_073; // Token ID (V4: 4000000073)
        generatedTokenIds[5] = 4_000_000_074; // Token ID (V4: 4000000074)
        generatedTokenIds[6] = 4_000_000_075; // Token ID (V4: 4000000075)
        generatedTokenIds[7] = 4_000_000_076; // Token ID (V4: 4000000076)
        generatedTokenIds[8] = 4_000_000_077; // Token ID (V4: 4000000077)
        generatedTokenIds[9] = 4_000_000_078; // Token ID (V4: 4000000078)
        generatedTokenIds[10] = 4_000_000_079; // Token ID (V4: 4000000079)
        generatedTokenIds[11] = 4_000_000_080; // Token ID (V4: 4000000080)
        generatedTokenIds[12] = 4_000_000_081; // Token ID (V4: 4000000081)
        generatedTokenIds[13] = 4_000_000_082; // Token ID (V4: 4000000082)
        generatedTokenIds[14] = 4_000_000_083; // Token ID (V4: 4000000083)
        generatedTokenIds[15] = 4_000_000_084; // Token ID (V4: 4000000084)
        generatedTokenIds[16] = 4_000_000_085; // Token ID (V4: 4000000085)
        generatedTokenIds[17] = 4_000_000_086; // Token ID (V4: 4000000086)
        generatedTokenIds[18] = 4_000_000_087; // Token ID (V4: 4000000087)
        generatedTokenIds[19] = 4_000_000_088; // Token ID (V4: 4000000088)
        generatedTokenIds[20] = 4_000_000_089; // Token ID (V4: 4000000089)
        generatedTokenIds[21] = 4_000_000_090; // Token ID (V4: 4000000090)
        generatedTokenIds[22] = 4_000_000_091; // Token ID (V4: 4000000091)
        generatedTokenIds[23] = 4_000_000_092; // Token ID (V4: 4000000092)
        generatedTokenIds[24] = 4_000_000_093; // Token ID (V4: 4000000093)
        generatedTokenIds[25] = 4_000_000_094; // Token ID (V4: 4000000094)

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
        // address[] memory uniqueOwners = new address[](18);

        // uniqueOwners[0] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        // uniqueOwners[1] = 0x46f3cC6a1c00A5cD8864d2B92f128196CAE07D15;
        // uniqueOwners[2] = 0x8e2B25dF2484000B9127b2D2F8E92079dcEE3E48;
        // uniqueOwners[3] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        // uniqueOwners[4] = 0x224aBa5D489675a7bD3CE07786FAda466b46FA0F;
        // uniqueOwners[5] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        // uniqueOwners[6] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        // uniqueOwners[7] = 0x3c2736f995535b5a755F3CE2BEb754362820671e;
        // uniqueOwners[8] = 0x6877be9E00d0bc5886c28419901E8cC98C1c2739;
        // uniqueOwners[9] = 0x8DFBdEEC8c5d4970BB5F481C6ec7f73fa1C65be5;
        // uniqueOwners[10] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        // uniqueOwners[11] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        // uniqueOwners[12] = 0x39a7B6fa1597BB6657Fe84e64E3B836c37d6F75d;
        // uniqueOwners[13] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        // uniqueOwners[14] = 0xDdB4938755C243a4f60a2f2f8f95dF4F894c58Cc;
        // uniqueOwners[15] = 0x34aA3F359A9D614239015126635CE7732c18fDF3;
        // uniqueOwners[16] = 0xF6cC71878e23c05406B35946CD9d378E0f2f4f2F;
        // uniqueOwners[17] = 0xd2e44E40B5FB960A8A74dD7B9D6b7f14B805b50d;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](16);

        // uniqueTierIds[0] = 4;
        // uniqueTierIds[1] = 5;
        // uniqueTierIds[2] = 10;
        // uniqueTierIds[3] = 13;
        // uniqueTierIds[4] = 19;
        // uniqueTierIds[5] = 20;
        // uniqueTierIds[6] = 25;
        // uniqueTierIds[7] = 27;
        // uniqueTierIds[8] = 28;
        // uniqueTierIds[9] = 35;
        // uniqueTierIds[10] = 38;
        // uniqueTierIds[11] = 39;
        // uniqueTierIds[12] = 41;
        // uniqueTierIds[13] = 43;
        // uniqueTierIds[14] = 44;
        // uniqueTierIds[15] = 48;

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
