# banny-retail-v6 -- Audit Instructions

Target: `Banny721TokenUriResolver` -- a single-contract system that manages on-chain SVG-based NFT composition for the Juicebox V6 Banny ecosystem.

## Contract Table

| Contract | Lines | Role |
|----------|-------|------|
| `Banny721TokenUriResolver` | ~1,428 | Token URI resolver, outfit custody, SVG storage, decoration logic, lock mechanism |
| `IBanny721TokenUriResolver` | ~175 | Interface: events, view functions, mutating functions |

Inheritance chain: `Ownable`, `ERC2771Context`, `ReentrancyGuard`, `IJB721TokenUriResolver`, `IBanny721TokenUriResolver`, `IERC721Receiver`.

Compiler: Solidity ^0.8.26, Cancun EVM, via-IR optimizer (200 runs).

## Architecture Overview

The resolver serves as both a **token URI generator** and an **NFT custodian**. It is registered as the URI resolver for a `JB721TiersHook` (the Juicebox 721 tier system). When a marketplace or wallet requests `tokenURI()`, the hook delegates to this resolver, which composes layered SVG artwork on-chain.

The resolver does not mint or burn tokens. It holds outfit and background NFTs in custody on behalf of banny body owners, and generates composed SVG output by layering those assets.

```
JB721TiersHook (the NFT contract)
    |
    v
Banny721TokenUriResolver (this contract)
    |-- holds outfit/background NFTs in custody
    |-- generates composed SVG token URIs
    |-- enforces decoration rules and lock mechanism
    |
    v
JB721TiersHookStore (read-only: tier metadata lookups)
```

## Core Concepts

### Token ID Structure

Token IDs encode product information: `tierId * 1_000_000_000 + sequenceNumber`. The `tierId` (called "UPC" or "product ID" in the codebase) maps to a tier in `JB721TiersHookStore`, which returns a `JB721Tier` struct containing `id`, `category`, `price`, `initialSupply`, `remainingSupply`, and other fields.

### Category System

There are 18 categories (0-17), each representing a layer or slot:

| ID | Constant | Name | Role |
|----|----------|------|------|
| 0 | `_BODY_CATEGORY` | Banny body | Base character (Alien, Pink, Orange, Original) |
| 1 | `_BACKGROUND_CATEGORY` | Background | Scene behind the banny |
| 2 | `_BACKSIDE_CATEGORY` | Backside | Behind-body accessories |
| 3 | `_NECKLACE_CATEGORY` | Necklace | Has special layering (after suit top) |
| 4 | `_HEAD_CATEGORY` | Head | Full head piece -- **blocks** Eyes, Glasses, Mouth, HeadTop |
| 5 | `_EYES_CATEGORY` | Eyes | Blocked by Head |
| 6 | `_GLASSES_CATEGORY` | Glasses | Blocked by Head |
| 7 | `_MOUTH_CATEGORY` | Mouth | Blocked by Head |
| 8 | `_LEGS_CATEGORY` | Legs | Leg wear |
| 9 | `_SUIT_CATEGORY` | Suit | Full suit -- **blocks** SuitBottom, SuitTop |
| 10 | `_SUIT_BOTTOM_CATEGORY` | Suit bottom | Blocked by Suit |
| 11 | `_SUIT_TOP_CATEGORY` | Suit top | Blocked by Suit |
| 12 | `_HEADTOP_CATEGORY` | Head top | Blocked by Head |
| 13 | `_HAND_CATEGORY` | Fist | Hand accessory |
| 14 | `_SPECIAL_SUIT_CATEGORY` | Special Suit | Special outfit slot |
| 15 | `_SPECIAL_LEGS_CATEGORY` | Special Legs | Special outfit slot |
| 16 | `_SPECIAL_HEAD_CATEGORY` | Special Head | Special outfit slot |
| 17 | `_SPECIAL_BODY_CATEGORY` | Special Body | Special outfit slot |

Categories 0 and 1 cannot be used as outfits (enforced at line 1299). Outfits must be categories 2-17.

### Conflict Rules

Two conflict rules prevent contradictory outfits:
1. **Head blocks face pieces**: If category 4 (Head) is equipped, categories 5 (Eyes), 6 (Glasses), 7 (Mouth), and 12 (HeadTop) are rejected (line 1312-1318).
2. **Suit blocks top/bottom**: If category 9 (Suit) is equipped, categories 10 (SuitBottom) and 11 (SuitTop) are rejected (line 1319-1323).

