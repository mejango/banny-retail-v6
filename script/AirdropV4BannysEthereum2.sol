// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysEthereum2 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 20, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 36, "Minted token count mismatch");
        require(mintedTokenIds[0] == 3000000014, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 3000000015, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 3000000016, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 3000000017, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 3000000018, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 3000000019, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 3000000020, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 3000000021, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 3000000022, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 3000000023, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 3000000024, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 3000000025, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 3000000026, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000001, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000002, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000003, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000004, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000005, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 4000000006, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 4000000007, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 5000000004, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 6000000004, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 6000000005, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 14000000003, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 15000000001, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 19000000004, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 25000000002, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 25000000003, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 28000000001, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 29000000001, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 37000000002, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 38000000001, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 39000000002, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 42000000001, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 48000000002, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 49000000001, "Minted token ID mismatch");
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
            require(3000000014 == 3000000014, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000014
                );
            }
        }

        {
            require(3000000015 == 3000000015, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000015
                );
            }
        }

        {
            require(3000000016 == 3000000016, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000016
                );
            }
        }

        {
            require(3000000017 == 3000000017, "Body token ID changed");
            // Dress Banny 3000000017 (Orange)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 25000000002; // V4 25000000005
            outfitIds[1] = 49000000001; // V4 49000000002

            resolver.decorateBannyWith(address(hook), 3000000017, 5000000004, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000017
                );
            }
        }

        {
            require(3000000018 == 3000000018, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000018
                );
            }
        }

        {
            require(3000000019 == 3000000019, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000019
                );
            }
        }

        {
            require(3000000020 == 3000000020, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000020
                );
            }
        }

        {
            require(3000000021 == 3000000021, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000021
                );
            }
        }

        {
            require(3000000022 == 3000000022, "Body token ID changed");
            // Dress Banny 3000000022 (Orange)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19000000004; // V4 19000000015
            outfitIds[1] = 38000000001; // V4 38000000002
            outfitIds[2] = 48000000002; // V4 48000000005

            resolver.decorateBannyWith(address(hook), 3000000022, 6000000004, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000022
                );
            }
        }

        {
            require(3000000023 == 3000000023, "Body token ID changed");
            // Dress Banny 3000000023 (Orange)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 14000000003; // V4 14000000005
            outfitIds[1] = 25000000003; // V4 25000000008
            outfitIds[2] = 37000000002; // V4 37000000003
            outfitIds[3] = 42000000001; // V4 42000000007

            resolver.decorateBannyWith(address(hook), 3000000023, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000023
                );
            }
        }

        {
            require(3000000024 == 3000000024, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000024
                );
            }
        }

        {
            require(3000000025 == 3000000025, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000025
                );
            }
        }

        {
            require(3000000026 == 3000000026, "Body token ID changed");
            // Dress Banny 3000000026 (Orange)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 15000000001; // V4 15000000004
            outfitIds[1] = 29000000001; // V4 29000000003
            outfitIds[2] = 39000000002; // V4 39000000003

            resolver.decorateBannyWith(address(hook), 3000000026, 6000000005, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    3000000026
                );
            }
        }

        {
            require(4000000001 == 4000000001, "Body token ID changed");
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
            // Dress Banny 4000000004 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 28000000001; // V4 28000000002

            resolver.decorateBannyWith(address(hook), 4000000004, 0, outfitIds);
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

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 3000000014; // V4 3000000014
        targetTokenIds[1] = 3000000015; // V4 3000000015
        targetTokenIds[2] = 3000000016; // V4 3000000016
        targetTokenIds[3] = 3000000017; // V4 3000000017
        targetTokenIds[4] = 3000000018; // V4 3000000018
        targetTokenIds[5] = 3000000019; // V4 3000000019
        targetTokenIds[6] = 3000000020; // V4 3000000020
        targetTokenIds[7] = 3000000021; // V4 3000000021
        targetTokenIds[8] = 3000000022; // V4 3000000022
        targetTokenIds[9] = 3000000023; // V4 3000000023
        targetTokenIds[10] = 3000000024; // V4 3000000024
        targetTokenIds[11] = 3000000025; // V4 3000000025
        targetTokenIds[12] = 3000000026; // V4 3000000026
        targetTokenIds[13] = 4000000001; // V4 4000000001
        targetTokenIds[14] = 4000000002; // V4 4000000002
        targetTokenIds[15] = 4000000003; // V4 4000000003
        targetTokenIds[16] = 4000000004; // V4 4000000004
        targetTokenIds[17] = 4000000005; // V4 4000000005
        targetTokenIds[18] = 4000000006; // V4 4000000006
        targetTokenIds[19] = 4000000007; // V4 4000000007

        v4TokenIds[0] = 3000000014; // V4 3000000014
        v4TokenIds[1] = 3000000015; // V4 3000000015
        v4TokenIds[2] = 3000000016; // V4 3000000016
        v4TokenIds[3] = 3000000017; // V4 3000000017
        v4TokenIds[4] = 3000000018; // V4 3000000018
        v4TokenIds[5] = 3000000019; // V4 3000000019
        v4TokenIds[6] = 3000000020; // V4 3000000020
        v4TokenIds[7] = 3000000021; // V4 3000000021
        v4TokenIds[8] = 3000000022; // V4 3000000022
        v4TokenIds[9] = 3000000023; // V4 3000000023
        v4TokenIds[10] = 3000000024; // V4 3000000024
        v4TokenIds[11] = 3000000025; // V4 3000000025
        v4TokenIds[12] = 3000000026; // V4 3000000026
        v4TokenIds[13] = 4000000001; // V4 4000000001
        v4TokenIds[14] = 4000000002; // V4 4000000002
        v4TokenIds[15] = 4000000003; // V4 4000000003
        v4TokenIds[16] = 4000000004; // V4 4000000004
        v4TokenIds[17] = 4000000005; // V4 4000000005
        v4TokenIds[18] = 4000000006; // V4 4000000006
        v4TokenIds[19] = 4000000007; // V4 4000000007


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
