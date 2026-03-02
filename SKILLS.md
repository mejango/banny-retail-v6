# banny-retail-v5

## Purpose

On-chain composable NFT avatar system that renders Banny characters with layered SVG outfits and backgrounds for Juicebox 721 collections.

## Contracts

| Contract | Role |
|----------|------|
| `Banny721TokenUriResolver` | Resolves token URIs for any Juicebox 721 hook by composing layered SVGs from registered asset content. Manages outfit attachment, background assignment, outfit locking, and on-chain SVG storage. |

## Key Functions

| Function | Contract | What it does |
|----------|----------|--------------|
| `tokenUriOf` | `Banny721TokenUriResolver` | Returns a base64-encoded JSON metadata URI with an on-chain SVG image. For body tokens, composes the full dressed Banny with attached outfits and background. For outfit/background tokens, renders the item on a mannequin Banny. |
| `decorateBannyWith` | `Banny721TokenUriResolver` | Attaches a background and outfit NFTs to a Banny body. Validates ownership (caller must own the body, background, and all outfits via the same 721 hook). Enforces category ordering and uniqueness (one head, one suit, etc.). Detaches previously worn items. |
| `lockOutfitChangesFor` | `Banny721TokenUriResolver` | Locks a Banny body's outfit for 7 days. Cannot accelerate an existing lock. Caller must own the body NFT. |
| `svgOf` | `Banny721TokenUriResolver` | Returns the composed SVG for a token. For bodies, layers: background + backside + body + necklace + eyes + mouth + outfits (in category order). Falls back to SVG base URI + hash if on-chain content is not stored. |
| `assetIdsOf` | `Banny721TokenUriResolver` | Returns the background ID and outfit IDs currently attached to a Banny body. |
| `namesOf` | `Banny721TokenUriResolver` | Returns the product name, category name, and Banny type (Alien/Pink/Orange/Original) for a token. |
| `setSvgContentsOf` | `Banny721TokenUriResolver` | Owner-only. Stores SVG content strings on-chain for given UPCs. Content must match the previously registered hash. Cannot overwrite existing content. |
| `setSvgHashsOf` | `Banny721TokenUriResolver` | Owner-only. Registers SVG content hashes for UPCs. Hash cannot be changed once set. |
| `setProductNames` | `Banny721TokenUriResolver` | Owner-only. Sets human-readable names for product UPCs. |
| `setSvgBaseUri` | `Banny721TokenUriResolver` | Owner-only. Sets the base URI for lazily-loaded SVG files (used when on-chain content is not yet stored). |
| `userOf` | `Banny721TokenUriResolver` | Returns the Banny body ID that a background is attached to. |
| `wearerOf` | `Banny721TokenUriResolver` | Returns the Banny body ID that an outfit is worn by. |
| `onERC721Received` | `Banny721TokenUriResolver` | Handles receiving 721 tokens. Validates the transfer is authorized (outfit must be worn by sender's Banny, or sender is hook). Used for outfit management. |

## Integration Points

| Dependency | Import | Used For |
|------------|--------|----------|
| `@bananapus/721-hook-v6` | `IJB721TiersHook`, `IJB721TiersHookStore`, `IJB721TokenUriResolver`, `JB721Tier`, `JBIpfsDecoder`, `IERC721` (custom ERC721) | Token ownership checks, tier data resolution, IPFS URI decoding, hook store queries. |
| `@openzeppelin/contracts` | `Ownable`, `ReentrancyGuard`, `ERC2771Context`, `IERC721Receiver`, `Strings` | Access control, reentrancy protection, meta-transactions, safe NFT receipt, string utilities. |
| `lib/base64` | `Base64` | Base64 encoding for on-chain SVG and JSON metadata. |

## Key Types

| Struct/Enum | Key Fields | Used In |
|-------------|------------|---------|
| `JB721Tier` | `id`, `category`, `encodedIPFSUri`, `price` | `tokenUriOf` (product resolution via tier store) |

### Internal Mappings (not structs, but critical state)

| Mapping | Key | Value | Purpose |
|---------|-----|-------|---------|
| `_attachedOutfitIdsOf` | `hook => bannyBodyId` | `uint256[]` | Outfit token IDs attached to a body. |
| `_attachedBackgroundIdOf` | `hook => bannyBodyId` | `uint256` | Background token ID attached to a body. |
| `_svgContentOf` | `upc` | `string` | On-chain SVG content for a product. |
| `svgHashOf` | `upc` | `bytes32` | Keccak256 hash of expected SVG content. |
| `_customProductNameOf` | `upc` | `string` | Human-readable product name. |
| `outfitLockedUntil` | `hook => upc` | `uint256` | Timestamp until outfit changes are locked. |
| `_userOf` | `hook => backgroundId` | `uint256` | Which body is using a background. |
| `_wearerOf` | `hook => outfitId` | `uint256` | Which body is wearing an outfit. |

## Gotchas

- The `_LOCK_DURATION` is hardcoded to 7 days. `lockOutfitChangesFor` prevents reducing an existing lock (reverts with `CantAccelerateTheLock`).
- SVG content is immutable once stored. `setSvgContentsOf` reverts if content already exists. The content must hash-match the previously registered `svgHashOf[upc]`.
- SVG hashes are also immutable. `setSvgHashsOf` reverts if a hash is already registered for a UPC.
- `decorateBannyWith` enforces strict ascending category order for outfits. Passing outfits in wrong order reverts with `UnorderedCategories`.
- Only one item per "slot" category is allowed on a body: one head, one suit (full suit XOR suit top + suit bottom), one background.
- Body type detection uses the UPC modulo: UPC 1 = Alien, 2 = Pink, 3 = Orange, 4 = Original. Alien bodies get `DEFAULT_ALIEN_EYES`, others get `DEFAULT_STANDARD_EYES`.
- Outfit/background ownership is validated against the 721 hook, not `msg.sender` directly. The caller must own the body AND all attached items through the same hook contract.
- `via-ir = true` is required in `foundry.toml` due to stack-too-deep in the complex SVG composition logic.

## Example Integration

```solidity
import {IBanny721TokenUriResolver} from "@bannynet/core-v6/src/interfaces/IBanny721TokenUriResolver.sol";

// Get the composed SVG for a dressed Banny
string memory svg = resolver.svgOf(
    hookAddress,
    bannyBodyTokenId,
    true,  // dress the banny with attached outfits
    true   // include the attached background
);

// Dress a Banny body with outfits
uint256[] memory outfitIds = new uint256[](2);
outfitIds[0] = hatTokenId;   // must be category 4 (head)
outfitIds[1] = shirtTokenId; // must be category 11 (suit top)

// Caller must own the body, background, and all outfits on the same hook
resolver.decorateBannyWith(
    hookAddress,
    bannyBodyTokenId,
    backgroundTokenId,
    outfitIds  // must be in ascending category order
);
```
