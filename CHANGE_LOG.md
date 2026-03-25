# banny-retail-v6 Changelog (v5 → v6)

This document describes all changes between `banny-retail` (v5) and `banny-retail-v6` (v6).

## Summary

- **Key bug fixes**: Default eyes incorrectly selected based on outfit UPC instead of body UPC; decoration operations blocked when a previously-equipped item was burned/removed.
- **Fault-tolerant transfers**: New `_tryTransferFrom()` wraps returns of previously-equipped items in try-catch — a burned or removed outfit no longer blocks the entire `decorateBannyWith()` operation.
- **Richer metadata**: `setSvgBaseUri()` replaced by `setMetadata()` which sets description, external URL, and base URI together. Token JSON `description` and `external_url` are now dynamic.
- **Body category validation**: `decorateBannyWith()` now verifies the `bannyBodyId` actually belongs to a body-category tier before proceeding.
- **Batch setter safety**: Array length mismatch checks added to `setProductNames()`, `setSvgContentsOf()`, and `setSvgHashesOf()`.

---

## 1. Breaking Changes

### Solidity Version Bump
- **v5:** `pragma solidity 0.8.23;`
- **v6:** `pragma solidity 0.8.28;`

### Dependency Imports Updated
All `@bananapus/721-hook-v5` imports replaced with `@bananapus/721-hook-v6`:
- `IERC721`, `IJB721TiersHook`, `IJB721TiersHookStore`, `IJB721TokenUriResolver`, `JB721Tier`, `JBIpfsDecoder`

### `setSvgBaseUri()` Removed and Replaced by `setMetadata()`
- **v5:** `setSvgBaseUri(string calldata baseUri)` -- sets only the SVG base URI. Emits `SetSvgBaseUri`.
- **v6:** `setMetadata(string calldata description, string calldata url, string calldata baseUri)` -- sets description, external URL, and base URI in a single call. Emits `SetMetadata`.
- Callers that previously used `setSvgBaseUri()` must migrate to `setMetadata()`.

### `setSvgHashsOf()` Renamed to `setSvgHashesOf()`
- **v5:** `setSvgHashsOf(uint256[] memory upcs, bytes32[] memory svgHashs)`
- **v6:** `setSvgHashesOf(uint256[] memory upcs, bytes32[] memory svgHashes)`
- Function name and parameter name corrected for proper English pluralization.

### `pricingContext()` Return Value Change
- **v5:** `(uint256 currency, uint256 decimals,) = IJB721TiersHook(hook).pricingContext();` -- three return values (third ignored).
- **v6:** `(uint256 currency, uint256 decimals) = IJB721TiersHook(hook).pricingContext();` -- two return values.
- Reflects an upstream change in `IJB721TiersHook` where `pricingContext()` now returns only two values.

### Token Metadata `description` and `external_url` Are Now Dynamic
- **v5:** Hardcoded in `tokenUriOf()`: `"description":"A piece of Banny Retail."` and `"external_url":"https://retail.banny.eth.sucks"`.
- **v6:** Read from state variables `svgDescription` and `svgExternalUrl`, set via `setMetadata()`. These default to empty strings until the owner sets them.

---

## 2. New Features

### New State Variables: `svgDescription` and `svgExternalUrl`
- `string public svgDescription` -- the description used in token metadata JSON.
- `string public svgExternalUrl` -- the external URL used in token metadata JSON.
- Both are settable via the new `setMetadata()` function.

### Body Category Validation in `decorateBannyWith()`
- **v6 adds:** A check that the `bannyBodyId` actually belongs to a body-category tier (`_BODY_CATEGORY == 0`). If not, reverts with `Banny721TokenUriResolver_BannyBodyNotBodyCategory()`.
- **v5:** No such check existed; any token ID could be passed as a banny body.

### `_tryTransferFrom()` -- Fault-Tolerant, Return-Aware Transfers
- **v6 adds:** `_tryTransferFrom(address hook, address from, address to, uint256 assetId) returns (bool success)` -- wraps `safeTransferFrom` in a try-catch and returns whether the transfer succeeded.
- Used in `_decorateBannyWithBackground()` and `_decorateBannyWithOutfits()` when returning previously equipped items.
- When the return transfer fails, **state is preserved** instead of cleared — preventing NFT stranding:
  - **Backgrounds**: Failed return aborts the entire background change (old background stays attached, new one is not equipped).
  - **Outfits**: Failed-to-return outfits are retained in the attached list via `_storeOutfitsWithRetained()`.
