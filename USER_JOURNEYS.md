# User Journeys

## Who This Repo Serves

- collectors minting Banny bodies, outfits, and backgrounds
- body owners composing and locking a Banny's look
- operators curating SVG assets and metadata for a live collection

## Journey 1: Mint And Dress A Banny

**Starting state:** a Juicebox 721 hook uses `Banny721TokenUriResolver` as its token URI resolver, and the relevant body or accessory tiers are live.

**Success:** the holder owns a body NFT whose `tokenURI` renders the intended background and outfit layers.

**Flow**
1. Mint a body NFT and any accessory NFTs from the connected 721 hook.
2. Call `decorateBannyWith(hook, bodyId, backgroundId, outfitIds)`.
3. The resolver verifies body ownership, takes custody of the selected accessories, and records which assets the body is wearing.
4. The body's `tokenURI` now returns the composed on-chain SVG and metadata.
5. If a slot is replaced later, the old accessory is returned to the holder.

**What changes onchain:** the body stays with the holder, but worn accessories are escrowed by the resolver while attached.

## Journey 2: Lock A Banny's Appearance

**Starting state:** a body already has the desired accessories attached.

**Success:** the look is frozen for the lock window and cannot be changed or stripped by another decoration call.

**Flow**
1. The body owner calls `lockOutfitChangesFor(hook, bodyId)`.
2. The resolver stores the lock expiry.
3. Until expiry, background and outfit changes for that body are blocked.
4. After expiry, the owner can decorate again or move the accessories elsewhere.

**Use this when:** social identity or downstream integrations rely on the Banny staying visually stable.

## Journey 3: Publish Or Repair On-Chain Art Assets

**Starting state:** UPC hashes and product metadata need to be registered or completed.

**Success:** token rendering resolves fully onchain or falls back to the intended content path.

**Flow**
1. The contract owner registers expected SVG hashes with `setSvgHashesOf(...)`.
2. Anyone can upload matching content with `setSvgContentsOf(...)`.
3. The owner sets product names or metadata used by the resolver.
4. `tokenURI` resolves on-chain content when present and otherwise falls back to the configured IPFS base path.

**Operational note:** this repo is the rendering and composition layer. Minting policy still lives in the connected 721 hook.

## Hand-Offs

- Use [nana-721-hook-v6](../nana-721-hook-v6/USER_JOURNEYS.md) to understand the collection hook that mints the bodies and accessories.
- Use [revnet-core-v6](../revnet-core-v6/USER_JOURNEYS.md) if the collection is treasury-backed by a revnet.
