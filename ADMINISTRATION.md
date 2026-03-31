# Administration

Admin privileges and their scope in banny-retail-v6. The contract (`Banny721TokenUriResolver`) is a single-file system with one admin role (Ownable) and per-token owner privileges.

## At A Glance

| Item | Details |
|------|---------|
| Scope | Resolver-level metadata, SVG asset commitments/uploads, and body-level outfit management for Banny NFTs. |
| Operators | The resolver owner for global metadata and asset commitments, body owners for decoration actions, and anyone for permissionless SVG uploads that match committed hashes. |
| Highest-risk actions | Committing the wrong SVG hash, changing global metadata unexpectedly, or locking outfit changes while assets are held custodially in the resolver. |
| Recovery posture | Write-once SVG commitments cannot be corrected in place. If resolver behavior is wrong, recovery usually means deploying a replacement resolver rather than editing stored content. |

## Routine Operations

- Commit SVG hashes only after verifying the exact UPC-to-content pairing, since the commitment is permanent.
- Treat metadata and product-name changes as ecosystem-wide display changes that affect every token rendered through the resolver.
- Remind users that equipped assets are held by the resolver contract until they are unequipped through the supported flow.
- Use outfit locks deliberately, because they freeze body-level changes for the fixed lock window.

## One-Way Or High-Risk Actions

- `setSvgHashesOf` is write-once per UPC.
- `setSvgContentsOf` is also write-once once valid content is uploaded.
- `lockOutfitChangesFor` can only extend the active lock, never shorten it.
- There is no admin rescue path for custodially held outfit NFTs.

## Recovery Notes

- If committed artwork is wrong, the practical recovery path is a new resolver or a new UPC strategy, not overwriting the existing entry.
- If outfits become stuck because of a resolver bug, this contract exposes no owner rescue flow; recovery would require replacement infrastructure rather than an admin intervention.

## Roles

| Role | How Assigned | Scope |
|------|-------------|-------|
| **Contract Owner** | Set via constructor `Ownable(owner)`. Transferable via OpenZeppelin `transferOwnership()`. | Global: SVG asset management, metadata, product naming |
| **NFT Body Owner** | Whoever holds the banny body token on the JB721TiersHook contract. Checked via `IERC721(hook).ownerOf(bannyBodyId)`. | Per-token: decoration, locking |
| **NFT Outfit/Background Owner** | Whoever holds the outfit or background token on the hook contract. | Per-token: authorize equipping to a body they own |
| **Anyone (Permissionless)** | No restriction. | Upload SVG content (if matching hash exists) |
| **Trusted Forwarder** | Set at construction via `ERC2771Context(trustedForwarder)`. Immutable after deploy. | Meta-transaction relay: `_msgSender()` resolves to the relayed sender |

## Privileged Functions

### Banny721TokenUriResolver -- Owner-Only Functions

| Function | Guard | What It Does |
|----------|-------|-------------|
| `setMetadata(description, url, baseUri)` | `onlyOwner` | Overwrites the token metadata description, external URL, and SVG base URI. All three fields are always written (pass current value to keep, empty string to clear). |
| `setProductNames(upcs, names)` | `onlyOwner` | Sets custom display names for products identified by UPC. Names are stored in `_customProductNameOf` mapping. Can overwrite previously set names. |
| `setSvgHashesOf(upcs, svgHashes)` | `onlyOwner` | Commits keccak256 hashes for SVG content keyed by UPC. Each hash can only be set once -- reverts with `HashAlreadyStored` if the UPC already has a hash. This is the gating step that controls which SVG content can later be uploaded permissionlessly. |

### Banny721TokenUriResolver -- Permissionless Functions

| Function | Guard | What It Does |
|----------|-------|-------------|
| `setSvgContentsOf(upcs, svgContents)` | None (anyone) | Stores SVG content for a UPC, but only if: (1) a hash was previously committed by the owner via `setSvgHashesOf`, (2) `keccak256(content) == storedHash`, and (3) content has not already been stored (`ContentsAlreadyStored`). This is the permissionless "lazy upload" mechanism. |

### Banny721TokenUriResolver -- NFT-Owner Functions

| Function | Guard | What It Does |
|----------|-------|-------------|
| `decorateBannyWith(hook, bannyBodyId, backgroundId, outfitIds)` | `_checkIfSenderIsOwner` + `nonReentrant` | Equips/unequips outfits and background on a banny body. Caller must own the body token. For each outfit/background: caller must own the asset directly, OR own the banny body that currently wears/uses it. Transfers outfit NFTs into the resolver contract (custodial). |
| `lockOutfitChangesFor(hook, bannyBodyId)` | `_checkIfSenderIsOwner` | Locks a banny body's outfit for 7 days (`_LOCK_DURATION`). Lock can only be extended, never shortened (`CantAccelerateTheLock`). Prevents `decorateBannyWith` during the lock period. |

### Banny721TokenUriResolver -- Restricted Receiver

| Function | Guard | What It Does |
|----------|-------|-------------|
| `onERC721Received(operator, from, tokenId, data)` | `operator == address(this)` | Only accepts incoming NFT transfers when the resolver itself initiated the transfer. Rejects all direct user transfers to the resolver contract with `UnauthorizedTransfer`. |