Outfits must be passed in **ascending category order** (line 1304-1305). No two outfits can share a category.

## Outfit Decoration System

### How Dressing Works

`decorateBannyWith(hook, bannyBodyId, backgroundId, outfitIds)` is the single entry point for all decoration changes. There is no separate "undress" function -- undressing is accomplished by calling `decorateBannyWith` with an empty `outfitIds` array and `backgroundId = 0`.

The function:
1. Verifies the caller owns the banny body (line 993).
2. Verifies the body token is actually category 0 (line 996).
3. Verifies the body is not locked (line 1001).
4. Delegates background handling to `_decorateBannyWithBackground` (line 1010).
5. Delegates outfit handling to `_decorateBannyWithOutfits` (line 1013).

### Background Decoration (`_decorateBannyWithBackground`, line 1173)

- If `backgroundId != 0`, the caller must own the background NFT or own the banny body currently using it.
- The background must be category 1 (`_BACKGROUND_CATEGORY`).
- State updates (`_attachedBackgroundIdOf`, `_userOf`) happen before external transfers (CEI pattern).
- The old background is returned via `_tryTransferFrom` (silent failure on burned tokens).
- The new background is transferred into the resolver via `_transferFrom` (reverts on failure).

### Outfit Decoration (`_decorateBannyWithOutfits`, line 1243)

This is the most complex function. It performs a **merge-style iteration** over two arrays: the new `outfitIds` and the previously equipped `previousOutfitIds`.

For each new outfit:
1. Authorization: caller must own the outfit OR own the banny body currently wearing it (lines 1278-1293).
2. Category validation: must be 2-17, ascending order, no conflicts (lines 1299-1324).
3. The inner `while` loop transfers out old outfits up to the current category (lines 1332-1350).
4. If the outfit is not already worn by this body, state is updated and the outfit is transferred in (lines 1353-1361).

After all new outfits are processed, a second `while` loop (line 1372) transfers out any remaining old outfits.

Finally, `_attachedOutfitIdsOf[hook][bannyBodyId]` is overwritten wholesale with the new array (line 1392).

## Custody Model

This is the highest-stakes part of the system.

**Who holds the NFT**: When an outfit or background is equipped, the NFT is transferred from the caller to the resolver contract via `safeTransferFrom`. The resolver holds custody. The NFT is returned to the body owner when:
- The body is redressed and the outfit is no longer in the new set.
- The body is dressed with an empty outfit array (full undress).
- The outfit is moved to a different body owned by the same person.

**Transfer implications**: When a banny body NFT is transferred on the hook contract, all equipped outfits and the background remain associated with that body. The new body owner can call `decorateBannyWith` with empty arrays to receive all equipped NFTs. This is by design but creates a significant gotcha for sellers who forget to undress before selling.

**No admin rescue**: The owner role has no function to force-return custody NFTs. If a bug prevents undressing, equipped NFTs are permanently locked.

**`_tryTransferFrom` vs `_transferFrom`**: Returning old outfits uses `_tryTransferFrom` (try-catch, silent failure) because the token may have been burned or its tier removed. Equipping new outfits uses `_transferFrom` (reverts on failure) because the caller is asserting ownership of a token that must exist.

### Key Invariant

Every outfit NFT held by the resolver must be recoverable by the current owner of the banny body it is associated with.

## Lock Mechanism

`lockOutfitChangesFor(hook, bannyBodyId)` locks a body for 7 days (`_LOCK_DURATION = 7 days = 604,800 seconds`). While locked, `decorateBannyWith` reverts with `OutfitChangesLocked`.

Rules:
- Only the body owner can lock (line 1021).
- Lock can only be extended, never shortened (line 1030). Attempting to set a shorter lock reverts with `CantAccelerateTheLock`.
- Equal-time relocks succeed (the `>` check allows `currentLockedUntil == newLockUntil`).
- The lock survives body transfers -- a buyer who receives a locked body cannot change outfits until the lock expires.
- The `outfitLockedUntil` mapping is public and readable by marketplaces.

**Purpose**: Enables trustless NFT marketplace sales of dressed bannys. A seller locks the body, lists it, and the buyer is guaranteed to receive the advertised outfit set.

## SVG Storage and Rendering

### Hash-Then-Reveal Pattern

