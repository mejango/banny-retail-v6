# Banny Retail

## Purpose

On-chain composable NFT avatar system that renders Banny characters with layered SVG outfits and backgrounds for Juicebox 721 collections. Bodies can be dressed, locked, and rendered entirely on-chain.

## Contracts

| Contract | Role |
|----------|------|
| `Banny721TokenUriResolver` | Resolves token URIs for any Juicebox 721 hook by composing layered SVGs from registered asset content. Manages outfit attachment, background assignment, outfit locking, on-chain SVG storage, and metadata generation. Inherits `Ownable`, `ReentrancyGuard`, `ERC2771Context`, `IERC721Receiver`. (~1,331 lines) |

## Key Functions

### Token URI & Rendering

| Function | What it does |
|----------|-------------|
| `tokenUriOf(hook, tokenId)` | Returns base64-encoded JSON metadata URI with on-chain SVG image. For bodies: composes dressed Banny with attached outfits and background. For outfit/background tokens: renders the item on a grayscale mannequin Banny. |
| `svgOf(hook, tokenId, shouldDressBannyBody, shouldIncludeBackgroundOnBannyBody)` | Returns the composed SVG string. Layers (in order): background, backside, body, necklace, eyes, mouth, outfits by category. Falls back to IPFS base URI if on-chain content not stored. |

### Decoration

| Function | What it does |
|----------|-------------|
| `decorateBannyWith(hook, bannyBodyId, backgroundId, outfitIds)` | Attaches background and outfits to a body. Transfers assets to contract custody. Validates ownership, lock status, category ordering, slot conflicts. Returns previously attached items to caller. Emits `DecorateBanny`. |
| `lockOutfitChangesFor(hook, bannyBodyId)` | Locks a body's outfit for 7 days. Cannot accelerate an existing lock. Caller must own the body NFT. |

### Views

| Function | What it does |
|----------|-------------|
| `assetIdsOf(hook, bannyBodyId)` | Returns `(backgroundId, outfitIds[])` currently attached to body. Filters out stale entries where `_wearerOf` no longer matches. |
| `namesOf(hook, tokenId)` | Returns `(fullName, categoryName, productName)`. Full name includes inventory count (e.g., "42/100"). |
| `userOf(hook, backgroundId)` | Returns the body ID using a background, or 0 if unused. Validates consistency. |
| `wearerOf(hook, outfitId)` | Returns the body ID wearing an outfit, or 0 if unworn. Validates outfit is in body's attached array. |

### SVG Content Management

| Function | Who | What it does |
|----------|-----|-------------|
| `setSvgHashesOf(upcs, svgHashes)` | Owner only | Registers expected SVG content hashes for UPCs. Immutable once set. |
| `setSvgContentsOf(upcs, svgContents)` | **Anyone** | Stores on-chain SVG content. Must match previously registered hash. Cannot overwrite existing content. |
| `setProductNames(upcs, names)` | Owner only | Sets human-readable names for product UPCs. |
| `setMetadata(description, url, baseUri)` | Owner only | Updates token metadata description, external URL, and SVG base URI. Skips empty strings. |

### Token Receipt

| Function | What it does |
|----------|-------------|
| `onERC721Received(operator, from, tokenId, data)` | Validates token receipt. Reverts unless `operator == address(this)`. Called when contract takes custody of outfits/backgrounds during decoration. |

## Integration Points

| Dependency | Import | Used For |
|------------|--------|----------|
| `@bananapus/721-hook-v6` | `IJB721TiersHook`, `IJB721TiersHookStore`, `IJB721TokenUriResolver`, `JB721Tier`, `JBIpfsDecoder`, `IERC721` | Token ownership checks, tier/product data resolution, IPFS URI decoding, hook store queries, safe transfers |
| `@openzeppelin/contracts` | `Ownable`, `ReentrancyGuard`, `ERC2771Context`, `IERC721Receiver`, `Strings` | Access control, reentrancy protection, meta-transactions, safe NFT receipt, string utilities |
| `lib/base64` | `Base64` | Base64 encoding for on-chain SVG and JSON metadata |

## Key Types

### Asset Categories

| ID | Name | Slot Rules |
|----|------|------------|
| 0 | Body | Base character. Owns outfits and backgrounds. |
| 1 | Background | One per body. |
| 2 | Backside | Behind body layer. |
| 3 | Necklace | Default provided if none attached. |
| 4 | Head | Blocks eyes, glasses, mouth, headtop. |
| 5 | Eyes | Defaults: alien eyes (UPC 1) or standard eyes (UPC 2-4). |
| 6 | Glasses | Blocked by head. |
| 7 | Mouth | Default provided. Blocked by head. |
| 8 | Legs | Lower body clothing. |
| 9 | Suit | Full one-piece. Blocks suit top and suit bottom. |
| 10 | Suit Bottom | Blocked by full suit. |
| 11 | Suit Top | Blocked by full suit. |
| 12 | Headtop | Blocked by head. |
| 13 | Hand | Held item. |
| 14-17 | Special | Special suit, legs, head, body overlays. |

