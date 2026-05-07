// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {JB721TierFlags} from "@bananapus/721-hook-v6/src/structs/JB721TierFlags.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

contract StrandMockHook {
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
            "StrandMockHook: not authorized"
        );

        ownerOf[tokenId] = to;

        if (to.code.length > 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            require(retval == IERC721Receiver.onERC721Received.selector, "StrandMockHook: receiver rejected");
        }
    }

    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

contract StrandMockStore {
    mapping(address hook => mapping(uint256 tokenId => JB721Tier)) public tiers;

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

contract NonReceiverOwner {
    function approveResolver(StrandMockHook hook, address resolver) external {
        hook.setApprovalForAll(resolver, true);
    }

    function decorate(
        Banny721TokenUriResolver resolver,
        address hook,
        uint256 bannyBodyId,
        uint256 backgroundId,
        uint256[] memory outfitIds
    )
        external
    {
        resolver.decorateBannyWith(hook, bannyBodyId, backgroundId, outfitIds);
    }
}

contract TryTransferFromStrandsAssetsTest is Test {
    Banny721TokenUriResolver resolver;
    StrandMockHook hook;
    StrandMockStore store;
    NonReceiverOwner ownerContract;

    uint256 constant BODY_TOKEN = 4_000_000_001;
    uint256 constant BACKGROUND_TOKEN = 5_000_000_001;
    uint256 constant NECKLACE_TOKEN = 10_000_000_001;

    function setUp() public {
        store = new StrandMockStore();
        hook = new StrandMockHook(address(store));
        ownerContract = new NonReceiverOwner();

        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", address(this), address(0)
        );

        _setupTier(BODY_TOKEN, 4, 0);
        _setupTier(BACKGROUND_TOKEN, 5, 1);
        _setupTier(NECKLACE_TOKEN, 10, 3);

        hook.setOwner(BODY_TOKEN, address(ownerContract));
        hook.setOwner(BACKGROUND_TOKEN, address(ownerContract));
        hook.setOwner(NECKLACE_TOKEN, address(ownerContract));

        ownerContract.approveResolver(hook, address(resolver));
    }

    function test_antiStranding_assetsRetainedWhenOwnerCannotReceiveERC721() public {
        // Equip background and necklace outfit.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_TOKEN;

        ownerContract.decorate(resolver, address(hook), BODY_TOKEN, BACKGROUND_TOKEN, outfits);

        assertEq(hook.ownerOf(BACKGROUND_TOKEN), address(resolver), "background should be in resolver custody");
        assertEq(hook.ownerOf(NECKLACE_TOKEN), address(resolver), "outfit should be in resolver custody");

        // Try to undress --transfers back to NonReceiverOwner will fail because it doesn't implement IERC721Receiver.
        uint256[] memory empty = new uint256[](0);
        ownerContract.decorate(resolver, address(hook), BODY_TOKEN, 0, empty);

        // Both NFTs remain in resolver custody (transfer failed silently).
        assertEq(hook.ownerOf(BACKGROUND_TOKEN), address(resolver), "background remains in resolver custody");
        assertEq(hook.ownerOf(NECKLACE_TOKEN), address(resolver), "outfit remains in resolver custody");

        // KEY CHANGE: State is now PRESERVED --tracking is NOT cleared on failed transfers.
        // Background remains tracked because _decorateBannyWithBackground aborts the removal on failed transfer.
        assertEq(
            resolver.userOf(address(hook), BACKGROUND_TOKEN),
            BODY_TOKEN,
            "background tracking preserved -- still attached to body"
        );

        // Outfit is retained in the attached list because _storeOutfitsWithRetained merges failed transfers.
        assertEq(
            resolver.wearerOf(address(hook), NECKLACE_TOKEN),
            BODY_TOKEN,
            "outfit tracking preserved --still worn by body"
        );

        // assetIdsOf reflects the retained state.
        (uint256 backgroundId, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(backgroundId, BACKGROUND_TOKEN, "body still exposes the background");
        assertEq(currentOutfits.length, 1, "body still exposes the outfit");
        assertEq(currentOutfits[0], NECKLACE_TOKEN, "retained outfit is the necklace");

        // The owner CAN still re-decorate because the assets are still tracked.
        // Re-equipping the same outfit (no-op transfer) works fine.
        outfits[0] = NECKLACE_TOKEN;
        ownerContract.decorate(resolver, address(hook), BODY_TOKEN, BACKGROUND_TOKEN, outfits);

        // State remains consistent.
        (backgroundId, currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(backgroundId, BACKGROUND_TOKEN, "background re-equipped");
        assertEq(currentOutfits.length, 1, "outfit still attached");
        assertEq(currentOutfits[0], NECKLACE_TOKEN, "outfit is still the necklace");
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
