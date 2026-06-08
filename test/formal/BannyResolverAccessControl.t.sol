// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice Reusable minimal hook/store mock for the access-control fuzz proofs.
contract ACMockHook {
    mapping(uint256 => address) public ownerOf;
    address public immutable STORE_;

    constructor(address store) {
        STORE_ = store;
    }

    function STORE() external view returns (address) {
        return STORE_;
    }

    function setOwner(uint256 tokenId, address owner) external {
        ownerOf[tokenId] = owner;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] && from == ownerOf[tokenId], "auth");
        ownerOf[tokenId] = to;
        if (to.code.length > 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "")
                    == IERC721Receiver.onERC721Received.selector,
                "rejected"
            );
        }
    }

    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

contract ACMockStore {
    mapping(address => mapping(uint256 => JB721Tier)) internal _tiers;

    function setTier(address hook, uint256 tokenId, uint32 id, uint24 category) external {
        JB721Tier memory t;
        t.id = id;
        t.category = category;
        _tiers[hook][tokenId] = t;
    }

    function tierOfTokenId(address hook, uint256 tokenId, bool) external view returns (JB721Tier memory) {
        return _tiers[hook][tokenId];
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function encodedTierIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function encodedIpfsUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/// @notice Fuzz proofs for the access-control and lock-monotonicity postconditions of
/// `Banny721TokenUriResolver` that are too stateful for Halmos but per-call deterministic.
contract BannyResolverAccessControl is Test {
    Banny721TokenUriResolver internal resolver;
    ACMockHook internal hook;
    ACMockStore internal store;

    uint256 internal constant BODY = 1;

    function setUp() public {
        store = new ACMockStore();
        hook = new ACMockHook(address(store));
        resolver = new Banny721TokenUriResolver("<b/>", "<n/>", "<m/>", "<e/>", "<a/>", address(this), address(0));
        store.setTier(address(hook), BODY, 4, 0); // body tier
    }

    //*********************************************************************//
    // ----------------------- decorate authority ------------------------ //
    //*********************************************************************//

    /// @notice POST-DECORATE-AUTH: only the current ERC-721 owner of the body may decorate it. Any other caller
    /// reverts and no state changes (the body keeps its previous — here, empty — attachment set).
    function testFuzz_onlyBodyOwnerCanDecorate(address bodyOwner, address caller) public {
        vm.assume(bodyOwner != address(0) && caller != address(0));
        vm.assume(bodyOwner != caller);
        vm.assume(caller != address(resolver));

        hook.setOwner(BODY, bodyOwner);

        uint256[] memory empty = new uint256[](0);
        vm.prank(caller);
        vm.expectRevert(); // UnauthorizedBannyBody
        resolver.decorateBannyWith(address(hook), BODY, 0, empty);

        // No attachment recorded.
        (uint256 bg, uint256[] memory outfits) = resolver.assetIdsOf(address(hook), BODY);
        assertEq(bg, 0);
        assertEq(outfits.length, 0);
    }

    /// @notice POST-DECORATE-CATEGORY: decorating a token that is NOT a body-category tier reverts, even by its
    /// owner. Only category-0 tiers can be dressed.
    function testFuzz_cannotDecorateNonBody(address bodyOwner, uint24 category) public {
        vm.assume(bodyOwner != address(0) && bodyOwner != address(resolver));
        category = uint24(bound(category, 1, type(uint24).max)); // anything but body category 0.

        uint256 notBody = 99;
        store.setTier(address(hook), notBody, 7, category);
        hook.setOwner(notBody, bodyOwner);

        uint256[] memory empty = new uint256[](0);
        vm.prank(bodyOwner);
        vm.expectRevert(); // BannyBodyNotBodyCategory
        resolver.decorateBannyWith(address(hook), notBody, 0, empty);
    }

    //*********************************************************************//
    // ------------------------- lock authority -------------------------- //
    //*********************************************************************//

    /// @notice POST-LOCK-AUTH: only the body owner may lock; an unauthorized lock reverts and leaves the lock
    /// timestamp unchanged.
    function testFuzz_onlyOwnerCanLock(address bodyOwner, address caller) public {
        vm.assume(bodyOwner != address(0) && caller != address(0) && bodyOwner != caller);

        hook.setOwner(BODY, bodyOwner);
        uint256 before = resolver.outfitLockedUntil(address(hook), BODY);

        vm.prank(caller);
        vm.expectRevert(); // UnauthorizedBannyBody (ownership check in _checkIfSenderIsOwner)
        resolver.lockOutfitChangesFor(address(hook), BODY);

        assertEq(resolver.outfitLockedUntil(address(hook), BODY), before, "lock changed on failed auth");
    }

    /// @notice POST-LOCK-SET: a successful lock sets `outfitLockedUntil == block.timestamp + 7 days` exactly.
    function testFuzz_lockSetsSevenDays(address bodyOwner, uint256 warpTo) public {
        vm.assume(bodyOwner != address(0));
        warpTo = bound(warpTo, 1, 1e12);
        vm.warp(warpTo);

        hook.setOwner(BODY, bodyOwner);
        vm.prank(bodyOwner);
        resolver.lockOutfitChangesFor(address(hook), BODY);

        assertEq(resolver.outfitLockedUntil(address(hook), BODY), warpTo + 7 days, "lock not exactly +7d");
    }

    /// @notice POST-LOCK-MONOTONIC: a lock can never be shortened. Calling lock again before the prior lock has
    /// decayed below `now + 7 days` either keeps or extends the expiry; an attempt that would shorten reverts.
    /// Because the new candidate is always `now + 7 days`, re-locking right after a previous lock (no time passed)
    /// reverts `CantAccelerateTheLock` only if the existing lock is strictly greater — which it cannot be when no
    /// time passed, so it succeeds and stays equal. After time passes, it strictly extends.
    function testFuzz_lockMonotonic(address bodyOwner, uint256 startTime, uint256 gap) public {
        vm.assume(bodyOwner != address(0));
        startTime = bound(startTime, 1, 1e12);
        gap = bound(gap, 0, 30 days);

        hook.setOwner(BODY, bodyOwner);

        vm.warp(startTime);
        vm.prank(bodyOwner);
        resolver.lockOutfitChangesFor(address(hook), BODY);
        uint256 firstLock = resolver.outfitLockedUntil(address(hook), BODY);
        assertEq(firstLock, startTime + 7 days);

        vm.warp(startTime + gap);
        uint256 candidate = startTime + gap + 7 days;

        if (candidate < firstLock) {
            // Would shorten the lock -> must revert, lock unchanged.
            vm.prank(bodyOwner);
            vm.expectRevert();
            resolver.lockOutfitChangesFor(address(hook), BODY);
            assertEq(resolver.outfitLockedUntil(address(hook), BODY), firstLock, "lock shortened");
        } else {
            // Refresh/extend allowed; lock never decreases.
            vm.prank(bodyOwner);
            resolver.lockOutfitChangesFor(address(hook), BODY);
            uint256 newLock = resolver.outfitLockedUntil(address(hook), BODY);
            assertGe(newLock, firstLock, "lock decreased");
            assertEq(newLock, candidate, "lock not set to candidate");
        }
    }

    //*********************************************************************//
    // ---------------- onERC721Received push-rejection ------------------ //
    //*********************************************************************//

    /// @notice POST-RECEIVE: `onERC721Received` only accepts transfers whose operator is the resolver itself; any
    /// external push reverts.
    function testFuzz_onlySelfInitiatedReceive(address operator, address from, uint256 tokenId) public {
        vm.assume(operator != address(resolver));
        vm.expectRevert(); // UnauthorizedTransfer
        resolver.onERC721Received(operator, from, tokenId, "");
    }

    /// @notice The self-initiated branch returns the ERC-721 receiver selector.
    function testFuzz_selfInitiatedReceiveReturnsSelector(address from, uint256 tokenId, bytes calldata data) public {
        vm.prank(address(resolver));
        bytes4 ret = resolver.onERC721Received(address(resolver), from, tokenId, data);
        assertEq(ret, IERC721Receiver.onERC721Received.selector);
    }

    //*********************************************************************//
    // -------------- SVG hash / content pre-commit one-shot ------------- //
    //*********************************************************************//

    /// @notice POST-HASH-ONESHOT: only the owner can set a hash; once set for a UPC it cannot be rotated.
    function testFuzz_svgHashOneShot(uint256 upc, bytes32 h1, bytes32 h2, address stranger) public {
        vm.assume(h1 != bytes32(0) && h2 != bytes32(0));
        vm.assume(stranger != address(this)); // address(this) is the owner.

        uint256[] memory upcs = new uint256[](1);
        upcs[0] = upc;
        bytes32[] memory hs = new bytes32[](1);
        hs[0] = h1;

        // Non-owner cannot set.
        vm.prank(stranger);
        vm.expectRevert();
        resolver.setSvgHashesOf(upcs, hs);

        // Owner sets it.
        resolver.setSvgHashesOf(upcs, hs);
        assertEq(resolver.svgHashOf(upc), h1);

        // Cannot rotate — even by owner.
        hs[0] = h2;
        vm.expectRevert();
        resolver.setSvgHashesOf(upcs, hs);
        assertEq(resolver.svgHashOf(upc), h1, "hash rotated");
    }

    /// @notice POST-CONTENT-COMMITMENT: `setSvgContentsOf` is permissionless but the published bytes must match the
    /// owner-precommitted hash, and content is one-shot. Mismatched bytes revert; matching bytes publish exactly once.
    function testFuzz_svgContentMatchesHashAndOneShot(
        uint256 upc,
        bytes calldata goodContent,
        bytes calldata badContent
    )
        public
    {
        // Non-empty content so the one-shot re-publish guard (`length != 0`) is exercised.
        vm.assume(goodContent.length != 0);
        bytes32 hash = keccak256(abi.encodePacked(goodContent));
        vm.assume(hash != bytes32(0));
        vm.assume(keccak256(abi.encodePacked(badContent)) != hash);

        // Owner pre-commits the hash.
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = upc;
        bytes32[] memory hs = new bytes32[](1);
        hs[0] = hash;
        resolver.setSvgHashesOf(upcs, hs);

        // Wrong bytes revert (ContentsMismatch).
        string[] memory bad = new string[](1);
        bad[0] = string(badContent);
        vm.expectRevert();
        resolver.setSvgContentsOf(upcs, bad);

        // Correct bytes succeed (permissionless: call as a random publisher).
        string[] memory good = new string[](1);
        good[0] = string(goodContent);
        vm.prank(address(0xBEEF));
        resolver.setSvgContentsOf(upcs, good);

        // Re-publishing is rejected (ContentsAlreadyStored).
        vm.expectRevert();
        resolver.setSvgContentsOf(upcs, good);
    }

    /// @notice POST-CONTENT-NOHASH: publishing content for a UPC with no pre-committed hash reverts (HashNotFound).
    function testFuzz_svgContentRequiresHash(uint256 upc, bytes calldata content) public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = upc;
        string[] memory c = new string[](1);
        c[0] = string(content);
        vm.expectRevert();
        resolver.setSvgContentsOf(upcs, c);
    }
}
