// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {JB721TierFlags} from "@bananapus/721-hook-v6/src/structs/JB721TierFlags.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

contract DuplicateCategoryMockHook {
    mapping(uint256 tokenId => address) public ownerOf;
    mapping(address owner => mapping(address operator => bool)) public isApprovedForAll;
    address public immutable MOCK_STORE;

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

        if (to.code.length != 0) {
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

contract DuplicateCategoryMockStore {
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

contract ERC721RejectingOwner {
    function approveResolver(DuplicateCategoryMockHook hook, address resolver) external {
        hook.setApprovalForAll(resolver, true);
    }

    function decorate(
        Banny721TokenUriResolver resolver,
        address hook,
        uint256 bodyId,
        uint256 backgroundId,
        uint256[] memory outfitIds
    )
        external
    {
        resolver.decorateBannyWith(hook, bodyId, backgroundId, outfitIds);
    }
}

contract DuplicateCategoryRetentionTest is Test {
    Banny721TokenUriResolver resolver;
    DuplicateCategoryMockHook hook;
    DuplicateCategoryMockStore store;
    ERC721RejectingOwner rejector;

    uint256 internal constant BODY_TOKEN = 4_000_000_001;
    uint256 internal constant NECKLACE_ONE = 10_000_000_001;
    uint256 internal constant NECKLACE_TWO = 11_000_000_001;

    function setUp() public {
        store = new DuplicateCategoryMockStore();
        hook = new DuplicateCategoryMockHook(address(store));
        rejector = new ERC721RejectingOwner();

        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", address(this), address(0)
        );

        _setupTier(BODY_TOKEN, 4, 0);
        _setupTier(NECKLACE_ONE, 10, 3);
        _setupTier(NECKLACE_TWO, 11, 3);

        hook.setOwner(BODY_TOKEN, address(rejector));
        hook.setOwner(NECKLACE_ONE, address(rejector));
        hook.setOwner(NECKLACE_TWO, address(rejector));
        rejector.approveResolver(hook, address(resolver));
    }

    function test_retainedOutfitCanBypassOnePerCategoryInvariant() public {
        uint256[] memory first = new uint256[](1);
        first[0] = NECKLACE_ONE;
        rejector.decorate(resolver, address(hook), BODY_TOKEN, 0, first);

        uint256[] memory replacement = new uint256[](1);
        replacement[0] = NECKLACE_TWO;

        // After the L-1 fix, the duplicate category is detected and the call reverts.
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_DuplicateCategory.selector);
        rejector.decorate(resolver, address(hook), BODY_TOKEN, 0, replacement);
    }

    function _setupTier(uint256 tokenId, uint32 tierId, uint24 category) internal {
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
