// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Manages Banny NFT assets -- bodies, backgrounds, and outfits -- and resolves on-chain SVG token URIs for
/// dressed Banny compositions.
interface IBanny721TokenUriResolver {
    event DecorateBanny(
        address indexed hook,
        uint256 indexed bannyBodyId,
        uint256 indexed backgroundId,
        uint256[] outfitIds,
        address caller
    );
    event SetMetadata(string description, string externalUrl, string baseUri, address caller);
    event SetProductName(uint256 indexed upc, string name, address caller);
    event SetSvgContent(uint256 indexed upc, string svgContent, address caller);
    event SetSvgHash(uint256 indexed upc, bytes32 indexed svgHash, address caller);

    /// @notice The stored SVG content hash for a given product.
    /// @param upc The universal product code to look up.
    /// @return The SVG content hash.
    function svgHashOf(uint256 upc) external view returns (bytes32);

    /// @notice The base URI used to lazily resolve SVG content from IPFS.
    /// @return The base URI string.
    function svgBaseUri() external view returns (string memory);

    /// @notice The description used in token metadata.
    /// @return The description string.
    function svgDescription() external view returns (string memory);

    /// @notice The external URL used in token metadata.
    /// @return The external URL string.
    function svgExternalUrl() external view returns (string memory);

    /// @notice The timestamp until which a banny body's outfit is locked and cannot be changed.
    /// @param hook The hook address of the collection.
    /// @param upc The ID of the banny body.
    /// @return The lock expiration timestamp, or 0 if not locked.
    function outfitLockedUntil(address hook, uint256 upc) external view returns (uint256);

    /// @notice The default SVG content for alien banny eyes.
    /// @return The SVG string.
    function DEFAULT_ALIEN_EYES() external view returns (string memory);

    /// @notice The default SVG content for a banny mouth.
    /// @return The SVG string.
    function DEFAULT_MOUTH() external view returns (string memory);

    /// @notice The default SVG content for a banny necklace.
    /// @return The SVG string.
    function DEFAULT_NECKLACE() external view returns (string memory);

    /// @notice The default SVG content for standard banny eyes.
    /// @return The SVG string.
    function DEFAULT_STANDARD_EYES() external view returns (string memory);

    /// @notice The base SVG content for a banny body.
    /// @return The SVG string.
    function BANNY_BODY() external view returns (string memory);

    /// @notice The background and outfit IDs currently attached to a banny body.
    /// @param hook The hook address of the collection.
    /// @param bannyBodyId The ID of the banny body.
    /// @return backgroundId The ID of the attached background.
    /// @return outfitIds The IDs of the attached outfits.
    function assetIdsOf(
        address hook,
        uint256 bannyBodyId
    )
        external
        view
        returns (uint256 backgroundId, uint256[] memory outfitIds);

    /// @notice The banny body ID that is currently using a given background.
    /// @param hook The hook address of the collection.
    /// @param backgroundId The ID of the background.
    /// @return The banny body ID using the background, or 0 if none.
    function userOf(address hook, uint256 backgroundId) external view returns (uint256);

    /// @notice The banny body ID that is currently wearing a given outfit.
    /// @param hook The hook address of the collection.
    /// @param outfitId The ID of the outfit.
    /// @return The banny body ID wearing the outfit, or 0 if none.
    function wearerOf(address hook, uint256 outfitId) external view returns (uint256);

    /// @notice Get the composed SVG for a token, optionally dressed and with a background.
    /// @param hook The hook address of the collection.
    /// @param tokenId The token ID to render.
    /// @param shouldDressBannyBody Whether to include the banny body's attached outfits.
    /// @param shouldIncludeBackgroundOnBannyBody Whether to include the banny body's attached background.
    /// @return The composed SVG string.
    function svgOf(
        address hook,
        uint256 tokenId,
        bool shouldDressBannyBody,
        bool shouldIncludeBackgroundOnBannyBody
    )
        external
        view
        returns (string memory);

    /// @notice Get the names associated with a token (product name, category name, and display name).
    /// @param hook The hook address of the collection.
    /// @param tokenId The token ID to look up.
    /// @return The product name, the category name, and the display name.
    function namesOf(address hook, uint256 tokenId) external view returns (string memory, string memory, string memory);

    /// @notice Dress a banny body with a background and outfits.
    /// @param hook The hook address of the collection.
    /// @param bannyBodyId The ID of the banny body to dress.
    /// @param backgroundId The ID of the background to attach (0 for none).
    /// @param outfitIds The IDs of the outfits to attach.
    function decorateBannyWith(
        address hook,
        uint256 bannyBodyId,
        uint256 backgroundId,
        uint256[] calldata outfitIds
    )
        external;

    /// @notice Lock a banny body so its outfit cannot be changed for a period of time.
    /// @param hook The hook address of the collection.
    /// @param bannyBodyId The ID of the banny body to lock.
    function lockOutfitChangesFor(address hook, uint256 bannyBodyId) external;

    /// @notice Store SVG contents for products, validated against previously stored hashes.
    /// @param upcs The universal product codes to store SVG contents for.
    /// @param svgContents The SVG contents to store (must match stored hashes).
    function setSvgContentsOf(uint256[] memory upcs, string[] calldata svgContents) external;

    /// @notice Store SVG content hashes for products. Only the contract owner can call this.
    /// @param upcs The universal product codes to store SVG hashes for.
    /// @param svgHashes The SVG content hashes to store.
    function setSvgHashesOf(uint256[] memory upcs, bytes32[] memory svgHashes) external;

    /// @notice Set custom display names for products. Only the contract owner can call this.
    /// @param upcs The universal product codes to set names for.
    /// @param names The names to assign to each product.
    function setProductNames(uint256[] memory upcs, string[] memory names) external;

    /// @notice Set the token metadata description, external URL, and SVG base URI. Only the contract owner can call
    /// this.
    /// @param description The new description.
    /// @param url The new external URL.
    /// @param baseUri The new base URI.
    function setMetadata(string calldata description, string calldata url, string calldata baseUri) external;
}
