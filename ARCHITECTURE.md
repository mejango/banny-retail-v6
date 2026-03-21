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
Owner → setSvgHashesOf(upcs, hashes)
  → Register content hashes for UPCs (owner-only)

Anyone → setSvgContentsOf(upcs, contents)
  → Upload SVG content matching registered hashes
  → Content validated against hash before storage

Owner → setProductNames(upcs, names)
  → Register product names for UPCs
```

### Outfit Composition
```
Body Owner → decorateBannyWith(hook, bodyId, backgroundId, outfitIds)
  → Attach outfit and background NFTs to a body NFT
  → Outfit/background NFTs transferred to resolver contract
  → Previous outfits returned to owner
  → Composite SVG generated from layered components

Body Owner → lockOutfitChangesFor(hook, bodyId)
  → Lock outfit changes for 7 days
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
