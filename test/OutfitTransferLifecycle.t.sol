// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {JB721TierFlags} from "@bananapus/721-hook-v6/src/structs/JB721TierFlags.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";

/// @notice Mock hook with transfer tracking for outfit-on-transfer lifecycle tests.
contract TransferMockHook {
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

/// @notice Mock store for outfit transfer lifecycle tests.
contract TransferMockStore {
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

/// @title OutfitTransferLifecycleTest
/// @notice Tests verifying that when a Banny body NFT is "transferred" (ownership changes),
///         equipped outfits remain associated with the body. The new body owner gains control
///         over the equipped items -- they can unequip them, or re-equip different ones.
///
///         IMPORTANT: Outfits do NOT automatically follow the body during an ERC721 transfer --
///         instead, they are held by the resolver contract. The "travel" is conceptual: the
///         outfit association (wearerOf, assetIdsOf) remains tied to the body ID, so whoever
///         owns the body controls the outfits.
contract OutfitTransferLifecycleTest is Test {
    Banny721TokenUriResolver resolver;
    TransferMockHook hook;
    TransferMockStore store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    // Token IDs: tierId * 1_000_000_000 + sequence.
    // Categories: 0=Body, 1=Background, 2=Backside, 3=Necklace, 4=Head, 5=Eyes
    uint256 constant BODY_A = 4_000_000_001;
    uint256 constant BODY_B = 4_000_000_002;
    uint256 constant BACKGROUND_1 = 5_000_000_001;
    uint256 constant NECKLACE_1 = 10_000_000_001;
    uint256 constant EYES_1 = 30_000_000_001;
    uint256 constant MOUTH_1 = 40_000_000_001;

    function setUp() public {
        store = new TransferMockStore();
        hook = new TransferMockHook(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        // Set up tier data.
        _setupTier(BODY_A, 4, 0);
        _setupTier(BODY_B, 4, 0);
        _setupTier(BACKGROUND_1, 5, 1);
        _setupTier(NECKLACE_1, 10, 3);
        _setupTier(EYES_1, 30, 5);
        _setupTier(MOUTH_1, 40, 7);

        // Alice owns everything initially.
        hook.setOwner(BODY_A, alice);
        hook.setOwner(BODY_B, alice);
        hook.setOwner(BACKGROUND_1, alice);
        hook.setOwner(NECKLACE_1, alice);
        hook.setOwner(EYES_1, alice);
        hook.setOwner(MOUTH_1, alice);

        // Approve resolver for all.
        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
        vm.prank(bob);
        hook.setApprovalForAll(address(resolver), true);
        vm.prank(charlie);
        hook.setApprovalForAll(address(resolver), true);
    }

    // =========================================================================
    // TEST 1: Outfits persist on body after ownership transfer.
    //         The new owner can query assetIdsOf and see the same outfits.
    // =========================================================================
    function test_outfitsPersistAfterBodyTransfer() public {
        // Alice dresses body A with necklace, eyes, mouth, and background.
        uint256[] memory outfits = new uint256[](3);
        outfits[0] = NECKLACE_1; // cat 3
        outfits[1] = EYES_1; // cat 5
        outfits[2] = MOUTH_1; // cat 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, outfits);

        // Verify: all assets are equipped.
        (uint256 bgId, uint256[] memory equipped) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, BACKGROUND_1, "background equipped");
        assertEq(equipped.length, 3, "3 outfits equipped");
        assertEq(equipped[0], NECKLACE_1, "necklace equipped");
        assertEq(equipped[1], EYES_1, "eyes equipped");
        assertEq(equipped[2], MOUTH_1, "mouth equipped");

        // Transfer body A to bob (simulated ownership change).
        hook.setOwner(BODY_A, bob);

        // Outfits should STILL be associated with body A.
        (uint256 bgId2, uint256[] memory equipped2) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId2, BACKGROUND_1, "background still equipped after transfer");
        assertEq(equipped2.length, 3, "3 outfits still equipped after transfer");
        assertEq(equipped2[0], NECKLACE_1, "necklace still equipped");
        assertEq(equipped2[1], EYES_1, "eyes still equipped");
        assertEq(equipped2[2], MOUTH_1, "mouth still equipped");

        // wearerOf still points to body A.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_1), BODY_A, "necklace wearer unchanged");
        assertEq(resolver.wearerOf(address(hook), EYES_1), BODY_A, "eyes wearer unchanged");
        assertEq(resolver.wearerOf(address(hook), MOUTH_1), BODY_A, "mouth wearer unchanged");
        assertEq(resolver.userOf(address(hook), BACKGROUND_1), BODY_A, "background user unchanged");
    }

    // =========================================================================
    // TEST 2: New body owner can unequip outfits (by decorating with empty).
    //         The outfits are returned to the new owner (msg.sender).
    // =========================================================================
    function test_newOwnerCanUnequipOutfits() public {
        // Alice dresses body A.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, outfits);

        // Transfer body A to bob.
        hook.setOwner(BODY_A, bob);

        // Bob undresses body A.
        uint256[] memory empty = new uint256[](0);
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // The necklace and background should be returned to bob (the msg.sender).
        assertEq(hook.ownerOf(NECKLACE_1), bob, "necklace returned to new body owner");
        assertEq(hook.ownerOf(BACKGROUND_1), bob, "background returned to new body owner");

        // Body A has no equipped items.
        (uint256 bgId, uint256[] memory equipped) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, 0, "no background");
        assertEq(equipped.length, 0, "no outfits");
    }

    // =========================================================================
    // TEST 3: New body owner can re-equip different outfits.
    // =========================================================================
    function test_newOwnerCanReEquipDifferentOutfits() public {
        // Alice dresses body A with necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Transfer body A and eyes to bob.
        hook.setOwner(BODY_A, bob);
        hook.setOwner(EYES_1, bob);

        // Bob redresses body A with eyes instead of necklace.
        uint256[] memory newOutfits = new uint256[](1);
        newOutfits[0] = EYES_1;
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, newOutfits);

        // Necklace returned to bob, eyes now equipped.
        assertEq(hook.ownerOf(NECKLACE_1), bob, "old necklace returned to bob");
        assertEq(resolver.wearerOf(address(hook), EYES_1), BODY_A, "eyes now worn by body A");

        (uint256 bgId, uint256[] memory equipped) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, 0, "no background");
        assertEq(equipped.length, 1, "1 outfit");
        assertEq(equipped[0], EYES_1, "eyes equipped");
    }

    // =========================================================================
    // TEST 4: Old owner (alice) cannot interact with the body's outfits
    //         after transferring the body to bob.
    // =========================================================================
    function test_oldOwnerCannotModifyOutfitsAfterTransfer() public {
        // Alice dresses body A.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Transfer body A to bob.
        hook.setOwner(BODY_A, bob);

        // Alice tries to undress body A. Should revert because alice no longer owns the body.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBannyBody.selector);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);
    }

    // =========================================================================
    // TEST 5: Background also "travels" with the body transfer.
    //         New owner can switch backgrounds.
    // =========================================================================
    function test_backgroundTravelsWithBody() public {
        // Alice puts background on body A.
        uint256[] memory empty = new uint256[](0);
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, empty);

        assertEq(resolver.userOf(address(hook), BACKGROUND_1), BODY_A, "background used by body A");

        // Transfer body to bob.
        hook.setOwner(BODY_A, bob);

        // Background is still associated.
        assertEq(resolver.userOf(address(hook), BACKGROUND_1), BODY_A, "background still used after transfer");

        // Bob removes the background.
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // Background returned to bob.
        assertEq(hook.ownerOf(BACKGROUND_1), bob, "background returned to new owner");
        assertEq(resolver.userOf(address(hook), BACKGROUND_1), 0, "background no longer in use");
    }

    // =========================================================================
    // TEST 6: Multi-outfit full lifecycle: dress -> transfer -> redress -> transfer again.
    // =========================================================================
    function test_fullLifecycle_dress_transfer_redress_transfer() public {
        // Step 1: Alice dresses body A with necklace + eyes.
        uint256[] memory outfitsA = new uint256[](2);
        outfitsA[0] = NECKLACE_1; // cat 3
        outfitsA[1] = EYES_1; // cat 5
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, BACKGROUND_1, outfitsA);

        // Step 2: Transfer body A to bob.
        hook.setOwner(BODY_A, bob);

        // Step 3: Bob redresses with just mouth (removing necklace and eyes).
        hook.setOwner(MOUTH_1, bob);
        uint256[] memory outfitsB = new uint256[](1);
        outfitsB[0] = MOUTH_1; // cat 7
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfitsB);

        // Verify: necklace and eyes returned to bob, background returned to bob.
        assertEq(hook.ownerOf(NECKLACE_1), bob, "necklace returned to bob");
        assertEq(hook.ownerOf(EYES_1), bob, "eyes returned to bob");
        assertEq(hook.ownerOf(BACKGROUND_1), bob, "background returned to bob");
        assertEq(resolver.wearerOf(address(hook), MOUTH_1), BODY_A, "mouth now on body A");

        // Step 4: Transfer body A to charlie.
        hook.setOwner(BODY_A, charlie);

        // Mouth is still on body A.
        (uint256 bgId, uint256[] memory equipped) = resolver.assetIdsOf(address(hook), BODY_A);
        assertEq(bgId, 0, "no background");
        assertEq(equipped.length, 1, "1 outfit");
        assertEq(equipped[0], MOUTH_1, "mouth still equipped");

        // Step 5: Charlie unequips everything.
        uint256[] memory empty = new uint256[](0);
        vm.prank(charlie);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // Mouth returned to charlie.
        assertEq(hook.ownerOf(MOUTH_1), charlie, "mouth returned to charlie");
    }

    // =========================================================================
    // TEST 7: WARNING verification -- sellers should unequip before selling.
    //         If they don't, the buyer gets control of all equipped items.
    // =========================================================================
    function test_sellerWarning_buyerGetsEquippedItems() public {
        // Alice dresses body A with expensive necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_1;
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, outfits);

        // Alice "sells" (transfers) body A to bob WITHOUT unequipping.
        // This is the documented WARNING behavior.
        hook.setOwner(BODY_A, bob);

        // Bob can now unequip the necklace and keep it.
        uint256[] memory empty = new uint256[](0);
        vm.prank(bob);
        resolver.decorateBannyWith(address(hook), BODY_A, 0, empty);

        // Bob now owns the necklace!
        assertEq(hook.ownerOf(NECKLACE_1), bob, "buyer gets the equipped outfit");
    }

    // =========================================================================
    // HELPER
    // =========================================================================

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
                flags: JB721TierFlags({
                    allowOwnerMint: false,
                    transfersPausable: false,
                    cantBeRemoved: false,
                    cantIncreaseDiscountPercent: false,
                    cantBuyWithCredits: false
                }),
                splitPercent: 0,
                resolvedUri: ""
            })
        );
    }
}
