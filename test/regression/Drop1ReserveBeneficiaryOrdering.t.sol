// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JB721TierConfig} from "@bananapus/721-hook-v6/src/structs/JB721TierConfig.sol";
import {JB721TiersHookStore} from "@bananapus/721-hook-v6/src/JB721TiersHookStore.sol";

import {Drop1Script} from "../../script/Drop1.s.sol";

/// @notice Exercises the Drop 1 tier set against the real 721 tiers store to prove every reserve-bearing tier
///         has a resolvable reserve beneficiary at the moment it is added.
/// @dev The store rejects a tier with a non-zero `reserveFrequency` when neither a tier-specific reserve beneficiary
///      nor a previously set hook default reserve beneficiary exists. The first reserve-bearing tier in the drop must
///      therefore establish the default, so the whole set adds in a single pass without reverting.
contract Drop1ReserveBeneficiaryOrderingTest is Test {
    JB721TiersHookStore store;
    Drop1Script drop1;

    /// @notice Stands in for the 721 hook. The store keys all tier state by `msg.sender`, so the caller of
    ///         `recordAddTiers` acts as the hook.
    address hook = makeAddr("hook");

    /// @notice The reserve beneficiary baked into the drop's reserve-bearing tiers.
    address reserveBeneficiary = makeAddr("reserveBeneficiary");

    function setUp() public {
        store = new JB721TiersHookStore();
        drop1 = new Drop1Script();
    }

    /// @notice The full Drop 1 tier set adds through the store without reverting, and every reserve-bearing tier
    ///         resolves to the configured reserve beneficiary.
    function test_drop1ReserveTiersAddWithoutReverting() public {
        (,, JB721TierConfig[] memory products) = drop1.buildDrop1Tiers(reserveBeneficiary);

        // Add every tier in a single pass, acting as the hook. This reverts with
        // `JB721TiersHookStore_MissingReserveBeneficiary` if a reserve-bearing tier is added before any beneficiary
        // (tier-specific or default) exists.
        vm.prank(hook);
        store.recordAddTiers(products);

        // All 47 tiers landed.
        assertEq(store.maxTierIdOf(hook), products.length, "all Drop 1 tiers should be added");

        // The default reserve beneficiary is now set for the hook.
        assertEq(
            store.defaultReserveBeneficiaryOf(hook),
            reserveBeneficiary,
            "default reserve beneficiary should be the configured beneficiary"
        );

        // Every reserve-bearing tier resolves to a non-zero beneficiary (the configured one). Tier IDs are 1-indexed.
        for (uint256 i; i < products.length; i++) {
            if (products[i].reserveFrequency == 0) continue;

            uint256 tierId = i + 1;
            assertEq(
                store.reserveBeneficiaryOf(hook, tierId),
                reserveBeneficiary,
                "reserve-bearing tier must resolve to the configured beneficiary"
            );
        }
    }

    /// @notice The first reserve-bearing tier in the drop is the one that establishes the default reserve beneficiary.
    /// @dev This is the load-bearing ordering property: because the store rejects any earlier reserve-bearing tier
    ///      that lacks a beneficiary, the first tier with `reserveFrequency > 0` must itself carry a non-zero
    ///      `reserveBeneficiary`.
    function test_firstReserveTierCarriesBeneficiary() public view {
        (,, JB721TierConfig[] memory products) = drop1.buildDrop1Tiers(reserveBeneficiary);

        // Find the first reserve-bearing tier.
        uint256 firstReserveIndex = type(uint256).max;
        for (uint256 i; i < products.length; i++) {
            if (products[i].reserveFrequency > 0) {
                firstReserveIndex = i;
                break;
            }
        }

        assertTrue(firstReserveIndex != type(uint256).max, "drop should contain at least one reserve-bearing tier");
        assertEq(
            products[firstReserveIndex].reserveBeneficiary,
            reserveBeneficiary,
            "first reserve-bearing tier must carry a non-zero reserve beneficiary"
        );
        assertTrue(
            products[firstReserveIndex].flags.useReserveBeneficiaryAsDefault,
            "first reserve-bearing tier must set the hook default reserve beneficiary"
        );
    }
}
