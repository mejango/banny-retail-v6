// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysEthereum5 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 20, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 44, "Minted token count mismatch");
        require(mintedTokenIds[0] == 4000000048, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 4000000049, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000050, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 4000000051, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 4000000052, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 4000000053, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 4000000054, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 4000000055, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 4000000056, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 4000000057, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 4000000058, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 4000000059, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 4000000060, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000061, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000062, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000063, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000064, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000065, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 4000000066, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 4000000067, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 5000000006, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 6000000007, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 10000000006, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 13000000002, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 15000000003, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 15000000004, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 18000000003, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 19000000010, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 19000000011, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 19000000012, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 20000000002, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 23000000006, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 26000000005, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 28000000002, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 31000000006, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 35000000006, "Minted token ID mismatch");
        require(mintedTokenIds[36] == 38000000002, "Minted token ID mismatch");
        require(mintedTokenIds[37] == 39000000003, "Minted token ID mismatch");
        require(mintedTokenIds[38] == 40000000001, "Minted token ID mismatch");
        require(mintedTokenIds[39] == 44000000004, "Minted token ID mismatch");
        require(mintedTokenIds[40] == 44000000005, "Minted token ID mismatch");
        require(mintedTokenIds[41] == 47000000002, "Minted token ID mismatch");
        require(mintedTokenIds[42] == 48000000005, "Minted token ID mismatch");
        require(mintedTokenIds[43] == 49000000003, "Minted token ID mismatch");
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
        Banny721TokenUriResolver resolver = Banny721TokenUriResolver(resolverAddress);
        Banny721TokenUriResolver v4Resolver = Banny721TokenUriResolver(v4ResolverAddress);
        Banny721TokenUriResolver fallbackV4Resolver = Banny721TokenUriResolver(fallbackV4ResolverAddress);

        token.setApprovalForAll(address(resolver), true);

        {
            require(4000000048 == 4000000048, "Body token ID changed");
            // Dress Banny 4000000048 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 19000000010; // V4 19000000013
            outfitIds[1] = 31000000006; // V4 31000000010
            outfitIds[2] = 35000000006; // V4 35000000007
            outfitIds[3] = 47000000002; // V4 47000000005

            resolver.decorateBannyWith(address(hook), 4000000048, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000048
                );
            }
        }

        {
            require(4000000049 == 4000000049, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000049
                );
            }
        }

        {
            require(4000000050 == 4000000050, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000050
                );
            }
        }

        {
            require(4000000051 == 4000000051, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000051
                );
            }
        }

        {
            require(4000000052 == 4000000052, "Body token ID changed");
            // Dress Banny 4000000052 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 10000000006; // V4 10000000012
            outfitIds[1] = 18000000003; // V4 18000000003
            outfitIds[2] = 20000000002; // V4 20000000008

            resolver.decorateBannyWith(address(hook), 4000000052, 5000000006, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000052
                );
            }
        }

        {
            require(4000000053 == 4000000053, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000053
                );
            }
        }

        {
            require(4000000054 == 4000000054, "Body token ID changed");
            // Dress Banny 4000000054 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 15000000003; // V4 15000000002
            outfitIds[1] = 26000000005; // V4 26000000005
            outfitIds[2] = 44000000004; // V4 44000000008

            resolver.decorateBannyWith(address(hook), 4000000054, 6000000007, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000054
                );
            }
        }

        {
            require(4000000055 == 4000000055, "Body token ID changed");
            // Dress Banny 4000000055 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19000000011; // V4 19000000016
            outfitIds[1] = 39000000003; // V4 39000000002
            outfitIds[2] = 44000000005; // V4 44000000009

            resolver.decorateBannyWith(address(hook), 4000000055, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000055
                );
            }
        }

        {
            require(4000000056 == 4000000056, "Body token ID changed");
            // Dress Banny 4000000056 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 15000000004; // V4 15000000003
            outfitIds[1] = 23000000006; // V4 23000000007
            outfitIds[2] = 40000000001; // V4 40000000001
            outfitIds[3] = 49000000003; // V4 49000000004

            resolver.decorateBannyWith(address(hook), 4000000056, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000056
                );
            }
        }

        {
            require(4000000057 == 4000000057, "Body token ID changed");
            // Dress Banny 4000000057 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19000000012; // V4 19000000017
            outfitIds[1] = 28000000002; // V4 28000000008
            outfitIds[2] = 38000000002; // V4 38000000003

            resolver.decorateBannyWith(address(hook), 4000000057, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000057
                );
            }
        }

        {
            require(4000000058 == 4000000058, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000058
                );
            }
        }

        {
            require(4000000059 == 4000000059, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000059
                );
            }
        }

        {
            require(4000000060 == 4000000060, "Body token ID changed");
            // Dress Banny 4000000060 (Original)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 13000000002; // V4 13000000003
            outfitIds[1] = 48000000005; // V4 48000000006

            resolver.decorateBannyWith(address(hook), 4000000060, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000060
                );
            }
        }

        {
            require(4000000061 == 4000000061, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000061
                );
            }
        }

        {
            require(4000000062 == 4000000062, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000062
                );
            }
        }

        {
            require(4000000063 == 4000000063, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000063
                );
            }
        }

        {
            require(4000000064 == 4000000064, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000064
                );
            }
        }

        {
            require(4000000065 == 4000000065, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000065
                );
            }
        }

        {
            require(4000000066 == 4000000066, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000066
                );
            }
        }

        {
            require(4000000067 == 4000000067, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000067
                );
            }
        }

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 4000000048; // V4 4000000048
        targetTokenIds[1] = 4000000049; // V4 4000000049
        targetTokenIds[2] = 4000000050; // V4 4000000050
        targetTokenIds[3] = 4000000051; // V4 4000000051
        targetTokenIds[4] = 4000000052; // V4 4000000052
        targetTokenIds[5] = 4000000053; // V4 4000000053
        targetTokenIds[6] = 4000000054; // V4 4000000054
        targetTokenIds[7] = 4000000055; // V4 4000000055
        targetTokenIds[8] = 4000000056; // V4 4000000056
        targetTokenIds[9] = 4000000057; // V4 4000000057
        targetTokenIds[10] = 4000000058; // V4 4000000058
        targetTokenIds[11] = 4000000059; // V4 4000000059
        targetTokenIds[12] = 4000000060; // V4 4000000060
        targetTokenIds[13] = 4000000061; // V4 4000000061
        targetTokenIds[14] = 4000000062; // V4 4000000062
        targetTokenIds[15] = 4000000063; // V4 4000000063
        targetTokenIds[16] = 4000000064; // V4 4000000064
        targetTokenIds[17] = 4000000065; // V4 4000000065
        targetTokenIds[18] = 4000000066; // V4 4000000066
        targetTokenIds[19] = 4000000067; // V4 4000000067

        v4TokenIds[0] = 4000000048; // V4 4000000048
        v4TokenIds[1] = 4000000049; // V4 4000000049
        v4TokenIds[2] = 4000000050; // V4 4000000050
        v4TokenIds[3] = 4000000051; // V4 4000000051
        v4TokenIds[4] = 4000000052; // V4 4000000052
        v4TokenIds[5] = 4000000053; // V4 4000000053
        v4TokenIds[6] = 4000000054; // V4 4000000054
        v4TokenIds[7] = 4000000055; // V4 4000000055
        v4TokenIds[8] = 4000000056; // V4 4000000056
        v4TokenIds[9] = 4000000057; // V4 4000000057
        v4TokenIds[10] = 4000000058; // V4 4000000058
        v4TokenIds[11] = 4000000059; // V4 4000000059
        v4TokenIds[12] = 4000000060; // V4 4000000060
        v4TokenIds[13] = 4000000061; // V4 4000000061
        v4TokenIds[14] = 4000000062; // V4 4000000062
        v4TokenIds[15] = 4000000063; // V4 4000000063
        v4TokenIds[16] = 4000000064; // V4 4000000064
        v4TokenIds[17] = 4000000065; // V4 4000000065
        v4TokenIds[18] = 4000000066; // V4 4000000066
        v4TokenIds[19] = 4000000067; // V4 4000000067


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

        require(successfulTransfers == 20, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
