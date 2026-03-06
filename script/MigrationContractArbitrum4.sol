// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

/// @notice Migration contract for Arbitrum to handle standalone outfits and backgrounds
/// that are not worn/used by any banny. These assets are minted to this contract
/// and then transferred directly to their owners.
contract MigrationContractArbitrum4 {
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
        IERC721 v4Hook = IERC721(v4HookAddress);

        // Arbitrum migration - Standalone outfits and backgrounds (176 items)
        // These are assets that are NOT being worn/used by any banny

        // Assets are already minted to this contract by the deployer
        // V5 token IDs are calculated based on mint order (continuing from previous chunks)
        // V4 token IDs are the original token IDs from V4

        // Generate token IDs - store both V5 minted token IDs and original V4 token IDs
        uint256[] memory v5TokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        v5TokenIds[0] = 5_000_000_003; // Minted V5 Token ID
        v4TokenIds[0] = 5_000_000_003; // Original V4 Token ID
        v5TokenIds[1] = 19_000_000_003; // Minted V5 Token ID
        v4TokenIds[1] = 19_000_000_002; // Original V4 Token ID
        v5TokenIds[2] = 19_000_000_004; // Minted V5 Token ID
        v4TokenIds[2] = 19_000_000_004; // Original V4 Token ID
        v5TokenIds[3] = 31_000_000_002; // Minted V5 Token ID
        v4TokenIds[3] = 31_000_000_002; // Original V4 Token ID
        v5TokenIds[4] = 32_000_000_001; // Minted V5 Token ID
        v4TokenIds[4] = 32_000_000_001; // Original V4 Token ID
        v5TokenIds[5] = 39_000_000_001; // Minted V5 Token ID
        v4TokenIds[5] = 39_000_000_001; // Original V4 Token ID
        v5TokenIds[6] = 47_000_000_002; // Minted V5 Token ID
        v4TokenIds[6] = 47_000_000_002; // Original V4 Token ID
        v5TokenIds[7] = 47_000_000_003; // Minted V5 Token ID
        v4TokenIds[7] = 47_000_000_003; // Original V4 Token ID
        v5TokenIds[8] = 47_000_000_004; // Minted V5 Token ID
        v4TokenIds[8] = 47_000_000_004; // Original V4 Token ID
        v5TokenIds[9] = 47_000_000_005; // Minted V5 Token ID
        v4TokenIds[9] = 47_000_000_005; // Original V4 Token ID
        v5TokenIds[10] = 47_000_000_006; // Minted V5 Token ID
        v4TokenIds[10] = 47_000_000_006; // Original V4 Token ID
        v5TokenIds[11] = 47_000_000_007; // Minted V5 Token ID
        v4TokenIds[11] = 47_000_000_007; // Original V4 Token ID
        v5TokenIds[12] = 47_000_000_008; // Minted V5 Token ID
        v4TokenIds[12] = 47_000_000_008; // Original V4 Token ID
        v5TokenIds[13] = 47_000_000_009; // Minted V5 Token ID
        v4TokenIds[13] = 47_000_000_009; // Original V4 Token ID
        v5TokenIds[14] = 47_000_000_010; // Minted V5 Token ID
        v4TokenIds[14] = 47_000_000_010; // Original V4 Token ID
        v5TokenIds[15] = 47_000_000_011; // Minted V5 Token ID
        v4TokenIds[15] = 47_000_000_011; // Original V4 Token ID
        v5TokenIds[16] = 47_000_000_012; // Minted V5 Token ID
        v4TokenIds[16] = 47_000_000_012; // Original V4 Token ID
        v5TokenIds[17] = 47_000_000_013; // Minted V5 Token ID
        v4TokenIds[17] = 47_000_000_013; // Original V4 Token ID
        v5TokenIds[18] = 47_000_000_014; // Minted V5 Token ID
        v4TokenIds[18] = 47_000_000_014; // Original V4 Token ID
        v5TokenIds[19] = 47_000_000_015; // Minted V5 Token ID
        v4TokenIds[19] = 47_000_000_015; // Original V4 Token ID
        v5TokenIds[20] = 47_000_000_016; // Minted V5 Token ID
        v4TokenIds[20] = 47_000_000_016; // Original V4 Token ID
        v5TokenIds[21] = 47_000_000_017; // Minted V5 Token ID
        v4TokenIds[21] = 47_000_000_017; // Original V4 Token ID
        v5TokenIds[22] = 47_000_000_018; // Minted V5 Token ID
        v4TokenIds[22] = 47_000_000_018; // Original V4 Token ID
        v5TokenIds[23] = 47_000_000_019; // Minted V5 Token ID
        v4TokenIds[23] = 47_000_000_019; // Original V4 Token ID
        v5TokenIds[24] = 47_000_000_020; // Minted V5 Token ID
        v4TokenIds[24] = 47_000_000_020; // Original V4 Token ID
        v5TokenIds[25] = 47_000_000_021; // Minted V5 Token ID
        v4TokenIds[25] = 47_000_000_021; // Original V4 Token ID
        v5TokenIds[26] = 47_000_000_022; // Minted V5 Token ID
        v4TokenIds[26] = 47_000_000_022; // Original V4 Token ID
        v5TokenIds[27] = 47_000_000_023; // Minted V5 Token ID
        v4TokenIds[27] = 47_000_000_023; // Original V4 Token ID
        v5TokenIds[28] = 47_000_000_024; // Minted V5 Token ID
        v4TokenIds[28] = 47_000_000_024; // Original V4 Token ID
        v5TokenIds[29] = 47_000_000_025; // Minted V5 Token ID
        v4TokenIds[29] = 47_000_000_025; // Original V4 Token ID
        v5TokenIds[30] = 47_000_000_026; // Minted V5 Token ID
        v4TokenIds[30] = 47_000_000_026; // Original V4 Token ID
        v5TokenIds[31] = 47_000_000_027; // Minted V5 Token ID
        v4TokenIds[31] = 47_000_000_027; // Original V4 Token ID
        v5TokenIds[32] = 49_000_000_002; // Minted V5 Token ID
        v4TokenIds[32] = 49_000_000_001; // Original V4 Token ID
        v5TokenIds[33] = 49_000_000_003; // Minted V5 Token ID
        v4TokenIds[33] = 49_000_000_003; // Original V4 Token ID
        v5TokenIds[34] = 49_000_000_004; // Minted V5 Token ID
        v4TokenIds[34] = 49_000_000_004; // Original V4 Token ID
        v5TokenIds[35] = 49_000_000_005; // Minted V5 Token ID
        v4TokenIds[35] = 49_000_000_005; // Original V4 Token ID
        v5TokenIds[36] = 49_000_000_006; // Minted V5 Token ID
        v4TokenIds[36] = 49_000_000_006; // Original V4 Token ID
        v5TokenIds[37] = 49_000_000_007; // Minted V5 Token ID
        v4TokenIds[37] = 49_000_000_007; // Original V4 Token ID
        v5TokenIds[38] = 49_000_000_008; // Minted V5 Token ID
        v4TokenIds[38] = 49_000_000_008; // Original V4 Token ID
        v5TokenIds[39] = 49_000_000_009; // Minted V5 Token ID
        v4TokenIds[39] = 49_000_000_009; // Original V4 Token ID
        v5TokenIds[40] = 49_000_000_010; // Minted V5 Token ID
        v4TokenIds[40] = 49_000_000_010; // Original V4 Token ID
        v5TokenIds[41] = 49_000_000_011; // Minted V5 Token ID
        v4TokenIds[41] = 49_000_000_011; // Original V4 Token ID
        v5TokenIds[42] = 49_000_000_012; // Minted V5 Token ID
        v4TokenIds[42] = 49_000_000_012; // Original V4 Token ID
        v5TokenIds[43] = 49_000_000_013; // Minted V5 Token ID
        v4TokenIds[43] = 49_000_000_013; // Original V4 Token ID
        v5TokenIds[44] = 49_000_000_014; // Minted V5 Token ID
        v4TokenIds[44] = 49_000_000_014; // Original V4 Token ID
        v5TokenIds[45] = 49_000_000_015; // Minted V5 Token ID
        v4TokenIds[45] = 49_000_000_015; // Original V4 Token ID
        v5TokenIds[46] = 49_000_000_016; // Minted V5 Token ID
        v4TokenIds[46] = 49_000_000_016; // Original V4 Token ID
        v5TokenIds[47] = 49_000_000_017; // Minted V5 Token ID
        v4TokenIds[47] = 49_000_000_017; // Original V4 Token ID
        v5TokenIds[48] = 49_000_000_018; // Minted V5 Token ID
        v4TokenIds[48] = 49_000_000_018; // Original V4 Token ID
        v5TokenIds[49] = 49_000_000_019; // Minted V5 Token ID
        v4TokenIds[49] = 49_000_000_019; // Original V4 Token ID
        v5TokenIds[50] = 49_000_000_020; // Minted V5 Token ID
        v4TokenIds[50] = 49_000_000_020; // Original V4 Token ID
        v5TokenIds[51] = 49_000_000_021; // Minted V5 Token ID
        v4TokenIds[51] = 49_000_000_021; // Original V4 Token ID
        v5TokenIds[52] = 49_000_000_022; // Minted V5 Token ID
        v4TokenIds[52] = 49_000_000_022; // Original V4 Token ID
        v5TokenIds[53] = 49_000_000_023; // Minted V5 Token ID
        v4TokenIds[53] = 49_000_000_023; // Original V4 Token ID
        v5TokenIds[54] = 49_000_000_024; // Minted V5 Token ID
        v4TokenIds[54] = 49_000_000_024; // Original V4 Token ID
        v5TokenIds[55] = 49_000_000_025; // Minted V5 Token ID
        v4TokenIds[55] = 49_000_000_025; // Original V4 Token ID
        v5TokenIds[56] = 49_000_000_026; // Minted V5 Token ID
        v4TokenIds[56] = 49_000_000_026; // Original V4 Token ID
        v5TokenIds[57] = 49_000_000_027; // Minted V5 Token ID
        v4TokenIds[57] = 49_000_000_027; // Original V4 Token ID
        v5TokenIds[58] = 49_000_000_028; // Minted V5 Token ID
        v4TokenIds[58] = 49_000_000_028; // Original V4 Token ID
        v5TokenIds[59] = 49_000_000_029; // Minted V5 Token ID
        v4TokenIds[59] = 49_000_000_029; // Original V4 Token ID
        v5TokenIds[60] = 49_000_000_030; // Minted V5 Token ID
        v4TokenIds[60] = 49_000_000_030; // Original V4 Token ID
        v5TokenIds[61] = 49_000_000_031; // Minted V5 Token ID
        v4TokenIds[61] = 49_000_000_031; // Original V4 Token ID
        v5TokenIds[62] = 49_000_000_032; // Minted V5 Token ID
        v4TokenIds[62] = 49_000_000_032; // Original V4 Token ID
        v5TokenIds[63] = 49_000_000_033; // Minted V5 Token ID
        v4TokenIds[63] = 49_000_000_033; // Original V4 Token ID
        v5TokenIds[64] = 49_000_000_034; // Minted V5 Token ID
        v4TokenIds[64] = 49_000_000_034; // Original V4 Token ID
        v5TokenIds[65] = 49_000_000_035; // Minted V5 Token ID
        v4TokenIds[65] = 49_000_000_035; // Original V4 Token ID
        v5TokenIds[66] = 49_000_000_036; // Minted V5 Token ID
        v4TokenIds[66] = 49_000_000_036; // Original V4 Token ID
        v5TokenIds[67] = 49_000_000_037; // Minted V5 Token ID
        v4TokenIds[67] = 49_000_000_037; // Original V4 Token ID
        v5TokenIds[68] = 49_000_000_038; // Minted V5 Token ID
        v4TokenIds[68] = 49_000_000_038; // Original V4 Token ID
        v5TokenIds[69] = 49_000_000_039; // Minted V5 Token ID
        v4TokenIds[69] = 49_000_000_039; // Original V4 Token ID
        v5TokenIds[70] = 49_000_000_040; // Minted V5 Token ID
        v4TokenIds[70] = 49_000_000_040; // Original V4 Token ID
        v5TokenIds[71] = 49_000_000_041; // Minted V5 Token ID
        v4TokenIds[71] = 49_000_000_041; // Original V4 Token ID
        v5TokenIds[72] = 49_000_000_042; // Minted V5 Token ID
        v4TokenIds[72] = 49_000_000_042; // Original V4 Token ID
        v5TokenIds[73] = 49_000_000_043; // Minted V5 Token ID
        v4TokenIds[73] = 49_000_000_043; // Original V4 Token ID
        v5TokenIds[74] = 49_000_000_044; // Minted V5 Token ID
        v4TokenIds[74] = 49_000_000_044; // Original V4 Token ID
        v5TokenIds[75] = 49_000_000_045; // Minted V5 Token ID
        v4TokenIds[75] = 49_000_000_045; // Original V4 Token ID
        v5TokenIds[76] = 49_000_000_046; // Minted V5 Token ID
        v4TokenIds[76] = 49_000_000_046; // Original V4 Token ID
        v5TokenIds[77] = 49_000_000_047; // Minted V5 Token ID
        v4TokenIds[77] = 49_000_000_047; // Original V4 Token ID
        v5TokenIds[78] = 49_000_000_048; // Minted V5 Token ID
        v4TokenIds[78] = 49_000_000_048; // Original V4 Token ID
        v5TokenIds[79] = 49_000_000_049; // Minted V5 Token ID
        v4TokenIds[79] = 49_000_000_049; // Original V4 Token ID
        v5TokenIds[80] = 49_000_000_050; // Minted V5 Token ID
        v4TokenIds[80] = 49_000_000_050; // Original V4 Token ID
        v5TokenIds[81] = 49_000_000_051; // Minted V5 Token ID
        v4TokenIds[81] = 49_000_000_051; // Original V4 Token ID
        v5TokenIds[82] = 49_000_000_052; // Minted V5 Token ID
        v4TokenIds[82] = 49_000_000_052; // Original V4 Token ID
        v5TokenIds[83] = 49_000_000_053; // Minted V5 Token ID
        v4TokenIds[83] = 49_000_000_053; // Original V4 Token ID
        v5TokenIds[84] = 49_000_000_054; // Minted V5 Token ID
        v4TokenIds[84] = 49_000_000_054; // Original V4 Token ID
        v5TokenIds[85] = 49_000_000_055; // Minted V5 Token ID
        v4TokenIds[85] = 49_000_000_055; // Original V4 Token ID
        v5TokenIds[86] = 49_000_000_056; // Minted V5 Token ID
        v4TokenIds[86] = 49_000_000_056; // Original V4 Token ID
        v5TokenIds[87] = 49_000_000_057; // Minted V5 Token ID
        v4TokenIds[87] = 49_000_000_057; // Original V4 Token ID
        v5TokenIds[88] = 49_000_000_058; // Minted V5 Token ID
        v4TokenIds[88] = 49_000_000_058; // Original V4 Token ID
        v5TokenIds[89] = 49_000_000_059; // Minted V5 Token ID
        v4TokenIds[89] = 49_000_000_059; // Original V4 Token ID
        v5TokenIds[90] = 49_000_000_060; // Minted V5 Token ID
        v4TokenIds[90] = 49_000_000_060; // Original V4 Token ID
        v5TokenIds[91] = 49_000_000_061; // Minted V5 Token ID
        v4TokenIds[91] = 49_000_000_061; // Original V4 Token ID
        v5TokenIds[92] = 49_000_000_062; // Minted V5 Token ID
        v4TokenIds[92] = 49_000_000_062; // Original V4 Token ID
        v5TokenIds[93] = 49_000_000_063; // Minted V5 Token ID
        v4TokenIds[93] = 49_000_000_063; // Original V4 Token ID
        v5TokenIds[94] = 49_000_000_064; // Minted V5 Token ID
        v4TokenIds[94] = 49_000_000_064; // Original V4 Token ID
        v5TokenIds[95] = 49_000_000_065; // Minted V5 Token ID
        v4TokenIds[95] = 49_000_000_065; // Original V4 Token ID
        v5TokenIds[96] = 49_000_000_066; // Minted V5 Token ID
        v4TokenIds[96] = 49_000_000_066; // Original V4 Token ID
        v5TokenIds[97] = 49_000_000_067; // Minted V5 Token ID
        v4TokenIds[97] = 49_000_000_067; // Original V4 Token ID
        v5TokenIds[98] = 49_000_000_068; // Minted V5 Token ID
        v4TokenIds[98] = 49_000_000_068; // Original V4 Token ID
        v5TokenIds[99] = 49_000_000_069; // Minted V5 Token ID
        v4TokenIds[99] = 49_000_000_069; // Original V4 Token ID
        v5TokenIds[100] = 49_000_000_070; // Minted V5 Token ID
        v4TokenIds[100] = 49_000_000_070; // Original V4 Token ID
        v5TokenIds[101] = 49_000_000_071; // Minted V5 Token ID
        v4TokenIds[101] = 49_000_000_071; // Original V4 Token ID
        v5TokenIds[102] = 49_000_000_072; // Minted V5 Token ID
        v4TokenIds[102] = 49_000_000_072; // Original V4 Token ID
        v5TokenIds[103] = 49_000_000_073; // Minted V5 Token ID
        v4TokenIds[103] = 49_000_000_073; // Original V4 Token ID
        v5TokenIds[104] = 49_000_000_074; // Minted V5 Token ID
        v4TokenIds[104] = 49_000_000_074; // Original V4 Token ID
        v5TokenIds[105] = 49_000_000_075; // Minted V5 Token ID
        v4TokenIds[105] = 49_000_000_075; // Original V4 Token ID
        v5TokenIds[106] = 49_000_000_076; // Minted V5 Token ID
        v4TokenIds[106] = 49_000_000_076; // Original V4 Token ID
        v5TokenIds[107] = 49_000_000_077; // Minted V5 Token ID
        v4TokenIds[107] = 49_000_000_077; // Original V4 Token ID
        v5TokenIds[108] = 49_000_000_078; // Minted V5 Token ID
        v4TokenIds[108] = 49_000_000_078; // Original V4 Token ID
        v5TokenIds[109] = 49_000_000_079; // Minted V5 Token ID
        v4TokenIds[109] = 49_000_000_079; // Original V4 Token ID
        v5TokenIds[110] = 49_000_000_080; // Minted V5 Token ID
        v4TokenIds[110] = 49_000_000_080; // Original V4 Token ID
        v5TokenIds[111] = 49_000_000_081; // Minted V5 Token ID
        v4TokenIds[111] = 49_000_000_081; // Original V4 Token ID
        v5TokenIds[112] = 49_000_000_082; // Minted V5 Token ID
        v4TokenIds[112] = 49_000_000_082; // Original V4 Token ID
        v5TokenIds[113] = 49_000_000_083; // Minted V5 Token ID
        v4TokenIds[113] = 49_000_000_083; // Original V4 Token ID
        v5TokenIds[114] = 49_000_000_084; // Minted V5 Token ID
        v4TokenIds[114] = 49_000_000_084; // Original V4 Token ID
        v5TokenIds[115] = 49_000_000_085; // Minted V5 Token ID
        v4TokenIds[115] = 49_000_000_085; // Original V4 Token ID
        v5TokenIds[116] = 49_000_000_086; // Minted V5 Token ID
        v4TokenIds[116] = 49_000_000_086; // Original V4 Token ID
        v5TokenIds[117] = 49_000_000_087; // Minted V5 Token ID
        v4TokenIds[117] = 49_000_000_087; // Original V4 Token ID
        v5TokenIds[118] = 49_000_000_088; // Minted V5 Token ID
        v4TokenIds[118] = 49_000_000_088; // Original V4 Token ID
        v5TokenIds[119] = 49_000_000_089; // Minted V5 Token ID
        v4TokenIds[119] = 49_000_000_089; // Original V4 Token ID
        v5TokenIds[120] = 49_000_000_090; // Minted V5 Token ID
        v4TokenIds[120] = 49_000_000_090; // Original V4 Token ID
        v5TokenIds[121] = 49_000_000_091; // Minted V5 Token ID
        v4TokenIds[121] = 49_000_000_091; // Original V4 Token ID
        v5TokenIds[122] = 49_000_000_092; // Minted V5 Token ID
        v4TokenIds[122] = 49_000_000_092; // Original V4 Token ID
        v5TokenIds[123] = 49_000_000_093; // Minted V5 Token ID
        v4TokenIds[123] = 49_000_000_093; // Original V4 Token ID
        v5TokenIds[124] = 49_000_000_094; // Minted V5 Token ID
        v4TokenIds[124] = 49_000_000_094; // Original V4 Token ID
        v5TokenIds[125] = 49_000_000_095; // Minted V5 Token ID
        v4TokenIds[125] = 49_000_000_095; // Original V4 Token ID
        v5TokenIds[126] = 49_000_000_096; // Minted V5 Token ID
        v4TokenIds[126] = 49_000_000_096; // Original V4 Token ID
        v5TokenIds[127] = 49_000_000_097; // Minted V5 Token ID
        v4TokenIds[127] = 49_000_000_097; // Original V4 Token ID
        v5TokenIds[128] = 49_000_000_098; // Minted V5 Token ID
        v4TokenIds[128] = 49_000_000_098; // Original V4 Token ID
        v5TokenIds[129] = 49_000_000_099; // Minted V5 Token ID
        v4TokenIds[129] = 49_000_000_099; // Original V4 Token ID
        v5TokenIds[130] = 49_000_000_100; // Minted V5 Token ID
        v4TokenIds[130] = 49_000_000_100; // Original V4 Token ID
        v5TokenIds[131] = 49_000_000_101; // Minted V5 Token ID
        v4TokenIds[131] = 49_000_000_101; // Original V4 Token ID
        v5TokenIds[132] = 49_000_000_102; // Minted V5 Token ID
        v4TokenIds[132] = 49_000_000_102; // Original V4 Token ID
        v5TokenIds[133] = 49_000_000_103; // Minted V5 Token ID
        v4TokenIds[133] = 49_000_000_103; // Original V4 Token ID
        v5TokenIds[134] = 49_000_000_104; // Minted V5 Token ID
        v4TokenIds[134] = 49_000_000_104; // Original V4 Token ID
        v5TokenIds[135] = 49_000_000_105; // Minted V5 Token ID
        v4TokenIds[135] = 49_000_000_105; // Original V4 Token ID
        v5TokenIds[136] = 49_000_000_106; // Minted V5 Token ID
        v4TokenIds[136] = 49_000_000_106; // Original V4 Token ID
        v5TokenIds[137] = 49_000_000_107; // Minted V5 Token ID
        v4TokenIds[137] = 49_000_000_107; // Original V4 Token ID
        v5TokenIds[138] = 49_000_000_108; // Minted V5 Token ID
        v4TokenIds[138] = 49_000_000_108; // Original V4 Token ID
        v5TokenIds[139] = 49_000_000_109; // Minted V5 Token ID
        v4TokenIds[139] = 49_000_000_109; // Original V4 Token ID
        v5TokenIds[140] = 49_000_000_110; // Minted V5 Token ID
        v4TokenIds[140] = 49_000_000_110; // Original V4 Token ID
        v5TokenIds[141] = 49_000_000_111; // Minted V5 Token ID
        v4TokenIds[141] = 49_000_000_111; // Original V4 Token ID
        v5TokenIds[142] = 49_000_000_112; // Minted V5 Token ID
        v4TokenIds[142] = 49_000_000_112; // Original V4 Token ID
        v5TokenIds[143] = 49_000_000_113; // Minted V5 Token ID
        v4TokenIds[143] = 49_000_000_113; // Original V4 Token ID
        v5TokenIds[144] = 49_000_000_114; // Minted V5 Token ID
        v4TokenIds[144] = 49_000_000_114; // Original V4 Token ID
        v5TokenIds[145] = 49_000_000_115; // Minted V5 Token ID
        v4TokenIds[145] = 49_000_000_115; // Original V4 Token ID
        v5TokenIds[146] = 49_000_000_116; // Minted V5 Token ID
        v4TokenIds[146] = 49_000_000_116; // Original V4 Token ID
        v5TokenIds[147] = 49_000_000_117; // Minted V5 Token ID
        v4TokenIds[147] = 49_000_000_117; // Original V4 Token ID
        v5TokenIds[148] = 49_000_000_118; // Minted V5 Token ID
        v4TokenIds[148] = 49_000_000_118; // Original V4 Token ID
        v5TokenIds[149] = 49_000_000_119; // Minted V5 Token ID
        v4TokenIds[149] = 49_000_000_119; // Original V4 Token ID
        v5TokenIds[150] = 49_000_000_120; // Minted V5 Token ID
        v4TokenIds[150] = 49_000_000_120; // Original V4 Token ID
        v5TokenIds[151] = 49_000_000_121; // Minted V5 Token ID
        v4TokenIds[151] = 49_000_000_121; // Original V4 Token ID
        v5TokenIds[152] = 49_000_000_122; // Minted V5 Token ID
        v4TokenIds[152] = 49_000_000_122; // Original V4 Token ID
        v5TokenIds[153] = 49_000_000_123; // Minted V5 Token ID
        v4TokenIds[153] = 49_000_000_123; // Original V4 Token ID
        v5TokenIds[154] = 49_000_000_124; // Minted V5 Token ID
        v4TokenIds[154] = 49_000_000_124; // Original V4 Token ID
        v5TokenIds[155] = 49_000_000_125; // Minted V5 Token ID
        v4TokenIds[155] = 49_000_000_125; // Original V4 Token ID
        v5TokenIds[156] = 49_000_000_126; // Minted V5 Token ID
        v4TokenIds[156] = 49_000_000_126; // Original V4 Token ID
        v5TokenIds[157] = 49_000_000_127; // Minted V5 Token ID
        v4TokenIds[157] = 49_000_000_127; // Original V4 Token ID
        v5TokenIds[158] = 49_000_000_128; // Minted V5 Token ID
        v4TokenIds[158] = 49_000_000_128; // Original V4 Token ID
        v5TokenIds[159] = 49_000_000_129; // Minted V5 Token ID
        v4TokenIds[159] = 49_000_000_129; // Original V4 Token ID
        v5TokenIds[160] = 49_000_000_130; // Minted V5 Token ID
        v4TokenIds[160] = 49_000_000_130; // Original V4 Token ID
        v5TokenIds[161] = 49_000_000_131; // Minted V5 Token ID
        v4TokenIds[161] = 49_000_000_131; // Original V4 Token ID
        v5TokenIds[162] = 49_000_000_132; // Minted V5 Token ID
        v4TokenIds[162] = 49_000_000_132; // Original V4 Token ID
        v5TokenIds[163] = 49_000_000_133; // Minted V5 Token ID
        v4TokenIds[163] = 49_000_000_133; // Original V4 Token ID
        v5TokenIds[164] = 49_000_000_134; // Minted V5 Token ID
        v4TokenIds[164] = 49_000_000_134; // Original V4 Token ID
        v5TokenIds[165] = 49_000_000_135; // Minted V5 Token ID
        v4TokenIds[165] = 49_000_000_135; // Original V4 Token ID
        v5TokenIds[166] = 49_000_000_136; // Minted V5 Token ID
        v4TokenIds[166] = 49_000_000_136; // Original V4 Token ID
        v5TokenIds[167] = 49_000_000_137; // Minted V5 Token ID
        v4TokenIds[167] = 49_000_000_137; // Original V4 Token ID
        v5TokenIds[168] = 49_000_000_138; // Minted V5 Token ID
        v4TokenIds[168] = 49_000_000_138; // Original V4 Token ID
        v5TokenIds[169] = 49_000_000_139; // Minted V5 Token ID
        v4TokenIds[169] = 49_000_000_139; // Original V4 Token ID
        v5TokenIds[170] = 49_000_000_140; // Minted V5 Token ID
        v4TokenIds[170] = 49_000_000_140; // Original V4 Token ID
        v5TokenIds[171] = 49_000_000_141; // Minted V5 Token ID
        v4TokenIds[171] = 49_000_000_141; // Original V4 Token ID
        v5TokenIds[172] = 49_000_000_142; // Minted V5 Token ID
        v4TokenIds[172] = 49_000_000_142; // Original V4 Token ID
        v5TokenIds[173] = 49_000_000_143; // Minted V5 Token ID
        v4TokenIds[173] = 49_000_000_143; // Original V4 Token ID
        v5TokenIds[174] = 49_000_000_144; // Minted V5 Token ID
        v4TokenIds[174] = 49_000_000_144; // Original V4 Token ID
        v5TokenIds[175] = 49_000_000_145; // Minted V5 Token ID
        v4TokenIds[175] = 49_000_000_145; // Original V4 Token ID

        uint256 successfulTransfers = 0;

        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 v5TokenId = v5TokenIds[i];
            uint256 v4TokenId = v4TokenIds[i];

            // Verify V4 ownership using the original V4 token ID
            // This will revert if the token doesn't exist, which indicates a data issue
            address v4Owner = v4Hook.ownerOf(v4TokenId);
            address expectedOwner = transferOwners[i];

            // If V4 owner is the main resolver, this token is being worn/used and shouldn't be in unused assets
            // contract
            require(
                v4Owner != address(v4ResolverAddress),
                "Token owned by main resolver in V4 - should not be in unused assets contract"
            );

            // Special case: If V4 owner is the fallback resolver BUT expected owner is NOT a resolver,
            // this is valid - the asset is being worn in V4 but we're minting directly to the actual owner in V5
            // raw.json already accounts for this and has the correct owner
            if (v4Owner == address(fallbackV4ResolverAddress)) {
                // Allow if expected owner is not a resolver (we're minting directly to owner in V5)
                require(
                    expectedOwner != address(v4ResolverAddress) && expectedOwner != address(fallbackV4ResolverAddress),
                    "Token owned by fallback resolver in V4 but expected owner is also a resolver - should not be in unused assets contract"
                );
                // Skip ownership verification in this case - we trust raw.json
            } else {
                // For all other cases, verify V4 owner matches expected owner
                require(v4Owner == expectedOwner, "V4/V5 ownership mismatch for token");
            }

            // Verify this contract owns the V5 token before transferring
            require(hook.ownerOf(v5TokenId) == address(this), "Contract does not own token");

            // Transfer using the minted V5 token ID
            IERC721(address(hook)).safeTransferFrom(address(this), transferOwners[i], v5TokenId);
            successfulTransfers++;
        }

        // Verify all expected items were transferred
        require(successfulTransfers == transferOwners.length, "Not all items were transferred");

        // Final verification: Ensure this contract no longer owns any tokens
        // This ensures all transfers completed successfully and no tokens were left behind
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");

        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)

        // // Collect unique owners
        // address[] memory uniqueOwners = new address[](3);

        // uniqueOwners[0] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        // uniqueOwners[1] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        // uniqueOwners[2] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](7);

        // uniqueTierIds[0] = 5;
        // uniqueTierIds[1] = 19;
        // uniqueTierIds[2] = 31;
        // uniqueTierIds[3] = 32;
        // uniqueTierIds[4] = 39;
        // uniqueTierIds[5] = 47;
        // uniqueTierIds[6] = 49;

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
