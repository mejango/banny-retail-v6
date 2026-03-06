// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractEthereum2 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[13] upc3;
        uint256[7] upc4;
        uint256[1] upc5;
        uint256[2] upc6;
        uint256[1] upc14;
        uint256[1] upc15;
        uint256[1] upc19;
        uint256[2] upc25;
        uint256[1] upc28;
        uint256[1] upc29;
        uint256[1] upc37;
        uint256[1] upc38;
        uint256[1] upc39;
        uint256[1] upc42;
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

        // Ethereum migration chunk 2/6 - 36 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 3 minted tokenIds (13 items)
        sortedMintedIds.upc3[0] = 3_000_000_014; // Token ID: 3 * 1000000000 + 1
        sortedMintedIds.upc3[1] = 3_000_000_015; // Token ID: 3 * 1000000000 + 2
        sortedMintedIds.upc3[2] = 3_000_000_016; // Token ID: 3 * 1000000000 + 3
        sortedMintedIds.upc3[3] = 3_000_000_017; // Token ID: 3 * 1000000000 + 4
        sortedMintedIds.upc3[4] = 3_000_000_018; // Token ID: 3 * 1000000000 + 5
        sortedMintedIds.upc3[5] = 3_000_000_019; // Token ID: 3 * 1000000000 + 6
        sortedMintedIds.upc3[6] = 3_000_000_020; // Token ID: 3 * 1000000000 + 7
        sortedMintedIds.upc3[7] = 3_000_000_021; // Token ID: 3 * 1000000000 + 8
        sortedMintedIds.upc3[8] = 3_000_000_022; // Token ID: 3 * 1000000000 + 9
        sortedMintedIds.upc3[9] = 3_000_000_023; // Token ID: 3 * 1000000000 + 10
        sortedMintedIds.upc3[10] = 3_000_000_024; // Token ID: 3 * 1000000000 + 11
        sortedMintedIds.upc3[11] = 3_000_000_025; // Token ID: 3 * 1000000000 + 12
        sortedMintedIds.upc3[12] = 3_000_000_026; // Token ID: 3 * 1000000000 + 13
        // Populate UPC 4 minted tokenIds (7 items)
        sortedMintedIds.upc4[0] = 4_000_000_001; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_002; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_003; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_004; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_005; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_006; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_007; // Token ID: 4 * 1000000000 + 7
        // Populate UPC 5 minted tokenIds (1 items)
        sortedMintedIds.upc5[0] = 5_000_000_004; // Token ID: 5 * 1000000000 + 1
        // Populate UPC 6 minted tokenIds (2 items)
        sortedMintedIds.upc6[0] = 6_000_000_004; // Token ID: 6 * 1000000000 + 1
        sortedMintedIds.upc6[1] = 6_000_000_005; // Token ID: 6 * 1000000000 + 2
        // Populate UPC 14 minted tokenIds (1 items)
        sortedMintedIds.upc14[0] = 14_000_000_003; // Token ID: 14 * 1000000000 + 1
        // Populate UPC 15 minted tokenIds (1 items)
        sortedMintedIds.upc15[0] = 15_000_000_001; // Token ID: 15 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (1 items)
        sortedMintedIds.upc19[0] = 19_000_000_004; // Token ID: 19 * 1000000000 + 1
        // Populate UPC 25 minted tokenIds (2 items)
        sortedMintedIds.upc25[0] = 25_000_000_002; // Token ID: 25 * 1000000000 + 1
        sortedMintedIds.upc25[1] = 25_000_000_003; // Token ID: 25 * 1000000000 + 2
        // Populate UPC 28 minted tokenIds (1 items)
        sortedMintedIds.upc28[0] = 28_000_000_001; // Token ID: 28 * 1000000000 + 1
        // Populate UPC 29 minted tokenIds (1 items)
        sortedMintedIds.upc29[0] = 29_000_000_001; // Token ID: 29 * 1000000000 + 1
        // Populate UPC 37 minted tokenIds (1 items)
        sortedMintedIds.upc37[0] = 37_000_000_002; // Token ID: 37 * 1000000000 + 1
        // Populate UPC 38 minted tokenIds (1 items)
        sortedMintedIds.upc38[0] = 38_000_000_001; // Token ID: 38 * 1000000000 + 1
        // Populate UPC 39 minted tokenIds (1 items)
        sortedMintedIds.upc39[0] = 39_000_000_002; // Token ID: 39 * 1000000000 + 1
        // Populate UPC 42 minted tokenIds (1 items)
        sortedMintedIds.upc42[0] = 42_000_000_001; // Token ID: 42 * 1000000000 + 1
        // Populate UPC 48 minted tokenIds (1 items)
        sortedMintedIds.upc48[0] = 48_000_000_002; // Token ID: 48 * 1000000000 + 1
        // Populate UPC 49 minted tokenIds (1 items)
        sortedMintedIds.upc49[0] = 49_000_000_001; // Token ID: 49 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 3000000017 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 25_000_000_002; // V4: 25000000005 -> V5: 25000000002
            outfitIds[1] = 49_000_000_001; // V4: 49000000002 -> V5: 49000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_017, 5_000_000_004, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_017
            );
        }

        // Dress Banny 3000000022 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19_000_000_004; // V4: 19000000015 -> V5: 19000000004
            outfitIds[1] = 38_000_000_001; // V4: 38000000002 -> V5: 38000000001
            outfitIds[2] = 48_000_000_002; // V4: 48000000005 -> V5: 48000000002

            resolver.decorateBannyWith(address(hook), 3_000_000_022, 6_000_000_004, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_022
            );
        }

        // Dress Banny 3000000023 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 14_000_000_003; // V4: 14000000005 -> V5: 14000000003
            outfitIds[1] = 25_000_000_003; // V4: 25000000008 -> V5: 25000000003
            outfitIds[2] = 37_000_000_002; // V4: 37000000003 -> V5: 37000000002
            outfitIds[3] = 42_000_000_001; // V4: 42000000007 -> V5: 42000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_023, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_023
            );
        }

        // Dress Banny 3000000026 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 15_000_000_001; // V4: 15000000004 -> V5: 15000000001
            outfitIds[1] = 29_000_000_001; // V4: 29000000003 -> V5: 29000000001
            outfitIds[2] = 39_000_000_002; // V4: 39000000003 -> V5: 39000000002

            resolver.decorateBannyWith(address(hook), 3_000_000_026, 6_000_000_005, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_026
            );
        }

        // Dress Banny 4000000004 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 28_000_000_001; // V4: 28000000002 -> V5: 28000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_004, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_004
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 3_000_000_014; // Token ID (V4: 3000000014)
        generatedTokenIds[1] = 3_000_000_015; // Token ID (V4: 3000000015)
        generatedTokenIds[2] = 3_000_000_016; // Token ID (V4: 3000000016)
        generatedTokenIds[3] = 3_000_000_017; // Token ID (V4: 3000000017)
        generatedTokenIds[4] = 3_000_000_018; // Token ID (V4: 3000000018)
        generatedTokenIds[5] = 3_000_000_019; // Token ID (V4: 3000000019)
        generatedTokenIds[6] = 3_000_000_020; // Token ID (V4: 3000000020)
        generatedTokenIds[7] = 3_000_000_021; // Token ID (V4: 3000000021)
        generatedTokenIds[8] = 3_000_000_022; // Token ID (V4: 3000000022)
        generatedTokenIds[9] = 3_000_000_023; // Token ID (V4: 3000000023)
        generatedTokenIds[10] = 3_000_000_024; // Token ID (V4: 3000000024)
        generatedTokenIds[11] = 3_000_000_025; // Token ID (V4: 3000000025)
        generatedTokenIds[12] = 3_000_000_026; // Token ID (V4: 3000000026)
        generatedTokenIds[13] = 4_000_000_001; // Token ID (V4: 4000000001)
        generatedTokenIds[14] = 4_000_000_002; // Token ID (V4: 4000000002)
        generatedTokenIds[15] = 4_000_000_003; // Token ID (V4: 4000000003)
        generatedTokenIds[16] = 4_000_000_004; // Token ID (V4: 4000000004)
        generatedTokenIds[17] = 4_000_000_005; // Token ID (V4: 4000000005)
        generatedTokenIds[18] = 4_000_000_006; // Token ID (V4: 4000000006)
        generatedTokenIds[19] = 4_000_000_007; // Token ID (V4: 4000000007)

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
        // address[] memory uniqueOwners = new address[](17);

        // uniqueOwners[0] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        // uniqueOwners[1] = 0x79d1E7F1A6E0Bbb3278a9d2B782e3A8983444cb6;
        // uniqueOwners[2] = 0x546B4A7A30b3193Badf70E1d43D8142928F3db0b;
        // uniqueOwners[3] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        // uniqueOwners[4] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        // uniqueOwners[5] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        // uniqueOwners[6] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        // uniqueOwners[7] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        // uniqueOwners[8] = 0x7D0068d0D8fC2Aa15d897448B348Fa9B30f6d4c9;
        // uniqueOwners[9] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        // uniqueOwners[10] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        // uniqueOwners[11] = 0x961d4191965C49537c88F764D88318872CE405bE;
        // uniqueOwners[12] = 0x21a8f5A6bF893D43d3964dDaf4E04766BBBE9b07;
        // uniqueOwners[13] = 0x7a16eABD1413Bfd468aE9fEBF7C26c62f1fFdc59;
        // uniqueOwners[14] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        // uniqueOwners[15] = 0xa13d49fCbf79EAF6A0a58cBDD3361422DB4eAfF1;
        // uniqueOwners[16] = 0xe7879a2D05dBA966Fcca34EE9C3F99eEe7eDEFd1;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](16);

        // uniqueTierIds[0] = 3;
        // uniqueTierIds[1] = 4;
        // uniqueTierIds[2] = 5;
        // uniqueTierIds[3] = 6;
        // uniqueTierIds[4] = 14;
        // uniqueTierIds[5] = 15;
        // uniqueTierIds[6] = 19;
        // uniqueTierIds[7] = 25;
        // uniqueTierIds[8] = 28;
        // uniqueTierIds[9] = 29;
        // uniqueTierIds[10] = 37;
        // uniqueTierIds[11] = 38;
        // uniqueTierIds[12] = 39;
        // uniqueTierIds[13] = 42;
        // uniqueTierIds[14] = 48;
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
