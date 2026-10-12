// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Exposes resolver authority, rendering configuration and artwork commitments used to verify a switch.
interface IBannyUpgradeResolver {
    /// @notice Returns the shared Banny body SVG template.
    /// @return body The configured SVG fragment.
    function bannyBody() external view returns (string memory body);

    /// @notice Returns the default alien eyes SVG fragment.
    /// @return eyes The configured SVG fragment.
    function defaultAlienEyes() external view returns (string memory eyes);

    /// @notice Returns the default mouth SVG fragment.
    /// @return mouth The configured SVG fragment.
    function defaultMouth() external view returns (string memory mouth);

    /// @notice Returns the default necklace SVG fragment.
    /// @return necklace The configured SVG fragment.
    function defaultNecklace() external view returns (string memory necklace);

    /// @notice Returns the default standard eyes SVG fragment.
    /// @return eyes The configured SVG fragment.
    function defaultStandardEyes() external view returns (string memory eyes);

    /// @notice Returns the collection, category and product names for an NFT.
    /// @param hook The collection whose NFT names are read.
    /// @param tokenId The NFT ID identifying the product tier and serial.
    /// @return collectionName The collection name.
    /// @return categoryName The product category name.
    /// @return productName The product tier name.
    function namesOf(
        address hook,
        uint256 tokenId
    )
        external
        view
        returns (string memory collectionName, string memory categoryName, string memory productName);

    /// @notice Returns the account authorized to configure the resolver.
    /// @return resolverOwner The resolver's owner.
    function owner() external view returns (address resolverOwner);

    /// @notice Returns the base URI used for external SVG artwork references.
    /// @return baseUri The configured SVG base URI.
    function svgBaseUri() external view returns (string memory baseUri);

    /// @notice Returns the description included in NFT metadata.
    /// @return description The configured metadata description.
    function svgDescription() external view returns (string memory description);

    /// @notice Returns the external URL included in NFT metadata.
    /// @return externalUrl The configured metadata external URL.
    function svgExternalUrl() external view returns (string memory externalUrl);

    /// @notice Returns the committed SVG content hash for a product.
    /// @param upc The product code whose artwork commitment is read.
    /// @return svgHash The committed keccak256 hash of the SVG content.
    function svgHashOf(uint256 upc) external view returns (bytes32 svgHash);

    /// @notice Returns the forwarder trusted to relay resolver calls.
    /// @return forwarder The configured trusted forwarder.
    function trustedForwarder() external view returns (address forwarder);
}
