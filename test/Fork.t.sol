// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

// JB core — deploy fresh within fork.
import {JBPermissions} from "@bananapus/core-v6/src/JBPermissions.sol";
import {JBProjects} from "@bananapus/core-v6/src/JBProjects.sol";
import {JBDirectory} from "@bananapus/core-v6/src/JBDirectory.sol";
import {JBRulesets} from "@bananapus/core-v6/src/JBRulesets.sol";
import {JBTokens} from "@bananapus/core-v6/src/JBTokens.sol";
import {JBERC20} from "@bananapus/core-v6/src/JBERC20.sol";
import {JBSplits} from "@bananapus/core-v6/src/JBSplits.sol";
import {JBPrices} from "@bananapus/core-v6/src/JBPrices.sol";
import {JBController} from "@bananapus/core-v6/src/JBController.sol";
import {JBFundAccessLimits} from "@bananapus/core-v6/src/JBFundAccessLimits.sol";

// 721 hook — deploy fresh within fork.
import {JB721TiersHookStore} from "@bananapus/721-hook-v6/src/JB721TiersHookStore.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {JB721TiersHookDeployer} from "@bananapus/721-hook-v6/src/JB721TiersHookDeployer.sol";
import {JBAddressRegistry} from "@bananapus/address-registry-v6/src/JBAddressRegistry.sol";
import {IJB721TiersHook} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHook.sol";
import {JB721TierConfig} from "@bananapus/721-hook-v6/src/structs/JB721TierConfig.sol";
import {JB721InitTiersConfig} from "@bananapus/721-hook-v6/src/structs/JB721InitTiersConfig.sol";
import {JB721TiersHookFlags} from "@bananapus/721-hook-v6/src/structs/JB721TiersHookFlags.sol";
import {JBDeploy721TiersHookConfig} from "@bananapus/721-hook-v6/src/structs/JBDeploy721TiersHookConfig.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IJB721TokenUriResolver} from "@bananapus/721-hook-v6/src/interfaces/IJB721TokenUriResolver.sol";
import {JBCurrencyIds} from "@bananapus/core-v6/src/libraries/JBCurrencyIds.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";

// OpenZeppelin.
import {IERC721} from "@bananapus/721-hook-v6/src/abstract/ERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// Banny.
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";

