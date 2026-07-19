// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysArbitrum4 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 176, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 176, "Minted token count mismatch");
        require(mintedTokenIds[0] == 5000000003, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 19000000003, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 19000000004, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 31000000002, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 32000000001, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 39000000001, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 47000000002, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 47000000003, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 47000000004, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 47000000005, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 47000000006, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 47000000007, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 47000000008, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 47000000009, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 47000000010, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 47000000011, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 47000000012, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 47000000013, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 47000000014, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 47000000015, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 47000000016, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 47000000017, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 47000000018, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 47000000019, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 47000000020, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 47000000021, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 47000000022, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 47000000023, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 47000000024, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 47000000025, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 47000000026, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 47000000027, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 49000000002, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 49000000003, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 49000000004, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 49000000005, "Minted token ID mismatch");
        require(mintedTokenIds[36] == 49000000006, "Minted token ID mismatch");
        require(mintedTokenIds[37] == 49000000007, "Minted token ID mismatch");
        require(mintedTokenIds[38] == 49000000008, "Minted token ID mismatch");
        require(mintedTokenIds[39] == 49000000009, "Minted token ID mismatch");
        require(mintedTokenIds[40] == 49000000010, "Minted token ID mismatch");
        require(mintedTokenIds[41] == 49000000011, "Minted token ID mismatch");
        require(mintedTokenIds[42] == 49000000012, "Minted token ID mismatch");
        require(mintedTokenIds[43] == 49000000013, "Minted token ID mismatch");
        require(mintedTokenIds[44] == 49000000014, "Minted token ID mismatch");
        require(mintedTokenIds[45] == 49000000015, "Minted token ID mismatch");
        require(mintedTokenIds[46] == 49000000016, "Minted token ID mismatch");
        require(mintedTokenIds[47] == 49000000017, "Minted token ID mismatch");
        require(mintedTokenIds[48] == 49000000018, "Minted token ID mismatch");
        require(mintedTokenIds[49] == 49000000019, "Minted token ID mismatch");
        require(mintedTokenIds[50] == 49000000020, "Minted token ID mismatch");
        require(mintedTokenIds[51] == 49000000021, "Minted token ID mismatch");
        require(mintedTokenIds[52] == 49000000022, "Minted token ID mismatch");
        require(mintedTokenIds[53] == 49000000023, "Minted token ID mismatch");
        require(mintedTokenIds[54] == 49000000024, "Minted token ID mismatch");
        require(mintedTokenIds[55] == 49000000025, "Minted token ID mismatch");
        require(mintedTokenIds[56] == 49000000026, "Minted token ID mismatch");
        require(mintedTokenIds[57] == 49000000027, "Minted token ID mismatch");
        require(mintedTokenIds[58] == 49000000028, "Minted token ID mismatch");
        require(mintedTokenIds[59] == 49000000029, "Minted token ID mismatch");
        require(mintedTokenIds[60] == 49000000030, "Minted token ID mismatch");
        require(mintedTokenIds[61] == 49000000031, "Minted token ID mismatch");
        require(mintedTokenIds[62] == 49000000032, "Minted token ID mismatch");
        require(mintedTokenIds[63] == 49000000033, "Minted token ID mismatch");
        require(mintedTokenIds[64] == 49000000034, "Minted token ID mismatch");
        require(mintedTokenIds[65] == 49000000035, "Minted token ID mismatch");
        require(mintedTokenIds[66] == 49000000036, "Minted token ID mismatch");
        require(mintedTokenIds[67] == 49000000037, "Minted token ID mismatch");
        require(mintedTokenIds[68] == 49000000038, "Minted token ID mismatch");
        require(mintedTokenIds[69] == 49000000039, "Minted token ID mismatch");
        require(mintedTokenIds[70] == 49000000040, "Minted token ID mismatch");
        require(mintedTokenIds[71] == 49000000041, "Minted token ID mismatch");
        require(mintedTokenIds[72] == 49000000042, "Minted token ID mismatch");
        require(mintedTokenIds[73] == 49000000043, "Minted token ID mismatch");
        require(mintedTokenIds[74] == 49000000044, "Minted token ID mismatch");
        require(mintedTokenIds[75] == 49000000045, "Minted token ID mismatch");
        require(mintedTokenIds[76] == 49000000046, "Minted token ID mismatch");
        require(mintedTokenIds[77] == 49000000047, "Minted token ID mismatch");
        require(mintedTokenIds[78] == 49000000048, "Minted token ID mismatch");
        require(mintedTokenIds[79] == 49000000049, "Minted token ID mismatch");
        require(mintedTokenIds[80] == 49000000050, "Minted token ID mismatch");
        require(mintedTokenIds[81] == 49000000051, "Minted token ID mismatch");
        require(mintedTokenIds[82] == 49000000052, "Minted token ID mismatch");
        require(mintedTokenIds[83] == 49000000053, "Minted token ID mismatch");
        require(mintedTokenIds[84] == 49000000054, "Minted token ID mismatch");
        require(mintedTokenIds[85] == 49000000055, "Minted token ID mismatch");
        require(mintedTokenIds[86] == 49000000056, "Minted token ID mismatch");
        require(mintedTokenIds[87] == 49000000057, "Minted token ID mismatch");
        require(mintedTokenIds[88] == 49000000058, "Minted token ID mismatch");
        require(mintedTokenIds[89] == 49000000059, "Minted token ID mismatch");
        require(mintedTokenIds[90] == 49000000060, "Minted token ID mismatch");
        require(mintedTokenIds[91] == 49000000061, "Minted token ID mismatch");
        require(mintedTokenIds[92] == 49000000062, "Minted token ID mismatch");
        require(mintedTokenIds[93] == 49000000063, "Minted token ID mismatch");
        require(mintedTokenIds[94] == 49000000064, "Minted token ID mismatch");
        require(mintedTokenIds[95] == 49000000065, "Minted token ID mismatch");
        require(mintedTokenIds[96] == 49000000066, "Minted token ID mismatch");
        require(mintedTokenIds[97] == 49000000067, "Minted token ID mismatch");
        require(mintedTokenIds[98] == 49000000068, "Minted token ID mismatch");
        require(mintedTokenIds[99] == 49000000069, "Minted token ID mismatch");
        require(mintedTokenIds[100] == 49000000070, "Minted token ID mismatch");
        require(mintedTokenIds[101] == 49000000071, "Minted token ID mismatch");
        require(mintedTokenIds[102] == 49000000072, "Minted token ID mismatch");
        require(mintedTokenIds[103] == 49000000073, "Minted token ID mismatch");
        require(mintedTokenIds[104] == 49000000074, "Minted token ID mismatch");
        require(mintedTokenIds[105] == 49000000075, "Minted token ID mismatch");
        require(mintedTokenIds[106] == 49000000076, "Minted token ID mismatch");
        require(mintedTokenIds[107] == 49000000077, "Minted token ID mismatch");
        require(mintedTokenIds[108] == 49000000078, "Minted token ID mismatch");
        require(mintedTokenIds[109] == 49000000079, "Minted token ID mismatch");
        require(mintedTokenIds[110] == 49000000080, "Minted token ID mismatch");
        require(mintedTokenIds[111] == 49000000081, "Minted token ID mismatch");
        require(mintedTokenIds[112] == 49000000082, "Minted token ID mismatch");
        require(mintedTokenIds[113] == 49000000083, "Minted token ID mismatch");
        require(mintedTokenIds[114] == 49000000084, "Minted token ID mismatch");
        require(mintedTokenIds[115] == 49000000085, "Minted token ID mismatch");
        require(mintedTokenIds[116] == 49000000086, "Minted token ID mismatch");
        require(mintedTokenIds[117] == 49000000087, "Minted token ID mismatch");
        require(mintedTokenIds[118] == 49000000088, "Minted token ID mismatch");
        require(mintedTokenIds[119] == 49000000089, "Minted token ID mismatch");
        require(mintedTokenIds[120] == 49000000090, "Minted token ID mismatch");
        require(mintedTokenIds[121] == 49000000091, "Minted token ID mismatch");
        require(mintedTokenIds[122] == 49000000092, "Minted token ID mismatch");
        require(mintedTokenIds[123] == 49000000093, "Minted token ID mismatch");
        require(mintedTokenIds[124] == 49000000094, "Minted token ID mismatch");
        require(mintedTokenIds[125] == 49000000095, "Minted token ID mismatch");
        require(mintedTokenIds[126] == 49000000096, "Minted token ID mismatch");
        require(mintedTokenIds[127] == 49000000097, "Minted token ID mismatch");
        require(mintedTokenIds[128] == 49000000098, "Minted token ID mismatch");
        require(mintedTokenIds[129] == 49000000099, "Minted token ID mismatch");
        require(mintedTokenIds[130] == 49000000100, "Minted token ID mismatch");
        require(mintedTokenIds[131] == 49000000101, "Minted token ID mismatch");
        require(mintedTokenIds[132] == 49000000102, "Minted token ID mismatch");
        require(mintedTokenIds[133] == 49000000103, "Minted token ID mismatch");
        require(mintedTokenIds[134] == 49000000104, "Minted token ID mismatch");
        require(mintedTokenIds[135] == 49000000105, "Minted token ID mismatch");
        require(mintedTokenIds[136] == 49000000106, "Minted token ID mismatch");
        require(mintedTokenIds[137] == 49000000107, "Minted token ID mismatch");
        require(mintedTokenIds[138] == 49000000108, "Minted token ID mismatch");
        require(mintedTokenIds[139] == 49000000109, "Minted token ID mismatch");
        require(mintedTokenIds[140] == 49000000110, "Minted token ID mismatch");
        require(mintedTokenIds[141] == 49000000111, "Minted token ID mismatch");
        require(mintedTokenIds[142] == 49000000112, "Minted token ID mismatch");
        require(mintedTokenIds[143] == 49000000113, "Minted token ID mismatch");
        require(mintedTokenIds[144] == 49000000114, "Minted token ID mismatch");
        require(mintedTokenIds[145] == 49000000115, "Minted token ID mismatch");
        require(mintedTokenIds[146] == 49000000116, "Minted token ID mismatch");
        require(mintedTokenIds[147] == 49000000117, "Minted token ID mismatch");
        require(mintedTokenIds[148] == 49000000118, "Minted token ID mismatch");
        require(mintedTokenIds[149] == 49000000119, "Minted token ID mismatch");
        require(mintedTokenIds[150] == 49000000120, "Minted token ID mismatch");
        require(mintedTokenIds[151] == 49000000121, "Minted token ID mismatch");
        require(mintedTokenIds[152] == 49000000122, "Minted token ID mismatch");
        require(mintedTokenIds[153] == 49000000123, "Minted token ID mismatch");
        require(mintedTokenIds[154] == 49000000124, "Minted token ID mismatch");
        require(mintedTokenIds[155] == 49000000125, "Minted token ID mismatch");
        require(mintedTokenIds[156] == 49000000126, "Minted token ID mismatch");
        require(mintedTokenIds[157] == 49000000127, "Minted token ID mismatch");
        require(mintedTokenIds[158] == 49000000128, "Minted token ID mismatch");
        require(mintedTokenIds[159] == 49000000129, "Minted token ID mismatch");
        require(mintedTokenIds[160] == 49000000130, "Minted token ID mismatch");
        require(mintedTokenIds[161] == 49000000131, "Minted token ID mismatch");
        require(mintedTokenIds[162] == 49000000132, "Minted token ID mismatch");
        require(mintedTokenIds[163] == 49000000133, "Minted token ID mismatch");
        require(mintedTokenIds[164] == 49000000134, "Minted token ID mismatch");
        require(mintedTokenIds[165] == 49000000135, "Minted token ID mismatch");
        require(mintedTokenIds[166] == 49000000136, "Minted token ID mismatch");
        require(mintedTokenIds[167] == 49000000137, "Minted token ID mismatch");
        require(mintedTokenIds[168] == 49000000138, "Minted token ID mismatch");
        require(mintedTokenIds[169] == 49000000139, "Minted token ID mismatch");
        require(mintedTokenIds[170] == 49000000140, "Minted token ID mismatch");
        require(mintedTokenIds[171] == 49000000141, "Minted token ID mismatch");
        require(mintedTokenIds[172] == 49000000142, "Minted token ID mismatch");
        require(mintedTokenIds[173] == 49000000143, "Minted token ID mismatch");
        require(mintedTokenIds[174] == 49000000144, "Minted token ID mismatch");
        require(mintedTokenIds[175] == 49000000145, "Minted token ID mismatch");
    }


    function executeMigration(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        IERC721 v4Hook = IERC721(v4HookAddress);

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 5000000003; // V4 5000000003
        targetTokenIds[1] = 19000000003; // V4 19000000002
        targetTokenIds[2] = 19000000004; // V4 19000000004
        targetTokenIds[3] = 31000000002; // V4 31000000002
        targetTokenIds[4] = 32000000001; // V4 32000000001
        targetTokenIds[5] = 39000000001; // V4 39000000001
        targetTokenIds[6] = 47000000002; // V4 47000000002
        targetTokenIds[7] = 47000000003; // V4 47000000003
        targetTokenIds[8] = 47000000004; // V4 47000000004
        targetTokenIds[9] = 47000000005; // V4 47000000005
        targetTokenIds[10] = 47000000006; // V4 47000000006
        targetTokenIds[11] = 47000000007; // V4 47000000007
        targetTokenIds[12] = 47000000008; // V4 47000000008
        targetTokenIds[13] = 47000000009; // V4 47000000009
        targetTokenIds[14] = 47000000010; // V4 47000000010
        targetTokenIds[15] = 47000000011; // V4 47000000011
        targetTokenIds[16] = 47000000012; // V4 47000000012
        targetTokenIds[17] = 47000000013; // V4 47000000013
        targetTokenIds[18] = 47000000014; // V4 47000000014
        targetTokenIds[19] = 47000000015; // V4 47000000015
        targetTokenIds[20] = 47000000016; // V4 47000000016
        targetTokenIds[21] = 47000000017; // V4 47000000017
        targetTokenIds[22] = 47000000018; // V4 47000000018
        targetTokenIds[23] = 47000000019; // V4 47000000019
        targetTokenIds[24] = 47000000020; // V4 47000000020
        targetTokenIds[25] = 47000000021; // V4 47000000021
        targetTokenIds[26] = 47000000022; // V4 47000000022
        targetTokenIds[27] = 47000000023; // V4 47000000023
        targetTokenIds[28] = 47000000024; // V4 47000000024
        targetTokenIds[29] = 47000000025; // V4 47000000025
        targetTokenIds[30] = 47000000026; // V4 47000000026
        targetTokenIds[31] = 47000000027; // V4 47000000027
        targetTokenIds[32] = 49000000002; // V4 49000000001
        targetTokenIds[33] = 49000000003; // V4 49000000003
        targetTokenIds[34] = 49000000004; // V4 49000000004
        targetTokenIds[35] = 49000000005; // V4 49000000005
        targetTokenIds[36] = 49000000006; // V4 49000000006
        targetTokenIds[37] = 49000000007; // V4 49000000007
        targetTokenIds[38] = 49000000008; // V4 49000000008
        targetTokenIds[39] = 49000000009; // V4 49000000009
        targetTokenIds[40] = 49000000010; // V4 49000000010
        targetTokenIds[41] = 49000000011; // V4 49000000011
        targetTokenIds[42] = 49000000012; // V4 49000000012
        targetTokenIds[43] = 49000000013; // V4 49000000013
        targetTokenIds[44] = 49000000014; // V4 49000000014
        targetTokenIds[45] = 49000000015; // V4 49000000015
        targetTokenIds[46] = 49000000016; // V4 49000000016
        targetTokenIds[47] = 49000000017; // V4 49000000017
        targetTokenIds[48] = 49000000018; // V4 49000000018
        targetTokenIds[49] = 49000000019; // V4 49000000019
        targetTokenIds[50] = 49000000020; // V4 49000000020
        targetTokenIds[51] = 49000000021; // V4 49000000021
        targetTokenIds[52] = 49000000022; // V4 49000000022
        targetTokenIds[53] = 49000000023; // V4 49000000023
        targetTokenIds[54] = 49000000024; // V4 49000000024
        targetTokenIds[55] = 49000000025; // V4 49000000025
        targetTokenIds[56] = 49000000026; // V4 49000000026
        targetTokenIds[57] = 49000000027; // V4 49000000027
        targetTokenIds[58] = 49000000028; // V4 49000000028
        targetTokenIds[59] = 49000000029; // V4 49000000029
        targetTokenIds[60] = 49000000030; // V4 49000000030
        targetTokenIds[61] = 49000000031; // V4 49000000031
        targetTokenIds[62] = 49000000032; // V4 49000000032
        targetTokenIds[63] = 49000000033; // V4 49000000033
        targetTokenIds[64] = 49000000034; // V4 49000000034
        targetTokenIds[65] = 49000000035; // V4 49000000035
        targetTokenIds[66] = 49000000036; // V4 49000000036
        targetTokenIds[67] = 49000000037; // V4 49000000037
        targetTokenIds[68] = 49000000038; // V4 49000000038
        targetTokenIds[69] = 49000000039; // V4 49000000039
        targetTokenIds[70] = 49000000040; // V4 49000000040
        targetTokenIds[71] = 49000000041; // V4 49000000041
        targetTokenIds[72] = 49000000042; // V4 49000000042
        targetTokenIds[73] = 49000000043; // V4 49000000043
        targetTokenIds[74] = 49000000044; // V4 49000000044
        targetTokenIds[75] = 49000000045; // V4 49000000045
        targetTokenIds[76] = 49000000046; // V4 49000000046
        targetTokenIds[77] = 49000000047; // V4 49000000047
        targetTokenIds[78] = 49000000048; // V4 49000000048
        targetTokenIds[79] = 49000000049; // V4 49000000049
        targetTokenIds[80] = 49000000050; // V4 49000000050
        targetTokenIds[81] = 49000000051; // V4 49000000051
        targetTokenIds[82] = 49000000052; // V4 49000000052
        targetTokenIds[83] = 49000000053; // V4 49000000053
        targetTokenIds[84] = 49000000054; // V4 49000000054
        targetTokenIds[85] = 49000000055; // V4 49000000055
        targetTokenIds[86] = 49000000056; // V4 49000000056
        targetTokenIds[87] = 49000000057; // V4 49000000057
        targetTokenIds[88] = 49000000058; // V4 49000000058
        targetTokenIds[89] = 49000000059; // V4 49000000059
        targetTokenIds[90] = 49000000060; // V4 49000000060
        targetTokenIds[91] = 49000000061; // V4 49000000061
        targetTokenIds[92] = 49000000062; // V4 49000000062
        targetTokenIds[93] = 49000000063; // V4 49000000063
        targetTokenIds[94] = 49000000064; // V4 49000000064
        targetTokenIds[95] = 49000000065; // V4 49000000065
        targetTokenIds[96] = 49000000066; // V4 49000000066
        targetTokenIds[97] = 49000000067; // V4 49000000067
        targetTokenIds[98] = 49000000068; // V4 49000000068
        targetTokenIds[99] = 49000000069; // V4 49000000069
        targetTokenIds[100] = 49000000070; // V4 49000000070
        targetTokenIds[101] = 49000000071; // V4 49000000071
        targetTokenIds[102] = 49000000072; // V4 49000000072
        targetTokenIds[103] = 49000000073; // V4 49000000073
        targetTokenIds[104] = 49000000074; // V4 49000000074
        targetTokenIds[105] = 49000000075; // V4 49000000075
        targetTokenIds[106] = 49000000076; // V4 49000000076
        targetTokenIds[107] = 49000000077; // V4 49000000077
        targetTokenIds[108] = 49000000078; // V4 49000000078
        targetTokenIds[109] = 49000000079; // V4 49000000079
        targetTokenIds[110] = 49000000080; // V4 49000000080
        targetTokenIds[111] = 49000000081; // V4 49000000081
        targetTokenIds[112] = 49000000082; // V4 49000000082
        targetTokenIds[113] = 49000000083; // V4 49000000083
        targetTokenIds[114] = 49000000084; // V4 49000000084
        targetTokenIds[115] = 49000000085; // V4 49000000085
        targetTokenIds[116] = 49000000086; // V4 49000000086
        targetTokenIds[117] = 49000000087; // V4 49000000087
        targetTokenIds[118] = 49000000088; // V4 49000000088
        targetTokenIds[119] = 49000000089; // V4 49000000089
        targetTokenIds[120] = 49000000090; // V4 49000000090
        targetTokenIds[121] = 49000000091; // V4 49000000091
        targetTokenIds[122] = 49000000092; // V4 49000000092
        targetTokenIds[123] = 49000000093; // V4 49000000093
        targetTokenIds[124] = 49000000094; // V4 49000000094
        targetTokenIds[125] = 49000000095; // V4 49000000095
        targetTokenIds[126] = 49000000096; // V4 49000000096
        targetTokenIds[127] = 49000000097; // V4 49000000097
        targetTokenIds[128] = 49000000098; // V4 49000000098
        targetTokenIds[129] = 49000000099; // V4 49000000099
        targetTokenIds[130] = 49000000100; // V4 49000000100
        targetTokenIds[131] = 49000000101; // V4 49000000101
        targetTokenIds[132] = 49000000102; // V4 49000000102
        targetTokenIds[133] = 49000000103; // V4 49000000103
        targetTokenIds[134] = 49000000104; // V4 49000000104
        targetTokenIds[135] = 49000000105; // V4 49000000105
        targetTokenIds[136] = 49000000106; // V4 49000000106
        targetTokenIds[137] = 49000000107; // V4 49000000107
        targetTokenIds[138] = 49000000108; // V4 49000000108
        targetTokenIds[139] = 49000000109; // V4 49000000109
        targetTokenIds[140] = 49000000110; // V4 49000000110
        targetTokenIds[141] = 49000000111; // V4 49000000111
        targetTokenIds[142] = 49000000112; // V4 49000000112
        targetTokenIds[143] = 49000000113; // V4 49000000113
        targetTokenIds[144] = 49000000114; // V4 49000000114
        targetTokenIds[145] = 49000000115; // V4 49000000115
        targetTokenIds[146] = 49000000116; // V4 49000000116
        targetTokenIds[147] = 49000000117; // V4 49000000117
        targetTokenIds[148] = 49000000118; // V4 49000000118
        targetTokenIds[149] = 49000000119; // V4 49000000119
        targetTokenIds[150] = 49000000120; // V4 49000000120
        targetTokenIds[151] = 49000000121; // V4 49000000121
        targetTokenIds[152] = 49000000122; // V4 49000000122
        targetTokenIds[153] = 49000000123; // V4 49000000123
        targetTokenIds[154] = 49000000124; // V4 49000000124
        targetTokenIds[155] = 49000000125; // V4 49000000125
        targetTokenIds[156] = 49000000126; // V4 49000000126
        targetTokenIds[157] = 49000000127; // V4 49000000127
        targetTokenIds[158] = 49000000128; // V4 49000000128
        targetTokenIds[159] = 49000000129; // V4 49000000129
        targetTokenIds[160] = 49000000130; // V4 49000000130
        targetTokenIds[161] = 49000000131; // V4 49000000131
        targetTokenIds[162] = 49000000132; // V4 49000000132
        targetTokenIds[163] = 49000000133; // V4 49000000133
        targetTokenIds[164] = 49000000134; // V4 49000000134
        targetTokenIds[165] = 49000000135; // V4 49000000135
        targetTokenIds[166] = 49000000136; // V4 49000000136
        targetTokenIds[167] = 49000000137; // V4 49000000137
        targetTokenIds[168] = 49000000138; // V4 49000000138
        targetTokenIds[169] = 49000000139; // V4 49000000139
        targetTokenIds[170] = 49000000140; // V4 49000000140
        targetTokenIds[171] = 49000000141; // V4 49000000141
        targetTokenIds[172] = 49000000142; // V4 49000000142
        targetTokenIds[173] = 49000000143; // V4 49000000143
        targetTokenIds[174] = 49000000144; // V4 49000000144
        targetTokenIds[175] = 49000000145; // V4 49000000145

        v4TokenIds[0] = 5000000003; // V4 5000000003
        v4TokenIds[1] = 19000000002; // V4 19000000002
        v4TokenIds[2] = 19000000004; // V4 19000000004
        v4TokenIds[3] = 31000000002; // V4 31000000002
        v4TokenIds[4] = 32000000001; // V4 32000000001
        v4TokenIds[5] = 39000000001; // V4 39000000001
        v4TokenIds[6] = 47000000002; // V4 47000000002
        v4TokenIds[7] = 47000000003; // V4 47000000003
        v4TokenIds[8] = 47000000004; // V4 47000000004
        v4TokenIds[9] = 47000000005; // V4 47000000005
        v4TokenIds[10] = 47000000006; // V4 47000000006
        v4TokenIds[11] = 47000000007; // V4 47000000007
        v4TokenIds[12] = 47000000008; // V4 47000000008
        v4TokenIds[13] = 47000000009; // V4 47000000009
        v4TokenIds[14] = 47000000010; // V4 47000000010
        v4TokenIds[15] = 47000000011; // V4 47000000011
        v4TokenIds[16] = 47000000012; // V4 47000000012
        v4TokenIds[17] = 47000000013; // V4 47000000013
        v4TokenIds[18] = 47000000014; // V4 47000000014
        v4TokenIds[19] = 47000000015; // V4 47000000015
        v4TokenIds[20] = 47000000016; // V4 47000000016
        v4TokenIds[21] = 47000000017; // V4 47000000017
        v4TokenIds[22] = 47000000018; // V4 47000000018
        v4TokenIds[23] = 47000000019; // V4 47000000019
        v4TokenIds[24] = 47000000020; // V4 47000000020
        v4TokenIds[25] = 47000000021; // V4 47000000021
        v4TokenIds[26] = 47000000022; // V4 47000000022
        v4TokenIds[27] = 47000000023; // V4 47000000023
        v4TokenIds[28] = 47000000024; // V4 47000000024
        v4TokenIds[29] = 47000000025; // V4 47000000025
        v4TokenIds[30] = 47000000026; // V4 47000000026
        v4TokenIds[31] = 47000000027; // V4 47000000027
        v4TokenIds[32] = 49000000001; // V4 49000000001
        v4TokenIds[33] = 49000000003; // V4 49000000003
        v4TokenIds[34] = 49000000004; // V4 49000000004
        v4TokenIds[35] = 49000000005; // V4 49000000005
        v4TokenIds[36] = 49000000006; // V4 49000000006
        v4TokenIds[37] = 49000000007; // V4 49000000007
        v4TokenIds[38] = 49000000008; // V4 49000000008
        v4TokenIds[39] = 49000000009; // V4 49000000009
        v4TokenIds[40] = 49000000010; // V4 49000000010
        v4TokenIds[41] = 49000000011; // V4 49000000011
        v4TokenIds[42] = 49000000012; // V4 49000000012
        v4TokenIds[43] = 49000000013; // V4 49000000013
        v4TokenIds[44] = 49000000014; // V4 49000000014
        v4TokenIds[45] = 49000000015; // V4 49000000015
        v4TokenIds[46] = 49000000016; // V4 49000000016
        v4TokenIds[47] = 49000000017; // V4 49000000017
        v4TokenIds[48] = 49000000018; // V4 49000000018
        v4TokenIds[49] = 49000000019; // V4 49000000019
        v4TokenIds[50] = 49000000020; // V4 49000000020
        v4TokenIds[51] = 49000000021; // V4 49000000021
        v4TokenIds[52] = 49000000022; // V4 49000000022
        v4TokenIds[53] = 49000000023; // V4 49000000023
        v4TokenIds[54] = 49000000024; // V4 49000000024
        v4TokenIds[55] = 49000000025; // V4 49000000025
        v4TokenIds[56] = 49000000026; // V4 49000000026
        v4TokenIds[57] = 49000000027; // V4 49000000027
        v4TokenIds[58] = 49000000028; // V4 49000000028
        v4TokenIds[59] = 49000000029; // V4 49000000029
        v4TokenIds[60] = 49000000030; // V4 49000000030
        v4TokenIds[61] = 49000000031; // V4 49000000031
        v4TokenIds[62] = 49000000032; // V4 49000000032
        v4TokenIds[63] = 49000000033; // V4 49000000033
        v4TokenIds[64] = 49000000034; // V4 49000000034
        v4TokenIds[65] = 49000000035; // V4 49000000035
        v4TokenIds[66] = 49000000036; // V4 49000000036
        v4TokenIds[67] = 49000000037; // V4 49000000037
        v4TokenIds[68] = 49000000038; // V4 49000000038
        v4TokenIds[69] = 49000000039; // V4 49000000039
        v4TokenIds[70] = 49000000040; // V4 49000000040
        v4TokenIds[71] = 49000000041; // V4 49000000041
        v4TokenIds[72] = 49000000042; // V4 49000000042
        v4TokenIds[73] = 49000000043; // V4 49000000043
        v4TokenIds[74] = 49000000044; // V4 49000000044
        v4TokenIds[75] = 49000000045; // V4 49000000045
        v4TokenIds[76] = 49000000046; // V4 49000000046
        v4TokenIds[77] = 49000000047; // V4 49000000047
        v4TokenIds[78] = 49000000048; // V4 49000000048
        v4TokenIds[79] = 49000000049; // V4 49000000049
        v4TokenIds[80] = 49000000050; // V4 49000000050
        v4TokenIds[81] = 49000000051; // V4 49000000051
        v4TokenIds[82] = 49000000052; // V4 49000000052
        v4TokenIds[83] = 49000000053; // V4 49000000053
        v4TokenIds[84] = 49000000054; // V4 49000000054
        v4TokenIds[85] = 49000000055; // V4 49000000055
        v4TokenIds[86] = 49000000056; // V4 49000000056
        v4TokenIds[87] = 49000000057; // V4 49000000057
        v4TokenIds[88] = 49000000058; // V4 49000000058
        v4TokenIds[89] = 49000000059; // V4 49000000059
        v4TokenIds[90] = 49000000060; // V4 49000000060
        v4TokenIds[91] = 49000000061; // V4 49000000061
        v4TokenIds[92] = 49000000062; // V4 49000000062
        v4TokenIds[93] = 49000000063; // V4 49000000063
        v4TokenIds[94] = 49000000064; // V4 49000000064
        v4TokenIds[95] = 49000000065; // V4 49000000065
        v4TokenIds[96] = 49000000066; // V4 49000000066
        v4TokenIds[97] = 49000000067; // V4 49000000067
        v4TokenIds[98] = 49000000068; // V4 49000000068
        v4TokenIds[99] = 49000000069; // V4 49000000069
        v4TokenIds[100] = 49000000070; // V4 49000000070
        v4TokenIds[101] = 49000000071; // V4 49000000071
        v4TokenIds[102] = 49000000072; // V4 49000000072
        v4TokenIds[103] = 49000000073; // V4 49000000073
        v4TokenIds[104] = 49000000074; // V4 49000000074
        v4TokenIds[105] = 49000000075; // V4 49000000075
        v4TokenIds[106] = 49000000076; // V4 49000000076
        v4TokenIds[107] = 49000000077; // V4 49000000077
        v4TokenIds[108] = 49000000078; // V4 49000000078
        v4TokenIds[109] = 49000000079; // V4 49000000079
        v4TokenIds[110] = 49000000080; // V4 49000000080
        v4TokenIds[111] = 49000000081; // V4 49000000081
        v4TokenIds[112] = 49000000082; // V4 49000000082
        v4TokenIds[113] = 49000000083; // V4 49000000083
        v4TokenIds[114] = 49000000084; // V4 49000000084
        v4TokenIds[115] = 49000000085; // V4 49000000085
        v4TokenIds[116] = 49000000086; // V4 49000000086
        v4TokenIds[117] = 49000000087; // V4 49000000087
        v4TokenIds[118] = 49000000088; // V4 49000000088
        v4TokenIds[119] = 49000000089; // V4 49000000089
        v4TokenIds[120] = 49000000090; // V4 49000000090
        v4TokenIds[121] = 49000000091; // V4 49000000091
        v4TokenIds[122] = 49000000092; // V4 49000000092
        v4TokenIds[123] = 49000000093; // V4 49000000093
        v4TokenIds[124] = 49000000094; // V4 49000000094
        v4TokenIds[125] = 49000000095; // V4 49000000095
        v4TokenIds[126] = 49000000096; // V4 49000000096
        v4TokenIds[127] = 49000000097; // V4 49000000097
        v4TokenIds[128] = 49000000098; // V4 49000000098
        v4TokenIds[129] = 49000000099; // V4 49000000099
        v4TokenIds[130] = 49000000100; // V4 49000000100
        v4TokenIds[131] = 49000000101; // V4 49000000101
        v4TokenIds[132] = 49000000102; // V4 49000000102
        v4TokenIds[133] = 49000000103; // V4 49000000103
        v4TokenIds[134] = 49000000104; // V4 49000000104
        v4TokenIds[135] = 49000000105; // V4 49000000105
        v4TokenIds[136] = 49000000106; // V4 49000000106
        v4TokenIds[137] = 49000000107; // V4 49000000107
        v4TokenIds[138] = 49000000108; // V4 49000000108
        v4TokenIds[139] = 49000000109; // V4 49000000109
        v4TokenIds[140] = 49000000110; // V4 49000000110
        v4TokenIds[141] = 49000000111; // V4 49000000111
        v4TokenIds[142] = 49000000112; // V4 49000000112
        v4TokenIds[143] = 49000000113; // V4 49000000113
        v4TokenIds[144] = 49000000114; // V4 49000000114
        v4TokenIds[145] = 49000000115; // V4 49000000115
        v4TokenIds[146] = 49000000116; // V4 49000000116
        v4TokenIds[147] = 49000000117; // V4 49000000117
        v4TokenIds[148] = 49000000118; // V4 49000000118
        v4TokenIds[149] = 49000000119; // V4 49000000119
        v4TokenIds[150] = 49000000120; // V4 49000000120
        v4TokenIds[151] = 49000000121; // V4 49000000121
        v4TokenIds[152] = 49000000122; // V4 49000000122
        v4TokenIds[153] = 49000000123; // V4 49000000123
        v4TokenIds[154] = 49000000124; // V4 49000000124
        v4TokenIds[155] = 49000000125; // V4 49000000125
        v4TokenIds[156] = 49000000126; // V4 49000000126
        v4TokenIds[157] = 49000000127; // V4 49000000127
        v4TokenIds[158] = 49000000128; // V4 49000000128
        v4TokenIds[159] = 49000000129; // V4 49000000129
        v4TokenIds[160] = 49000000130; // V4 49000000130
        v4TokenIds[161] = 49000000131; // V4 49000000131
        v4TokenIds[162] = 49000000132; // V4 49000000132
        v4TokenIds[163] = 49000000133; // V4 49000000133
        v4TokenIds[164] = 49000000134; // V4 49000000134
        v4TokenIds[165] = 49000000135; // V4 49000000135
        v4TokenIds[166] = 49000000136; // V4 49000000136
        v4TokenIds[167] = 49000000137; // V4 49000000137
        v4TokenIds[168] = 49000000138; // V4 49000000138
        v4TokenIds[169] = 49000000139; // V4 49000000139
        v4TokenIds[170] = 49000000140; // V4 49000000140
        v4TokenIds[171] = 49000000141; // V4 49000000141
        v4TokenIds[172] = 49000000142; // V4 49000000142
        v4TokenIds[173] = 49000000143; // V4 49000000143
        v4TokenIds[174] = 49000000144; // V4 49000000144
        v4TokenIds[175] = 49000000145; // V4 49000000145


        uint256 successfulTransfers;

        for (uint256 i; i < transferOwners.length; i++) {
            uint256 targetTokenId = targetTokenIds[i];
            uint256 v4TokenId = v4TokenIds[i];
            address expectedOwner = transferOwners[i];

            if (verifyV4State) {
                address v4Owner = v4Hook.ownerOf(v4TokenId);

                if (v4Owner == address(v4ResolverAddress)) {
                    require(allowResolverOwners[i], "Token owned by main resolver in V4 - should not be standalone");
                } else if (v4Owner == address(fallbackV4ResolverAddress)) {
                    require(
                        expectedOwner != address(v4ResolverAddress)
                            && expectedOwner != address(fallbackV4ResolverAddress),
                        "Fallback resolver owner cannot receive standalone token"
                    );
                } else {
                    require(v4Owner == expectedOwner, "V4/V6 ownership mismatch for token");
                }
            }

            require(token.ownerOf(targetTokenId) == address(this), "Contract does not own token");
            token.safeTransferFrom(address(this), expectedOwner, targetTokenId);
            successfulTransfers++;
        }

        require(successfulTransfers == 176, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
