# V5 to V6 Changelog

## Scope

This is a V5-to-V6 migration changelog, not a package release log or commit history. It compares `banny-retail-v5` in `../../v5/evm` with the current `banny-retail-v6` repo.

## Current V6 Surface

- `Banny721TokenUriResolver`
- `IBanny721TokenUriResolver`

## Summary

- Metadata management changed from a base-URI-only model to a single metadata setter for description, external URL, and base URI.
- Several ABI names were cleaned up: v5's misspelled `setSvgHashsOf(...)` became `setSvgHashesOf(...)`, and the uppercase constant-style art getters became lower-camel interface getters.
- The resolver now consumes the V6 721 hook pricing/context shape and should be compiled against the V6 721 hook ABI.
- Decoration flows are more defensive. V6 validates array lengths, body/background categories, duplicate categories, and failed return transfers more explicitly.
- SVG and metadata output can change in ways that V5 indexers should not treat as a pure URI-prefix update.

## ABI, Event, and Error Changes

- Removed or replaced functions:
  - `setSvgBaseUri(string)` -> `setMetadata(string description, string url, string baseUri)`
  - `setSvgHashsOf(uint256[],bytes32[])` -> `setSvgHashesOf(uint256[],bytes32[])`
  - uppercase art getters such as `BANNY_BODY()` are exposed through lower-camel getters such as `bannyBody()`
- Added view surface:
  - `svgDescription()`
  - `svgExternalUrl()`
- Added or migration-sensitive events:
  - `SetMetadata`
  - `SetSvgHash`
  - existing decoration/content events should be regenerated from the V6 interface because argument names and setter names changed.
- Added or migration-sensitive errors include:
  - `Banny721TokenUriResolver_ArrayLengthMismatch`
  - `Banny721TokenUriResolver_BannyBodyNotBodyCategory`
  - `Banny721TokenUriResolver_DuplicateCategory`
  - `Banny721TokenUriResolver_HashAlreadyStored`
  - `Banny721TokenUriResolver_HashNotFound`
  - `Banny721TokenUriResolver_UnrecognizedBackground`

## Machine-Checked ABI Coverage

Generated from Foundry `out/**/*.json` artifacts, filtered to this repo's own runtime source roots and excluding tests, scripts, and dependencies.

- V5 comparison package: `banny-retail-v5`.
- Own-source ABI artifacts compared: V6 `2`, V5 `2`.
- Contract/interface coverage: `0` added, `0` removed, `2` shared names with ABI changes, `0` shared names ABI-identical.
- Shared-name ABI item deltas: `37` added, `30` removed, `0` modified.

Shared ABI artifacts with changes:
- `Banny721TokenUriResolver`: `28` added, `23` removed, `0` modified ABI items.
- `IBanny721TokenUriResolver`: `9` added, `7` removed, `0` modified ABI items.

Generated event/error name deltas:
- Event names added:
  - `SetMetadata`.
- Event names removed or replaced:
  - `SetSvgBaseUri`.
- Error names added:
  - `Banny721TokenUriResolver_ArrayLengthMismatch`, `Banny721TokenUriResolver_BannyBodyNotBodyCategory`, `Banny721TokenUriResolver_CantAccelerateTheLock`, `Banny721TokenUriResolver_ContentsAlreadyStored`, `Banny721TokenUriResolver_ContentsMismatch`, `Banny721TokenUriResolver_DuplicateCategory`, `Banny721TokenUriResolver_HashAlreadyStored`, `Banny721TokenUriResolver_HashNotFound`.
  - `Banny721TokenUriResolver_HeadAlreadyAdded`, `Banny721TokenUriResolver_OutfitChangesLocked`, `Banny721TokenUriResolver_SuitAlreadyAdded`, `Banny721TokenUriResolver_UnauthorizedBackground`, `Banny721TokenUriResolver_UnauthorizedBannyBody`, `Banny721TokenUriResolver_UnauthorizedOutfit`, `Banny721TokenUriResolver_UnauthorizedTransfer`, `Banny721TokenUriResolver_UnorderedCategories`.
  - `Banny721TokenUriResolver_UnrecognizedBackground`, `Banny721TokenUriResolver_UnrecognizedCategory`, `Banny721TokenUriResolver_UnrecognizedProduct`.
- Error names removed or replaced:
  - `Banny721TokenUriResolver_CantAccelerateTheLock`, `Banny721TokenUriResolver_ContentsAlreadyStored`, `Banny721TokenUriResolver_ContentsMismatch`, `Banny721TokenUriResolver_HashAlreadyStored`, `Banny721TokenUriResolver_HashNotFound`, `Banny721TokenUriResolver_HeadAlreadyAdded`, `Banny721TokenUriResolver_OutfitChangesLocked`, `Banny721TokenUriResolver_SuitAlreadyAdded`.
  - `Banny721TokenUriResolver_UnauthorizedBackground`, `Banny721TokenUriResolver_UnauthorizedBannyBody`, `Banny721TokenUriResolver_UnauthorizedOutfit`, `Banny721TokenUriResolver_UnauthorizedTransfer`, `Banny721TokenUriResolver_UnorderedCategories`, `Banny721TokenUriResolver_UnrecognizedBackground`, `Banny721TokenUriResolver_UnrecognizedCategory`, `Banny721TokenUriResolver_UnrecognizedProduct`.

## Migration Notes

- Regenerate the resolver ABI. Do not keep a V5 ABI with only the base URI setter renamed manually.
- Update any admin tooling that calls `setSvgBaseUri(...)` or `setSvgHashsOf(...)`.
- Review decoration UX for failed outgoing NFT transfers. V6 can retain previously equipped assets when returning them fails, instead of assuming the transfer always succeeds.
