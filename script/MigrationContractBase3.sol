// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractBase3 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[27] upc4;
        uint256[3] upc10;
        uint256[1] upc14;
        uint256[1] upc19;
        uint256[2] upc25;
        uint256[1] upc28;
        uint256[1] upc31;
        uint256[1] upc38;
        uint256[2] upc43;
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

        // Base migration chunk 3/4 - 40 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (27 items)
        sortedMintedIds.upc4[0] = 4_000_000_042; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_043; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_044; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_045; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_046; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_047; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_048; // Token ID: 4 * 1000000000 + 7
        sortedMintedIds.upc4[7] = 4_000_000_049; // Token ID: 4 * 1000000000 + 8
        sortedMintedIds.upc4[8] = 4_000_000_050; // Token ID: 4 * 1000000000 + 9
        sortedMintedIds.upc4[9] = 4_000_000_051; // Token ID: 4 * 1000000000 + 10
        sortedMintedIds.upc4[10] = 4_000_000_052; // Token ID: 4 * 1000000000 + 11
        sortedMintedIds.upc4[11] = 4_000_000_053; // Token ID: 4 * 1000000000 + 12
        sortedMintedIds.upc4[12] = 4_000_000_054; // Token ID: 4 * 1000000000 + 13
        sortedMintedIds.upc4[13] = 4_000_000_055; // Token ID: 4 * 1000000000 + 14
        sortedMintedIds.upc4[14] = 4_000_000_056; // Token ID: 4 * 1000000000 + 15
        sortedMintedIds.upc4[15] = 4_000_000_057; // Token ID: 4 * 1000000000 + 16
        sortedMintedIds.upc4[16] = 4_000_000_058; // Token ID: 4 * 1000000000 + 17
        sortedMintedIds.upc4[17] = 4_000_000_059; // Token ID: 4 * 1000000000 + 18
        sortedMintedIds.upc4[18] = 4_000_000_060; // Token ID: 4 * 1000000000 + 19
        sortedMintedIds.upc4[19] = 4_000_000_061; // Token ID: 4 * 1000000000 + 20
        sortedMintedIds.upc4[20] = 4_000_000_062; // Token ID: 4 * 1000000000 + 21
        sortedMintedIds.upc4[21] = 4_000_000_063; // Token ID: 4 * 1000000000 + 22
        sortedMintedIds.upc4[22] = 4_000_000_064; // Token ID: 4 * 1000000000 + 23
        sortedMintedIds.upc4[23] = 4_000_000_065; // Token ID: 4 * 1000000000 + 24
        sortedMintedIds.upc4[24] = 4_000_000_066; // Token ID: 4 * 1000000000 + 25
        sortedMintedIds.upc4[25] = 4_000_000_067; // Token ID: 4 * 1000000000 + 26
        sortedMintedIds.upc4[26] = 4_000_000_068; // Token ID: 4 * 1000000000 + 27
        // Populate UPC 10 minted tokenIds (3 items)
        sortedMintedIds.upc10[0] = 10_000_000_002; // Token ID: 10 * 1000000000 + 1
        sortedMintedIds.upc10[1] = 10_000_000_003; // Token ID: 10 * 1000000000 + 2
        sortedMintedIds.upc10[2] = 10_000_000_004; // Token ID: 10 * 1000000000 + 3
        // Populate UPC 14 minted tokenIds (1 items)
        sortedMintedIds.upc14[0] = 14_000_000_003; // Token ID: 14 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (1 items)
        sortedMintedIds.upc19[0] = 19_000_000_005; // Token ID: 19 * 1000000000 + 1
        // Populate UPC 25 minted tokenIds (2 items)
        sortedMintedIds.upc25[0] = 25_000_000_005; // Token ID: 25 * 1000000000 + 1
        sortedMintedIds.upc25[1] = 25_000_000_006; // Token ID: 25 * 1000000000 + 2
        // Populate UPC 28 minted tokenIds (1 items)
        sortedMintedIds.upc28[0] = 28_000_000_005; // Token ID: 28 * 1000000000 + 1
        // Populate UPC 31 minted tokenIds (1 items)
        sortedMintedIds.upc31[0] = 31_000_000_002; // Token ID: 31 * 1000000000 + 1
        // Populate UPC 38 minted tokenIds (1 items)
        sortedMintedIds.upc38[0] = 38_000_000_001; // Token ID: 38 * 1000000000 + 1
        // Populate UPC 43 minted tokenIds (2 items)
        sortedMintedIds.upc43[0] = 43_000_000_002; // Token ID: 43 * 1000000000 + 1
        sortedMintedIds.upc43[1] = 43_000_000_003; // Token ID: 43 * 1000000000 + 2
        // Populate UPC 47 minted tokenIds (1 items)
        sortedMintedIds.upc47[0] = 47_000_000_003; // Token ID: 47 * 1000000000 + 1
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 4000000045 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 10_000_000_002; // V4: 10000000001 -> V5: 10000000002
            outfitIds[1] = 25_000_000_005; // V4: 25000000002 -> V5: 25000000005
            outfitIds[2] = 43_000_000_002; // V4: 43000000002 -> V5: 43000000002

            resolver.decorateBannyWith(address(hook), 4_000_000_045, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_045
            );
        }

        // Dress Banny 4000000046 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 47_000_000_003; // V4: 47000000001 -> V5: 47000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_046, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_046
            );
        }

        // Dress Banny 4000000048 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 10_000_000_003; // V4: 10000000003 -> V5: 10000000003
            outfitIds[1] = 19_000_000_005; // V4: 19000000003 -> V5: 19000000005
            outfitIds[2] = 28_000_000_005; // V4: 28000000004 -> V5: 28000000005

            resolver.decorateBannyWith(address(hook), 4_000_000_048, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_048
            );
        }

        // Dress Banny 4000000049 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 10_000_000_004; // V4: 10000000004 -> V5: 10000000004

            resolver.decorateBannyWith(address(hook), 4_000_000_049, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_049
            );
        }

        // Dress Banny 4000000050 (Original)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 14_000_000_003; // V4: 14000000001 -> V5: 14000000003
            outfitIds[1] = 31_000_000_002; // V4: 31000000001 -> V5: 31000000002
            outfitIds[2] = 38_000_000_001; // V4: 38000000001 -> V5: 38000000001
            outfitIds[3] = 43_000_000_003; // V4: 43000000003 -> V5: 43000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_050, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_050
            );
        }

        // Dress Banny 4000000054 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 25_000_000_006; // V4: 25000000005 -> V5: 25000000006

            resolver.decorateBannyWith(address(hook), 4_000_000_054, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_054
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_042; // Token ID (V4: 4000000042)
        generatedTokenIds[1] = 4_000_000_043; // Token ID (V4: 4000000043)
        generatedTokenIds[2] = 4_000_000_044; // Token ID (V4: 4000000044)
        generatedTokenIds[3] = 4_000_000_045; // Token ID (V4: 4000000045)
        generatedTokenIds[4] = 4_000_000_046; // Token ID (V4: 4000000046)
        generatedTokenIds[5] = 4_000_000_047; // Token ID (V4: 4000000047)
        generatedTokenIds[6] = 4_000_000_048; // Token ID (V4: 4000000048)
        generatedTokenIds[7] = 4_000_000_049; // Token ID (V4: 4000000049)
        generatedTokenIds[8] = 4_000_000_050; // Token ID (V4: 4000000050)
        generatedTokenIds[9] = 4_000_000_051; // Token ID (V4: 4000000051)
        generatedTokenIds[10] = 4_000_000_052; // Token ID (V4: 4000000052)
        generatedTokenIds[11] = 4_000_000_053; // Token ID (V4: 4000000053)
        generatedTokenIds[12] = 4_000_000_054; // Token ID (V4: 4000000054)
        generatedTokenIds[13] = 4_000_000_055; // Token ID (V4: 4000000055)
        generatedTokenIds[14] = 4_000_000_056; // Token ID (V4: 4000000056)
        generatedTokenIds[15] = 4_000_000_057; // Token ID (V4: 4000000057)
        generatedTokenIds[16] = 4_000_000_058; // Token ID (V4: 4000000058)
        generatedTokenIds[17] = 4_000_000_059; // Token ID (V4: 4000000059)
        generatedTokenIds[18] = 4_000_000_060; // Token ID (V4: 4000000060)
        generatedTokenIds[19] = 4_000_000_061; // Token ID (V4: 4000000061)
        generatedTokenIds[20] = 4_000_000_062; // Token ID (V4: 4000000062)
        generatedTokenIds[21] = 4_000_000_063; // Token ID (V4: 4000000063)
        generatedTokenIds[22] = 4_000_000_064; // Token ID (V4: 4000000064)
        generatedTokenIds[23] = 4_000_000_065; // Token ID (V4: 4000000065)
        generatedTokenIds[24] = 4_000_000_066; // Token ID (V4: 4000000066)
        generatedTokenIds[25] = 4_000_000_067; // Token ID (V4: 4000000067)
        generatedTokenIds[26] = 4_000_000_068; // Token ID (V4: 4000000068)

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
        // address[] memory uniqueOwners = new address[](16);

        // uniqueOwners[0] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        // uniqueOwners[1] = 0x67BcBE602e870e2286C19E4E0044E583967c9665;
        // uniqueOwners[2] = 0x18deEE9699526f8C8a87004b2e4e55029Fb26b9a;
        // uniqueOwners[3] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        // uniqueOwners[4] = 0xAcD59e854adf632d2322404198624F757C868C97;
        // uniqueOwners[5] = 0xa13d49fCbf79EAF6A0a58cBDD3361422DB4eAfF1;
        // uniqueOwners[6] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        // uniqueOwners[7] = 0xbeC26FFa12c90217943D1b2958f60A821aE6E549;
        // uniqueOwners[8] = 0x8Ec174c5d86469D1A74094E10485357eBFe2e08e;
        // uniqueOwners[9] = 0xC5704f77f94087CC644d361A5A57295851d242aB;
        // uniqueOwners[10] = 0x99Fa48ccEa8a38CDE6B437450fF9bBdDAFAA4Fc8;
        // uniqueOwners[11] = 0xb6ECb51e3638Eb7aa0C6289ef058DCa27494Acb2;
        // uniqueOwners[12] = 0x57700212B1cB7b67bD7DF3801DA43CA634513fE0;
        // uniqueOwners[13] = 0x9342E2aC6dd4A907948E91E80D2734ecAC1D70eC;
        // uniqueOwners[14] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        // uniqueOwners[15] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](10);

        // uniqueTierIds[0] = 4;
        // uniqueTierIds[1] = 10;
        // uniqueTierIds[2] = 14;
        // uniqueTierIds[3] = 19;
        // uniqueTierIds[4] = 25;
        // uniqueTierIds[5] = 28;
        // uniqueTierIds[6] = 31;
        // uniqueTierIds[7] = 38;
        // uniqueTierIds[8] = 43;
        // uniqueTierIds[9] = 47;

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
