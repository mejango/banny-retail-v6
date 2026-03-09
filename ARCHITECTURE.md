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

## Key Operations

### Asset Storage
```
Owner → storeContents(hash, contents)
  → Store SVG content chunks on-chain (keyed by hash)
  → Content stored in multiple chunks for large SVGs

Owner → addProduct(category, hash)
  → Register a product (body/background/head/suit) for a category
  → Products linked to stored SVG content
```

### Outfit Composition
```
NFT Holder → dress(tokenId, outfitTokenIds[])
  → Attach outfit NFTs (head, suit, background) to a body NFT
  → Outfit NFTs transferred to resolver contract (locked)
  → Composite SVG generated from layered components

NFT Holder → undress(tokenId, outfitTokenIds[])
  → Remove outfit NFTs from body
  → Outfit NFTs returned to holder
```

### Token URI Generation
```
JB721TiersHook → tokenURI(tokenId)
  → Banny721TokenUriResolver.tokenURI(hook, tokenId)
    → Look up body tier and any attached outfits
    → Compose SVG layers (background → body → outfits)
    → Encode as base64 data URI with JSON metadata
    → Return fully on-chain SVG
```

## Dependencies
- `@bananapus/721-hook-v6` — NFT tier system (IJB721TiersHook, IJB721TokenUriResolver)
- `@bananapus/core-v6` — Core protocol interfaces
- `@bananapus/router-terminal-v6` — Payment routing
- `@bananapus/suckers-v6` — Cross-chain support
- `@rev-net/core-v6` — Revnet integration
- `@openzeppelin/contracts` — Ownable, ERC2771, ReentrancyGuard, Strings
- `keccak` — Hashing utilities
