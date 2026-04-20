# Architecture

## Purpose

`banny-retail-v6` is the Banny-specific metadata and attachment layer for Juicebox 721 collections. It does not mint the NFTs or own treasury logic. It owns attachment custody, outfit-lock rules, and final token rendering.

## System Overview

The repo is centered on `Banny721TokenUriResolver`. A 721 hook from `nana-721-hook-v6` points to this resolver for `tokenURI(...)`, while bodies, outfits, and backgrounds remain separate NFTs at the collection layer. The resolver escrows equipped accessories, records which assets are attached to each body, and composes the final SVG and JSON metadata on demand.

## Core Invariants

- A body can only reference accessories that are currently escrowed by the resolver.
- Replacing an equipped item must atomically return the old item and escrow the new item.
- Outfit locks must block both explicit removal and implicit replacement until the lock expires.
- Equipped assets travel with the body NFT on transfer until the new owner unequips them.
- Registered SVG payloads must match their pre-registered content hash before they become renderable.
- Rendering must stay deterministic for the same stored body state.

## Modules

| Module | Responsibility | Notes |
| --- | --- | --- |
| `Banny721TokenUriResolver` | Escrow, attachment state, lock windows, and metadata rendering | Main contract; application-specific |
| `IBanny721TokenUriResolver` | External integration surface | Used by hooks and offchain tooling |

## Trust Boundaries

- Minting, ownership transfer, and collection-level ERC-721 semantics live in `nana-721-hook-v6`.
- This repo is trusted for rendering correctness and custody of equipped assets.
- Asset content upload is controlled by the registered content owner, but the contract verifies the uploaded bytes against the stored hash.

## Critical Flows

### Decorate

```text
body owner
  -> calls decorateBannyWith(...)
  -> resolver verifies body ownership and lock status
  -> resolver pulls new accessories into escrow
  -> resolver updates equipped slots
  -> resolver returns replaced accessories to the owner
```

### Render

```text
tokenURI(bodyId)
  -> resolver loads body, background, and equipped slot state
  -> fetches registered SVG fragments
  -> composes layered SVG in Banny-specific order
  -> returns base64 JSON metadata
```

### Lock Outfit

```text
body owner
  -> calls lockOutfitChangesFor(...)
  -> resolver stores a no-change window
  -> later decoration and removal paths must respect it
```

## Accounting Model

This repo does not own treasury accounting. Its critical state is custody accounting: which NFTs are escrowed, which body they belong to, and when a body is locked against changes.

That custody model uses lazy reconciliation for some stale attachment records. Read paths filter against current ownership and attachment state instead of eagerly rewriting storage on every external transfer.

## Security Model

- The main failure mode is custody drift between slot state and actual escrowed NFTs.
- Rendering order is part of application semantics, not cosmetic output.
- Lazy reconciliation is intentional. Changes that assume attachment arrays are perfectly clean in storage can strand assets or mis-render bodies.
- Any new asset category adds both a rendering concern and a custody concern.

## Safe Change Guide

- Keep generic ERC-721 behavior in `nana-721-hook-v6`, not here.
- Review escrow writes and transfer behavior together whenever changing attachment logic.
- If transfer or cleanup behavior changes, re-check lazy reconciliation assumptions alongside body-transfer inheritance of equipped assets.
- If `tokenURI(...)` changes, test stable output for unchanged state and replacement behavior for changed state.
- If adding slots or asset classes, update rendering order, slot replacement, and lock enforcement in one change.

## Canonical Checks

- accessory escrow, replacement, and decoration flow:
  `test/DecorateFlow.t.sol`
- burned-body custody edge cases:
  `test/audit/BurnedBodyStrandsAssets.t.sol`
- transfer-path protection against stranded attachments:
  `test/audit/TryTransferFromStrandsAssets.t.sol`

## Source Map

- `src/Banny721TokenUriResolver.sol`
- `test/DecorateFlow.t.sol`
- `test/audit/BurnedBodyStrandsAssets.t.sol`
- `test/audit/TryTransferFromStrandsAssets.t.sol`
- `script/Deploy.s.sol`
