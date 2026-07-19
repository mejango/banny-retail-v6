// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysBase4 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 22, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 27, "Minted token count mismatch");
        require(mintedTokenIds[0] == 4000000054, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 4000000055, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000056, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 4000000057, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 4000000058, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 4000000059, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 4000000060, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 4000000061, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 4000000062, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 4000000063, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 4000000064, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 4000000065, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 4000000066, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000067, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000068, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000069, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000070, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000071, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 4000000072, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 4000000073, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 4000000074, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 4000000075, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 10000000005, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 19000000006, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 25000000006, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 25000000007, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 43000000004, "Minted token ID mismatch");
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
            require(4000000054 == 4000000054, "Body token ID changed");
            // Dress Banny 4000000054 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 25000000006; // V4 25000000005

            resolver.decorateBannyWith(address(hook), 4000000054, 0, outfitIds);
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

        {
            require(4000000068 == 4000000068, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000068
                );
            }
        }

        {
            require(4000000069 == 4000000069, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000069
                );
            }
        }

        {
            require(4000000070 == 4000000070, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000070
                );
            }
        }

        {
            require(4000000071 == 4000000071, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000071
                );
            }
        }

        {
            require(4000000072 == 4000000072, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000072
                );
            }
        }

        {
            require(4000000073 == 4000000073, "Body token ID changed");
            // Dress Banny 4000000073 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10000000005; // V4 10000000007
            outfitIds[1] = 19000000006; // V4 19000000006
            outfitIds[2] = 25000000007; // V4 25000000006
            outfitIds[3] = 43000000004; // V4 43000000005

            resolver.decorateBannyWith(address(hook), 4000000073, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000073
                );
            }
        }

        {
            require(4000000074 == 4000000074, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000074
                );
            }
        }

        {
            require(4000000075 == 4000000075, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000075
                );
            }
        }

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 4000000054; // V4 4000000054
        targetTokenIds[1] = 4000000055; // V4 4000000055
        targetTokenIds[2] = 4000000056; // V4 4000000056
        targetTokenIds[3] = 4000000057; // V4 4000000057
        targetTokenIds[4] = 4000000058; // V4 4000000058
        targetTokenIds[5] = 4000000059; // V4 4000000059
        targetTokenIds[6] = 4000000060; // V4 4000000060
        targetTokenIds[7] = 4000000061; // V4 4000000061
        targetTokenIds[8] = 4000000062; // V4 4000000062
        targetTokenIds[9] = 4000000063; // V4 4000000063
        targetTokenIds[10] = 4000000064; // V4 4000000064
        targetTokenIds[11] = 4000000065; // V4 4000000065
        targetTokenIds[12] = 4000000066; // V4 4000000066
        targetTokenIds[13] = 4000000067; // V4 4000000067
        targetTokenIds[14] = 4000000068; // V4 4000000068
        targetTokenIds[15] = 4000000069; // V4 4000000069
        targetTokenIds[16] = 4000000070; // V4 4000000070
        targetTokenIds[17] = 4000000071; // V4 4000000071
        targetTokenIds[18] = 4000000072; // V4 4000000072
        targetTokenIds[19] = 4000000073; // V4 4000000073
        targetTokenIds[20] = 4000000074; // V4 4000000074
        targetTokenIds[21] = 4000000075; // V4 4000000075

        v4TokenIds[0] = 4000000054; // V4 4000000054
        v4TokenIds[1] = 4000000055; // V4 4000000055
        v4TokenIds[2] = 4000000056; // V4 4000000056
        v4TokenIds[3] = 4000000057; // V4 4000000057
        v4TokenIds[4] = 4000000058; // V4 4000000058
        v4TokenIds[5] = 4000000059; // V4 4000000059
        v4TokenIds[6] = 4000000060; // V4 4000000060
        v4TokenIds[7] = 4000000061; // V4 4000000061
        v4TokenIds[8] = 4000000062; // V4 4000000062
        v4TokenIds[9] = 4000000063; // V4 4000000063
        v4TokenIds[10] = 4000000064; // V4 4000000064
        v4TokenIds[11] = 4000000065; // V4 4000000065
        v4TokenIds[12] = 4000000066; // V4 4000000066
        v4TokenIds[13] = 4000000067; // V4 4000000067
        v4TokenIds[14] = 4000000068; // V4 4000000068
        v4TokenIds[15] = 4000000069; // V4 4000000069
        v4TokenIds[16] = 4000000070; // V4 4000000070
        v4TokenIds[17] = 4000000071; // V4 4000000071
        v4TokenIds[18] = 4000000072; // V4 4000000072
        v4TokenIds[19] = 4000000073; // V4 4000000073
        v4TokenIds[20] = 4000000074; // V4 4000000074
        v4TokenIds[21] = 4000000075; // V4 4000000075


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

        require(successfulTransfers == 22, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