### Body Types (by UPC)

| UPC | Type | Default Eyes |
|-----|------|-------------|
| 1 | Alien | `DEFAULT_ALIEN_EYES` (purple) |
| 2 | Pink | `DEFAULT_STANDARD_EYES` |
| 3 | Orange | `DEFAULT_STANDARD_EYES` |
| 4 | Original | `DEFAULT_STANDARD_EYES` |

## Events

| Event | When |
|-------|------|
| `DecorateBanny(hook, bannyBodyId, backgroundId, outfitIds, caller)` | Body decorated with new outfits/background |
| `SetMetadata(description, externalUrl, baseUri, caller)` | Metadata updated |
| `SetProductName(upc, name, caller)` | Product name set |
| `SetSvgContent(upc, svgContent, caller)` | SVG content stored on-chain |
| `SetSvgHash(upc, svgHash, caller)` | SVG hash registered |

## Errors

| Error | When |
|-------|------|
| `Banny721TokenUriResolver_CantAccelerateTheLock` | Trying to lock a body that's already locked for longer |
| `Banny721TokenUriResolver_ContentsAlreadyStored` | SVG content already exists for this UPC |
| `Banny721TokenUriResolver_ContentsMismatch` | Uploaded content doesn't match registered hash |
| `Banny721TokenUriResolver_HashAlreadyStored` | Hash already registered for this UPC |
| `Banny721TokenUriResolver_HashNotFound` | No hash registered for UPC (must register before uploading content) |
| `Banny721TokenUriResolver_HeadAlreadyAdded` | Trying to add eyes/glasses/mouth/headtop when head is already attached |
| `Banny721TokenUriResolver_OutfitChangesLocked` | Body is locked (7-day lock active) |
| `Banny721TokenUriResolver_SuitAlreadyAdded` | Trying to add suit top/bottom when full suit is already attached |
| `Banny721TokenUriResolver_UnauthorizedBannyBody` | Caller doesn't own the body |
| `Banny721TokenUriResolver_UnauthorizedOutfit` | Caller doesn't own the outfit or the body wearing it |
| `Banny721TokenUriResolver_UnauthorizedBackground` | Caller doesn't own the background or the body using it |
| `Banny721TokenUriResolver_UnorderedCategories` | Outfit IDs not in ascending category order |
| `Banny721TokenUriResolver_UnrecognizedCategory` | Category ID not in valid range (0-17) |
| `Banny721TokenUriResolver_UnrecognizedBackground` | Token is not a background category |
| `Banny721TokenUriResolver_UnrecognizedProduct` | Token's UPC doesn't map to a known product |
| `Banny721TokenUriResolver_UnauthorizedTransfer` | `onERC721Received` called by non-self operator |

## Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `_LOCK_DURATION` | 7 days | Fixed outfit lock period |
| `_ONE_BILLION` | 1,000,000,000 | Token ID encoding: `tokenId = upc * 1B + sequenceNumber` |
| `_BODY_CATEGORY` | 0 | Category ID for base Banny body |
| `_BACKGROUND_CATEGORY` | 1 | Category ID for backgrounds |
| Categories 2-17 | 2-17 | Backside, necklace, head, eyes, glasses, mouth, legs, suit, suit bottom, suit top, headtop, hand, specials |

## Storage

| Mapping | Type | Purpose |
|---------|------|---------|
| `_attachedOutfitIdsOf` | `hook => bannyBodyId => uint256[]` | Outfit token IDs attached to a body |
| `_attachedBackgroundIdOf` | `hook => bannyBodyId => uint256` | Background token ID attached to a body |
| `_svgContentOf` | `upc => string` | On-chain SVG content (immutable once set) |
| `svgHashOf` | `upc => bytes32` | Expected SVG content hash (immutable once set) |
| `_customProductNameOf` | `upc => string` | Human-readable product name |
| `outfitLockedUntil` | `hook => upc => uint256` | Timestamp until outfit changes locked |
| `_userOf` | `hook => backgroundId => uint256` | Which body uses a background |
| `_wearerOf` | `hook => outfitId => uint256` | Which body wears an outfit |
| `svgBaseUri` | `string` | IPFS/HTTP base URI for fallback SVG loading |
| `svgDescription` | `string` | Token metadata description |
| `svgExternalUrl` | `string` | Token metadata external URL |

