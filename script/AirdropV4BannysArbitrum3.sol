// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysArbitrum3 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        require(_transferOwners.length == 3, "Transfer owner count mismatch");
        transferOwners = _transferOwners;
    }


    function requireMintedTokenIds(uint256[] calldata mintedTokenIds) external pure {
        require(mintedTokenIds.length == 8, "Minted token count mismatch");
        require(mintedTokenIds[0] == 4000000007, "Minted token ID mismatch");
        require(mintedTokenIds[1] == 4000000008, "Minted token ID mismatch");
        require(mintedTokenIds[2] == 4000000009, "Minted token ID mismatch");
        require(mintedTokenIds[3] == 5000000002, "Minted token ID mismatch");
        require(mintedTokenIds[4] == 10000000002, "Minted token ID mismatch");
        require(mintedTokenIds[5] == 20000000002, "Minted token ID mismatch");
        require(mintedTokenIds[6] == 28000000002, "Minted token ID mismatch");
        require(mintedTokenIds[7] == 43000000001, "Minted token ID mismatch");
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
            require(4000000007 == 4000000007, "Body token ID changed");
            // Dress Banny 4000000007 (Original)
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 10000000002; // V4 10000000002
            outfitIds[1] = 20000000002; // V4 20000000002
            outfitIds[2] = 43000000001; // V4 43000000001

            resolver.decorateBannyWith(address(hook), 4000000007, 5000000002, outfitIds);
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
            // Dress Banny 4000000009 (Original)
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 28000000002; // V4 28000000002

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

        uint256[] memory targetTokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        bool[] memory allowResolverOwners = new bool[](transferOwners.length);
        targetTokenIds[0] = 4000000007; // V4 4000000007
        targetTokenIds[1] = 4000000008; // V4 4000000008
        targetTokenIds[2] = 4000000009; // V4 4000000009

        v4TokenIds[0] = 4000000007; // V4 4000000007
        v4TokenIds[1] = 4000000008; // V4 4000000008
        v4TokenIds[2] = 4000000009; // V4 4000000009


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

        require(successfulTransfers == 3, "Not all items were transferred");
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

}
