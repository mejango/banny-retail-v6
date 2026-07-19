// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysEthereum1 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 20, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 60, "Minted token count mismatch");
        require(mintedTokenIds[0] == 1000000001, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 2000000001, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 2000000002, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 2000000003, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 2000000004, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 2000000005, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 2000000006, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 3000000001, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 3000000002, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 3000000003, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 3000000004, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 3000000005, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 3000000006, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 3000000007, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 3000000008, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 3000000009, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 3000000010, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 3000000011, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 3000000012, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 3000000013, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 5000000001, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 5000000002, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 5000000003, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 6000000001, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 6000000002, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 6000000003, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 7000000001, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 7000000002, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 10000000001, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 14000000001, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 14000000002, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 17000000001, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 18000000001, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 19000000001, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 19000000002, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 19000000003, "Minted token ID mismatch");
        require(mintedTokenIds[36] == 21000000001, "Minted token ID mismatch");
        require(mintedTokenIds[37] == 23000000001, "Minted token ID mismatch");
        require(mintedTokenIds[38] == 25000000001, "Minted token ID mismatch");
        require(mintedTokenIds[39] == 26000000001, "Minted token ID mismatch");
        require(mintedTokenIds[40] == 26000000002, "Minted token ID mismatch");
        require(mintedTokenIds[41] == 26000000003, "Minted token ID mismatch");
        require(mintedTokenIds[42] == 31000000001, "Minted token ID mismatch");
        require(mintedTokenIds[43] == 31000000002, "Minted token ID mismatch");
        require(mintedTokenIds[44] == 32000000001, "Minted token ID mismatch");
        require(mintedTokenIds[45] == 32000000002, "Minted token ID mismatch");
        require(mintedTokenIds[46] == 35000000001, "Minted token ID mismatch");
        require(mintedTokenIds[47] == 35000000002, "Minted token ID mismatch");
        require(mintedTokenIds[48] == 35000000003, "Minted token ID mismatch");
        require(mintedTokenIds[49] == 35000000004, "Minted token ID mismatch");
        require(mintedTokenIds[50] == 37000000001, "Minted token ID mismatch");
        require(mintedTokenIds[51] == 39000000001, "Minted token ID mismatch");
        require(mintedTokenIds[52] == 43000000001, "Minted token ID mismatch");
        require(mintedTokenIds[53] == 43000000002, "Minted token ID mismatch");
        require(mintedTokenIds[54] == 43000000003, "Minted token ID mismatch");
        require(mintedTokenIds[55] == 44000000001, "Minted token ID mismatch");
        require(mintedTokenIds[56] == 44000000002, "Minted token ID mismatch");
        require(mintedTokenIds[57] == 46000000001, "Minted token ID mismatch");
        require(mintedTokenIds[58] == 47000000001, "Minted token ID mismatch");
        require(mintedTokenIds[59] == 48000000001, "Minted token ID mismatch");
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
            require(1000000001 == 1000000001, "Body token ID changed");
            // Dress Banny 1000000001 (Alien)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 7000000002; // V4 7000000002
            outfitIds[1] = 17000000001; // V4 17000000001
            outfitIds[2] = 26000000003; // V4 26000000004
            outfitIds[3] = 46000000001; // V4 46000000001

            resolver.decorateBannyWith(address(hook), 1000000001, 5000000001, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    1000000001
                );
            }
        }

        {
            require(2000000001 == 2000000001, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    2000000001
                );
            }
        }

        {
            require(2000000002 == 2000000002, "Body token ID changed");
            // Dress Banny 2000000002 (Pink)
            uint256[] memory outfitIds = new uint256[](5);
            outfitIds[0] = 7000000001; // V4 7000000001
            outfitIds[1] = 14000000002; // V4 14000000003
            outfitIds[2] = 19000000002; // V4 19000000012
            outfitIds[3] = 26000000002; // V4 26000000003
            outfitIds[4] = 35000000004; // V4 35000000006

            resolver.decorateBannyWith(address(hook), 2000000002, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    2000000002
                );
            }
        }

        {
            require(2000000003 == 2000000003, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    2000000003
                );
            }
        }

        {
            require(2000000004 == 2000000004, "Body token ID changed");
            // Dress Banny 2000000004 (Pink)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 18000000001; // V4 18000000002

            resolver.decorateBannyWith(address(hook), 2000000004, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    2000000004
                );
            }
        }

        {
            require(2000000005 == 2000000005, "Body token ID changed");
            // Dress Banny 2000000005 (Pink)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 21000000001; // V4 21000000001

            resolver.decorateBannyWith(address(hook), 2000000005, 5000000002, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    2000000005
                );
            }
        }

        {
            require(2000000006 == 2000000006, "Body token ID changed");
            // Dress Banny 2000000006 (Pink)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 19000000003; // V4 19000000019
            outfitIds[1] = 25000000001; // V4 25000000009

            resolver.decorateBannyWith(address(hook), 2000000006, 5000000003, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    2000000006
                );
            }
        }

        {
            require(3000000001 == 3000000001, "Body token ID changed");
            // Dress Banny 3000000001 (Orange)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 14000000001; // V4 14000000001
            outfitIds[1] = 26000000001; // V4 26000000001
            outfitIds[2] = 35000000001; // V4 35000000001

            resolver.decorateBannyWith(address(hook), 3000000001, 6000000001, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000001
                );
            }
        }

        {
            require(3000000002 == 3000000002, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000002
                );
            }
        }

        {
            require(3000000003 == 3000000003, "Body token ID changed");
            // Dress Banny 3000000003 (Orange)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 10000000001; // V4 10000000005
            outfitIds[1] = 44000000001; // V4 44000000003

            resolver.decorateBannyWith(address(hook), 3000000003, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000003
                );
            }
        }

        {
            require(3000000004 == 3000000004, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000004
                );
            }
        }

        {
            require(3000000005 == 3000000005, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000005
                );
            }
        }

        {
            require(3000000006 == 3000000006, "Body token ID changed");
            // Dress Banny 3000000006 (Orange)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 32000000001; // V4 32000000001
            outfitIds[1] = 44000000002; // V4 44000000004

            resolver.decorateBannyWith(address(hook), 3000000006, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000006
                );
            }
        }

        {
            require(3000000007 == 3000000007, "Body token ID changed");
            // Dress Banny 3000000007 (Orange)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 31000000001; // V4 31000000003
            outfitIds[1] = 47000000001; // V4 47000000003

            resolver.decorateBannyWith(address(hook), 3000000007, 6000000002, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000007
                );
            }
        }

        {
            require(3000000008 == 3000000008, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000008
                );
            }
        }

        {
            require(3000000009 == 3000000009, "Body token ID changed");
            // Dress Banny 3000000009 (Orange)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 35000000002; // V4 35000000002
            outfitIds[1] = 43000000001; // V4 43000000005

            resolver.decorateBannyWith(address(hook), 3000000009, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000009
                );
            }
        }

        {
            require(3000000010 == 3000000010, "Body token ID changed");
            // Dress Banny 3000000010 (Orange)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 32000000002; // V4 32000000002
            outfitIds[1] = 35000000003; // V4 35000000004
            outfitIds[2] = 48000000001; // V4 48000000001

            resolver.decorateBannyWith(address(hook), 3000000010, 6000000003, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000010
                );
            }
        }

        {
            require(3000000011 == 3000000011, "Body token ID changed");
            // Dress Banny 3000000011 (Orange)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 23000000001; // V4 23000000001
            outfitIds[1] = 39000000001; // V4 39000000001
            outfitIds[2] = 43000000002; // V4 43000000006

            resolver.decorateBannyWith(address(hook), 3000000011, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000011
                );
            }
        }

        {
            require(3000000012 == 3000000012, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000012
                );
            }
        }

        {
            require(3000000013 == 3000000013, "Body token ID changed");
            // Dress Banny 3000000013 (Orange)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 19000000001; // V4 19000000008
            outfitIds[1] = 31000000002; // V4 31000000006
            outfitIds[2] = 37000000001; // V4 37000000001
            outfitIds[3] = 43000000003; // V4 43000000007

            resolver.decorateBannyWith(address(hook), 3000000013, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000013
                );
            }
        }

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 1000000001; // V4 1000000001
        targetTokenIds[1] = 2000000001; // V4 2000000001
        targetTokenIds[2] = 2000000002; // V4 2000000002
        targetTokenIds[3] = 2000000003; // V4 2000000003
        targetTokenIds[4] = 2000000004; // V4 2000000004
        targetTokenIds[5] = 2000000005; // V4 2000000005
        targetTokenIds[6] = 2000000006; // V4 2000000006
        targetTokenIds[7] = 3000000001; // V4 3000000001
        targetTokenIds[8] = 3000000002; // V4 3000000002
        targetTokenIds[9] = 3000000003; // V4 3000000003
        targetTokenIds[10] = 3000000004; // V4 3000000004
        targetTokenIds[11] = 3000000005; // V4 3000000005
        targetTokenIds[12] = 3000000006; // V4 3000000006
        targetTokenIds[13] = 3000000007; // V4 3000000007
        targetTokenIds[14] = 3000000008; // V4 3000000008
        targetTokenIds[15] = 3000000009; // V4 3000000009
        targetTokenIds[16] = 3000000010; // V4 3000000010
        targetTokenIds[17] = 3000000011; // V4 3000000011
        targetTokenIds[18] = 3000000012; // V4 3000000012
        targetTokenIds[19] = 3000000013; // V4 3000000013

        v4TokenIds[0] = 1000000001; // V4 1000000001
        v4TokenIds[1] = 2000000001; // V4 2000000001
        v4TokenIds[2] = 2000000002; // V4 2000000002
        v4TokenIds[3] = 2000000003; // V4 2000000003
        v4TokenIds[4] = 2000000004; // V4 2000000004
        v4TokenIds[5] = 2000000005; // V4 2000000005
        v4TokenIds[6] = 2000000006; // V4 2000000006
        v4TokenIds[7] = 3000000001; // V4 3000000001
        v4TokenIds[8] = 3000000002; // V4 3000000002
        v4TokenIds[9] = 3000000003; // V4 3000000003
        v4TokenIds[10] = 3000000004; // V4 3000000004
        v4TokenIds[11] = 3000000005; // V4 3000000005
        v4TokenIds[12] = 3000000006; // V4 3000000006
        v4TokenIds[13] = 3000000007; // V4 3000000007
        v4TokenIds[14] = 3000000008; // V4 3000000008
        v4TokenIds[15] = 3000000009; // V4 3000000009
        v4TokenIds[16] = 3000000010; // V4 3000000010
        v4TokenIds[17] = 3000000011; // V4 3000000011
        v4TokenIds[18] = 3000000012; // V4 3000000012
        v4TokenIds[19] = 3000000013; // V4 3000000013


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
