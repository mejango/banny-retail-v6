// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {JB721TierFlags} from "@bananapus/721-hook-v6/src/structs/JB721TierFlags.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

contract MockBurnableHook is Test {
    mapping(uint256 => address) public owners;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    address public immutable MOCK_STORE;

    constructor(address store) {
        MOCK_STORE = store;
    }

    function STORE() external view returns (address) {
        return MOCK_STORE;
    }

    function setOwner(uint256 tokenId, address owner) external {
        owners[tokenId] = owner;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = owners[tokenId];
        require(owner != address(0), "ERC721: token does not exist");
        return owner;
    }

    function burn(uint256 tokenId) external {
        owners[tokenId] = address(0);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        address owner = owners[tokenId];
        require(owner != address(0), "ERC721: token does not exist");
        require(
            msg.sender == owner || msg.sender == from || isApprovedForAll[from][msg.sender], "MockHook: not authorized"
        );
        owners[tokenId] = to;
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

contract MockBurnableStore {
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

contract BurnedBodyStrandsAssetsTest is Test {
    Banny721TokenUriResolver resolver;
    MockBurnableHook hook;
    MockBurnableStore store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    address constant BURN_ADDRESS = address(0xdEaD);

    uint256 constant BODY1 = 1_000_000_001;
    uint256 constant BODY2 = 1_000_000_002;
    uint256 constant BACKGROUND = 2_000_000_001;
    uint256 constant OUTFIT_BACKSIDE = 3_000_000_001; // category 2
    uint256 constant OUTFIT_NECKLACE = 4_000_000_001; // category 3

    function setUp() public {
        store = new MockBurnableStore();
        hook = new MockBurnableHook(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        _setupTier(BODY1, 1, 0);
        _setupTier(BODY2, 1, 0);
        _setupTier(BACKGROUND, 2, 1);
        _setupTier(OUTFIT_BACKSIDE, 3, 2);
        _setupTier(OUTFIT_NECKLACE, 4, 3);

        hook.setOwner(BODY1, alice);
        hook.setOwner(BODY2, alice);
        hook.setOwner(BACKGROUND, alice);
        hook.setOwner(OUTFIT_BACKSIDE, alice);
        hook.setOwner(OUTFIT_NECKLACE, alice);

        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
    }

    /// @notice Proves the fix: burnEquippedAssetsFor burns all equipped assets when a body is burned.
    function test_burnEquippedAssetsFor_burnsAllEquippedAssets() public {
        // Equip outfit and background on body.
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = OUTFIT_BACKSIDE;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY1, BACKGROUND, outfitIds);

        // Verify assets are equipped.
        assertEq(resolver.userOf(address(hook), BACKGROUND), BODY1, "background should be used by body");
        assertEq(resolver.wearerOf(address(hook), OUTFIT_BACKSIDE), BODY1, "outfit should be worn by body");
        assertEq(hook.ownerOf(BACKGROUND), address(resolver), "background should be held by resolver");
        assertEq(hook.ownerOf(OUTFIT_BACKSIDE), address(resolver), "outfit should be held by resolver");

        // Burn the body.
        hook.burn(BODY1);

        // Call burnEquippedAssetsFor to clean up stranded assets.
        resolver.burnEquippedAssetsFor(address(hook), BODY1);

        // Background and outfit should now be at the burn address.
        assertEq(hook.ownerOf(BACKGROUND), BURN_ADDRESS, "background should be sent to burn address");
        assertEq(hook.ownerOf(OUTFIT_BACKSIDE), BURN_ADDRESS, "outfit should be sent to burn address");

        // Mappings should be cleared.
        assertEq(resolver.userOf(address(hook), BACKGROUND), 0, "background user mapping should be cleared");
        assertEq(resolver.wearerOf(address(hook), OUTFIT_BACKSIDE), 0, "outfit wearer mapping should be cleared");

        // assetIdsOf should return empty.
        (uint256 bgId, uint256[] memory outfits) = resolver.assetIdsOf(address(hook), BODY1);
        assertEq(bgId, 0, "assetIdsOf background should be 0");
        assertEq(outfits.length, 0, "assetIdsOf outfits should be empty");
    }

    /// @notice Proves the fix: burnEquippedAssetsFor works with multiple outfits.
    function test_burnEquippedAssetsFor_burnsMultipleOutfits() public {
        // Equip two outfits and a background.
        uint256[] memory outfitIds = new uint256[](2);
        outfitIds[0] = OUTFIT_BACKSIDE; // category 2
        outfitIds[1] = OUTFIT_NECKLACE; // category 3

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY1, BACKGROUND, outfitIds);

        // Burn the body.
        hook.burn(BODY1);

        // Clean up.
        resolver.burnEquippedAssetsFor(address(hook), BODY1);

        // All assets should be at the burn address.
        assertEq(hook.ownerOf(BACKGROUND), BURN_ADDRESS, "background burned");
        assertEq(hook.ownerOf(OUTFIT_BACKSIDE), BURN_ADDRESS, "backside outfit burned");
        assertEq(hook.ownerOf(OUTFIT_NECKLACE), BURN_ADDRESS, "necklace outfit burned");

        // All mappings cleared.
        assertEq(resolver.userOf(address(hook), BACKGROUND), 0);
        assertEq(resolver.wearerOf(address(hook), OUTFIT_BACKSIDE), 0);
        assertEq(resolver.wearerOf(address(hook), OUTFIT_NECKLACE), 0);
    }

    /// @notice burnEquippedAssetsFor reverts if the body is not actually burned.
    function test_burnEquippedAssetsFor_revertsIfBodyNotBurned() public {
        // Body still alive -- should revert.
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_BodyNotBurned.selector);
        resolver.burnEquippedAssetsFor(address(hook), BODY1);
    }

    /// @notice burnEquippedAssetsFor is callable by anyone (permissionless cleanup).
    function test_burnEquippedAssetsFor_callableByAnyone() public {
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = OUTFIT_BACKSIDE;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY1, BACKGROUND, outfitIds);

        hook.burn(BODY1);

        // Bob (not the original owner) can call burnEquippedAssetsFor.
        vm.prank(bob);
        resolver.burnEquippedAssetsFor(address(hook), BODY1);

        assertEq(hook.ownerOf(BACKGROUND), BURN_ADDRESS, "background burned by non-owner");
        assertEq(hook.ownerOf(OUTFIT_BACKSIDE), BURN_ADDRESS, "outfit burned by non-owner");
    }

    /// @notice burnEquippedAssetsFor works even when called on a body with no equipped assets.
    function test_burnEquippedAssetsFor_noAssetsIsNoOp() public {
        hook.burn(BODY1);

        // Should not revert -- just a no-op cleanup.
        resolver.burnEquippedAssetsFor(address(hook), BODY1);

        (uint256 bgId, uint256[] memory outfits) = resolver.assetIdsOf(address(hook), BODY1);
        assertEq(bgId, 0);
        assertEq(outfits.length, 0);
    }

    /// @notice burnEquippedAssetsFor clears the outfit lock.
    function test_burnEquippedAssetsFor_clearsLock() public {
        // Lock the body.
        vm.prank(alice);
        resolver.lockOutfitChangesFor(address(hook), BODY1);

        // Verify lock is set.
        assertGt(resolver.outfitLockedUntil(address(hook), BODY1), 0, "lock should be set");

        // Burn the body.
        hook.burn(BODY1);

        // Clean up.
        resolver.burnEquippedAssetsFor(address(hook), BODY1);

        // Lock should be cleared.
        assertEq(resolver.outfitLockedUntil(address(hook), BODY1), 0, "lock should be cleared after burn cleanup");
    }

    /// @notice After burnEquippedAssetsFor, assets can no longer be re-equipped to a different body
    /// (they are at the burn address, not recoverable).
    function test_burnEquippedAssetsFor_assetsNotRecoverable() public {
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = OUTFIT_BACKSIDE;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY1, BACKGROUND, outfitIds);

        hook.burn(BODY1);
        resolver.burnEquippedAssetsFor(address(hook), BODY1);

        // Assets are now at BURN_ADDRESS, not owned by alice or resolver.
        // Trying to equip them on BODY2 should fail because alice doesn't own them.
        uint256[] memory outfitIds2 = new uint256[](1);
        outfitIds2[0] = OUTFIT_BACKSIDE;

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_UnauthorizedBackground.selector);
        resolver.decorateBannyWith(address(hook), BODY2, BACKGROUND, outfitIds2);
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
            flags: JB721TierFlags({
                allowOwnerMint: false,
                transfersPausable: false,
                cantBeRemoved: false,
                cantIncreaseDiscountPercent: false,
                cantBuyWithCredits: false
            }),
            splitPercent: 0,
            resolvedUri: ""
        });
        store.setTier(address(hook), tokenId, tier);
    }
}
