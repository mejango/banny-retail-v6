# Audit Instructions

This repo is the Banny avatar composition layer. Its runtime surface is small, but it directly custodizes NFTs and decides what a Banny body can wear.

## Objective

Find issues that:
- strand body, outfit, or background NFTs in the resolver
- let the wrong actor equip, unequip, steal, or overwrite accessories
- bypass outfit-lock timing or freeze users longer than intended
- return incorrect metadata for bodies, outfits, or backgrounds
- break category exclusivity or layering assumptions

## Scope

In scope:
- `src/Banny721TokenUriResolver.sol`
- `src/interfaces/IBanny721TokenUriResolver.sol`
- deployment scripts in `script/`

Primary integration assumptions to verify:
- the resolver is used as a token URI resolver for a `JB721TiersHook`
- the underlying 721 hook remains the token contract and tier source
- the resolver temporarily holds accessory NFTs while they are equipped

## System Model

The resolver does not mint project NFTs. It:
- reads tier and token metadata from the attached 721 hook
- receives outfit and background NFTs through safe transfers
- records which body currently has which attachments
- enforces category and conflict rules
- renders composed metadata and SVG output

The critical custody model is:
- body owner controls decoration
- resolver holds equipped accessories
- on unequip or invalidation, assets must become recoverable by the rightful owner

## Critical Invariants

1. No asset loss in custody
Every outfit or background transferred into the resolver must remain attributable to exactly one body or be withdrawable back to the rightful owner.

2. Body ownership gates decoration
Only an authorized actor for the body may change its equipped state.

3. Category exclusivity
Conflicting categories must not be equipped together, and categories that are forbidden as accessories must never become equipped through edge paths.

4. Lock correctness
`lockOutfitChangesFor` must only prevent changes for the intended body and duration. It must not be bypassable, extendable by unauthorized actors, or accidentally permanent.

5. Metadata coherence
`tokenURI` and related rendering helpers must reflect actual equipped state and should not expose stale or impossible compositions.

## Threat Model

Prioritize adversaries that:
- transfer unexpected NFTs into the resolver
- try to decorate using burned, removed, or mismatched token IDs
- exploit reentrancy on NFT receipt or withdrawal
- use invalid category order or duplicate categories to desync state
- attempt to steal accessories by redecorating around lock windows

## Hotspots

- `decorateBannyWith`: ownership checks, state replacement, and asset movement ordering
- any path that accepts NFT transfers into resolver custody
- outfit/background release paths after redecorating, burning, or invalid token states
- category validation and conflict checks
- lock timestamp handling
- token URI generation that assumes on-chain SVG data exists or remains consistent

## Build And Verification

Standard workflow:
- `npm install`
- `forge build`
- `forge test`

The current test tree emphasizes:
- attack and regression coverage around stranding and exclusivity
- decoration lifecycle flows
- fork and QA scenarios

Prefer proofs that show a body or accessory becoming inaccessible, transferable by the wrong party, or rendered inconsistently with stored state.
