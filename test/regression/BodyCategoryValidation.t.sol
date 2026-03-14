// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice Minimal mock hook.
contract MockHook57 {
    mapping(uint256 => address) public ownerOf;
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

/// @notice Minimal mock store.
contract MockStore57 {
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

/// @notice decorateBannyWith should reject non-body-category tokens as bannyBodyId.
contract BodyCategoryValidationTest is Test {
    Banny721TokenUriResolver resolver;
    MockHook57 hook;
    MockStore57 store;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");

    uint256 constant BODY_TOKEN = 4_000_000_001; // category 0 (body)
    uint256 constant NECKLACE_TOKEN = 10_000_000_001; // category 3 (necklace)

    function setUp() public {
        store = new MockStore57();
        hook = new MockHook57(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );

        // Set up body token (category 0).
        _setupTier(BODY_TOKEN, 4, 0);
        hook.setOwner(BODY_TOKEN, alice);

        // Set up necklace token (category 3) -- NOT a body.
        _setupTier(NECKLACE_TOKEN, 10, 3);
        hook.setOwner(NECKLACE_TOKEN, alice);

        vm.prank(alice);
        hook.setApprovalForAll(address(resolver), true);
    }

    /// @notice Passing a non-body token as bannyBodyId should revert.
    function test_decorateBannyWith_revertsIfNotBodyCategory() public {
        uint256[] memory outfitIds = new uint256[](0);

        vm.prank(alice);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_BannyBodyNotBodyCategory.selector);
        resolver.decorateBannyWith(address(hook), NECKLACE_TOKEN, 0, outfitIds);
    }

    /// @notice Passing a valid body token should succeed.
    function test_decorateBannyWith_succeedsWithBodyCategory() public {
        uint256[] memory outfitIds = new uint256[](0);

        vm.prank(alice);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, outfitIds);
        // Should not revert.
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
