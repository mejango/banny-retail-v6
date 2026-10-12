// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBannyUpgradeStore} from "./IBannyUpgradeStore.sol";

/// @notice Exposes collection store and custody reads used to verify a resolver switch.
interface IBannyUpgradeHook {
    /// @notice Returns the collection's authoritative tier store.
    /// @return store The tier store associated with the collection.
    function STORE() external view returns (IBannyUpgradeStore store);

    /// @notice Returns the number of collection NFTs held by an account.
    /// @param account The account whose NFT custody is checked.
    /// @return balance The account's NFT balance.
    function balanceOf(address account) external view returns (uint256 balance);
}
