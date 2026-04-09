# Changelog

## Scope

This file describes the verified change from `banny-retail-v5` to the current `banny-retail-v6` repo.

## Current v6 surface

- `Banny721TokenUriResolver`
- `IBanny721TokenUriResolver`

## Summary

- Decoration flows now handle previously equipped assets more defensively. The v6 test suite adds explicit regression coverage for removed tiers, failed return transfers, and stranded-asset scenarios.
- Metadata management is broader than in v5. The resolver now manages description, external URL, and base URI together instead of only a base URI path.
- Validation is stricter. v6 adds array-length checks on batch setters and extra checks around valid body and background categories before decoration logic proceeds.
- The repo was upgraded to the v6 dependency set and Solidity `0.8.28`.

## Verified deltas

- `setSvgBaseUri(...)` was replaced by `setMetadata(description, url, baseUri)`.
- Metadata JSON is no longer hardcoded around a fixed description and external URL. Those values now come from contract state.
- `pricingContext()` consumption changed with the v6 721 hook and now uses the two-value return shape.
- The resolver adds explicit `Banny721TokenUriResolver_ArrayLengthMismatch()` and `Banny721TokenUriResolver_BannyBodyNotBodyCategory()` errors.
- Outfit and background handling now includes logic intended to preserve attachment state when a previously equipped asset cannot be returned cleanly.
- (L-1) `_storeOutfitsWithRetained` now verifies that no two merged outfits share the same category after sorting. A retained outfit whose transfer failed could previously duplicate a category supplied in the new outfit set, leading to rendering artifacts. The new `Banny721TokenUriResolver_DuplicateCategory()` error prevents this.
- Gas optimizations: all `for` loops use `unchecked { ++i; }` increments, `_sortOutfitsByCategory` pre-computes categories to avoid repeated external calls during sort comparisons, `_msgSender()` is cached once per entry point to avoid repeated ERC-2771 context reads, and the mannequin SVG style string is inlined to remove redundant `string.concat` overhead.

## Migration notes

- Treat `setMetadata` as the metadata-management entry point. v5 assumptions around a base-URI-only setter no longer fit this repo.
- Decoration flows should be reviewed for failure handling, especially if an integration assumed every previously equipped NFT could always be transferred back out.
- Event and error expectations should be regenerated from the v6 ABI rather than copied from v5.
