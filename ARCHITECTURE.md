# Architecture

## Purpose

`banny-retail-v6` provides the metadata layer for Banny collections. The repo does not mint or own the NFTs itself. Instead, a Juicebox 721 hook points at `Banny721TokenUriResolver`, and the resolver composes body, background, and outfit NFTs into a single on-chain representation.

## Boundaries

- The repo owns Banny-specific composition logic, asset registration, and outfit locking.
- `nana-721-hook-v6` still owns token minting, transfers, and collection-level ERC-721 behavior.
- The resolver is intentionally application-specific. Generic 721 hook behavior should stay in `nana-721-hook-v6`.

## Main Components

| Component | Responsibility |
| --- | --- |
| `Banny721TokenUriResolver` | Stores SVG content references, tracks equipped assets per body, enforces outfit-lock windows, and returns composed token metadata |
| `IBanny721TokenUriResolver` | Integration surface for the 721 hook or external tooling |

## Runtime Model

### Decoration

```text
body owner
  -> calls decorateBannyWith(...)
  -> resolver verifies ownership of the body token
  -> resolver pulls the chosen background and outfit NFTs into escrow
  -> resolver records which assets are attached to the body
  -> resolver returns any replaced assets to the owner
```

### Rendering

```text
tokenURI(bodyId)
  -> resolve body, background, and equipped outfit slots
  -> fetch registered SVG fragments
  -> compose layered SVG
  -> return base64 JSON metadata
```

### Locking

```text
owner
  -> lockOutfitChangesFor(...)
  -> body enters a temporary no-change window
  -> decoration and removal paths must respect the lock
```

## Critical Invariants

- A body can only point at assets currently escrowed by the resolver.
- Slot replacement must be one-for-one. Replacing an equipped item returns the old item instead of orphaning it.
- Outfit locks must block both direct edits and indirect attempts to reclaim an equipped item through another decoration call.
- Asset registration is split between hash registration and content upload so content can be trustlessly verified before it is stored on-chain.

## Where Complexity Lives

- Escrow bookkeeping and slot replacement must stay synchronized.
- Lock enforcement has to cover both explicit removal and implicit replacement paths.
- SVG composition order is application logic, not a cosmetic detail.

## Dependencies

- `nana-721-hook-v6` for collection ownership and transfer semantics
- Juicebox metadata resolver patterns for token URI integration

## Safe Change Guide

- Put new generic 721 behavior in `nana-721-hook-v6`, not here.
- Treat slot accounting and escrow transfers as coupled logic. Changing one without the other is how equipment duplication bugs appear.
- Changes to `tokenURI` should preserve deterministic output for the same body state.
- If adding new asset categories, verify render order and replacement semantics together.
- If a change touches both metadata composition and escrow state, test transfer lifecycle behavior, not just rendered output.
