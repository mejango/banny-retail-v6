// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";

/// @notice Mock hook for audit gap testing.
contract AuditGapMockHook {
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

    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @notice Mock store for audit gap testing.
contract AuditGapMockStore {
    mapping(address hook => mapping(uint256 tokenId => JB721Tier)) public tiers;

    function setTier(address hook, uint256 tokenId, JB721Tier memory tier) external {
        tiers[hook][tokenId] = tier;
    }

    function tierOfTokenId(address hook, uint256 tokenId, bool) external view returns (JB721Tier memory) {
        return tiers[hook][tokenId];
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function encodedTierIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function encodedIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/// @title TestAuditGaps
/// @notice Tests for ERC-2771 meta-transaction support and SVG rendering edge cases.
contract TestAuditGaps is Test {
    Banny721TokenUriResolver resolver;
    Banny721TokenUriResolver resolverWithForwarder;
    AuditGapMockHook hook;
    AuditGapMockStore store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address forwarder = makeAddr("forwarder");

    // Token IDs: product ID * 1_000_000_000 + sequence.
    uint256 constant BODY_TOKEN = 4_000_000_001; // Original body (UPC 4, category 0)
    uint256 constant ALIEN_BODY_TOKEN = 1_000_000_001; // Alien body (UPC 1, category 0)
    uint256 constant BACKGROUND_TOKEN = 5_000_000_001; // category 1
    uint256 constant NECKLACE_TOKEN = 10_000_000_001; // category 3
    uint256 constant EYES_TOKEN = 30_000_000_001; // category 5
    uint256 constant MOUTH_TOKEN = 40_000_000_001; // category 7

    function setUp() public {
        store = new AuditGapMockStore();
        hook = new AuditGapMockHook(address(store));

        // Deploy resolver WITHOUT trusted forwarder (address(0)).
        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        // Deploy resolver WITH trusted forwarder.
        vm.prank(deployer);
        resolverWithForwarder = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, forwarder
        );

        // Set up tier data for both resolvers.
        _setupTier(BODY_TOKEN, 4, 0);
        _setupTier(ALIEN_BODY_TOKEN, 1, 0);
        _setupTier(BACKGROUND_TOKEN, 5, 1);
        _setupTier(NECKLACE_TOKEN, 10, 3);
        _setupTier(EYES_TOKEN, 30, 5);
        _setupTier(MOUTH_TOKEN, 40, 7);

        // Give alice all tokens.
        hook.setOwner(BODY_TOKEN, alice);
        hook.setOwner(ALIEN_BODY_TOKEN, alice);
        hook.setOwner(BACKGROUND_TOKEN, alice);
        hook.setOwner(NECKLACE_TOKEN, alice);
        hook.setOwner(EYES_TOKEN, alice);
        hook.setOwner(MOUTH_TOKEN, alice);

        // Approve both resolvers for alice.
        vm.startPrank(alice);
        hook.setApprovalForAll(address(resolver), true);
        hook.setApprovalForAll(address(resolverWithForwarder), true);
        vm.stopPrank();
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
                cannotBeRemoved: false,
                cannotIncreaseDiscountPercent: false,
                cantBuyWithCredits: false,
                splitPercent: 0,
                resolvedUri: ""
            })
        );
    }

    /// @notice Helper to build ERC-2771 calldata: original calldata + 20-byte sender suffix.
    function _buildForwarderCalldata(
        bytes memory originalCalldata,
        address sender
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(originalCalldata, sender);
    }

    //*********************************************************************//
    // --- Meta-Transaction (ERC-2771) Tests ----------------------------- //
    //*********************************************************************//

    /// @notice When no forwarder is set (address(0)), _msgSender() returns msg.sender.
    function test_metaTx_noForwarder_msgSenderIsCaller() public {
        // When forwarder is address(0), directly calling as alice should work.
        uint256[] memory outfitIds = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
        // No revert means _msgSender() returned alice (the actual caller).
    }

    /// @notice The resolver properly reports the trusted forwarder.
    function test_metaTx_trustedForwarderIsSet() public view {
        assertEq(resolverWithForwarder.trustedForwarder(), forwarder, "forwarder should match");
        assertTrue(resolverWithForwarder.isTrustedForwarder(forwarder), "should recognize forwarder");
        assertFalse(resolverWithForwarder.isTrustedForwarder(alice), "alice is not forwarder");
    }

    /// @notice When forwarder is address(0), the resolver reports no trusted forwarder.
    function test_metaTx_zeroForwarderReportsNone() public view {
        assertEq(resolver.trustedForwarder(), address(0), "no forwarder when address(0)");
        assertFalse(resolver.isTrustedForwarder(forwarder), "should not trust any forwarder");
    }

    /// @notice Trusted forwarder can relay a lockOutfitChangesFor call on behalf of alice.
    function test_metaTx_forwarderRelaysLock() public {
        // Build the calldata that the forwarder would send: original function calldata + alice's address.
        bytes memory originalCalldata =
            abi.encodeCall(Banny721TokenUriResolver.lockOutfitChangesFor, (address(hook), BODY_TOKEN));
        bytes memory forwarderCalldata = _buildForwarderCalldata(originalCalldata, alice);

        // Call from the forwarder address with suffixed calldata.
        vm.prank(forwarder);
        (bool success,) = address(resolverWithForwarder).call(forwarderCalldata);
        assertTrue(success, "forwarder relay should succeed");

        // Verify the lock was applied.
        uint256 lockedUntil = resolverWithForwarder.outfitLockedUntil(address(hook), BODY_TOKEN);
        assertEq(lockedUntil, block.timestamp + 7 days, "lock should be set for 7 days");
    }

    /// @notice Trusted forwarder can relay decorateBannyWith on behalf of alice.
    function test_metaTx_forwarderRelaysDecorate() public {
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = NECKLACE_TOKEN;

        bytes memory originalCalldata =
            abi.encodeCall(Banny721TokenUriResolver.decorateBannyWith, (address(hook), BODY_TOKEN, 0, outfitIds));
        bytes memory forwarderCalldata = _buildForwarderCalldata(originalCalldata, alice);

        vm.prank(forwarder);
        (bool success,) = address(resolverWithForwarder).call(forwarderCalldata);
        assertTrue(success, "forwarder relay of decorate should succeed");

        // Verify the necklace is worn by the body.
        assertEq(resolverWithForwarder.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace should be worn");
    }

    /// @notice Non-forwarder cannot spoof _msgSender by appending an address suffix.
    function test_metaTx_nonForwarderCannotSpoof() public {
        // Bob (not the forwarder) tries to send calldata with alice's address appended.
        // When msg.sender is not the forwarder, the suffix is ignored and msg.sender is used.
        uint256[] memory outfitIds = new uint256[](0);

        bytes memory originalCalldata =
            abi.encodeCall(Banny721TokenUriResolver.decorateBannyWith, (address(hook), BODY_TOKEN, 0, outfitIds));
        bytes memory spoofedCalldata = _buildForwarderCalldata(originalCalldata, alice);

        // Bob calls with spoofed calldata. Since bob is not the forwarder,
        // _msgSender() returns bob (not alice), so this should revert
        // because bob doesn't own the body.
        vm.prank(bob);
        (bool success,) = address(resolverWithForwarder).call(spoofedCalldata);
        assertFalse(success, "non-forwarder spoof should fail");
    }

    /// @notice When the forwarder relays but the suffixed sender does not own the body, it reverts.
    function test_metaTx_forwarderRelayUnauthorizedUser() public {
        // Relay on behalf of bob, who does not own the body token.
        uint256[] memory outfitIds = new uint256[](0);
        bytes memory originalCalldata =
            abi.encodeCall(Banny721TokenUriResolver.decorateBannyWith, (address(hook), BODY_TOKEN, 0, outfitIds));
        bytes memory forwarderCalldata = _buildForwarderCalldata(originalCalldata, bob);

        vm.prank(forwarder);
        (bool success,) = address(resolverWithForwarder).call(forwarderCalldata);
        assertFalse(success, "forwarder relay for non-owner should revert");
    }

    /// @notice Owner-only operations (setMetadata) work via meta-transaction when relayed by forwarder on behalf of
    /// owner.
    function test_metaTx_forwarderRelaysOwnerAction() public {
        bytes memory originalCalldata = abi.encodeCall(
            Banny721TokenUriResolver.setMetadata, ("Meta desc", "https://meta.url", "https://meta.base/")
        );
        bytes memory forwarderCalldata = _buildForwarderCalldata(originalCalldata, deployer);

        vm.prank(forwarder);
        (bool success,) = address(resolverWithForwarder).call(forwarderCalldata);
        assertTrue(success, "forwarder relay of owner setMetadata should succeed");

        assertEq(resolverWithForwarder.svgDescription(), "Meta desc");
        assertEq(resolverWithForwarder.svgExternalUrl(), "https://meta.url");
        assertEq(resolverWithForwarder.svgBaseUri(), "https://meta.base/");
    }

    /// @notice Owner-only operations fail when forwarder relays on behalf of non-owner.
    function test_metaTx_forwarderRelaysNonOwnerAction_reverts() public {
        bytes memory originalCalldata =
            abi.encodeCall(Banny721TokenUriResolver.setMetadata, ("Evil", "https://evil.url", "https://evil.base/"));
        bytes memory forwarderCalldata = _buildForwarderCalldata(originalCalldata, alice);

        vm.prank(forwarder);
        (bool success,) = address(resolverWithForwarder).call(forwarderCalldata);
        assertFalse(success, "forwarder relay of non-owner setMetadata should revert");
    }

    /// @notice Direct call to resolver with forwarder works normally (no ERC-2771 decoding for non-forwarder callers).
    function test_metaTx_directCallStillWorks() public {
        // Alice calls directly (not via forwarder). Should still work.
        uint256[] memory outfitIds = new uint256[](0);
        vm.prank(alice);
        resolverWithForwarder.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
        // No revert means it worked.
    }

    /// @notice Forwarder relaying setProductNames on behalf of owner succeeds.
    function test_metaTx_forwarderRelaysSetProductNames() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        string[] memory names = new string[](1);
        names[0] = "Relayed Hat";

        bytes memory originalCalldata = abi.encodeCall(Banny721TokenUriResolver.setProductNames, (upcs, names));
        bytes memory forwarderCalldata = _buildForwarderCalldata(originalCalldata, deployer);

        vm.prank(forwarder);
        (bool success,) = address(resolverWithForwarder).call(forwarderCalldata);
        assertTrue(success, "forwarder relay of setProductNames should succeed");
    }

    /// @notice Forwarder relaying setSvgHashesOf on behalf of owner succeeds.
    function test_metaTx_forwarderRelaysSetSvgHashes() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("relayed-svg");

        bytes memory originalCalldata = abi.encodeCall(Banny721TokenUriResolver.setSvgHashesOf, (upcs, hashes));
        bytes memory forwarderCalldata = _buildForwarderCalldata(originalCalldata, deployer);

        vm.prank(forwarder);
        (bool success,) = address(resolverWithForwarder).call(forwarderCalldata);
        assertTrue(success, "forwarder relay of setSvgHashesOf should succeed");

        assertEq(resolverWithForwarder.svgHashOf(100), keccak256("relayed-svg"));
    }

    //*********************************************************************//
    // --- SVG Sanitization / Rendering Edge Cases ----------------------- //
    //*********************************************************************//

    /// @notice SVG content with special HTML characters is stored and rendered faithfully (no sanitization needed
    ///         because output is base64-encoded).
    function test_svg_specialCharactersInContent() public {
        string memory svgWithSpecialChars = '<rect x="10" y="20" width="100" height="100" fill="red"/>';

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(svgWithSpecialChars));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = svgWithSpecialChars;

        resolver.setSvgContentsOf(upcs, contents);
        // No revert means content was stored successfully.
    }

    /// @notice SVG content containing script tags is stored without filtering (the contract stores
    ///         content as-is; sanitization is expected at the display layer).
    function test_svg_scriptTagContent() public {
        string memory maliciousSvg = '<script>alert("xss")</script><rect width="10" height="10"/>';

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 200;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(maliciousSvg));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = maliciousSvg;

        resolver.setSvgContentsOf(upcs, contents);
        // Content stored as-is. Hash validation passed.
    }

    /// @notice SVG content with onload event handler is stored faithfully.
    function test_svg_eventHandlerContent() public {
        string memory eventHandlerSvg = '<rect onload="alert(1)" width="400" height="400"/>';

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 201;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(eventHandlerSvg));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = eventHandlerSvg;

        resolver.setSvgContentsOf(upcs, contents);
    }

    /// @notice Empty SVG content cannot be stored because the hash of "" would need to be pre-stored,
    ///         and an empty content means no SVG is rendered.
    function test_svg_emptyContentMatchesHash() public {
        string memory emptyContent = "";

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 300;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(emptyContent));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = emptyContent;

        // This should succeed because keccak256("") matches.
        resolver.setSvgContentsOf(upcs, contents);
    }

    /// @notice SVG content with unicode characters (emoji, CJK, etc.) is handled correctly.
    function test_svg_unicodeContent() public {
        // Unicode characters in SVG text elements.
        string memory unicodeSvg = unicode'<text x="10" y="50" font-size="20">Hello \u4e16\u754c</text>';

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 301;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(unicodeSvg));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = unicodeSvg;

        resolver.setSvgContentsOf(upcs, contents);
    }

    /// @notice A very long SVG string can be stored (gas cost scales but no overflow).
    function test_svg_veryLongContent() public {
        // Build a 10KB SVG string.
        bytes memory longSvg = bytes('<rect width="400" height="400" fill="blue"/>');
        bytes memory padding = new bytes(10_000);
        for (uint256 i; i < padding.length; i++) {
            padding[i] = "A";
        }
        string memory longContent = string(abi.encodePacked(longSvg, padding));

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 302;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(longContent));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = longContent;

        resolver.setSvgContentsOf(upcs, contents);
    }

    /// @notice SVG content with JSON-breaking characters (quotes, backslashes) is stored correctly.
    ///         The contract wraps everything in base64, so JSON special chars in the SVG do not break the output.
    function test_svg_jsonBreakingCharacters() public {
        // Quotes and backslashes that would break naive JSON assembly.
        string memory jsonBreakingSvg = '<text>"Hello \\ World"</text>';

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 303;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(jsonBreakingSvg));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = jsonBreakingSvg;

        resolver.setSvgContentsOf(upcs, contents);
    }

    /// @notice tokenUriOf returns empty string for a non-existent product (tier ID 0).
    function test_svg_tokenUriOfNonExistentProduct() public view {
        // Token 99_000_000_001 has no tier set up, so product.id == 0.
        string memory uri = resolver.tokenUriOf(address(hook), 99_000_000_001);
        assertEq(bytes(uri).length, 0, "non-existent product should return empty URI");
    }

    /// @notice svgOf returns empty string for a non-existent product.
    function test_svg_svgOfNonExistentProduct() public view {
        string memory svg = resolver.svgOf(address(hook), 99_000_000_001, true, true);
        assertEq(bytes(svg).length, 0, "non-existent product should return empty SVG");
    }

    /// @notice svgOf for a body with no outfits still produces valid SVG with default decorations.
    function test_svg_nakedBodyProducesValidSvg() public view {
        string memory svg = resolver.svgOf(address(hook), BODY_TOKEN, true, true);
        // Should contain the SVG wrapper.
        assertTrue(bytes(svg).length > 0, "naked body should produce SVG");
        // Check it starts with the expected SVG opening tag.
        assertTrue(_startsWith(svg, "<svg"), "should start with <svg");
        // Check it ends with </svg>.
        assertTrue(_endsWith(svg, "</svg>"), "should end with </svg>");
    }

    /// @notice svgOf for an alien body uses alien-specific eyes defaults.
    function test_svg_alienBodyUsesAlienEyes() public view {
        string memory svg = resolver.svgOf(address(hook), ALIEN_BODY_TOKEN, true, false);
        assertTrue(bytes(svg).length > 0, "alien body should produce SVG");
        // The alien body SVG should contain the alien eyes default.
        assertTrue(_contains(svg, "<alieneyes/>"), "alien body should include default alien eyes");
    }

    /// @notice svgOf for an original body uses standard eyes defaults.
    function test_svg_originalBodyUsesStandardEyes() public view {
        string memory svg = resolver.svgOf(address(hook), BODY_TOKEN, true, false);
        assertTrue(bytes(svg).length > 0, "original body should produce SVG");
        // The original body SVG should contain the standard eyes default.
        assertTrue(_contains(svg, "<eyes/>"), "original body should include default standard eyes");
    }

    /// @notice svgOf for a body with shouldDressBannyBody=false omits default outfits.
    function test_svg_undressedBodyOmitsOutfits() public view {
        string memory svg = resolver.svgOf(address(hook), BODY_TOKEN, false, false);
        assertTrue(bytes(svg).length > 0, "undressed body should produce SVG");
        // Should NOT contain default necklace, eyes, or mouth since dressing is disabled.
        assertFalse(_contains(svg, "<necklace/>"), "undressed body should not include default necklace");
        assertFalse(_contains(svg, "<eyes/>"), "undressed body should not include default eyes");
        assertFalse(_contains(svg, "<mouth/>"), "undressed body should not include default mouth");
    }

    /// @notice Metadata with special characters in description and URL is stored and retrieved correctly.
    function test_svg_metadataWithSpecialChars() public {
        // Set metadata with characters that could break JSON if not base64-encoded.
        vm.prank(deployer);
        resolver.setMetadata(
            'A "special" description with <tags> & ampersands', "https://example.com/path?a=1&b=2", "https://base.uri/"
        );

        assertEq(resolver.svgDescription(), 'A "special" description with <tags> & ampersands');
        assertEq(resolver.svgExternalUrl(), "https://example.com/path?a=1&b=2");
    }

    /// @notice tokenUriOf for a body produces base64-encoded data URI.
    function test_svg_tokenUriOfBodyProducesDataUri() public view {
        string memory uri = resolver.tokenUriOf(address(hook), BODY_TOKEN);
        assertTrue(bytes(uri).length > 0, "body token should have URI");
        // The tokenUriOf should start with data:application/json;base64,
        assertTrue(_startsWith(uri, "data:application/json;base64,"), "URI should be a base64-encoded data URI");
    }

    /// @notice Product name with special characters in setProductNames is stored and retrievable.
    function test_svg_productNameWithSpecialChars() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 400;
        string[] memory names = new string[](1);
        names[0] = 'Cool "Hat" <special>';

        vm.prank(deployer);
        resolver.setProductNames(upcs, names);

        // Set up a tier with UPC 400 to verify via namesOf.
        uint256 tokenId = 400_000_000_001;
        _setupTier(tokenId, 400, 3); // category 3 = necklace

        (,, string memory productName) = resolver.namesOf(address(hook), tokenId);
        assertEq(productName, 'Cool "Hat" <special>');
    }

    /// @notice SVG content with newlines and tabs is stored faithfully.
    function test_svg_newlinesAndTabs() public {
        string memory svgWithWhitespace = "<g>\n\t<rect width=\"10\" height=\"10\"/>\n</g>";

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 304;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(svgWithWhitespace));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = svgWithWhitespace;

        resolver.setSvgContentsOf(upcs, contents);
    }

    /// @notice SVG rendering: body with stored SVG outfit content renders it in the output.
    function test_svg_renderedOutfitContentInSvg() public {
        // Store SVG content for necklace (UPC 10).
        string memory necklaceSvg = '<circle cx="200" cy="300" r="20" fill="gold"/>';
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 10;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(necklaceSvg));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = necklaceSvg;
        resolver.setSvgContentsOf(upcs, contents);

        // Equip the necklace on the body.
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = NECKLACE_TOKEN;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Render the body with outfits.
        string memory svg = resolver.svgOf(address(hook), BODY_TOKEN, true, false);
        assertTrue(bytes(svg).length > 0, "should render SVG");
        // The necklace content should be present in the rendered SVG.
        // Note: custom necklaces are layered after suit_top (category 11) in _outfitContentsFor.
        assertTrue(_contains(svg, necklaceSvg), "rendered SVG should contain necklace content");
    }

    /// @notice SVG rendering: body with background produces SVG containing the background.
    function test_svg_renderedBackgroundInSvg() public {
        // Store SVG content for background (UPC 5).
        string memory bgSvg = '<rect width="400" height="400" fill="skyblue"/>';
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 5;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(bgSvg));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = bgSvg;
        resolver.setSvgContentsOf(upcs, contents);

        // Equip the background on the body.
        uint256[] memory outfitIds = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BACKGROUND_TOKEN, outfitIds);

        // Render with background included.
        string memory svg = resolver.svgOf(address(hook), BODY_TOKEN, true, true);
        assertTrue(_contains(svg, bgSvg), "rendered SVG should contain background content");
    }

    /// @notice SVG rendering: body with background but shouldIncludeBackgroundOnBannyBody=false omits it.
    function test_svg_backgroundExcludedWhenFlagFalse() public {
        // Store SVG content for background (UPC 5).
        string memory bgSvg = '<rect width="400" height="400" fill="skyblue"/>';
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 5;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(bgSvg));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = bgSvg;
        resolver.setSvgContentsOf(upcs, contents);

        // Equip background.
        uint256[] memory outfitIds = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BACKGROUND_TOKEN, outfitIds);

        // Render WITHOUT background.
        string memory svg = resolver.svgOf(address(hook), BODY_TOKEN, true, false);
        assertFalse(_contains(svg, bgSvg), "background should not appear when flag is false");
    }

    //*********************************************************************//
    // --- Helpers ------------------------------------------------------- //
    //*********************************************************************//

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
}