## Asset Management

**Who can add SVG assets:**

1. The contract **owner** commits SVG hashes via `setSvgHashesOf()`. This is the only gatekeeping step -- only the owner decides which UPCs get artwork.
2. **Anyone** can then upload the actual SVG content via `setSvgContentsOf()`, provided the content's keccak256 hash matches the owner-committed hash. This is intentional: the owner sets the commitment, and anyone can fulfill it (useful for gas-efficient lazy uploading).

**Immutability of stored content:**
- Once a hash is set for a UPC, it cannot be changed (`HashAlreadyStored`).
- Once content is uploaded for a UPC, it cannot be replaced (`ContentsAlreadyStored`).
- There is no function to delete or modify stored SVG hashes or content.

**Product names:**
- Can be overwritten by the owner at any time via `setProductNames()`. There is no immutability guard on names -- the owner can rename products freely. The built-in names for UPCs 1-4 (Alien, Pink, Orange, Original) are hardcoded in `_productNameOf()` and cannot be overridden.

**Metadata:**
- `svgDescription`, `svgExternalUrl`, and `svgBaseUri` can be changed by the owner at any time via `setMetadata()`. All three are always overwritten in a single call.

## Custodial Model

When a user equips an outfit or background on a banny body via `decorateBannyWith()`, the outfit/background NFT is transferred from the user's wallet into the `Banny721TokenUriResolver` contract. The resolver holds these NFTs in custody until the user unequips them (by calling `decorateBannyWith()` again with different outfits).

**Trust assumptions:**
- Users must trust that the resolver contract's `decorateBannyWith()` function correctly returns NFTs when outfits are changed. There is no separate `withdraw()` or `rescue()` function.
- The `onERC721Received` guard (`operator == address(this)`) prevents anyone from sending arbitrary NFTs to the resolver. Only self-initiated transfers during `decorateBannyWith()` are accepted.
- If the banny body NFT is transferred to a new owner while outfits are equipped, the new body owner can unequip and claim the outfit NFTs (the ownership check in `_checkIfSenderIsOwner` is against the current body owner).
- The `lockOutfitChangesFor()` function can lock outfits for up to 7 days per call (extendable). During a lock, neither the body owner nor anyone else can change the equipped outfits.
- There is no admin override to rescue stuck outfit NFTs. If a bug in `decorateBannyWith()` prevents unequipping, the outfits remain locked in the resolver permanently.

## Immutable Configuration

The following are set at construction and cannot be changed:

| Property | Set At | Value |
|----------|--------|-------|
| `BANNY_BODY` | Constructor | Base SVG path for all banny body rendering |
| `DEFAULT_NECKLACE` | Constructor | Default necklace SVG injected when no custom necklace equipped |
| `DEFAULT_MOUTH` | Constructor | Default mouth SVG injected when no custom mouth equipped |
| `DEFAULT_STANDARD_EYES` | Constructor | Default eyes SVG for non-alien bodies |
| `DEFAULT_ALIEN_EYES` | Constructor | Default eyes SVG for alien bodies |
| `trustedForwarder` | Constructor | ERC-2771 forwarder address for meta-transactions |
| `_LOCK_DURATION` | Constant | 7 days -- hardcoded, not configurable |
| Body color fills | Hardcoded in `_fillsFor()` | Color palettes for Alien, Pink, Orange, Original body types |
| Category IDs | Constants | 18 category slots (0-17), hardcoded |

## Admin Boundaries

**What the owner CANNOT do:**

- **Cannot move or steal user NFTs.** The resolver only holds custody of outfit/background NFTs that users voluntarily equip. The `onERC721Received` guard ensures only self-initiated transfers are accepted.
- **Cannot modify stored SVG content.** Once hash + content are committed, they are permanent. No delete or update function exists.
- **Cannot modify stored SVG hashes.** Each UPC's hash is write-once.
- **Cannot change the lock duration.** The 7-day lock is a compile-time constant.
- **Cannot force-equip or force-unequip outfits.** Only the body NFT's owner can call `decorateBannyWith` and `lockOutfitChangesFor`.
- **Cannot override hardcoded body names.** UPCs 1-4 always resolve to Alien, Pink, Orange, Original regardless of `_customProductNameOf`.
- **Cannot change the trusted forwarder.** It is immutable after construction.
- **Cannot pause the contract.** There is no pause mechanism.
- **Cannot upgrade the contract.** It is not upgradeable.

**What the owner CAN do that affects users:**

- **Change metadata** (`svgDescription`, `svgExternalUrl`, `svgBaseUri`). This affects how all tokens render in wallets/marketplaces. Clearing `svgBaseUri` would break IPFS-based fallback rendering for products without on-chain SVG content.
- **Rename products.** Custom product names (UPC > 4) can be changed at any time, altering how NFTs display.
- **Commit new SVG hashes.** This controls which new artwork can be uploaded, but cannot affect already-stored content.
- **Transfer ownership.** Via OpenZeppelin `transferOwnership()`, the owner can hand off all admin privileges to a new address (including a multisig, DAO, or malicious actor).
