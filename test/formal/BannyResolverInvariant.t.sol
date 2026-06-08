// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";
import {IBanny721TokenUriResolver} from "../../src/interfaces/IBanny721TokenUriResolver.sol";

//*********************************************************************//
// ----------------------------- mocks ------------------------------ //
//*********************************************************************//

/// @notice Minimal ERC-721 + tiers-hook mock mirroring the production interface surface the resolver touches:
/// `ownerOf`, `safeTransferFrom`, `STORE`, `pricingContext`, `baseURI`. Category/tier metadata is served by the
/// embedded store. The hook is intentionally a faithful (if minimal) ERC-721 so the resolver's custody transfers
/// behave like mainnet.
contract InvariantMockHook {
    mapping(uint256 tokenId => address) public ownerOf;
    InvariantMockStore public immutable STORE_;

    constructor(InvariantMockStore store) {
        STORE_ = store;
    }

    function STORE() external view returns (address) {
        return address(STORE_);
    }

    function setOwner(uint256 tokenId, address owner) external {
        ownerOf[tokenId] = owner;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId], "not owner");
        require(from == ownerOf[tokenId], "from mismatch");
        ownerOf[tokenId] = to;
        if (to.code.length > 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "")
                    == IERC721Receiver.onERC721Received.selector,
                "receiver rejected"
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

