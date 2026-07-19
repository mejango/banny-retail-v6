// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysBase3 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 22, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 34, "Minted token count mismatch");
        require(mintedTokenIds[0] == 4000000032, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 4000000033, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000034, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 4000000035, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 4000000036, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 4000000037, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 4000000038, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 4000000039, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 4000000040, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 4000000041, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 4000000042, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 4000000043, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 4000000044, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000045, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000046, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000047, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000048, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000049, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 4000000050, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 4000000051, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 4000000052, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 4000000053, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 10000000002, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 10000000003, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 10000000004, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 14000000003, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 19000000005, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 25000000005, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 28000000005, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 31000000002, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 38000000001, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 43000000002, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 43000000003, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 47000000003, "Minted token ID mismatch");
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
            require(4000000032 == 4000000032, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000032
                );
            }
        }

        {
            require(4000000033 == 4000000033, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000033
                );
            }
        }

        {
            require(4000000034 == 4000000034, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000034
                );
            }
        }

        {
            require(4000000035 == 4000000035, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000035
                );
            }
        }

        {
            require(4000000036 == 4000000036, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000036
                );
            }
        }

        {
            require(4000000037 == 4000000037, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000037
                );
            }
        }

        {
            require(4000000038 == 4000000038, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000038
                );
            }
        }

        {
            require(4000000039 == 4000000039, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000039
                );
            }
        }

        {
            require(4000000040 == 4000000040, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000040
                );
            }
        }

        {
            require(4000000041 == 4000000041, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000041
                );
            }
        }

        {
            require(4000000042 == 4000000042, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000042
                );
            }
        }

        {
            require(4000000043 == 4000000043, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000043
                );
            }
        }

        {
            require(4000000044 == 4000000044, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000044
                );
            }
        }

        {
            require(4000000045 == 4000000045, "Body token ID changed");
            // Dress Banny 4000000045 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 10000000002; // V4 10000000001
            outfitIds[1] = 25000000005; // V4 25000000002
            outfitIds[2] = 43000000002; // V4 43000000002

            resolver.decorateBannyWith(address(hook), 4000000045, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000045
                );
            }
        }

        {
            require(4000000046 == 4000000046, "Body token ID changed");
            // Dress Banny 4000000046 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 47000000003; // V4 47000000001

            resolver.decorateBannyWith(address(hook), 4000000046, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000046
                );
            }
        }

        {
            require(4000000047 == 4000000047, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000047
                );
            }
        }

        {
            require(4000000048 == 4000000048, "Body token ID changed");
            // Dress Banny 4000000048 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 10000000003; // V4 10000000003
            outfitIds[1] = 19000000005; // V4 19000000003
            outfitIds[2] = 28000000005; // V4 28000000004

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
            // Dress Banny 4000000049 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 10000000004; // V4 10000000004

            resolver.decorateBannyWith(address(hook), 4000000049, 0, outfitIds);
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
            // Dress Banny 4000000050 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 14000000003; // V4 14000000001
            outfitIds[1] = 31000000002; // V4 31000000001
            outfitIds[2] = 38000000001; // V4 38000000001
            outfitIds[3] = 43000000003; // V4 43000000003

            resolver.decorateBannyWith(address(hook), 4000000050, 0, outfitIds);
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

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 4000000032; // V4 4000000032
        targetTokenIds[1] = 4000000033; // V4 4000000033
        targetTokenIds[2] = 4000000034; // V4 4000000034
        targetTokenIds[3] = 4000000035; // V4 4000000035
        targetTokenIds[4] = 4000000036; // V4 4000000036
        targetTokenIds[5] = 4000000037; // V4 4000000037
        targetTokenIds[6] = 4000000038; // V4 4000000038
        targetTokenIds[7] = 4000000039; // V4 4000000039
        targetTokenIds[8] = 4000000040; // V4 4000000040
        targetTokenIds[9] = 4000000041; // V4 4000000041
        targetTokenIds[10] = 4000000042; // V4 4000000042
        targetTokenIds[11] = 4000000043; // V4 4000000043
        targetTokenIds[12] = 4000000044; // V4 4000000044
        targetTokenIds[13] = 4000000045; // V4 4000000045
        targetTokenIds[14] = 4000000046; // V4 4000000046
        targetTokenIds[15] = 4000000047; // V4 4000000047
        targetTokenIds[16] = 4000000048; // V4 4000000048
        targetTokenIds[17] = 4000000049; // V4 4000000049
        targetTokenIds[18] = 4000000050; // V4 4000000050
        targetTokenIds[19] = 4000000051; // V4 4000000051
        targetTokenIds[20] = 4000000052; // V4 4000000052
        targetTokenIds[21] = 4000000053; // V4 4000000053

        v4TokenIds[0] = 4000000032; // V4 4000000032
        v4TokenIds[1] = 4000000033; // V4 4000000033
        v4TokenIds[2] = 4000000034; // V4 4000000034
        v4TokenIds[3] = 4000000035; // V4 4000000035
        v4TokenIds[4] = 4000000036; // V4 4000000036
        v4TokenIds[5] = 4000000037; // V4 4000000037
        v4TokenIds[6] = 4000000038; // V4 4000000038
        v4TokenIds[7] = 4000000039; // V4 4000000039
        v4TokenIds[8] = 4000000040; // V4 4000000040
        v4TokenIds[9] = 4000000041; // V4 4000000041
        v4TokenIds[10] = 4000000042; // V4 4000000042
        v4TokenIds[11] = 4000000043; // V4 4000000043
        v4TokenIds[12] = 4000000044; // V4 4000000044
        v4TokenIds[13] = 4000000045; // V4 4000000045
        v4TokenIds[14] = 4000000046; // V4 4000000046
        v4TokenIds[15] = 4000000047; // V4 4000000047
        v4TokenIds[16] = 4000000048; // V4 4000000048
        v4TokenIds[17] = 4000000049; // V4 4000000049
        v4TokenIds[18] = 4000000050; // V4 4000000050
        v4TokenIds[19] = 4000000051; // V4 4000000051
        v4TokenIds[20] = 4000000052; // V4 4000000052
        v4TokenIds[21] = 4000000053; // V4 4000000053


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
