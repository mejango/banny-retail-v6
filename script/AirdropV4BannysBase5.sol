// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysBase5 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 19, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 35, "Minted token count mismatch");
        require(mintedTokenIds[0] == 4000000076, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 4000000077, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000078, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 4000000079, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 4000000080, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 4000000081, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 4000000082, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 4000000083, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 4000000084, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 4000000085, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 4000000086, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 4000000087, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 4000000088, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000089, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000090, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000091, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000092, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000093, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 4000000094, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 5000000002, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 5000000003, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 13000000001, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 19000000007, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 20000000001, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 25000000008, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 27000000001, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 28000000006, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 35000000001, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 38000000002, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 39000000001, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 41000000001, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 43000000005, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 43000000006, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 44000000003, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 48000000001, "Minted token ID mismatch");
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
            require(4000000076 == 4000000076, "Body token ID changed");
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
            outfitIds[0] = 27000000001; // V4 27000000001
            outfitIds[1] = 38000000002; // V4 38000000002
            outfitIds[2] = 48000000001; // V4 48000000001

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
            outfitIds[0] = 13000000001; // V4 13000000001
            outfitIds[1] = 20000000001; // V4 20000000001
            outfitIds[2] = 44000000003; // V4 44000000004

            resolver.decorateBannyWith(address(hook), 4000000080, 5000000002, outfitIds);
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
            // Dress Banny 4000000081 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 19000000007; // V4 19000000008
            outfitIds[1] = 25000000008; // V4 25000000007
            outfitIds[2] = 35000000001; // V4 35000000002
            outfitIds[3] = 43000000005; // V4 43000000006

            resolver.decorateBannyWith(address(hook), 4000000081, 0, outfitIds);
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
            // Dress Banny 4000000082 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 43000000006; // V4 43000000007

            resolver.decorateBannyWith(address(hook), 4000000082, 0, outfitIds);
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
            // Dress Banny 4000000084 (Original)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 39000000001; // V4 39000000001
            outfitIds[1] = 41000000001; // V4 41000000001

            resolver.decorateBannyWith(address(hook), 4000000084, 5000000003, outfitIds);
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
            outfitIds[0] = 28000000006; // V4 28000000008

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

        {
            require(4000000086 == 4000000086, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000086
                );
            }
        }

        {
            require(4000000087 == 4000000087, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000087
                );
            }
        }

        {
            require(4000000088 == 4000000088, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000088
                );
            }
        }

        {
            require(4000000089 == 4000000089, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000089
                );
            }
        }

        {
            require(4000000090 == 4000000090, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000090
                );
            }
        }

        {
            require(4000000091 == 4000000091, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000091
                );
            }
        }

        {
            require(4000000092 == 4000000092, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000092
                );
            }
        }

        {
            require(4000000093 == 4000000093, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000093
                );
            }
        }

        {
            require(4000000094 == 4000000094, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000094
                );
            }
        }

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 4000000076; // V4 4000000076
        targetTokenIds[1] = 4000000077; // V4 4000000077
        targetTokenIds[2] = 4000000078; // V4 4000000078
        targetTokenIds[3] = 4000000079; // V4 4000000079
        targetTokenIds[4] = 4000000080; // V4 4000000080
        targetTokenIds[5] = 4000000081; // V4 4000000081
        targetTokenIds[6] = 4000000082; // V4 4000000082
        targetTokenIds[7] = 4000000083; // V4 4000000083
        targetTokenIds[8] = 4000000084; // V4 4000000084
        targetTokenIds[9] = 4000000085; // V4 4000000085
        targetTokenIds[10] = 4000000086; // V4 4000000086
        targetTokenIds[11] = 4000000087; // V4 4000000087
        targetTokenIds[12] = 4000000088; // V4 4000000088
        targetTokenIds[13] = 4000000089; // V4 4000000089
        targetTokenIds[14] = 4000000090; // V4 4000000090
        targetTokenIds[15] = 4000000091; // V4 4000000091
        targetTokenIds[16] = 4000000092; // V4 4000000092
        targetTokenIds[17] = 4000000093; // V4 4000000093
        targetTokenIds[18] = 4000000094; // V4 4000000094

        v4TokenIds[0] = 4000000076; // V4 4000000076
        v4TokenIds[1] = 4000000077; // V4 4000000077
        v4TokenIds[2] = 4000000078; // V4 4000000078
        v4TokenIds[3] = 4000000079; // V4 4000000079
        v4TokenIds[4] = 4000000080; // V4 4000000080
        v4TokenIds[5] = 4000000081; // V4 4000000081
        v4TokenIds[6] = 4000000082; // V4 4000000082
        v4TokenIds[7] = 4000000083; // V4 4000000083
        v4TokenIds[8] = 4000000084; // V4 4000000084
        v4TokenIds[9] = 4000000085; // V4 4000000085
        v4TokenIds[10] = 4000000086; // V4 4000000086
        v4TokenIds[11] = 4000000087; // V4 4000000087
        v4TokenIds[12] = 4000000088; // V4 4000000088
        v4TokenIds[13] = 4000000089; // V4 4000000089
        v4TokenIds[14] = 4000000090; // V4 4000000090
        v4TokenIds[15] = 4000000091; // V4 4000000091
        v4TokenIds[16] = 4000000092; // V4 4000000092
        v4TokenIds[17] = 4000000093; // V4 4000000093
        v4TokenIds[18] = 4000000094; // V4 4000000094


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

        require(successfulTransfers == 19, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
