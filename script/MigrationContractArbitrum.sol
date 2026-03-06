// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractArbitrum {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[2] upc3;
        uint256[9] upc4;
        uint256[3] upc5;
        uint256[1] upc6;
        uint256[2] upc10;
        uint256[1] upc11;
        uint256[4] upc19;
        uint256[2] upc20;
        uint256[1] upc25;
        uint256[2] upc28;
        uint256[2] upc31;
        uint256[1] upc32;
        uint256[1] upc38;
        uint256[1] upc39;
        uint256[1] upc43;
        uint256[27] upc47;
        uint256[145] upc49;
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

        // Arbitrum migration - 205 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs are generated as: UPC * 1000000000 + unitNumber (where unitNumber starts at 1)
        MintedIds memory sortedMintedIds;

        // Populate UPC 3 minted tokenIds (2 items)
        for (uint256 i = 0; i < 2; i++) {
            sortedMintedIds.upc3[i] = 3 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 4 minted tokenIds (9 items)
        for (uint256 i = 0; i < 9; i++) {
            sortedMintedIds.upc4[i] = 4 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 5 minted tokenIds (3 items)
        for (uint256 i = 0; i < 3; i++) {
            sortedMintedIds.upc5[i] = 5 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 6 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc6[i] = 6 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 10 minted tokenIds (2 items)
        for (uint256 i = 0; i < 2; i++) {
            sortedMintedIds.upc10[i] = 10 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 11 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc11[i] = 11 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 19 minted tokenIds (4 items)
        for (uint256 i = 0; i < 4; i++) {
            sortedMintedIds.upc19[i] = 19 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 20 minted tokenIds (2 items)
        for (uint256 i = 0; i < 2; i++) {
            sortedMintedIds.upc20[i] = 20 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 25 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc25[i] = 25 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 28 minted tokenIds (2 items)
        for (uint256 i = 0; i < 2; i++) {
            sortedMintedIds.upc28[i] = 28 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 31 minted tokenIds (2 items)
        for (uint256 i = 0; i < 2; i++) {
            sortedMintedIds.upc31[i] = 31 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 32 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc32[i] = 32 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 38 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc38[i] = 38 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 39 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc39[i] = 39 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 43 minted tokenIds (1 items)
        for (uint256 i = 0; i < 1; i++) {
            sortedMintedIds.upc43[i] = 43 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 47 minted tokenIds (27 items)
        for (uint256 i = 0; i < 27; i++) {
            sortedMintedIds.upc47[i] = 47 * 1_000_000_000 + (i + 1);
        }
        // Populate UPC 49 minted tokenIds (145 items)
        for (uint256 i = 0; i < 145; i++) {
            sortedMintedIds.upc49[i] = 49 * 1_000_000_000 + (i + 1);
        }
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 3000000001 (Orange)
        {
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = sortedMintedIds.upc19[0]; // V4: 19000000001 -> V5: sortedMintedIds.upc19[0]
            outfitIds[1] = sortedMintedIds.upc25[0]; // V4: 25000000001 -> V5: sortedMintedIds.upc25[0]
            outfitIds[2] = sortedMintedIds.upc38[0]; // V4: 38000000001 -> V5: sortedMintedIds.upc38[0]
            outfitIds[3] = sortedMintedIds.upc47[0]; // V4: 47000000001 -> V5: sortedMintedIds.upc47[0]

            resolver.decorateBannyWith(address(hook), 3_000_000_001, sortedMintedIds.upc5[0], outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 3_000_000_001
            );
        }

        // Dress Banny 4000000003 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = sortedMintedIds.upc11[0]; // V4: 11000000001 -> V5: sortedMintedIds.upc11[0]
            outfitIds[1] = sortedMintedIds.upc19[2]; // V4: 19000000003 -> V5: sortedMintedIds.upc19[2]
            outfitIds[2] = sortedMintedIds.upc28[0]; // V4: 28000000001 -> V5: sortedMintedIds.upc28[0]

            resolver.decorateBannyWith(address(hook), 4_000_000_003, sortedMintedIds.upc6[0], outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_003
            );
        }

        // Dress Banny 4000000004 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = sortedMintedIds.upc10[0]; // V4: 10000000001 -> V5: sortedMintedIds.upc10[0]
            outfitIds[1] = sortedMintedIds.upc20[0]; // V4: 20000000001 -> V5: sortedMintedIds.upc20[0]

            resolver.decorateBannyWith(address(hook), 4_000_000_004, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_004
            );
        }

        // Dress Banny 4000000005 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = sortedMintedIds.upc31[0]; // V4: 31000000001 -> V5: sortedMintedIds.upc31[0]
            outfitIds[1] = sortedMintedIds.upc49[1]; // V4: 49000000002 -> V5: sortedMintedIds.upc49[1]

            resolver.decorateBannyWith(address(hook), 4_000_000_005, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_005
            );
        }

        // Dress Banny 4000000007 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = sortedMintedIds.upc10[1]; // V4: 10000000002 -> V5: sortedMintedIds.upc10[1]
            outfitIds[1] = sortedMintedIds.upc20[1]; // V4: 20000000002 -> V5: sortedMintedIds.upc20[1]
            outfitIds[2] = sortedMintedIds.upc43[0]; // V4: 43000000001 -> V5: sortedMintedIds.upc43[0]

            resolver.decorateBannyWith(address(hook), 4_000_000_007, sortedMintedIds.upc5[1], outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_007
            );
        }

        // Dress Banny 4000000009 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = sortedMintedIds.upc28[1]; // V4: 28000000002 -> V5: sortedMintedIds.upc28[1]

            resolver.decorateBannyWith(address(hook), 4_000_000_009, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_009
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 3_000_000_001; // Token ID (V4: 3000000001)
        generatedTokenIds[1] = 3_000_000_002; // Token ID (V4: 3000000002)
        generatedTokenIds[2] = 4_000_000_001; // Token ID (V4: 4000000001)
        generatedTokenIds[3] = 4_000_000_002; // Token ID (V4: 4000000002)
        generatedTokenIds[4] = 4_000_000_003; // Token ID (V4: 4000000003)
        generatedTokenIds[5] = 4_000_000_004; // Token ID (V4: 4000000004)
        generatedTokenIds[6] = 4_000_000_005; // Token ID (V4: 4000000005)
        generatedTokenIds[7] = 4_000_000_006; // Token ID (V4: 4000000006)
        generatedTokenIds[8] = 4_000_000_007; // Token ID (V4: 4000000007)
        generatedTokenIds[9] = 4_000_000_008; // Token ID (V4: 4000000008)
        generatedTokenIds[10] = 4_000_000_009; // Token ID (V4: 4000000009)
        generatedTokenIds[11] = 19_000_000_002; // Token ID (V4: 19000000002)
        generatedTokenIds[12] = 19_000_000_004; // Token ID (V4: 19000000004)
        generatedTokenIds[13] = 31_000_000_002; // Token ID (V4: 31000000002)
        generatedTokenIds[14] = 32_000_000_001; // Token ID (V4: 32000000001)
        generatedTokenIds[15] = 39_000_000_001; // Token ID (V4: 39000000001)
        generatedTokenIds[16] = 47_000_000_002; // Token ID (V4: 47000000002)
        generatedTokenIds[17] = 47_000_000_003; // Token ID (V4: 47000000003)
        generatedTokenIds[18] = 47_000_000_004; // Token ID (V4: 47000000004)
        generatedTokenIds[19] = 47_000_000_005; // Token ID (V4: 47000000005)
        generatedTokenIds[20] = 47_000_000_006; // Token ID (V4: 47000000006)
        generatedTokenIds[21] = 47_000_000_007; // Token ID (V4: 47000000007)
        generatedTokenIds[22] = 47_000_000_008; // Token ID (V4: 47000000008)
        generatedTokenIds[23] = 47_000_000_009; // Token ID (V4: 47000000009)
        generatedTokenIds[24] = 47_000_000_010; // Token ID (V4: 47000000010)
        generatedTokenIds[25] = 47_000_000_011; // Token ID (V4: 47000000011)
        generatedTokenIds[26] = 47_000_000_012; // Token ID (V4: 47000000012)
        generatedTokenIds[27] = 47_000_000_013; // Token ID (V4: 47000000013)
        generatedTokenIds[28] = 47_000_000_014; // Token ID (V4: 47000000014)
        generatedTokenIds[29] = 47_000_000_015; // Token ID (V4: 47000000015)
        generatedTokenIds[30] = 47_000_000_016; // Token ID (V4: 47000000016)
        generatedTokenIds[31] = 47_000_000_017; // Token ID (V4: 47000000017)
        generatedTokenIds[32] = 47_000_000_018; // Token ID (V4: 47000000018)
        generatedTokenIds[33] = 47_000_000_019; // Token ID (V4: 47000000019)
        generatedTokenIds[34] = 47_000_000_020; // Token ID (V4: 47000000020)
        generatedTokenIds[35] = 47_000_000_021; // Token ID (V4: 47000000021)
        generatedTokenIds[36] = 47_000_000_022; // Token ID (V4: 47000000022)
        generatedTokenIds[37] = 47_000_000_023; // Token ID (V4: 47000000023)
        generatedTokenIds[38] = 47_000_000_024; // Token ID (V4: 47000000024)
        generatedTokenIds[39] = 47_000_000_025; // Token ID (V4: 47000000025)
        generatedTokenIds[40] = 47_000_000_026; // Token ID (V4: 47000000026)
        generatedTokenIds[41] = 47_000_000_027; // Token ID (V4: 47000000027)
        generatedTokenIds[42] = 49_000_000_001; // Token ID (V4: 49000000001)
        generatedTokenIds[43] = 49_000_000_003; // Token ID (V4: 49000000003)
        generatedTokenIds[44] = 49_000_000_004; // Token ID (V4: 49000000004)
        generatedTokenIds[45] = 49_000_000_005; // Token ID (V4: 49000000005)
        generatedTokenIds[46] = 49_000_000_006; // Token ID (V4: 49000000006)
        generatedTokenIds[47] = 49_000_000_007; // Token ID (V4: 49000000007)
        generatedTokenIds[48] = 49_000_000_008; // Token ID (V4: 49000000008)
        generatedTokenIds[49] = 49_000_000_009; // Token ID (V4: 49000000009)
        generatedTokenIds[50] = 49_000_000_010; // Token ID (V4: 49000000010)
        generatedTokenIds[51] = 49_000_000_011; // Token ID (V4: 49000000011)
        generatedTokenIds[52] = 49_000_000_012; // Token ID (V4: 49000000012)
        generatedTokenIds[53] = 49_000_000_013; // Token ID (V4: 49000000013)
        generatedTokenIds[54] = 49_000_000_014; // Token ID (V4: 49000000014)
        generatedTokenIds[55] = 49_000_000_015; // Token ID (V4: 49000000015)
        generatedTokenIds[56] = 49_000_000_016; // Token ID (V4: 49000000016)
        generatedTokenIds[57] = 49_000_000_017; // Token ID (V4: 49000000017)
        generatedTokenIds[58] = 49_000_000_018; // Token ID (V4: 49000000018)
        generatedTokenIds[59] = 49_000_000_019; // Token ID (V4: 49000000019)
        generatedTokenIds[60] = 49_000_000_020; // Token ID (V4: 49000000020)
        generatedTokenIds[61] = 49_000_000_021; // Token ID (V4: 49000000021)
        generatedTokenIds[62] = 49_000_000_022; // Token ID (V4: 49000000022)
        generatedTokenIds[63] = 49_000_000_023; // Token ID (V4: 49000000023)
        generatedTokenIds[64] = 49_000_000_024; // Token ID (V4: 49000000024)
        generatedTokenIds[65] = 49_000_000_025; // Token ID (V4: 49000000025)
        generatedTokenIds[66] = 49_000_000_026; // Token ID (V4: 49000000026)
        generatedTokenIds[67] = 49_000_000_027; // Token ID (V4: 49000000027)
        generatedTokenIds[68] = 49_000_000_028; // Token ID (V4: 49000000028)
        generatedTokenIds[69] = 49_000_000_029; // Token ID (V4: 49000000029)
        generatedTokenIds[70] = 49_000_000_030; // Token ID (V4: 49000000030)
        generatedTokenIds[71] = 49_000_000_031; // Token ID (V4: 49000000031)
        generatedTokenIds[72] = 49_000_000_032; // Token ID (V4: 49000000032)
        generatedTokenIds[73] = 49_000_000_033; // Token ID (V4: 49000000033)
        generatedTokenIds[74] = 49_000_000_034; // Token ID (V4: 49000000034)
        generatedTokenIds[75] = 49_000_000_035; // Token ID (V4: 49000000035)
        generatedTokenIds[76] = 49_000_000_036; // Token ID (V4: 49000000036)
        generatedTokenIds[77] = 49_000_000_037; // Token ID (V4: 49000000037)
        generatedTokenIds[78] = 49_000_000_038; // Token ID (V4: 49000000038)
        generatedTokenIds[79] = 49_000_000_039; // Token ID (V4: 49000000039)
        generatedTokenIds[80] = 49_000_000_040; // Token ID (V4: 49000000040)
        generatedTokenIds[81] = 49_000_000_041; // Token ID (V4: 49000000041)
        generatedTokenIds[82] = 49_000_000_042; // Token ID (V4: 49000000042)
        generatedTokenIds[83] = 49_000_000_043; // Token ID (V4: 49000000043)
        generatedTokenIds[84] = 49_000_000_044; // Token ID (V4: 49000000044)
        generatedTokenIds[85] = 49_000_000_045; // Token ID (V4: 49000000045)
        generatedTokenIds[86] = 49_000_000_046; // Token ID (V4: 49000000046)
        generatedTokenIds[87] = 49_000_000_047; // Token ID (V4: 49000000047)
        generatedTokenIds[88] = 49_000_000_048; // Token ID (V4: 49000000048)
        generatedTokenIds[89] = 49_000_000_049; // Token ID (V4: 49000000049)
        generatedTokenIds[90] = 49_000_000_050; // Token ID (V4: 49000000050)
        generatedTokenIds[91] = 49_000_000_051; // Token ID (V4: 49000000051)
        generatedTokenIds[92] = 49_000_000_052; // Token ID (V4: 49000000052)
        generatedTokenIds[93] = 49_000_000_053; // Token ID (V4: 49000000053)
        generatedTokenIds[94] = 49_000_000_054; // Token ID (V4: 49000000054)
        generatedTokenIds[95] = 49_000_000_055; // Token ID (V4: 49000000055)
        generatedTokenIds[96] = 49_000_000_056; // Token ID (V4: 49000000056)
        generatedTokenIds[97] = 49_000_000_057; // Token ID (V4: 49000000057)
        generatedTokenIds[98] = 49_000_000_058; // Token ID (V4: 49000000058)
        generatedTokenIds[99] = 49_000_000_059; // Token ID (V4: 49000000059)
        generatedTokenIds[100] = 49_000_000_060; // Token ID (V4: 49000000060)
        generatedTokenIds[101] = 49_000_000_061; // Token ID (V4: 49000000061)
        generatedTokenIds[102] = 49_000_000_062; // Token ID (V4: 49000000062)
        generatedTokenIds[103] = 49_000_000_063; // Token ID (V4: 49000000063)
        generatedTokenIds[104] = 49_000_000_064; // Token ID (V4: 49000000064)
        generatedTokenIds[105] = 49_000_000_065; // Token ID (V4: 49000000065)
        generatedTokenIds[106] = 49_000_000_066; // Token ID (V4: 49000000066)
        generatedTokenIds[107] = 49_000_000_067; // Token ID (V4: 49000000067)
        generatedTokenIds[108] = 49_000_000_068; // Token ID (V4: 49000000068)
        generatedTokenIds[109] = 49_000_000_069; // Token ID (V4: 49000000069)
        generatedTokenIds[110] = 49_000_000_070; // Token ID (V4: 49000000070)
        generatedTokenIds[111] = 49_000_000_071; // Token ID (V4: 49000000071)
        generatedTokenIds[112] = 49_000_000_072; // Token ID (V4: 49000000072)
        generatedTokenIds[113] = 49_000_000_073; // Token ID (V4: 49000000073)
        generatedTokenIds[114] = 49_000_000_074; // Token ID (V4: 49000000074)
        generatedTokenIds[115] = 49_000_000_075; // Token ID (V4: 49000000075)
        generatedTokenIds[116] = 49_000_000_076; // Token ID (V4: 49000000076)
        generatedTokenIds[117] = 49_000_000_077; // Token ID (V4: 49000000077)
        generatedTokenIds[118] = 49_000_000_078; // Token ID (V4: 49000000078)
        generatedTokenIds[119] = 49_000_000_079; // Token ID (V4: 49000000079)
        generatedTokenIds[120] = 49_000_000_080; // Token ID (V4: 49000000080)
        generatedTokenIds[121] = 49_000_000_081; // Token ID (V4: 49000000081)
        generatedTokenIds[122] = 49_000_000_082; // Token ID (V4: 49000000082)
        generatedTokenIds[123] = 49_000_000_083; // Token ID (V4: 49000000083)
        generatedTokenIds[124] = 49_000_000_084; // Token ID (V4: 49000000084)
        generatedTokenIds[125] = 49_000_000_085; // Token ID (V4: 49000000085)
        generatedTokenIds[126] = 49_000_000_086; // Token ID (V4: 49000000086)
        generatedTokenIds[127] = 49_000_000_087; // Token ID (V4: 49000000087)
        generatedTokenIds[128] = 49_000_000_088; // Token ID (V4: 49000000088)
        generatedTokenIds[129] = 49_000_000_089; // Token ID (V4: 49000000089)
        generatedTokenIds[130] = 49_000_000_090; // Token ID (V4: 49000000090)
        generatedTokenIds[131] = 49_000_000_091; // Token ID (V4: 49000000091)
        generatedTokenIds[132] = 49_000_000_092; // Token ID (V4: 49000000092)
        generatedTokenIds[133] = 49_000_000_093; // Token ID (V4: 49000000093)
        generatedTokenIds[134] = 49_000_000_094; // Token ID (V4: 49000000094)
        generatedTokenIds[135] = 49_000_000_095; // Token ID (V4: 49000000095)
        generatedTokenIds[136] = 49_000_000_096; // Token ID (V4: 49000000096)
        generatedTokenIds[137] = 49_000_000_097; // Token ID (V4: 49000000097)
        generatedTokenIds[138] = 49_000_000_098; // Token ID (V4: 49000000098)
        generatedTokenIds[139] = 49_000_000_099; // Token ID (V4: 49000000099)
        generatedTokenIds[140] = 49_000_000_100; // Token ID (V4: 49000000100)
        generatedTokenIds[141] = 49_000_000_101; // Token ID (V4: 49000000101)
        generatedTokenIds[142] = 49_000_000_102; // Token ID (V4: 49000000102)
        generatedTokenIds[143] = 49_000_000_103; // Token ID (V4: 49000000103)
        generatedTokenIds[144] = 49_000_000_104; // Token ID (V4: 49000000104)
        generatedTokenIds[145] = 49_000_000_105; // Token ID (V4: 49000000105)
        generatedTokenIds[146] = 49_000_000_106; // Token ID (V4: 49000000106)
        generatedTokenIds[147] = 49_000_000_107; // Token ID (V4: 49000000107)
        generatedTokenIds[148] = 49_000_000_108; // Token ID (V4: 49000000108)
        generatedTokenIds[149] = 49_000_000_109; // Token ID (V4: 49000000109)
        generatedTokenIds[150] = 49_000_000_110; // Token ID (V4: 49000000110)
        generatedTokenIds[151] = 49_000_000_111; // Token ID (V4: 49000000111)
        generatedTokenIds[152] = 49_000_000_112; // Token ID (V4: 49000000112)
        generatedTokenIds[153] = 49_000_000_113; // Token ID (V4: 49000000113)
        generatedTokenIds[154] = 49_000_000_114; // Token ID (V4: 49000000114)
        generatedTokenIds[155] = 49_000_000_115; // Token ID (V4: 49000000115)
        generatedTokenIds[156] = 49_000_000_116; // Token ID (V4: 49000000116)
        generatedTokenIds[157] = 49_000_000_117; // Token ID (V4: 49000000117)
        generatedTokenIds[158] = 49_000_000_118; // Token ID (V4: 49000000118)
        generatedTokenIds[159] = 49_000_000_119; // Token ID (V4: 49000000119)
        generatedTokenIds[160] = 49_000_000_120; // Token ID (V4: 49000000120)
        generatedTokenIds[161] = 49_000_000_121; // Token ID (V4: 49000000121)
        generatedTokenIds[162] = 49_000_000_122; // Token ID (V4: 49000000122)
        generatedTokenIds[163] = 49_000_000_123; // Token ID (V4: 49000000123)
        generatedTokenIds[164] = 49_000_000_124; // Token ID (V4: 49000000124)
        generatedTokenIds[165] = 49_000_000_125; // Token ID (V4: 49000000125)
        generatedTokenIds[166] = 49_000_000_126; // Token ID (V4: 49000000126)
        generatedTokenIds[167] = 49_000_000_127; // Token ID (V4: 49000000127)
        generatedTokenIds[168] = 49_000_000_128; // Token ID (V4: 49000000128)
        generatedTokenIds[169] = 49_000_000_129; // Token ID (V4: 49000000129)
        generatedTokenIds[170] = 49_000_000_130; // Token ID (V4: 49000000130)
        generatedTokenIds[171] = 49_000_000_131; // Token ID (V4: 49000000131)
        generatedTokenIds[172] = 49_000_000_132; // Token ID (V4: 49000000132)
        generatedTokenIds[173] = 49_000_000_133; // Token ID (V4: 49000000133)
        generatedTokenIds[174] = 49_000_000_134; // Token ID (V4: 49000000134)
        generatedTokenIds[175] = 49_000_000_135; // Token ID (V4: 49000000135)
        generatedTokenIds[176] = 49_000_000_136; // Token ID (V4: 49000000136)
        generatedTokenIds[177] = 49_000_000_137; // Token ID (V4: 49000000137)
        generatedTokenIds[178] = 49_000_000_138; // Token ID (V4: 49000000138)
        generatedTokenIds[179] = 49_000_000_139; // Token ID (V4: 49000000139)
        generatedTokenIds[180] = 49_000_000_140; // Token ID (V4: 49000000140)
        generatedTokenIds[181] = 49_000_000_141; // Token ID (V4: 49000000141)
        generatedTokenIds[182] = 49_000_000_142; // Token ID (V4: 49000000142)
        generatedTokenIds[183] = 49_000_000_143; // Token ID (V4: 49000000143)
        generatedTokenIds[184] = 49_000_000_144; // Token ID (V4: 49000000144)
        generatedTokenIds[185] = 49_000_000_145; // Token ID (V4: 49000000145)
        generatedTokenIds[186] = 5_000_000_003; // Token ID (V4: 5000000003)

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

            IERC721(address(hook)).transferFrom(address(this), transferOwners[i], tokenId);
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

        // uniqueOwners[0] = 0x2aa64E6d80390F5C017F0313cB908051BE2FD35e;
        // uniqueOwners[1] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        // uniqueOwners[2] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        // uniqueOwners[3] = 0xfD282d9f4d06C4BDc6a41af1Ae920A0AD70D18a3;
        // uniqueOwners[4] = 0x08B3e694caA2F1fcF8eF71095CED1326f3454B89;
        // uniqueOwners[5] = 0x9fDf876a50EA8f95017dCFC7709356887025B5BB;
        // uniqueOwners[6] = 0x187089B33E5812310Ed32A57F53B3fAD0383a19D;
        // uniqueOwners[7] = 0xc6404f24DB2f573F07F3A60758765caad198c0c3;
        // uniqueOwners[8] = 0xB2d3900807094D4Fe47405871B0C8AdB58E10D42;
        // uniqueOwners[9] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](17);

        // uniqueTierIds[0] = 3;
        // uniqueTierIds[1] = 4;
        // uniqueTierIds[2] = 5;
        // uniqueTierIds[3] = 6;
        // uniqueTierIds[4] = 10;
        // uniqueTierIds[5] = 11;
        // uniqueTierIds[6] = 19;
        // uniqueTierIds[7] = 20;
        // uniqueTierIds[8] = 25;
        // uniqueTierIds[9] = 28;
        // uniqueTierIds[10] = 31;
        // uniqueTierIds[11] = 32;
        // uniqueTierIds[12] = 38;
        // uniqueTierIds[13] = 39;
        // uniqueTierIds[14] = 43;
        // uniqueTierIds[15] = 47;
        // uniqueTierIds[16] = 49;

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