1. Owner calls `setSvgHashesOf(upcs, svgHashes)` to commit `keccak256` hashes (line 1138). Hashes are write-once per UPC.
2. Anyone calls `setSvgContentsOf(upcs, svgContents)` to reveal content (line 1108). Content must match the stored hash. Content is write-once per UPC.
3. If content is not yet uploaded, `_svgOf` falls back to IPFS resolution via `JBIpfsDecoder` (line 936-949).

### SVG Composition

`tokenUriOf` (line 203) builds a complete on-chain data URI:
1. For non-body tokens: renders the outfit SVG on a grey mannequin banny.
2. For body tokens: composes background + body + all outfit layers in category order.

The body SVG uses CSS classes (`.b1`-`.b4`, `.a1`-`.a3`) with color fills specific to each body type (Alien=green, Pink=pink, Orange=orange, Original=yellow).

Default accessories (necklace, eyes, mouth) are injected when no custom outfit occupies that slot. The necklace has special layering: it is stored during iteration but rendered after `_SUIT_TOP_CATEGORY` (line 885-890).

### SVG Sanitization

**There is none.** SVG content is stored and rendered verbatim. The hash-commit pattern ensures only owner-approved content is stored, but the content itself is not sanitized. A malicious or compromised owner could commit hashes for SVGs containing `<script>` tags, external resource references (`<image href="https://...">`), or CSS injection.

## Meta-Transaction Support (ERC-2771)

The contract inherits `ERC2771Context` with an immutable `trustedForwarder` set at construction. All authorization checks use `_msgSender()` instead of `msg.sender`.

If `trustedForwarder == address(0)` (the default in all test setups), meta-transactions are effectively disabled -- `_msgSender()` returns `msg.sender`.

If a non-zero forwarder is set, that forwarder contract can append arbitrary sender addresses to calldata, allowing gasless transactions. The forwarder is fully trusted and can impersonate any address for all operations.

**Risk**: If the forwarder is compromised, all authorization checks (body ownership, outfit authorization, lock, admin functions) can be bypassed.

## `onERC721Received` Gate

The resolver implements `IERC721Receiver.onERC721Received` (line 1044) and rejects all incoming transfers unless `operator == address(this)`. This means:
- Only the resolver itself can send NFTs to itself (via its own `_transferFrom` calls).
- Users cannot accidentally send NFTs directly to the resolver.
- If a user sends an NFT via `transferFrom` (not `safeTransferFrom`), the callback is not triggered and the NFT is silently deposited. This is an inherent ERC-721 limitation.

## Priority Audit Areas

### 1. Outfit Authorization Logic (CRITICAL)

File: `src/Banny721TokenUriResolver.sol`, lines 1278-1293.

The authorization check for outfits allows the caller to use an outfit if they either own it directly or own the banny body currently wearing it. A historical bug (L18, now fixed) allowed `ownerOf(0)` bypass when `wearerOf` returned 0 for unworn outfits. Verify the current fix is sound:
- Line 1283: `if (wearerId == 0) revert` -- ensures unworn outfits require direct ownership.
- Line 1287: `ownerOf(wearerId)` -- verifies caller owns the body wearing the outfit.

Look for: any path where an attacker can pass authorization without actually owning the outfit or the body wearing it.

### 2. Merge Iteration in `_decorateBannyWithOutfits` (HIGH)

Lines 1271-1392. The merge between new `outfitIds` and `previousOutfitIds` is complex. The inner `while` loop advances through previous outfits, transferring them out. The second `while` loop (line 1372) handles remaining previous outfits.

Look for:
- Off-by-one errors in the `previousOutfitIndex` counter.
- Skipped outfits that should be returned.
- Double-transfer of outfits (both in the inner while and the tail while).
- Removed-tier outfits (category=0) causing infinite loops or skipped entries.
- The `_isInArray` check at line 1376 preventing outfits in the new set from being transferred out.

### 3. Custody Accounting Consistency (HIGH)

State variables: `_attachedOutfitIdsOf`, `_attachedBackgroundIdOf`, `_wearerOf`, `_userOf`.

These four mappings must remain consistent. After every `decorateBannyWith` call:
- Every outfit in `_attachedOutfitIdsOf[hook][bodyId]` should have `_wearerOf[hook][outfitId] == bodyId`.
- The background in `_attachedBackgroundIdOf[hook][bodyId]` should have `_userOf[hook][backgroundId] == bodyId`.
- Every outfit/background held by the resolver should be tracked in these mappings.

