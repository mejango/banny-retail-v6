// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysArbitrum1 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 4, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 9, "Minted token count mismatch");
        require(mintedTokenIds[0] == 3000000001, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 3000000002, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000001, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 4000000002, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 5000000001, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 19000000001, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 25000000001, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 38000000001, "Minted token ID mismatch");
        require(mintedTokenIds[8] == 47000000001, "Minted token ID mismatch");
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
            require(3000000001 == 3000000001, "Body token ID changed");
            // Dress Banny 3000000001 (Orange)
            uint256[] memory outfitIds = new uint256[](4);
            outfitIds[0] = 19000000001; // V4 19000000001
            outfitIds[1] = 25000000001; // V4 25000000001
            outfitIds[2] = 38000000001; // V4 38000000001
            outfitIds[3] = 47000000001; // V4 47000000001

            resolver.decorateBannyWith(address(hook), 3000000001, 5000000001, outfitIds);
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

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 3000000001; // V4 3000000001
        targetTokenIds[1] = 3000000002; // V4 3000000002
        targetTokenIds[2] = 4000000001; // V4 4000000001
        targetTokenIds[3] = 4000000002; // V4 4000000002

        v4TokenIds[0] = 3000000001; // V4 3000000001
        v4TokenIds[1] = 3000000002; // V4 3000000002
        v4TokenIds[2] = 4000000001; // V4 4000000001
        v4TokenIds[3] = 4000000002; // V4 4000000002


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

        require(successfulTransfers == 4, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
