// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IJB721TiersHookStore} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHookStore.sol";

import {MigrationHelper} from "../../script/helpers/MigrationHelper.sol";

contract MigrationHelperVerificationBypassTest is Test {
    address internal constant ALICE = address(0xA11CE);
    address internal constant FALLBACK_RESOLVER = address(0xFA11BAC);

    MockStore internal v4Store;
    MockStore internal v5Store;
    MockHook internal v4Hook;
    MockHook internal v5Hook;
    MigrationHelperHarness internal harness;

    function setUp() public {
        v4Store = new MockStore();
        v5Store = new MockStore();
        v4Hook = new MockHook(address(v4Store));
        v5Hook = new MockHook(address(v5Store));
        harness = new MigrationHelperHarness();
    }

    function test_verifyTierBalances_skipsAllOwnersForTierWhenFallbackResolverOwnsAnyOfTier() public {
        address[] memory owners = new address[](1);
        owners[0] = ALICE;

        uint256[] memory tierIds = new uint256[](1);
        tierIds[0] = 7;

        // Alice is over-allocated in V5 versus V4 for tier 7.
        v4Store.setTierBalance(address(v4Hook), ALICE, 7, 1);
        v5Store.setTierBalance(address(v5Hook), ALICE, 7, 2);

        // One unrelated V4 token of the same tier sits in the fallback resolver.
        v4Store.setTierBalance(address(v4Hook), FALLBACK_RESOLVER, 7, 1);

        // Intended behavior would reject Alice's inflation, but the helper skips the tier entirely.
        harness.verifyTierBalances(address(v5Hook), address(v4Hook), FALLBACK_RESOLVER, owners, tierIds);
    }

    function test_verifyTierBalances_revertsWhenFallbackResolverDoesNotOwnTier() public {
        address[] memory owners = new address[](1);
        owners[0] = ALICE;

        uint256[] memory tierIds = new uint256[](1);
        tierIds[0] = 7;

        v4Store.setTierBalance(address(v4Hook), ALICE, 7, 1);
        v5Store.setTierBalance(address(v5Hook), ALICE, 7, 2);

        vm.expectRevert(
            bytes(
                "V5 tier balance exceeds V4: owner=0x00000000000000000000000000000000000a11ce tier=7 v4Balance=1 v5Balance=2"
            )
        );
        harness.verifyTierBalances(address(v5Hook), address(v4Hook), FALLBACK_RESOLVER, owners, tierIds);
    }
}

contract MigrationHelperHarness {
    function verifyTierBalances(
        address hookAddress,
        address v4HookAddress,
        address v4FallbackResolverAddress,
        address[] memory owners,
        uint256[] memory tierIds
    )
        external
        view
    {
        MigrationHelper.verifyTierBalances(hookAddress, v4HookAddress, v4FallbackResolverAddress, owners, tierIds);
    }
}

contract MockHook {
    address internal immutable _store;

    constructor(address store) {
        _store = store;
    }

    function STORE() external view returns (IJB721TiersHookStore) {
        return IJB721TiersHookStore(_store);
    }
}

contract MockStore {
    mapping(address hook => mapping(address owner => mapping(uint256 tierId => uint256))) internal _tierBalanceOf;

    function setTierBalance(address hook, address owner, uint256 tierId, uint256 balance) external {
        _tierBalanceOf[hook][owner][tierId] = balance;
    }

    function tierBalanceOf(address hook, address owner, uint256 tierId) external view returns (uint256) {
        return _tierBalanceOf[hook][owner][tierId];
    }
}
