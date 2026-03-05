// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {IJB721TiersHookStore} from "@bananapus/721-hook-v5/src/interfaces/IJB721TiersHookStore.sol";

library MigrationHelper {
    /// @notice Get the UPC (tier ID) from a token ID
    function _getUPC(address hook, uint256 tokenId) internal view returns (uint256) {
        IJB721TiersHookStore store = JB721TiersHook(hook).STORE();
        return store.tierOfTokenId({hook: hook, tokenId: tokenId, includeResolvedUri: false}).id;
    }

    function verifyV4AssetMatch(
        Banny721TokenUriResolver resolver,
        Banny721TokenUriResolver v4Resolver,
        Banny721TokenUriResolver fallbackV4Resolver,
        address hookAddress,
        address v4HookAddress,
        uint256 tokenId
    )
        internal
        view
    {
        // Get V5 asset token IDs (from V5 hook)
        (uint256 v5BackgroundId, uint256[] memory v5OutfitIds) = resolver.assetIdsOf(hookAddress, tokenId);
        // Get V4 asset token IDs (from V4 hook)
        (uint256 v4BackgroundId, uint256[] memory v4OutfitIds) = v4Resolver.assetIdsOf(v4HookAddress, tokenId);

        // Compare background UPCs (not token IDs, since they may differ)
        uint256 v5BackgroundUPC = v5BackgroundId == 0 ? 0 : _getUPC(hookAddress, v5BackgroundId);
        uint256 v4BackgroundUPC = v4BackgroundId == 0 ? 0 : _getUPC(v4HookAddress, v4BackgroundId);

        bool matches = v5BackgroundUPC == v4BackgroundUPC && v5OutfitIds.length == v4OutfitIds.length;

        if (matches) {
            // Compare outfit UPCs
            for (uint256 i = 0; i < v5OutfitIds.length; i++) {
                uint256 v5OutfitUPC = _getUPC(hookAddress, v5OutfitIds[i]);
                uint256 v4OutfitUPC = _getUPC(v4HookAddress, v4OutfitIds[i]);
                if (v5OutfitUPC != v4OutfitUPC) {
                    matches = false;
                    break;
                }
            }
        }

        if (!matches) {
            // Try fallback resolver
            (v4BackgroundId, v4OutfitIds) = fallbackV4Resolver.assetIdsOf(v4HookAddress, tokenId);
            v4BackgroundUPC = v4BackgroundId == 0 ? 0 : _getUPC(v4HookAddress, v4BackgroundId);

            require(
                v5BackgroundUPC == v4BackgroundUPC && v5OutfitIds.length == v4OutfitIds.length, "V4/V5 asset mismatch"
            );

            for (uint256 i = 0; i < v5OutfitIds.length; i++) {
                uint256 v5OutfitUPC = _getUPC(hookAddress, v5OutfitIds[i]);
                uint256 v4OutfitUPC = _getUPC(v4HookAddress, v4OutfitIds[i]);
                require(v5OutfitUPC == v4OutfitUPC, "V4/V5 asset mismatch");
            }
        }
    }

    /// @notice Verify that tier balances in V5 are never greater than in V4 for all owners and tiers
    /// @param hookAddress V5 hook address
    /// @param v4HookAddress V4 hook address
    /// @param v4FallbackResolverAddress V4 fallback resolver address (legacy resolver)
    /// @param owners Array of owner addresses to check
    /// @param tierIds Array of tier IDs to check
    function verifyTierBalances(
        address hookAddress,
        address v4HookAddress,
        address v4FallbackResolverAddress,
        address[] memory owners,
        uint256[] memory tierIds
    )
        internal
        view
    {
        IJB721TiersHookStore v5Store = JB721TiersHook(hookAddress).STORE();
        IJB721TiersHookStore v4Store = JB721TiersHook(v4HookAddress).STORE();

        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];

            for (uint256 j = 0; j < tierIds.length; j++) {
                uint256 tierId = tierIds[j];

                // Check if this tier is owned by the fallback resolver in V4
                // If so, skip verification (these are now owned by rightful owners in V5)
                uint256 v4FallbackResolverBalance =
                    v4Store.tierBalanceOf(v4HookAddress, v4FallbackResolverAddress, tierId);
                if (v4FallbackResolverBalance > 0) {
                    continue;
                }

                // Get V4 and V5 tier balances for this owner and tier
                uint256 v4Balance = v4Store.tierBalanceOf(v4HookAddress, owner, tierId);
                uint256 v5Balance = v5Store.tierBalanceOf(hookAddress, owner, tierId);

                // Require that V5 balance is never greater than V4 balance
                require(
                    v5Balance <= v4Balance,
                    string.concat(
                        "V5 tier balance exceeds V4: owner=",
                        _addressToString(owner),
                        " tier=",
                        _uint256ToString(tierId),
                        " v4Balance=",
                        _uint256ToString(v4Balance),
                        " v5Balance=",
                        _uint256ToString(v5Balance)
                    )
                );
            }
        }
    }

    /// @notice Convert address to string (helper for error messages)
    function _addressToString(address addr) private pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    /// @notice Convert uint256 to string (helper for error messages)
    function _uint256ToString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

