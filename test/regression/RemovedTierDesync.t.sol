// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice Mock hook that supports tier removal (clearing tier data so tierOfTokenId returns defaults).
contract MockHookM8 {
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => uint32) public tierIdOf;
    mapping(uint256 => uint24) public categoryOf;
    address public immutable MOCK_STORE;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

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

/// @notice Mock store that supports tier removal (deleting tier data so tierOfTokenId returns a zeroed struct).
contract MockStoreM8 {
    mapping(address => mapping(uint256 => JB721Tier)) public tiers;
    mapping(address => mapping(uint256 => bool)) public tierRemoved;

    function setTier(address hook, uint256 tokenId, JB721Tier memory tier) external {
        tiers[hook][tokenId] = tier;
        tierRemoved[hook][tokenId] = false;
    }

    /// @notice Simulate removing a tier — tierOfTokenId will return a zeroed struct (category = 0).
    function removeTier(address hook, uint256 tokenId) external {
        delete tiers[hook][tokenId];
        tierRemoved[hook][tokenId] = true;
    }

    function tierOfTokenId(address hook, uint256 tokenId, bool) external view returns (JB721Tier memory) {
        return tiers[hook][tokenId];
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function encodedIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/// @notice Removed tier causes outfit state desynchronization.
/// @dev When a previously equipped outfit's tier is removed, `_productOfTokenId` returns category 0.
///      Before the fix, this caused the first while loop to exit immediately (due to `!= 0` guard),
///      and the second while loop would transfer out outfits that were being re-equipped.
contract RemovedTierDesyncTest is Test {
    Banny721TokenUriResolver resolver;
    MockHookM8 hook;
    MockStoreM8 store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");

    // Token IDs: tierId * 1_000_000_000 + sequence.
    uint256 constant BODY_TOKEN = 4_000_000_001;
    uint256 constant NECKLACE_TOKEN = 10_000_000_001; // category 3
    uint256 constant EYES_TOKEN = 30_000_000_001; // category 5
    uint256 constant MOUTH_TOKEN = 40_000_000_001; // category 7

    function setUp() public {
        store = new MockStoreM8();
        hook = new MockHookM8(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        _setupTier(BODY_TOKEN, 4, 0);
        _setupTier(NECKLACE_TOKEN, 10, 3);
        _setupTier(EYES_TOKEN, 30, 5);
        _setupTier(MOUTH_TOKEN, 40, 7);

        hook.setOwner(BODY_TOKEN, alice);
        hook.setOwner(NECKLACE_TOKEN, alice);
        hook.setOwner(EYES_TOKEN, alice);
        hook.setOwner(MOUTH_TOKEN, alice);

        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
    }

    /// @notice Equip 3 outfits, remove first outfit's tier, re-equip remaining 2.
    ///         The remaining outfits should stay properly equipped and not be transferred back.
    function test_reequipAfterTierRemoval_retainsValidOutfits() public {
        // Step 1: Equip necklace, eyes, and mouth.
        uint256[] memory outfitIds = new uint256[](3);
        outfitIds[0] = NECKLACE_TOKEN; // category 3
        outfitIds[1] = EYES_TOKEN; // category 5
        outfitIds[2] = MOUTH_TOKEN; // category 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Verify all equipped.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace should be worn");
        assertEq(resolver.wearerOf(address(hook), EYES_TOKEN), BODY_TOKEN, "eyes should be worn");
        assertEq(resolver.wearerOf(address(hook), MOUTH_TOKEN), BODY_TOKEN, "mouth should be worn");

        // All outfit tokens should be held by the resolver.
        assertEq(hook.ownerOf(NECKLACE_TOKEN), address(resolver), "necklace held by resolver");
        assertEq(hook.ownerOf(EYES_TOKEN), address(resolver), "eyes held by resolver");
        assertEq(hook.ownerOf(MOUTH_TOKEN), address(resolver), "mouth held by resolver");

        // Step 2: Admin removes the necklace tier.
        store.removeTier(address(hook), NECKLACE_TOKEN);

        // Step 3: Re-equip with only the remaining valid outfits (eyes + mouth).
        uint256[] memory newOutfitIds = new uint256[](2);
        newOutfitIds[0] = EYES_TOKEN; // category 5
        newOutfitIds[1] = MOUTH_TOKEN; // category 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, newOutfitIds);

        // Step 4: Verify eyes and mouth are STILL properly equipped (not transferred out).
        assertEq(resolver.wearerOf(address(hook), EYES_TOKEN), BODY_TOKEN, "eyes should still be worn after re-equip");
        assertEq(resolver.wearerOf(address(hook), MOUTH_TOKEN), BODY_TOKEN, "mouth should still be worn after re-equip");

        // Eyes and mouth should still be held by the resolver.
        assertEq(hook.ownerOf(EYES_TOKEN), address(resolver), "eyes should still be held by resolver");
        assertEq(hook.ownerOf(MOUTH_TOKEN), address(resolver), "mouth should still be held by resolver");

        // Step 5: Verify the assets list only contains eyes and mouth.
        (, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(currentOutfits.length, 2, "should have 2 outfits");
        assertEq(currentOutfits[0], EYES_TOKEN, "first outfit should be eyes");
        assertEq(currentOutfits[1], MOUTH_TOKEN, "second outfit should be mouth");
    }

    /// @notice Variant: remove a middle outfit's tier, re-equip first and last.
    function test_reequipAfterMiddleTierRemoval_retainsValidOutfits() public {
        // Equip necklace, eyes, and mouth.
        uint256[] memory outfitIds = new uint256[](3);
        outfitIds[0] = NECKLACE_TOKEN; // category 3
        outfitIds[1] = EYES_TOKEN; // category 5
        outfitIds[2] = MOUTH_TOKEN; // category 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Remove the eyes tier (middle outfit).
        store.removeTier(address(hook), EYES_TOKEN);

        // Re-equip with necklace + mouth (skipping the removed eyes).
        uint256[] memory newOutfitIds = new uint256[](2);
        newOutfitIds[0] = NECKLACE_TOKEN; // category 3
        newOutfitIds[1] = MOUTH_TOKEN; // category 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, newOutfitIds);

        // Necklace and mouth should still be equipped.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace should still be worn");
        assertEq(resolver.wearerOf(address(hook), MOUTH_TOKEN), BODY_TOKEN, "mouth should still be worn");
        assertEq(hook.ownerOf(NECKLACE_TOKEN), address(resolver), "necklace should still be held by resolver");
        assertEq(hook.ownerOf(MOUTH_TOKEN), address(resolver), "mouth should still be held by resolver");

        (, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(currentOutfits.length, 2, "should have 2 outfits");
        assertEq(currentOutfits[0], NECKLACE_TOKEN, "first outfit should be necklace");
        assertEq(currentOutfits[1], MOUTH_TOKEN, "second outfit should be mouth");
    }

    /// @notice Variant: remove the last outfit's tier, re-equip first two.
    function test_reequipAfterLastTierRemoval_retainsValidOutfits() public {
        // Equip necklace, eyes, and mouth.
        uint256[] memory outfitIds = new uint256[](3);
        outfitIds[0] = NECKLACE_TOKEN; // category 3
        outfitIds[1] = EYES_TOKEN; // category 5
        outfitIds[2] = MOUTH_TOKEN; // category 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Remove the mouth tier (last outfit).
        store.removeTier(address(hook), MOUTH_TOKEN);

        // Re-equip with necklace + eyes only.
        uint256[] memory newOutfitIds = new uint256[](2);
        newOutfitIds[0] = NECKLACE_TOKEN; // category 3
        newOutfitIds[1] = EYES_TOKEN; // category 5

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, newOutfitIds);

        // Necklace and eyes should still be equipped.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace should still be worn");
        assertEq(resolver.wearerOf(address(hook), EYES_TOKEN), BODY_TOKEN, "eyes should still be worn");
        assertEq(hook.ownerOf(NECKLACE_TOKEN), address(resolver), "necklace should still be held by resolver");
        assertEq(hook.ownerOf(EYES_TOKEN), address(resolver), "eyes should still be held by resolver");
    }

    /// @notice Variant: all tiers removed, clear all outfits. Should not revert.
    function test_clearOutfitsAfterAllTiersRemoved() public {
        // Equip necklace and eyes.
        uint256[] memory outfitIds = new uint256[](2);
        outfitIds[0] = NECKLACE_TOKEN;
        outfitIds[1] = EYES_TOKEN;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Remove both tiers.
        store.removeTier(address(hook), NECKLACE_TOKEN);
        store.removeTier(address(hook), EYES_TOKEN);

        // Clear all outfits (empty array). Should not revert.
        uint256[] memory emptyOutfits = new uint256[](0);

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, emptyOutfits);

        (, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(currentOutfits.length, 0, "should have no outfits");
    }

    /// @notice Edge case: single outfit equipped, its tier removed, re-equip with a different outfit.
    function test_replaceRemovedTierOutfitWithNew() public {
        // Equip necklace.
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = NECKLACE_TOKEN;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Remove necklace tier.
        store.removeTier(address(hook), NECKLACE_TOKEN);

        // Equip eyes instead.
        uint256[] memory newOutfitIds = new uint256[](1);
        newOutfitIds[0] = EYES_TOKEN;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, newOutfitIds);

        // Eyes should be equipped.
        assertEq(resolver.wearerOf(address(hook), EYES_TOKEN), BODY_TOKEN, "eyes should be worn");
        assertEq(hook.ownerOf(EYES_TOKEN), address(resolver), "eyes should be held by resolver");

        (, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(currentOutfits.length, 1, "should have 1 outfit");
        assertEq(currentOutfits[0], EYES_TOKEN, "outfit should be eyes");
    }

    /// @notice Edge case: two consecutive removed tiers at the start.
    function test_reequipAfterTwoConsecutiveRemovedTiers() public {
        // Equip necklace, eyes, and mouth.
        uint256[] memory outfitIds = new uint256[](3);
        outfitIds[0] = NECKLACE_TOKEN; // category 3
        outfitIds[1] = EYES_TOKEN; // category 5
        outfitIds[2] = MOUTH_TOKEN; // category 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Remove both necklace and eyes tiers.
        store.removeTier(address(hook), NECKLACE_TOKEN);
        store.removeTier(address(hook), EYES_TOKEN);

        // Re-equip with just mouth.
        uint256[] memory newOutfitIds = new uint256[](1);
        newOutfitIds[0] = MOUTH_TOKEN; // category 7

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, newOutfitIds);

        // Mouth should still be equipped.
        assertEq(resolver.wearerOf(address(hook), MOUTH_TOKEN), BODY_TOKEN, "mouth should still be worn");
        assertEq(hook.ownerOf(MOUTH_TOKEN), address(resolver), "mouth should still be held by resolver");

        (, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(currentOutfits.length, 1, "should have 1 outfit");
        assertEq(currentOutfits[0], MOUTH_TOKEN, "outfit should be mouth");
    }

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
    }
}
