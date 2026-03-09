# Administration

Admin privileges and their scope in banny-retail-v6. The contract (`Banny721TokenUriResolver`) is a single-file system with one admin role (Ownable) and per-token owner privileges.

## Roles

| Role | How Assigned | Scope |
|------|-------------|-------|
| **Contract Owner** | Set via constructor `Ownable(owner)` (line 174). Transferable via OpenZeppelin `transferOwnership()`. | Global: SVG asset management, metadata, product naming |
| **NFT Body Owner** | Whoever holds the banny body token on the JB721TiersHook contract. Checked via `IERC721(hook).ownerOf(bannyBodyId)` (line 605). | Per-token: decoration, locking |
| **NFT Outfit/Background Owner** | Whoever holds the outfit or background token on the hook contract. | Per-token: authorize equipping to a body they own |
| **Anyone (Permissionless)** | No restriction. | Upload SVG content (if matching hash exists) |
| **Trusted Forwarder** | Set at construction via `ERC2771Context(trustedForwarder)` (line 175). Immutable after deploy. | Meta-transaction relay: `_msgSender()` resolves to the relayed sender |

## Privileged Functions

### Banny721TokenUriResolver -- Owner-Only Functions

| Function | Line | Guard | What It Does |
|----------|------|-------|-------------|
| `setMetadata(description, url, baseUri)` | 1054-1068 | `onlyOwner` | Overwrites the token metadata description, external URL, and SVG base URI. All three fields are always written (pass current value to keep, empty string to clear). |
| `setProductNames(upcs, names)` | 1073-1084 | `onlyOwner` | Sets custom display names for products identified by UPC. Names are stored in `_customProductNameOf` mapping. Can overwrite previously set names. |
| `setSvgHashesOf(upcs, svgHashes)` | 1119-1134 | `onlyOwner` | Commits keccak256 hashes for SVG content keyed by UPC. Each hash can only be set once -- reverts with `HashAlreadyStored` if the UPC already has a hash. This is the gating step that controls which SVG content can later be uploaded permissionlessly. |

### Banny721TokenUriResolver -- Permissionless Functions

| Function | Line | Guard | What It Does |
|----------|------|-------|-------------|
| `setSvgContentsOf(upcs, svgContents)` | 1089-1113 | None (anyone) | Stores SVG content for a UPC, but only if: (1) a hash was previously committed by the owner via `setSvgHashesOf`, (2) `keccak256(content) == storedHash`, and (3) content has not already been stored (`ContentsAlreadyStored`). This is the permissionless "lazy upload" mechanism. |

### Banny721TokenUriResolver -- NFT-Owner Functions

| Function | Line | Guard | What It Does |
|----------|------|-------|-------------|
| `decorateBannyWith(hook, bannyBodyId, backgroundId, outfitIds)` | 969-999 | `_checkIfSenderIsOwner` (line 979) + `nonReentrant` | Equips/unequips outfits and background on a banny body. Caller must own the body token. For each outfit/background: caller must own the asset directly, OR own the banny body that currently wears/uses it. Transfers outfit NFTs into the resolver contract (custodial). |
| `lockOutfitChangesFor(hook, bannyBodyId)` | 1005-1019 | `_checkIfSenderIsOwner` (line 1007) | Locks a banny body's outfit for 7 days (`_LOCK_DURATION`). Lock can only be extended, never shortened (`CantAccelerateTheLock`, line 1016). Prevents `decorateBannyWith` during the lock period. |

### Banny721TokenUriResolver -- Restricted Receiver

| Function | Line | Guard | What It Does |
|----------|------|-------|-------------|
| `onERC721Received(operator, from, tokenId, data)` | 1027-1046 | `operator == address(this)` (line 1043) | Only accepts incoming NFT transfers when the resolver itself initiated the transfer. Rejects all direct user transfers to the resolver contract with `UnauthorizedTransfer`. |

## Asset Management

**Who can add SVG assets:**

1. The contract **owner** commits SVG hashes via `setSvgHashesOf()`. This is the only gatekeeping step -- only the owner decides which UPCs get artwork.
2. **Anyone** can then upload the actual SVG content via `setSvgContentsOf()`, provided the content's keccak256 hash matches the owner-committed hash. This is intentional: the owner sets the commitment, and anyone can fulfill it (useful for gas-efficient lazy uploading).

**Immutability of stored content:**
- Once a hash is set for a UPC, it cannot be changed (line 1127: `HashAlreadyStored`).
- Once content is uploaded for a UPC, it cannot be replaced (line 1097: `ContentsAlreadyStored`).
- There is no function to delete or modify stored SVG hashes or content.

**Product names:**
- Can be overwritten by the owner at any time via `setProductNames()`. There is no immutability guard on names -- the owner can rename products freely. The built-in names for UPCs 1-4 (Alien, Pink, Orange, Original) are hardcoded in `_productNameOf()` (lines 888-902) and cannot be overridden.

**Metadata:**
- `svgDescription`, `svgExternalUrl`, and `svgBaseUri` can be changed by the owner at any time via `setMetadata()`. All three are always overwritten in a single call.

## Immutable Configuration

The following are set at construction and cannot be changed:

| Property | Set At | Value |
|----------|--------|-------|
| `BANNY_BODY` | Constructor (line 177) | Base SVG path for all banny body rendering |
| `DEFAULT_NECKLACE` | Constructor (line 178) | Default necklace SVG injected when no custom necklace equipped |
| `DEFAULT_MOUTH` | Constructor (line 179) | Default mouth SVG injected when no custom mouth equipped |
| `DEFAULT_STANDARD_EYES` | Constructor (line 180) | Default eyes SVG for non-alien bodies |
| `DEFAULT_ALIEN_EYES` | Constructor (line 181) | Default eyes SVG for alien bodies |
| `trustedForwarder` | Constructor (line 175) | ERC-2771 forwarder address for meta-transactions |
| `_LOCK_DURATION` | Constant (line 63) | 7 days -- hardcoded, not configurable |
| Body color fills | Hardcoded in `_fillsFor()` (lines 661-685) | Color palettes for Alien, Pink, Orange, Original body types |
| Category IDs | Constants (lines 65-82) | 18 category slots (0-17), hardcoded |

## Admin Boundaries

**What the owner CANNOT do:**

- **Cannot move or steal user NFTs.** The resolver only holds custody of outfit/background NFTs that users voluntarily equip. The `onERC721Received` guard (line 1043) ensures only self-initiated transfers are accepted.
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