**Note**: `_attachedOutfitIdsOf` is overwritten wholesale at line 1392, but `_wearerOf` is only set for *new* outfits at line 1355. Outfits that were already worn by this body retain their `_wearerOf` entry from the previous call. Verify this does not cause stale state.

### 4. `_tryTransferFrom` Silent Failures (MEDIUM)

Line 1424-1428. When returning old outfits, transfer failures are silently caught. This is intentional (handles burned tokens) but could mask real bugs.

Look for: scenarios where `_tryTransferFrom` silently fails but the state mappings (`_wearerOf`, `_attachedOutfitIdsOf`) have already been updated, causing an outfit to be "lost" -- not held by the resolver, not returned to the owner, but still tracked as worn.

### 5. Cross-Hook Isolation (MEDIUM)

All state mappings are keyed by `address hook`. The `hook` parameter is caller-supplied and never validated. A malicious hook contract could return arbitrary data from `ownerOf()`, `STORE()`, `tierOfTokenId()`.

Verify: a malicious hook cannot affect outfits custodied from a different (legitimate) hook. The per-hook mapping keys should provide full isolation.

### 6. CEI Ordering in Background Replacement (MEDIUM)

`_decorateBannyWithBackground` (lines 1212-1224) updates state before transfers. Verify:
- `_attachedBackgroundIdOf` and `_userOf` are updated at lines 1213-1214 before the try-transfer at line 1218 and the incoming transfer at line 1223.
- No reachable state where a reentrancy callback during the safeTransferFrom at line 1223 could observe inconsistent state.

### 7. SVG Content Safety (LOW)

SVG content is stored verbatim. While this is a view-function-only concern, verify that the encoding in `_encodeTokenUri` (line 628) cannot produce malformed JSON that breaks parsers. Specifically check for unescaped characters in `svgDescription`, `svgExternalUrl`, and custom product names injected into the JSON.

## Key Invariants to Test

1. **Outfit recoverability**: Every outfit NFT held by the resolver can be recovered by the current body owner via `decorateBannyWith(hook, bodyId, 0, [])`.
2. **No orphaned custody**: After `decorateBannyWith`, the resolver does not hold any outfit NFTs that are not tracked in `_attachedOutfitIdsOf` or `_attachedBackgroundIdOf`.
3. **Category ascending order**: `_attachedOutfitIdsOf[hook][bodyId]` always contains outfits in ascending category order.
4. **Lock monotonicity**: `outfitLockedUntil[hook][bodyId]` can only increase or remain the same.
5. **Cross-hook isolation**: Operations on hook A never transfer, modify, or read custody state from hook B.
6. **SVG hash/content immutability**: Once `svgHashOf[upc]` is set, it cannot be changed. Once `_svgContentOf[upc]` is set, it cannot be changed.
7. **ReentrancyGuard blocks re-entry**: No call to `decorateBannyWith` can re-enter itself.

## Testing Setup

**Framework**: Foundry (forge). Config in `foundry.toml`.

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/Fork.t.sol -vvv

# Run fork tests (requires RPC_ETHEREUM_MAINNET env var)
RPC_ETHEREUM_MAINNET=<your-rpc-url> forge test --match-path test/Fork.t.sol -vvv

