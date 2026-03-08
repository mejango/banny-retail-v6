// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractBase1 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[3] upc2;
        uint256[10] upc3;
        uint256[14] upc4;
        uint256[1] upc5;
        uint256[4] upc6;
        uint256[1] upc10;
        uint256[1] upc11;
        uint256[2] upc14;
        uint256[2] upc15;
        uint256[4] upc19;
        uint256[4] upc25;
        uint256[4] upc28;
        uint256[1] upc31;
        uint256[1] upc32;
        uint256[1] upc33;
        uint256[2] upc37;
        uint256[1] upc40;
        uint256[1] upc43;
        uint256[2] upc44;
        uint256[1] upc45;
        uint256[2] upc47;
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

        // Base migration chunk 1/4 - 62 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 2 minted tokenIds (3 items)
        sortedMintedIds.upc2[0] = 2_000_000_001; // Token ID: 2 * 1000000000 + 1
        sortedMintedIds.upc2[1] = 2_000_000_002; // Token ID: 2 * 1000000000 + 2
        sortedMintedIds.upc2[2] = 2_000_000_003; // Token ID: 2 * 1000000000 + 3
        // Populate UPC 3 minted tokenIds (10 items)
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
        // Populate UPC 4 minted tokenIds (14 items)
        sortedMintedIds.upc4[0] = 4_000_000_001; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_002; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_003; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_004; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_005; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_006; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_007; // Token ID: 4 * 1000000000 + 7
        sortedMintedIds.upc4[7] = 4_000_000_008; // Token ID: 4 * 1000000000 + 8
        sortedMintedIds.upc4[8] = 4_000_000_009; // Token ID: 4 * 1000000000 + 9
        sortedMintedIds.upc4[9] = 4_000_000_010; // Token ID: 4 * 1000000000 + 10
        sortedMintedIds.upc4[10] = 4_000_000_011; // Token ID: 4 * 1000000000 + 11
        sortedMintedIds.upc4[11] = 4_000_000_012; // Token ID: 4 * 1000000000 + 12
        sortedMintedIds.upc4[12] = 4_000_000_013; // Token ID: 4 * 1000000000 + 13
        sortedMintedIds.upc4[13] = 4_000_000_014; // Token ID: 4 * 1000000000 + 14
        // Populate UPC 5 minted tokenIds (1 items)
        sortedMintedIds.upc5[0] = 5_000_000_001; // Token ID: 5 * 1000000000 + 1
        // Populate UPC 6 minted tokenIds (4 items)
        sortedMintedIds.upc6[0] = 6_000_000_001; // Token ID: 6 * 1000000000 + 1
        sortedMintedIds.upc6[1] = 6_000_000_002; // Token ID: 6 * 1000000000 + 2
        sortedMintedIds.upc6[2] = 6_000_000_003; // Token ID: 6 * 1000000000 + 3
        sortedMintedIds.upc6[3] = 6_000_000_004; // Token ID: 6 * 1000000000 + 4
        // Populate UPC 10 minted tokenIds (1 items)
        sortedMintedIds.upc10[0] = 10_000_000_001; // Token ID: 10 * 1000000000 + 1
        // Populate UPC 11 minted tokenIds (1 items)
        sortedMintedIds.upc11[0] = 11_000_000_001; // Token ID: 11 * 1000000000 + 1
        // Populate UPC 14 minted tokenIds (2 items)
        sortedMintedIds.upc14[0] = 14_000_000_001; // Token ID: 14 * 1000000000 + 1
        sortedMintedIds.upc14[1] = 14_000_000_002; // Token ID: 14 * 1000000000 + 2
        // Populate UPC 15 minted tokenIds (2 items)
        sortedMintedIds.upc15[0] = 15_000_000_001; // Token ID: 15 * 1000000000 + 1
        sortedMintedIds.upc15[1] = 15_000_000_002; // Token ID: 15 * 1000000000 + 2
        // Populate UPC 19 minted tokenIds (4 items)
        sortedMintedIds.upc19[0] = 19_000_000_001; // Token ID: 19 * 1000000000 + 1
        sortedMintedIds.upc19[1] = 19_000_000_002; // Token ID: 19 * 1000000000 + 2
        sortedMintedIds.upc19[2] = 19_000_000_003; // Token ID: 19 * 1000000000 + 3
        sortedMintedIds.upc19[3] = 19_000_000_004; // Token ID: 19 * 1000000000 + 4
        // Populate UPC 25 minted tokenIds (4 items)
        sortedMintedIds.upc25[0] = 25_000_000_001; // Token ID: 25 * 1000000000 + 1
        sortedMintedIds.upc25[1] = 25_000_000_002; // Token ID: 25 * 1000000000 + 2
        sortedMintedIds.upc25[2] = 25_000_000_003; // Token ID: 25 * 1000000000 + 3
        sortedMintedIds.upc25[3] = 25_000_000_004; // Token ID: 25 * 1000000000 + 4
        // Populate UPC 28 minted tokenIds (4 items)
        sortedMintedIds.upc28[0] = 28_000_000_001; // Token ID: 28 * 1000000000 + 1
        sortedMintedIds.upc28[1] = 28_000_000_002; // Token ID: 28 * 1000000000 + 2
        sortedMintedIds.upc28[2] = 28_000_000_003; // Token ID: 28 * 1000000000 + 3
        sortedMintedIds.upc28[3] = 28_000_000_004; // Token ID: 28 * 1000000000 + 4
        // Populate UPC 31 minted tokenIds (1 items)
        sortedMintedIds.upc31[0] = 31_000_000_001; // Token ID: 31 * 1000000000 + 1
        // Populate UPC 32 minted tokenIds (1 items)
        sortedMintedIds.upc32[0] = 32_000_000_001; // Token ID: 32 * 1000000000 + 1
        // Populate UPC 33 minted tokenIds (1 items)
        sortedMintedIds.upc33[0] = 33_000_000_001; // Token ID: 33 * 1000000000 + 1
        // Populate UPC 37 minted tokenIds (2 items)
        sortedMintedIds.upc37[0] = 37_000_000_001; // Token ID: 37 * 1000000000 + 1
        sortedMintedIds.upc37[1] = 37_000_000_002; // Token ID: 37 * 1000000000 + 2
        // Populate UPC 40 minted tokenIds (1 items)
        sortedMintedIds.upc40[0] = 40_000_000_001; // Token ID: 40 * 1000000000 + 1
        // Populate UPC 43 minted tokenIds (1 items)
        sortedMintedIds.upc43[0] = 43_000_000_001; // Token ID: 43 * 1000000000 + 1
        // Populate UPC 44 minted tokenIds (2 items)
        sortedMintedIds.upc44[0] = 44_000_000_001; // Token ID: 44 * 1000000000 + 1
        sortedMintedIds.upc44[1] = 44_000_000_002; // Token ID: 44 * 1000000000 + 2
        // Populate UPC 45 minted tokenIds (1 items)
        sortedMintedIds.upc45[0] = 45_000_000_001; // Token ID: 45 * 1000000000 + 1
        // Populate UPC 47 minted tokenIds (2 items)
        sortedMintedIds.upc47[0] = 47_000_000_001; // Token ID: 47 * 1000000000 + 1
        sortedMintedIds.upc47[1] = 47_000_000_002; // Token ID: 47 * 1000000000 + 2
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 2000000001 (Pink)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 28_000_000_002; // V4: 28000000002 -> V5: 28000000002
            outfitIds[1] = 37_000_000_001; // V4: 37000000001 -> V5: 37000000001

            resolver.decorateBannyWith(address(hook), 2_000_000_001, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 2_000_000_001
            );
        }

        // Dress Banny 2000000002 (Pink)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 14_000_000_001; // V4: 14000000002 -> V5: 14000000001
            outfitIds[1] = 32_000_000_001; // V4: 32000000001 -> V5: 32000000001

            resolver.decorateBannyWith(address(hook), 2_000_000_002, 6_000_000_001, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 2_000_000_002
            );
        }

        // Dress Banny 2000000003 (Pink)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 25_000_000_003; // V4: 25000000008 -> V5: 25000000003
            outfitIds[1] = 37_000_000_002; // V4: 37000000002 -> V5: 37000000002
            outfitIds[2] = 45_000_000_001; // V4: 45000000001 -> V5: 45000000001

            resolver.decorateBannyWith(address(hook), 2_000_000_003, 6_000_000_003, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 2_000_000_003
            );
        }

        // Dress Banny 3000000001 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 25_000_000_002; // V4: 25000000004 -> V5: 25000000002
            outfitIds[1] = 47_000_000_001; // V4: 47000000003 -> V5: 47000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_001, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_001
            );
        }

        // Dress Banny 3000000002 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 31_000_000_001; // V4: 31000000002 -> V5: 31000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_002, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_002
            );
        }

        // Dress Banny 3000000003 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10_000_000_001; // V4: 10000000005 -> V5: 10000000001
            outfitIds[1] = 19_000_000_002; // V4: 19000000005 -> V5: 19000000002
            outfitIds[2] = 28_000_000_003; // V4: 28000000005 -> V5: 28000000003
            outfitIds[3] = 47_000_000_002; // V4: 47000000005 -> V5: 47000000002

            resolver.decorateBannyWith(address(hook), 3_000_000_003, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_003
            );
        }

        // Dress Banny 3000000006 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 14_000_000_002; // V4: 14000000003 -> V5: 14000000002
            outfitIds[1] = 19_000_000_003; // V4: 19000000007 -> V5: 19000000003
            outfitIds[2] = 28_000_000_001; // V4: 28000000001 -> V5: 28000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_006, 6_000_000_002, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_006
            );
        }

        // Dress Banny 3000000007 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19_000_000_004; // V4: 19000000009 -> V5: 19000000004
            outfitIds[1] = 28_000_000_004; // V4: 28000000007 -> V5: 28000000004
            outfitIds[2] = 44_000_000_002; // V4: 44000000005 -> V5: 44000000002

            resolver.decorateBannyWith(address(hook), 3_000_000_007, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_007
            );
        }

        // Dress Banny 3000000008 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 15_000_000_002; // V4: 15000000002 -> V5: 15000000002
            outfitIds[1] = 40_000_000_001; // V4: 40000000001 -> V5: 40000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_008, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_008
            );
        }

        // Dress Banny 3000000010 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 25_000_000_004; // V4: 25000000009 -> V5: 25000000004
            outfitIds[1] = 43_000_000_001; // V4: 43000000008 -> V5: 43000000001

            resolver.decorateBannyWith(address(hook), 3_000_000_010, 5_000_000_001, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_010
            );
        }

        // Dress Banny 4000000001 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 15_000_000_001; // V4: 15000000001 -> V5: 15000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_001, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_001
            );
        }

        // Dress Banny 4000000003 (Original)
        {
            uint256[] memory outfitIds = new uint256[](5);
            outfitIds[0] = 11_000_000_001; // V4: 11000000001 -> V5: 11000000001
            outfitIds[1] = 19_000_000_001; // V4: 19000000001 -> V5: 19000000001
            outfitIds[2] = 25_000_000_001; // V4: 25000000001 -> V5: 25000000001
            outfitIds[3] = 33_000_000_001; // V4: 33000000001 -> V5: 33000000001
            outfitIds[4] = 44_000_000_001; // V4: 44000000001 -> V5: 44000000001

            resolver.decorateBannyWith(address(hook), 4_000_000_003, 6_000_000_004, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_003
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 2_000_000_001; // Token ID (V4: 2000000001)
        generatedTokenIds[1] = 2_000_000_002; // Token ID (V4: 2000000002)
        generatedTokenIds[2] = 2_000_000_003; // Token ID (V4: 2000000003)
        generatedTokenIds[3] = 3_000_000_001; // Token ID (V4: 3000000001)
        generatedTokenIds[4] = 3_000_000_002; // Token ID (V4: 3000000002)
        generatedTokenIds[5] = 3_000_000_003; // Token ID (V4: 3000000003)
        generatedTokenIds[6] = 3_000_000_004; // Token ID (V4: 3000000004)
        generatedTokenIds[7] = 3_000_000_005; // Token ID (V4: 3000000005)
        generatedTokenIds[8] = 3_000_000_006; // Token ID (V4: 3000000006)
        generatedTokenIds[9] = 3_000_000_007; // Token ID (V4: 3000000007)
        generatedTokenIds[10] = 3_000_000_008; // Token ID (V4: 3000000008)
        generatedTokenIds[11] = 3_000_000_009; // Token ID (V4: 3000000009)
        generatedTokenIds[12] = 3_000_000_010; // Token ID (V4: 3000000010)
        generatedTokenIds[13] = 4_000_000_001; // Token ID (V4: 4000000001)
        generatedTokenIds[14] = 4_000_000_002; // Token ID (V4: 4000000002)
        generatedTokenIds[15] = 4_000_000_003; // Token ID (V4: 4000000003)
        generatedTokenIds[16] = 4_000_000_004; // Token ID (V4: 4000000004)
        generatedTokenIds[17] = 4_000_000_005; // Token ID (V4: 4000000005)
        generatedTokenIds[18] = 4_000_000_006; // Token ID (V4: 4000000006)
        generatedTokenIds[19] = 4_000_000_007; // Token ID (V4: 4000000007)
        generatedTokenIds[20] = 4_000_000_008; // Token ID (V4: 4000000008)
        generatedTokenIds[21] = 4_000_000_009; // Token ID (V4: 4000000009)
        generatedTokenIds[22] = 4_000_000_010; // Token ID (V4: 4000000010)
        generatedTokenIds[23] = 4_000_000_011; // Token ID (V4: 4000000011)
        generatedTokenIds[24] = 4_000_000_012; // Token ID (V4: 4000000012)
        generatedTokenIds[25] = 4_000_000_013; // Token ID (V4: 4000000013)
        generatedTokenIds[26] = 4_000_000_014; // Token ID (V4: 4000000014)

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
        // address[] memory uniqueOwners = new address[](13);

        // uniqueOwners[0] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        // uniqueOwners[1] = 0x565B93a15d38aCD79c120b15432D21E21eD274d6;
        // uniqueOwners[2] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        // uniqueOwners[3] = 0x25171bD3cD3231c3057c96F38E32E3bA6681497a;
        // uniqueOwners[4] = 0x4718ce007293bCe1E514887E6F55ea71d9A992d6;
        // uniqueOwners[5] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        // uniqueOwners[6] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        // uniqueOwners[7] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        // uniqueOwners[8] = 0xAAeD9fFF9858d48925904E391B77892BA5Fda824;
        // uniqueOwners[9] = 0xDf087B724174A3E4eD2338C0798193932E851F1b;
        // uniqueOwners[10] = 0x28C173B8F20488eEF1b0f48Df8453A2f59C38337;
        // uniqueOwners[11] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        // uniqueOwners[12] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](21);

        // uniqueTierIds[0] = 2;
        // uniqueTierIds[1] = 3;
        // uniqueTierIds[2] = 4;
        // uniqueTierIds[3] = 5;
        // uniqueTierIds[4] = 6;
        // uniqueTierIds[5] = 10;
        // uniqueTierIds[6] = 11;
        // uniqueTierIds[7] = 14;
        // uniqueTierIds[8] = 15;
        // uniqueTierIds[9] = 19;
        // uniqueTierIds[10] = 25;
        // uniqueTierIds[11] = 28;
        // uniqueTierIds[12] = 31;
        // uniqueTierIds[13] = 32;
        // uniqueTierIds[14] = 33;
        // uniqueTierIds[15] = 37;
        // uniqueTierIds[16] = 40;
        // uniqueTierIds[17] = 43;
        // uniqueTierIds[18] = 44;
        // uniqueTierIds[19] = 45;
        // uniqueTierIds[20] = 47;

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
