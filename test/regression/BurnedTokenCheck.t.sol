// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice Mock hook that supports burning (setting owner to address(0) so ownerOf reverts).
contract MockHook62 {
    mapping(uint256 => address) public owners;
    address public immutable MOCK_STORE;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

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

    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @notice Minimal mock store.
contract MockStore62 {
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

/// @notice Burned equipped tokens should not lock the body.
contract BurnedTokenCheckTest is Test {
    Banny721TokenUriResolver resolver;
    MockHook62 hook;
    MockStore62 store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");

    uint256 constant BODY_TOKEN = 4_000_000_001;
    uint256 constant NECKLACE_TOKEN = 10_000_000_001;
    uint256 constant EYES_TOKEN = 30_000_000_001;

    function setUp() public {
        store = new MockStore62();
        hook = new MockHook62(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        _setupTier(BODY_TOKEN, 4, 0);
        _setupTier(NECKLACE_TOKEN, 10, 3);
        _setupTier(EYES_TOKEN, 30, 5);

        hook.setOwner(BODY_TOKEN, alice);
        hook.setOwner(NECKLACE_TOKEN, alice);
        hook.setOwner(EYES_TOKEN, alice);

        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
    }

    /// @notice If an equipped outfit is burned, the body should still be able to change outfits.
    function test_decorateBannyWith_succeedsAfterEquippedOutfitBurned() public {
        // Equip a necklace.
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = NECKLACE_TOKEN;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Verify necklace is equipped.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN);

        // Burn the necklace (simulate external burn while it's equipped).
        hook.burn(NECKLACE_TOKEN);

        // Now try to change outfits -- equip eyes instead. This should NOT revert.
        uint256[] memory newOutfitIds = new uint256[](1);
        newOutfitIds[0] = EYES_TOKEN;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, newOutfitIds);

        // Verify new outfit is equipped.
        assertEq(resolver.wearerOf(address(hook), EYES_TOKEN), BODY_TOKEN);
    }

    /// @notice If an equipped outfit is burned, the body should be able to clear all outfits.
    function test_decorateBannyWith_canClearOutfitsAfterBurn() public {
        // Equip a necklace.
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = NECKLACE_TOKEN;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);

        // Burn the necklace.
        hook.burn(NECKLACE_TOKEN);

        // Clear all outfits. This should NOT revert.
        uint256[] memory emptyOutfits = new uint256[](0);

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, emptyOutfits);
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
