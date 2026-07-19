// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysBase6 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 53, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 53, "Minted token count mismatch");
        require(mintedTokenIds[0] == 5000000004, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 5000000005, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 6000000005, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 7000000001, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 10000000006, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 10000000007, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 10000000008, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 10000000009, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 10000000010, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 10000000011, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 11000000002, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 11000000003, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 13000000002, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 14000000004, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 17000000001, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 19000000008, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 19000000009, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 19000000010, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 19000000011, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 19000000012, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 24000000001, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 25000000009, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 28000000007, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 28000000008, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 28000000009, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 28000000010, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 31000000003, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 31000000004, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 31000000005, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 31000000006, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 32000000002, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 34000000001, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 35000000002, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 35000000003, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 35000000004, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 38000000003, "Minted token ID mismatch");
        require(mintedTokenIds[36] == 39000000002, "Minted token ID mismatch");
        require(mintedTokenIds[37] == 40000000002, "Minted token ID mismatch");
        require(mintedTokenIds[38] == 40000000003, "Minted token ID mismatch");
        require(mintedTokenIds[39] == 41000000002, "Minted token ID mismatch");
        require(mintedTokenIds[40] == 42000000001, "Minted token ID mismatch");
        require(mintedTokenIds[41] == 42000000002, "Minted token ID mismatch");
        require(mintedTokenIds[42] == 43000000007, "Minted token ID mismatch");
        require(mintedTokenIds[43] == 43000000008, "Minted token ID mismatch");
        require(mintedTokenIds[44] == 44000000004, "Minted token ID mismatch");
        require(mintedTokenIds[45] == 44000000005, "Minted token ID mismatch");
        require(mintedTokenIds[46] == 47000000004, "Minted token ID mismatch");
        require(mintedTokenIds[47] == 47000000005, "Minted token ID mismatch");
        require(mintedTokenIds[48] == 47000000006, "Minted token ID mismatch");
        require(mintedTokenIds[49] == 47000000007, "Minted token ID mismatch");
        require(mintedTokenIds[50] == 47000000008, "Minted token ID mismatch");
        require(mintedTokenIds[51] == 49000000001, "Minted token ID mismatch");
        require(mintedTokenIds[52] == 49000000002, "Minted token ID mismatch");
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
        targetTokenIds[0] = 5000000004; // V4 5000000002
        targetTokenIds[1] = 5000000005; // V4 5000000005
        targetTokenIds[2] = 6000000005; // V4 6000000002
        targetTokenIds[3] = 7000000001; // V4 7000000001
        targetTokenIds[4] = 10000000006; // V4 10000000002
        targetTokenIds[5] = 10000000007; // V4 10000000006
        targetTokenIds[6] = 10000000008; // V4 10000000008
        targetTokenIds[7] = 10000000009; // V4 10000000009
        targetTokenIds[8] = 10000000010; // V4 10000000010
        targetTokenIds[9] = 10000000011; // V4 10000000011
        targetTokenIds[10] = 11000000002; // V4 11000000002
        targetTokenIds[11] = 11000000003; // V4 11000000003
        targetTokenIds[12] = 13000000002; // V4 13000000002
        targetTokenIds[13] = 14000000004; // V4 14000000004
        targetTokenIds[14] = 17000000001; // V4 17000000001
        targetTokenIds[15] = 19000000008; // V4 19000000002
        targetTokenIds[16] = 19000000009; // V4 19000000004
        targetTokenIds[17] = 19000000010; // V4 19000000010
        targetTokenIds[18] = 19000000011; // V4 19000000011
        targetTokenIds[19] = 19000000012; // V4 19000000012
        targetTokenIds[20] = 24000000001; // V4 24000000001
        targetTokenIds[21] = 25000000009; // V4 25000000003
        targetTokenIds[22] = 28000000007; // V4 28000000003
        targetTokenIds[23] = 28000000008; // V4 28000000006
        targetTokenIds[24] = 28000000009; // V4 28000000009
        targetTokenIds[25] = 28000000010; // V4 28000000010
        targetTokenIds[26] = 31000000003; // V4 31000000003
        targetTokenIds[27] = 31000000004; // V4 31000000004
        targetTokenIds[28] = 31000000005; // V4 31000000005
        targetTokenIds[29] = 31000000006; // V4 31000000006
        targetTokenIds[30] = 32000000002; // V4 32000000002
        targetTokenIds[31] = 34000000001; // V4 34000000001
        targetTokenIds[32] = 35000000002; // V4 35000000001
        targetTokenIds[33] = 35000000003; // V4 35000000003
        targetTokenIds[34] = 35000000004; // V4 35000000004
        targetTokenIds[35] = 38000000003; // V4 38000000003
        targetTokenIds[36] = 39000000002; // V4 39000000002
        targetTokenIds[37] = 40000000002; // V4 40000000002
        targetTokenIds[38] = 40000000003; // V4 40000000003
        targetTokenIds[39] = 41000000002; // V4 41000000002
        targetTokenIds[40] = 42000000001; // V4 42000000001
        targetTokenIds[41] = 42000000002; // V4 42000000002
        targetTokenIds[42] = 43000000007; // V4 43000000001
        targetTokenIds[43] = 43000000008; // V4 43000000004
        targetTokenIds[44] = 44000000004; // V4 44000000002
        targetTokenIds[45] = 44000000005; // V4 44000000003
        targetTokenIds[46] = 47000000004; // V4 47000000002
        targetTokenIds[47] = 47000000005; // V4 47000000004
        targetTokenIds[48] = 47000000006; // V4 47000000006
        targetTokenIds[49] = 47000000007; // V4 47000000007
        targetTokenIds[50] = 47000000008; // V4 47000000008
        targetTokenIds[51] = 49000000001; // V4 49000000001
        targetTokenIds[52] = 49000000002; // V4 49000000002

        v4TokenIds[0] = 5000000002; // V4 5000000002
        v4TokenIds[1] = 5000000005; // V4 5000000005
        v4TokenIds[2] = 6000000002; // V4 6000000002
        v4TokenIds[3] = 7000000001; // V4 7000000001
        v4TokenIds[4] = 10000000002; // V4 10000000002
        v4TokenIds[5] = 10000000006; // V4 10000000006
        v4TokenIds[6] = 10000000008; // V4 10000000008
        v4TokenIds[7] = 10000000009; // V4 10000000009
        v4TokenIds[8] = 10000000010; // V4 10000000010
        v4TokenIds[9] = 10000000011; // V4 10000000011
        v4TokenIds[10] = 11000000002; // V4 11000000002
        v4TokenIds[11] = 11000000003; // V4 11000000003
        v4TokenIds[12] = 13000000002; // V4 13000000002
        v4TokenIds[13] = 14000000004; // V4 14000000004
        v4TokenIds[14] = 17000000001; // V4 17000000001
        v4TokenIds[15] = 19000000002; // V4 19000000002
        v4TokenIds[16] = 19000000004; // V4 19000000004
        v4TokenIds[17] = 19000000010; // V4 19000000010
        v4TokenIds[18] = 19000000011; // V4 19000000011
        v4TokenIds[19] = 19000000012; // V4 19000000012
        v4TokenIds[20] = 24000000001; // V4 24000000001
        v4TokenIds[21] = 25000000003; // V4 25000000003
        v4TokenIds[22] = 28000000003; // V4 28000000003
        v4TokenIds[23] = 28000000006; // V4 28000000006
        v4TokenIds[24] = 28000000009; // V4 28000000009
        v4TokenIds[25] = 28000000010; // V4 28000000010
        v4TokenIds[26] = 31000000003; // V4 31000000003
        v4TokenIds[27] = 31000000004; // V4 31000000004
        v4TokenIds[28] = 31000000005; // V4 31000000005
        v4TokenIds[29] = 31000000006; // V4 31000000006
        v4TokenIds[30] = 32000000002; // V4 32000000002
        v4TokenIds[31] = 34000000001; // V4 34000000001
        v4TokenIds[32] = 35000000001; // V4 35000000001
        v4TokenIds[33] = 35000000003; // V4 35000000003
        v4TokenIds[34] = 35000000004; // V4 35000000004
        v4TokenIds[35] = 38000000003; // V4 38000000003
        v4TokenIds[36] = 39000000002; // V4 39000000002
        v4TokenIds[37] = 40000000002; // V4 40000000002
        v4TokenIds[38] = 40000000003; // V4 40000000003
        v4TokenIds[39] = 41000000002; // V4 41000000002
        v4TokenIds[40] = 42000000001; // V4 42000000001
        v4TokenIds[41] = 42000000002; // V4 42000000002
        v4TokenIds[42] = 43000000001; // V4 43000000001
        v4TokenIds[43] = 43000000004; // V4 43000000004
        v4TokenIds[44] = 44000000002; // V4 44000000002
        v4TokenIds[45] = 44000000003; // V4 44000000003
        v4TokenIds[46] = 47000000002; // V4 47000000002
        v4TokenIds[47] = 47000000004; // V4 47000000004
        v4TokenIds[48] = 47000000006; // V4 47000000006
        v4TokenIds[49] = 47000000007; // V4 47000000007
        v4TokenIds[50] = 47000000008; // V4 47000000008
        v4TokenIds[51] = 49000000001; // V4 49000000001
        v4TokenIds[52] = 49000000002; // V4 49000000002


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

        require(successfulTransfers == 53, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
