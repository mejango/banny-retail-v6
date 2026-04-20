# User Journeys

## Repo Purpose

This repo is the Banny-specific composition and metadata layer on top of a Juicebox 721 collection.
It owns attachment custody, compatibility rules, outfit locks, and rendered token metadata. It does not own tier
pricing, treasury accounting, or mint eligibility outside the resolver-specific checks.

## Primary Actors

- collection operators publishing bodies, outfits, backgrounds, and metadata
- collectors equipping and unequipping avatar pieces
- auditors reviewing custody, lock, and rendering behavior

## Key Surfaces

- `Banny721TokenUriResolver`: custody, compatibility, locks, and rendered SVG metadata
- `decorateBannyWith(...)`: equips outfits and a background to a body and returns no-longer-equipped items when possible
- `lockOutfitChangesFor(...)`: freezes appearance changes for the fixed lock window
- `setSvgHashesOf(...)` / `setSvgContentsOf(...)`: publish or repair art payloads
- `setMetadata(...)` / `setProductNames(...)`: update collection metadata and UPC naming

## Journey 1: Mint A Body, Outfit, And Background Set

**Actor:** collector.

**Intent:** acquire the pieces needed to build a composed Banny.

**Preconditions**
- the Banny collection is live through the 721 hook
- the required body, outfit, and background tiers exist

**Main Flow**
1. Mint the body, outfit, and background NFTs through the underlying 721 project.
2. Keep mint pricing and issuance assumptions anchored in the 721 hook, not this repo.
3. Move to this resolver only once the user actually owns compatible pieces.

**Failure Modes**
- the wrong tiers are minted or the pieces are not compatible
- teams misread this repo as the minting or accounting surface

**Postconditions**
- the user holds the components needed for later composition
- mint pricing, reserves, and treasury effects still belong to the underlying 721 project rather than this resolver

## Journey 2: Dress A Banny And Put Accessories Into Resolver Custody

**Actor:** body owner.

**Intent:** equip a body with a background and outfits so the resolver serves the composed avatar.

**Preconditions**
- the caller controls the body and the accessories being equipped
- no active outfit lock blocks the change
- the selected pieces are compatible by category and collection rules

**Main Flow**
1. Call `decorateBannyWith(...)` for the target body.
2. The resolver checks compatibility and diffs old versus new attachments.
3. Equipped accessories move into resolver custody while attached.
4. The token URI for the body now reflects the combined SVG and metadata.

**Failure Modes**
- duplicate outfit categories or incompatible combinations are provided
- a transfer-back of previously attached items fails, leaving retained custody state that must be recovered later
- reviewers forget that the resolver, not the user wallet, holds equipped accessories while active

**Postconditions**
- the body renders with the newly attached composition
- attached accessories remain in resolver custody until replaced or cleared

## Journey 3: Lock A Banny's Appearance For A Period

**Actor:** body owner.

**Intent:** freeze the current appearance for the fixed lock window.

**Preconditions**
- the body already has a state worth freezing
- the caller understands the lock is intentionally fixed-duration

**Main Flow**
1. Call `lockOutfitChangesFor(...)`.
2. The resolver extends the lock for that body.
3. Future decoration or removal attempts must wait until the lock expires.

**Failure Modes**
- a seller locks just before transfer and the buyer cannot re-style immediately
- integrations fail to surface lock state before listing or sale

**Postconditions**
- appearance changes are blocked until the lock expires

## Journey 4: Publish Or Repair On-Chain Art Assets

**Actor:** collection operator or art publisher.

**Intent:** make token URIs render complete onchain art.

**Preconditions**
- the relevant UPCs and content hashes are known
- the operator understands hashes are the commitment and SVG content must match them exactly

**Main Flow**
1. Register hashes with `setSvgHashesOf(...)`.
2. Upload matching payloads with `setSvgContentsOf(...)`.
3. Re-check token URI output after publication or repair.

**Failure Modes**
- the uploaded SVG does not match the committed hash
- product names are missing or stale
- teams assume the 721 hook owns rendered output when this repo does

**Postconditions**
- token URIs can render the intended onchain art payloads for published UPCs

## Journey 5: Update Collection Metadata And Product Catalog Entries

**Actor:** collection operator.

**Intent:** change collection-level metadata and human-readable product labels.

**Preconditions**
- the operator has authority over the resolver metadata surface

**Main Flow**
1. Update collection metadata with `setMetadata(...)`.
2. Set or repair UPC names with `setProductNames(...)`.
3. Re-check a representative token URI so labels and art agree.

**Failure Modes**
- metadata and SVG state drift apart
- operators update catalog labels without checking already-minted assets

**Postconditions**
- collection-level metadata and UPC names line up with the currently published art set

## Journey 6: Unequip And Recover Custodied Accessories

**Actor:** body owner.

**Intent:** recover attached accessories from resolver custody.

**Preconditions**
- the current lock window, if any, has expired
- the owner understands old pieces may only be returned as part of a later decoration update

**Main Flow**
1. Replace or clear the equipped items through `decorateBannyWith(...)`.
2. The resolver attempts to return no-longer-equipped accessories.
3. Once returned, those NFTs can be transferred or re-used independently.

**Failure Modes**
- previously equipped pieces remain retained because transfer-back failed
- burned or otherwise unrecoverable pieces leave cosmetic phantom state until corrected

**Postconditions**
- no-longer-equipped accessories are either returned to the owner or remain explicitly retained pending recovery

## Trust Boundaries

- this repo is trusted for custody of equipped accessories while attached
- the underlying 721 hook remains the source of mint pricing, tier issuance, and treasury behavior
- metadata correctness depends on operators publishing the intended SVG hashes and contents

## Hand-Offs

- Use [nana-721-hook-v6](../nana-721-hook-v6/USER_JOURNEYS.md) for mint pricing, tier issuance, reserves, and treasury behavior.
- Use this repo only once the question is about custody, compatibility, outfit locks, or SVG composition.
