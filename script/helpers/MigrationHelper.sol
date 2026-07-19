// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {IJB721TiersHookStore} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHookStore.sol";

library MigrationHelper {
    /// @notice Get the UPC (tier ID) from a token ID
    function _getUpc(uint256 tokenId) internal pure returns (uint256) {
        return tokenId / 1_000_000_000;
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
        // Get target asset token IDs from the hook being verified.
        (uint256 targetBackgroundId, uint256[] memory targetOutfitIds) =
            resolver.assetIdsOf({hook: hookAddress, bannyBodyId: tokenId});
        // Get V4 asset token IDs (from V4 hook)
        (uint256 v4BackgroundId, uint256[] memory v4OutfitIds) =
            v4Resolver.assetIdsOf({hook: v4HookAddress, bannyBodyId: tokenId});

        // Compare background UPCs (not token IDs, since they may differ)
        uint256 targetBackgroundUpc = targetBackgroundId == 0 ? 0 : _getUpc({tokenId: targetBackgroundId});
        uint256 v4BackgroundUpc = v4BackgroundId == 0 ? 0 : _getUpc({tokenId: v4BackgroundId});

        bool matches = targetBackgroundUpc == v4BackgroundUpc && targetOutfitIds.length == v4OutfitIds.length;

        if (matches) {
            // Compare outfit UPCs
            for (uint256 i = 0; i < targetOutfitIds.length; i++) {
                uint256 targetOutfitUpc = _getUpc({tokenId: targetOutfitIds[i]});
                uint256 v4OutfitUpc = _getUpc({tokenId: v4OutfitIds[i]});
                if (targetOutfitUpc != v4OutfitUpc) {
                    matches = false;
                    break;
                }
            }
        }

        if (!matches) {
            // Try fallback resolver
            (v4BackgroundId, v4OutfitIds) = fallbackV4Resolver.assetIdsOf({hook: v4HookAddress, bannyBodyId: tokenId});
            v4BackgroundUpc = v4BackgroundId == 0 ? 0 : _getUpc({tokenId: v4BackgroundId});

            require(
                targetBackgroundUpc == v4BackgroundUpc && targetOutfitIds.length == v4OutfitIds.length,
                "V4/target asset mismatch"
            );

            for (uint256 i = 0; i < targetOutfitIds.length; i++) {
                uint256 targetOutfitUpc = _getUpc({tokenId: targetOutfitIds[i]});
                uint256 v4OutfitUpc = _getUpc({tokenId: v4OutfitIds[i]});
                require(targetOutfitUpc == v4OutfitUpc, "V4/target asset mismatch");
            }
        }
    }

    /// @notice Verify that target tier balances are never greater than V4 for all owners and tiers
    /// @param hookAddress Target hook address
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
        IJB721TiersHookStore targetStore = JB721TiersHook(hookAddress).STORE();
        IJB721TiersHookStore v4Store = JB721TiersHook(v4HookAddress).STORE();

        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];

            for (uint256 j = 0; j < tierIds.length; j++) {
                uint256 tierId = tierIds[j];

                // Check if this tier is owned by the fallback resolver in V4.
                // If so, skip verification because target ownership was intentionally reassigned.
                uint256 v4FallbackResolverBalance =
                    v4Store.tierBalanceOf({hook: v4HookAddress, owner: v4FallbackResolverAddress, tierId: tierId});
                if (v4FallbackResolverBalance > 0) {
                    continue;
                }

                // Get V4 and target tier balances for this owner and tier.
                uint256 v4Balance = v4Store.tierBalanceOf({hook: v4HookAddress, owner: owner, tierId: tierId});
                uint256 targetBalance = targetStore.tierBalanceOf({hook: hookAddress, owner: owner, tierId: tierId});

                // Require that the target balance is never greater than the V4 balance.
                require(
                    targetBalance <= v4Balance,
                    string.concat(
                        "target tier balance exceeds V4: owner=",
                        _addressToString(owner),
                        " tier=",
                        _uint256ToString(tierId),
                        " v4Balance=",
                        _uint256ToString(v4Balance),
                        " targetBalance=",
                        _uint256ToString(targetBalance)
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
            // forge-lint: disable-next-line(unsafe-typecast)
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