## Gotchas

1. **7-day lock is fixed and non-cancellable.** `lockOutfitChangesFor` always sets `outfitLockedUntil = block.timestamp + 7 days`. Cannot be shortened, cancelled, or accelerated. Only extended.
2. **SVG content is immutable.** Once `setSvgContentsOf` stores content for a UPC, it cannot be changed. A mistake requires deploying a new resolver.
3. **SVG hashes are also immutable.** `setSvgHashesOf` reverts if a hash already exists for a UPC. Register carefully.
4. **Hash registration is owner-only, but content upload is permissionless.** Anyone can call `setSvgContentsOf` as long as the content matches the registered hash. This enables community-driven lazy uploads.
5. **Strict ascending category order.** `decorateBannyWith` requires outfits passed in ascending category order. Reverts with `UnorderedCategories` if violated.
6. **Slot conflicts block combinations.** Head (4) blocks eyes (5), glasses (6), mouth (7), and headtop (12). Full suit (9) blocks suit top (11) and suit bottom (10). These are enforced at decoration time.
7. **Default injection.** If no explicit necklace, eyes, or mouth outfit is attached, the resolver auto-injects defaults during SVG rendering. Alien bodies get `DEFAULT_ALIEN_EYES`; others get `DEFAULT_STANDARD_EYES`.
8. **Outfits are held in contract custody.** Attached outfits and backgrounds are transferred to `address(this)` via `safeTransferFrom`. They are returned to the caller when detached (by passing a new outfit set that excludes them).
9. **Complex outfit ownership rules.** If an outfit is unworn: only its owner can attach it. If already worn by another body: the caller must own THAT body to reassign the outfit. This allows body owners to swap outfits between their own bodies.
10. **Token ID encoding.** `tokenId = upc * 1_000_000_000 + sequenceNumber`. The resolver extracts UPC via integer division and sequence via modulo to display inventory counts like "42/100".
11. **`onERC721Received` only accepts self-transfers.** Reverts unless `operator == address(this)`. The contract calls `safeTransferFrom` on itself during decoration, triggering this callback.
12. **Via-IR required.** `foundry.toml` must have `via_ir = true` due to stack-too-deep in the SVG composition logic.
13. **SVG fallback chain.** If on-chain content exists: use it. Else if category <= 17: fall back to `svgBaseUri + IPFS URI`. Else: use the hook's `baseURI() + IPFS URI`.
14. **Mannequin rendering.** Outfit and background tokens (not bodies) are rendered on a grayscale mannequin Banny for preview purposes. The mannequin has `fill:#808080` styling.
15. **ERC2771 meta-transaction support.** Constructor takes a `trustedForwarder` address. All `_msgSender()` calls use `ERC2771Context`, allowing relayers to submit decoration transactions on behalf of users.
16. **Empty metadata fields skipped.** `setMetadata` only updates fields where non-empty strings are passed. Allows partial metadata updates without overwriting existing values.

## Example Integration

```solidity
import {IBanny721TokenUriResolver} from "@bannynet/core-v6/src/interfaces/IBanny721TokenUriResolver.sol";

// --- Get the composed SVG for a dressed Banny ---

string memory svg = resolver.svgOf(
    hookAddress,
    bannyBodyTokenId,
    true,  // dress the banny with attached outfits
    true   // include the attached background
);

// --- Dress a Banny body with outfits ---

uint256[] memory outfitIds = new uint256[](2);
outfitIds[0] = hatTokenId;   // must be category 4 (head)
outfitIds[1] = shirtTokenId; // must be category 11 (suit top)

// Caller must own the body, background, and all outfits on the same hook
resolver.decorateBannyWith(
    hookAddress,
    bannyBodyTokenId,
    backgroundTokenId,
    outfitIds  // MUST be in ascending category order
);

// --- Lock outfit changes for 7 days ---

resolver.lockOutfitChangesFor(hookAddress, bannyBodyTokenId);

// --- Register and upload SVG content ---

// Step 1: Owner registers content hashes
uint256[] memory upcs = new uint256[](1);
upcs[0] = 42;
bytes32[] memory hashes = new bytes32[](1);
hashes[0] = keccak256(bytes(svgContent));
resolver.setSvgHashesOf(upcs, hashes);

// Step 2: Anyone uploads matching content
string[] memory contents = new string[](1);
contents[0] = svgContent;
resolver.setSvgContentsOf(upcs, contents);
```