# Gas report
forge test --gas-report
```

**Test suite**: 14 test files, ~230+ tests.

| File | Purpose |
|------|---------|
| `Banny721TokenUriResolver.t.sol` | Unit tests with mock hook/store |
| `DecorateFlow.t.sol` | Authorization flows, L18 fix proof, multi-party |
| `BannyAttacks.t.sol` | Adversarial: outfit theft, lock bypass, category abuse |
| `Fork.t.sol` | End-to-end with real JB infrastructure, reentrancy |
| `regression/CEIReorder.t.sol` | CEI ordering verification |
| `regression/RemovedTierDesync.t.sol` | Removed tier handling |
| `regression/ArrayLengthValidation.t.sol` | Array mismatch reverts |
| `regression/BodyCategoryValidation.t.sol` | Non-body token rejection |
| `regression/MsgSenderEvents.t.sol` | ERC-2771 event correctness |
| `regression/BurnedTokenCheck.t.sol` | Burned token handling |
| `regression/ClearMetadata.t.sol` | Metadata clearing |
| `OutfitTransferLifecycle.t.sol` | Outfit transfer lifecycle flows |
| `TestAuditGaps.sol` | Audit gap coverage: ERC-2771 meta-transaction flows (forwarder relay, spoofing prevention, owner-only relay), SVG rendering edge cases (special characters, script tags, unicode, long content, JSON-breaking chars), SVG composition validation (default decorations, alien vs standard eyes, background inclusion/exclusion) |
| `TestQALastMile.t.sol` | QA last-mile edge cases |

**Untested areas** (potential audit additions):
- Meta-transaction flows with a real forwarder (basic coverage exists in TestAuditGaps.sol; advanced scenarios with a real forwarder remain untested -- all tests use `address(0)`).
- SVG content containing special characters or potential injection payloads (basic coverage exists in TestAuditGaps.sol for script tags, unicode, JSON-breaking chars, and long content; advanced payloads remain untested).
- Gas consumption for `tokenUriOf` with maximum outfit count.
- Ownership transfer of the resolver (`transferOwnership`) and continued admin access.
- Product name overwriting (no write-once protection on `_customProductNameOf`).
- The `transferFrom` (non-safe) path where NFTs bypass `onERC721Received`.

## External Dependencies

| Dependency | Used For |
|------------|----------|
| OpenZeppelin `Ownable` | Admin access control |
| OpenZeppelin `ERC2771Context` | Meta-transaction sender extraction |
| OpenZeppelin `ReentrancyGuard` | Reentrancy protection on `decorateBannyWith` |
| OpenZeppelin `Strings` | `uint256.toString()` for metadata |
| `base64` (lib) | Base64 encoding for data URIs |
| `@bananapus/721-hook-v6` | `IJB721TiersHook`, `IJB721TiersHookStore`, `JBIpfsDecoder`, `JB721Tier`, `IERC721` |

The resolver makes external calls to the `hook` and its `STORE()` but does not call any core Juicebox protocol contracts (no terminal, controller, or directory interactions).

## Error Reference

| Error | Trigger |
|-------|---------|
| `ArrayLengthMismatch` | `upcs.length != svgHashes/svgContents/names.length` |
| `BannyBodyNotBodyCategory` | `bannyBodyId` is not category 0 |
| `CantAccelerateTheLock` | New lock expires sooner than current lock |
| `ContentsAlreadyStored` | SVG content already set for this UPC |
| `ContentsMismatch` | SVG content hash does not match stored hash |
| `HashAlreadyStored` | SVG hash already set for this UPC |
| `HashNotFound` | No hash set for this UPC (cannot upload content) |
| `HeadAlreadyAdded` | Conflict: Head + Eyes/Glasses/Mouth/HeadTop |
| `OutfitChangesLocked` | Body is locked, cannot change outfits |
| `SuitAlreadyAdded` | Conflict: Suit + SuitBottom/SuitTop |
| `UnauthorizedBackground` | Caller does not own the background |
| `UnauthorizedBannyBody` | Caller does not own the banny body |
| `UnauthorizedOutfit` | Caller does not own the outfit or its wearer's body |
| `UnauthorizedTransfer` | NFT sent to resolver not by resolver itself |
| `UnorderedCategories` | Outfits not in ascending category order |
| `UnrecognizedBackground` | Token is not category 1 |
| `UnrecognizedCategory` | Outfit category not in 2-17 range |
| `UnrecognizedProduct` | Body UPC not 1-4 (Alien/Pink/Orange/Original) |

## How to Report Findings

For each finding:

1. **Title** -- one line, starts with severity (CRITICAL/HIGH/MEDIUM/LOW)
2. **Affected contract(s)** -- exact file path and line numbers
3. **Description** -- what is wrong, in plain language
4. **Trigger sequence** -- step-by-step, minimal steps to reproduce
5. **Impact** -- what an attacker gains, what a user loses
6. **Proof** -- code trace or Foundry test
7. **Fix** -- minimal code change

**Severity guide:**
- **CRITICAL**: Permanent NFT custody loss, unauthorized outfit theft.
- **HIGH**: Conditional NFT loss, authorization bypass, broken custody invariant.
- **MEDIUM**: State inconsistency without fund loss, griefing that locks outfits.
- **LOW**: Cosmetic SVG issues, informational, edge-case-only.

## Previous Audit Findings

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| L18 | HIGH | FIXED | `ownerOf(0)` bypass in outfit authorization. When `wearerOf` returned 0 for unworn outfits, `hook.ownerOf(0)` could succeed for some hooks, allowing unauthorized outfit use. Fixed by adding `if (wearerId == 0) revert` guard at line 1283. Regression test in `DecorateFlow.t.sol`. |
