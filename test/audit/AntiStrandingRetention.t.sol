// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @dev Mock hook that supports safeTransferFrom with ERC721Receiver checks.
contract RetentionMockHook {
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
            "RetentionMockHook: not authorized"
        );

        ownerOf[tokenId] = to;

        if (to.code.length > 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            require(retval == IERC721Receiver.onERC721Received.selector, "RetentionMockHook: receiver rejected");
        }
    }

    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @dev Mock store that returns tier data.
contract RetentionMockStore {
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

/// @dev Contract that does NOT implement IERC721Receiver --transfers to it will revert.
contract NonReceiverContract {
    function approveResolver(RetentionMockHook hook, address resolver) external {
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

/// @dev Contract that DOES implement IERC721Receiver --can receive NFTs.
contract ReceiverContract is IERC721Receiver {
    bool public canReceive = true;

    function setCanReceive(bool _canReceive) external {
        canReceive = _canReceive;
    }

    function approveResolver(RetentionMockHook hook, address resolver) external {
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

    function onERC721Received(address, address, uint256, bytes calldata) external view override returns (bytes4) {
        require(canReceive, "ReceiverContract: rejecting");
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract AntiStrandingRetentionTest is Test {
    Banny721TokenUriResolver resolver;
    RetentionMockHook hook;
    RetentionMockStore store;
    NonReceiverContract nonReceiver;
    ReceiverContract receiverContract;

    uint256 constant BODY_TOKEN = 4_000_000_001;
    uint256 constant BG_TOKEN_1 = 5_000_000_001;
    uint256 constant BG_TOKEN_2 = 5_000_000_002;
    uint256 constant NECKLACE_TOKEN = 10_000_000_001;
    uint256 constant HEAD_TOKEN = 11_000_000_001;
    uint256 constant EYES_TOKEN = 12_000_000_001;

    function setUp() public {
        store = new RetentionMockStore();
        hook = new RetentionMockHook(address(store));
        nonReceiver = new NonReceiverContract();
        receiverContract = new ReceiverContract();

        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", address(this), address(0)
        );

        // Set up tiers: body(cat 0), backgrounds(cat 1), necklace(cat 3), head(cat 4), eyes(cat 5)
        _setupTier(BODY_TOKEN, 4, 0);
        _setupTier(BG_TOKEN_1, 5, 1);
        _setupTier(BG_TOKEN_2, 6, 1);
        _setupTier(NECKLACE_TOKEN, 10, 3);
        _setupTier(HEAD_TOKEN, 11, 4);
        _setupTier(EYES_TOKEN, 12, 5);
    }

    // -----------------------------------------------------------------------
    // Test 1: Background equip aborted on failed return
    // -----------------------------------------------------------------------
    function test_backgroundEquipAbortedOnFailedReturn() public {
        // Give NonReceiverContract ownership of body and both backgrounds.
        _setOwnerForAll(address(nonReceiver));
        nonReceiver.approveResolver(hook, address(resolver));

        // Equip BG_TOKEN_1.
        uint256[] memory empty = new uint256[](0);
        nonReceiver.decorate(resolver, address(hook), BODY_TOKEN, BG_TOKEN_1, empty);

        assertEq(hook.ownerOf(BG_TOKEN_1), address(resolver), "bg1 in resolver custody");
        assertEq(resolver.userOf(address(hook), BG_TOKEN_1), BODY_TOKEN, "bg1 attached to body");

        // Try to replace with BG_TOKEN_2 --returning BG_TOKEN_1 fails (NonReceiverContract).
        nonReceiver.decorate(resolver, address(hook), BODY_TOKEN, BG_TOKEN_2, empty);

        // Old background stays attached (return aborted the background change).
        assertEq(resolver.userOf(address(hook), BG_TOKEN_1), BODY_TOKEN, "bg1 still attached --change was aborted");

        // New background was NOT equipped.
        (uint256 bgId,) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(bgId, BG_TOKEN_1, "body still has bg1, not bg2");

        // BG_TOKEN_2 stays with the nonReceiver (never transferred in).
        assertEq(hook.ownerOf(BG_TOKEN_2), address(nonReceiver), "bg2 never transferred to resolver");
    }

    // -----------------------------------------------------------------------
    // Test 2: Background removal preserved on failed return
    // -----------------------------------------------------------------------
    function test_backgroundRemovalPreservedOnFailedReturn() public {
        _setOwnerForAll(address(nonReceiver));
        nonReceiver.approveResolver(hook, address(resolver));

        // Equip BG_TOKEN_1.
        uint256[] memory empty = new uint256[](0);
        nonReceiver.decorate(resolver, address(hook), BODY_TOKEN, BG_TOKEN_1, empty);

        assertEq(resolver.userOf(address(hook), BG_TOKEN_1), BODY_TOKEN, "bg1 attached");

        // Try to remove background (pass 0) --return to NonReceiverContract fails.
        nonReceiver.decorate(resolver, address(hook), BODY_TOKEN, 0, empty);

        // Background stays attached because the transfer failed and state was preserved.
        assertEq(resolver.userOf(address(hook), BG_TOKEN_1), BODY_TOKEN, "bg1 still attached --removal failed");
        (uint256 bgId,) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(bgId, BG_TOKEN_1, "body still has bg1");
    }

    // -----------------------------------------------------------------------
    // Test 3: Outfit retained on failed return
    // -----------------------------------------------------------------------
    function test_outfitRetainedOnFailedReturn() public {
        _setOwnerForAll(address(nonReceiver));
        nonReceiver.approveResolver(hook, address(resolver));

        // Equip necklace outfit.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_TOKEN;
        nonReceiver.decorate(resolver, address(hook), BODY_TOKEN, 0, outfits);

        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace worn by body");

        // Try to remove outfit (pass empty) --return to NonReceiverContract fails.
        uint256[] memory empty = new uint256[](0);
        nonReceiver.decorate(resolver, address(hook), BODY_TOKEN, 0, empty);

        // Outfit retained in the attached list.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace still worn --retained");
        (, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(currentOutfits.length, 1, "one outfit retained");
        assertEq(currentOutfits[0], NECKLACE_TOKEN, "retained outfit is the necklace");
    }

    // -----------------------------------------------------------------------
    // Test 4: Mixed outfit success/failure --EOA succeeds, contract fails
    // -----------------------------------------------------------------------
    function test_mixedOutfitSuccessAndFailure() public {
        // Set up: body owned by nonReceiver, outfits owned by nonReceiver.
        hook.setOwner(BODY_TOKEN, address(nonReceiver));
        hook.setOwner(NECKLACE_TOKEN, address(nonReceiver));
        hook.setOwner(HEAD_TOKEN, address(nonReceiver));
        hook.setOwner(BG_TOKEN_1, address(nonReceiver));
        hook.setOwner(BG_TOKEN_2, address(nonReceiver));
        hook.setOwner(EYES_TOKEN, address(nonReceiver));
        nonReceiver.approveResolver(hook, address(resolver));

        // Equip necklace and head.
        uint256[] memory outfits = new uint256[](2);
        outfits[0] = NECKLACE_TOKEN;
        outfits[1] = HEAD_TOKEN;
        nonReceiver.decorate(resolver, address(hook), BODY_TOKEN, 0, outfits);

        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace worn");
        assertEq(resolver.wearerOf(address(hook), HEAD_TOKEN), BODY_TOKEN, "head worn");

        // Now try to remove all outfits --both transfers will fail (NonReceiverContract).
        uint256[] memory empty = new uint256[](0);
        nonReceiver.decorate(resolver, address(hook), BODY_TOKEN, 0, empty);

        // Both should be retained.
        (, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(currentOutfits.length, 2, "both outfits retained");

        // Order: retained items are appended after new (empty), so they appear in order.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace still worn");
        assertEq(resolver.wearerOf(address(hook), HEAD_TOKEN), BODY_TOKEN, "head still worn");
    }

    // -----------------------------------------------------------------------
    // Test 5: Recovery path --make contract receivable, retry decoration
    // -----------------------------------------------------------------------
    function test_recoveryAfterMakingContractReceivable() public {
        // Use ReceiverContract with canReceive initially set to false.
        hook.setOwner(BODY_TOKEN, address(receiverContract));
        hook.setOwner(NECKLACE_TOKEN, address(receiverContract));
        hook.setOwner(BG_TOKEN_1, address(receiverContract));
        hook.setOwner(BG_TOKEN_2, address(receiverContract));
        hook.setOwner(HEAD_TOKEN, address(receiverContract));
        hook.setOwner(EYES_TOKEN, address(receiverContract));
        receiverContract.approveResolver(hook, address(resolver));

        // Equip necklace with receiver accepting.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_TOKEN;
        receiverContract.decorate(resolver, address(hook), BODY_TOKEN, BG_TOKEN_1, outfits);

        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace worn");
        assertEq(resolver.userOf(address(hook), BG_TOKEN_1), BODY_TOKEN, "bg1 attached");

        // Now disable receiving --simulates the "contract can't receive" scenario.
        receiverContract.setCanReceive(false);

        // Try to undress --transfers will fail.
        uint256[] memory empty = new uint256[](0);
        receiverContract.decorate(resolver, address(hook), BODY_TOKEN, 0, empty);

        // Assets retained.
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace retained");
        assertEq(resolver.userOf(address(hook), BG_TOKEN_1), BODY_TOKEN, "bg1 retained");

        // Re-enable receiving.
        receiverContract.setCanReceive(true);

        // Retry undress --now transfers should succeed.
        receiverContract.decorate(resolver, address(hook), BODY_TOKEN, 0, empty);

        // Background successfully removed.
        (uint256 bgId, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(bgId, 0, "bg removed after recovery");
        assertEq(currentOutfits.length, 0, "outfit removed after recovery");

        // NFTs returned to owner.
        assertEq(hook.ownerOf(BG_TOKEN_1), address(receiverContract), "bg1 returned to owner");
        assertEq(hook.ownerOf(NECKLACE_TOKEN), address(receiverContract), "necklace returned to owner");
    }

    // -----------------------------------------------------------------------
    // Test 6: Happy path unchanged --EOA owner equip/unequip works as before
    // -----------------------------------------------------------------------
    function test_happyPathUnchanged_EOAOwner() public {
        address alice = makeAddr("alice");

        // Set up: Alice (EOA) owns everything.
        hook.setOwner(BODY_TOKEN, alice);
        hook.setOwner(NECKLACE_TOKEN, alice);
        hook.setOwner(HEAD_TOKEN, alice);
        hook.setOwner(BG_TOKEN_1, alice);
        hook.setOwner(BG_TOKEN_2, alice);
        hook.setOwner(EYES_TOKEN, alice);

        vm.startPrank(alice);
        hook.setApprovalForAll(address(resolver), true);

        // Equip background + necklace.
        uint256[] memory outfits = new uint256[](1);
        outfits[0] = NECKLACE_TOKEN;
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, BG_TOKEN_1, outfits);

        assertEq(hook.ownerOf(BG_TOKEN_1), address(resolver), "bg in resolver custody");
        assertEq(hook.ownerOf(NECKLACE_TOKEN), address(resolver), "necklace in resolver custody");
        assertEq(resolver.userOf(address(hook), BG_TOKEN_1), BODY_TOKEN, "bg attached");
        assertEq(resolver.wearerOf(address(hook), NECKLACE_TOKEN), BODY_TOKEN, "necklace worn");

        // Undress --should work fine for EOA.
        uint256[] memory empty = new uint256[](0);
        resolver.decorateBannyWith(address(hook), BODY_TOKEN, 0, empty);

        // NFTs returned to Alice.
        assertEq(hook.ownerOf(BG_TOKEN_1), alice, "bg returned to alice");
        assertEq(hook.ownerOf(NECKLACE_TOKEN), alice, "necklace returned to alice");

        // State cleared.
        (uint256 bgId, uint256[] memory currentOutfits) = resolver.assetIdsOf(address(hook), BODY_TOKEN);
        assertEq(bgId, 0, "no bg attached");
        assertEq(currentOutfits.length, 0, "no outfits attached");

        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    function _setOwnerForAll(address owner) internal {
        hook.setOwner(BODY_TOKEN, owner);
        hook.setOwner(BG_TOKEN_1, owner);
        hook.setOwner(BG_TOKEN_2, owner);
        hook.setOwner(NECKLACE_TOKEN, owner);
        hook.setOwner(HEAD_TOKEN, owner);
        hook.setOwner(EYES_TOKEN, owner);
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
            cantBeRemoved: false,
            cantIncreaseDiscountPercent: false,
            cantBuyWithCredits: false,
            splitPercent: 0,
            resolvedUri: ""
        });

        store.setTier(address(hook), tokenId, tier);
    }
}
