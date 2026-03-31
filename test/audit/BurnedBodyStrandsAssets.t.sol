// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
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

    uint256 constant BODY1 = 1_000_000_001;
    uint256 constant BODY2 = 1_000_000_002;
    uint256 constant BACKGROUND = 2_000_000_001;
    uint256 constant OUTFIT = 3_000_000_001;

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
        _setupTier(OUTFIT, 3, 2);

        hook.setOwner(BODY1, alice);
        hook.setOwner(BODY2, alice);
        hook.setOwner(BACKGROUND, alice);
        hook.setOwner(OUTFIT, alice);

        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
    }

    function test_burningDressedBodyPermanentlyStrandsAttachedAssets() public {
        uint256[] memory outfitIds = new uint256[](1);
        outfitIds[0] = OUTFIT;

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY1, BACKGROUND, outfitIds);

        assertEq(resolver.userOf(address(hook), BACKGROUND), BODY1);
        assertEq(resolver.wearerOf(address(hook), OUTFIT), BODY1);

        hook.burn(BODY1);

        vm.expectRevert(bytes("ERC721: token does not exist"));
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY2, BACKGROUND, outfitIds);

        uint256[] memory emptyOutfits = new uint256[](0);
        vm.expectRevert(bytes("ERC721: token does not exist"));
        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY1, 0, emptyOutfits);
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
