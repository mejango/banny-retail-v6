# User Journeys

## Who This Repo Serves

- Banny collection operators publishing body, outfit, and background tiers
- collectors minting avatars and equipping accessories
- teams managing on-chain art payloads and metadata composition

## Journey 1: Mint A Body, Outfit, And Background Set

**Starting state:** the Banny collection is live through the 721 hook and the relevant tiers exist.

**Success:** the collector owns the pieces needed to build a composed avatar.

**Flow**
1. Mint the body, outfit, and background NFTs through the underlying Juicebox 721 project.
2. Keep pricing, issuance, and treasury assumptions anchored in the 721 hook rather than this resolver.
3. Treat this repo as the composition layer that activates once the user owns the right pieces.

## Journey 2: Dress A Banny And Put Accessories Into Resolver Custody

**Starting state:** the collector owns a body plus compatible accessories.

**Success:** the chosen outfit and background are attached to the body and the resolver renders the combined look.

**Flow**
1. Call `decorateBannyWith(...)` for the target body.
2. `Banny721TokenUriResolver` checks compatibility rules and takes custody of the attached accessory NFTs while they are equipped.
3. The body's token URI now resolves to a layered SVG and metadata payload reflecting the active composition.

## Journey 3: Lock A Banny's Appearance For A Period

**Starting state:** the collector likes the current look and does not want it changed immediately.

**Success:** the avatar's appearance is frozen for the lock window and later equipment changes must wait.

**Flow**
1. Call `lockOutfitChangesFor(...)` on the resolver.
2. The resolver records the lock period for that body.
3. Future decorate or removal actions respect the lock until it expires.

## Journey 4: Publish Or Repair On-Chain Art Assets

**Starting state:** the collection's visual payloads are referenced by content hashes but the actual SVG payloads still need to be made available.

**Success:** token URIs render complete art instead of placeholders or missing layers.

**Flow**
1. Register the content hashes for bodies, outfits, or backgrounds with `setSvgHashesOf(...)`.
2. Upload or repair the corresponding SVG payloads with `setSvgContentsOf(...)`.
3. Re-resolve token URIs to confirm the on-chain composition now renders correctly.

**Failure cases that matter:** publishing content that does not match the registered hash, forgetting to set product names for new pieces, and assuming the 721 hook owns the art payload when this repo owns the rendered output.

## Journey 5: Update Collection Metadata And Product Catalog Entries

**Starting state:** the collection exists, but its descriptive metadata or UPC-to-name catalog needs to change.

**Success:** token URIs and collection-level presentation reflect the intended description, external URL, base URI, and product naming.

**Flow**
1. Update collection metadata with `setMetadata(...)`.
2. Set or repair product names for the UPCs the renderer should expose with `setProductNames(...)`.
3. Re-check token URI output so the rendered Banny and its catalog labels agree.

## Journey 6: Unequip And Recover Custodied Accessories

**Starting state:** a body has attached pieces held by the resolver and the owner wants to rearrange or transfer them.

**Success:** the accessories leave resolver custody and can be reused or transferred independently.

**Flow**
1. Remove or replace the equipped items once no lock blocks the change.
2. The resolver releases custody of the old accessory NFTs.
3. The owner can now transfer, burn, or re-equip those pieces elsewhere.

## Hand-Offs

- Use [nana-721-hook-v6](../nana-721-hook-v6/USER_JOURNEYS.md) for mint pricing, tier issuance, reserves, and treasury behavior.
- Use this repo only once the question is about custody, compatibility, outfit locks, or SVG composition.
