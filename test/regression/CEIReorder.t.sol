// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice Mock hook that records transfer ordering so we can verify CEI.
contract MockHookI25 {
    mapping(uint256 => address) public ownerOf;
    address public immutable MOCK_STORE;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// @notice Tracks order of transfers for CEI verification.
    uint256[] public transferLog;

    constructor(address store) {
        MOCK_STORE = store;
    }

    function STORE() external view returns (address) {
        return MOCK_STORE;
    }

    function setOwner(uint256 tokenId, address owner) external {
        ownerOf[tokenId] = owner;
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
        transferLog.push(tokenId);
        if (to.code.length > 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            require(retval == IERC721Receiver.onERC721Received.selector, "MockHook: receiver rejected");
        }
    }

    function transferLogLength() external view returns (uint256) {
        return transferLog.length;
    }

    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @notice Minimal mock store.
contract MockStoreI25 {
    mapping(address => mapping(uint256 => JB721Tier)) public tiers;

    function setTier(address hook, uint256 tokenId, JB721Tier memory tier) external {
        tiers[hook][tokenId] = tier;
    }

    function tierOfTokenId(address hook, uint256 tokenId, bool) external view returns (JB721Tier memory) {
        return tiers[hook][tokenId];
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function encodedIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/// @notice _decorateBannyWithBackground follows CEI pattern.
/// @dev The fix reordered state writes (effects) before external transfers (interactions)
/// in _decorateBannyWithBackground. This test verifies that after a background replacement,
/// state is consistent and both the old background return and new background custody work.
contract CEIReorderTest is Test {
    Banny721TokenUriResolver resolver;
    MockHookI25 hook;
    MockStoreI25 store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");

    uint256 constant BODY_TOKEN = 4_000_000_001;
    uint256 constant BG_TOKEN_A = 5_000_000_001; // background A
    uint256 constant BG_TOKEN_B = 5_000_000_002; // background B

    function setUp() public {
        store = new MockStoreI25();
        hook = new MockHookI25(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        // Set up body (category 0).
        _setupTier(BODY_TOKEN, 4, 0);
        // Set up two backgrounds (category 1).
        _setupTier(BG_TOKEN_A, 5, 1);
        _setupTier(BG_TOKEN_B, 6, 1);

        hook.setOwner(BODY_TOKEN, alice);
        hook.setOwner(BG_TOKEN_A, alice);
        hook.setOwner(BG_TOKEN_B, alice);

        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
    }

    /// @notice Replacing background A with B should update state correctly and return A to caller.
    function test_replaceBackground_stateConsistentAfterCEIReorder() public {
        uint256[] memory emptyOutfits = new uint256[](0);

        // Attach background A.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BG_TOKEN_A, emptyOutfits);

        // Verify background A is attached.
        assertEq(resolver.userOf(address(hook), BG_TOKEN_A), BODY_TOKEN, "BG_A should be used by body");
        assertEq(hook.ownerOf(BG_TOKEN_A), address(resolver), "BG_A should be held by resolver");

        // Replace background A with B.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BG_TOKEN_B, emptyOutfits);

        // Verify state is consistent after replacement.
        assertEq(resolver.userOf(address(hook), BG_TOKEN_B), BODY_TOKEN, "BG_B should now be used by body");
        assertEq(resolver.userOf(address(hook), BG_TOKEN_A), 0, "BG_A should no longer be used");
        assertEq(hook.ownerOf(BG_TOKEN_B), address(resolver), "BG_B should be held by resolver");
        assertEq(hook.ownerOf(BG_TOKEN_A), alice, "BG_A should be returned to alice");

        // Verify assetIdsOf reflects the new background.
        (uint256 backgroundId,) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(backgroundId, BG_TOKEN_B, "assetIdsOf should show BG_B");
    }

    /// @notice Clearing a background (setting to 0) should update state before transfer.
    function test_clearBackground_stateConsistentAfterCEIReorder() public {
        uint256[] memory emptyOutfits = new uint256[](0);

        // Attach background A.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BG_TOKEN_A, emptyOutfits);

        // Clear background.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, emptyOutfits);

        // State should be cleared and token returned.
        assertEq(resolver.userOf(address(hook), BG_TOKEN_A), 0, "BG_A should no longer be used");
        assertEq(hook.ownerOf(BG_TOKEN_A), alice, "BG_A should be returned to alice");

        (uint256 backgroundId,) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(backgroundId, 0, "assetIdsOf should show no background");
    }

    /// @notice Setting the same background again should be a no-op (no redundant transfers).
    function test_sameBackground_noRedundantTransfer() public {
        uint256[] memory emptyOutfits = new uint256[](0);

        // Attach background A.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BG_TOKEN_A, emptyOutfits);

        uint256 logBefore = hook.transferLogLength();

        // Re-attach same background.
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BG_TOKEN_A, emptyOutfits);

        // No new transfers should have occurred for the background.
        uint256 logAfter = hook.transferLogLength();
        assertEq(logAfter, logBefore, "No transfers should occur when re-attaching same background");
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
            cantBuyWithCredits: false,
            splitPercent: 0,
            resolvedUri: ""
        });
        store.setTier(address(hook), tokenId, tier);
    }
}
