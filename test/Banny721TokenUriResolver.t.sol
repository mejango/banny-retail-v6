// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {IERC721} from "@bananapus/721-hook-v6/src/abstract/ERC721.sol";
import {IJB721TiersHook} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHook.sol";
import {IJB721TiersHookStore} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHookStore.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";

/// @notice Minimal mock hook for testing. Tracks owners and categories for mock 721 tokens.
contract MockHook {
    // Mock owner tracking.
    mapping(uint256 tokenId => address) public ownerOf;

    // Mock tier data: tokenId => (tierId, category).
    mapping(uint256 tokenId => uint32) public tierIdOf;
    mapping(uint256 tokenId => uint24) public categoryOf;

    // Mock store.
    address public immutable MOCK_STORE;

    // Approval tracking.
    mapping(address owner => mapping(address operator => bool)) public isApprovedForAll;

    constructor(address store) {
        MOCK_STORE = store;
    }

    function STORE() external view returns (address) {
        return MOCK_STORE;
    }

    function setOwner(uint256 tokenId, address owner) external {
        ownerOf[tokenId] = owner;
    }

    function setTier(uint256 tokenId, uint32 tierId, uint24 category) external {
        tierIdOf[tokenId] = tierId;
        categoryOf[tokenId] = category;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    // Minimal safeTransferFrom mock.
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(
            msg.sender == ownerOf[tokenId] || msg.sender == from || isApprovedForAll[from][msg.sender],
            "MockHook: not authorized"
        );
        ownerOf[tokenId] = to;

        // Call onERC721Received if to is a contract.
        if (to.code.length > 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            require(retval == IERC721Receiver.onERC721Received.selector, "MockHook: receiver rejected");
        }
    }

    function pricingContext() external pure returns (uint256 currency, uint256 decimals, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @notice Minimal mock store.
contract MockStore {
    mapping(address hook => mapping(uint256 tokenId => JB721Tier)) public tiers;

    function setTier(address hook, uint256 tokenId, JB721Tier memory tier) external {
        tiers[hook][tokenId] = tier;
    }

    function tierOfTokenId(address hook, uint256 tokenId, bool) external view returns (JB721Tier memory) {
        return tiers[hook][tokenId];
    }

    function encodedTierIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }

    function encodedIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/// @notice Tests for Banny721TokenUriResolver.
contract TestBanny721TokenUriResolver is Test {
    Banny721TokenUriResolver resolver;
    MockHook hook;
    MockStore store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Token IDs: product ID * 1_000_000_000 + sequence.
    // Product ID 1 = Alien body (UPC 1, category 0)
    // Product ID 4 = Original body (UPC 4, category 0)
    // Product ID 5 = background (category 1)
    // Product ID 10 = necklace (category 3)
    // Product ID 20 = head (category 4)
    // Product ID 30 = eyes (category 5)
    // Product ID 40 = mouth (category 7)
    // Product ID 50 = suit (category 9)
    // Product ID 51 = suit_bottom (category 10)
    // Product ID 52 = suit_top (category 11)

    uint256 constant BODY_TOKEN = 4_000_000_001; // Original body, token 1
    uint256 constant BACKGROUND_TOKEN = 5_000_000_001;
    uint256 constant NECKLACE_TOKEN = 10_000_000_001;
    uint256 constant HEAD_TOKEN = 20_000_000_001;
    uint256 constant EYES_TOKEN = 30_000_000_001;
    uint256 constant MOUTH_TOKEN = 40_000_000_001;
    uint256 constant SUIT_TOKEN = 50_000_000_001;
    uint256 constant SUIT_BOTTOM_TOKEN = 51_000_000_001;
    uint256 constant SUIT_TOP_TOKEN = 52_000_000_001;

    function setUp() public {
        store = new MockStore();
        hook = new MockHook(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", // bannyBody
            "<necklace/>", // defaultNecklace
            "<mouth/>", // defaultMouth
            "<eyes/>", // defaultStandardEyes
            "<alieneyes/>", // defaultAlienEyes
            deployer, // owner
            address(0) // trustedForwarder
        );

        // Set up tier data in mock store for each token.
        _setupTier(BODY_TOKEN, 4, 0); // Original body
        _setupTier(BACKGROUND_TOKEN, 5, 1); // Background
        _setupTier(NECKLACE_TOKEN, 10, 3); // Necklace
        _setupTier(HEAD_TOKEN, 20, 4); // Head
        _setupTier(EYES_TOKEN, 30, 5); // Eyes
        _setupTier(MOUTH_TOKEN, 40, 7); // Mouth
        _setupTier(SUIT_TOKEN, 50, 9); // Suit
        _setupTier(SUIT_BOTTOM_TOKEN, 51, 10); // Suit bottom
        _setupTier(SUIT_TOP_TOKEN, 52, 11); // Suit top

        // Give alice all tokens.
        hook.setOwner(BODY_TOKEN, alice);
        hook.setOwner(BACKGROUND_TOKEN, alice);
        hook.setOwner(NECKLACE_TOKEN, alice);
        hook.setOwner(HEAD_TOKEN, alice);
        hook.setOwner(EYES_TOKEN, alice);
        hook.setOwner(MOUTH_TOKEN, alice);
        hook.setOwner(SUIT_TOKEN, alice);
        hook.setOwner(SUIT_BOTTOM_TOKEN, alice);
        hook.setOwner(SUIT_TOP_TOKEN, alice);

        // Approve resolver to manage tokens for alice.
        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
    }

    //*********************************************************************//
    // --- Constructor --------------------------------------------------- //
    //*********************************************************************//

    function test_constructor_setsDefaults() public {
        assertEq(resolver.BANNY_BODY(), "<path/>");
        assertEq(resolver.DEFAULT_NECKLACE(), "<necklace/>");
        assertEq(resolver.DEFAULT_MOUTH(), "<mouth/>");
        assertEq(resolver.DEFAULT_STANDARD_EYES(), "<eyes/>");
        assertEq(resolver.DEFAULT_ALIEN_EYES(), "<alieneyes/>");
        assertEq(resolver.owner(), deployer);
    }

    //*********************************************************************//
    // --- Owner-Only: setMetadata --------------------------------------- //
    //*********************************************************************//

    function test_setMetadata() public {
        vm.prank(deployer);
        resolver.setMetadata("New description", "https://new.url", "https://svg.example.com/");
        assertEq(resolver.svgDescription(), "New description");
        assertEq(resolver.svgExternalUrl(), "https://new.url");
        assertEq(resolver.svgBaseUri(), "https://svg.example.com/");
    }

    function test_setMetadata_skipsEmptyStrings() public {
        vm.startPrank(deployer);
        resolver.setMetadata("Initial desc", "https://initial.url", "https://initial.base/");

        // Passing empty strings should leave existing values unchanged.
        resolver.setMetadata("", "", "");
        assertEq(resolver.svgDescription(), "Initial desc");
        assertEq(resolver.svgExternalUrl(), "https://initial.url");
        assertEq(resolver.svgBaseUri(), "https://initial.base/");

        // Passing one non-empty value should only update that field.
        resolver.setMetadata("Updated desc", "", "");
        assertEq(resolver.svgDescription(), "Updated desc");
        assertEq(resolver.svgExternalUrl(), "https://initial.url");
        assertEq(resolver.svgBaseUri(), "https://initial.base/");
        vm.stopPrank();
    }

    function test_setMetadata_revertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        resolver.setMetadata("evil", "https://evil.com/", "https://evil.svg/");
    }

    //*********************************************************************//
    // --- Owner-Only: setProductNames ----------------------------------- //
    //*********************************************************************//

    function test_setProductNames() public {
        uint256[] memory upcs = new uint256[](2);
        upcs[0] = 100;
        upcs[1] = 200;

        string[] memory names = new string[](2);
        names[0] = "Cool Hat";
        names[1] = "Fancy Suit";

        vm.prank(deployer);
        resolver.setProductNames(upcs, names);

        // Verify via namesOf (requires tier with that UPC).
    }

    function test_setProductNames_revertsIfNotOwner() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;

        string[] memory names = new string[](1);
        names[0] = "Hacked";

        vm.prank(alice);
        vm.expectRevert();
        resolver.setProductNames(upcs, names);
    }

    //*********************************************************************//
    // --- Owner-Only: setSvgHashesOf ------------------------------------- //
    //*********************************************************************//

    function test_setSvgHashesOf() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;

        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("test-svg-content");

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        assertEq(resolver.svgHashOf(100), keccak256("test-svg-content"));
    }

    function test_setSvgHashesOf_revertsIfAlreadyStored() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("test");

        vm.startPrank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        // Second attempt should revert.
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HashAlreadyStored.selector);
        resolver.setSvgHashesOf(upcs, hashes);
        vm.stopPrank();
    }

    function test_setSvgHashesOf_revertsIfNotOwner() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("test");

        vm.prank(alice);
        vm.expectRevert();
        resolver.setSvgHashesOf(upcs, hashes);
    }

    //*********************************************************************//
    // --- setSvgContentsOf ---------------------------------------------- //
    //*********************************************************************//

    function test_setSvgContentsOf_matchingHash() public {
        string memory content = "test-svg-content";

        // Store hash first (owner-only).
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(content));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        // Anyone can store content if hash matches.
        string[] memory contents = new string[](1);
        contents[0] = content;

        vm.prank(alice);
        resolver.setSvgContentsOf(upcs, contents);
    }

    function test_setSvgContentsOf_revertsIfNoHash() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 999; // No hash set.
        string[] memory contents = new string[](1);
        contents[0] = "anything";

        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HashNotFound.selector);
        resolver.setSvgContentsOf(upcs, contents);
    }

    function test_setSvgContentsOf_revertsIfMismatch() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked("correct-content"));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = "wrong-content";

        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_ContentsMismatch.selector);
        resolver.setSvgContentsOf(upcs, contents);
    }

    function test_setSvgContentsOf_revertsIfAlreadyStored() public {
        string memory content = "test-svg";
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(content));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = content;
        resolver.setSvgContentsOf(upcs, contents);

        // Second time reverts.
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_ContentsAlreadyStored.selector);
        resolver.setSvgContentsOf(upcs, contents);
    }

    //*********************************************************************//
    // --- Lock Mechanism ------------------------------------------------ //
    //*********************************************************************//

    function test_lockOutfitChangesFor() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_TOKEN);

        uint256 lockedUntil = resolver.outfitLockedUntil(address(hook), BODY_TOKEN);
        assertEq(lockedUntil, block.timestamp + 7 days, "should lock for 7 days");
    }

    function test_lockOutfitChangesFor_revertsIfNotOwner() public {
        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBannyBody.selector);
        resolver.lockOutfitChangesFor(address(hook), BODY_TOKEN);
    }

    function test_lockOutfitChangesFor_extendsLock() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_TOKEN);
        uint256 firstLock = resolver.outfitLockedUntil(address(hook), BODY_TOKEN);

        // Warp forward 3 days and re-lock.
        vm.warp(block.timestamp + 3 days);
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_TOKEN);
        uint256 secondLock = resolver.outfitLockedUntil(address(hook), BODY_TOKEN);

        assertGt(secondLock, firstLock, "re-lock should extend the lock");
    }

    function test_lockOutfitChangesFor_cantAccelerate() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_TOKEN);

        // Try to lock again immediately — new lock would be the same as current, not earlier.
        // The contract checks: currentLockedUntil > newLockUntil.
        // Same value passes (not strictly >). So this should succeed.
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_TOKEN);
        // No revert expected since equal is allowed.
    }

    function test_decorateBannyWith_revertsWhenLocked() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_TOKEN);

        uint256[] memory outfitIds = new uint256[](0);

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_OutfitChangesLocked.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    function test_decorateBannyWith_succeedsAfterLockExpires() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_TOKEN);

        // Warp past lock.
        vm.warp(block.timestamp + 7 days + 1);

        uint256[] memory outfitIds = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
        // Should not revert.
    }

    //*********************************************************************//
    // --- decorateBannyWith: Authorization ------------------------------- //
    //*********************************************************************//

    function test_decorateBannyWith_revertsIfNotBodyOwner() public {
        uint256[] memory outfitIds = new uint256[](0);

        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBannyBody.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    //*********************************************************************//
    // --- decorateBannyWith: Category Ordering -------------------------- //
    //*********************************************************************//

    function test_decorateBannyWith_outfitCategoriesMustBeOrdered() public {
        // Pass outfits out of order: mouth (7) before eyes (5).
        uint256[] memory outfitIds = new uint256[](2);
        outfitIds[0] = MOUTH_TOKEN; // category 7
        outfitIds[1] = EYES_TOKEN; // category 5

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnorderedCategories.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    //*********************************************************************//
    // --- decorateBannyWith: Head Conflicts ----------------------------- //
    //*********************************************************************//

    function test_decorateBannyWith_headConflictsWithEyes() public {
        // Head (4) then Eyes (5) should conflict.
        uint256[] memory outfitIds = new uint256[](2);
        outfitIds[0] = HEAD_TOKEN; // category 4
        outfitIds[1] = EYES_TOKEN; // category 5

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    function test_decorateBannyWith_headConflictsWithMouth() public {
        // Head (4) then Mouth (7) should conflict.
        uint256[] memory outfitIds = new uint256[](2);
        outfitIds[0] = HEAD_TOKEN; // category 4
        outfitIds[1] = MOUTH_TOKEN; // category 7

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    //*********************************************************************//
    // --- decorateBannyWith: Suit Conflicts ----------------------------- //
    //*********************************************************************//

    function test_decorateBannyWith_suitConflictsWithSuitBottom() public {
        // Suit (9) then Suit bottom (10) should conflict.
        uint256[] memory outfitIds = new uint256[](2);
        outfitIds[0] = SUIT_TOKEN; // category 9
        outfitIds[1] = SUIT_BOTTOM_TOKEN; // category 10

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_SuitAlreadyAdded.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    function test_decorateBannyWith_suitConflictsWithSuitTop() public {
        // Suit (9) then Suit top (11) should conflict.
        uint256[] memory outfitIds = new uint256[](2);
        outfitIds[0] = SUIT_TOKEN; // category 9
        outfitIds[1] = SUIT_TOP_TOKEN; // category 11

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_SuitAlreadyAdded.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    //*********************************************************************//
    // --- decorateBannyWith: Unrecognized Category ---------------------- //
    //*********************************************************************//

    function test_decorateBannyWith_revertsOnBodyCategory() public {
        // Create a token with category 0 (body) — not allowed as outfit.
        uint256 fakeBadToken = 99_000_000_001;
        _setupTier(fakeBadToken, 99, 0); // category 0
        hook.setOwner(fakeBadToken, alice);

        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = fakeBadToken;

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnrecognizedCategory.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    function test_decorateBannyWith_revertsOnBackgroundCategory() public {
        // Category 1 (background) is not allowed as an outfit.
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = BACKGROUND_TOKEN; // category 1

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnrecognizedCategory.selector);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
    }

    //*********************************************************************//
    // --- decorateBannyWith: Background --------------------------------- //
    //*********************************************************************//

    function test_decorateBannyWith_setsBackground() public {
        uint256[] memory outfitIds = new uint256[](0);

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BACKGROUND_TOKEN, outfitIds);

        // Verify background is attached.
        (uint256 backgroundId,) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(backgroundId, BACKGROUND_TOKEN, "background should be attached");

        // Verify the background is "used by" this banny.
        assertEq(resolver.userOf(address(hook), BACKGROUND_TOKEN), BODY_TOKEN, "background user should be banny");
    }

    function test_decorateBannyWith_removesBackground() public {
        // First attach background.
        uint256[] memory outfitIds = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BACKGROUND_TOKEN, outfitIds);

        // Now remove by passing 0.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        (uint256 backgroundId,) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(backgroundId, 0, "background should be removed");
    }

    //*********************************************************************//
    // --- decorateBannyWith: Valid Outfits ------------------------------- //
    //*********************************************************************//

    function test_decorateBannyWith_singleOutfit() public {
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = NECKLACE_TOKEN; // category 3

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Verify outfit is worn.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace should be worn by banny");

        // Verify token was transferred to resolver.
        assertEq(hook.ownerOf(NECKLACE_TOKEN), address(resolver), "necklace should be held by resolver");
    }

    function test_decorateBannyWith_multipleOutfits() public {
        // Necklace (3), Eyes (5), Mouth (7) — all ordered correctly.
        uint256[] memory outfitIds = new uint256[](3);
        outfitIds[0] = NECKLACE_TOKEN; // 3
        outfitIds[1] = EYES_TOKEN; // 5
        outfitIds[2] = MOUTH_TOKEN; // 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN);
        assertEq(resolver.wearerOf(address(hook), EYES_TOKEN), BODY_TOKEN);
        assertEq(resolver.wearerOf(address(hook), MOUTH_TOKEN), BODY_TOKEN);
    }

    //*********************************************************************//
    // --- decorateBannyWith: Replace Outfits ----------------------------- //
    //*********************************************************************//

    function test_decorateBannyWith_replacingOutfitsReturnsOld() public {
        // First: equip necklace.
        uint256[] memory outfitIds1 = new uint256[](1);
        outfitIds1[0] = NECKLACE_TOKEN;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds1);

        // Create a new necklace token.
        uint256 NECKLACE_TOKEN_2 = 11_000_000_001;
        _setupTier(NECKLACE_TOKEN_2, 11, 3); // Same category (3)
        hook.setOwner(NECKLACE_TOKEN_2, alice);

        // Replace with new necklace. Old one should be returned.
        uint256[] memory outfitIds2 = new uint256[](1);
        outfitIds2[0] = NECKLACE_TOKEN_2;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds2);

        // Old necklace returned to alice.
        assertEq(hook.ownerOf(NECKLACE_TOKEN), alice, "old necklace should be returned");
        // New necklace held by resolver.
        assertEq(hook.ownerOf(NECKLACE_TOKEN_2), address(resolver), "new necklace should be held");
    }

    //*********************************************************************//
    // --- onERC721Received ---------------------------------------------- //
    //*********************************************************************//

    function test_onERC721Received_acceptsFromSelf() public {
        bytes4 result = resolver.onERC721Received(address(resolver), alice, 1, "");
        assertEq(result, IERC721Receiver.onERC721Received.selector, "should accept from self");
    }

    function test_onERC721Received_revertsIfNotSelf() public {
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedTransfer.selector);
        resolver.onERC721Received(alice, alice, 1, "");
    }

    //*********************************************************************//
    // --- View: assetIdsOf with no outfits ------------------------------ //
    //*********************************************************************//

    function test_assetIdsOf_empty() public {
        (uint256 backgroundId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(backgroundId, 0, "no background initially");
        assertEq(outfitIds.length, 0, "no outfits initially");
    }

    //*********************************************************************//
    // --- View: userOf / wearerOf --------------------------------------- //
    //*********************************************************************//

    function test_userOf_returnsZeroIfNotAttached() public {
        assertEq(resolver.userOf(address(hook), BACKGROUND_TOKEN), 0, "no user initially");
    }

    function test_wearerOf_returnsZeroIfNotWorn() public {
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), 0, "no wearer initially");
    }

    //*********************************************************************//
    // --- Helpers ------------------------------------------------------- //
    //*********************************************************************//

    function _setupTier(uint256 tokenId, uint32 tierId, uint24 category) internal {
        JB721Tier memory tier = JB721Tier({
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
            splitPercent: 0,
            resolvedUri: ""
        });
        store.setTier(address(hook), tokenId, tier);
        hook.setTier(tokenId, tierId, category);
    }
}
