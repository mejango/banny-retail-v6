// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBannyUpgradeHook {
    function STORE() external view returns (IBannyUpgradeStore);
    function balanceOf(address account) external view returns (uint256);
}

interface IBannyUpgradeStore {
    function tokenUriResolverOf(address hook) external view returns (address);
    function totalSupplyOf(address hook) external view returns (uint256);
    function maxTierIdOf(address hook) external view returns (uint256);
    function numberOfBurnedFor(address hook, uint256 tierId) external view returns (uint256);
}

interface IBannyUpgradeResolver {
    function owner() external view returns (address);
    function trustedForwarder() external view returns (address);
    function svgDescription() external view returns (string memory);
    function svgExternalUrl() external view returns (string memory);
    function svgBaseUri() external view returns (string memory);
    function bannyBody() external view returns (string memory);
    function defaultNecklace() external view returns (string memory);
    function defaultMouth() external view returns (string memory);
    function defaultStandardEyes() external view returns (string memory);
    function defaultAlienEyes() external view returns (string memory);
    function svgHashOf(uint256 upc) external view returns (bytes32);
    function namesOf(address hook, uint256 tokenId) external view returns (string memory, string memory, string memory);
}

/// @notice Run immediately before the hook's resolver switch in the SAME Safe MultiSend transaction.
/// @dev A normal CALL emits an event so proposal collectors retain the execution-time guard.
/// This contract holds no authority or state. Switching after minting requires a separate migration design.
contract BannyResolverUpgradeGuard {
    event Verified(
        address indexed hook, address indexed previous, address indexed replacement, bytes32 configurationHash
    );

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
        require(
            previous != replacement && previous.code.length != 0 && replacement.code.length != 0, "Invalid resolver"
        );
        require(previous.codehash == previousCodeHash && replacement.codehash == replacementCodeHash, "Runtime changed");
        IBannyUpgradeStore store = IBannyUpgradeHook(hook).STORE();
        require(store.tokenUriResolverOf(hook) == previous, "Resolver changed");
        require(store.totalSupplyOf(hook) == 0, "Already minted");
        require(IBannyUpgradeHook(hook).balanceOf(previous) == 0, "Previous custody");
        require(IBannyUpgradeHook(hook).balanceOf(replacement) == 0, "Replacement custody");
        require(store.maxTierIdOf(hook) == expectedMaxTierId, "Products changed");
        for (uint256 upc = 1; upc <= expectedMaxTierId; ++upc) {
            require(store.numberOfBurnedFor(hook, upc) == 0, "Mint history");
        }
        require(IBannyUpgradeResolver(previous).owner() == msg.sender, "Caller not owner");
        require(IBannyUpgradeResolver(replacement).owner() == msg.sender, "Replacement owner");
        require(
            configurationHash(hook, previous, expectedMaxTierId) == expectedConfigurationHash, "Previous config changed"
        );
        require(
            configurationHash(hook, replacement, expectedMaxTierId) == expectedConfigurationHash,
            "Replacement config changed"
        );
        emit Verified(hook, previous, replacement, expectedConfigurationHash);
    }

    function configurationHash(address hook, address resolver, uint256 maxTierId) public view returns (bytes32 digest) {
        IBannyUpgradeResolver r = IBannyUpgradeResolver(resolver);
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
        for (uint256 upc = 1; upc <= maxTierId; ++upc) {
            (,, string memory name) = r.namesOf(hook, upc * 1_000_000_000 + 1);
            digest = keccak256(abi.encode(digest, upc, r.svgHashOf(upc), name));
        }
    }
}
