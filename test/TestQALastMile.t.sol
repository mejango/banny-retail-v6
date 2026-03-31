// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Base64} from "lib/base64/base64.sol";

import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";

/// @notice Mock hook for QA last-mile testing.
contract QAMockHook {
    mapping(uint256 tokenId => address) public ownerOf;
    mapping(uint256 tokenId => uint32) public tierIdOf;
    mapping(uint256 tokenId => uint24) public categoryOf;
    address public immutable MOCK_STORE;
    mapping(address owner => mapping(address operator => bool)) public isApprovedForAll;

    constructor(address store) {
        MOCK_STORE = store;
    }

    function STORE() external view returns (address) {
        return MOCK_STORE;
    }

    function setOwner(uint256 tokenId, address _owner) external {
        ownerOf[tokenId] = _owner;
    }

    function setTier(uint256 tokenId, uint32 tierId, uint24 category) external {
        tierIdOf[tokenId] = tierId;
        categoryOf[tokenId] = category;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(
            msg.sender == ownerOf[tokenId] || msg.sender == from || isApprovedForAll[from][msg.sender],
            "MockHook: not authorized"
        );
        ownerOf[tokenId] = to;

        if (to.code.length > 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            require(retval == IERC721Receiver.onERC721Received.selector, "MockHook: receiver rejected");
        }
    }

    function pricingContext() external pure returns (uint256, uint256) {
        return (1, 18);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @notice Mock store for QA last-mile testing.
contract QAMockStore {
    mapping(address hook => mapping(uint256 tokenId => JB721Tier)) public tiers;
    mapping(address hook => mapping(uint256 tierId => bytes32)) public ipfsUris;

    function setTier(address hook, uint256 tokenId, JB721Tier memory tier) external {
        tiers[hook][tokenId] = tier;
    }

    function tierOfTokenId(address hook, uint256 tokenId, bool) external view returns (JB721Tier memory) {
        return tiers[hook][tokenId];
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function setEncodedIPFSUri(address hook, uint256 tierId, bytes32 uri) external {
        ipfsUris[hook][tierId] = uri;
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function encodedTierIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function encodedIPFSUriOf(address hook, uint256 tierId) external view returns (bytes32) {
        return ipfsUris[hook][tierId];
    }
}

/// @title TestQALastMile
/// @notice Last-mile QA tests: tokenURI round-trip decode, SVG-to-IPFS fallback, and 9-outfit gas ceiling.
contract TestQALastMile is Test {
    Banny721TokenUriResolver resolver;
    QAMockHook hook;
    QAMockStore store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");

    // Body: UPC 4, category 0 (Original body).
    uint256 constant BODY_TOKEN = 4_000_000_001;

    // Background: UPC 5, category 1.
    uint256 constant BACKGROUND_TOKEN = 5_000_000_001;

    // Outfit tokens (one per non-conflicting outfit category).
    uint256 constant NECKLACE_TOKEN = 6_000_000_001; // category 3
    uint256 constant EYES_TOKEN = 8_000_000_001; // category 5
    uint256 constant GLASSES_TOKEN = 9_000_000_001; // category 6
    uint256 constant MOUTH_TOKEN = 10_000_000_001; // category 7
    uint256 constant LEGS_TOKEN = 11_000_000_001; // category 8
    uint256 constant SUIT_BOTTOM_TOKEN = 13_000_000_001; // category 10
    uint256 constant SUIT_TOP_TOKEN = 14_000_000_001; // category 11
    uint256 constant HEADTOP_TOKEN = 15_000_000_001; // category 12
    uint256 constant HAND_TOKEN = 16_000_000_001; // category 13

    function setUp() public {
        store = new QAMockStore();
        hook = new QAMockHook(address(store));

        // Deploy resolver with abbreviated SVG constants.
        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            '<g class="b1"><path d="M173 53h4v17h-4z"/></g>',
            '<g class="o"><path d="M190 173h-37v-3h-10"/></g>',
            '<g class="o"><path d="M183 160v-4h-20v4" fill="#ad71c8"/></g>',
            '<g class="o"><path d="M177 140v3h6v11h10v-11h4v-3h-20z"/></g>',
            '<g class="o"><path d="M190 127h3v3h-3z"/></g>',
            deployer,
            address(0)
        );

        // Set metadata so tokenURI JSON is populated.
        vm.prank(deployer);
        resolver.setMetadata("A piece of Banny Retail.", "https://retail.banny.eth.shop", "https://bannyverse.test/");

        // Set up all tiers.
        _setupTier(BODY_TOKEN, 4, 0);
        _setupTier(BACKGROUND_TOKEN, 5, 1);
        _setupTier(NECKLACE_TOKEN, 6, 3);
        _setupTier(EYES_TOKEN, 8, 5);
        _setupTier(GLASSES_TOKEN, 9, 6);
        _setupTier(MOUTH_TOKEN, 10, 7);
        _setupTier(LEGS_TOKEN, 11, 8);
        _setupTier(SUIT_BOTTOM_TOKEN, 13, 10);
        _setupTier(SUIT_TOP_TOKEN, 14, 11);
        _setupTier(HEADTOP_TOKEN, 15, 12);
        _setupTier(HAND_TOKEN, 16, 13);

        // Give alice all tokens.
        hook.setOwner(BODY_TOKEN, alice);
        hook.setOwner(BACKGROUND_TOKEN, alice);
        hook.setOwner(NECKLACE_TOKEN, alice);
        hook.setOwner(EYES_TOKEN, alice);
        hook.setOwner(GLASSES_TOKEN, alice);
        hook.setOwner(MOUTH_TOKEN, alice);
        hook.setOwner(LEGS_TOKEN, alice);
        hook.setOwner(SUIT_BOTTOM_TOKEN, alice);
        hook.setOwner(SUIT_TOP_TOKEN, alice);
        hook.setOwner(HEADTOP_TOKEN, alice);
        hook.setOwner(HAND_TOKEN, alice);

        // Approve resolver for alice.
        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
    }

    function _setupTier(uint256 tokenId, uint32 tierId, uint24 category) internal {
        hook.setTier(tokenId, tierId, category);
        store.setTier(
            address(hook),
            tokenId,
            JB721Tier({
                id: tierId,
                price: 0.01 ether,
                remainingSupply: 100,
                initialSupply: 100,
                votingUnits: 0,
                reserveFrequency: 0,
                reserveBeneficiary: address(0),
                encodedIPFSUri: bytes32(0),
                category: category,
                discountPercent: 0,
                allowOwnerMint: false,
                transfersPausable: false,
                cantBeRemoved: false,
                cantIncreaseDiscountPercent: false,
                cantBuyWithCredits: false,
                splitPercent: 0,
                resolvedUri: ""
            })
        );
    }

    //*********************************************************************//
    // --- Task 1: tokenURI Round-Trip Decode Test ------------------------ //
    //*********************************************************************//

    /// @notice Mint a complete Banny (body + outfit + background), call tokenUriOf(), decode the base64
    ///         data URI, parse the JSON, and validate it has name, image, and attributes fields.
    function test_tokenUri_roundTripDecode() public {
        // Equip one outfit and a background on the body.
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = NECKLACE_TOKEN;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BACKGROUND_TOKEN, outfitIds);

        // Call tokenUriOf.
        string memory uri = resolver.tokenUriOf(address(hook), BODY_TOKEN);

        // Verify the data URI prefix.
        bytes memory uriBytes = bytes(uri);
        string memory prefix = "data:application/json;base64,";
        bytes memory prefixBytes = bytes(prefix);
        assertGt(uriBytes.length, prefixBytes.length, "URI should be longer than the prefix");
        for (uint256 i; i < prefixBytes.length; i++) {
            assertEq(uriBytes[i], prefixBytes[i], "URI prefix mismatch");
        }

        // Extract the base64-encoded portion (everything after the prefix).
        bytes memory base64Portion = new bytes(uriBytes.length - prefixBytes.length);
        for (uint256 i; i < base64Portion.length; i++) {
            base64Portion[i] = uriBytes[prefixBytes.length + i];
        }

        // Decode the base64 payload to get raw JSON bytes.
        bytes memory jsonBytes = Base64.decode(string(base64Portion));
        string memory json = string(jsonBytes);
        assertGt(jsonBytes.length, 0, "decoded JSON should not be empty");

        // Validate the JSON contains required fields: "name", "image", "attributes".
        assertTrue(_contains(json, '"name"'), 'JSON should contain "name" field');
        assertTrue(_contains(json, '"image"'), 'JSON should contain "image" field');
        assertTrue(_contains(json, '"attributes"'), 'JSON should contain "attributes" field');

        // Validate the "image" field contains a valid SVG data URI.
        assertTrue(_contains(json, '"image":"data:image/svg+xml;base64,'), "image field should contain SVG data URI");

        // Extract and decode the SVG from the image field.
        // Find the SVG base64 start marker.
        string memory svgMarker = '"image":"data:image/svg+xml;base64,';
        bytes memory markerBytes = bytes(svgMarker);
        uint256 svgBase64Start = _indexOf(json, svgMarker);
        assertTrue(svgBase64Start != type(uint256).max, "should find SVG base64 start");

        // The SVG base64 starts after the marker and ends at the closing quote + brace.
        uint256 svgDataStart = svgBase64Start + markerBytes.length;
        // Find the closing `"}` which ends the JSON.
        uint256 svgDataEnd = jsonBytes.length - 2; // skip trailing `"}`

        bytes memory svgBase64 = new bytes(svgDataEnd - svgDataStart);
        for (uint256 i; i < svgBase64.length; i++) {
            svgBase64[i] = jsonBytes[svgDataStart + i];
        }

        // Decode the SVG.
        bytes memory svgBytes = Base64.decode(string(svgBase64));
        string memory svg = string(svgBytes);
        assertGt(svgBytes.length, 0, "decoded SVG should not be empty");

        // Validate the SVG structure.
        assertTrue(_startsWith(svg, "<svg"), "SVG should start with <svg");
        assertTrue(_endsWith(svg, "</svg>"), "SVG should end with </svg>");
    }

    //*********************************************************************//
    // --- Task 2: Missing SVG -> IPFS Fallback Test ---------------------- //
    //*********************************************************************//

    /// @notice When an outfit's _svgContentOf[upc] is empty and an IPFS hash is set on the store,
    ///         the _svgOf() function falls back to an <image href="..."> tag with the IPFS-decoded URI.
    function test_tokenUri_svgToIpfsFallback() public {
        // Set a non-zero IPFS hash for the necklace tier (UPC 6) in the mock store.
        // This simulates having an IPFS hash but no on-chain SVG content.
        bytes32 fakeIpfsHash = keccak256("fake-ipfs-content");
        store.setEncodedIPFSUri(address(hook), 6, fakeIpfsHash);

        // Do NOT store any SVG content for UPC 6 (necklace). The _svgContentOf[6] remains empty.
        // This means _svgOf() will fall back to constructing an <image href="..."> tag.

        // Equip the necklace on the body.
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = NECKLACE_TOKEN;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Render the body SVG. The necklace should appear as an <image> tag with the IPFS URI
        // instead of inline SVG content.
        string memory svg = resolver.svgOf(address(hook), BODY_TOKEN, true, false);
        assertGt(bytes(svg).length, 0, "SVG should not be empty");

        // The fallback constructs: <image href="<baseUri><base58Hash>" width="400" height="400"/>
        // where baseUri is svgBaseUri ("https://bannyverse.test/").
        assertTrue(_contains(svg, "<image href="), "SVG should contain an <image href= fallback tag");
        assertTrue(
            _contains(svg, 'width="400" height="400"/>'), "IPFS fallback image should have width and height attributes"
        );

        // Also verify that the tokenUriOf still produces a valid data URI (not the raw IPFS fallback path).
        string memory uri = resolver.tokenUriOf(address(hook), BODY_TOKEN);
        assertTrue(
            _startsWith(uri, "data:application/json;base64,"),
            "tokenURI should still be a base64 data URI even with IPFS fallback outfit"
        );
    }

    //*********************************************************************//
    // --- Task 3: Gas Snapshot for 9-Outfit tokenURI --------------------- //
    //*********************************************************************//

    /// @notice Equip 9 non-conflicting outfits plus a background, then call tokenUriOf() and measure gas.
    ///         This establishes a gas ceiling for the worst-case on-chain SVG rendering.
    function test_tokenUri_gasSnapshot_9outfits() public {
        // Store SVG content for all outfit UPCs so we exercise the full rendering path.
        _storeSvgContent(5, '<rect width="400" height="400" fill="skyblue"/>'); // background
        _storeSvgContent(6, '<circle cx="200" cy="300" r="20" fill="gold"/>'); // necklace
        _storeSvgContent(8, '<circle cx="180" cy="140" r="5" fill="black"/>'); // eyes
        _storeSvgContent(9, '<rect x="170" y="135" width="30" height="10" fill="brown"/>'); // glasses
        _storeSvgContent(10, '<path d="M180 160h20v5h-20z" fill="red"/>'); // mouth
        _storeSvgContent(11, '<rect x="180" y="250" width="20" height="80" fill="blue"/>'); // legs
        _storeSvgContent(13, '<rect x="175" y="200" width="25" height="40" fill="green"/>'); // suit_bottom
        _storeSvgContent(14, '<rect x="175" y="170" width="25" height="30" fill="purple"/>'); // suit_top
        _storeSvgContent(15, '<circle cx="190" cy="100" r="15" fill="yellow"/>'); // headtop
        _storeSvgContent(16, '<rect x="210" y="200" width="10" height="30" fill="orange"/>'); // hand

        // Equip all 9 non-conflicting outfits (sorted by ascending category).
        uint256[] memory outfits = new uint256[](9);
        outfits[0] = NECKLACE_TOKEN; // cat 3
        outfits[1] = EYES_TOKEN; // cat 5
        outfits[2] = GLASSES_TOKEN; // cat 6
        outfits[3] = MOUTH_TOKEN; // cat 7
        outfits[4] = LEGS_TOKEN; // cat 8
        outfits[5] = SUIT_BOTTOM_TOKEN; // cat 10
        outfits[6] = SUIT_TOP_TOKEN; // cat 11
        outfits[7] = HEADTOP_TOKEN; // cat 12
        outfits[8] = HAND_TOKEN; // cat 13

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BACKGROUND_TOKEN, outfits);

        // Verify all 9 outfits are attached.
        (, uint256[] memory attachedOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(attachedOutfits.length, 9, "should have 9 outfits attached");

        // Measure gas for tokenUriOf with maximum outfit count.
        uint256 gasBefore = gasleft();
        string memory uri = resolver.tokenUriOf(address(hook), BODY_TOKEN);
        uint256 gasUsed = gasBefore - gasleft();

        // Verify the URI is valid.
        assertGt(bytes(uri).length, 0, "9-outfit tokenURI should not be empty");
        assertTrue(_startsWith(uri, "data:application/json;base64,"), "9-outfit tokenURI should be a base64 data URI");

        // Log gas used for snapshot tracking.
        emit log_named_uint("Gas used for 9-outfit tokenUriOf", gasUsed);

        // Assert gas stays under 2M (generous ceiling for view calls; typical RPC node limit is 30M+).
        assertLt(gasUsed, 2_000_000, "9-outfit tokenUriOf should use less than 2M gas");
    }

    //*********************************************************************//
    // --- Helpers -------------------------------------------------------- //
    //*********************************************************************//

    /// @notice Store SVG content for a given UPC, with hash pre-commitment.
    function _storeSvgContent(uint256 upc, string memory svgContent) internal {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = upc;

        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(svgContent));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = svgContent;
        resolver.setSvgContentsOf(upcs, contents);
    }

    /// @notice Check if a string starts with a prefix.
    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        if (prefixBytes.length > strBytes.length) return false;
        for (uint256 i; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }

    /// @notice Check if a string ends with a suffix.
    function _endsWith(string memory str, string memory suffix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory suffixBytes = bytes(suffix);
        if (suffixBytes.length > strBytes.length) return false;
        uint256 offset = strBytes.length - suffixBytes.length;
        for (uint256 i; i < suffixBytes.length; i++) {
            if (strBytes[offset + i] != suffixBytes[i]) return false;
        }
        return true;
    }

    /// @notice Check if a string contains a substring.
    function _contains(string memory str, string memory sub) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory subBytes = bytes(sub);
        if (subBytes.length > strBytes.length) return false;
        if (subBytes.length == 0) return true;
        for (uint256 i; i <= strBytes.length - subBytes.length; i++) {
            bool found = true;
            for (uint256 j; j < subBytes.length; j++) {
                if (strBytes[i + j] != subBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    /// @notice Find the index of a substring in a string. Returns type(uint256).max if not found.
    function _indexOf(string memory str, string memory sub) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        bytes memory subBytes = bytes(sub);
        if (subBytes.length > strBytes.length) return type(uint256).max;
        if (subBytes.length == 0) return 0;
        for (uint256 i; i <= strBytes.length - subBytes.length; i++) {
            bool found = true;
            for (uint256 j; j < subBytes.length; j++) {
                if (strBytes[i + j] != subBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return i;
        }
        return type(uint256).max;
    }
}
