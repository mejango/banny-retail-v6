// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract AirdropV4BannysCombinedBase {


    function requireMintedTokenIds(
        uint256[] calldata mintedTokenIds,
        uint256[] calldata expectedTokenIds
    )
        external
        pure
    {
        require(mintedTokenIds.length == expectedTokenIds.length, "Minted token count mismatch");
        for (uint256 i; i < expectedTokenIds.length; i++) {
            require(mintedTokenIds[i] == expectedTokenIds[i], "Minted token ID mismatch");
        }
    }


    function decorateBannys(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State,
        uint256[] calldata bannyV4TokenIds,
        uint256[] calldata bannyTargetTokenIds,
        uint256[] calldata bannyBackgroundTokenIds,
        uint256[] calldata bannyOutfitOffsets,
        uint256[] calldata bannyOutfitTokenIds
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        require(
            bannyV4TokenIds.length == bannyTargetTokenIds.length
                && bannyV4TokenIds.length == bannyBackgroundTokenIds.length
                && bannyOutfitOffsets.length == bannyV4TokenIds.length + 1,
            "Banny data length mismatch"
        );

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        Banny721TokenUriResolver resolver = Banny721TokenUriResolver(resolverAddress);
        Banny721TokenUriResolver v4Resolver = Banny721TokenUriResolver(v4ResolverAddress);
        Banny721TokenUriResolver fallbackV4Resolver = Banny721TokenUriResolver(fallbackV4ResolverAddress);

        token.setApprovalForAll(address(resolver), true);

        for (uint256 i; i < bannyV4TokenIds.length; i++) {
            uint256 bannyTargetTokenId = bannyTargetTokenIds[i];
            require(bannyTargetTokenId == bannyV4TokenIds[i], "Body token ID changed");
            uint256 outfitStart = bannyOutfitOffsets[i];
            uint256 outfitEnd = bannyOutfitOffsets[i + 1];
            require(outfitEnd >= outfitStart && outfitEnd <= bannyOutfitTokenIds.length, "Banny outfit offset mismatch");
            uint256 outfitCount = outfitEnd - outfitStart;

            if (bannyBackgroundTokenIds[i] != 0 || outfitCount != 0) {
                uint256[] memory outfitTokenIds = new uint256[](outfitCount);
                for (uint256 j; j < outfitCount; j++) {
                    outfitTokenIds[j] = bannyOutfitTokenIds[outfitStart + j];
                }
                resolver.decorateBannyWith(
                    address(hook), bannyTargetTokenId, bannyBackgroundTokenIds[i], outfitTokenIds
                );
            }

            if (verifyV4State) {
                MigrationHelper.verifyV4AssetMatch(
                    resolver,
                    v4Resolver,
                    fallbackV4Resolver,
                    address(hook),
                    v4HookAddress,
                    bannyV4TokenIds[i]
                );
            }
        }
    }

    function transferRegular(
        address hookAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State,
        address[] calldata transferOwners,
        uint256[] calldata regularTargetTokenIds,
        uint256[] calldata regularV4TokenIds,
        bool[] calldata regularAllowResolverOwners
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        require(regularTargetTokenIds.length == regularV4TokenIds.length, "Regular transfer data mismatch");
        require(regularTargetTokenIds.length == regularAllowResolverOwners.length, "Regular resolver data mismatch");
        require(transferOwners.length >= regularTargetTokenIds.length, "Transfer owner count mismatch");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        IERC721 v4Hook = IERC721(v4HookAddress);

        uint256 successfulRegularTransfers;

        for (uint256 i; i < regularTargetTokenIds.length; i++) {
            address expectedOwner = transferOwners[i];

            if (verifyV4State) {
                _verifyStandaloneV4Owner(
                    v4Hook,
                    regularV4TokenIds[i],
                    expectedOwner,
                    v4ResolverAddress,
                    fallbackV4ResolverAddress,
                    regularAllowResolverOwners[i]
                );
            }

            require(token.ownerOf(regularTargetTokenIds[i]) == address(this), "Contract does not own token");
            token.safeTransferFrom(address(this), expectedOwner, regularTargetTokenIds[i]);
            successfulRegularTransfers++;
        }

        require(
            successfulRegularTransfers == regularTargetTokenIds.length,
            "Not all regular items were transferred"
        );
    }

    function transferUnused(
        address hookAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool verifyV4State,
        address[] calldata transferOwners,
        uint256 ownerOffset,
        uint256[] calldata unusedTargetTokenIds,
        uint256[] calldata unusedV4TokenIds,
        bool[] calldata unusedAllowResolverOwners
    ) external {
        require(hookAddress != address(0), "Hook address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");
        require(unusedTargetTokenIds.length == unusedV4TokenIds.length, "Unused transfer data mismatch");
        require(unusedTargetTokenIds.length == unusedAllowResolverOwners.length, "Unused resolver data mismatch");
        require(transferOwners.length >= ownerOffset + unusedTargetTokenIds.length, "Transfer owner count mismatch");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 token = IERC721(address(hook));
        IERC721 v4Hook = IERC721(v4HookAddress);

        uint256 successfulUnusedTransfers;

        for (uint256 i; i < unusedTargetTokenIds.length; i++) {
            address expectedOwner = transferOwners[ownerOffset + i];

            if (verifyV4State) {
                _verifyStandaloneV4Owner(
                    v4Hook,
                    unusedV4TokenIds[i],
                    expectedOwner,
                    v4ResolverAddress,
                    fallbackV4ResolverAddress,
                    unusedAllowResolverOwners[i]
                );
            }

            require(token.ownerOf(unusedTargetTokenIds[i]) == address(this), "Contract does not own token");
            token.safeTransferFrom(address(this), expectedOwner, unusedTargetTokenIds[i]);
            successfulUnusedTransfers++;
        }

        require(successfulUnusedTransfers == unusedTargetTokenIds.length, "Not all unused items were transferred");
    }

    function requireNoBalance(address hookAddress) external view {
        JB721TiersHook hook = JB721TiersHook(hookAddress);
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");
    }

    function _verifyStandaloneV4Owner(
        IERC721 v4Hook,
        uint256 v4TokenId,
        address expectedOwner,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress,
        bool allowResolverOwner
    )
        private
        view
    {
        address v4Owner = v4Hook.ownerOf(v4TokenId);

        if (v4Owner == address(v4ResolverAddress)) {
            require(allowResolverOwner, "Token owned by main resolver in V4 - should not be standalone");
        } else if (v4Owner == address(fallbackV4ResolverAddress)) {
            require(
                expectedOwner != address(v4ResolverAddress) && expectedOwner != address(fallbackV4ResolverAddress),
                "Fallback resolver owner cannot receive standalone token"
            );
        } else {
            require(v4Owner == expectedOwner, "V4/V6 ownership mismatch for token");
        }
    }

}