- **v5:** Used `_transferFrom()` (which reverts on failure) for all transfers, meaning a single burned/removed outfit could block the entire decoration operation.

> **Why this mattered**: In v5, if a project owner removed a tier that contained an equipped outfit, the Banny body owner could never change decorations again — the `safeTransferFrom` for the removed item would revert, permanently blocking the `decorateBannyWith()` function. This was the most-reported user issue.

### `_storeOutfitsWithRetained()` -- Anti-Stranding Merge
- **v6 adds:** `_storeOutfitsWithRetained(address hook, uint256 bannyBodyId, uint256[] memory outfitIds, uint256[] memory previousOutfitIds)` -- stores the new outfit array, appending any previously equipped outfits whose return transfer failed (non-zero entries in `previousOutfitIds`).
- This ensures that NFTs held by the resolver but not successfully returned to the owner remain tracked and recoverable in subsequent `decorateBannyWith` calls.

### `_isInArray()` Helper
- **v6 adds:** `_isInArray(uint256 value, uint256[] memory array)` -- checks if a value is present in an array.
- Used during outfit cleanup to skip outfits being re-equipped rather than transferring them out and back in.

### Array Length Validation on Batch Setters
- **v6 adds:** `Banny721TokenUriResolver_ArrayLengthMismatch()` error.
- `setProductNames()`, `setSvgContentsOf()`, and `setSvgHashesOf()` now validate that the `upcs` and values arrays have matching lengths. v5 had no such check, risking out-of-bounds reverts.

### `assetIdsOf()` Array Resize via Assembly
- **v6 adds:** After filtering outfits, the returned `outfitIds` array is resized via inline assembly (`mstore(outfitIds, numberOfIncludedOutfits)`) to remove trailing zeros.
- **v5:** Returned the full-length array with trailing zero entries for unincluded outfits.

### `_encodeTokenUri()` Extracted Helper
- **v6 adds:** `_encodeTokenUri(uint256 tokenId, JB721Tier memory product, string memory extraMetadata, string memory imageContents)` -- an internal view function that encodes the token URI JSON with base64.
- Uses nested `abi.encodePacked()` calls to avoid "stack too deep" errors.
- **v5:** Inlined the entire JSON encoding in `tokenUriOf()` as a single large `abi.encodePacked()` call.

### Default Eyes Bug Fix (`_outfitContentsFor`)
- **v5 (bug):** `_outfitContentsFor()` used the current outfit's `upc` to decide alien vs. standard default eyes: `if (upc == ALIEN_UPC)`. This checked the UPC of the *outfit being iterated*, not the banny body.
- **v6 (fix):** `_outfitContentsFor()` now accepts an additional `bodyUpc` parameter and uses `if (bodyUpc == ALIEN_UPC)` to correctly select default eyes based on the banny body type.

> **Why this mattered**: The bug caused alien Bannys to get standard eyes and vice versa when any outfit was equipped, breaking the visual identity of the NFT. The fix ensures default eyes are always selected based on the body type, not whatever outfit happens to be iterated.

### Improved Background Authorization Logic
- **v6:** `_decorateBannyWithBackground()` now explicitly checks if an unused background (where `userId == 0`) can only be attached by its owner. In v5, the authorization check `_msgSender() != owner && _msgSender() != IERC721(hook).ownerOf(userOf(hook, backgroundId))` could behave unexpectedly when `userOf()` returned 0 (querying `ownerOf(0)` on the hook).

### CEI Pattern in `_decorateBannyWithBackground()`
- **v6:** Updates all state (`_attachedBackgroundIdOf`, `_userOf`) before any external transfers. Previous background transfer-out happens after state updates.
- **v5:** Transferred the previous background out *before* updating state for the new background, creating a less safe interaction ordering.

### Background Category Validation
- **v5:** Only checked `backgroundProduct.id == 0` to reject invalid backgrounds.
- **v6:** Also checks `backgroundProduct.category != _BACKGROUND_CATEGORY`, ensuring only actual background-category items can be used as backgrounds.

