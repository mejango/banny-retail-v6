// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysEthereum6 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 18, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 31, "Minted token count mismatch");
        require(mintedTokenIds[0] == 4000000068, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 4000000069, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000070, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 4000000071, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 4000000072, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 4000000073, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 4000000074, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 4000000075, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 4000000076, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 4000000077, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 4000000078, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 4000000079, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 4000000080, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000081, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000082, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000083, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000084, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000085, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 6000000008, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 15000000005, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 19000000013, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 19000000014, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 19000000015, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 25000000008, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 25000000009, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 29000000002, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 31000000007, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 31000000008, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 38000000003, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 43000000006, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 43000000007, "Minted token ID mismatch");
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

        {
            require(4000000076 == 4000000076, "Body token ID changed");
            // Dress Banny 4000000076 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19000000013; // V4 19000000018
            outfitIds[1] = 29000000002; // V4 29000000002
            outfitIds[2] = 38000000003; // V4 38000000001

            resolver.decorateBannyWith(address(hook), 4000000076, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000076
                );
            }
        }

        {
            require(4000000077 == 4000000077, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000077
                );
            }
        }

        {
            require(4000000078 == 4000000078, "Body token ID changed");
            // Dress Banny 4000000078 (Original)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 31000000007; // V4 31000000011
            outfitIds[1] = 43000000006; // V4 43000000017

            resolver.decorateBannyWith(address(hook), 4000000078, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000078
                );
            }
        }

        {
            require(4000000079 == 4000000079, "Body token ID changed");
            // Dress Banny 4000000079 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19000000014; // V4 19000000020
            outfitIds[1] = 25000000008; // V4 25000000010
            outfitIds[2] = 43000000007; // V4 43000000018

            resolver.decorateBannyWith(address(hook), 4000000079, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000079
                );
            }
        }

        {
            require(4000000080 == 4000000080, "Body token ID changed");
            // Dress Banny 4000000080 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 15000000005; // V4 15000000005
            outfitIds[1] = 19000000015; // V4 19000000021
            outfitIds[2] = 25000000009; // V4 25000000011

            resolver.decorateBannyWith(address(hook), 4000000080, 6000000008, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000080
                );
            }
        }

        {
            require(4000000081 == 4000000081, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000081
                );
            }
        }

        {
            require(4000000082 == 4000000082, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000082
                );
            }
        }

        {
            require(4000000083 == 4000000083, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000083
                );
            }
        }

        {
            require(4000000084 == 4000000084, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000084
                );
            }
        }

        {
            require(4000000085 == 4000000085, "Body token ID changed");
            // Dress Banny 4000000085 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 31000000008; // V4 31000000013

            resolver.decorateBannyWith(address(hook), 4000000085, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000085
                );
            }
        }

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 4000000068; // V4 4000000068
        targetTokenIds[1] = 4000000069; // V4 4000000069
        targetTokenIds[2] = 4000000070; // V4 4000000070
        targetTokenIds[3] = 4000000071; // V4 4000000071
        targetTokenIds[4] = 4000000072; // V4 4000000072
        targetTokenIds[5] = 4000000073; // V4 4000000073
        targetTokenIds[6] = 4000000074; // V4 4000000074
        targetTokenIds[7] = 4000000075; // V4 4000000075
        targetTokenIds[8] = 4000000076; // V4 4000000076
        targetTokenIds[9] = 4000000077; // V4 4000000077
        targetTokenIds[10] = 4000000078; // V4 4000000078
        targetTokenIds[11] = 4000000079; // V4 4000000079
        targetTokenIds[12] = 4000000080; // V4 4000000080
        targetTokenIds[13] = 4000000081; // V4 4000000081
        targetTokenIds[14] = 4000000082; // V4 4000000082
        targetTokenIds[15] = 4000000083; // V4 4000000083
        targetTokenIds[16] = 4000000084; // V4 4000000084
        targetTokenIds[17] = 4000000085; // V4 4000000085

        v4TokenIds[0] = 4000000068; // V4 4000000068
        v4TokenIds[1] = 4000000069; // V4 4000000069
        v4TokenIds[2] = 4000000070; // V4 4000000070
        v4TokenIds[3] = 4000000071; // V4 4000000071
        v4TokenIds[4] = 4000000072; // V4 4000000072
        v4TokenIds[5] = 4000000073; // V4 4000000073
        v4TokenIds[6] = 4000000074; // V4 4000000074
        v4TokenIds[7] = 4000000075; // V4 4000000075
        v4TokenIds[8] = 4000000076; // V4 4000000076
        v4TokenIds[9] = 4000000077; // V4 4000000077
        v4TokenIds[10] = 4000000078; // V4 4000000078
        v4TokenIds[11] = 4000000079; // V4 4000000079
        v4TokenIds[12] = 4000000080; // V4 4000000080
        v4TokenIds[13] = 4000000081; // V4 4000000081
        v4TokenIds[14] = 4000000082; // V4 4000000082
        v4TokenIds[15] = 4000000083; // V4 4000000083
        v4TokenIds[16] = 4000000084; // V4 4000000084
        v4TokenIds[17] = 4000000085; // V4 4000000085


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

        require(successfulTransfers == 18, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
