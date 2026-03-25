// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";

/// @notice Mock hook that allows setting ownerOf for any token including token 0.
contract DecorateFlowMockHook {
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

/// @notice Mock store for decoration flow tests.
contract DecorateFlowMockStore {
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

/// @title DecorateFlowTests
/// @notice Comprehensive tests for the Banny decoration (dress/undress) flow.
///         Includes tests proving why the L18 outfit authorization fix is needed.
contract DecorateFlowTests is Test {
    Banny721TokenUriResolver resolver;
    DecorateFlowMockHook hook;
    DecorateFlowMockStore store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    // Token IDs: tierId * 1_000_000_000 + sequence.
    // Categories: 0=Body, 1=Background, 2=Backside, 3=Necklace, 4=Head, 5=Eyes,
    //             6=Glasses, 7=Mouth, 8=Legs, 9=Suit, 10=SuitBottom, 11=SuitTop, 12=HeadTop
    uint256 constant BODY_A = 4_000_000_001;
    uint256 constant BODY_B = 4_000_000_002;
    uint256 constant BODY_C = 4_000_000_003;
    uint256 constant BACKGROUND_1 = 5_000_000_001;
    uint256 constant BACKGROUND_2 = 5_000_000_002;
    uint256 constant BACKSIDE = 6_000_000_001;
    uint256 constant NECKLACE_1 = 10_000_000_001;
    uint256 constant NECKLACE_2 = 10_000_000_002;
    uint256 constant HEAD = 20_000_000_001;
    uint256 constant EYES = 30_000_000_001;
    uint256 constant GLASSES = 31_000_000_001;
    uint256 constant MOUTH = 40_000_000_001;
    uint256 constant LEGS = 41_000_000_001;
    uint256 constant SUIT = 50_000_000_001;
    uint256 constant SUIT_BOTTOM = 51_000_000_001;
    uint256 constant SUIT_TOP = 52_000_000_001;
    uint256 constant HEADTOP = 53_000_000_001;

    function setUp() public {
        store = new DecorateFlowMockStore();
        hook = new DecorateFlowMockHook(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        // Set up tier data for all tokens.
        _setupTier(BODY_A, 4, 0);
        _setupTier(BODY_B, 4, 0);
        _setupTier(BODY_C, 4, 0);
        _setupTier(BACKGROUND_1, 5, 1);
        _setupTier(BACKGROUND_2, 5, 1);
        _setupTier(BACKSIDE, 6, 2);
        _setupTier(NECKLACE_1, 10, 3);
        _setupTier(NECKLACE_2, 10, 3);
        _setupTier(HEAD, 20, 4);
        _setupTier(EYES, 30, 5);
        _setupTier(GLASSES, 31, 6);
        _setupTier(MOUTH, 40, 7);
        _setupTier(LEGS, 41, 8);
        _setupTier(SUIT, 50, 9);
        _setupTier(SUIT_BOTTOM, 51, 10);
        _setupTier(SUIT_TOP, 52, 11);
        _setupTier(HEADTOP, 53, 12);

        // Give alice all tokens by default.
        hook.setOwner(BODY_A, alice);
        hook.setOwner(BODY_B, alice);
        hook.setOwner(BODY_C, alice);
        hook.setOwner(BACKGROUND_1, alice);
        hook.setOwner(BACKGROUND_2, alice);
        hook.setOwner(BACKSIDE, alice);
        hook.setOwner(NECKLACE_1, alice);
        hook.setOwner(NECKLACE_2, alice);
        hook.setOwner(HEAD, alice);
        hook.setOwner(EYES, alice);
        hook.setOwner(GLASSES, alice);
        hook.setOwner(MOUTH, alice);
        hook.setOwner(LEGS, alice);
        hook.setOwner(SUIT, alice);
        hook.setOwner(SUIT_BOTTOM, alice);
        hook.setOwner(SUIT_TOP, alice);
        hook.setOwner(HEADTOP, alice);

        // Approve resolver for alice and bob.
        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
        vm.prank(bob);
        hook.setApprovalForAll(address(resolver), true);
        vm.prank(charlie);
        hook.setApprovalForAll(address(resolver), true);
    }

    // =========================================================================
    //  SECTION 1: L18 VULNERABILITY PROOF — Why the diff is needed
    // =========================================================================

    /// @notice CRITICAL TEST: Proves the L18 outfit authorization vulnerability.
    ///
    ///         The OLD code was:
    ///           if (_msgSender() != owner && _msgSender() != IERC721(hook).ownerOf(wearerOf(hook, outfitId)))
    ///
    ///         When an outfit is UNWORN, wearerOf() returns 0. The old code then calls ownerOf(0)
    ///         on the hook contract. If an attacker happens to own token 0 (or a hook returns
    ///         their address for ownerOf(0)), they pass the authorization check and can steal
    ///         any unworn outfit — dressing their body with someone else's NFT.
    ///
    ///         The FIX checks wearerOf == 0 first and immediately reverts, so only the outfit's
    ///         direct owner can use an unworn outfit.
    function test_l18_nonOwnerCannotUseUnwornOutfitViaTokenZero() public {
        // Setup: Bob owns a body and token 0 on the hook. Alice owns a necklace (unworn).
        hook.setOwner(BODY_A, bob);
        hook.setOwner(0, bob); // Bob owns token 0 — this is the attack vector.

        // The necklace is owned by alice and NOT currently worn by any body.
        assertEq(hook.ownerOf(NECKLACE_1), alice, "alice owns the necklace");
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), 0, "necklace is unworn");

        // Bob tries to decorate his body with alice's unworn necklace.
        // OLD CODE BUG: wearerOf(hook, NECKLACE_1) = 0, ownerOf(0) = bob, so bob passes the check.
        // FIXED CODE: wearerOf = 0 → immediate revert with UnauthorizedOutfit.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedOutfit.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Verify: necklace was NOT stolen.
        assertEq(hook.ownerOf(NECKLACE_1), alice, "necklace must still belong to alice");
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), 0, "necklace must remain unworn");
    }

    /// @notice Variant: Even without token 0 trickery, a non-owner cannot use an unworn outfit.
    function test_l18_nonOwnerCannotUseUnwornOutfit_noTokenZero() public {
        // Bob owns a body. Alice owns the necklace. Token 0 has no owner (address(0)).
        hook.setOwner(BODY_A, bob);

        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedOutfit.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    /// @notice The fix preserves the legitimate case: outfit owner CAN use their own unworn outfit.
    function test_l18_outfitOwnerCanUseOwnUnwornOutfit() public {
        // Alice owns both body and necklace. Necklace is unworn.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Necklace is now worn by body A.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);
        assertEq(hook.ownerOf(NECKLACE_1), address(resolver), "resolver holds the necklace");
    }

    /// @notice The fix preserves the legitimate case: owner of a body wearing an outfit
    ///         can reassign it (e.g., move to another body or replace).
    function test_l18_wearerOwnerCanReassignWornOutfit() public {
        // Alice dresses body A with necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Necklace is now worn by body A. Alice owns body A.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);

        // Alice moves necklace from body A to body B (she owns both).
        uint256[] memory outfitsB = new uint256[](1);
        outfitsB[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_B, 0, outfitsB);

        // Necklace moved to body B. Body A no longer has it according to wearerOf.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_B);
        // Note: _attachedOutfitIdsOf for body A retains a stale entry (by design),
        // but wearerOf correctly reports the necklace is NOT on body A.
    }

    /// @notice After alice's body is sold to bob (with outfit on it), bob as the new body
    ///         owner can re-decorate the body and the old outfit is returned to bob.
    function test_l18_newBodyOwnerCanRedecorate() public {
        // Alice dresses body A with necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Simulate: alice sells body A to bob (mock transfer).
        hook.setOwner(BODY_A, bob);

        // Bob now owns body A. The necklace is worn by body A (held by resolver).
        // Bob should be able to redecorate and get the necklace returned to him.
        uint256[] memory empty = new uint256[](0);
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // Necklace returned to bob (the new body owner / msg.sender).
        assertEq(hook.ownerOf(NECKLACE_1), bob, "necklace should be returned to new body owner");
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), 0, "necklace no longer worn");
    }

    /// @notice Third party (charlie) cannot use an outfit worn by alice's body,
    ///         even if charlie owns token 0.
    function test_l18_thirdPartyCannotStealWornOutfit() public {
        // Alice dresses body A with necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Charlie owns a different body and token 0.
        hook.setOwner(BODY_C, charlie);
        hook.setOwner(0, charlie);

        // Charlie tries to use alice's worn necklace on body C.
        // Charlie is NOT the necklace owner (resolver holds it) and NOT body A's owner.
        uint256[] memory charlieOutfits = new uint256[](1);
        charlieOutfits[0] = NECKLACE_1;

        vm.prank(charlie);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedOutfit.selector);
        resolver.decorateBannyWith(address(hook), BODY_C, 0, charlieOutfits);

        // Necklace still on body A.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);
    }

    /// @notice CRITICAL TEST: Same vulnerability exists for backgrounds.
    ///
    ///         Line 1214 (OLD):
    ///           if (_msgSender() != owner && _msgSender() != IERC721(hook).ownerOf(userOf(hook, backgroundId)))
    ///
    ///         When a background is NOT in use, userOf() returns 0. The old code then calls
    ///         ownerOf(0). If the attacker owns token 0, they bypass authorization and can
    ///         steal any unused background.
    function test_l18_nonOwnerCannotUseUnusedBackgroundViaTokenZero() public {
        // Bob owns a body and token 0. Alice owns the background (unused).
        hook.setOwner(BODY_A, bob);
        hook.setOwner(0, bob);

        assertEq(hook.ownerOf(BACKGROUND_1), alice, "alice owns the background");
        assertEq(resolver.userOf(address(hook), BACKGROUND_1), 0, "background is unused");

        // Bob tries to decorate his body with alice's unused background.
        uint256[] memory empty = new uint256[](0);

        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBackground.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);

        // Background must NOT be stolen.
        assertEq(hook.ownerOf(BACKGROUND_1), alice, "background must still belong to alice");
    }

    /// @notice Variant: non-owner cannot use unused background even without token 0 trickery.
    function test_l18_nonOwnerCannotUseUnusedBackground_noTokenZero() public {
        hook.setOwner(BODY_A, bob);

        uint256[] memory empty = new uint256[](0);

        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBackground.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);
    }

    /// @notice Background owner CAN use their own unused background (fix preserves this).
    function test_l18_backgroundOwnerCanUseOwnUnusedBackground() public {
        uint256[] memory empty = new uint256[](0);

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);

        assertEq(resolver.userOf(address(hook), BACKGROUND_1), BODY_A);
        assertEq(hook.ownerOf(BACKGROUND_1), address(resolver));
    }

    // =========================================================================
    //  SECTION 2: Basic Dress Flow
    // =========================================================================

    /// @notice Dress a banny with a single outfit. Verify all state transitions.
    function test_dress_singleOutfit_fullStateCheck() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Token transferred to resolver.
        assertEq(hook.ownerOf(NECKLACE_1), address(resolver));
        // Wearer set.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);
        // assetIdsOf returns the outfit.
        (uint256 bgId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, 0);
        assertEq(outfitIds.length, 1);
        assertEq(outfitIds[0], NECKLACE_1);
    }

    /// @notice Dress with multiple outfits across different categories.
    function test_dress_multipleOutfits_ordered() public {
        // backside(2), necklace(3), eyes(5), mouth(7), legs(8), suit_bottom(10), suit_top(11)
        uint256[] memory outfits = new uint256[](7);
        outfits[0] = BACKSIDE; // cat 2
        outfits[1] = NECKLACE_1; // cat 3
        outfits[2] = EYES; // cat 5
        outfits[3] = MOUTH; // cat 7
        outfits[4] = LEGS; // cat 8
        outfits[5] = SUIT_BOTTOM; // cat 10
        outfits[6] = SUIT_TOP; // cat 11

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Verify all outfits worn.
        assertEq(resolver.wearerOf(address(hook), BACKSIDE), BODY_A);
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);
        assertEq(resolver.wearerOf(address(hook), EYES), BODY_A);
        assertEq(resolver.wearerOf(address(hook), MOUTH), BODY_A);
        assertEq(resolver.wearerOf(address(hook), LEGS), BODY_A);
        assertEq(resolver.wearerOf(address(hook), SUIT_BOTTOM), BODY_A);
        assertEq(resolver.wearerOf(address(hook), SUIT_TOP), BODY_A);

        // All held by resolver.
        assertEq(hook.ownerOf(BACKSIDE), address(resolver));
        assertEq(hook.ownerOf(NECKLACE_1), address(resolver));
        assertEq(hook.ownerOf(EYES), address(resolver));
        assertEq(hook.ownerOf(MOUTH), address(resolver));
        assertEq(hook.ownerOf(LEGS), address(resolver));
        assertEq(hook.ownerOf(SUIT_BOTTOM), address(resolver));
        assertEq(hook.ownerOf(SUIT_TOP), address(resolver));

        (, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(outfitIds.length, 7);
    }

    /// @notice Dress with background only (no outfits).
    function test_dress_backgroundOnly() public {
        uint256[] memory empty = new uint256[](0);

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);

        assertEq(resolver.userOf(address(hook), BACKGROUND_1), BODY_A);
        assertEq(hook.ownerOf(BACKGROUND_1), address(resolver));

        (uint256 bgId,) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, BACKGROUND_1);
    }

    /// @notice Dress with both background and outfits in one call.
    function test_dress_backgroundAndOutfits() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_1; // cat 3
        outfits[1] = EYES; // cat 5

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, outfits);

        assertEq(resolver.userOf(address(hook), BACKGROUND_1), BODY_A);
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);
        assertEq(resolver.wearerOf(address(hook), EYES), BODY_A);

        (uint256 bgId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, BACKGROUND_1);
        assertEq(outfitIds.length, 2);
    }

    // =========================================================================
    //  SECTION 3: Undress Flow
    // =========================================================================

    /// @notice Remove all outfits by passing empty array. Old outfits returned to caller.
    function test_undress_removeAllOutfits() public {
        // First: dress with necklace + eyes.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_1;
        outfits[1] = EYES;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Verify dressed.
        assertEq(hook.ownerOf(NECKLACE_1), address(resolver));
        assertEq(hook.ownerOf(EYES), address(resolver));

        // Undress: pass empty outfits.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // Outfits returned to alice.
        assertEq(hook.ownerOf(NECKLACE_1), alice, "necklace returned");
        assertEq(hook.ownerOf(EYES), alice, "eyes returned");
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), 0, "necklace unworn");
        assertEq(resolver.wearerOf(address(hook), EYES), 0, "eyes unworn");

        (, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(outfitIds.length, 0, "no outfits on body");
    }

    /// @notice Remove background by passing 0. Old background returned to caller.
    function test_undress_removeBackground() public {
        // Dress with background.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);
        assertEq(hook.ownerOf(BACKGROUND_1), address(resolver));

        // Remove background.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        assertEq(hook.ownerOf(BACKGROUND_1), alice, "background returned");
        assertEq(resolver.userOf(address(hook), BACKGROUND_1), 0, "background unused");

        (uint256 bgId,) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, 0, "no background on body");
    }

    /// @notice Strip everything (background + outfits) in one call.
    function test_undress_removeEverything() public {
        // Fully dress.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_1;
        outfits[1] = MOUTH;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, outfits);

        // Strip everything.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // All returned.
        assertEq(hook.ownerOf(BACKGROUND_1), alice);
        assertEq(hook.ownerOf(NECKLACE_1), alice);
        assertEq(hook.ownerOf(MOUTH), alice);

        (uint256 bgId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, 0);
        assertEq(outfitIds.length, 0);
    }

    /// @notice Partial undress: keep some outfits, remove others.
    function test_undress_partial_keepSomeRemoveOthers() public {
        // Dress with necklace(3) + eyes(5) + mouth(7).
        uint256[] memory outfits = new uint256[](3);
        outfits[0] = NECKLACE_1;
        outfits[1] = EYES;
        outfits[2] = MOUTH;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Re-dress: keep only necklace and mouth (eyes removed).
        uint256[] memory keepOutfits = new uint256[](2);
        keepOutfits[0] = NECKLACE_1; // cat 3 — keep
        keepOutfits[1] = MOUTH; // cat 7 — keep
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, keepOutfits);

        // Eyes returned, necklace + mouth still worn.
        assertEq(hook.ownerOf(EYES), alice, "eyes returned");
        assertEq(resolver.wearerOf(address(hook), EYES), 0, "eyes unworn");
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A, "necklace still worn");
        assertEq(resolver.wearerOf(address(hook), MOUTH), BODY_A, "mouth still worn");
    }

    // =========================================================================
    //  SECTION 4: Outfit Replacement
    // =========================================================================

    /// @notice Replace one necklace with another necklace (same category). Old one returned.
    function test_replace_sameCategoryOutfit() public {
        // Dress with necklace 1.
        uint256[] memory outfits1 = new uint256[](1);
        outfits1[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits1);

        // Replace with necklace 2.
        uint256[] memory outfits2 = new uint256[](1);
        outfits2[0] = NECKLACE_2;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits2);

        // Old returned, new worn.
        assertEq(hook.ownerOf(NECKLACE_1), alice, "old necklace returned");
        assertEq(hook.ownerOf(NECKLACE_2), address(resolver), "new necklace held by resolver");
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), 0);
        assertEq(resolver.wearerOf(address(hook), NECKLACE_2), BODY_A);
    }

    /// @notice Replace background with a different background.
    function test_replace_background() public {
        uint256[] memory empty = new uint256[](0);

        // Attach background 1.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);

        // Replace with background 2.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_2, empty);

        assertEq(hook.ownerOf(BACKGROUND_1), alice, "old bg returned");
        assertEq(hook.ownerOf(BACKGROUND_2), address(resolver), "new bg held");
        assertEq(resolver.userOf(address(hook), BACKGROUND_1), 0);
        assertEq(resolver.userOf(address(hook), BACKGROUND_2), BODY_A);
    }

    /// @notice Re-dressing with the same outfit doesn't trigger unnecessary transfers.
    function test_redress_sameOutfit_noUnnecessaryTransfer() public {
        // Dress with necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Re-dress with same necklace. Should not revert or change ownership.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Still worn by body A, held by resolver.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);
        assertEq(hook.ownerOf(NECKLACE_1), address(resolver));
    }

    // =========================================================================
    //  SECTION 5: Multi-Body Outfit Transfer
    // =========================================================================

    /// @notice Move outfit from body A to body B (same owner).
    function test_moveOutfit_betweenOwnedBodies() public {
        // Dress body A with necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Move necklace to body B. Alice owns body A (the current wearer).
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_B, 0, outfits);

        // Necklace now on body B per wearerOf.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_B);
        // Body A's wearerOf for the necklace is no longer body A.
        // (Note: _attachedOutfitIdsOf for body A keeps a stale entry,
        //  but assetIdsOf filters it out via wearerOf cross-check.)
    }

    /// @notice Move background from body A to body B.
    function test_moveBackground_betweenOwnedBodies() public {
        uint256[] memory empty = new uint256[](0);

        // Background on body A.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);

        // Move to body B.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_B, BACKGROUND_1, empty);

        assertEq(resolver.userOf(address(hook), BACKGROUND_1), BODY_B);
        (uint256 bgA,) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgA, 0, "body A has no background");
    }

    /// @notice After body transfer, new owner can undress and reclaim all outfits.
    function test_bodyTransfer_newOwnerCanUndress() public {
        // Alice fully dresses body A.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_1;
        outfits[1] = MOUTH;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, outfits);

        // Transfer body A to bob (simulated).
        hook.setOwner(BODY_A, bob);

        // Bob undresses body A — all assets returned to bob.
        uint256[] memory empty = new uint256[](0);
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        assertEq(hook.ownerOf(NECKLACE_1), bob, "necklace goes to bob");
        assertEq(hook.ownerOf(MOUTH), bob, "mouth goes to bob");
        assertEq(hook.ownerOf(BACKGROUND_1), bob, "background goes to bob");
    }

    // =========================================================================
    //  SECTION 6: Authorization Edge Cases
    // =========================================================================

    /// @notice Non-owner of body cannot decorate it.
    function test_auth_nonBodyOwnerCannotDecorate() public {
        uint256[] memory empty = new uint256[](0);

        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBannyBody.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);
    }

    /// @notice Body owner cannot use someone else's unworn outfit.
    function test_auth_bodyOwnerCannotUseOthersUnwornOutfit() public {
        // Bob owns a body, charlie owns a necklace.
        hook.setOwner(BODY_C, bob);
        hook.setOwner(NECKLACE_1, charlie);

        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedOutfit.selector);
        resolver.decorateBannyWith(address(hook), BODY_C, 0, outfits);
    }

    /// @notice Body owner cannot use an outfit worn by someone else's body.
    function test_auth_cannotUseOutfitWornByOthersBody() public {
        // Alice dresses body A with necklace. Bob owns body B.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        hook.setOwner(BODY_C, bob);

        // Bob tries to steal necklace from alice's body A to put on his body C.
        // Bob doesn't own body A, so he can't authorize the necklace.
        uint256[] memory bobOutfits = new uint256[](1);
        bobOutfits[0] = NECKLACE_1;

        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedOutfit.selector);
        resolver.decorateBannyWith(address(hook), BODY_C, 0, bobOutfits);
    }

    /// @notice Body owner CAN use an outfit currently worn by their own other body.
    function test_auth_canUseOutfitFromOwnOtherBody() public {
        // Alice dresses body A with necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Alice owns body A (the wearer), so she can move the outfit to body B.
        uint256[] memory outfitsB = new uint256[](1);
        outfitsB[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_B, 0, outfitsB);

        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_B);
    }

    // =========================================================================
    //  SECTION 7: Lock Mechanism Interactions
    // =========================================================================

    /// @notice Locked banny cannot be decorated.
    function test_lock_preventsDecoration() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_A);

        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_OutfitChangesLocked.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    /// @notice After lock expires, decoration succeeds.
    function test_lock_canDecorateAfterExpiry() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_A);

        vm.warp(block.timestamp + 7 days + 1);

        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);
    }

    /// @notice Lock does not prevent undressing after body transfer and lock expiry.
    function test_lock_newOwnerCanUndressAfterExpiry() public {
        // Alice dresses and locks body A.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_A);

        // Transfer body to bob.
        hook.setOwner(BODY_A, bob);

        // Bob can't undress during lock.
        uint256[] memory empty = new uint256[](0);
        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_OutfitChangesLocked.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // After lock expires, bob can undress.
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        assertEq(hook.ownerOf(NECKLACE_1), bob, "necklace returned to bob");
    }

    /// @notice A locked body keeps its equipped background until the lock expires, even if the owner also controls an
    /// unlocked destination body.
    function test_lock_preventsMovingBackgroundFromLockedBody() public {
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, new uint256[](0));

        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_A);

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_OutfitChangesLocked.selector);
        resolver.decorateBannyWith(address(hook), BODY_B, BACKGROUND_1, new uint256[](0));
    }

    /// @notice A locked body keeps its equipped outfits until the lock expires, even if the owner also controls an
    /// unlocked destination body.
    function test_lock_preventsMovingOutfitFromLockedBody() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_A);

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_OutfitChangesLocked.selector);
        resolver.decorateBannyWith(address(hook), BODY_B, 0, outfits);
    }

    // =========================================================================
    //  SECTION 8: Complex Multi-Step Scenarios
    // =========================================================================

    /// @notice Full lifecycle: dress → sell body → new owner undresses → old outfits go to buyer.
    function test_lifecycle_dressTransferUndress() public {
        // Step 1: Alice dresses body A with necklace + eyes + background.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_1;
        outfits[1] = EYES;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, outfits);

        // Step 2: Alice sells body A to bob.
        hook.setOwner(BODY_A, bob);

        // Step 3: Bob undresses body A.
        uint256[] memory empty = new uint256[](0);
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // All assets now belong to bob.
        assertEq(hook.ownerOf(NECKLACE_1), bob);
        assertEq(hook.ownerOf(EYES), bob);
        assertEq(hook.ownerOf(BACKGROUND_1), bob);
    }

    /// @notice Dress → replace one outfit → undress → verify only remaining are returned.
    function test_lifecycle_dressReplaceUndress() public {
        // Step 1: Dress with necklace 1 + mouth.
        uint256[] memory outfits1 = new uint256[](2);
        outfits1[0] = NECKLACE_1; // cat 3
        outfits1[1] = MOUTH; // cat 7
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits1);

        // Step 2: Replace necklace with necklace 2 (keep mouth).
        uint256[] memory outfits2 = new uint256[](2);
        outfits2[0] = NECKLACE_2; // cat 3 (replaces necklace 1)
        outfits2[1] = MOUTH; // cat 7 (kept)
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits2);

        // Necklace 1 returned, necklace 2 + mouth worn.
        assertEq(hook.ownerOf(NECKLACE_1), alice, "old necklace returned");
        assertEq(resolver.wearerOf(address(hook), NECKLACE_2), BODY_A);
        assertEq(resolver.wearerOf(address(hook), MOUTH), BODY_A);

        // Step 3: Undress completely.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        assertEq(hook.ownerOf(NECKLACE_2), alice, "necklace 2 returned");
        assertEq(hook.ownerOf(MOUTH), alice, "mouth returned");
    }

    /// @notice Multi-body scenario: dress body A, dress body B, undress body A,
    ///         verify body B's outfits are unaffected.
    function test_lifecycle_multiBodiesIndependent() public {
        // Dress body A with necklace.
        uint256[] memory outfitsA = new uint256[](1);
        outfitsA[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfitsA);

        // Dress body B with mouth.
        uint256[] memory outfitsB = new uint256[](1);
        outfitsB[0] = MOUTH;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_B, 0, outfitsB);

        // Undress body A.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // Body A stripped, body B unaffected.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), 0, "necklace removed from A");
        assertEq(hook.ownerOf(NECKLACE_1), alice, "necklace returned");
        assertEq(resolver.wearerOf(address(hook), MOUTH), BODY_B, "mouth still on B");
        assertEq(hook.ownerOf(MOUTH), address(resolver), "mouth still held by resolver");
    }

    /// @notice Rapid re-dressing: dress → undress → dress → undress. No state leaks.
    function test_lifecycle_rapidDressUndressCycles() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        uint256[] memory empty = new uint256[](0);

        for (uint256 i; i < 5; i++) {
            // Dress.
            vm.prank(alice);
            resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
            assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);
            assertEq(hook.ownerOf(NECKLACE_1), address(resolver));

            // Undress.
            vm.prank(alice);
            resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);
            assertEq(resolver.wearerOf(address(hook), NECKLACE_1), 0);
            assertEq(hook.ownerOf(NECKLACE_1), alice);
        }
    }

    /// @notice Three bodies, one outfit — prove outfit can only be on one body at a time.
    function test_outfitExclusivity_acrossThreeBodies() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        // Put necklace on body A.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A);

        // Move to body B. wearerOf should update atomically.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_B, 0, outfits);
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_B);

        // Move to body C.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_C, 0, outfits);
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_C);

        // Only body C shows the necklace as worn. The other bodies' stale entries
        // are filtered by wearerOf's cross-check against _attachedOutfitIdsOf.
    }

    // =========================================================================
    //  SECTION 9: Category Conflict Rules
    // =========================================================================

    /// @notice Head + glasses conflict.
    function test_conflict_headAndGlasses() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = HEAD; // cat 4
        outfits[1] = GLASSES; // cat 6

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    /// @notice Head + headtop conflict.
    function test_conflict_headAndHeadtop() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = HEAD; // cat 4
        outfits[1] = HEADTOP; // cat 12

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    /// @notice Suit bottom + suit top (no full suit) is valid.
    function test_noConflict_suitBottomAndTop() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = SUIT_BOTTOM; // cat 10
        outfits[1] = SUIT_TOP; // cat 11

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        assertEq(resolver.wearerOf(address(hook), SUIT_BOTTOM), BODY_A);
        assertEq(resolver.wearerOf(address(hook), SUIT_TOP), BODY_A);
    }

    /// @notice Eyes + mouth + glasses (no head) is valid.
    function test_noConflict_eyesMouthGlasses() public {
        uint256[] memory outfits = new uint256[](3);
        outfits[0] = EYES; // cat 5
        outfits[1] = GLASSES; // cat 6
        outfits[2] = MOUTH; // cat 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        assertEq(resolver.wearerOf(address(hook), EYES), BODY_A);
        assertEq(resolver.wearerOf(address(hook), GLASSES), BODY_A);
        assertEq(resolver.wearerOf(address(hook), MOUTH), BODY_A);
    }

    // =========================================================================
    //  SECTION 10: Edge Cases
    // =========================================================================

    /// @notice Decorating with no outfits and no background is a no-op.
    function test_edge_emptyDecoration() public {
        uint256[] memory empty = new uint256[](0);

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        (uint256 bgId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, 0);
        assertEq(outfitIds.length, 0);
    }

    /// @notice Undressing an already undressed body is a no-op (no revert).
    function test_edge_undressAlreadyNaked() public {
        uint256[] memory empty = new uint256[](0);

        // Should not revert even though there's nothing to remove.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        (uint256 bgId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, 0);
        assertEq(outfitIds.length, 0);
    }

    /// @notice Same background on same body — no unnecessary transfer.
    function test_edge_sameBackgroundSameBody() public {
        uint256[] memory empty = new uint256[](0);

        // Attach background.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);

        // Re-apply same background. Should not revert.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);

        assertEq(resolver.userOf(address(hook), BACKGROUND_1), BODY_A);
    }

    // =========================================================================
    //  Helpers
    // =========================================================================

    function _setupTier(uint256 tokenId, uint32 tierId, uint24 category) internal {
        hook.setTier(tokenId, tierId, category);
        store.setTier(
            address(hook),
            tokenId,
            JB721Tier({
                id: tierId,
                price: 0,
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
            })
        );
    }
}
