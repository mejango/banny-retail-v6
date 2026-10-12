// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IBannyUpgradeHook} from "./interfaces/IBannyUpgradeHook.sol";
import {IBannyUpgradeResolver} from "./interfaces/IBannyUpgradeResolver.sol";
import {IBannyUpgradeStore} from "./interfaces/IBannyUpgradeStore.sol";

/// @notice Verifies resolver configuration and an unminted collection before a Safe switches its resolver.
/// @dev Must run as a normal CALL immediately before the switch in the same Safe MultiSend transaction.
/// Emits an event so proposal collectors retain the execution-time guard. Holds no authority or state.
contract BannyResolverUpgradeGuard {
    //*********************************************************************//
    // ------------------------------ events ----------------------------- //
    //*********************************************************************//

    /// @notice Emitted when both resolvers match the expected configuration and the collection has never minted.
    /// @param hook The collection whose resolver is being switched.
    /// @param previous The collection's current resolver.
    /// @param replacement The resolver proposed for the collection.
    /// @param configurationHash The verified configuration commitment shared by both resolvers.
    event Verified(
        address indexed hook, address indexed previous, address indexed replacement, bytes32 configurationHash
    );

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Checks that switching the collection's resolver preserves its committed configuration before minting.
    /// @dev Requires the calling Safe to own both resolvers. Zero supply, burns and resolver custody establish the
    /// unminted switch window; executing the switch in the same batch prevents state changes between checks and
    /// activation.
    ///
    /// @param hook The collection whose resolver is being switched.
    /// @param previous The resolver expected to be active on the collection.
    /// @param replacement The resolver proposed for the collection.
    /// @param previousCodeHash The expected runtime code hash of the current resolver.
    /// @param replacementCodeHash The expected runtime code hash of the proposed resolver.
    /// @param expectedConfigurationHash The configuration commitment both resolvers must match.
    /// @param expectedMaxTierId The greatest configured product tier ID.
    function check(
        address hook,
        address previous,
        address replacement,
        bytes32 previousCodeHash,
        bytes32 replacementCodeHash,
        bytes32 expectedConfigurationHash,
        uint256 expectedMaxTierId
    )
        external
    {
        // Distinct deployed contracts prevent a no-op switch or an address without resolver behavior.
        require(
            previous != replacement && previous.code.length != 0 && replacement.code.length != 0, "Invalid resolver"
        );
        // Bind both implementations to the runtimes reviewed for this switch.
        require(previous.codehash == previousCodeHash && replacement.codehash == replacementCodeHash, "Runtime changed");
        // An injected dependency must authorize the replacement before the collection points to it.
        require(IBannyUpgradeResolver(replacement).SVG_STORAGE().writer() == replacement, "Storage writer");
        // Read the collection's authoritative store so the pointer and mint history cannot be supplied by the caller.
        IBannyUpgradeStore store = IBannyUpgradeHook(hook).STORE();
        // Reject a stale proposal if the collection has already selected another resolver.
        require(store.tokenUriResolverOf(hook) == previous, "Resolver changed");
        // Outstanding NFTs and resolver custody would require preserving ownership and dressing state.
        require(store.totalSupplyOf(hook) == 0, "Already minted");
        require(IBannyUpgradeHook(hook).balanceOf(previous) == 0, "Previous custody");
        require(IBannyUpgradeHook(hook).balanceOf(replacement) == 0, "Replacement custody");
        // Bind the product range before checking every tier, including NFTs removed from circulating supply.
        require(store.maxTierIdOf(hook) == expectedMaxTierId, "Products changed");
        // A mint followed by a burn leaves zero circulating supply but still closes the unminted switch window.
        for (uint256 upc = 1; upc <= expectedMaxTierId; ++upc) {
            require(store.numberOfBurnedFor({hook: hook, tierId: upc}) == 0, "Mint history");
        }
        // Both resolver owners must be the executing Safe so configuration authority remains unchanged.
        require(IBannyUpgradeResolver(previous).owner() == msg.sender, "Caller not owner");
        require(IBannyUpgradeResolver(replacement).owner() == msg.sender, "Replacement owner");
        // Verify each configuration independently against the reviewed commitment rather than only against one another.
        require(
            configurationHash({hook: hook, resolver: previous, maxTierId: expectedMaxTierId})
                == expectedConfigurationHash,
            "Previous config changed"
        );
        require(
            configurationHash({hook: hook, resolver: replacement, maxTierId: expectedMaxTierId})
                == expectedConfigurationHash,
            "Replacement config changed"
        );
        // Keep a non-view receipt marker so collectors retain this execution-time check in the submitted batch.
        emit Verified({
            hook: hook, previous: previous, replacement: replacement, configurationHash: expectedConfigurationHash
        });
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Computes the commitment to a resolver's metadata, artwork templates, product names and SVG hashes.
    /// @dev Excludes published SVG bytes so permissionless publication of correctly committed artwork cannot block a
    /// switch.
    ///
    /// @param hook The collection whose product names are included.
    /// @param resolver The resolver whose configuration is committed.
    /// @param maxTierId The greatest product tier ID included in the commitment.
    /// @return digest The ordered configuration commitment.
    function configurationHash(address hook, address resolver, uint256 maxTierId) public view returns (bytes32 digest) {
        IBannyUpgradeResolver r = IBannyUpgradeResolver(resolver);
        // Commit to authority and shared rendering inputs before folding in the ordered product configuration.
        digest = keccak256(
            abi.encode(
                r.owner(),
                r.trustedForwarder(),
                r.svgDescription(),
                r.svgExternalUrl(),
                r.svgBaseUri(),
                r.bannyBody(),
                r.defaultNecklace(),
                r.defaultMouth(),
                r.defaultStandardEyes(),
                r.defaultAlienEyes(),
                maxTierId
            )
        );
        // The first serial in each tier selects its configured product name without relying on minted NFT ownership.
        for (uint256 upc = 1; upc <= maxTierId; ++upc) {
            (,, string memory name) = r.namesOf({hook: hook, tokenId: upc * 1_000_000_000 + 1});
            // Include the tier ID and prior digest so changing a name, commitment or ordering changes the result.
            digest = keccak256(abi.encode(digest, upc, r.svgHashOf(upc), name));
        }
    }
}
