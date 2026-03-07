# banny-retail

On-chain composable avatar system for Juicebox 721 collections -- manages Banny character bodies, backgrounds, and outfit NFTs with layered SVG rendering. Bodies can be dressed with outfits and placed on backgrounds, all composed into fully on-chain SVG images with base64-encoded JSON metadata.

[Docs](https://docs.juicebox.money) | [Discord](https://discord.gg/juicebox)

## Conceptual Overview

Banny is a composable NFT character system built on top of Juicebox 721 hooks. Each Banny is a body NFT (Alien, Pink, Orange, or Original) that can wear outfit NFTs and sit on a background NFT. The resolver composes these layers into a single SVG image, fully on-chain.

### How It Works

```
1. A Juicebox 721 hook registers Banny721TokenUriResolver as its token URI resolver
   → All tokenURI() calls are forwarded to the resolver
   |
2. Users mint Banny body NFTs + outfit/background NFTs via the 721 hook
   → Bodies are the "base" layer; outfits and backgrounds are accessories
   |
3. Body owner calls decorateBannyWith(hook, bodyId, backgroundId, outfitIds)
   → Outfit and background NFTs are transferred to the resolver contract
   → Resolver tracks which body wears which outfits
   → Body's tokenURI now renders the full dressed composition
   |
4. Outfit lock (optional): lockOutfitChangesFor(hook, bodyId)
   → Freezes outfit changes for 7 days
   → Proves the Banny's look is stable (useful for PFPs, displays)
   |
5. SVG content is stored on-chain via a two-step process:
   → Owner registers content hashes: setSvgHashesOf(upcs, hashes)
   → Anyone uploads matching content: setSvgContentsOf(upcs, contents)
   → Falls back to IPFS base URI if on-chain content not yet stored
```

### Asset Categories

| Category ID | Name | Slot Rules |
|-------------|------|------------|
| 0 | Body | Base character. One of four types: Alien, Pink, Orange, Original. |
| 1 | Background | Scene behind the Banny. One per body. |
| 2 | Backside | Layer rendered behind the body. |
| 3 | Necklace | Accessory (default provided if none attached). |
| 4 | Head | Full head accessory. Blocks eyes, glasses, mouth, and headtop. |
| 5 | Eyes | Eye style (defaults: alien or standard based on body type). |
| 6 | Glasses | Eyewear layer. Blocked by head. |
| 7 | Mouth | Mouth expression (default provided). Blocked by head. |
| 8 | Legs | Lower body clothing. |
| 9 | Suit | Full body one-piece. Blocks suit top and suit bottom. |
| 10 | Suit Bottom | Lower suit piece. Blocked by full suit. |
| 11 | Suit Top | Upper suit piece. Blocked by full suit. |
| 12 | Headtop | Top-of-head accessory. Blocked by head. |
| 13 | Hand | Held item layer. |
| 14-17 | Special | Special suit, legs, head, and body overlays. |

### Body Types

| UPC | Type | Color Palette |
|-----|------|--------------|
| 1 | Alien | Green tones (`67d757`, `30a220`, `217a15`, `09490f`) with purple accents |
| 2 | Pink | Pink tones (`ffd8c5`, `ff96a9`, `fe588b`, `c92f45`) |
| 3 | Orange | Orange tones (`f3a603`, `ff7c02`, `fd3600`, `c32e0d`) |
| 4 | Original | Yellow tones (`ffe900`, `ffc700`, `f3a603`, `965a1a`) |

## Architecture

| Contract | Description |
|----------|-------------|
| `Banny721TokenUriResolver` | The sole contract. Implements `IJB721TokenUriResolver` to serve fully on-chain SVG token URIs for any Juicebox 721 hook. Manages outfit attachment, background assignment, outfit locking, on-chain SVG storage, and layered SVG rendering. Inherits `Ownable`, `ReentrancyGuard`, `ERC2771Context`, `IERC721Receiver`. |

### Interface

| Interface | Description |
|-----------|-------------|
| `IBanny721TokenUriResolver` | Public API: `tokenUriOf`, `svgOf`, `decorateBannyWith`, `lockOutfitChangesFor`, `assetIdsOf`, `namesOf`, `userOf`, `wearerOf`, SVG management, metadata management, plus all events. |

## Install

```bash
npm install @bannynet/core-v6
```

If using Forge directly:

```bash
forge install
```

## Develop

Requires `via_ir = true` in foundry.toml due to stack depth in SVG composition.

| Command | Description |
|---------|-------------|
| `forge build` | Compile contracts (requires via-IR) |
| `forge test` | Run all tests (3 test files: functionality, attacks, decoration flows) |
| `forge test -vvv` | Run tests with full trace |

## Repository Layout

```
src/
  Banny721TokenUriResolver.sol                  # Sole contract (~1,331 lines)
  interfaces/
    IBanny721TokenUriResolver.sol               # Public interface + events
test/
  Banny721TokenUriResolver.t.sol                # Unit tests (~690 lines)
  BannyAttacks.t.sol                            # Security/adversarial tests (~323 lines)
  DecorateFlow.t.sol                            # Decoration flow tests (~1,057 lines)
script/
  Deploy.s.sol                                  # Sphinx multi-chain deployment
  Drop1.s.sol                                   # Outfit drop deployment
  Add.Denver.s.sol                              # Denver-specific deployment
  helpers/
    BannyverseDeploymentLib.sol                 # Deployment artifact reader
    MigrationHelper.sol                         # Migration utilities
```

## Permissions

| Action | Who Can Do It |
|--------|--------------|
| `decorateBannyWith` | Body owner (must also own or have worn-by-body access to outfits/backgrounds) |
| `lockOutfitChangesFor` | Body owner |
| `setSvgHashesOf` | Contract owner only |
| `setSvgContentsOf` | Anyone (content validated against registered hash) |
| `setProductNames` | Contract owner only |
| `setMetadata` | Contract owner only |

## Risks

- **Outfit custody:** Attached outfits and backgrounds are held by the resolver contract. If the contract has a bug in the return logic, assets could be stuck.
- **7-day lock is fixed.** Cannot be shortened or cancelled once set. The lock duration is hardcoded.
- **SVG immutability.** Once SVG content is stored on-chain for a UPC, it cannot be changed. A mistake in the content requires deploying a new resolver.
- **Hash registration is owner-only, but content upload is not.** Anyone can call `setSvgContentsOf` as long as the content matches the registered hash. This is by design for lazy uploads.
- **Single resolver per hook.** The resolver is set on the 721 hook and applies to all tiers. Different collections would need different resolver instances.
