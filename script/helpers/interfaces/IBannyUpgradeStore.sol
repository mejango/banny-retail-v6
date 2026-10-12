// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Exposes collection configuration and mint history used to verify an unminted resolver switch.
interface IBannyUpgradeStore {
    /// @notice Returns the greatest configured tier ID for a collection.
    /// @param hook The collection whose tier range is read.
    /// @return maxTierId The greatest configured tier ID.
    function maxTierIdOf(address hook) external view returns (uint256 maxTierId);

    /// @notice Returns the number of NFTs burned from a collection's tier.
    /// @param hook The collection whose burn history is read.
    /// @param tierId The tier whose burn history is read.
    /// @return numberOfBurned The number of NFTs burned from the tier.
    function numberOfBurnedFor(address hook, uint256 tierId) external view returns (uint256 numberOfBurned);

    /// @notice Returns the metadata resolver configured for a collection.
    /// @param hook The collection whose resolver is read.
    /// @return resolver The configured metadata resolver.
    function tokenUriResolverOf(address hook) external view returns (address resolver);

    /// @notice Returns the collection's circulating NFT supply across its tiers.
    /// @dev Burned NFTs are excluded; burn history must be checked separately to establish that no NFTs have minted.
    /// @param hook The collection whose circulating supply is read.
    /// @return supply The number of NFTs in circulation.
    function totalSupplyOf(address hook) external view returns (uint256 supply);
}