### Outfit Re-equip Optimization
- **v6:** When cleaning up remaining previous outfits, checks `_isInArray(previousOutfitId, outfitIds)` to skip outfits being re-equipped, avoiding unnecessary transfer-out-and-back-in cycles.
- **v5:** Would transfer the outfit out and then transfer it back in during the same transaction.

### Improved Loop Guard in `_decorateBannyWithOutfits()`
- **v5:** `while (previousOutfitProductCategory <= outfitProductCategory && previousOutfitProductCategory != 0)` -- stops on category 0 but could re-enter after exhaustion.
- **v6:** `while (previousOutfitId != 0 && previousOutfitProductCategory <= outfitProductCategory)` -- guards on `previousOutfitId != 0` as primary condition, correctly handling removed tiers (category 0) by always processing and advancing past them.

### Re-check Ownership Before Transfer in `_decorateBannyWithOutfits()`
- **v5:** Cached `owner = IERC721(hook).ownerOf(outfitId)` at the top of the loop, then later checked `if (owner != address(this))`.
- **v6:** Re-checks `IERC721(hook).ownerOf(outfitId) != address(this)` at transfer time, avoiding stale ownership data after intermediate transfers.

---

## 3. Event Changes

### Added
| Event | Signature |
|-------|-----------|
| `SetMetadata` | `SetMetadata(string description, string externalUrl, string baseUri, address caller)` |

### Removed
| Event | Signature |
|-------|-----------|
| `SetSvgBaseUri` | `SetSvgBaseUri(string baseUri, address caller)` |

### Unchanged
| Event | Notes |
|-------|-------|
| `DecorateBanny` | Same signature in both versions |
| `SetProductName` | Same signature in both versions |
| `SetSvgContent` | Same signature in both versions |
| `SetSvgHash` | Same signature in both versions |

### `msg.sender` Replaced with `_msgSender()` in Event Emissions
- **v5:** `setProductNames()`, `setSvgBaseUri()`, `setSvgContentsOf()`, and `setSvgHashsOf()` used `msg.sender` in event emissions.
- **v6:** All event emissions consistently use `_msgSender()` (ERC-2771 compatible).

---

## 4. Error Changes

### Added
| Error | Purpose |
|-------|---------|
| `Banny721TokenUriResolver_ArrayLengthMismatch()` | Reverts when batch setter arrays have mismatched lengths |
| `Banny721TokenUriResolver_BannyBodyNotBodyCategory()` | Reverts when `decorateBannyWith()` is called with a non-body-category token |

### Unchanged
| Error |
|-------|
| `Banny721TokenUriResolver_CantAccelerateTheLock()` |
| `Banny721TokenUriResolver_ContentsAlreadyStored()` |
| `Banny721TokenUriResolver_ContentsMismatch()` |
| `Banny721TokenUriResolver_HashAlreadyStored()` |
| `Banny721TokenUriResolver_HashNotFound()` |
| `Banny721TokenUriResolver_HeadAlreadyAdded()` |
| `Banny721TokenUriResolver_OutfitChangesLocked()` |
| `Banny721TokenUriResolver_SuitAlreadyAdded()` |
| `Banny721TokenUriResolver_UnauthorizedBackground()` |
| `Banny721TokenUriResolver_UnauthorizedBannyBody()` |
| `Banny721TokenUriResolver_UnauthorizedOutfit()` |
| `Banny721TokenUriResolver_UnauthorizedTransfer()` |
| `Banny721TokenUriResolver_UnorderedCategories()` |
| `Banny721TokenUriResolver_UnrecognizedBackground()` |
| `Banny721TokenUriResolver_UnrecognizedCategory()` |
| `Banny721TokenUriResolver_UnrecognizedProduct()` |

---

## 5. Struct Changes

No struct changes. Both versions use `JB721Tier` from the respective `721-hook` dependency. Any changes to `JB721Tier` are upstream in `nana-721-hook-v6`.

---

## 6. Implementation Changes (Non-Interface)

### Token URI JSON Encoding Refactored
- **v5:** Single large `abi.encodePacked()` call with all JSON fields inlined in `tokenUriOf()`.
- **v6:** Split into `pricingMetadata` string built separately, then delegated to `_encodeTokenUri()`. Uses nested `abi.encodePacked()` to avoid "stack too deep".