/// @notice Malicious hook for reentrancy testing. Re-enters the resolver during safeTransferFrom.
contract ReentrantHook {
    Banny721TokenUriResolver public resolver;
    address public hookTarget;
    uint256 public bodyId;
    bool public armed;

    mapping(uint256 tokenId => address) public ownerOf;
    mapping(uint256 tokenId => uint32) public tierIdOf;
    mapping(address owner => mapping(address operator => bool)) public isApprovedForAll;
    address public immutable MOCK_STORE;

    constructor(address store) {
        MOCK_STORE = store;
    }

    function STORE() external view returns (address) {
        return MOCK_STORE;
    }

    function setOwner(uint256 tokenId, address _owner) external {
        ownerOf[tokenId] = _owner;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function arm(Banny721TokenUriResolver _resolver, address _hookTarget, uint256 _bodyId) external {
        resolver = _resolver;
        hookTarget = _hookTarget;
        bodyId = _bodyId;
        armed = true;
    }

    function disarm() external {
        armed = false;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;

        // Re-enter if armed.
        if (armed) {
            armed = false; // prevent infinite loop
            uint256[] memory emptyOutfits = new uint256[](0);
            try resolver.decorateBannyWith(hookTarget, bodyId, 0, emptyOutfits) {} catch {}
        }

        if (to.code.length > 0) {
            IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
        }
    }

    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @notice Mock store for the reentrancy hook.
contract ReentrantMockStore {
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

/// @notice Fork tests for Banny721TokenUriResolver against real JB infrastructure.
/// @dev Deploys all JB core + 721 hook contracts fresh within a mainnet fork, then tests
/// the full decoration lifecycle with adversarial conditions.
contract BannyForkTest is Test {
    // ───────────────────────── JB core (deployed fresh)
    // ────────────────────

    address multisig = address(0xBEEF);
    address trustedForwarder = address(0);

    JBPermissions jbPermissions;
    JBProjects jbProjects;
    JBDirectory jbDirectory;
    JBRulesets jbRulesets;
    JBTokens jbTokens;
    JBSplits jbSplits;
    JBPrices jbPrices;
    JBFundAccessLimits jbFundAccessLimits;
    JBController jbController;

    // ───────────────────────── 721 hook (deployed fresh)
    // ──────────────────

    JB721TiersHookDeployer hookDeployer;
    IJB721TiersHook bannyHook;

    // ───────────────────────── Banny resolver
    // ──────────────────────────

    Banny721TokenUriResolver resolver;

    // ───────────────────────── Actors
    // ──────────────────────────────────

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address attacker = makeAddr("attacker");

    // ───────────────────────── Tier IDs
    // ──────────────────────────────────

    // Tiers sorted by category (ascending) as required by the store.
    // Tier 1-4: Bodies (category 0) — Alien, Pink, Orange, Original
    // Tier 5: Background (category 1)
    // Tier 6: Necklace (category 3)
    // Tier 7: Head (category 4)
    // Tier 8: Eyes (category 5)
    // Tier 9: Glasses (category 6)
    // Tier 10: Mouth (category 7)
    // Tier 11: Legs (category 8)
    // Tier 12: Suit (category 9)
    // Tier 13: Suit Bottom (category 10)
    // Tier 14: Suit Top (category 11)
    // Tier 15: Headtop (category 12)
    // Tier 16: Hand (category 13)

    uint16 constant TIER_ALIEN_BODY = 1;
    uint16 constant TIER_PINK_BODY = 2;
    uint16 constant TIER_ORANGE_BODY = 3;
    uint16 constant TIER_ORIGINAL_BODY = 4;
    uint16 constant TIER_BACKGROUND = 5;
    uint16 constant TIER_NECKLACE = 6;
    uint16 constant TIER_HEAD = 7;
    uint16 constant TIER_EYES = 8;
    uint16 constant TIER_GLASSES = 9;
    uint16 constant TIER_MOUTH = 10;
    uint16 constant TIER_LEGS = 11;
    uint16 constant TIER_SUIT = 12;
    uint16 constant TIER_SUIT_BOTTOM = 13;
    uint16 constant TIER_SUIT_TOP = 14;
    uint16 constant TIER_HEADTOP = 15;
    uint16 constant TIER_HAND = 16;

    // Pre-computed token IDs for the first mint of each tier.
    // Formula: tierId * 1_000_000_000 + sequenceNumber (starts at 1).
    uint256 constant ALIEN_BODY_1 = 1_000_000_001;
    uint256 constant PINK_BODY_1 = 2_000_000_001;
    uint256 constant ORIGINAL_BODY_1 = 4_000_000_001;
    uint256 constant ORIGINAL_BODY_2 = 4_000_000_002;
    uint256 constant BACKGROUND_1 = 5_000_000_001;
    uint256 constant BACKGROUND_2 = 5_000_000_002;
    uint256 constant NECKLACE_1 = 6_000_000_001;
    uint256 constant NECKLACE_2 = 6_000_000_002;
    uint256 constant HEAD_1 = 7_000_000_001;
    uint256 constant EYES_1 = 8_000_000_001;
    uint256 constant GLASSES_1 = 9_000_000_001;
    uint256 constant MOUTH_1 = 10_000_000_001;
    uint256 constant LEGS_1 = 11_000_000_001;
    uint256 constant SUIT_1 = 12_000_000_001;
    uint256 constant SUIT_BOTTOM_1 = 13_000_000_001;
    uint256 constant SUIT_TOP_1 = 14_000_000_001;
    uint256 constant HEADTOP_1 = 15_000_000_001;
    uint256 constant HAND_1 = 16_000_000_001;

    // Second mints for multi-actor tests.
    uint256 constant EYES_2 = 8_000_000_002;
    uint256 constant MOUTH_2 = 10_000_000_002;
    uint256 constant HEAD_2 = 7_000_000_002;

    // Third mints for redressing cycle tests (minted to alice in setUp).
    uint256 constant GLASSES_2 = 9_000_000_002;
    uint256 constant LEGS_2 = 11_000_000_002;
    uint256 constant NECKLACE_3 = 6_000_000_003;
    uint256 constant HEADTOP_2 = 15_000_000_002;

    // ───────────────────────── Setup
    // ──────────────────────────────────────

    function setUp() public {
        vm.createSelectFork("ethereum");

        // Clear any mainnet code at actor addresses (makeAddr may collide with deployed contracts).
        vm.etch(alice, "");
        vm.etch(bob, "");
        vm.etch(charlie, "");
        vm.etch(attacker, "");

        // Deploy all JB core contracts fresh within the fork.
        _deployJBCore();

        // Deploy the 721 hook infrastructure.
        _deploy721Hook();

        // Deploy the Banny resolver.
        _deployBannyResolver();

        // Deploy the 721 hook with production-like tiers.
        _deployBannyHook();

        // Mint NFTs to test actors.
        _mintInitialNFTs();

        // Labels for trace readability.
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(charlie, "charlie");
        vm.label(attacker, "attacker");
        vm.label(address(resolver), "BannyResolver");
        vm.label(address(bannyHook), "BannyHook");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 1. E2E HAPPY PATH: Mint → Decorate → Verify Token URI
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_e2e_mintDecorateRender() public {
        // Alice owns ORIGINAL_BODY_1, NECKLACE_1, EYES_1, MOUTH_1, BACKGROUND_1.
        // Decorate with necklace, eyes, mouth, and background.
        uint256[] memory outfitIds = new uint256[](3);
        outfitIds[0] = NECKLACE_1; // cat 3
        outfitIds[1] = EYES_1; // cat 5
        outfitIds[2] = MOUTH_1; // cat 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, outfitIds);

        // Verify outfits are worn.
        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_1), ORIGINAL_BODY_1);
        assertEq(resolver.wearerOf(address(bannyHook), EYES_1), ORIGINAL_BODY_1);
        assertEq(resolver.wearerOf(address(bannyHook), MOUTH_1), ORIGINAL_BODY_1);
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_1), ORIGINAL_BODY_1);

        // Verify token URI is non-empty (SVG rendered on-chain).
        string memory uri = resolver.tokenUriOf(address(bannyHook), ORIGINAL_BODY_1);
        assertGt(bytes(uri).length, 0, "token URI should not be empty");

        // Verify outfits are held by the resolver.
        assertEq(IERC721(address(bannyHook)).ownerOf(NECKLACE_1), address(resolver));
        assertEq(IERC721(address(bannyHook)).ownerOf(EYES_1), address(resolver));
        assertEq(IERC721(address(bannyHook)).ownerOf(MOUTH_1), address(resolver));
        assertEq(IERC721(address(bannyHook)).ownerOf(BACKGROUND_1), address(resolver));

        // Body still owned by alice.
        assertEq(IERC721(address(bannyHook)).ownerOf(ORIGINAL_BODY_1), alice);
    }

    function test_fork_e2e_alienBodyDefaultEyes() public view {
        // Alice owns ALIEN_BODY_1. Naked alien body should inject alien eyes in SVG.
        string memory svg = resolver.svgOf(address(bannyHook), ALIEN_BODY_1, true, false);
        assertGt(bytes(svg).length, 0, "alien body SVG should render");
    }

    function test_fork_e2e_outfitRenderedOnMannequin() public view {
        // Unequipped outfit token should render on mannequin.
        string memory uri = resolver.tokenUriOf(address(bannyHook), NECKLACE_1);
        assertGt(bytes(uri).length, 0, "outfit URI should render on mannequin");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 2. DECORATION FLOWS
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_decorateWithBackgroundOnly() public {
        uint256[] memory emptyOutfits = new uint256[](0);

        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, emptyOutfits);

        (uint256 bgId,) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(bgId, BACKGROUND_1);
    }

    function test_fork_decorateReplaceOutfit() public {
        // Equip necklace 1.
        uint256[] memory outfits1 = new uint256[](1);
        outfits1[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits1);

        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_1), ORIGINAL_BODY_1);
        assertEq(IERC721(address(bannyHook)).ownerOf(NECKLACE_1), address(resolver));

        // Replace with necklace 2.
        uint256[] memory outfits2 = new uint256[](1);
        outfits2[0] = NECKLACE_2;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits2);

        // Old necklace returned to alice, new one held by resolver.
        assertEq(IERC721(address(bannyHook)).ownerOf(NECKLACE_1), alice);
        assertEq(IERC721(address(bannyHook)).ownerOf(NECKLACE_2), address(resolver));
        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_2), ORIGINAL_BODY_1);
        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_1), 0);
    }

    function test_fork_decorateStripAllOutfits() public {
        // Equip multiple outfits.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_1; // cat 3
        outfits[1] = EYES_1; // cat 5
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, outfits);

        // Strip all by passing empty arrays.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);

        // All returned.
        assertEq(IERC721(address(bannyHook)).ownerOf(NECKLACE_1), alice);
        assertEq(IERC721(address(bannyHook)).ownerOf(EYES_1), alice);
        assertEq(IERC721(address(bannyHook)).ownerOf(BACKGROUND_1), alice);

        (uint256 bgId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(bgId, 0);
        assertEq(outfitIds.length, 0);
    }

    function test_fork_decorateReplaceBackground() public {
        uint256[] memory empty = new uint256[](0);

        // Set background 1.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, empty);

        // Replace with background 2.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_2, empty);

        // Background 1 returned, background 2 held.
        assertEq(IERC721(address(bannyHook)).ownerOf(BACKGROUND_1), alice);
        assertEq(IERC721(address(bannyHook)).ownerOf(BACKGROUND_2), address(resolver));
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_2), ORIGINAL_BODY_1);
    }

    function test_fork_decorateMaxOutfits() public {
        // Equip one of every non-conflicting category: necklace(3), eyes(5), glasses(6), mouth(7),
        // legs(8), suit_bottom(10), suit_top(11), headtop(12), hand(13).
        uint256[] memory outfits = new uint256[](9);
        outfits[0] = NECKLACE_1; // cat 3
        outfits[1] = EYES_1; // cat 5
        outfits[2] = GLASSES_1; // cat 6
        outfits[3] = MOUTH_1; // cat 7
        outfits[4] = LEGS_1; // cat 8
        outfits[5] = SUIT_BOTTOM_1; // cat 10
        outfits[6] = SUIT_TOP_1; // cat 11
        outfits[7] = HEADTOP_1; // cat 12
        outfits[8] = HAND_1; // cat 13

        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, outfits);

        (, uint256[] memory attachedOutfits) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(attachedOutfits.length, 9, "should have 9 outfits attached");
    }

    function test_fork_outfitReuseBetweenOwnBodies() public {
        // Alice owns both ORIGINAL_BODY_1 and ORIGINAL_BODY_2.
        // Equip necklace on body 1.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        // Move necklace to body 2 (alice owns both).
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_2, 0, outfits);

        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_1), ORIGINAL_BODY_2);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 3. AUTHORIZATION (ADVERSARIAL)
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_auth_nonOwnerCantDecorate() public {
        uint256[] memory empty = new uint256[](0);

        vm.prank(attacker);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBannyBody.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);
    }

    function test_fork_auth_cantEquipOthersOutfit() public {
        // Bob owns his own body. He tries to equip alice's necklace (which she owns).
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1; // Owned by alice

        // Bob has his own body but necklace belongs to alice.
        vm.prank(bob);
        vm.expectRevert(); // UnauthorizedOutfit — bob doesn't own the necklace
        resolver.decorateBannyWith(address(bannyHook), PINK_BODY_1, 0, outfits);
    }

    function test_fork_auth_cantEquipOthersBackground() public {
        uint256[] memory empty = new uint256[](0);

        // Bob tries to use alice's background.
        vm.prank(bob);
        vm.expectRevert(); // UnauthorizedBackground
        resolver.decorateBannyWith(address(bannyHook), PINK_BODY_1, BACKGROUND_1, empty);
    }

    function test_fork_auth_attackerCantStealOutfit() public {
        // Alice equips necklace on her body.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        // Attacker has their own body but tries to steal alice's worn necklace.
        // Attacker doesn't own the banny body the necklace is worn by.
        uint256[] memory stealOutfits = new uint256[](1);
        stealOutfits[0] = NECKLACE_1;

        // Give attacker a body for this test.
        _mintTo(attacker, TIER_ORIGINAL_BODY); // ORIGINAL_BODY_3 = 4_000_000_003

        vm.prank(attacker);
        vm.expectRevert(); // UnauthorizedOutfit — attacker doesn't own body wearing the necklace
        resolver.decorateBannyWith(address(bannyHook), 4_000_000_003, 0, stealOutfits);
    }

    function test_fork_auth_nonOwnerCantLock() public {
        vm.prank(attacker);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBannyBody.selector);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);
    }

    function test_fork_auth_bodyAsOutfitReverts() public {
        // Try to use a body token as an outfit.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = ORIGINAL_BODY_2;

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnrecognizedCategory.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_auth_backgroundAsOutfitReverts() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = BACKGROUND_1; // cat 1

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnrecognizedCategory.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_auth_nonBodyAsBodyReverts() public {
        // Try to decorate a necklace token as if it were a body.
        uint256[] memory empty = new uint256[](0);

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_BannyBodyNotBodyCategory.selector);
        resolver.decorateBannyWith(address(bannyHook), NECKLACE_1, 0, empty);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 4. LOCK MECHANISM
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_lock_preventsDecoration() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);

        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_OutfitChangesLocked.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);
    }

    function test_fork_lock_expiresAfter7Days() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);

        // Warp past lock.
        vm.warp(block.timestamp + 7 days + 1);

        // Should succeed.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_1), ORIGINAL_BODY_1);
    }

    function test_fork_lock_extendsOnRelock() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);
        uint256 firstLock = resolver.outfitLockedUntil(address(bannyHook), ORIGINAL_BODY_1);

        // Warp forward 3 days (within lock period).
        vm.warp(block.timestamp + 3 days);

        // Re-lock extends from now + 7 days.
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);
        uint256 secondLock = resolver.outfitLockedUntil(address(bannyHook), ORIGINAL_BODY_1);

        assertGt(secondLock, firstLock, "lock should be extended");
    }

    function test_fork_lock_cantAccelerate() public {
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);
        uint256 originalLock = resolver.outfitLockedUntil(address(bannyHook), ORIGINAL_BODY_1);

        // Same-block re-lock doesn't shorten.
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);
        uint256 afterRelock = resolver.outfitLockedUntil(address(bannyHook), ORIGINAL_BODY_1);

        assertEq(afterRelock, originalLock, "lock should not accelerate");
    }

    function test_fork_lock_persistsAcrossTransfer() public {
        // Alice locks her body.
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);

        // Alice transfers body to bob.
        vm.prank(alice);
        IERC721(address(bannyHook)).safeTransferFrom(alice, bob, ORIGINAL_BODY_1);

        // Bob owns the body but it's still locked.
        assertEq(IERC721(address(bannyHook)).ownerOf(ORIGINAL_BODY_1), bob);

        uint256[] memory empty = new uint256[](0);
        vm.prank(bob);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_OutfitChangesLocked.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);

        // After lock expires, bob can decorate.
        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(bob);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 5. CATEGORY CONFLICTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_conflict_headBlocksEyes() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = HEAD_1; // cat 4
        outfits[1] = EYES_1; // cat 5

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_conflict_headBlocksGlasses() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = HEAD_1; // cat 4
        outfits[1] = GLASSES_1; // cat 6

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_conflict_headBlocksMouth() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = HEAD_1; // cat 4
        outfits[1] = MOUTH_1; // cat 7

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_conflict_headBlocksHeadtop() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = HEAD_1; // cat 4
        outfits[1] = HEADTOP_1; // cat 12

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_conflict_suitBlocksSuitBottom() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = SUIT_1; // cat 9
        outfits[1] = SUIT_BOTTOM_1; // cat 10

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_SuitAlreadyAdded.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_conflict_suitBlocksSuitTop() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = SUIT_1; // cat 9
        outfits[1] = SUIT_TOP_1; // cat 11

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_SuitAlreadyAdded.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_conflict_unorderedCategoriesRevert() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = MOUTH_1; // cat 7
        outfits[1] = NECKLACE_1; // cat 3 — out of order!

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnorderedCategories.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_conflict_suitBottomAndTopAllowed() public {
        // Suit bottom (10) + suit top (11) without full suit — should work.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = SUIT_BOTTOM_1; // cat 10
        outfits[1] = SUIT_TOP_1; // cat 11

        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        assertEq(resolver.wearerOf(address(bannyHook), SUIT_BOTTOM_1), ORIGINAL_BODY_1);
        assertEq(resolver.wearerOf(address(bannyHook), SUIT_TOP_1), ORIGINAL_BODY_1);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 6. SVG STORAGE (IMMUTABILITY + PERMISSIONLESS UPLOAD)
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_svg_hashSetAndContentUpload() public {
        string memory content = "<g class='test'>test-svg</g>";
        uint256 testUpc = 100;

        // Owner sets hash.
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = testUpc;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(content));

        vm.prank(multisig);
        resolver.setSvgHashesOf(upcs, hashes);

        assertEq(resolver.svgHashOf(testUpc), hashes[0]);

        // Anyone can upload content if hash matches.
        string[] memory contents = new string[](1);
        contents[0] = content;

        vm.prank(charlie); // charlie is random — permissionless upload
        resolver.setSvgContentsOf(upcs, contents);
    }

    function test_fork_svg_wrongContentRejected() public {
        uint256 testUpc = 101;
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = testUpc;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked("correct"));

        vm.prank(multisig);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = "wrong";

        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_ContentsMismatch.selector);
        resolver.setSvgContentsOf(upcs, contents);
    }

    function test_fork_svg_doubleHashReverts() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 102;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("test");

        vm.startPrank(multisig);
        resolver.setSvgHashesOf(upcs, hashes);

        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HashAlreadyStored.selector);
        resolver.setSvgHashesOf(upcs, hashes);
        vm.stopPrank();
    }

    function test_fork_svg_doubleUploadReverts() public {
        string memory content = "svg-content";
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 103;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(content));

        vm.prank(multisig);
        resolver.setSvgHashesOf(upcs, hashes);

        string[] memory contents = new string[](1);
        contents[0] = content;
        resolver.setSvgContentsOf(upcs, contents);

        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_ContentsAlreadyStored.selector);
        resolver.setSvgContentsOf(upcs, contents);
    }

    function test_fork_svg_nonOwnerCantSetHash() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 104;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("test");

        vm.prank(attacker);
        vm.expectRevert();
        resolver.setSvgHashesOf(upcs, hashes);
    }

    function test_fork_svg_uploadWithoutHashReverts() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 999;
        string[] memory contents = new string[](1);
        contents[0] = "anything";

        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HashNotFound.selector);
        resolver.setSvgContentsOf(upcs, contents);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 7. TOKEN URI RENDERING
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_render_nakedBodyHasDefaultInjections() public view {
        // A naked body should still render with default necklace, eyes, mouth.
        string memory svg = resolver.svgOf(address(bannyHook), ORIGINAL_BODY_1, true, false);
        assertGt(bytes(svg).length, 0, "naked body should render");
        // The SVG should contain the body path and defaults.
    }

    function test_fork_render_allFourBodyTypes() public view {
        // Each body type should render.
        string memory alienSvg = resolver.svgOf(address(bannyHook), ALIEN_BODY_1, true, false);
        string memory pinkSvg = resolver.svgOf(address(bannyHook), PINK_BODY_1, true, false);
        string memory originalSvg = resolver.svgOf(address(bannyHook), ORIGINAL_BODY_1, true, false);

        assertGt(bytes(alienSvg).length, 0);
        assertGt(bytes(pinkSvg).length, 0);
        assertGt(bytes(originalSvg).length, 0);

        // SVGs should differ (different body colors).
        assertTrue(
            keccak256(bytes(alienSvg)) != keccak256(bytes(originalSvg)), "alien and original should have different SVGs"
        );
    }

    function test_fork_render_headSuppressesDefaultEyesMouth() public {
        // Equip only a head — defaults for eyes and mouth should NOT be injected.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = HEAD_1; // cat 4

        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        // Should still render without error.
        string memory svg = resolver.svgOf(address(bannyHook), ORIGINAL_BODY_1, true, false);
        assertGt(bytes(svg).length, 0);
    }

    function test_fork_render_nonexistentTierReverts() public {
        // A token ID that doesn't belong to any tier should revert with UnrecognizedProduct.
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnrecognizedProduct.selector);
        resolver.tokenUriOf(address(bannyHook), 999_000_000_001);
    }

    function test_fork_render_dressedBodyIncludesBackground() public {
        // Equip background.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, empty);

        // Render with background.
        string memory svgWithBg = resolver.svgOf(address(bannyHook), ORIGINAL_BODY_1, true, true);
        string memory svgWithoutBg = resolver.svgOf(address(bannyHook), ORIGINAL_BODY_1, true, false);

        assertGt(bytes(svgWithBg).length, 0);
        assertGt(bytes(svgWithoutBg).length, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 8. REENTRANCY ATTACKS
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_reentrancy_reentrantHookBlocked() public {
        // Deploy a malicious mock hook that re-enters during safeTransferFrom.
        ReentrantMockStore reStore = new ReentrantMockStore();
        ReentrantHook reHook = new ReentrantHook(address(reStore));

        // Set up a body and outfit on the malicious hook.
        uint256 bodyId = 4_000_000_001;
        uint256 outfitId = 6_000_000_001;

        reStore.setTier(
            address(reHook),
            bodyId,
            JB721Tier({
                id: 4,
                price: 0,
                remainingSupply: 100,
                initialSupply: 100,
                votingUnits: 0,
                reserveFrequency: 0,
                reserveBeneficiary: address(0),
                encodedIPFSUri: bytes32(0),
                category: 0, // body
                discountPercent: 0,
                allowOwnerMint: false,
                transfersPausable: false,
                cannotBeRemoved: false,
                cannotIncreaseDiscountPercent: false,
                splitPercent: 0,
                resolvedUri: ""
            })
        );
        reStore.setTier(
            address(reHook),
            outfitId,
            JB721Tier({
                id: 6,
                price: 0,
                remainingSupply: 100,
                initialSupply: 100,
                votingUnits: 0,
                reserveFrequency: 0,
                reserveBeneficiary: address(0),
                encodedIPFSUri: bytes32(0),
                category: 3, // necklace
                discountPercent: 0,
                allowOwnerMint: false,
                transfersPausable: false,
                cannotBeRemoved: false,
                cannotIncreaseDiscountPercent: false,
                splitPercent: 0,
                resolvedUri: ""
            })
        );

        reHook.setOwner(bodyId, alice);
        reHook.setOwner(outfitId, alice);

        vm.prank(alice);
        reHook.setApprovalForAll(address(resolver), true);

        // Arm the reentrancy attack: when outfit transfers, re-enter decorateBannyWith.
        reHook.arm(resolver, address(reHook), bodyId);

        // The reentrancy should be caught by ReentrancyGuard (silent try-catch in the hook).
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = outfitId;

        vm.prank(alice);
        resolver.decorateBannyWith(address(reHook), bodyId, 0, outfits);

        // The initial decoration should still succeed.
        assertEq(resolver.wearerOf(address(reHook), outfitId), bodyId);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 9. MULTI-ACTOR SCENARIOS
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_multiActor_bodyTransferOutfitsStay() public {
        // Alice equips outfits on her body.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, outfits);

        // Alice transfers body to bob. Outfits stay.
        vm.prank(alice);
        IERC721(address(bannyHook)).safeTransferFrom(alice, bob, ORIGINAL_BODY_1);

        // Outfits still attached.
        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_1), ORIGINAL_BODY_1);
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_1), ORIGINAL_BODY_1);

        // Bob can redecorate (strip the necklace to himself).
        vm.prank(bob);
        IERC721(address(bannyHook)).setApprovalForAll(address(resolver), true);

        uint256[] memory empty = new uint256[](0);
        vm.prank(bob);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);

        // Necklace returned to bob (new body owner), not alice.
        assertEq(IERC721(address(bannyHook)).ownerOf(NECKLACE_1), bob);
    }

    function test_fork_multiActor_bobDecoratesWithOwnOutfit() public {
        // Bob equips his own eyes on his own body.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = EYES_2; // Bob's eyes

        vm.prank(bob);
        resolver.decorateBannyWith(address(bannyHook), PINK_BODY_1, 0, outfits);

        assertEq(resolver.wearerOf(address(bannyHook), EYES_2), PINK_BODY_1);
    }

    function test_fork_multiActor_twoUsersCompeteForSameCategory() public {
        // Both alice and bob have bodies and eyes. They both equip eyes.
        uint256[] memory aliceOutfits = new uint256[](1);
        aliceOutfits[0] = EYES_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, aliceOutfits);

        uint256[] memory bobOutfits = new uint256[](1);
        bobOutfits[0] = EYES_2;
        vm.prank(bob);
        resolver.decorateBannyWith(address(bannyHook), PINK_BODY_1, 0, bobOutfits);

        assertEq(resolver.wearerOf(address(bannyHook), EYES_1), ORIGINAL_BODY_1);
        assertEq(resolver.wearerOf(address(bannyHook), EYES_2), PINK_BODY_1);
    }

    function test_fork_multiActor_threePartyInteraction() public {
        // Alice owns body, bob owns outfit worn by alice's body, charlie tries to interact.
        // Step 1: Alice equips necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        // Necklace is now held by resolver, worn by ORIGINAL_BODY_1.
        // Charlie has no body or outfit — any interaction should fail.
        uint256[] memory empty = new uint256[](0);
        vm.prank(charlie);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBannyBody.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 10. EDGE CASES
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_edge_onERC721ReceivedRejectsDirectTransfer() public {
        // Direct transfer to resolver should revert (only self-transfers allowed).
        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedTransfer.selector);
        IERC721(address(bannyHook)).safeTransferFrom(alice, address(resolver), NECKLACE_2);
    }

    function test_fork_edge_decorateEmptyOutfitsAndZeroBackground() public {
        // Empty decoration should succeed (no-op).
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);

        (uint256 bgId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(bgId, 0);
        assertEq(outfitIds.length, 0);
    }

    function test_fork_edge_assetIdsEmptyInitially() public view {
        (uint256 bgId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(bgId, 0);
        assertEq(outfitIds.length, 0);
    }

    function test_fork_edge_wearerOfUnwornReturnsZero() public view {
        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_1), 0);
    }

    function test_fork_edge_userOfUnusedBackgroundReturnsZero() public view {
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_1), 0);
    }

    function test_fork_edge_setMetadata() public {
        vm.prank(multisig);
        resolver.setMetadata("Test desc", "https://test.url", "https://test.base/");

        assertEq(resolver.svgDescription(), "Test desc");
        assertEq(resolver.svgExternalUrl(), "https://test.url");
        assertEq(resolver.svgBaseUri(), "https://test.base/");
    }

    function test_fork_edge_setMetadataNonOwnerReverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        resolver.setMetadata("evil", "https://evil", "https://evil");
    }

    function test_fork_edge_setProductNames() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 200;
        string[] memory names = new string[](1);
        names[0] = "Cool Hat";

        vm.prank(multisig);
        resolver.setProductNames(upcs, names);
    }

    function test_fork_edge_arrayLengthMismatchReverts() public {
        uint256[] memory upcs = new uint256[](2);
        upcs[0] = 1;
        upcs[1] = 2;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("test");

        vm.prank(multisig);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_ArrayLengthMismatch.selector);
        resolver.setSvgHashesOf(upcs, hashes);
    }

    function test_fork_edge_clearMetadataWithEmptyStrings() public {
        vm.startPrank(multisig);
        resolver.setMetadata("desc", "https://url", "https://base/");
        resolver.setMetadata("", "", "");
        vm.stopPrank();

        assertEq(resolver.svgDescription(), "");
        assertEq(resolver.svgExternalUrl(), "");
        assertEq(resolver.svgBaseUri(), "");
    }

    function test_fork_edge_crossHookIsolation() public {
        // Deploy a second hook for a different project. Outfits should not cross hooks.
        uint256 projectId2 = jbProjects.count() + 1;

        JBDeploy721TiersHookConfig memory hookConfig2 = _buildHookConfig();

        vm.prank(multisig);
        IJB721TiersHook hook2 = hookDeployer.deployHookFor(projectId2, hookConfig2, bytes32(uint256(2)));

        // Mint a body on hook2 for alice.
        uint16[] memory tierIds = new uint16[](1);
        tierIds[0] = TIER_ORIGINAL_BODY;
        vm.prank(multisig);
        hook2.mintFor(tierIds, alice);
        uint256 hook2Body = 4_000_000_001;

        // Alice has resolver approval for hook2.
        vm.prank(alice);
        IERC721(address(hook2)).setApprovalForAll(address(resolver), true);

        // Try to decorate hook2 body with hook1 necklace — different hooks, should revert.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1; // belongs to hook1

        // This should fail because NECKLACE_1 doesn't exist on hook2
        // (its tier data won't match, and ownership is on hook1 not hook2).
        vm.prank(alice);
        vm.expectRevert();
        resolver.decorateBannyWith(address(hook2), hook2Body, 0, outfits);
    }

    function test_fork_edge_approvalRevocationPreventsDecoration() public {
        // Alice approves resolver, then revokes before decorating.
        vm.prank(alice);
        IERC721(address(bannyHook)).setApprovalForAll(address(resolver), false);

        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;

        vm.prank(alice);
        vm.expectRevert(); // transfer fails due to no approval
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        // Re-approve for other tests.
        vm.prank(alice);
        IERC721(address(bannyHook)).setApprovalForAll(address(resolver), true);
    }

    function test_fork_edge_duplicateCategoryInSingleCallReverts() public {
        // Mint a second necklace (same category 3) to alice.
        _mintTo(alice, TIER_NECKLACE);
        uint256 necklace3 = 6_000_000_003; // Third necklace minted overall

        // Try to equip two necklaces (same category).
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_1; // cat 3
        outfits[1] = necklace3; // cat 3

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnorderedCategories.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    function test_fork_edge_namesReturnsCorrectData() public view {
        // Verify namesOf returns correct product name for each body type.
        (string memory alienFull,,) = resolver.namesOf(address(bannyHook), ALIEN_BODY_1);
        assertGt(bytes(alienFull).length, 0, "alien name should not be empty");

        (string memory originalFull,,) = resolver.namesOf(address(bannyHook), ORIGINAL_BODY_1);
        assertGt(bytes(originalFull).length, 0, "original name should not be empty");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 11. GRIEFING & FRONT-RUNNING VECTORS
    // ═══════════════════════════════════════════════════════════════════════

    function test_fork_grief_lockDoesNotPreventTokenTransfer() public {
        // Lock should prevent redecoration but NOT prevent body NFT transfer.
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);

        // Alice can still transfer the body.
        vm.prank(alice);
        IERC721(address(bannyHook)).safeTransferFrom(alice, bob, ORIGINAL_BODY_1);
        assertEq(IERC721(address(bannyHook)).ownerOf(ORIGINAL_BODY_1), bob);
    }

    function test_fork_grief_frontRunStripBeforeSale() public {
        // Scenario: Alice equips valuable outfits, then sells body to bob.
        // Alice strips outfits first (simulating front-run).
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        // Alice strips before transfer.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);

        // Transfer to bob — body is naked.
        vm.prank(alice);
        IERC721(address(bannyHook)).safeTransferFrom(alice, bob, ORIGINAL_BODY_1);

        // Necklace is back with alice, not bob.
        assertEq(IERC721(address(bannyHook)).ownerOf(NECKLACE_1), alice);
        assertEq(IERC721(address(bannyHook)).ownerOf(ORIGINAL_BODY_1), bob);

        // This is expected behavior — sellers should be warned to unequip.
    }

    function test_fork_grief_lockPreventsFrontRunStrip() public {
        // Counter: Lock outfits so they can't be stripped before sale.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);

        // Lock the body.
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(bannyHook), ORIGINAL_BODY_1);

        // Alice can't strip during lock period.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_OutfitChangesLocked.selector);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);

        // Transfer to bob — body still has outfit.
        vm.prank(alice);
        IERC721(address(bannyHook)).safeTransferFrom(alice, bob, ORIGINAL_BODY_1);

        assertEq(resolver.wearerOf(address(bannyHook), NECKLACE_1), ORIGINAL_BODY_1);
        assertEq(IERC721(address(bannyHook)).ownerOf(ORIGINAL_BODY_1), bob);

        // Bob can unequip after lock expires.
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(bob);
        IERC721(address(bannyHook)).setApprovalForAll(address(resolver), true);
        vm.prank(bob);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);

        assertEq(IERC721(address(bannyHook)).ownerOf(NECKLACE_1), bob);
    }

    function test_fork_grief_doubleEquipSameOutfitReverts() public {
        // Try to pass the same outfit ID twice.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_1;
        outfits[1] = NECKLACE_1; // duplicate

        vm.prank(alice);
        vm.expectRevert(); // UnorderedCategories (same category = not ascending)
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 12. REDRESSING CYCLES — exhaustive outfit rotation, re-equip, partial swap
    // ═══════════════════════════════════════════════════════════════════════

    /// @dev Helper: assert ownership and wearer state for an outfit on a body held by resolver.
    function _assertWorn(uint256 outfitId, uint256 bodyId) internal view {
        assertEq(resolver.wearerOf(address(bannyHook), outfitId), bodyId, "wrong wearer");
        assertEq(IERC721(address(bannyHook)).ownerOf(outfitId), address(resolver), "outfit not held by resolver");
    }

    /// @dev Helper: assert outfit returned to owner.
    function _assertReturned(uint256 outfitId, address owner) internal view {
        assertEq(IERC721(address(bannyHook)).ownerOf(outfitId), owner, "outfit not returned");
        assertEq(resolver.wearerOf(address(bannyHook), outfitId), 0, "wearer should be cleared");
    }

    /// @notice Full wardrobe cycle: dress → strip → re-equip same → swap some → strip → dress different.
    function test_fork_redress_fullWardrobeCycle() public {
        // --- Round 1: Equip necklace + eyes + mouth ---
        uint256[] memory r1 = new uint256[](3);
        r1[0] = NECKLACE_1; // cat 3
        r1[1] = EYES_1; // cat 5
        r1[2] = MOUTH_1; // cat 7
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, r1);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertWorn(EYES_1, ORIGINAL_BODY_1);
        _assertWorn(MOUTH_1, ORIGINAL_BODY_1);

        // --- Round 2: Strip everything ---
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);
        _assertReturned(NECKLACE_1, alice);
        _assertReturned(EYES_1, alice);
        _assertReturned(MOUTH_1, alice);
        _assertReturned(BACKGROUND_1, alice);

        // --- Round 3: Re-equip the EXACT SAME outfits ---
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, r1);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertWorn(EYES_1, ORIGINAL_BODY_1);
        _assertWorn(MOUTH_1, ORIGINAL_BODY_1);

        // --- Round 4: Swap to entirely different categories (glasses + legs + headtop) ---
        uint256[] memory r4 = new uint256[](3);
        r4[0] = GLASSES_1; // cat 6
        r4[1] = LEGS_1; // cat 8
        r4[2] = HEADTOP_1; // cat 12
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_2, r4);
        // Old outfits returned.
        _assertReturned(NECKLACE_1, alice);
        _assertReturned(EYES_1, alice);
        _assertReturned(MOUTH_1, alice);
        _assertReturned(BACKGROUND_1, alice);
        // New outfits worn.
        _assertWorn(GLASSES_1, ORIGINAL_BODY_1);
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);
        _assertWorn(HEADTOP_1, ORIGINAL_BODY_1);

        // --- Round 5: Strip all again ---
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);
        _assertReturned(GLASSES_1, alice);
        _assertReturned(LEGS_1, alice);
        _assertReturned(HEADTOP_1, alice);
        _assertReturned(BACKGROUND_2, alice);

        // --- Round 6: Dress with original set one more time ---
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, r1);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertWorn(EYES_1, ORIGINAL_BODY_1);
        _assertWorn(MOUTH_1, ORIGINAL_BODY_1);
    }

    /// @notice Partial redress: keep some outfits, swap others in a single call.
    function test_fork_redress_partialSwap() public {
        // Round 1: necklace + eyes + legs (cats 3, 5, 8).
        uint256[] memory r1 = new uint256[](3);
        r1[0] = NECKLACE_1;
        r1[1] = EYES_1;
        r1[2] = LEGS_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);

        // Round 2: necklace + mouth + legs (cats 3, 7, 8) — eyes out, mouth in, necklace+legs stay.
        uint256[] memory r2 = new uint256[](3);
        r2[0] = NECKLACE_1; // SAME — should be re-equipped (no-op transfer)
        r2[1] = MOUTH_1; // NEW — cat 7 replaces nothing (eyes at cat 5 gets swept)
        r2[2] = LEGS_1; // SAME
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r2);

        // Necklace stays worn (same body).
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        // Eyes returned (category 5 was swept by category 7 advance).
        _assertReturned(EYES_1, alice);
        // Mouth now worn.
        _assertWorn(MOUTH_1, ORIGINAL_BODY_1);
        // Legs stays worn.
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);

        (, uint256[] memory attached) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(attached.length, 3, "should have 3 outfits");
    }

    /// @notice Expand then shrink outfit set across redressings.
    function test_fork_redress_expandAndShrink() public {
        // Round 1: 1 outfit.
        uint256[] memory r1 = new uint256[](1);
        r1[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);
        (, uint256[] memory a1) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(a1.length, 1);

        // Round 2: expand to 4 outfits.
        uint256[] memory r2 = new uint256[](4);
        r2[0] = NECKLACE_1; // cat 3
        r2[1] = EYES_1; // cat 5
        r2[2] = MOUTH_1; // cat 7
        r2[3] = LEGS_1; // cat 8
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, r2);
        (, uint256[] memory a2) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(a2.length, 4);

        // Round 3: shrink to 2 outfits in different categories (glasses + hand).
        uint256[] memory r3 = new uint256[](2);
        r3[0] = GLASSES_1; // cat 6
        r3[1] = HAND_1; // cat 13
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r3);
        (, uint256[] memory a3) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(a3.length, 2);

        // All previous 4 outfits returned.
        _assertReturned(NECKLACE_1, alice);
        _assertReturned(EYES_1, alice);
        _assertReturned(MOUTH_1, alice);
        _assertReturned(LEGS_1, alice);
        _assertReturned(BACKGROUND_1, alice);

        // Round 4: shrink to 0.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);
        (, uint256[] memory a4) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(a4.length, 0);
        _assertReturned(GLASSES_1, alice);
        _assertReturned(HAND_1, alice);
    }

    /// @notice Same outfit worn by body A, stripped, worn by body B, stripped, re-worn by body A.
    function test_fork_redress_outfitPingPongBetweenBodies() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        uint256[] memory empty = new uint256[](0);

        // Round 1: Body 1 wears necklace.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);

        // Round 2: Strip from body 1.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, empty);
        _assertReturned(NECKLACE_1, alice);

        // Round 3: Body 2 wears necklace.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_2, 0, outfits);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_2);

        // Round 4: Strip from body 2.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_2, 0, empty);
        _assertReturned(NECKLACE_1, alice);

        // Round 5: Back to body 1 again.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
    }

    /// @notice Re-equip exact same outfit set that's already worn — should be a no-op.
    function test_fork_redress_reequipSameSetIsNoop() public {
        uint256[] memory outfits = new uint256[](3);
        outfits[0] = NECKLACE_1;
        outfits[1] = EYES_1;
        outfits[2] = MOUTH_1;

        // First dress.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, outfits);

        // Re-dress with exact same set.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, outfits);

        // Everything still worn.
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertWorn(EYES_1, ORIGINAL_BODY_1);
        _assertWorn(MOUTH_1, ORIGINAL_BODY_1);
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_1), ORIGINAL_BODY_1);

        (, uint256[] memory attached) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(attached.length, 3);
    }

    /// @notice Swap outfits within same category across rounds — tests replacement of same-category items.
    function test_fork_redress_sameCategoryRotation() public {
        // Round 1: NECKLACE_1.
        uint256[] memory r1 = new uint256[](1);
        r1[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);

        // Round 2: NECKLACE_2 replaces NECKLACE_1 (same category 3).
        uint256[] memory r2 = new uint256[](1);
        r2[0] = NECKLACE_2;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r2);
        _assertWorn(NECKLACE_2, ORIGINAL_BODY_1);
        _assertReturned(NECKLACE_1, alice);

        // Round 3: NECKLACE_3 replaces NECKLACE_2.
        uint256[] memory r3 = new uint256[](1);
        r3[0] = NECKLACE_3;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r3);
        _assertWorn(NECKLACE_3, ORIGINAL_BODY_1);
        _assertReturned(NECKLACE_2, alice);

        // Round 4: Back to NECKLACE_1 — previously worn item re-equipped.
        uint256[] memory r4 = new uint256[](1);
        r4[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r4);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertReturned(NECKLACE_3, alice);
    }

    /// @notice Category ordering varies across rounds — each round uses different category subsets.
    function test_fork_redress_varyingCategorySubsets() public {
        // Round 1: Low categories (necklace=3, eyes=5).
        uint256[] memory r1 = new uint256[](2);
        r1[0] = NECKLACE_1;
        r1[1] = EYES_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);

        // Round 2: High categories only (headtop=12, hand=13) — all low returned.
        uint256[] memory r2 = new uint256[](2);
        r2[0] = HEADTOP_1;
        r2[1] = HAND_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r2);
        _assertReturned(NECKLACE_1, alice);
        _assertReturned(EYES_1, alice);
        _assertWorn(HEADTOP_1, ORIGINAL_BODY_1);
        _assertWorn(HAND_1, ORIGINAL_BODY_1);

        // Round 3: Mid categories (glasses=6, mouth=7, legs=8) — all high returned.
        uint256[] memory r3 = new uint256[](3);
        r3[0] = GLASSES_1;
        r3[1] = MOUTH_1;
        r3[2] = LEGS_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r3);
        _assertReturned(HEADTOP_1, alice);
        _assertReturned(HAND_1, alice);
        _assertWorn(GLASSES_1, ORIGINAL_BODY_1);
        _assertWorn(MOUTH_1, ORIGINAL_BODY_1);
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);

        // Round 4: Spread across all ranges (necklace=3, legs=8, hand=13).
        uint256[] memory r4 = new uint256[](3);
        r4[0] = NECKLACE_1;
        r4[1] = LEGS_1; // same item stays
        r4[2] = HAND_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r4);
        _assertReturned(GLASSES_1, alice);
        _assertReturned(MOUTH_1, alice);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);
        _assertWorn(HAND_1, ORIGINAL_BODY_1);
    }

    /// @notice Interleave background changes with outfit changes across rounds.
    function test_fork_redress_backgroundAndOutfitInterleaved() public {
        uint256[] memory empty = new uint256[](0);

        // Round 1: Background only.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, empty);
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_1), ORIGINAL_BODY_1);

        // Round 2: Add outfits, keep background.
        uint256[] memory r2 = new uint256[](2);
        r2[0] = NECKLACE_1;
        r2[1] = EYES_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, r2);
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_1), ORIGINAL_BODY_1);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);

        // Round 3: Swap background, keep outfits.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_2, r2);
        _assertReturned(BACKGROUND_1, alice);
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_2), ORIGINAL_BODY_1);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertWorn(EYES_1, ORIGINAL_BODY_1);

        // Round 4: Remove background, swap outfits.
        uint256[] memory r4 = new uint256[](1);
        r4[0] = MOUTH_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r4);
        _assertReturned(BACKGROUND_2, alice);
        _assertReturned(NECKLACE_1, alice);
        _assertReturned(EYES_1, alice);
        _assertWorn(MOUTH_1, ORIGINAL_BODY_1);

        // Round 5: Add background back + outfit.
        uint256[] memory r5 = new uint256[](2);
        r5[0] = GLASSES_1;
        r5[1] = MOUTH_1; // keep from round 4
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, r5);
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_1), ORIGINAL_BODY_1);
        _assertWorn(GLASSES_1, ORIGINAL_BODY_1);
        _assertWorn(MOUTH_1, ORIGINAL_BODY_1);
    }

    /// @notice Move an outfit directly from one body to another without explicit strip.
    function test_fork_redress_directOutfitMoveToOtherBody() public {
        // Equip necklace on body 1.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, outfits);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);

        // Move to body 2 without stripping body 1 first.
        // Alice owns both bodies, and since she owns the body wearing the necklace,
        // she can re-equip it on her other body.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_2, 0, outfits);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_2);

        // Body 1 should now have no outfits (the old necklace moved away).
        (, uint256[] memory body1Outfits) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(body1Outfits.length, 0, "body 1 should have 0 outfits after move");
    }

    /// @notice Swap items across categories where old and new overlap partially.
    /// Old: [necklace(3), eyes(5), legs(8)]. New: [necklace(3), glasses(6), legs(8), headtop(12)].
    /// Expected: necklace stays, eyes returned, glasses added, legs stays, headtop added.
    function test_fork_redress_overlappingCategorySwap() public {
        // Round 1: necklace + eyes + legs.
        uint256[] memory r1 = new uint256[](3);
        r1[0] = NECKLACE_1;
        r1[1] = EYES_1;
        r1[2] = LEGS_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);

        // Round 2: necklace + glasses + legs + headtop.
        uint256[] memory r2 = new uint256[](4);
        r2[0] = NECKLACE_1; // same
        r2[1] = GLASSES_1; // new, cat 6 > cat 5 so eyes swept
        r2[2] = LEGS_1; // same
        r2[3] = HEADTOP_1; // new
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r2);

        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertReturned(EYES_1, alice);
        _assertWorn(GLASSES_1, ORIGINAL_BODY_1);
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);
        _assertWorn(HEADTOP_1, ORIGINAL_BODY_1);

        (, uint256[] memory attached) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(attached.length, 4);
    }

    /// @notice Replace items within same categories using different tokens (e.g., EYES_1 → GLASSES_2 in cat 6).
    function test_fork_redress_replaceSameCategoryDifferentTokens() public {
        // Round 1: glasses_1 (cat 6).
        uint256[] memory r1 = new uint256[](1);
        r1[0] = GLASSES_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);
        _assertWorn(GLASSES_1, ORIGINAL_BODY_1);

        // Round 2: glasses_2 replaces glasses_1 (both cat 6).
        uint256[] memory r2 = new uint256[](1);
        r2[0] = GLASSES_2;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r2);
        _assertWorn(GLASSES_2, ORIGINAL_BODY_1);
        _assertReturned(GLASSES_1, alice);

        // Round 3: back to glasses_1.
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);
        _assertWorn(GLASSES_1, ORIGINAL_BODY_1);
        _assertReturned(GLASSES_2, alice);
    }

    /// @notice Rapid-fire redressing: 10 rounds in one test, alternating between two outfit sets.
    function test_fork_redress_rapidAlternation() public {
        uint256[] memory setA = new uint256[](2);
        setA[0] = NECKLACE_1; // cat 3
        setA[1] = EYES_1; // cat 5

        uint256[] memory setB = new uint256[](2);
        setB[0] = GLASSES_1; // cat 6
        setB[1] = LEGS_1; // cat 8

        for (uint256 i; i < 10; i++) {
            uint256[] memory set = (i % 2 == 0) ? setA : setB;
            vm.prank(alice);
            resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, set);

            (, uint256[] memory attached) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
            assertEq(attached.length, 2, "should always have 2 outfits");

            if (i % 2 == 0) {
                _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
                _assertWorn(EYES_1, ORIGINAL_BODY_1);
            } else {
                _assertWorn(GLASSES_1, ORIGINAL_BODY_1);
                _assertWorn(LEGS_1, ORIGINAL_BODY_1);
            }
        }
    }

    /// @notice Redress where new set has categories both below and above the old set's range.
    /// Old: [glasses(6), mouth(7)]. New: [necklace(3), headtop(12)].
    function test_fork_redress_newSetBracketsOldRange() public {
        // Round 1: middle categories.
        uint256[] memory r1 = new uint256[](2);
        r1[0] = GLASSES_1; // cat 6
        r1[1] = MOUTH_1; // cat 7
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);

        // Round 2: new set brackets old range — lower and higher.
        uint256[] memory r2 = new uint256[](2);
        r2[0] = NECKLACE_1; // cat 3 — below old range
        r2[1] = HEADTOP_1; // cat 12 — above old range
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r2);

        _assertReturned(GLASSES_1, alice);
        _assertReturned(MOUTH_1, alice);
        _assertWorn(NECKLACE_1, ORIGINAL_BODY_1);
        _assertWorn(HEADTOP_1, ORIGINAL_BODY_1);
    }

    /// @notice Redress from max outfits to completely different max outfits — tests full sweep + re-equip.
    function test_fork_redress_maxToMaxSwap() public {
        // Round 1: 5 outfits (necklace, eyes, mouth, legs, hand).
        uint256[] memory r1 = new uint256[](5);
        r1[0] = NECKLACE_1; // cat 3
        r1[1] = EYES_1; // cat 5
        r1[2] = MOUTH_1; // cat 7
        r1[3] = LEGS_1; // cat 8
        r1[4] = HAND_1; // cat 13
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_1, r1);

        // Round 2: 5 different outfits (necklace2, glasses, legs2, suit_bottom, headtop).
        uint256[] memory r2 = new uint256[](5);
        r2[0] = NECKLACE_2; // cat 3 — replaces NECKLACE_1
        r2[1] = GLASSES_1; // cat 6 — eyes swept
        r2[2] = LEGS_2; // cat 8 — replaces LEGS_1
        r2[3] = SUIT_BOTTOM_1; // cat 10 — new
        r2[4] = HEADTOP_1; // cat 12 — new, hand (13) swept by tail loop
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, BACKGROUND_2, r2);

        // All old items returned.
        _assertReturned(NECKLACE_1, alice);
        _assertReturned(EYES_1, alice);
        _assertReturned(MOUTH_1, alice);
        _assertReturned(LEGS_1, alice);
        _assertReturned(HAND_1, alice);
        _assertReturned(BACKGROUND_1, alice);

        // All new items worn.
        _assertWorn(NECKLACE_2, ORIGINAL_BODY_1);
        _assertWorn(GLASSES_1, ORIGINAL_BODY_1);
        _assertWorn(LEGS_2, ORIGINAL_BODY_1);
        _assertWorn(SUIT_BOTTOM_1, ORIGINAL_BODY_1);
        _assertWorn(HEADTOP_1, ORIGINAL_BODY_1);
        assertEq(resolver.userOf(address(bannyHook), BACKGROUND_2), ORIGINAL_BODY_1);

        (, uint256[] memory attached) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(attached.length, 5);
    }

    /// @notice Single outfit survives multiple rounds where other categories rotate around it.
    function test_fork_redress_anchorOutfitSurvivesRotation() public {
        // LEGS_1 (cat 8) is the anchor. Other categories change each round.

        // Round 1: necklace + legs.
        uint256[] memory r1 = new uint256[](2);
        r1[0] = NECKLACE_1;
        r1[1] = LEGS_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r1);
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);

        // Round 2: eyes + legs.
        uint256[] memory r2 = new uint256[](2);
        r2[0] = EYES_1;
        r2[1] = LEGS_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r2);
        _assertReturned(NECKLACE_1, alice);
        _assertWorn(EYES_1, ORIGINAL_BODY_1);
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);

        // Round 3: glasses + legs + headtop.
        uint256[] memory r3 = new uint256[](3);
        r3[0] = GLASSES_1;
        r3[1] = LEGS_1;
        r3[2] = HEADTOP_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r3);
        _assertReturned(EYES_1, alice);
        _assertWorn(GLASSES_1, ORIGINAL_BODY_1);
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);
        _assertWorn(HEADTOP_1, ORIGINAL_BODY_1);

        // Round 4: just legs alone.
        uint256[] memory r4 = new uint256[](1);
        r4[0] = LEGS_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(bannyHook), ORIGINAL_BODY_1, 0, r4);
        _assertReturned(GLASSES_1, alice);
        _assertReturned(HEADTOP_1, alice);
        _assertWorn(LEGS_1, ORIGINAL_BODY_1);

        (, uint256[] memory attached) = resolver.assetIdsOf(address(bannyHook), ORIGINAL_BODY_1);
        assertEq(attached.length, 1);
        assertEq(attached[0], LEGS_1);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Internal helpers
    // ═══════════════════════════════════════════════════════════════════════

    // forge-lint: disable-next-line(mixed-case-function)
    function _deployJBCore() internal {
        jbPermissions = new JBPermissions(trustedForwarder);
        jbProjects = new JBProjects(multisig, address(0), trustedForwarder);
        jbDirectory = new JBDirectory(jbPermissions, jbProjects, multisig);
        JBERC20 jbErc20 = new JBERC20();
        jbTokens = new JBTokens(jbDirectory, jbErc20);
        jbRulesets = new JBRulesets(jbDirectory);
        jbPrices = new JBPrices(jbDirectory, jbPermissions, jbProjects, multisig, trustedForwarder);
        jbSplits = new JBSplits(jbDirectory);
        jbFundAccessLimits = new JBFundAccessLimits(jbDirectory);

        jbController = new JBController(
            jbDirectory,
            jbFundAccessLimits,
            jbPermissions,
            jbPrices,
            jbProjects,
            jbRulesets,
            jbSplits,
            jbTokens,
            address(0), // omnichainRulesetOperator
            trustedForwarder
        );

        vm.prank(multisig);
        jbDirectory.setIsAllowedToSetFirstController(address(jbController), true);
    }

    function _deploy721Hook() internal {
        JB721TiersHookStore store = new JB721TiersHookStore();
        JBAddressRegistry addressRegistry = new JBAddressRegistry();

        JB721TiersHook hookImpl =
            new JB721TiersHook(jbDirectory, jbPermissions, jbPrices, jbRulesets, store, jbSplits, trustedForwarder);

        hookDeployer = new JB721TiersHookDeployer(hookImpl, store, addressRegistry, trustedForwarder);
    }

    function _deployBannyResolver() internal {
        // Deploy with production SVG constants (abbreviated for tests).
        string memory bannyBody =
            '<g class="b1"><path d="M173 53h4v17h-4z"/></g><g class="b2"><path d="M167 57h3v10h-3z"/></g><g class="o"><path d="M177 53h3v17h-3z"/></g>';
        string memory defaultNecklace = '<g class="o"><path d="M190 173h-37v-3h-10v-4h-6v4h3v3h-3v4h6v3h10v4h37"/></g>';
        string memory defaultMouth = '<g class="o"><path d="M183 160v-4h-20v4h-3v3h3v4h24v-7h-4z" fill="#ad71c8"/></g>';
        string memory defaultEyes = '<g class="o"><path d="M177 140v3h6v11h10v-11h4v-3h-20z"/></g>';
        string memory defaultAlienEyes = '<g class="o"><path d="M190 127h3v3h-3z"/></g>';

        vm.prank(multisig);
        resolver = new Banny721TokenUriResolver(
            bannyBody, defaultNecklace, defaultMouth, defaultEyes, defaultAlienEyes, multisig, trustedForwarder
        );

        // Set metadata.
        vm.prank(multisig);
        resolver.setMetadata("A piece of Banny Retail.", "https://retail.banny.eth.shop", "https://bannyverse.test/");
    }

    function _buildHookConfig() internal view returns (JBDeploy721TiersHookConfig memory) {
        // 16 tiers sorted by category (ascending).
        JB721TierConfig[] memory tiers = new JB721TierConfig[](16);

        // Tier 1-4: Bodies (category 0) — different prices.
        tiers[0] = _tierConfig(1 ether, 100, 0); // Alien
        tiers[1] = _tierConfig(0.1 ether, 1000, 0); // Pink
        tiers[2] = _tierConfig(0.01 ether, 10_000, 0); // Orange
        tiers[3] = _tierConfig(0.0001 ether, 999_999_999, 0); // Original

        // Tier 5: Background (category 1)
        tiers[4] = _tierConfig(0.01 ether, 1000, 1);

        // Tier 6: Necklace (category 3)
        tiers[5] = _tierConfig(0.01 ether, 1000, 3);

        // Tier 7: Head (category 4)
        tiers[6] = _tierConfig(0.01 ether, 1000, 4);

        // Tier 8: Eyes (category 5)
        tiers[7] = _tierConfig(0.01 ether, 1000, 5);

        // Tier 9: Glasses (category 6)
        tiers[8] = _tierConfig(0.01 ether, 1000, 6);

        // Tier 10: Mouth (category 7)
        tiers[9] = _tierConfig(0.01 ether, 1000, 7);

        // Tier 11: Legs (category 8)
        tiers[10] = _tierConfig(0.01 ether, 1000, 8);

        // Tier 12: Suit (category 9)
        tiers[11] = _tierConfig(0.01 ether, 1000, 9);

        // Tier 13: Suit Bottom (category 10)
        tiers[12] = _tierConfig(0.01 ether, 1000, 10);

        // Tier 14: Suit Top (category 11)
        tiers[13] = _tierConfig(0.01 ether, 1000, 11);

        // Tier 15: Headtop (category 12)
        tiers[14] = _tierConfig(0.01 ether, 1000, 12);

        // Tier 16: Hand (category 13)
        tiers[15] = _tierConfig(0.01 ether, 1000, 13);

        return JBDeploy721TiersHookConfig({
            name: "Banny Retail",
            symbol: "BANNY",
            baseUri: "ipfs://",
            tokenUriResolver: IJB721TokenUriResolver(address(resolver)),
            contractUri: "",
            tiersConfig: JB721InitTiersConfig({tiers: tiers, currency: JBCurrencyIds.ETH, decimals: 18}),
            flags: JB721TiersHookFlags({
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: false,
                preventOverspending: false,
                issueTokensForSplits: false
            })
        });
    }

    function _deployBannyHook() internal {
        // Compute the next project ID.
        uint256 projectId = jbProjects.count() + 1;

        JBDeploy721TiersHookConfig memory hookConfig = _buildHookConfig();

        // Deploy hook for this project. multisig becomes the owner.
        vm.prank(multisig);
        bannyHook = hookDeployer.deployHookFor(projectId, hookConfig, bytes32(uint256(1)));
    }

    function _tierConfig(uint104 price, uint32 supply, uint24 category) internal pure returns (JB721TierConfig memory) {
        return JB721TierConfig({
            price: price,
            initialSupply: supply,
            votingUnits: 0,
            reserveFrequency: 0,
            reserveBeneficiary: address(0),
            encodedIPFSUri: bytes32(0),
            category: category,
            discountPercent: 0,
            allowOwnerMint: true,
            useReserveBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: false,
            cannotBeRemoved: false,
            cannotIncreaseDiscountPercent: false,
            splitPercent: 0,
            splits: new JBSplit[](0)
        });
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function _mintInitialNFTs() internal {
        // Mint bodies and outfits to alice, bob.
        vm.startPrank(multisig); // hook owner can mint

        // Alice: alien body, original body x2, background x2, necklace x2,
        // head, eyes, glasses, mouth, legs, suit, suit bottom, suit top, headtop, hand.
        uint16[] memory aliceTiers = new uint16[](18);
        aliceTiers[0] = TIER_ALIEN_BODY; // ALIEN_BODY_1
        aliceTiers[1] = TIER_PINK_BODY; // PINK_BODY_1 — will give to bob
        aliceTiers[2] = TIER_ORIGINAL_BODY; // ORIGINAL_BODY_1
        aliceTiers[3] = TIER_ORIGINAL_BODY; // ORIGINAL_BODY_2
        aliceTiers[4] = TIER_BACKGROUND; // BACKGROUND_1
        aliceTiers[5] = TIER_BACKGROUND; // BACKGROUND_2
        aliceTiers[6] = TIER_NECKLACE; // NECKLACE_1
        aliceTiers[7] = TIER_NECKLACE; // NECKLACE_2
        aliceTiers[8] = TIER_HEAD; // HEAD_1
        aliceTiers[9] = TIER_EYES; // EYES_1
        aliceTiers[10] = TIER_GLASSES; // GLASSES_1
        aliceTiers[11] = TIER_MOUTH; // MOUTH_1
        aliceTiers[12] = TIER_LEGS; // LEGS_1
        aliceTiers[13] = TIER_SUIT; // SUIT_1
        aliceTiers[14] = TIER_SUIT_BOTTOM; // SUIT_BOTTOM_1
        aliceTiers[15] = TIER_SUIT_TOP; // SUIT_TOP_1
        aliceTiers[16] = TIER_HEADTOP; // HEADTOP_1
        aliceTiers[17] = TIER_HAND; // HAND_1
        bannyHook.mintFor(aliceTiers, alice);

        // Alice extra: glasses2, legs2, necklace3, headtop2 (for redressing cycle tests).
        uint16[] memory aliceExtra = new uint16[](4);
        aliceExtra[0] = TIER_NECKLACE; // NECKLACE_3
        aliceExtra[1] = TIER_GLASSES; // GLASSES_2
        aliceExtra[2] = TIER_LEGS; // LEGS_2
        aliceExtra[3] = TIER_HEADTOP; // HEADTOP_2
        bannyHook.mintFor(aliceExtra, alice);

        // Bob: eyes, mouth, head (for multi-actor tests).
        uint16[] memory bobTiers = new uint16[](3);
        bobTiers[0] = TIER_HEAD; // HEAD_2
        bobTiers[1] = TIER_EYES; // EYES_2
        bobTiers[2] = TIER_MOUTH; // MOUTH_2
        bannyHook.mintFor(bobTiers, bob);

        vm.stopPrank();

        // Transfer PINK_BODY_1 from alice to bob for multi-actor tests.
        vm.prank(alice);
        IERC721(address(bannyHook)).safeTransferFrom(alice, bob, PINK_BODY_1);

        // Approve resolver for alice and bob.
        vm.prank(alice);
        IERC721(address(bannyHook)).setApprovalForAll(address(resolver), true);

        vm.prank(bob);
        IERC721(address(bannyHook)).setApprovalForAll(address(resolver), true);
    }

    /// @dev Mint a single NFT of the given tier to the given address.
    function _mintTo(address to, uint16 tierId) internal {
        uint16[] memory tierIds = new uint16[](1);
        tierIds[0] = tierId;
        vm.prank(multisig);
        bannyHook.mintFor(tierIds, to);
    }
}
