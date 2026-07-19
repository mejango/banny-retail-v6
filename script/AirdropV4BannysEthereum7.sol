// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysEthereum7 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 141, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 141, "Minted token count mismatch");
        require(mintedTokenIds[0] == 5000000007, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 5000000008, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 6000000009, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 6000000010, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 6000000011, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 6000000012, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 6000000013, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 10000000007, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 10000000008, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 10000000009, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 10000000010, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 10000000011, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 10000000012, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 10000000013, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 11000000001, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 13000000003, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 13000000004, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 14000000004, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 14000000005, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 14000000006, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 17000000003, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 17000000004, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 17000000005, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 19000000016, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 19000000017, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 19000000018, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 19000000019, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 19000000020, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 19000000021, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 19000000022, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 20000000003, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 20000000004, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 20000000005, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 20000000006, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 20000000007, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 20000000008, "Minted token ID mismatch");
        require(mintedTokenIds[36] == 21000000002, "Minted token ID mismatch");
        require(mintedTokenIds[37] == 23000000007, "Minted token ID mismatch");
        require(mintedTokenIds[38] == 23000000008, "Minted token ID mismatch");
        require(mintedTokenIds[39] == 25000000010, "Minted token ID mismatch");
        require(mintedTokenIds[40] == 25000000011, "Minted token ID mismatch");
        require(mintedTokenIds[41] == 25000000012, "Minted token ID mismatch");
        require(mintedTokenIds[42] == 26000000006, "Minted token ID mismatch");
        require(mintedTokenIds[43] == 26000000007, "Minted token ID mismatch");
        require(mintedTokenIds[44] == 28000000003, "Minted token ID mismatch");
        require(mintedTokenIds[45] == 28000000004, "Minted token ID mismatch");
        require(mintedTokenIds[46] == 28000000005, "Minted token ID mismatch");
        require(mintedTokenIds[47] == 28000000006, "Minted token ID mismatch");
        require(mintedTokenIds[48] == 28000000007, "Minted token ID mismatch");
        require(mintedTokenIds[49] == 28000000008, "Minted token ID mismatch");
        require(mintedTokenIds[50] == 28000000009, "Minted token ID mismatch");
        require(mintedTokenIds[51] == 29000000003, "Minted token ID mismatch");
        require(mintedTokenIds[52] == 31000000009, "Minted token ID mismatch");
        require(mintedTokenIds[53] == 31000000010, "Minted token ID mismatch");
        require(mintedTokenIds[54] == 31000000011, "Minted token ID mismatch");
        require(mintedTokenIds[55] == 31000000012, "Minted token ID mismatch");
        require(mintedTokenIds[56] == 31000000013, "Minted token ID mismatch");
        require(mintedTokenIds[57] == 32000000004, "Minted token ID mismatch");
        require(mintedTokenIds[58] == 32000000005, "Minted token ID mismatch");
        require(mintedTokenIds[59] == 33000000002, "Minted token ID mismatch");
        require(mintedTokenIds[60] == 35000000007, "Minted token ID mismatch");
        require(mintedTokenIds[61] == 35000000008, "Minted token ID mismatch");
        require(mintedTokenIds[62] == 35000000009, "Minted token ID mismatch");
        require(mintedTokenIds[63] == 37000000003, "Minted token ID mismatch");
        require(mintedTokenIds[64] == 37000000004, "Minted token ID mismatch");
        require(mintedTokenIds[65] == 39000000004, "Minted token ID mismatch");
        require(mintedTokenIds[66] == 40000000002, "Minted token ID mismatch");
        require(mintedTokenIds[67] == 40000000003, "Minted token ID mismatch");
        require(mintedTokenIds[68] == 41000000005, "Minted token ID mismatch");
        require(mintedTokenIds[69] == 42000000004, "Minted token ID mismatch");
        require(mintedTokenIds[70] == 42000000005, "Minted token ID mismatch");
        require(mintedTokenIds[71] == 42000000006, "Minted token ID mismatch");
        require(mintedTokenIds[72] == 42000000007, "Minted token ID mismatch");
        require(mintedTokenIds[73] == 42000000008, "Minted token ID mismatch");
        require(mintedTokenIds[74] == 42000000009, "Minted token ID mismatch");
        require(mintedTokenIds[75] == 42000000010, "Minted token ID mismatch");
        require(mintedTokenIds[76] == 42000000011, "Minted token ID mismatch");
        require(mintedTokenIds[77] == 42000000012, "Minted token ID mismatch");
        require(mintedTokenIds[78] == 42000000013, "Minted token ID mismatch");
        require(mintedTokenIds[79] == 42000000014, "Minted token ID mismatch");
        require(mintedTokenIds[80] == 42000000015, "Minted token ID mismatch");
        require(mintedTokenIds[81] == 42000000016, "Minted token ID mismatch");
        require(mintedTokenIds[82] == 42000000017, "Minted token ID mismatch");
        require(mintedTokenIds[83] == 42000000018, "Minted token ID mismatch");
        require(mintedTokenIds[84] == 42000000019, "Minted token ID mismatch");
        require(mintedTokenIds[85] == 43000000008, "Minted token ID mismatch");
        require(mintedTokenIds[86] == 43000000009, "Minted token ID mismatch");
        require(mintedTokenIds[87] == 43000000010, "Minted token ID mismatch");
        require(mintedTokenIds[88] == 43000000011, "Minted token ID mismatch");
        require(mintedTokenIds[89] == 43000000012, "Minted token ID mismatch");
        require(mintedTokenIds[90] == 43000000013, "Minted token ID mismatch");
        require(mintedTokenIds[91] == 43000000014, "Minted token ID mismatch");
        require(mintedTokenIds[92] == 43000000015, "Minted token ID mismatch");
        require(mintedTokenIds[93] == 43000000016, "Minted token ID mismatch");
        require(mintedTokenIds[94] == 43000000017, "Minted token ID mismatch");
        require(mintedTokenIds[95] == 43000000018, "Minted token ID mismatch");
        require(mintedTokenIds[96] == 44000000006, "Minted token ID mismatch");
        require(mintedTokenIds[97] == 44000000007, "Minted token ID mismatch");
        require(mintedTokenIds[98] == 44000000008, "Minted token ID mismatch");
        require(mintedTokenIds[99] == 44000000009, "Minted token ID mismatch");
        require(mintedTokenIds[100] == 44000000010, "Minted token ID mismatch");
        require(mintedTokenIds[101] == 44000000011, "Minted token ID mismatch");
        require(mintedTokenIds[102] == 44000000012, "Minted token ID mismatch");
        require(mintedTokenIds[103] == 44000000013, "Minted token ID mismatch");
        require(mintedTokenIds[104] == 44000000014, "Minted token ID mismatch");
        require(mintedTokenIds[105] == 44000000015, "Minted token ID mismatch");
        require(mintedTokenIds[106] == 44000000016, "Minted token ID mismatch");
        require(mintedTokenIds[107] == 44000000017, "Minted token ID mismatch");
        require(mintedTokenIds[108] == 44000000018, "Minted token ID mismatch");
        require(mintedTokenIds[109] == 44000000019, "Minted token ID mismatch");
        require(mintedTokenIds[110] == 44000000020, "Minted token ID mismatch");
        require(mintedTokenIds[111] == 44000000021, "Minted token ID mismatch");
        require(mintedTokenIds[112] == 44000000022, "Minted token ID mismatch");
        require(mintedTokenIds[113] == 44000000023, "Minted token ID mismatch");
        require(mintedTokenIds[114] == 44000000024, "Minted token ID mismatch");
        require(mintedTokenIds[115] == 44000000025, "Minted token ID mismatch");
        require(mintedTokenIds[116] == 44000000026, "Minted token ID mismatch");
        require(mintedTokenIds[117] == 44000000027, "Minted token ID mismatch");
        require(mintedTokenIds[118] == 44000000028, "Minted token ID mismatch");
        require(mintedTokenIds[119] == 44000000029, "Minted token ID mismatch");
        require(mintedTokenIds[120] == 44000000030, "Minted token ID mismatch");
        require(mintedTokenIds[121] == 44000000031, "Minted token ID mismatch");
        require(mintedTokenIds[122] == 44000000032, "Minted token ID mismatch");
        require(mintedTokenIds[123] == 44000000033, "Minted token ID mismatch");
        require(mintedTokenIds[124] == 44000000034, "Minted token ID mismatch");
        require(mintedTokenIds[125] == 47000000003, "Minted token ID mismatch");
        require(mintedTokenIds[126] == 47000000004, "Minted token ID mismatch");
        require(mintedTokenIds[127] == 47000000005, "Minted token ID mismatch");
        require(mintedTokenIds[128] == 47000000006, "Minted token ID mismatch");
        require(mintedTokenIds[129] == 47000000007, "Minted token ID mismatch");
        require(mintedTokenIds[130] == 47000000008, "Minted token ID mismatch");
        require(mintedTokenIds[131] == 47000000009, "Minted token ID mismatch");
        require(mintedTokenIds[132] == 47000000010, "Minted token ID mismatch");
        require(mintedTokenIds[133] == 47000000011, "Minted token ID mismatch");
        require(mintedTokenIds[134] == 47000000012, "Minted token ID mismatch");
        require(mintedTokenIds[135] == 47000000013, "Minted token ID mismatch");
        require(mintedTokenIds[136] == 47000000014, "Minted token ID mismatch");
        require(mintedTokenIds[137] == 48000000006, "Minted token ID mismatch");
        require(mintedTokenIds[138] == 49000000004, "Minted token ID mismatch");
        require(mintedTokenIds[139] == 49000000005, "Minted token ID mismatch");
        require(mintedTokenIds[140] == 49000000006, "Minted token ID mismatch");
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
        targetTokenIds[0] = 5000000007; // V4 5000000003
        targetTokenIds[1] = 5000000008; // V4 5000000007
        targetTokenIds[2] = 6000000009; // V4 6000000005
        targetTokenIds[3] = 6000000010; // V4 6000000006
        targetTokenIds[4] = 6000000011; // V4 6000000007
        targetTokenIds[5] = 6000000012; // V4 6000000008
        targetTokenIds[6] = 6000000013; // V4 6000000009
        targetTokenIds[7] = 10000000007; // V4 10000000004
        targetTokenIds[8] = 10000000008; // V4 10000000008
        targetTokenIds[9] = 10000000009; // V4 10000000009
        targetTokenIds[10] = 10000000010; // V4 10000000010
        targetTokenIds[11] = 10000000011; // V4 10000000011
        targetTokenIds[12] = 10000000012; // V4 10000000013
        targetTokenIds[13] = 10000000013; // V4 10000000014
        targetTokenIds[14] = 11000000001; // V4 11000000001
        targetTokenIds[15] = 13000000003; // V4 13000000002
        targetTokenIds[16] = 13000000004; // V4 13000000004
        targetTokenIds[17] = 14000000004; // V4 14000000002
        targetTokenIds[18] = 14000000005; // V4 14000000004
        targetTokenIds[19] = 14000000006; // V4 14000000006
        targetTokenIds[20] = 17000000003; // V4 17000000003
        targetTokenIds[21] = 17000000004; // V4 17000000004
        targetTokenIds[22] = 17000000005; // V4 17000000005
        targetTokenIds[23] = 19000000016; // V4 19000000001
        targetTokenIds[24] = 19000000017; // V4 19000000003
        targetTokenIds[25] = 19000000018; // V4 19000000006
        targetTokenIds[26] = 19000000019; // V4 19000000007
        targetTokenIds[27] = 19000000020; // V4 19000000010
        targetTokenIds[28] = 19000000021; // V4 19000000014
        targetTokenIds[29] = 19000000022; // V4 19000000022
        targetTokenIds[30] = 20000000003; // V4 20000000002
        targetTokenIds[31] = 20000000004; // V4 20000000003
        targetTokenIds[32] = 20000000005; // V4 20000000004
        targetTokenIds[33] = 20000000006; // V4 20000000005
        targetTokenIds[34] = 20000000007; // V4 20000000006
        targetTokenIds[35] = 20000000008; // V4 20000000007
        targetTokenIds[36] = 21000000002; // V4 21000000002
        targetTokenIds[37] = 23000000007; // V4 23000000006
        targetTokenIds[38] = 23000000008; // V4 23000000008
        targetTokenIds[39] = 25000000010; // V4 25000000001
        targetTokenIds[40] = 25000000011; // V4 25000000004
        targetTokenIds[41] = 25000000012; // V4 25000000012
        targetTokenIds[42] = 26000000006; // V4 26000000006
        targetTokenIds[43] = 26000000007; // V4 26000000007
        targetTokenIds[44] = 28000000003; // V4 28000000001
        targetTokenIds[45] = 28000000004; // V4 28000000003
        targetTokenIds[46] = 28000000005; // V4 28000000004
        targetTokenIds[47] = 28000000006; // V4 28000000005
        targetTokenIds[48] = 28000000007; // V4 28000000006
        targetTokenIds[49] = 28000000008; // V4 28000000007
        targetTokenIds[50] = 28000000009; // V4 28000000009
        targetTokenIds[51] = 29000000003; // V4 29000000001
        targetTokenIds[52] = 31000000009; // V4 31000000001
        targetTokenIds[53] = 31000000010; // V4 31000000004
        targetTokenIds[54] = 31000000011; // V4 31000000005
        targetTokenIds[55] = 31000000012; // V4 31000000008
        targetTokenIds[56] = 31000000013; // V4 31000000012
        targetTokenIds[57] = 32000000004; // V4 32000000004
        targetTokenIds[58] = 32000000005; // V4 32000000005
        targetTokenIds[59] = 33000000002; // V4 33000000002
        targetTokenIds[60] = 35000000007; // V4 35000000005
        targetTokenIds[61] = 35000000008; // V4 35000000008
        targetTokenIds[62] = 35000000009; // V4 35000000009
        targetTokenIds[63] = 37000000003; // V4 37000000002
        targetTokenIds[64] = 37000000004; // V4 37000000004
        targetTokenIds[65] = 39000000004; // V4 39000000004
        targetTokenIds[66] = 40000000002; // V4 40000000002
        targetTokenIds[67] = 40000000003; // V4 40000000003
        targetTokenIds[68] = 41000000005; // V4 41000000005
        targetTokenIds[69] = 42000000004; // V4 42000000001
        targetTokenIds[70] = 42000000005; // V4 42000000003
        targetTokenIds[71] = 42000000006; // V4 42000000005
        targetTokenIds[72] = 42000000007; // V4 42000000006
        targetTokenIds[73] = 42000000008; // V4 42000000008
        targetTokenIds[74] = 42000000009; // V4 42000000009
        targetTokenIds[75] = 42000000010; // V4 42000000010
        targetTokenIds[76] = 42000000011; // V4 42000000011
        targetTokenIds[77] = 42000000012; // V4 42000000012
        targetTokenIds[78] = 42000000013; // V4 42000000013
        targetTokenIds[79] = 42000000014; // V4 42000000014
        targetTokenIds[80] = 42000000015; // V4 42000000015
        targetTokenIds[81] = 42000000016; // V4 42000000016
        targetTokenIds[82] = 42000000017; // V4 42000000017
        targetTokenIds[83] = 42000000018; // V4 42000000018
        targetTokenIds[84] = 42000000019; // V4 42000000019
        targetTokenIds[85] = 43000000008; // V4 43000000001
        targetTokenIds[86] = 43000000009; // V4 43000000002
        targetTokenIds[87] = 43000000010; // V4 43000000004
        targetTokenIds[88] = 43000000011; // V4 43000000009
        targetTokenIds[89] = 43000000012; // V4 43000000010
        targetTokenIds[90] = 43000000013; // V4 43000000011
        targetTokenIds[91] = 43000000014; // V4 43000000012
        targetTokenIds[92] = 43000000015; // V4 43000000013
        targetTokenIds[93] = 43000000016; // V4 43000000014
        targetTokenIds[94] = 43000000017; // V4 43000000015
        targetTokenIds[95] = 43000000018; // V4 43000000016
        targetTokenIds[96] = 44000000006; // V4 44000000002
        targetTokenIds[97] = 44000000007; // V4 44000000005
        targetTokenIds[98] = 44000000008; // V4 44000000006
        targetTokenIds[99] = 44000000009; // V4 44000000007
        targetTokenIds[100] = 44000000010; // V4 44000000010
        targetTokenIds[101] = 44000000011; // V4 44000000011
        targetTokenIds[102] = 44000000012; // V4 44000000012
        targetTokenIds[103] = 44000000013; // V4 44000000013
        targetTokenIds[104] = 44000000014; // V4 44000000014
        targetTokenIds[105] = 44000000015; // V4 44000000015
        targetTokenIds[106] = 44000000016; // V4 44000000016
        targetTokenIds[107] = 44000000017; // V4 44000000017
        targetTokenIds[108] = 44000000018; // V4 44000000018
        targetTokenIds[109] = 44000000019; // V4 44000000019
        targetTokenIds[110] = 44000000020; // V4 44000000020
        targetTokenIds[111] = 44000000021; // V4 44000000021
        targetTokenIds[112] = 44000000022; // V4 44000000022
        targetTokenIds[113] = 44000000023; // V4 44000000023
        targetTokenIds[114] = 44000000024; // V4 44000000024
        targetTokenIds[115] = 44000000025; // V4 44000000025
        targetTokenIds[116] = 44000000026; // V4 44000000026
        targetTokenIds[117] = 44000000027; // V4 44000000027
        targetTokenIds[118] = 44000000028; // V4 44000000028
        targetTokenIds[119] = 44000000029; // V4 44000000029
        targetTokenIds[120] = 44000000030; // V4 44000000030
        targetTokenIds[121] = 44000000031; // V4 44000000031
        targetTokenIds[122] = 44000000032; // V4 44000000032
        targetTokenIds[123] = 44000000033; // V4 44000000033
        targetTokenIds[124] = 44000000034; // V4 44000000034
        targetTokenIds[125] = 47000000003; // V4 47000000001
        targetTokenIds[126] = 47000000004; // V4 47000000002
        targetTokenIds[127] = 47000000005; // V4 47000000004
        targetTokenIds[128] = 47000000006; // V4 47000000006
        targetTokenIds[129] = 47000000007; // V4 47000000007
        targetTokenIds[130] = 47000000008; // V4 47000000008
        targetTokenIds[131] = 47000000009; // V4 47000000009
        targetTokenIds[132] = 47000000010; // V4 47000000010
        targetTokenIds[133] = 47000000011; // V4 47000000011
        targetTokenIds[134] = 47000000012; // V4 47000000012
        targetTokenIds[135] = 47000000013; // V4 47000000013
        targetTokenIds[136] = 47000000014; // V4 47000000014
        targetTokenIds[137] = 48000000006; // V4 48000000004
        targetTokenIds[138] = 49000000004; // V4 49000000003
        targetTokenIds[139] = 49000000005; // V4 49000000005
        targetTokenIds[140] = 49000000006; // V4 49000000006

        v4TokenIds[0] = 5000000003; // V4 5000000003
        v4TokenIds[1] = 5000000007; // V4 5000000007
        v4TokenIds[2] = 6000000005; // V4 6000000005
        v4TokenIds[3] = 6000000006; // V4 6000000006
        v4TokenIds[4] = 6000000007; // V4 6000000007
        v4TokenIds[5] = 6000000008; // V4 6000000008
        v4TokenIds[6] = 6000000009; // V4 6000000009
        v4TokenIds[7] = 10000000004; // V4 10000000004
        v4TokenIds[8] = 10000000008; // V4 10000000008
        v4TokenIds[9] = 10000000009; // V4 10000000009
        v4TokenIds[10] = 10000000010; // V4 10000000010
        v4TokenIds[11] = 10000000011; // V4 10000000011
        v4TokenIds[12] = 10000000013; // V4 10000000013
        v4TokenIds[13] = 10000000014; // V4 10000000014
        v4TokenIds[14] = 11000000001; // V4 11000000001
        v4TokenIds[15] = 13000000002; // V4 13000000002
        v4TokenIds[16] = 13000000004; // V4 13000000004
        v4TokenIds[17] = 14000000002; // V4 14000000002
        v4TokenIds[18] = 14000000004; // V4 14000000004
        v4TokenIds[19] = 14000000006; // V4 14000000006
        v4TokenIds[20] = 17000000003; // V4 17000000003
        v4TokenIds[21] = 17000000004; // V4 17000000004
        v4TokenIds[22] = 17000000005; // V4 17000000005
        v4TokenIds[23] = 19000000001; // V4 19000000001
        v4TokenIds[24] = 19000000003; // V4 19000000003
        v4TokenIds[25] = 19000000006; // V4 19000000006
        v4TokenIds[26] = 19000000007; // V4 19000000007
        v4TokenIds[27] = 19000000010; // V4 19000000010
        v4TokenIds[28] = 19000000014; // V4 19000000014
        v4TokenIds[29] = 19000000022; // V4 19000000022
        v4TokenIds[30] = 20000000002; // V4 20000000002
        v4TokenIds[31] = 20000000003; // V4 20000000003
        v4TokenIds[32] = 20000000004; // V4 20000000004
        v4TokenIds[33] = 20000000005; // V4 20000000005
        v4TokenIds[34] = 20000000006; // V4 20000000006
        v4TokenIds[35] = 20000000007; // V4 20000000007
        v4TokenIds[36] = 21000000002; // V4 21000000002
        v4TokenIds[37] = 23000000006; // V4 23000000006
        v4TokenIds[38] = 23000000008; // V4 23000000008
        v4TokenIds[39] = 25000000001; // V4 25000000001
        v4TokenIds[40] = 25000000004; // V4 25000000004
        v4TokenIds[41] = 25000000012; // V4 25000000012
        v4TokenIds[42] = 26000000006; // V4 26000000006
        v4TokenIds[43] = 26000000007; // V4 26000000007
        v4TokenIds[44] = 28000000001; // V4 28000000001
        v4TokenIds[45] = 28000000003; // V4 28000000003
        v4TokenIds[46] = 28000000004; // V4 28000000004
        v4TokenIds[47] = 28000000005; // V4 28000000005
        v4TokenIds[48] = 28000000006; // V4 28000000006
        v4TokenIds[49] = 28000000007; // V4 28000000007
        v4TokenIds[50] = 28000000009; // V4 28000000009
        v4TokenIds[51] = 29000000001; // V4 29000000001
        v4TokenIds[52] = 31000000001; // V4 31000000001
        v4TokenIds[53] = 31000000004; // V4 31000000004
        v4TokenIds[54] = 31000000005; // V4 31000000005
        v4TokenIds[55] = 31000000008; // V4 31000000008
        v4TokenIds[56] = 31000000012; // V4 31000000012
        v4TokenIds[57] = 32000000004; // V4 32000000004
        v4TokenIds[58] = 32000000005; // V4 32000000005
        v4TokenIds[59] = 33000000002; // V4 33000000002
        v4TokenIds[60] = 35000000005; // V4 35000000005
        v4TokenIds[61] = 35000000008; // V4 35000000008
        v4TokenIds[62] = 35000000009; // V4 35000000009
        v4TokenIds[63] = 37000000002; // V4 37000000002
        v4TokenIds[64] = 37000000004; // V4 37000000004
        v4TokenIds[65] = 39000000004; // V4 39000000004
        v4TokenIds[66] = 40000000002; // V4 40000000002
        v4TokenIds[67] = 40000000003; // V4 40000000003
        v4TokenIds[68] = 41000000005; // V4 41000000005
        v4TokenIds[69] = 42000000001; // V4 42000000001
        v4TokenIds[70] = 42000000003; // V4 42000000003
        v4TokenIds[71] = 42000000005; // V4 42000000005
        v4TokenIds[72] = 42000000006; // V4 42000000006
        v4TokenIds[73] = 42000000008; // V4 42000000008
        v4TokenIds[74] = 42000000009; // V4 42000000009
        v4TokenIds[75] = 42000000010; // V4 42000000010
        v4TokenIds[76] = 42000000011; // V4 42000000011
        v4TokenIds[77] = 42000000012; // V4 42000000012
        v4TokenIds[78] = 42000000013; // V4 42000000013
        v4TokenIds[79] = 42000000014; // V4 42000000014
        v4TokenIds[80] = 42000000015; // V4 42000000015
        v4TokenIds[81] = 42000000016; // V4 42000000016
        v4TokenIds[82] = 42000000017; // V4 42000000017
        v4TokenIds[83] = 42000000018; // V4 42000000018
        v4TokenIds[84] = 42000000019; // V4 42000000019
        v4TokenIds[85] = 43000000001; // V4 43000000001
        v4TokenIds[86] = 43000000002; // V4 43000000002
        v4TokenIds[87] = 43000000004; // V4 43000000004
        v4TokenIds[88] = 43000000009; // V4 43000000009
        v4TokenIds[89] = 43000000010; // V4 43000000010
        v4TokenIds[90] = 43000000011; // V4 43000000011
        v4TokenIds[91] = 43000000012; // V4 43000000012
        v4TokenIds[92] = 43000000013; // V4 43000000013
        v4TokenIds[93] = 43000000014; // V4 43000000014
        v4TokenIds[94] = 43000000015; // V4 43000000015
        v4TokenIds[95] = 43000000016; // V4 43000000016
        v4TokenIds[96] = 44000000002; // V4 44000000002
        v4TokenIds[97] = 44000000005; // V4 44000000005
        v4TokenIds[98] = 44000000006; // V4 44000000006
        v4TokenIds[99] = 44000000007; // V4 44000000007
        v4TokenIds[100] = 44000000010; // V4 44000000010
        v4TokenIds[101] = 44000000011; // V4 44000000011
        v4TokenIds[102] = 44000000012; // V4 44000000012
        v4TokenIds[103] = 44000000013; // V4 44000000013
        v4TokenIds[104] = 44000000014; // V4 44000000014
        v4TokenIds[105] = 44000000015; // V4 44000000015
        v4TokenIds[106] = 44000000016; // V4 44000000016
        v4TokenIds[107] = 44000000017; // V4 44000000017
        v4TokenIds[108] = 44000000018; // V4 44000000018
        v4TokenIds[109] = 44000000019; // V4 44000000019
        v4TokenIds[110] = 44000000020; // V4 44000000020
        v4TokenIds[111] = 44000000021; // V4 44000000021
        v4TokenIds[112] = 44000000022; // V4 44000000022
        v4TokenIds[113] = 44000000023; // V4 44000000023
        v4TokenIds[114] = 44000000024; // V4 44000000024
        v4TokenIds[115] = 44000000025; // V4 44000000025
        v4TokenIds[116] = 44000000026; // V4 44000000026
        v4TokenIds[117] = 44000000027; // V4 44000000027
        v4TokenIds[118] = 44000000028; // V4 44000000028
        v4TokenIds[119] = 44000000029; // V4 44000000029
        v4TokenIds[120] = 44000000030; // V4 44000000030
        v4TokenIds[121] = 44000000031; // V4 44000000031
        v4TokenIds[122] = 44000000032; // V4 44000000032
        v4TokenIds[123] = 44000000033; // V4 44000000033
        v4TokenIds[124] = 44000000034; // V4 44000000034
        v4TokenIds[125] = 47000000001; // V4 47000000001
        v4TokenIds[126] = 47000000002; // V4 47000000002
        v4TokenIds[127] = 47000000004; // V4 47000000004
        v4TokenIds[128] = 47000000006; // V4 47000000006
        v4TokenIds[129] = 47000000007; // V4 47000000007
        v4TokenIds[130] = 47000000008; // V4 47000000008
        v4TokenIds[131] = 47000000009; // V4 47000000009
        v4TokenIds[132] = 47000000010; // V4 47000000010
        v4TokenIds[133] = 47000000011; // V4 47000000011
        v4TokenIds[134] = 47000000012; // V4 47000000012
        v4TokenIds[135] = 47000000013; // V4 47000000013
        v4TokenIds[136] = 47000000014; // V4 47000000014
        v4TokenIds[137] = 48000000004; // V4 48000000004
        v4TokenIds[138] = 49000000003; // V4 49000000003
        v4TokenIds[139] = 49000000005; // V4 49000000005
        v4TokenIds[140] = 49000000006; // V4 49000000006


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

        require(successfulTransfers == 141, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
