// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysEthereum3 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 20, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 42, "Minted token count mismatch");
        require(mintedTokenIds[0] == 4000000008, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 4000000009, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000010, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 4000000011, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 4000000012, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 4000000013, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 4000000014, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 4000000015, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 4000000016, "Minted token ID mismatch");
        require(mintedTokenIds[9] == 4000000017, "Minted token ID mismatch");
        require(mintedTokenIds[10] == 4000000018, "Minted token ID mismatch");
        require(mintedTokenIds[11] == 4000000019, "Minted token ID mismatch");
        require(mintedTokenIds[12] == 4000000020, "Minted token ID mismatch");
        require(mintedTokenIds[13] == 4000000021, "Minted token ID mismatch");
        require(mintedTokenIds[14] == 4000000022, "Minted token ID mismatch");
        require(mintedTokenIds[15] == 4000000023, "Minted token ID mismatch");
        require(mintedTokenIds[16] == 4000000024, "Minted token ID mismatch");
        require(mintedTokenIds[17] == 4000000025, "Minted token ID mismatch");
        require(mintedTokenIds[18] == 4000000026, "Minted token ID mismatch");
        require(mintedTokenIds[19] == 4000000027, "Minted token ID mismatch");
        require(mintedTokenIds[20] == 5000000005, "Minted token ID mismatch");
        require(mintedTokenIds[21] == 6000000006, "Minted token ID mismatch");
        require(mintedTokenIds[22] == 10000000002, "Minted token ID mismatch");
        require(mintedTokenIds[23] == 10000000003, "Minted token ID mismatch");
        require(mintedTokenIds[24] == 10000000004, "Minted token ID mismatch");
        require(mintedTokenIds[25] == 10000000005, "Minted token ID mismatch");
        require(mintedTokenIds[26] == 15000000002, "Minted token ID mismatch");
        require(mintedTokenIds[27] == 18000000002, "Minted token ID mismatch");
        require(mintedTokenIds[28] == 19000000005, "Minted token ID mismatch");
        require(mintedTokenIds[29] == 19000000006, "Minted token ID mismatch");
        require(mintedTokenIds[30] == 19000000007, "Minted token ID mismatch");
        require(mintedTokenIds[31] == 20000000001, "Minted token ID mismatch");
        require(mintedTokenIds[32] == 25000000004, "Minted token ID mismatch");
        require(mintedTokenIds[33] == 25000000005, "Minted token ID mismatch");
        require(mintedTokenIds[34] == 26000000004, "Minted token ID mismatch");
        require(mintedTokenIds[35] == 31000000003, "Minted token ID mismatch");
        require(mintedTokenIds[36] == 31000000004, "Minted token ID mismatch");
        require(mintedTokenIds[37] == 35000000005, "Minted token ID mismatch");
        require(mintedTokenIds[38] == 42000000002, "Minted token ID mismatch");
        require(mintedTokenIds[39] == 43000000004, "Minted token ID mismatch");
        require(mintedTokenIds[40] == 44000000003, "Minted token ID mismatch");
        require(mintedTokenIds[41] == 49000000002, "Minted token ID mismatch");
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
            // Dress Banny 4000000009 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10000000002; // V4 10000000001
            outfitIds[1] = 19000000005; // V4 19000000002
            outfitIds[2] = 25000000004; // V4 25000000002
            outfitIds[3] = 43000000004; // V4 43000000003

            resolver.decorateBannyWith(address(hook), 4000000009, 0, outfitIds);
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

        {
            require(4000000010 == 4000000010, "Body token ID changed");
            // Dress Banny 4000000010 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10000000003; // V4 10000000002
            outfitIds[1] = 18000000002; // V4 18000000001
            outfitIds[2] = 20000000001; // V4 20000000001
            outfitIds[3] = 44000000003; // V4 44000000001

            resolver.decorateBannyWith(address(hook), 4000000010, 5000000005, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000010
                );
            }
        }

        {
            require(4000000011 == 4000000011, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000011
                );
            }
        }

        {
            require(4000000012 == 4000000012, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000012
                );
            }
        }

        {
            require(4000000013 == 4000000013, "Body token ID changed");
            // Dress Banny 4000000013 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 31000000003; // V4 31000000002

            resolver.decorateBannyWith(address(hook), 4000000013, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000013
                );
            }
        }

        {
            require(4000000014 == 4000000014, "Body token ID changed");
            // Dress Banny 4000000014 (Original)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 10000000004; // V4 10000000006
            outfitIds[1] = 19000000006; // V4 19000000004
            outfitIds[2] = 25000000005; // V4 25000000003
            outfitIds[3] = 49000000002; // V4 49000000001

            resolver.decorateBannyWith(address(hook), 4000000014, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000014
                );
            }
        }

        {
            require(4000000015 == 4000000015, "Body token ID changed");
            // Dress Banny 4000000015 (Original)
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 15000000002; // V4 15000000001
            outfitIds[1] = 26000000004; // V4 26000000002

            resolver.decorateBannyWith(address(hook), 4000000015, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000015
                );
            }
        }

        {
            require(4000000016 == 4000000016, "Body token ID changed");
            // Dress Banny 4000000016 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 10000000005; // V4 10000000007

            resolver.decorateBannyWith(address(hook), 4000000016, 6000000006, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000016
                );
            }
        }

        {
            require(4000000017 == 4000000017, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000017
                );
            }
        }

        {
            require(4000000018 == 4000000018, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000018
                );
            }
        }

        {
            require(4000000019 == 4000000019, "Body token ID changed");
            // Dress Banny 4000000019 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19000000007; // V4 19000000005
            outfitIds[1] = 35000000005; // V4 35000000003
            outfitIds[2] = 42000000002; // V4 42000000002

            resolver.decorateBannyWith(address(hook), 4000000019, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000019
                );
            }
        }

        {
            require(4000000020 == 4000000020, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000020
                );
            }
        }

        {
            require(4000000021 == 4000000021, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000021
                );
            }
        }

        {
            require(4000000022 == 4000000022, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000022
                );
            }
        }

        {
            require(4000000023 == 4000000023, "Body token ID changed");
            // Dress Banny 4000000023 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 31000000004; // V4 31000000007

            resolver.decorateBannyWith(address(hook), 4000000023, 0, outfitIds);
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000023
                );
            }
        }

        {
            require(4000000024 == 4000000024, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000024
                );
            }
        }

        {
            require(4000000025 == 4000000025, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000025
                );
            }
        }

        {
            require(4000000026 == 4000000026, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000026
                );
            }
        }

        {
            require(4000000027 == 4000000027, "Body token ID changed");
            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    4000000027
                );
            }
        }

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 4000000008; // V4 4000000008
        targetTokenIds[1] = 4000000009; // V4 4000000009
        targetTokenIds[2] = 4000000010; // V4 4000000010
        targetTokenIds[3] = 4000000011; // V4 4000000011
        targetTokenIds[4] = 4000000012; // V4 4000000012
        targetTokenIds[5] = 4000000013; // V4 4000000013
        targetTokenIds[6] = 4000000014; // V4 4000000014
        targetTokenIds[7] = 4000000015; // V4 4000000015
        targetTokenIds[8] = 4000000016; // V4 4000000016
        targetTokenIds[9] = 4000000017; // V4 4000000017
        targetTokenIds[10] = 4000000018; // V4 4000000018
        targetTokenIds[11] = 4000000019; // V4 4000000019
        targetTokenIds[12] = 4000000020; // V4 4000000020
        targetTokenIds[13] = 4000000021; // V4 4000000021
        targetTokenIds[14] = 4000000022; // V4 4000000022
        targetTokenIds[15] = 4000000023; // V4 4000000023
        targetTokenIds[16] = 4000000024; // V4 4000000024
        targetTokenIds[17] = 4000000025; // V4 4000000025
        targetTokenIds[18] = 4000000026; // V4 4000000026
        targetTokenIds[19] = 4000000027; // V4 4000000027

        v4TokenIds[0] = 4000000008; // V4 4000000008
        v4TokenIds[1] = 4000000009; // V4 4000000009
        v4TokenIds[2] = 4000000010; // V4 4000000010
        v4TokenIds[3] = 4000000011; // V4 4000000011
        v4TokenIds[4] = 4000000012; // V4 4000000012
        v4TokenIds[5] = 4000000013; // V4 4000000013
        v4TokenIds[6] = 4000000014; // V4 4000000014
        v4TokenIds[7] = 4000000015; // V4 4000000015
        v4TokenIds[8] = 4000000016; // V4 4000000016
        v4TokenIds[9] = 4000000017; // V4 4000000017
        v4TokenIds[10] = 4000000018; // V4 4000000018
        v4TokenIds[11] = 4000000019; // V4 4000000019
        v4TokenIds[12] = 4000000020; // V4 4000000020
        v4TokenIds[13] = 4000000021; // V4 4000000021
        v4TokenIds[14] = 4000000022; // V4 4000000022
        v4TokenIds[15] = 4000000023; // V4 4000000023
        v4TokenIds[16] = 4000000024; // V4 4000000024
        v4TokenIds[17] = 4000000025; // V4 4000000025
        v4TokenIds[18] = 4000000026; // V4 4000000026
        v4TokenIds[19] = 4000000027; // V4 4000000027


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
