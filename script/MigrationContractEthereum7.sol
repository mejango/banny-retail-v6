// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

/// @notice Migration contract for Ethereum to handle standalone outfits and backgrounds
/// that are not worn/used by any banny. These assets are minted to this contract
/// and then transferred directly to their owners.
contract MigrationContractEthereum7 {
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

        // Ethereum migration - Standalone outfits and backgrounds (140 items)
        // These are assets that are NOT being worn/used by any banny

        // Assets are already minted to this contract by the deployer
        // V5 token IDs are calculated based on mint order (continuing from previous chunks)
        // V4 token IDs are the original token IDs from V4

        // Generate token IDs - store both V5 minted token IDs and original V4 token IDs
        uint256[] memory v5TokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        v5TokenIds[0] = 5_000_000_007; // Minted V5 Token ID
        v4TokenIds[0] = 5_000_000_003; // Original V4 Token ID
        v5TokenIds[1] = 5_000_000_008; // Minted V5 Token ID
        v4TokenIds[1] = 5_000_000_007; // Original V4 Token ID
        v5TokenIds[2] = 6_000_000_009; // Minted V5 Token ID
        v4TokenIds[2] = 6_000_000_005; // Original V4 Token ID
        v5TokenIds[3] = 6_000_000_010; // Minted V5 Token ID
        v4TokenIds[3] = 6_000_000_006; // Original V4 Token ID
        v5TokenIds[4] = 6_000_000_011; // Minted V5 Token ID
        v4TokenIds[4] = 6_000_000_007; // Original V4 Token ID
        v5TokenIds[5] = 6_000_000_012; // Minted V5 Token ID
        v4TokenIds[5] = 6_000_000_008; // Original V4 Token ID
        v5TokenIds[6] = 6_000_000_013; // Minted V5 Token ID
        v4TokenIds[6] = 6_000_000_009; // Original V4 Token ID
        v5TokenIds[7] = 10_000_000_007; // Minted V5 Token ID
        v4TokenIds[7] = 10_000_000_004; // Original V4 Token ID
        v5TokenIds[8] = 10_000_000_008; // Minted V5 Token ID
        v4TokenIds[8] = 10_000_000_008; // Original V4 Token ID
        v5TokenIds[9] = 10_000_000_009; // Minted V5 Token ID
        v4TokenIds[9] = 10_000_000_009; // Original V4 Token ID
        v5TokenIds[10] = 10_000_000_010; // Minted V5 Token ID
        v4TokenIds[10] = 10_000_000_010; // Original V4 Token ID
        v5TokenIds[11] = 10_000_000_011; // Minted V5 Token ID
        v4TokenIds[11] = 10_000_000_011; // Original V4 Token ID
        v5TokenIds[12] = 10_000_000_012; // Minted V5 Token ID
        v4TokenIds[12] = 10_000_000_013; // Original V4 Token ID
        v5TokenIds[13] = 10_000_000_013; // Minted V5 Token ID
        v4TokenIds[13] = 10_000_000_014; // Original V4 Token ID
        v5TokenIds[14] = 11_000_000_001; // Minted V5 Token ID
        v4TokenIds[14] = 11_000_000_001; // Original V4 Token ID
        v5TokenIds[15] = 13_000_000_003; // Minted V5 Token ID
        v4TokenIds[15] = 13_000_000_002; // Original V4 Token ID
        v5TokenIds[16] = 13_000_000_004; // Minted V5 Token ID
        v4TokenIds[16] = 13_000_000_004; // Original V4 Token ID
        v5TokenIds[17] = 14_000_000_004; // Minted V5 Token ID
        v4TokenIds[17] = 14_000_000_002; // Original V4 Token ID
        v5TokenIds[18] = 14_000_000_005; // Minted V5 Token ID
        v4TokenIds[18] = 14_000_000_004; // Original V4 Token ID
        v5TokenIds[19] = 14_000_000_006; // Minted V5 Token ID
        v4TokenIds[19] = 14_000_000_006; // Original V4 Token ID
        v5TokenIds[20] = 17_000_000_003; // Minted V5 Token ID
        v4TokenIds[20] = 17_000_000_003; // Original V4 Token ID
        v5TokenIds[21] = 17_000_000_004; // Minted V5 Token ID
        v4TokenIds[21] = 17_000_000_004; // Original V4 Token ID
        v5TokenIds[22] = 17_000_000_005; // Minted V5 Token ID
        v4TokenIds[22] = 17_000_000_005; // Original V4 Token ID
        v5TokenIds[23] = 19_000_000_016; // Minted V5 Token ID
        v4TokenIds[23] = 19_000_000_001; // Original V4 Token ID
        v5TokenIds[24] = 19_000_000_017; // Minted V5 Token ID
        v4TokenIds[24] = 19_000_000_003; // Original V4 Token ID
        v5TokenIds[25] = 19_000_000_018; // Minted V5 Token ID
        v4TokenIds[25] = 19_000_000_006; // Original V4 Token ID
        v5TokenIds[26] = 19_000_000_019; // Minted V5 Token ID
        v4TokenIds[26] = 19_000_000_007; // Original V4 Token ID
        v5TokenIds[27] = 19_000_000_020; // Minted V5 Token ID
        v4TokenIds[27] = 19_000_000_010; // Original V4 Token ID
        v5TokenIds[28] = 19_000_000_021; // Minted V5 Token ID
        v4TokenIds[28] = 19_000_000_014; // Original V4 Token ID
        v5TokenIds[29] = 19_000_000_022; // Minted V5 Token ID
        v4TokenIds[29] = 19_000_000_022; // Original V4 Token ID
        v5TokenIds[30] = 20_000_000_003; // Minted V5 Token ID
        v4TokenIds[30] = 20_000_000_002; // Original V4 Token ID
        v5TokenIds[31] = 20_000_000_004; // Minted V5 Token ID
        v4TokenIds[31] = 20_000_000_003; // Original V4 Token ID
        v5TokenIds[32] = 20_000_000_005; // Minted V5 Token ID
        v4TokenIds[32] = 20_000_000_004; // Original V4 Token ID
        v5TokenIds[33] = 20_000_000_006; // Minted V5 Token ID
        v4TokenIds[33] = 20_000_000_005; // Original V4 Token ID
        v5TokenIds[34] = 20_000_000_007; // Minted V5 Token ID
        v4TokenIds[34] = 20_000_000_006; // Original V4 Token ID
        v5TokenIds[35] = 20_000_000_008; // Minted V5 Token ID
        v4TokenIds[35] = 20_000_000_007; // Original V4 Token ID
        v5TokenIds[36] = 21_000_000_002; // Minted V5 Token ID
        v4TokenIds[36] = 21_000_000_002; // Original V4 Token ID
        v5TokenIds[37] = 23_000_000_007; // Minted V5 Token ID
        v4TokenIds[37] = 23_000_000_006; // Original V4 Token ID
        v5TokenIds[38] = 23_000_000_008; // Minted V5 Token ID
        v4TokenIds[38] = 23_000_000_008; // Original V4 Token ID
        v5TokenIds[39] = 25_000_000_010; // Minted V5 Token ID
        v4TokenIds[39] = 25_000_000_001; // Original V4 Token ID
        v5TokenIds[40] = 25_000_000_011; // Minted V5 Token ID
        v4TokenIds[40] = 25_000_000_004; // Original V4 Token ID
        v5TokenIds[41] = 25_000_000_012; // Minted V5 Token ID
        v4TokenIds[41] = 25_000_000_012; // Original V4 Token ID
        v5TokenIds[42] = 26_000_000_006; // Minted V5 Token ID
        v4TokenIds[42] = 26_000_000_006; // Original V4 Token ID
        v5TokenIds[43] = 26_000_000_007; // Minted V5 Token ID
        v4TokenIds[43] = 26_000_000_007; // Original V4 Token ID
        v5TokenIds[44] = 28_000_000_003; // Minted V5 Token ID
        v4TokenIds[44] = 28_000_000_001; // Original V4 Token ID
        v5TokenIds[45] = 28_000_000_004; // Minted V5 Token ID
        v4TokenIds[45] = 28_000_000_003; // Original V4 Token ID
        v5TokenIds[46] = 28_000_000_005; // Minted V5 Token ID
        v4TokenIds[46] = 28_000_000_004; // Original V4 Token ID
        v5TokenIds[47] = 28_000_000_006; // Minted V5 Token ID
        v4TokenIds[47] = 28_000_000_005; // Original V4 Token ID
        v5TokenIds[48] = 28_000_000_007; // Minted V5 Token ID
        v4TokenIds[48] = 28_000_000_006; // Original V4 Token ID
        v5TokenIds[49] = 28_000_000_008; // Minted V5 Token ID
        v4TokenIds[49] = 28_000_000_007; // Original V4 Token ID
        v5TokenIds[50] = 28_000_000_009; // Minted V5 Token ID
        v4TokenIds[50] = 28_000_000_009; // Original V4 Token ID
        v5TokenIds[51] = 29_000_000_003; // Minted V5 Token ID
        v4TokenIds[51] = 29_000_000_001; // Original V4 Token ID
        v5TokenIds[52] = 31_000_000_009; // Minted V5 Token ID
        v4TokenIds[52] = 31_000_000_001; // Original V4 Token ID
        v5TokenIds[53] = 31_000_000_010; // Minted V5 Token ID
        v4TokenIds[53] = 31_000_000_004; // Original V4 Token ID
        v5TokenIds[54] = 31_000_000_011; // Minted V5 Token ID
        v4TokenIds[54] = 31_000_000_005; // Original V4 Token ID
        v5TokenIds[55] = 31_000_000_012; // Minted V5 Token ID
        v4TokenIds[55] = 31_000_000_008; // Original V4 Token ID
        v5TokenIds[56] = 31_000_000_013; // Minted V5 Token ID
        v4TokenIds[56] = 31_000_000_012; // Original V4 Token ID
        v5TokenIds[57] = 32_000_000_004; // Minted V5 Token ID
        v4TokenIds[57] = 32_000_000_004; // Original V4 Token ID
        v5TokenIds[58] = 32_000_000_005; // Minted V5 Token ID
        v4TokenIds[58] = 32_000_000_005; // Original V4 Token ID
        v5TokenIds[59] = 33_000_000_002; // Minted V5 Token ID
        v4TokenIds[59] = 33_000_000_002; // Original V4 Token ID
        v5TokenIds[60] = 35_000_000_007; // Minted V5 Token ID
        v4TokenIds[60] = 35_000_000_005; // Original V4 Token ID
        v5TokenIds[61] = 35_000_000_008; // Minted V5 Token ID
        v4TokenIds[61] = 35_000_000_008; // Original V4 Token ID
        v5TokenIds[62] = 35_000_000_009; // Minted V5 Token ID
        v4TokenIds[62] = 35_000_000_009; // Original V4 Token ID
        v5TokenIds[63] = 37_000_000_003; // Minted V5 Token ID
        v4TokenIds[63] = 37_000_000_002; // Original V4 Token ID
        v5TokenIds[64] = 37_000_000_004; // Minted V5 Token ID
        v4TokenIds[64] = 37_000_000_004; // Original V4 Token ID
        v5TokenIds[65] = 39_000_000_004; // Minted V5 Token ID
        v4TokenIds[65] = 39_000_000_004; // Original V4 Token ID
        v5TokenIds[66] = 40_000_000_002; // Minted V5 Token ID
        v4TokenIds[66] = 40_000_000_002; // Original V4 Token ID
        v5TokenIds[67] = 40_000_000_003; // Minted V5 Token ID
        v4TokenIds[67] = 40_000_000_003; // Original V4 Token ID
        v5TokenIds[68] = 41_000_000_005; // Minted V5 Token ID
        v4TokenIds[68] = 41_000_000_005; // Original V4 Token ID
        v5TokenIds[69] = 42_000_000_004; // Minted V5 Token ID
        v4TokenIds[69] = 42_000_000_001; // Original V4 Token ID
        v5TokenIds[70] = 42_000_000_005; // Minted V5 Token ID
        v4TokenIds[70] = 42_000_000_003; // Original V4 Token ID
        v5TokenIds[71] = 42_000_000_006; // Minted V5 Token ID
        v4TokenIds[71] = 42_000_000_005; // Original V4 Token ID
        v5TokenIds[72] = 42_000_000_007; // Minted V5 Token ID
        v4TokenIds[72] = 42_000_000_006; // Original V4 Token ID
        v5TokenIds[73] = 42_000_000_008; // Minted V5 Token ID
        v4TokenIds[73] = 42_000_000_008; // Original V4 Token ID
        v5TokenIds[74] = 42_000_000_009; // Minted V5 Token ID
        v4TokenIds[74] = 42_000_000_009; // Original V4 Token ID
        v5TokenIds[75] = 42_000_000_010; // Minted V5 Token ID
        v4TokenIds[75] = 42_000_000_010; // Original V4 Token ID
        v5TokenIds[76] = 42_000_000_011; // Minted V5 Token ID
        v4TokenIds[76] = 42_000_000_011; // Original V4 Token ID
        v5TokenIds[77] = 42_000_000_012; // Minted V5 Token ID
        v4TokenIds[77] = 42_000_000_012; // Original V4 Token ID
        v5TokenIds[78] = 42_000_000_013; // Minted V5 Token ID
        v4TokenIds[78] = 42_000_000_013; // Original V4 Token ID
        v5TokenIds[79] = 42_000_000_014; // Minted V5 Token ID
        v4TokenIds[79] = 42_000_000_014; // Original V4 Token ID
        v5TokenIds[80] = 42_000_000_015; // Minted V5 Token ID
        v4TokenIds[80] = 42_000_000_015; // Original V4 Token ID
        v5TokenIds[81] = 42_000_000_016; // Minted V5 Token ID
        v4TokenIds[81] = 42_000_000_016; // Original V4 Token ID
        v5TokenIds[82] = 42_000_000_017; // Minted V5 Token ID
        v4TokenIds[82] = 42_000_000_017; // Original V4 Token ID
        v5TokenIds[83] = 42_000_000_018; // Minted V5 Token ID
        v4TokenIds[83] = 42_000_000_018; // Original V4 Token ID
        v5TokenIds[84] = 42_000_000_019; // Minted V5 Token ID
        v4TokenIds[84] = 42_000_000_019; // Original V4 Token ID
        v5TokenIds[85] = 43_000_000_008; // Minted V5 Token ID
        v4TokenIds[85] = 43_000_000_001; // Original V4 Token ID
        v5TokenIds[86] = 43_000_000_009; // Minted V5 Token ID
        v4TokenIds[86] = 43_000_000_002; // Original V4 Token ID
        v5TokenIds[87] = 43_000_000_010; // Minted V5 Token ID
        v4TokenIds[87] = 43_000_000_004; // Original V4 Token ID
        v5TokenIds[88] = 43_000_000_011; // Minted V5 Token ID
        v4TokenIds[88] = 43_000_000_009; // Original V4 Token ID
        v5TokenIds[89] = 43_000_000_012; // Minted V5 Token ID
        v4TokenIds[89] = 43_000_000_010; // Original V4 Token ID
        v5TokenIds[90] = 43_000_000_013; // Minted V5 Token ID
        v4TokenIds[90] = 43_000_000_011; // Original V4 Token ID
        v5TokenIds[91] = 43_000_000_014; // Minted V5 Token ID
        v4TokenIds[91] = 43_000_000_012; // Original V4 Token ID
        v5TokenIds[92] = 43_000_000_015; // Minted V5 Token ID
        v4TokenIds[92] = 43_000_000_013; // Original V4 Token ID
        v5TokenIds[93] = 43_000_000_016; // Minted V5 Token ID
        v4TokenIds[93] = 43_000_000_014; // Original V4 Token ID
        v5TokenIds[94] = 43_000_000_017; // Minted V5 Token ID
        v4TokenIds[94] = 43_000_000_015; // Original V4 Token ID
        v5TokenIds[95] = 43_000_000_018; // Minted V5 Token ID
        v4TokenIds[95] = 43_000_000_016; // Original V4 Token ID
        v5TokenIds[96] = 44_000_000_006; // Minted V5 Token ID
        v4TokenIds[96] = 44_000_000_002; // Original V4 Token ID
        v5TokenIds[97] = 44_000_000_007; // Minted V5 Token ID
        v4TokenIds[97] = 44_000_000_005; // Original V4 Token ID
        v5TokenIds[98] = 44_000_000_008; // Minted V5 Token ID
        v4TokenIds[98] = 44_000_000_006; // Original V4 Token ID
        v5TokenIds[99] = 44_000_000_009; // Minted V5 Token ID
        v4TokenIds[99] = 44_000_000_007; // Original V4 Token ID
        v5TokenIds[100] = 44_000_000_010; // Minted V5 Token ID
        v4TokenIds[100] = 44_000_000_010; // Original V4 Token ID
        v5TokenIds[101] = 44_000_000_011; // Minted V5 Token ID
        v4TokenIds[101] = 44_000_000_011; // Original V4 Token ID
        v5TokenIds[102] = 44_000_000_012; // Minted V5 Token ID
        v4TokenIds[102] = 44_000_000_012; // Original V4 Token ID
        v5TokenIds[103] = 44_000_000_013; // Minted V5 Token ID
        v4TokenIds[103] = 44_000_000_013; // Original V4 Token ID
        v5TokenIds[104] = 44_000_000_014; // Minted V5 Token ID
        v4TokenIds[104] = 44_000_000_014; // Original V4 Token ID
        v5TokenIds[105] = 44_000_000_015; // Minted V5 Token ID
        v4TokenIds[105] = 44_000_000_015; // Original V4 Token ID
        v5TokenIds[106] = 44_000_000_016; // Minted V5 Token ID
        v4TokenIds[106] = 44_000_000_016; // Original V4 Token ID
        v5TokenIds[107] = 44_000_000_017; // Minted V5 Token ID
        v4TokenIds[107] = 44_000_000_017; // Original V4 Token ID
        v5TokenIds[108] = 44_000_000_018; // Minted V5 Token ID
        v4TokenIds[108] = 44_000_000_018; // Original V4 Token ID
        v5TokenIds[109] = 44_000_000_019; // Minted V5 Token ID
        v4TokenIds[109] = 44_000_000_019; // Original V4 Token ID
        v5TokenIds[110] = 44_000_000_020; // Minted V5 Token ID
        v4TokenIds[110] = 44_000_000_020; // Original V4 Token ID
        v5TokenIds[111] = 44_000_000_021; // Minted V5 Token ID
        v4TokenIds[111] = 44_000_000_021; // Original V4 Token ID
        v5TokenIds[112] = 44_000_000_022; // Minted V5 Token ID
        v4TokenIds[112] = 44_000_000_022; // Original V4 Token ID
        v5TokenIds[113] = 44_000_000_023; // Minted V5 Token ID
        v4TokenIds[113] = 44_000_000_023; // Original V4 Token ID
        v5TokenIds[114] = 44_000_000_024; // Minted V5 Token ID
        v4TokenIds[114] = 44_000_000_024; // Original V4 Token ID
        v5TokenIds[115] = 44_000_000_025; // Minted V5 Token ID
        v4TokenIds[115] = 44_000_000_025; // Original V4 Token ID
        v5TokenIds[116] = 44_000_000_026; // Minted V5 Token ID
        v4TokenIds[116] = 44_000_000_026; // Original V4 Token ID
        v5TokenIds[117] = 44_000_000_027; // Minted V5 Token ID
        v4TokenIds[117] = 44_000_000_027; // Original V4 Token ID
        v5TokenIds[118] = 44_000_000_028; // Minted V5 Token ID
        v4TokenIds[118] = 44_000_000_028; // Original V4 Token ID
        v5TokenIds[119] = 44_000_000_029; // Minted V5 Token ID
        v4TokenIds[119] = 44_000_000_029; // Original V4 Token ID
        v5TokenIds[120] = 44_000_000_030; // Minted V5 Token ID
        v4TokenIds[120] = 44_000_000_030; // Original V4 Token ID
        v5TokenIds[121] = 44_000_000_031; // Minted V5 Token ID
        v4TokenIds[121] = 44_000_000_031; // Original V4 Token ID
        v5TokenIds[122] = 44_000_000_032; // Minted V5 Token ID
        v4TokenIds[122] = 44_000_000_032; // Original V4 Token ID
        v5TokenIds[123] = 44_000_000_033; // Minted V5 Token ID
        v4TokenIds[123] = 44_000_000_033; // Original V4 Token ID
        v5TokenIds[124] = 44_000_000_034; // Minted V5 Token ID
        v4TokenIds[124] = 44_000_000_034; // Original V4 Token ID
        v5TokenIds[125] = 47_000_000_003; // Minted V5 Token ID
        v4TokenIds[125] = 47_000_000_001; // Original V4 Token ID
        v5TokenIds[126] = 47_000_000_004; // Minted V5 Token ID
        v4TokenIds[126] = 47_000_000_002; // Original V4 Token ID
        v5TokenIds[127] = 47_000_000_005; // Minted V5 Token ID
        v4TokenIds[127] = 47_000_000_004; // Original V4 Token ID
        v5TokenIds[128] = 47_000_000_006; // Minted V5 Token ID
        v4TokenIds[128] = 47_000_000_006; // Original V4 Token ID
        v5TokenIds[129] = 47_000_000_007; // Minted V5 Token ID
        v4TokenIds[129] = 47_000_000_007; // Original V4 Token ID
        v5TokenIds[130] = 47_000_000_008; // Minted V5 Token ID
        v4TokenIds[130] = 47_000_000_008; // Original V4 Token ID
        v5TokenIds[131] = 47_000_000_009; // Minted V5 Token ID
        v4TokenIds[131] = 47_000_000_009; // Original V4 Token ID
        v5TokenIds[132] = 47_000_000_010; // Minted V5 Token ID
        v4TokenIds[132] = 47_000_000_010; // Original V4 Token ID
        v5TokenIds[133] = 47_000_000_011; // Minted V5 Token ID
        v4TokenIds[133] = 47_000_000_011; // Original V4 Token ID
        v5TokenIds[134] = 47_000_000_012; // Minted V5 Token ID
        v4TokenIds[134] = 47_000_000_012; // Original V4 Token ID
        v5TokenIds[135] = 47_000_000_013; // Minted V5 Token ID
        v4TokenIds[135] = 47_000_000_013; // Original V4 Token ID
        v5TokenIds[136] = 47_000_000_014; // Minted V5 Token ID
        v4TokenIds[136] = 47_000_000_014; // Original V4 Token ID
        v5TokenIds[137] = 48_000_000_006; // Minted V5 Token ID
        v4TokenIds[137] = 48_000_000_004; // Original V4 Token ID
        v5TokenIds[138] = 49_000_000_004; // Minted V5 Token ID
        v4TokenIds[138] = 49_000_000_003; // Original V4 Token ID
        v5TokenIds[139] = 49_000_000_005; // Minted V5 Token ID
        v4TokenIds[139] = 49_000_000_005; // Original V4 Token ID

        uint256 successfulTransfers = 0;

        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 v5TokenId = v5TokenIds[i];
            uint256 v4TokenId = v4TokenIds[i];

            // Verify V4 ownership using the original V4 token ID
            address v4Owner = v4Hook.ownerOf(v4TokenId);
            address expectedOwner = transferOwners[i];

            require(
                v4Owner != address(v4ResolverAddress),
                "Token owned by main resolver in V4 - should not be in unused assets contract"
            );

            if (v4Owner == address(fallbackV4ResolverAddress)) {
                require(
                    expectedOwner != address(v4ResolverAddress) && expectedOwner != address(fallbackV4ResolverAddress),
                    "Token owned by fallback resolver in V4 but expected owner is also a resolver - should not be in unused assets contract"
                );
            } else {
                require(v4Owner == expectedOwner, "V4/V5 ownership mismatch for token");
            }

            require(hook.ownerOf(v5TokenId) == address(this), "Contract does not own token");

            IERC721(address(hook)).safeTransferFrom(address(this), transferOwners[i], v5TokenId);
            successfulTransfers++;
        }

        require(successfulTransfers == transferOwners.length, "Not all items were transferred");

        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");

        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)

        // // Collect unique owners
        // address[] memory uniqueOwners = new address[](28);

        // uniqueOwners[0] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        // uniqueOwners[1] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        // uniqueOwners[2] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        // uniqueOwners[3] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        // uniqueOwners[4] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        // uniqueOwners[5] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        // uniqueOwners[6] = 0x4A290F18c35bBFE97B2557cf765De9387726dE39;
        // uniqueOwners[7] = 0xf0FE43a75Ff248FD2E75D33fa1ebde71c6d1abAd;
        // uniqueOwners[8] = 0x7044d88283c8FFF0679b711C0cd81f1a6754C843;
        // uniqueOwners[9] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        // uniqueOwners[10] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        // uniqueOwners[11] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        // uniqueOwners[12] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        // uniqueOwners[13] = 0x516cAfD745Ec780D20f61c0d71fe258eA765222D;
        // uniqueOwners[14] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        // uniqueOwners[15] = 0x289715fFBB2f4b482e2917D2f183FeAb564ec84F;
        // uniqueOwners[16] = 0x79d1E7F1A6E0Bbb3278a9d2B782e3A8983444cb6;
        // uniqueOwners[17] = 0xe7879a2D05dBA966Fcca34EE9C3F99eEe7eDEFd1;
        // uniqueOwners[18] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        // uniqueOwners[19] = 0x21a8f5A6bF893D43d3964dDaf4E04766BBBE9b07;
        // uniqueOwners[20] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        // uniqueOwners[21] = 0x7a16eABD1413Bfd468aE9fEBF7C26c62f1fFdc59;
        // uniqueOwners[22] = 0x08cEb8Bba685ee708C9c4c65576837cbE19B9dea;
        // uniqueOwners[23] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        // uniqueOwners[24] = 0x961d4191965C49537c88F764D88318872CE405bE;
        // uniqueOwners[25] = 0x1786D033D5CbCC235B673e872c7613c2F83DA583;
        // uniqueOwners[26] = 0x38EED3CCeED88f380E436eb21811250797c453C5;
        // uniqueOwners[27] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](29);

        // uniqueTierIds[0] = 5;
        // uniqueTierIds[1] = 6;
        // uniqueTierIds[2] = 10;
        // uniqueTierIds[3] = 11;
        // uniqueTierIds[4] = 13;
        // uniqueTierIds[5] = 14;
        // uniqueTierIds[6] = 17;
        // uniqueTierIds[7] = 19;
        // uniqueTierIds[8] = 20;
        // uniqueTierIds[9] = 21;
        // uniqueTierIds[10] = 23;
        // uniqueTierIds[11] = 25;
        // uniqueTierIds[12] = 26;
        // uniqueTierIds[13] = 28;
        // uniqueTierIds[14] = 29;
        // uniqueTierIds[15] = 31;
        // uniqueTierIds[16] = 32;
        // uniqueTierIds[17] = 33;
        // uniqueTierIds[18] = 35;
        // uniqueTierIds[19] = 37;
        // uniqueTierIds[20] = 39;
        // uniqueTierIds[21] = 40;
        // uniqueTierIds[22] = 41;
        // uniqueTierIds[23] = 42;
        // uniqueTierIds[24] = 43;
        // uniqueTierIds[25] = 44;
        // uniqueTierIds[26] = 47;
        // uniqueTierIds[27] = 48;
        // uniqueTierIds[28] = 49;

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
