// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBanny721TokenUriResolver {
    event DecorateBanny(
        address indexed hook,
        uint256 indexed bannyBodyId,
        uint256 indexed backgroundId,
        uint256[] outfitIds,
        address caller
    );
    event SetProductName(uint256 indexed upc, string name, address caller);
    event SetSvgBaseUri(string baseUri, address caller);
    event SetSvgContent(uint256 indexed upc, string svgContent, address caller);
    event SetSvgHash(uint256 indexed upc, bytes32 indexed svgHash, address caller);

    function svgHashOf(uint256 upc) external view returns (bytes32);
    function svgBaseUri() external view returns (string memory);
    function outfitLockedUntil(address hook, uint256 upc) external view returns (uint256);
    function DEFAULT_ALIEN_EYES() external view returns (string memory);
    function DEFAULT_MOUTH() external view returns (string memory);
    function DEFAULT_NECKLACE() external view returns (string memory);
    function DEFAULT_STANDARD_EYES() external view returns (string memory);
    function BANNY_BODY() external view returns (string memory);

    function assetIdsOf(
        address hook,
        uint256 bannyBodyId
    )
        external
        view
        returns (uint256 backgroundId, uint256[] memory outfitIds);
    function userOf(address hook, uint256 backgroundId) external view returns (uint256);
    function wearerOf(address hook, uint256 outfitId) external view returns (uint256);
    function svgOf(
        address hook,
        uint256 tokenId,
        bool shouldDressBannyBody,
        bool shouldIncludeBackgroundOnBannyBody
    )
        external
        view
        returns (string memory);
    function namesOf(
        address hook,
        uint256 tokenId
    )
        external
        view
        returns (string memory, string memory, string memory);

    function decorateBannyWith(
        address hook,
        uint256 bannyBodyId,
        uint256 backgroundId,
        uint256[] calldata outfitIds
    )
        external;

    function lockOutfitChangesFor(address hook, uint256 bannyBodyId) external;

    function setSvgContentsOf(uint256[] memory upcs, string[] calldata svgContents) external;
    function setSvgHashsOf(uint256[] memory upcs, bytes32[] memory svgHashs) external;
    function setProductNames(uint256[] memory upcs, string[] memory names) external;
    function setSvgBaseUri(string calldata baseUri) external;
}
