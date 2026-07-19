// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysEthereum4 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 20, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 42, "Minted token count mismatch");
        require(mintedTokenIds[0] == 4000000028, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 4000000029, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000030, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 4000000031, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 4000000032, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 4000000033, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 4000000034, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 4000000035, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 4000000036, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 4000000037, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 4000000038, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 4000000039, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 4000000040, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000041, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000042, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000043, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000044, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000045, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 4000000046, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 4000000047, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 13000000001, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 16000000001, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 17000000002, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 19000000008, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 19000000009, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 23000000002, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 23000000003, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 23000000004, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 23000000005, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 25000000006, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 25000000007, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 31000000005, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 32000000003, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 33000000001, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 41000000001, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 41000000002, "Minted token ID mismatch");
        require(mintedTokenIds[36] == 41000000003, "Minted token ID mismatch");
        require(mintedTokenIds[37] == 41000000004, "Minted token ID mismatch");
        require(mintedTokenIds[38] == 42000000003, "Minted token ID mismatch");
        require(mintedTokenIds[39] == 43000000005, "Minted token ID mismatch");
        require(mintedTokenIds[40] == 48000000003, "Minted token ID mismatch");
        require(mintedTokenIds[41] == 48000000004, "Minted token ID mismatch");
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
            require(4000000028 == 4000000028, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000028
                );
            }
        }

        {
            require(4000000029 == 4000000029, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000029
                );
            }
        }

        {
            require(4000000030 == 4000000030, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000030
                );
            }
        }

        {
            require(4000000031 == 4000000031, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000031
                );
            }
        }

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
            // Dress Banny 4000000033 (Original)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 19000000008; // V4 19000000009
            outfitIds[1] = 43000000005; // V4 43000000008

            resolver.decorateBannyWith(address(hook), 4000000033, 0, outfitIds);
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
            // Dress Banny 4000000039 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 13000000001; // V4 13000000001
            outfitIds[1] = 19000000009; // V4 19000000011
            outfitIds[2] = 25000000006; // V4 25000000006
            outfitIds[3] = 42000000003; // V4 42000000004

            resolver.decorateBannyWith(address(hook), 4000000039, 0, outfitIds);
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
            // Dress Banny 4000000040 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 25000000007; // V4 25000000007

            resolver.decorateBannyWith(address(hook), 4000000040, 0, outfitIds);
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
            // Dress Banny 4000000041 (Original)
            uint256[] memory outfitIds = new uint256[](5);
            outfitIds[0] = 16000000001; // V4 16000000001
            outfitIds[1] = 17000000002; // V4 17000000002
            outfitIds[2] = 31000000005; // V4 31000000009
            outfitIds[3] = 33000000001; // V4 33000000001
            outfitIds[4] = 48000000003; // V4 48000000002

            resolver.decorateBannyWith(address(hook), 4000000041, 0, outfitIds);
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
            // Dress Banny 4000000043 (Original)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 32000000003; // V4 32000000003
            outfitIds[1] = 48000000004; // V4 48000000003

            resolver.decorateBannyWith(address(hook), 4000000043, 0, outfitIds);
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
            // Dress Banny 4000000044 (Original)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 23000000002; // V4 23000000002
            outfitIds[1] = 41000000001; // V4 41000000001

            resolver.decorateBannyWith(address(hook), 4000000044, 0, outfitIds);
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
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 23000000004; // V4 23000000004
            outfitIds[1] = 41000000003; // V4 41000000003

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
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 23000000005; // V4 23000000005
            outfitIds[1] = 41000000004; // V4 41000000004

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
            // Dress Banny 4000000047 (Original)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 23000000003; // V4 23000000003
            outfitIds[1] = 41000000002; // V4 41000000002

            resolver.decorateBannyWith(address(hook), 4000000047, 0, outfitIds);
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

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 4000000028; // V4 4000000028
        targetTokenIds[1] = 4000000029; // V4 4000000029
        targetTokenIds[2] = 4000000030; // V4 4000000030
        targetTokenIds[3] = 4000000031; // V4 4000000031
        targetTokenIds[4] = 4000000032; // V4 4000000032
        targetTokenIds[5] = 4000000033; // V4 4000000033
        targetTokenIds[6] = 4000000034; // V4 4000000034
        targetTokenIds[7] = 4000000035; // V4 4000000035
        targetTokenIds[8] = 4000000036; // V4 4000000036
        targetTokenIds[9] = 4000000037; // V4 4000000037
        targetTokenIds[10] = 4000000038; // V4 4000000038
        targetTokenIds[11] = 4000000039; // V4 4000000039
        targetTokenIds[12] = 4000000040; // V4 4000000040
        targetTokenIds[13] = 4000000041; // V4 4000000041
        targetTokenIds[14] = 4000000042; // V4 4000000042
        targetTokenIds[15] = 4000000043; // V4 4000000043
        targetTokenIds[16] = 4000000044; // V4 4000000044
        targetTokenIds[17] = 4000000045; // V4 4000000045
        targetTokenIds[18] = 4000000046; // V4 4000000046
        targetTokenIds[19] = 4000000047; // V4 4000000047

        v4TokenIds[0] = 4000000028; // V4 4000000028
        v4TokenIds[1] = 4000000029; // V4 4000000029
        v4TokenIds[2] = 4000000030; // V4 4000000030
        v4TokenIds[3] = 4000000031; // V4 4000000031
        v4TokenIds[4] = 4000000032; // V4 4000000032
        v4TokenIds[5] = 4000000033; // V4 4000000033
        v4TokenIds[6] = 4000000034; // V4 4000000034
        v4TokenIds[7] = 4000000035; // V4 4000000035
        v4TokenIds[8] = 4000000036; // V4 4000000036
        v4TokenIds[9] = 4000000037; // V4 4000000037
        v4TokenIds[10] = 4000000038; // V4 4000000038
        v4TokenIds[11] = 4000000039; // V4 4000000039
        v4TokenIds[12] = 4000000040; // V4 4000000040
        v4TokenIds[13] = 4000000041; // V4 4000000041
        v4TokenIds[14] = 4000000042; // V4 4000000042
        v4TokenIds[15] = 4000000043; // V4 4000000043
        v4TokenIds[16] = 4000000044; // V4 4000000044
        v4TokenIds[17] = 4000000045; // V4 4000000045
        v4TokenIds[18] = 4000000046; // V4 4000000046
        v4TokenIds[19] = 4000000047; // V4 4000000047


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