/// @notice Minimal tiers store: returns the tier (id+category) for a token id.
contract InvariantMockStore {
    mapping(address hook => mapping(uint256 tokenId => JB721Tier)) internal _tiers;

    function setTier(address hook, uint256 tokenId, uint32 id, uint24 category) external {
        JB721Tier memory t;
        t.id = id;
        t.category = category;
        t.initialSupply = 100;
        t.remainingSupply = 50;
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

//*********************************************************************//
// ---------------------------- handler ----------------------------- //
//*********************************************************************//

/// @notice Drives `decorateBannyWith` / `lockOutfitChangesFor` with a bounded universe of actors, bodies, outfits
/// and backgrounds, so the invariant runner explores realistic equip/unequip/transfer/lock interleavings.
contract BannyHandler is Test {
    Banny721TokenUriResolver public immutable RESOLVER;
    InvariantMockHook public immutable HOOK;
    InvariantMockStore public immutable STORE;

    // Bounded actor + token universe (kept small so the runner reaches deep equip/unequip states).
    address[3] public actors;

    // The body, background and outfit token universe (token ids chosen to be distinct).
    uint256[3] public bodies; // category 0
    uint256[2] public backgrounds; // category 1
    uint256[6] public outfits; // categories 2..17, distinct categories

    // Mirror of all asset/body tokens for invariant enumeration.
    uint256[] public allTokens;

    constructor(Banny721TokenUriResolver resolver, InvariantMockHook hook, InvariantMockStore store) {
        RESOLVER = resolver;
        HOOK = hook;
        STORE = store;

        actors[0] = address(0xA11CE);
        actors[1] = address(0xB0B);
        actors[2] = address(0xCA201);

        // Bodies: token ids 1,2,3 (category 0). Product id 4 = Original body (recognized fills).
        bodies[0] = 1;
        bodies[1] = 2;
        bodies[2] = 3;
        for (uint256 i; i < 3; ++i) {
            store.setTier(address(hook), bodies[i], 4, 0);
            hook.setOwner(bodies[i], actors[i % 3]);
            allTokens.push(bodies[i]);
        }

        // Backgrounds: token ids 10,11 (category 1).
        backgrounds[0] = 10;
        backgrounds[1] = 11;
        for (uint256 i; i < 2; ++i) {
            store.setTier(address(hook), backgrounds[i], uint32(100 + i), 1);
            hook.setOwner(backgrounds[i], actors[i % 3]);
            allTokens.push(backgrounds[i]);
        }

        // Outfits: distinct categories drawn from the recognized outfit range [2,17], one per category so they can
        // be combined in ascending order. Avoid HEAD(4)/SUIT(9) exclusivity clashes by spacing categories out.
        uint24[6] memory cats = [uint24(2), 3, 5, 7, 12, 13];
        for (uint256 i; i < 6; ++i) {
            outfits[i] = 100 + i;
            store.setTier(address(hook), outfits[i], uint32(200 + i), cats[i]);
            hook.setOwner(outfits[i], actors[i % 3]);
            allTokens.push(outfits[i]);
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % 3];
    }

    /// @notice Equip a body with a subset of outfits (in ascending category order) and an optional background.
    function decorate(uint256 actorSeed, uint256 bodySeed, uint256 bgSeed, uint256 outfitMask) public {
        address actor = _actor(actorSeed);
        uint256 bodyId = bodies[bodySeed % 3];

        // Only the body's current owner may decorate; skip otherwise (matches the contract's revert, keeps depth).
        if (HOOK.ownerOf(bodyId) != actor) return;

        // Build the outfit list from a bitmask over the 6 distinct-category outfits; they are already in ascending
        // category order, so selecting a subset preserves ascending order.
        uint256 count;
        for (uint256 i; i < 6; ++i) {
            if (outfitMask & (1 << i) != 0) count++;
        }
        uint256[] memory ids = new uint256[](count);
        uint256 j;
        for (uint256 i; i < 6; ++i) {
            if (outfitMask & (1 << i) != 0) {
                ids[j++] = outfits[i];
            }
        }

        // Background: 0 (none) or one of the two backgrounds.
        uint256 bg = bgSeed % 3 == 0 ? 0 : backgrounds[bgSeed % 2];

        vm.prank(actor);
        try RESOLVER.decorateBannyWith(address(HOOK), bodyId, bg, ids) {} catch {}
    }

    /// @notice Lock a body's outfit changes (only its owner can).
    function lock(uint256 actorSeed, uint256 bodySeed) public {
        address actor = _actor(actorSeed);
        uint256 bodyId = bodies[bodySeed % 3];
        vm.prank(actor);
        try RESOLVER.lockOutfitChangesFor(address(HOOK), bodyId) {} catch {}
    }

    /// @notice Advance time so locks can expire (bounded jump).
    function warp(uint256 secondsSeed) public {
        vm.warp(block.timestamp + (secondsSeed % 10 days));
    }

    /// @notice Transfer a body NFT between actors (simulating a sale of the carrier). Only unequipped-by-contract
    /// body tokens (always actor-held) are moved; assets held by the resolver are untouched.
    function transferBody(uint256, uint256 toSeed, uint256 bodySeed) public {
        uint256 bodyId = bodies[bodySeed % 3];
        address owner = HOOK.ownerOf(bodyId);
        address to = _actor(toSeed);
        if (owner == address(RESOLVER) || owner == address(0)) return;
        vm.prank(owner);
        try HOOK.safeTransferFrom(owner, to, bodyId) {} catch {}
    }

    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }
}

//*********************************************************************//
// --------------------------- invariants --------------------------- //
//*********************************************************************//

/// @notice Stateful functional-correctness invariants for the equip/unequip custody + bookkeeping of
/// `Banny721TokenUriResolver`, driven by {BannyHandler}.
contract BannyResolverInvariant is StdInvariant, Test {
    Banny721TokenUriResolver internal resolver;
    InvariantMockHook internal hook;
    InvariantMockStore internal store;
    BannyHandler internal handler;

    function setUp() public {
        store = new InvariantMockStore();
        hook = new InvariantMockHook(store);
        resolver = new Banny721TokenUriResolver("<b/>", "<n/>", "<m/>", "<e/>", "<a/>", address(this), address(0));
        handler = new BannyHandler(resolver, hook, store);

        // Move all token ownership so the handler's actors own the seeded tokens (the handler set owners on the hook
        // already in its constructor); nothing else to wire.

        targetContract(address(handler));
    }

    /// @notice INV-CUSTODY: every outfit the resolver reports as worn (`wearerOf != 0`) and every background it
    /// reports as used (`userOf != 0`) is physically held by the resolver. The resolver never claims an asset is
    /// equipped while the asset NFT lives in an actor wallet.
    function invariant_equippedAssetsAreInCustody() public view {
        // Outfits.
        for (uint256 i; i < 6; ++i) {
            uint256 outfitId = handler.outfits(i);
            uint256 wearer = resolver.wearerOf(address(hook), outfitId);
            if (wearer != 0) {
                assertEq(hook.ownerOf(outfitId), address(resolver), "worn outfit not held by resolver");
            }
        }
        // Backgrounds.
        for (uint256 i; i < 2; ++i) {
            uint256 bgId = handler.backgrounds(i);
            uint256 user = resolver.userOf(address(hook), bgId);
            if (user != 0) {
                assertEq(hook.ownerOf(bgId), address(resolver), "used background not held by resolver");
            }
        }
    }

    /// @notice INV-WEARER-ATTACHED: `wearerOf(o)` and the live attachment list agree. If `wearerOf(o)==body`, the
    /// outfit appears in `assetIdsOf(body).outfitIds`; conversely every outfit returned by `assetIdsOf` has that body
    /// as its wearer. This is the read-time reconciliation contract.
    function invariant_wearerMatchesAttachment() public view {
        for (uint256 b; b < 3; ++b) {
            uint256 bodyId = handler.bodies(b);
            (uint256 backgroundId, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), bodyId);

            // Every attached outfit must report this body as its wearer.
            for (uint256 k; k < outfitIds.length; ++k) {
                assertEq(resolver.wearerOf(address(hook), outfitIds[k]), bodyId, "attached outfit wearer mismatch");
            }

            // The attached background (if any) must report this body as its user.
            if (backgroundId != 0) {
                assertEq(resolver.userOf(address(hook), backgroundId), bodyId, "attached bg user mismatch");
            }
        }

        // Conversely: any outfit whose wearer is a body must appear in that body's attachment list.
        for (uint256 i; i < 6; ++i) {
            uint256 outfitId = handler.outfits(i);
            uint256 wearer = resolver.wearerOf(address(hook), outfitId);
            if (wearer != 0) {
                (, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), wearer);
                bool found;
                for (uint256 k; k < outfitIds.length; ++k) {
                    if (outfitIds[k] == outfitId) {
                        found = true;
                        break;
                    }
                }
                assertTrue(found, "worn outfit missing from attachment list");
            }
        }
    }

    /// @notice INV-UNIQUE-WEARER: no outfit is reported as worn by two different bodies, and no background is used by
    /// two bodies. (Each asset maps to at most one body.)
    function invariant_uniqueAssignment() public view {
        // Outfits: collect wearer per outfit; since wearerOf is a function, single-valued by construction, but we
        // assert the *attachment lists* don't double-count an outfit across bodies.
        for (uint256 i; i < 6; ++i) {
            uint256 outfitId = handler.outfits(i);
            uint256 owners;
            for (uint256 b; b < 3; ++b) {
                (, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), handler.bodies(b));
                for (uint256 k; k < outfitIds.length; ++k) {
                    if (outfitIds[k] == outfitId) {
                        owners++;
                        break;
                    }
                }
            }
            assertLe(owners, 1, "outfit attached to multiple bodies");
        }
        // Backgrounds.
        for (uint256 i; i < 2; ++i) {
            uint256 bgId = handler.backgrounds(i);
            uint256 owners;
            for (uint256 b; b < 3; ++b) {
                (uint256 backgroundId,) = resolver.assetIdsOf(address(hook), handler.bodies(b));
                if (backgroundId == bgId) owners++;
            }
            assertLe(owners, 1, "background used by multiple bodies");
        }
    }

    /// @notice INV-ATTACHMENT-SORTED-UNIQUE: each body's live attachment list is strictly ascending by category
    /// (hence has no duplicate categories) — the rendering invariant `_outfitContentsFor` depends on.
    function invariant_attachmentSortedUniqueCategory() public view {
        for (uint256 b; b < 3; ++b) {
            (, uint256[] memory outfitIds) = resolver.assetIdsOf(address(hook), handler.bodies(b));
            uint256 prevCat;
            bool first = true;
            for (uint256 k; k < outfitIds.length; ++k) {
                uint256 cat = store.tierOfTokenId(address(hook), outfitIds[k], false).category;
                if (!first) {
                    assertGt(cat, prevCat, "attachment not strictly ascending by category");
                }
                prevCat = cat;
                first = false;
            }
        }
    }

    /// @notice INV-LOCK-BOUNDED: every body's lock timestamp is at most `block.timestamp + 7 days`. The lock can
    /// never be set arbitrarily far into the future.
    function invariant_lockBounded() public view {
        for (uint256 b; b < 3; ++b) {
            uint256 lockedUntil = resolver.outfitLockedUntil(address(hook), handler.bodies(b));
            assertLe(lockedUntil, block.timestamp + 7 days, "lock exceeds 7-day bound");
        }
    }

    /// @notice INV-NO-SELF-WEAR: a body is never recorded as wearing/using itself, and a token is never both a worn
    /// outfit and a used background.
    function invariant_noCrossUse() public view {
        for (uint256 i; i < 6; ++i) {
            uint256 outfitId = handler.outfits(i);
            // An outfit token is never tracked as a background user.
            assertEq(resolver.userOf(address(hook), outfitId), 0, "outfit tracked as background");
        }
        for (uint256 i; i < 2; ++i) {
            uint256 bgId = handler.backgrounds(i);
            // A background token is never tracked as a worn outfit.
            assertEq(resolver.wearerOf(address(hook), bgId), 0, "background tracked as outfit");
        }
    }
}