### `_outfitContentsFor()` Signature Change
- **v5:** `_outfitContentsFor(address hook, uint256[] memory outfitIds)`
- **v6:** `_outfitContentsFor(address hook, uint256[] memory outfitIds, uint256 bodyUpc)` -- added `bodyUpc` parameter for correct default eyes selection.

### `_bannyBodySvgOf()` Relocated
- **v5:** Located after `_msgSender()` / `_msgData()` overrides (line ~700).
- **v6:** Relocated to immediately before `_categoryNameOf()` (line ~538), grouped with other internal view functions.

### `_contextSuffixLength()` Relocated
- **v5:** Located before `_bannyBodySvgOf()` (line ~562).
- **v6:** Relocated after `_categoryNameOf()` and `_bannyBodySvgOf()` (line ~616).

### Named Parameters in `JBIpfsDecoder.decode()` Calls
- **v5:** Positional arguments: `JBIpfsDecoder.decode(baseUri, ...)`.
- **v6:** Named arguments: `JBIpfsDecoder.decode({baseUri: baseUri, hexString: ...})`.

### NatDoc / Comment Improvements
- Typo fixes: "Nakes" to "Naked", "receieved" to "received", "prefered" to "preferred", "categorie's" to "category's", "transfered" to "transferred", "scg" to "svg", "lateset" to "latest".
- Added detailed NatDoc to all interface functions (v5 interface had no NatDoc).
- Added documentation for outfit travel behavior on banny body transfer.
- Added documentation for unbounded array gas considerations on `_attachedOutfitIdsOf`.
- Added detailed authorization rules in `decorateBannyWith()` NatDoc (6-point checklist).
- Added warning about outfit/background travel on banny body transfer.
- Added comment about `transferFrom` vs `safeTransferFrom` limitation in `onERC721Received`.

### Lint Suppression Comments
- **v6 adds:** `// forge-lint: disable-next-line(mixed-case-variable)` above `DEFAULT_ALIEN_EYES`, `DEFAULT_MOUTH`, `DEFAULT_NECKLACE`, `DEFAULT_STANDARD_EYES`, and `BANNY_BODY`.

### Import Order Change
- **v5:** `@bananapus` imports first, then OpenZeppelin imports.
- **v6:** OpenZeppelin imports first, then `@bananapus` imports.

### Slither Annotations
- **v6 adds:** `// slither-disable-next-line calls-loop` on several `IERC721(hook).ownerOf()` calls inside loops.
- **v6 adds:** `// slither-disable-next-line encode-packed-collision` on the `_encodeTokenUri()` return.

---

## 7. Migration Table

| v5 Function / Event | v6 Equivalent | Notes |
|---|---|---|
| `setSvgBaseUri(string)` | `setMetadata(string, string, string)` | Now sets description + external URL + base URI together |
| `setSvgHashsOf(uint256[], bytes32[])` | `setSvgHashesOf(uint256[], bytes32[])` | Renamed (typo fix) |
| `SetSvgBaseUri` event | `SetMetadata` event | Different parameters |
| N/A | `svgDescription` (state variable) | New |
| N/A | `svgExternalUrl` (state variable) | New |
| N/A | `Banny721TokenUriResolver_ArrayLengthMismatch` | New error |
| N/A | `Banny721TokenUriResolver_BannyBodyNotBodyCategory` | New error |
| `_transferFrom()` (for returning items) | `_tryTransferFrom()` | Fault-tolerant; `_transferFrom()` still exists for mandatory transfers |
| N/A | `_isInArray()` | New helper |
| N/A | `_encodeTokenUri()` | Extracted from `tokenUriOf()` |
| `_outfitContentsFor(hook, outfitIds)` | `_outfitContentsFor(hook, outfitIds, bodyUpc)` | Added `bodyUpc` param (bug fix) |
| `@bananapus/721-hook-v5` | `@bananapus/721-hook-v6` | Dependency upgrade |
| `pragma solidity 0.8.23` | `pragma solidity 0.8.28` | Compiler version bump |

> **Cross-repo impact**: The `pricingContext()` return change (3 values → 2) is driven by the upstream `nana-721-hook-v6` `IJB721TiersHook` interface change. The `@bananapus/721-hook-v6` dependency brings in the new tier splits system, though Banny Retail does not use tier splits.
