// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractEthereum4 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[20] upc4;
        uint256[1] upc13;
        uint256[1] upc16;
        uint256[1] upc17;
        uint256[2] upc19;
        uint256[4] upc23;
        uint256[2] upc25;
        uint256[1] upc31;
        uint256[1] upc32;
        uint256[1] upc33;
        uint256[4] upc41;
        uint256[1] upc42;
        uint256[1] upc43;
        uint256[2] upc48;
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

        // Ethereum migration chunk 4/6 - 42 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (20 items)
        sortedMintedIds.upc4[0] = 4_000_000_028; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_029; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_030; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_031; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_032; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_033; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_034; // Token ID: 4 * 1000000000 + 7
        sortedMintedIds.upc4[7] = 4_000_000_035; // Token ID: 4 * 1000000000 + 8
        sortedMintedIds.upc4[8] = 4_000_000_036; // Token ID: 4 * 1000000000 + 9
        sortedMintedIds.upc4[9] = 4_000_000_037; // Token ID: 4 * 1000000000 + 10
        sortedMintedIds.upc4[10] = 4_000_000_038; // Token ID: 4 * 1000000000 + 11
        sortedMintedIds.upc4[11] = 4_000_000_039; // Token ID: 4 * 1000000000 + 12
        sortedMintedIds.upc4[12] = 4_000_000_040; // Token ID: 4 * 1000000000 + 13
        sortedMintedIds.upc4[13] = 4_000_000_041; // Token ID: 4 * 1000000000 + 14
        sortedMintedIds.upc4[14] = 4_000_000_042; // Token ID: 4 * 1000000000 + 15
        sortedMintedIds.upc4[15] = 4_000_000_043; // Token ID: 4 * 1000000000 + 16
        sortedMintedIds.upc4[16] = 4_000_000_044; // Token ID: 4 * 1000000000 + 17
        sortedMintedIds.upc4[17] = 4_000_000_045; // Token ID: 4 * 1000000000 + 18
        sortedMintedIds.upc4[18] = 4_000_000_046; // Token ID: 4 * 1000000000 + 19
        sortedMintedIds.upc4[19] = 4_000_000_047; // Token ID: 4 * 1000000000 + 20
        // Populate UPC 13 minted tokenIds (1 items)
        sortedMintedIds.upc13[0] = 13_000_000_001; // Token ID: 13 * 1000000000 + 1
        // Populate UPC 16 minted tokenIds (1 items)
        sortedMintedIds.upc16[0] = 16_000_000_001; // Token ID: 16 * 1000000000 + 1
        // Populate UPC 17 minted tokenIds (1 items)
        sortedMintedIds.upc17[0] = 17_000_000_002; // Token ID: 17 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (2 items)
        sortedMintedIds.upc19[0] = 19_000_000_008; // Token ID: 19 * 1000000000 + 1
        sortedMintedIds.upc19[1] = 19_000_000_009; // Token ID: 19 * 1000000000 + 2
        // Populate UPC 23 minted tokenIds (4 items)
        sortedMintedIds.upc23[0] = 23_000_000_002; // Token ID: 23 * 1000000000 + 1
        sortedMintedIds.upc23[1] = 23_000_000_003; // Token ID: 23 * 1000000000 + 2
        sortedMintedIds.upc23[2] = 23_000_000_004; // Token ID: 23 * 1000000000 + 3
        sortedMintedIds.upc23[3] = 23_000_000_005; // Token ID: 23 * 1000000000 + 4
        // Populate UPC 25 minted tokenIds (2 items)
        sortedMintedIds.upc25[0] = 25_000_000_006; // Token ID: 25 * 1000000000 + 1
        sortedMintedIds.upc25[1] = 25_000_000_007; // Token ID: 25 * 1000000000 + 2
        // Populate UPC 31 minted tokenIds (1 items)
        sortedMintedIds.upc31[0] = 31_000_000_005; // Token ID: 31 * 1000000000 + 1
        // Populate UPC 32 minted tokenIds (1 items)
        sortedMintedIds.upc32[0] = 32_000_000_003; // Token ID: 32 * 1000000000 + 1
        // Populate UPC 33 minted tokenIds (1 items)
        sortedMintedIds.upc33[0] = 33_000_000_001; // Token ID: 33 * 1000000000 + 1
        // Populate UPC 41 minted tokenIds (4 items)
        sortedMintedIds.upc41[0] = 41_000_000_001; // Token ID: 41 * 1000000000 + 1
        sortedMintedIds.upc41[1] = 41_000_000_002; // Token ID: 41 * 1000000000 + 2
        sortedMintedIds.upc41[2] = 41_000_000_003; // Token ID: 41 * 1000000000 + 3
        sortedMintedIds.upc41[3] = 41_000_000_004; // Token ID: 41 * 1000000000 + 4
        // Populate UPC 42 minted tokenIds (1 items)
        sortedMintedIds.upc42[0] = 42_000_000_003; // Token ID: 42 * 1000000000 + 1
        // Populate UPC 43 minted tokenIds (1 items)
        sortedMintedIds.upc43[0] = 43_000_000_005; // Token ID: 43 * 1000000000 + 1
        // Populate UPC 48 minted tokenIds (2 items)
        sortedMintedIds.upc48[0] = 48_000_000_003; // Token ID: 48 * 1000000000 + 1
        sortedMintedIds.upc48[1] = 48_000_000_004; // Token ID: 48 * 1000000000 + 2
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 4000000033 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 19_000_000_008; // V4: 19000000009 -> V5: 19000000008
            outfitIds[1] = 43_000_000_005; // V4: 43000000008 -> V5: 43000000005

            resolver.decorateBannyWith(address(hook), 4_000_000_033, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_033
            );
        }

        // Dress Banny 4000000039 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 13_000_000_001; // V4: 13000000001 -> V5: 13000000001
            outfitIds[1] = 19_000_000_009; // V4: 19000000011 -> V5: 19000000009
            outfitIds[2] = 25_000_000_006; // V4: 25000000006 -> V5: 25000000006
            outfitIds[3] = 42_000_000_003; // V4: 42000000004 -> V5: 42000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_039, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_039
            );
        }

        // Dress Banny 4000000040 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 25_000_000_007; // V4: 25000000007 -> V5: 25000000007

            resolver.decorateBannyWith(address(hook), 4_000_000_040, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_040
            );
        }

        // Dress Banny 4000000041 (Original)
        {
            uint256[] memory outfitIds = new uint256[](5);
            outfitIds[0] = 16_000_000_001; // V4: 16000000001 -> V5: 16000000001
            outfitIds[1] = 17_000_000_002; // V4: 17000000002 -> V5: 17000000002
            outfitIds[2] = 31_000_000_005; // V4: 31000000009 -> V5: 31000000005
            outfitIds[3] = 33_000_000_001; // V4: 33000000001 -> V5: 33000000001
            outfitIds[4] = 48_000_000_003; // V4: 48000000002 -> V5: 48000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_041, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_041
            );
        }

        // Dress Banny 4000000043 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 32_000_000_003; // V4: 32000000003 -> V5: 32000000003
            outfitIds[1] = 48_000_000_004; // V4: 48000000003 -> V5: 48000000004

            resolver.decorateBannyWith(address(hook), 4_000_000_043, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_043
            );
        }

        // Dress Banny 4000000044 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 23_000_000_002; // V4: 23000000002 -> V5: 23000000002
            outfitIds[1] = 41_000_000_001; // V4: 41000000001 -> V5: 41000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_044, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_044
            );
        }

        // Dress Banny 4000000045 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 23_000_000_004; // V4: 23000000004 -> V5: 23000000004
            outfitIds[1] = 41_000_000_003; // V4: 41000000003 -> V5: 41000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_045, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_045
            );
        }

        // Dress Banny 4000000046 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 23_000_000_005; // V4: 23000000005 -> V5: 23000000005
            outfitIds[1] = 41_000_000_004; // V4: 41000000004 -> V5: 41000000004

            resolver.decorateBannyWith(address(hook), 4_000_000_046, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_046
            );
        }

        // Dress Banny 4000000047 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 23_000_000_003; // V4: 23000000003 -> V5: 23000000003
            outfitIds[1] = 41_000_000_002; // V4: 41000000002 -> V5: 41000000002

            resolver.decorateBannyWith(address(hook), 4_000_000_047, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_047
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_028; // Token ID (V4: 4000000028)
        generatedTokenIds[1] = 4_000_000_029; // Token ID (V4: 4000000029)
        generatedTokenIds[2] = 4_000_000_030; // Token ID (V4: 4000000030)
        generatedTokenIds[3] = 4_000_000_031; // Token ID (V4: 4000000031)
        generatedTokenIds[4] = 4_000_000_032; // Token ID (V4: 4000000032)
        generatedTokenIds[5] = 4_000_000_033; // Token ID (V4: 4000000033)
        generatedTokenIds[6] = 4_000_000_034; // Token ID (V4: 4000000034)
        generatedTokenIds[7] = 4_000_000_035; // Token ID (V4: 4000000035)
        generatedTokenIds[8] = 4_000_000_036; // Token ID (V4: 4000000036)
        generatedTokenIds[9] = 4_000_000_037; // Token ID (V4: 4000000037)
        generatedTokenIds[10] = 4_000_000_038; // Token ID (V4: 4000000038)
        generatedTokenIds[11] = 4_000_000_039; // Token ID (V4: 4000000039)
        generatedTokenIds[12] = 4_000_000_040; // Token ID (V4: 4000000040)
        generatedTokenIds[13] = 4_000_000_041; // Token ID (V4: 4000000041)
        generatedTokenIds[14] = 4_000_000_042; // Token ID (V4: 4000000042)
        generatedTokenIds[15] = 4_000_000_043; // Token ID (V4: 4000000043)
        generatedTokenIds[16] = 4_000_000_044; // Token ID (V4: 4000000044)
        generatedTokenIds[17] = 4_000_000_045; // Token ID (V4: 4000000045)
        generatedTokenIds[18] = 4_000_000_046; // Token ID (V4: 4000000046)
        generatedTokenIds[19] = 4_000_000_047; // Token ID (V4: 4000000047)

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
        // address[] memory uniqueOwners = new address[](10);

        // uniqueOwners[0] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        // uniqueOwners[1] = 0x5A00e8683f37e8B08C744054a0EF606a18b1aEF7;
        // uniqueOwners[2] = 0x59E98040E53d7dC1900B4daf36D9Fbbd4a8f1dA2;
        // uniqueOwners[3] = 0x46f3cC6a1c00A5cD8864d2B92f128196CAE07D15;
        // uniqueOwners[4] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        // uniqueOwners[5] = 0x381CC779761212344f8400373a994d29E17522c6;
        // uniqueOwners[6] = 0x849151d7D0bF1F34b70d5caD5149D28CC2308bf1;
        // uniqueOwners[7] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        // uniqueOwners[8] = 0x63A2368F4B509438ca90186cb1C15156713D5834;
        // uniqueOwners[9] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](14);

        // uniqueTierIds[0] = 4;
        // uniqueTierIds[1] = 13;
        // uniqueTierIds[2] = 16;
        // uniqueTierIds[3] = 17;
        // uniqueTierIds[4] = 19;
        // uniqueTierIds[5] = 23;
        // uniqueTierIds[6] = 25;
        // uniqueTierIds[7] = 31;
        // uniqueTierIds[8] = 32;
        // uniqueTierIds[9] = 33;
        // uniqueTierIds[10] = 41;
        // uniqueTierIds[11] = 42;
        // uniqueTierIds[12] = 43;
        // uniqueTierIds[13] = 48;

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
