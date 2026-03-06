// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractEthereum5 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[20] upc4;
        uint256[1] upc5;
        uint256[1] upc6;
        uint256[1] upc10;
        uint256[1] upc13;
        uint256[2] upc15;
        uint256[1] upc18;
        uint256[3] upc19;
        uint256[1] upc20;
        uint256[1] upc23;
        uint256[1] upc26;
        uint256[1] upc28;
        uint256[1] upc31;
        uint256[1] upc35;
        uint256[1] upc38;
        uint256[1] upc39;
        uint256[1] upc40;
        uint256[2] upc44;
        uint256[1] upc47;
        uint256[1] upc48;
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

        // Ethereum migration chunk 5/6 - 44 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (20 items)
        sortedMintedIds.upc4[0] = 4_000_000_048; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_049; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_050; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_051; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_052; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_053; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_054; // Token ID: 4 * 1000000000 + 7
        sortedMintedIds.upc4[7] = 4_000_000_055; // Token ID: 4 * 1000000000 + 8
        sortedMintedIds.upc4[8] = 4_000_000_056; // Token ID: 4 * 1000000000 + 9
        sortedMintedIds.upc4[9] = 4_000_000_057; // Token ID: 4 * 1000000000 + 10
        sortedMintedIds.upc4[10] = 4_000_000_058; // Token ID: 4 * 1000000000 + 11
        sortedMintedIds.upc4[11] = 4_000_000_059; // Token ID: 4 * 1000000000 + 12
        sortedMintedIds.upc4[12] = 4_000_000_060; // Token ID: 4 * 1000000000 + 13
        sortedMintedIds.upc4[13] = 4_000_000_061; // Token ID: 4 * 1000000000 + 14
        sortedMintedIds.upc4[14] = 4_000_000_062; // Token ID: 4 * 1000000000 + 15
        sortedMintedIds.upc4[15] = 4_000_000_063; // Token ID: 4 * 1000000000 + 16
        sortedMintedIds.upc4[16] = 4_000_000_064; // Token ID: 4 * 1000000000 + 17
        sortedMintedIds.upc4[17] = 4_000_000_065; // Token ID: 4 * 1000000000 + 18
        sortedMintedIds.upc4[18] = 4_000_000_066; // Token ID: 4 * 1000000000 + 19
        sortedMintedIds.upc4[19] = 4_000_000_067; // Token ID: 4 * 1000000000 + 20
        // Populate UPC 5 minted tokenIds (1 items)
        sortedMintedIds.upc5[0] = 5_000_000_006; // Token ID: 5 * 1000000000 + 1
        // Populate UPC 6 minted tokenIds (1 items)
        sortedMintedIds.upc6[0] = 6_000_000_007; // Token ID: 6 * 1000000000 + 1
        // Populate UPC 10 minted tokenIds (1 items)
        sortedMintedIds.upc10[0] = 10_000_000_006; // Token ID: 10 * 1000000000 + 1
        // Populate UPC 13 minted tokenIds (1 items)
        sortedMintedIds.upc13[0] = 13_000_000_002; // Token ID: 13 * 1000000000 + 1
        // Populate UPC 15 minted tokenIds (2 items)
        sortedMintedIds.upc15[0] = 15_000_000_003; // Token ID: 15 * 1000000000 + 1
        sortedMintedIds.upc15[1] = 15_000_000_004; // Token ID: 15 * 1000000000 + 2
        // Populate UPC 18 minted tokenIds (1 items)
        sortedMintedIds.upc18[0] = 18_000_000_003; // Token ID: 18 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (3 items)
        sortedMintedIds.upc19[0] = 19_000_000_010; // Token ID: 19 * 1000000000 + 1
        sortedMintedIds.upc19[1] = 19_000_000_011; // Token ID: 19 * 1000000000 + 2
        sortedMintedIds.upc19[2] = 19_000_000_012; // Token ID: 19 * 1000000000 + 3
        // Populate UPC 20 minted tokenIds (1 items)
        sortedMintedIds.upc20[0] = 20_000_000_002; // Token ID: 20 * 1000000000 + 1
        // Populate UPC 23 minted tokenIds (1 items)
        sortedMintedIds.upc23[0] = 23_000_000_006; // Token ID: 23 * 1000000000 + 1
        // Populate UPC 26 minted tokenIds (1 items)
        sortedMintedIds.upc26[0] = 26_000_000_005; // Token ID: 26 * 1000000000 + 1
        // Populate UPC 28 minted tokenIds (1 items)
        sortedMintedIds.upc28[0] = 28_000_000_002; // Token ID: 28 * 1000000000 + 1
        // Populate UPC 31 minted tokenIds (1 items)
        sortedMintedIds.upc31[0] = 31_000_000_006; // Token ID: 31 * 1000000000 + 1
        // Populate UPC 35 minted tokenIds (1 items)
        sortedMintedIds.upc35[0] = 35_000_000_006; // Token ID: 35 * 1000000000 + 1
        // Populate UPC 38 minted tokenIds (1 items)
        sortedMintedIds.upc38[0] = 38_000_000_002; // Token ID: 38 * 1000000000 + 1
        // Populate UPC 39 minted tokenIds (1 items)
        sortedMintedIds.upc39[0] = 39_000_000_003; // Token ID: 39 * 1000000000 + 1
        // Populate UPC 40 minted tokenIds (1 items)
        sortedMintedIds.upc40[0] = 40_000_000_001; // Token ID: 40 * 1000000000 + 1
        // Populate UPC 44 minted tokenIds (2 items)
        sortedMintedIds.upc44[0] = 44_000_000_004; // Token ID: 44 * 1000000000 + 1
        sortedMintedIds.upc44[1] = 44_000_000_005; // Token ID: 44 * 1000000000 + 2
        // Populate UPC 47 minted tokenIds (1 items)
        sortedMintedIds.upc47[0] = 47_000_000_002; // Token ID: 47 * 1000000000 + 1
        // Populate UPC 48 minted tokenIds (1 items)
        sortedMintedIds.upc48[0] = 48_000_000_005; // Token ID: 48 * 1000000000 + 1
        // Populate UPC 49 minted tokenIds (1 items)
        sortedMintedIds.upc49[0] = 49_000_000_003; // Token ID: 49 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 4000000048 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 19_000_000_010; // V4: 19000000013 -> V5: 19000000010
            outfitIds[1] = 31_000_000_006; // V4: 31000000010 -> V5: 31000000006
            outfitIds[2] = 35_000_000_006; // V4: 35000000007 -> V5: 35000000006
            outfitIds[3] = 47_000_000_002; // V4: 47000000005 -> V5: 47000000002

            resolver.decorateBannyWith(address(hook), 4_000_000_048, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_048
            );
        }

        // Dress Banny 4000000052 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 10_000_000_006; // V4: 10000000012 -> V5: 10000000006
            outfitIds[1] = 18_000_000_003; // V4: 18000000003 -> V5: 18000000003
            outfitIds[2] = 20_000_000_002; // V4: 20000000008 -> V5: 20000000002

            resolver.decorateBannyWith(address(hook), 4_000_000_052, 5_000_000_006, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_052
            );
        }

        // Dress Banny 4000000054 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 15_000_000_003; // V4: 15000000002 -> V5: 15000000003
            outfitIds[1] = 26_000_000_005; // V4: 26000000005 -> V5: 26000000005
            outfitIds[2] = 44_000_000_004; // V4: 44000000008 -> V5: 44000000004

            resolver.decorateBannyWith(address(hook), 4_000_000_054, 6_000_000_007, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_054
            );
        }

        // Dress Banny 4000000055 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19_000_000_011; // V4: 19000000016 -> V5: 19000000011
            outfitIds[1] = 39_000_000_003; // V4: 39000000002 -> V5: 39000000003
            outfitIds[2] = 44_000_000_005; // V4: 44000000009 -> V5: 44000000005

            resolver.decorateBannyWith(address(hook), 4_000_000_055, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_055
            );
        }

        // Dress Banny 4000000056 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 15_000_000_004; // V4: 15000000003 -> V5: 15000000004
            outfitIds[1] = 23_000_000_006; // V4: 23000000007 -> V5: 23000000006
            outfitIds[2] = 40_000_000_001; // V4: 40000000001 -> V5: 40000000001
            outfitIds[3] = 49_000_000_003; // V4: 49000000004 -> V5: 49000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_056, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_056
            );
        }

        // Dress Banny 4000000057 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19_000_000_012; // V4: 19000000017 -> V5: 19000000012
            outfitIds[1] = 28_000_000_002; // V4: 28000000008 -> V5: 28000000002
            outfitIds[2] = 38_000_000_002; // V4: 38000000003 -> V5: 38000000002

            resolver.decorateBannyWith(address(hook), 4_000_000_057, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_057
            );
        }

        // Dress Banny 4000000060 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 13_000_000_002; // V4: 13000000003 -> V5: 13000000002
            outfitIds[1] = 48_000_000_005; // V4: 48000000006 -> V5: 48000000005

            resolver.decorateBannyWith(address(hook), 4_000_000_060, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_060
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_048; // Token ID (V4: 4000000048)
        generatedTokenIds[1] = 4_000_000_049; // Token ID (V4: 4000000049)
        generatedTokenIds[2] = 4_000_000_050; // Token ID (V4: 4000000050)
        generatedTokenIds[3] = 4_000_000_051; // Token ID (V4: 4000000051)
        generatedTokenIds[4] = 4_000_000_052; // Token ID (V4: 4000000052)
        generatedTokenIds[5] = 4_000_000_053; // Token ID (V4: 4000000053)
        generatedTokenIds[6] = 4_000_000_054; // Token ID (V4: 4000000054)
        generatedTokenIds[7] = 4_000_000_055; // Token ID (V4: 4000000055)
        generatedTokenIds[8] = 4_000_000_056; // Token ID (V4: 4000000056)
        generatedTokenIds[9] = 4_000_000_057; // Token ID (V4: 4000000057)
        generatedTokenIds[10] = 4_000_000_058; // Token ID (V4: 4000000058)
        generatedTokenIds[11] = 4_000_000_059; // Token ID (V4: 4000000059)
        generatedTokenIds[12] = 4_000_000_060; // Token ID (V4: 4000000060)
        generatedTokenIds[13] = 4_000_000_061; // Token ID (V4: 4000000061)
        generatedTokenIds[14] = 4_000_000_062; // Token ID (V4: 4000000062)
        generatedTokenIds[15] = 4_000_000_063; // Token ID (V4: 4000000063)
        generatedTokenIds[16] = 4_000_000_064; // Token ID (V4: 4000000064)
        generatedTokenIds[17] = 4_000_000_065; // Token ID (V4: 4000000065)
        generatedTokenIds[18] = 4_000_000_066; // Token ID (V4: 4000000066)
        generatedTokenIds[19] = 4_000_000_067; // Token ID (V4: 4000000067)

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
        // address[] memory uniqueOwners = new address[](11);

        // uniqueOwners[0] = 0xf32dd1Bd55bD14d929218499a2E7D106F72f79c7;
        // uniqueOwners[1] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        // uniqueOwners[2] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        // uniqueOwners[3] = 0x80581C6e88Ce00095F85cdf24bB760f16d6eC0D6;
        // uniqueOwners[4] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        // uniqueOwners[5] = 0x30670D81E487c80b9EDc54370e6EaF943B6EAB39;
        // uniqueOwners[6] = 0x60535A6605958fFf6cEC5B1e92892601EFb3473b;
        // uniqueOwners[7] = 0x34724D71cE674FcD4d06e60Dd1BaA88c14D36b75;
        // uniqueOwners[8] = 0xA99c384f43e72B65BB51fE33b85CE12A32C09526;
        // uniqueOwners[9] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        // uniqueOwners[10] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](21);

        // uniqueTierIds[0] = 4;
        // uniqueTierIds[1] = 5;
        // uniqueTierIds[2] = 6;
        // uniqueTierIds[3] = 10;
        // uniqueTierIds[4] = 13;
        // uniqueTierIds[5] = 15;
        // uniqueTierIds[6] = 18;
        // uniqueTierIds[7] = 19;
        // uniqueTierIds[8] = 20;
        // uniqueTierIds[9] = 23;
        // uniqueTierIds[10] = 26;
        // uniqueTierIds[11] = 28;
        // uniqueTierIds[12] = 31;
        // uniqueTierIds[13] = 35;
        // uniqueTierIds[14] = 38;
        // uniqueTierIds[15] = 39;
        // uniqueTierIds[16] = 40;
        // uniqueTierIds[17] = 44;
        // uniqueTierIds[18] = 47;
        // uniqueTierIds[19] = 48;
        // uniqueTierIds[20] = 49;

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
