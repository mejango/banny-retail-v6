// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";

/// @notice Minimal mock hook for attack testing.
contract AttackMockHook {
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

/// @notice Minimal mock store for attack testing.
contract AttackMockStore {
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

/// @title BannyAttacks
/// @notice Adversarial security tests for Banny721TokenUriResolver decoration system.
contract BannyAttacks is Test {
    Banny721TokenUriResolver resolver;
    AttackMockHook hook;
    AttackMockStore store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address attacker = makeAddr("attacker");

    // Token IDs: product ID * 1_000_000_000 + sequence.
    // Categories: 0=Body, 1=Background, 3=Necklace, 4=Head, 5=Eyes, 7=Mouth,
    //             9=Suit, 10=SuitBottom, 11=SuitTop
    uint256 constant BODY_A = 4_000_000_001;
    uint256 constant BODY_B = 4_000_000_002;
    uint256 constant BACKGROUND = 5_000_000_001;
    uint256 constant NECKLACE = 10_000_000_001;
    uint256 constant HEAD = 20_000_000_001;
    uint256 constant EYES = 30_000_000_001;
    uint256 constant MOUTH = 40_000_000_001;
    uint256 constant SUIT = 50_000_000_001;
    uint256 constant SUIT_BOTTOM = 51_000_000_001;
    uint256 constant SUIT_TOP = 52_000_000_001;

    function setUp() public {
        store = new AttackMockStore();
        hook = new AttackMockHook(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        // Set up tier data.
        _setupTier(BODY_A, 4, 0);
        _setupTier(BODY_B, 4, 0);
        _setupTier(BACKGROUND, 5, 1);
        _setupTier(NECKLACE, 10, 3);
        _setupTier(HEAD, 20, 4);
        _setupTier(EYES, 30, 5);
        _setupTier(MOUTH, 40, 7);
        _setupTier(SUIT, 50, 9);
        _setupTier(SUIT_BOTTOM, 51, 10);
        _setupTier(SUIT_TOP, 52, 11);

        // Give alice all tokens.
        hook.setOwner(BODY_A, alice);
        hook.setOwner(BODY_B, alice);
        hook.setOwner(BACKGROUND, alice);
        hook.setOwner(NECKLACE, alice);
        hook.setOwner(HEAD, alice);
        hook.setOwner(EYES, alice);
        hook.setOwner(MOUTH, alice);
        hook.setOwner(SUIT, alice);
        hook.setOwner(SUIT_BOTTOM, alice);
        hook.setOwner(SUIT_TOP, alice);

        // Approve resolver.
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

    // =========================================================================
    // Test 1: Outfit reuse across body replacement
    // =========================================================================
    /// @notice Decorate body A with necklace, then try to decorate body B with
    ///         the same necklace. The necklace should be transferred back from body A
    ///         to the resolver, then attached to body B.
    function test_outfitReuse_acrossBodies() public {
        // Decorate body A with necklace.
        uint256[] memory outfitsA = new uint256[](1);
        outfitsA[0] = NECKLACE;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfitsA);

        assertEq(resolver.wearerOf(address(hook), NECKLACE), BODY_A, "Necklace on body A");

        // Now decorate body B with the same necklace.
        // Alice owns both bodies, so this should work — necklace should be removed
        // from body A and attached to body B.
        uint256[] memory outfitsB = new uint256[](1);
        outfitsB[0] = NECKLACE;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_B, 0, outfitsB);

        assertEq(resolver.wearerOf(address(hook), NECKLACE), BODY_B, "Necklace should now be on body B");
    }

    // =========================================================================
    // Test 2: Lock bypass — try decorating before lock expires
    // =========================================================================
    /// @notice Lock a banny body, then try to change outfits before the lock expires.
    function test_lockBypass_beforeExpiry_reverts() public {
        // Decorate body A with necklace first.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Lock the outfit changes.
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY_A);

        // Try to change decoration immediately — should revert.
        uint256[] memory newOutfits = new uint256[](1);
        newOutfits[0] = MOUTH;

        vm.prank(alice);
        vm.expectRevert();
        resolver.decorateBannyWith(address(hook), BODY_A, 0, newOutfits);

        // Fast-forward past lock period (7 days).
        vm.warp(block.timestamp + 7 days + 1);

        // Should succeed now.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, newOutfits);

        assertEq(resolver.wearerOf(address(hook), MOUTH), BODY_A, "Mouth should be on body A after lock");
    }

    // =========================================================================
    // Test 3: Category conflict — head + eyes simultaneously
    // =========================================================================
    /// @notice Head (category 4) should conflict with Eyes (category 5).
    function test_categoryConflict_headAndEyes_reverts() public {
        // Try to equip both head and eyes at once.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = HEAD; // category 4
        outfits[1] = EYES; // category 5

        vm.prank(alice);
        vm.expectRevert();
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    // =========================================================================
    // Test 4: Category conflict — suit + suit bottom
    // =========================================================================
    /// @notice Suit (category 9) should conflict with Suit Bottom (category 10).
    function test_categoryConflict_suitAndParts_reverts() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = SUIT; // category 9
        outfits[1] = SUIT_BOTTOM; // category 10

        vm.prank(alice);
        vm.expectRevert();
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    // =========================================================================
    // Test 5: Unauthorized decoration — non-owner tries to decorate
    // =========================================================================
    /// @notice Attacker (not the body owner) tries to decorate alice's banny.
    function test_unauthorizedDecoration_reverts() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE;

        // Give attacker a body but not the necklace owner.
        hook.setOwner(BODY_A, attacker);

        vm.prank(attacker);
        vm.expectRevert();
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    // =========================================================================
    // Test 6: Out-of-order categories — must be ascending
    // =========================================================================
    /// @notice Outfit categories must be in ascending order. Passing mouth before necklace
    ///         should revert.
    function test_outOfOrderCategories_reverts() public {
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = MOUTH; // category 7
        outfits[1] = NECKLACE; // category 3 — out of order!

        vm.prank(alice);
        vm.expectRevert();
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    // =========================================================================
    // Test 7: Body as outfit — should revert
    // =========================================================================
    /// @notice Category 0 (Body) should not be usable as an outfit.
    function test_bodyAsOutfit_reverts() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = BODY_B; // category 0

        vm.prank(alice);
        vm.expectRevert();
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }

    // =========================================================================
    // Test 8: Background as outfit — should revert
    // =========================================================================
    /// @notice Category 1 (Background) should not be passed as outfit. It has
    ///         its own dedicated parameter in decorateBannyWith.
    function test_backgroundAsOutfit_reverts() public {
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = BACKGROUND; // category 1

        vm.prank(alice);
        vm.expectRevert();
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);
    }
}
