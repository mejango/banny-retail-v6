# banny-retail-v6 — Architecture

## Purpose

Banny NFT asset manager for Juicebox V6. Stores on-chain SVG artwork for Banny characters and generates fully on-chain token URI metadata. Supports outfit composition (bodies, backgrounds, heads, suits) with lockable outfit changes.

## Contract Map

```
src/
├── Banny721TokenUriResolver.sol — Token URI resolver: SVG generation, outfit management, asset storage
└── interfaces/
    └── IBanny721TokenUriResolver.sol — Interface for outfit and asset operations
```

## UPC System

A UPC (Universal Product Code) is the tier ID from the 721 hook's tier system, used as the primary identifier for every asset type (bodies, backgrounds, outfits). Each tier in the `IJB721TiersHook` has an `id` and a `category` -- the UPC is that `id`.

- **Bodies** (category 0) have hardcoded UPCs with built-in color palettes: Alien (1), Pink (2), Orange (3), Original (4).
- **Outfits and backgrounds** use arbitrary UPCs assigned when their tiers are created in the 721 hook. Their SVG content is stored on-chain via the hash-then-upload flow described below.
- **Token IDs** encode the UPC: `tokenId = UPC * 1_000_000_000 + mintNumber`. The resolver recovers the tier (and thus UPC and category) via `tierOfTokenId` from the hook's store.

All asset storage, outfit attachment, and SVG generation are keyed by UPC.

## Key Operations

### Asset Storage
```
Owner → setSvgHashesOf(upcs, hashes)
  → Register content hashes for UPCs (owner-only)

Anyone → setSvgContentsOf(upcs, contents)
  → Upload SVG content matching registered hashes
  → Content validated: keccak256(content) must equal stored hash
  → Content is immutable once stored (cannot be overwritten)

Owner → setProductNames(upcs, names)
  → Register product names for UPCs
```

### Outfit Composition
```
Body Owner → decorateBannyWith(hook, bodyId, backgroundId, outfitIds)
  → Attach outfit and background NFTs to a body NFT
  → Outfit/background NFTs transferred to resolver contract
  → Previous outfits returned to owner (if transfer fails, retained in attached list)
  → Composite SVG generated from layered components

Body Owner → lockOutfitChangesFor(hook, bodyId)
  → Lock outfit changes for 7 days
```

### Token URI Generation
```
JB721TiersHook → tokenURI(tokenId)
  → Banny721TokenUriResolver.tokenURI(hook, tokenId)
    → Look up body tier and any attached outfits
    → Compose SVG layers in fixed z-order (back to front):
        1. Background (if attached)
        2. Body (with color palette fills from UPC)
        3. Outfits in category order:
           Backside(2) → Necklace(3)* → Head(4) → Eyes(5)† →
           Glasses(6) → Mouth(7)† → Legs(8) → Suit(9) →
           Suit Bottom(10) → Suit Top(11) → Necklace‡ →
           Headtop(12) → Hand(13) → Special categories(14-17)
           (* = default necklace inserted if no custom equipped)
           († = default inserted if no custom equipped and no full Head)
           (‡ = custom necklace rendered here, above suit layers)
    → Wrap in <svg> container (400x400 viewBox)
    → Encode as base64 data URI with JSON metadata
    → Return fully on-chain SVG
```

Non-body tokens are shown on a grey mannequin Banny (body fills set to `none`, outline to `#808080`).

For IPFS-backed assets without on-chain SVG content, the resolver falls back to an `<image href="...">` tag referencing the tier's encoded IPFS URI at 400x400 pixels.

## Dependencies
- `@bananapus/721-hook-v6` — NFT tier system (IJB721TiersHook, IJB721TokenUriResolver)
- `@bananapus/core-v6` — Core protocol interfaces
- `@bananapus/router-terminal-v6` — Payment routing
- `@bananapus/suckers-v6` — Cross-chain support
- `@rev-net/core-v6` — Revnet integration
- `@openzeppelin/contracts` — Ownable, ERC2771, ReentrancyGuard, Strings
- `keccak` — Hashing utilities

## Design Decisions

**Hash-then-upload for SVG storage.** The owner registers a keccak256 hash first (`setSvgHashesOf`, owner-only), then anyone can upload the matching content (`setSvgContentsOf`, permissionless). This separates content approval from upload gas costs -- the owner commits to exactly which artwork is valid, and community members or bots can pay the gas to actually store it. Both hash and content are immutable once set, preventing artwork tampering after mint.

**7-day outfit lock.** `lockOutfitChangesFor` freezes a body's outfit for 7 days (`_LOCK_DURATION`). This exists so that a dressed Banny can be used as a stable visual identity (e.g. a PFP or on-chain avatar) without risk of the outfit changing underneath external references. The lock can be extended but never shortened -- calling it again resets the timer to 7 days from now, and reverts if the existing lock expires later than the new one would.

**UPC as tier ID.** Rather than introducing a separate asset registry, the resolver reuses the 721 hook's tier ID as the universal product code. This means asset identity, pricing, supply caps, and category are all managed by the existing tier system with no additional storage. The resolver is purely a read/compose layer on top of the hook's data.

**Fixed category ordering for outfit layering.** Outfits must be passed in ascending category order (2-17) and only one outfit per category is allowed. This constraint eliminates ambiguity in SVG z-ordering -- the category number directly determines the layer position. It also enables the resolver to insert default accessories (necklace, eyes, mouth) at the correct z-position when no custom one is equipped and no full-head item occludes them.

**Equipped assets travel with the body.** When a body NFT is transferred, all equipped outfits and backgrounds remain attached. The new owner inherits them and can unequip to receive the outfit NFTs. This was chosen over auto-unequip to preserve the dressed Banny as a complete visual unit, but it means sellers should unequip valuable outfits before listing.

**Outfits burn with the body.** When a body NFT is burned, equipped outfits and backgrounds held by the resolver become permanently unrecoverable. There is no recovery function — outfits share the body's fate. Users must unequip outfits before burning the body if they want to keep them.
