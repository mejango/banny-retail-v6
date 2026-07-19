// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysBase1 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 22, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 57, "Minted token count mismatch");
        require(mintedTokenIds[0] == 2000000001, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 2000000002, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 2000000003, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 3000000001, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 3000000002, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 3000000003, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 3000000004, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 3000000005, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 3000000006, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 3000000007, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 3000000008, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 3000000009, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 3000000010, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000001, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000002, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000003, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000004, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000005, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 4000000006, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 4000000007, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 4000000008, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 4000000009, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 5000000001, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 6000000001, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 6000000002, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 6000000003, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 6000000004, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 10000000001, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 11000000001, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 14000000001, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 14000000002, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 15000000001, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 15000000002, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 19000000001, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 19000000002, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 19000000003, "Minted token ID mismatch");
        require(mintedTokenIds[36] == 19000000004, "Minted token ID mismatch");
        require(mintedTokenIds[37] == 25000000001, "Minted token ID mismatch");
        require(mintedTokenIds[38] == 25000000002, "Minted token ID mismatch");
        require(mintedTokenIds[39] == 25000000003, "Minted token ID mismatch");
        require(mintedTokenIds[40] == 25000000004, "Minted token ID mismatch");
        require(mintedTokenIds[41] == 28000000001, "Minted token ID mismatch");
        require(mintedTokenIds[42] == 28000000002, "Minted token ID mismatch");
        require(mintedTokenIds[43] == 28000000003, "Minted token ID mismatch");
        require(mintedTokenIds[44] == 28000000004, "Minted token ID mismatch");
        require(mintedTokenIds[45] == 31000000001, "Minted token ID mismatch");
        require(mintedTokenIds[46] == 32000000001, "Minted token ID mismatch");
        require(mintedTokenIds[47] == 33000000001, "Minted token ID mismatch");
        require(mintedTokenIds[48] == 37000000001, "Minted token ID mismatch");
        require(mintedTokenIds[49] == 37000000002, "Minted token ID mismatch");
        require(mintedTokenIds[50] == 40000000001, "Minted token ID mismatch");
        require(mintedTokenIds[51] == 43000000001, "Minted token ID mismatch");
        require(mintedTokenIds[52] == 44000000001, "Minted token ID mismatch");
        require(mintedTokenIds[53] == 44000000002, "Minted token ID mismatch");
        require(mintedTokenIds[54] == 45000000001, "Minted token ID mismatch");
        require(mintedTokenIds[55] == 47000000001, "Minted token ID mismatch");
        require(mintedTokenIds[56] == 47000000002, "Minted token ID mismatch");
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
            require(2000000001 == 2000000001, "Body token ID changed");
            // Dress Banny 2000000001 (Pink)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 28000000002; // V4 28000000002
            outfitIds[1] = 37000000001; // V4 37000000001

            resolver.decorateBannyWith(address(hook), 2000000001, 0, outfitIds);
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
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 14000000001; // V4 14000000002
            outfitIds[1] = 32000000001; // V4 32000000001

            resolver.decorateBannyWith(address(hook), 2000000002, 6000000001, outfitIds);
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
            // Dress Banny 2000000003 (Pink)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 25000000003; // V4 25000000008
            outfitIds[1] = 37000000002; // V4 37000000002
            outfitIds[2] = 45000000001; // V4 45000000001

            resolver.decorateBannyWith(address(hook), 2000000003, 6000000003, outfitIds);
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
            require(3000000001 == 3000000001, "Body token ID changed");
            // Dress Banny 3000000001 (Orange)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 25000000002; // V4 25000000004
            outfitIds[1] = 47000000001; // V4 47000000003

            resolver.decorateBannyWith(address(hook), 3000000001, 0, outfitIds);
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
            // Dress Banny 3000000002 (Orange)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 31000000001; // V4 31000000002

            resolver.decorateBannyWith(address(hook), 3000000002, 0, outfitIds);
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
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10000000001; // V4 10000000005
            outfitIds[1] = 19000000002; // V4 19000000005
            outfitIds[2] = 28000000003; // V4 28000000005
            outfitIds[3] = 47000000002; // V4 47000000005

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
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 14000000002; // V4 14000000003
            outfitIds[1] = 19000000003; // V4 19000000007
            outfitIds[2] = 28000000001; // V4 28000000001

            resolver.decorateBannyWith(address(hook), 3000000006, 6000000002, outfitIds);
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
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19000000004; // V4 19000000009
            outfitIds[1] = 28000000004; // V4 28000000007
            outfitIds[2] = 44000000002; // V4 44000000005

            resolver.decorateBannyWith(address(hook), 3000000007, 0, outfitIds);
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
            // Dress Banny 3000000008 (Orange)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 15000000002; // V4 15000000002
            outfitIds[1] = 40000000001; // V4 40000000001

            resolver.decorateBannyWith(address(hook), 3000000008, 0, outfitIds);
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
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 25000000004; // V4 25000000009
            outfitIds[1] = 43000000001; // V4 43000000008

            resolver.decorateBannyWith(address(hook), 3000000010, 5000000001, outfitIds);
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
            require(4000000001 == 4000000001, "Body token ID changed");
            // Dress Banny 4000000001 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 15000000001; // V4 15000000001

            resolver.decorateBannyWith(address(hook), 4000000001, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000001
                );
            }
        }

        {
            require(4000000002 == 4000000002, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000002
                );
            }
        }

        {
            require(4000000003 == 4000000003, "Body token ID changed");
            // Dress Banny 4000000003 (Original)
            uint256[] memory outfitIds = new uint256[](5);
            outfitIds[0] = 11000000001; // V4 11000000001
            outfitIds[1] = 19000000001; // V4 19000000001
            outfitIds[2] = 25000000001; // V4 25000000001
            outfitIds[3] = 33000000001; // V4 33000000001
            outfitIds[4] = 44000000001; // V4 44000000001

            resolver.decorateBannyWith(address(hook), 4000000003, 6000000004, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000003
                );
            }
        }

        {
            require(4000000004 == 4000000004, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000004
                );
            }
        }

        {
            require(4000000005 == 4000000005, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000005
                );
            }
        }

        {
            require(4000000006 == 4000000006, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000006
                );
            }
        }

        {
            require(4000000007 == 4000000007, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000007
                );
            }
        }

        {
            require(4000000008 == 4000000008, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000008
                );
            }
        }

        {
            require(4000000009 == 4000000009, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000009
                );
            }
        }

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 2000000001; // V4 2000000001
        targetTokenIds[1] = 2000000002; // V4 2000000002
        targetTokenIds[2] = 2000000003; // V4 2000000003
        targetTokenIds[3] = 3000000001; // V4 3000000001
        targetTokenIds[4] = 3000000002; // V4 3000000002
        targetTokenIds[5] = 3000000003; // V4 3000000003
        targetTokenIds[6] = 3000000004; // V4 3000000004
        targetTokenIds[7] = 3000000005; // V4 3000000005
        targetTokenIds[8] = 3000000006; // V4 3000000006
        targetTokenIds[9] = 3000000007; // V4 3000000007
        targetTokenIds[10] = 3000000008; // V4 3000000008
        targetTokenIds[11] = 3000000009; // V4 3000000009
        targetTokenIds[12] = 3000000010; // V4 3000000010
        targetTokenIds[13] = 4000000001; // V4 4000000001
        targetTokenIds[14] = 4000000002; // V4 4000000002
        targetTokenIds[15] = 4000000003; // V4 4000000003
        targetTokenIds[16] = 4000000004; // V4 4000000004
        targetTokenIds[17] = 4000000005; // V4 4000000005
        targetTokenIds[18] = 4000000006; // V4 4000000006
        targetTokenIds[19] = 4000000007; // V4 4000000007
        targetTokenIds[20] = 4000000008; // V4 4000000008
        targetTokenIds[21] = 4000000009; // V4 4000000009

        v4TokenIds[0] = 2000000001; // V4 2000000001
        v4TokenIds[1] = 2000000002; // V4 2000000002
        v4TokenIds[2] = 2000000003; // V4 2000000003
        v4TokenIds[3] = 3000000001; // V4 3000000001
        v4TokenIds[4] = 3000000002; // V4 3000000002
        v4TokenIds[5] = 3000000003; // V4 3000000003
        v4TokenIds[6] = 3000000004; // V4 3000000004
        v4TokenIds[7] = 3000000005; // V4 3000000005
        v4TokenIds[8] = 3000000006; // V4 3000000006
        v4TokenIds[9] = 3000000007; // V4 3000000007
        v4TokenIds[10] = 3000000008; // V4 3000000008
        v4TokenIds[11] = 3000000009; // V4 3000000009
        v4TokenIds[12] = 3000000010; // V4 3000000010
        v4TokenIds[13] = 4000000001; // V4 4000000001
        v4TokenIds[14] = 4000000002; // V4 4000000002
        v4TokenIds[15] = 4000000003; // V4 4000000003
        v4TokenIds[16] = 4000000004; // V4 4000000004
        v4TokenIds[17] = 4000000005; // V4 4000000005
        v4TokenIds[18] = 4000000006; // V4 4000000006
        v4TokenIds[19] = 4000000007; // V4 4000000007
        v4TokenIds[20] = 4000000008; // V4 4000000008
        v4TokenIds[21] = 4000000009; // V4 4000000009


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
