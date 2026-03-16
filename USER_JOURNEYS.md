# banny-retail-v6 -- User Journeys

Every interaction path through `Banny721TokenUriResolver`, traced from entry point to final state. All function signatures and line references are verified against `src/Banny721TokenUriResolver.sol`.

---

## Journey 1: Buy a Naked Banny

The resolver does not handle minting. Banny bodies are minted through the Juicebox 721 tier system. This journey is included for context because it produces the token that all other journeys depend on.

### Entry Point

Payment to a `JBMultiTerminal` for the project that owns the `JB721TiersHook`. The hook's `afterPayRecordedWith` callback mints a 721 token from the appropriate tier.

### What the Resolver Does

After minting, when any caller requests the token URI:

```
JB721TiersHook.tokenURI(tokenId)
  -> Banny721TokenUriResolver.tokenUriOf(hook, tokenId)
```

**Function**: `tokenUriOf(address hook, uint256 tokenId) external view returns (string memory)` (line 200)

### Parameters

- `hook`: The `JB721TiersHook` contract address.
- `tokenId`: The minted token ID (e.g., `4_000_000_001` for Original Banny #1).

### State Read

1. `_productOfTokenId(hook, tokenId)` calls `hook.STORE().tierOfTokenId(hook, tokenId, false)`.
2. If `product.category == 0` (body), calls `svgOf(hook, tokenId, true, true)`.
3. `svgOf` calls `assetIdsOf(hook, tokenId)` which returns empty arrays (no outfits or background attached).
4. The body SVG is composed with default accessories (necklace, eyes, mouth) and no custom outfits.

### Result

A base64-encoded data URI containing JSON metadata with:
- Product name (Alien, Pink, Orange, or Original).
- Category name ("Banny body").
- An SVG image with the naked banny body and default accessories.
- Empty `outfitIds` array, `backgroundId: 0`.

### Edge Cases

- **Token ID does not exist**: `_productOfTokenId` returns a tier with `id == 0`. Function returns `""` (line 205).
- **SVG content not uploaded**: Falls back to IPFS URI via `JBIpfsDecoder` (line 303).
- **Token from category > 17**: Falls back to hook's `baseURI()` for IPFS resolution (line 300).

---

## Journey 2: Dress a Banny with Outfits

### Entry Point

```solidity
function decorateBannyWith(
    address hook,
    uint256 bannyBodyId,
    uint256 backgroundId,
    uint256[] calldata outfitIds
) external nonReentrant
```

Line 977. Protected by `ReentrancyGuard`.

### Prerequisites

- Caller owns the banny body NFT (`IERC721(hook).ownerOf(bannyBodyId) == _msgSender()`).
- Body is not locked (`outfitLockedUntil[hook][bannyBodyId] <= block.timestamp`).
- Caller owns each outfit NFT directly, or owns the banny body currently wearing that outfit.
- Caller owns the background NFT directly (or owns the banny body currently using it), if `backgroundId != 0`.
- Caller has approved the resolver for the hook contract (`hook.setApprovalForAll(resolver, true)`).

### Parameters

- `hook`: The `JB721TiersHook` contract address.
- `bannyBodyId`: Token ID of the banny body being dressed. Must be category 0.
- `backgroundId`: Token ID of the background to attach. Pass `0` for no background.
- `outfitIds`: Array of outfit token IDs. Must be in ascending category order (categories 2-17). Pass `[]` for no outfits.

### State Changes

**Checks (lines 987-997)**:
1. `_checkIfSenderIsOwner(hook, bannyBodyId)` -- reverts `UnauthorizedBannyBody` if caller is not the body owner.
2. `_productOfTokenId(hook, bannyBodyId).category` must equal 0 -- reverts `BannyBodyNotBodyCategory`.
3. `outfitLockedUntil[hook][bannyBodyId]` must be `<= block.timestamp` -- reverts `OutfitChangesLocked`.

**Event emission (line 999)**:
```
DecorateBanny(hook, bannyBodyId, backgroundId, outfitIds, _msgSender())
```

**Background processing (`_decorateBannyWithBackground`, line 1155)**:

If the background is changing:
- `_attachedBackgroundIdOf[hook][bannyBodyId]` is updated to `backgroundId` (or cleared to 0).
- `_userOf[hook][backgroundId]` is set to `bannyBodyId`.
- Old background NFT is returned to caller via `_tryTransferFrom` (silent failure OK).
- New background NFT is transferred into the resolver via `_transferFrom` (reverts on failure).

**Outfit processing (`_decorateBannyWithOutfits`, line 1222)**:

For each new outfit:
- Authorization verified: caller owns the outfit or the body wearing it.
- Category validated: in range 2-17, ascending order, no conflicts.
- Old outfits up to the current category are transferred out via `_tryTransferFrom`.
- New outfit transferred into the resolver via `_transferFrom` (if not already held).
- `_wearerOf[hook][outfitId]` set to `bannyBodyId`.

After all new outfits are processed:
- Remaining old outfits are transferred out.
- `_attachedOutfitIdsOf[hook][bannyBodyId]` is overwritten with the new `outfitIds` array (line 1368).

### Example: Dress with Hat and Glasses

```
Precondition: Alice owns body #4_000_000_001 (Original, category 0)
              Alice owns hat #5_000_000_001 (category 4, Head)
              Alice owns glasses #6_000_000_001 (category 6, Glasses)
              Alice has called hook.setApprovalForAll(resolver, true)

Call: decorateBannyWith(hook, 4_000_000_001, 0, [5_000_000_001, 6_000_000_001])

REVERTS -- Head (category 4) blocks Glasses (category 6) per conflict rule.
```

```
Corrected: decorateBannyWith(hook, 4_000_000_001, 0, [5_000_000_001])

Result:
  - Hat NFT transferred from Alice to resolver.
  - _wearerOf[hook][5_000_000_001] = 4_000_000_001
  - _attachedOutfitIdsOf[hook][4_000_000_001] = [5_000_000_001]
  - Body's tokenURI now renders with hat layer.
```

### Edge Cases

- **Empty outfitIds with backgroundId=0**: Strips all outfits and background. All previously equipped NFTs returned to caller.
- **Outfit already worn by this body**: Not re-transferred. `_wearerOf` retains existing value. The outfit stays in resolver custody.
- **Outfit worn by another body owned by caller**: Authorized via `ownerOf(wearerId) == _msgSender()`. The outfit is unlinked from the old body and transferred to the new body's custody.
- **Burned outfit in previous set**: `_tryTransferFrom` silently fails. The burned outfit is removed from the attachment array but no NFT is returned.
- **Removed tier in previous set**: `_productOfTokenId` returns category 0. The while loop processes it (category 0 <= any new category) and transfers it out.
- **Categories not ascending**: Reverts `UnorderedCategories`.
- **Duplicate categories**: Reverts `UnorderedCategories` (equality fails the `<` check).
- **Category 0 or 1 as outfit**: Reverts `UnrecognizedCategory`.
- **Reentrancy via safeTransferFrom callback**: Blocked by `nonReentrant` modifier.

---

## Journey 3: Undress a Banny

Undressing is not a separate function. It is performed by calling `decorateBannyWith` with empty arrays.

### Entry Point

```solidity
decorateBannyWith(hook, bannyBodyId, 0, [])
```

### Parameters

- `hook`: The hook address.
- `bannyBodyId`: The banny body to undress.
- `backgroundId`: `0` (remove background).
- `outfitIds`: `[]` (remove all outfits).

### State Changes

1. All checks pass (ownership, not locked, body category).
2. **Background**: `_attachedBackgroundIdOf[hook][bannyBodyId]` set to 0. Old background NFT returned to caller.
3. **Outfits**: The new `outfitIds` array is empty, so the merge loop does not execute. The tail loop transfers out all previous outfits. `_attachedOutfitIdsOf[hook][bannyBodyId]` set to `[]`.
4. All outfit NFTs and the background NFT are returned to `_msgSender()`.

### Partial Undress

To remove some outfits but keep others, pass only the outfits you want to keep:

```
Before: outfitIds = [hat, glasses, necklace]
Call:    decorateBannyWith(hook, bodyId, backgroundId, [necklace])
After:  hat and glasses returned to caller, necklace stays equipped.
```

### Edge Cases

- **Body is locked**: Reverts `OutfitChangesLocked`. Cannot undress during lock period.
- **Some equipped outfits were burned**: `_tryTransferFrom` silently fails for burned tokens. No revert, no NFT returned for those tokens.
- **Caller is not the current owner**: Reverts `UnauthorizedBannyBody`. This can happen if the body was recently transferred.

---

## Journey 4: Lock a Banny

### Entry Point

```solidity
function lockOutfitChangesFor(
    address hook,
    uint256 bannyBodyId
) public
```

Line 1013.

### Prerequisites

- Caller owns the banny body NFT.

### Parameters

- `hook`: The hook address.
- `bannyBodyId`: The banny body to lock.

### State Changes

1. `_checkIfSenderIsOwner(hook, bannyBodyId)` -- reverts `UnauthorizedBannyBody` if not owner.
2. `newLockUntil = block.timestamp + 7 days` (line 1021).
3. If `currentLockedUntil > newLockUntil`, reverts `CantAccelerateTheLock` (line 1024).
4. `outfitLockedUntil[hook][bannyBodyId] = newLockUntil` (line 1027).

### Result

The body cannot have its outfits or background changed until `block.timestamp > outfitLockedUntil[hook][bannyBodyId]`.

### Use Case: Marketplace Sale

```
1. Alice owns body #1 dressed with rare hat and suit.
2. Alice calls lockOutfitChangesFor(hook, bodyId).
3. Alice lists body #1 on marketplace.
4. Bob buys body #1. Body transfers to Bob.
5. Lock persists -- Bob receives the body with guaranteed outfits.
6. After 7 days, Bob can undress and receive the hat and suit NFTs.
```

### Edge Cases

- **Relocking while already locked**: Succeeds if the new expiry is >= the current expiry. Since `newLockUntil = block.timestamp + 7 days`, this effectively extends the lock by whatever time remains.
- **Locking an undressed body**: Valid. The body is locked with no outfits. No outfits can be added during the lock period.
- **Lock after transfer**: The new owner can lock. The old owner cannot (they no longer pass `_checkIfSenderIsOwner`).
- **Lock does not prevent body transfer**: The lock only affects `decorateBannyWith`. The body NFT can still be transferred on the hook contract.
- **No admin override**: The contract owner cannot unlock a body. The lock must expire naturally.

---

## Journey 5: Transfer a Decorated Banny

The resolver does not intercept or control body transfers. Body transfers happen on the `JB721TiersHook` contract. The resolver observes the ownership change lazily.

### What Happens

1. Alice transfers body #1 to Bob via the hook contract (`hook.safeTransferFrom(alice, bob, bodyId)`).
2. No resolver functions are called during the transfer.
3. The resolver's state remains unchanged:
   - `_attachedOutfitIdsOf[hook][bodyId]` still contains the outfit array.
   - `_attachedBackgroundIdOf[hook][bodyId]` still contains the background ID.
   - `_wearerOf[hook][outfitId]` still maps each outfit to `bodyId`.
   - `_userOf[hook][backgroundId]` still maps to `bodyId`.
4. All equipped outfit and background NFTs remain held by the resolver.

### What Bob Can Do

Bob now owns the body. All resolver authorization checks (`_checkIfSenderIsOwner`) will pass for Bob.

- **Undress**: `decorateBannyWith(hook, bodyId, 0, [])` returns all equipped NFTs to Bob.
- **Redress**: `decorateBannyWith(hook, bodyId, newBg, [newOutfits])` replaces outfits. Old outfits returned to Bob (even though Alice originally equipped them).
- **Lock**: `lockOutfitChangesFor(hook, bodyId)` locks the body under Bob's control.

### What Alice Can No Longer Do

Alice cannot call `decorateBannyWith` or `lockOutfitChangesFor` for that body -- she no longer owns it.

### Edge Cases

- **Alice equipped valuable outfits and forgot to undress before selling**: Bob receives full control of all equipped NFTs. This is the intended behavior but creates a seller gotcha. The lock mechanism exists to make this explicit (sellers lock, then sell at a higher price including outfits).
- **Body transferred while locked**: Lock persists. Bob cannot change outfits until the lock expires.
- **Body transferred to a contract**: The new contract owner must be able to call `decorateBannyWith`. If the contract does not implement this call, equipped outfits are effectively locked forever (until the contract is upgraded or has a function to make this call).
- **Double transfer (Alice -> Bob -> Charlie)**: Only Charlie can interact with the body's outfits. Each transfer implicitly transfers outfit control.

---

## Journey 6: Move an Outfit Between Bodies

A user who owns multiple bodies can move an equipped outfit from one body to another in a single call.

### Entry Point

```solidity
decorateBannyWith(hook, newBodyId, 0, [outfitId])
```

Where `outfitId` is currently equipped on `oldBodyId`, and the caller owns both bodies.

### Prerequisites

- Caller owns `newBodyId`.
- Caller owns `oldBodyId` (which currently wears the outfit).
- `newBodyId` is not locked.

### State Changes

1. Authorization passes: caller does not own the outfit directly (resolver holds it), but caller owns `oldBodyId` which is the `wearerOf(hook, outfitId)`.
2. `_wearerOf[hook][outfitId]` is updated to `newBodyId` (line 1331).
3. The outfit is not transferred (resolver already holds it, line 1335 check).
4. `_attachedOutfitIdsOf[hook][newBodyId]` is set to the new array including this outfit.
5. `_attachedOutfitIdsOf[hook][oldBodyId]` is NOT explicitly updated. However, `wearerOf(hook, outfitId)` will now return `newBodyId`, so `assetIdsOf(hook, oldBodyId)` will exclude this outfit from its filtered result.

### Edge Cases

- **Old body is locked**: The lock is on `oldBodyId`, but the caller is calling `decorateBannyWith` on `newBodyId`. The lock only prevents changes to the locked body, not removal of its outfits via a different body's decoration call. **Wait -- verify this**: The outfit's `wearerOf` returns `oldBodyId`. The caller owns `oldBodyId`. The authorization check at line 1266 checks `ownerOf(wearerId)` which is the caller. So this succeeds. However, `oldBodyId`'s `_attachedOutfitIdsOf` still contains the outfit. The outfit has been moved at the `_wearerOf` level, but the old array is stale. This is handled by `assetIdsOf` which filters by checking `wearerOf` (line 383). **Auditors should verify the lock on `oldBodyId` does not prevent this path.** The lock check is only in `decorateBannyWith` at line 995, and it checks the body being decorated (`bannyBodyId`), not the body being undressed.

---

## Journey 7: Admin -- Store SVG Content

### Step 1: Commit Hashes

**Entry Point**:
```solidity
function setSvgHashesOf(
    uint256[] memory upcs,
    bytes32[] memory svgHashes
) external onlyOwner
```

Line 1130.

**Parameters**:
- `upcs`: Array of universal product codes to set hashes for.
- `svgHashes`: Array of `keccak256` hashes of the SVG content strings.

**State Changes**:
- `svgHashOf[upc] = svgHash` for each pair.
- Reverts `HashAlreadyStored` if any UPC already has a hash set.
- Emits `SetSvgHash(upc, svgHash, caller)`.

### Step 2: Upload Content

**Entry Point**:
```solidity
function setSvgContentsOf(
    uint256[] memory upcs,
    string[] calldata svgContents
) external
```

Line 1100. **Not restricted to owner** -- anyone can upload content as long as it matches the hash.

**Parameters**:
- `upcs`: Array of universal product codes to upload content for.
- `svgContents`: Array of SVG content strings (without wrapping `<svg>` tags).

**State Changes**:
- Reverts `ContentsAlreadyStored` if content already set for this UPC.
- Reverts `HashNotFound` if no hash set for this UPC.
- Reverts `ContentsMismatch` if `keccak256(abi.encodePacked(svgContent)) != svgHashOf[upc]`.
- `_svgContentOf[upc] = svgContent`.
- Emits `SetSvgContent(upc, svgContent, caller)`.

### Edge Cases

- **Hash set but content never uploaded**: `_svgOf` falls back to IPFS resolution. Tokens render with IPFS images instead of on-chain SVG.
- **Content with special characters**: Stored verbatim. No sanitization. A `<script>` tag in SVG content would be included in the data URI.
- **Multiple UPCs in one call**: Array lengths must match or `ArrayLengthMismatch` reverts. The entire call reverts if any single UPC fails.

---

## Journey 8: Admin -- Set Metadata and Product Names

### Set Metadata

**Entry Point**:
```solidity
function setMetadata(
    string calldata description,
    string calldata url,
    string calldata baseUri
) external onlyOwner
```

Line 1065.

**State Changes**:
- `svgDescription = description`
- `svgExternalUrl = url`
- `svgBaseUri = baseUri`
- All three fields are always overwritten. Pass current values for fields you do not want to change. Pass `""` to clear.

### Set Product Names

**Entry Point**:
```solidity
function setProductNames(
    uint256[] memory upcs,
    string[] memory names
) external onlyOwner
```

Line 1084.

**State Changes**:
- `_customProductNameOf[upc] = name` for each pair.
- Unlike SVG hashes and content, names are **not write-once**. Names can be overwritten.
- Built-in names for UPCs 1-4 (Alien, Pink, Orange, Original) are hardcoded in `_productNameOf` (line 896-909) and cannot be overridden by this function. The `_productNameOf` function checks UPCs 1-4 first and returns the hardcoded name before checking `_customProductNameOf`.

### Edge Cases

- **Overwriting a product name**: No revert. The old name is replaced. This could change how existing NFTs display.
- **Setting name for UPCs 1-4**: The `_customProductNameOf` mapping is written, but `_productNameOf` returns the hardcoded name first. The custom name is never read for these UPCs.
- **Empty name string**: Valid. Sets the custom name to empty, causing `_productNameOf` to return `""` for that UPC.

---

## Journey 9: View Functions -- Query Banny State

### Get Attached Assets

```solidity
function assetIdsOf(
    address hook,
    uint256 bannyBodyId
) public view returns (uint256 backgroundId, uint256[] memory outfitIds)
```

Line 356.

Returns the currently attached background and outfits. Filters by checking `wearerOf` and `userOf` for each stored ID, excluding outfits that have been moved to other bodies.

### Get Outfit Wearer

```solidity
function wearerOf(address hook, uint256 outfitId) public view returns (uint256)
```

Line 509. Returns the body ID wearing this outfit, or 0 if unworn. Verifies the outfit is still in the body's `_attachedOutfitIdsOf` array.

### Get Background User

```solidity
function userOf(address hook, uint256 backgroundId) public view returns (uint256)
```

Line 494. Returns the body ID using this background, or 0 if unused. Verifies the background is still the body's `_attachedBackgroundIdOf` entry.

### Get SVG

```solidity
function svgOf(
    address hook,
    uint256 tokenId,
    bool shouldDressBannyBody,
    bool shouldIncludeBackgroundOnBannyBody
) public view returns (string memory)
```

Line 434. Returns the composed SVG for any token. For bodies, can toggle dressing and background. For non-bodies, returns the outfit/background SVG alone.

### Get Names

```solidity
function namesOf(
    address hook,
    uint256 tokenId
) public view returns (string memory, string memory, string memory)
```

Line 406. Returns (fullName, categoryName, productName).

### Get Lock Status

```solidity
mapping(address hook => mapping(uint256 upc => uint256)) public outfitLockedUntil;
```

Line 96. Directly readable. Returns the timestamp until which the body is locked, or 0 if never locked.

---

## Summary: State Machine per Banny Body

```
                     +-----------+
                     |   NAKED   |
                     | (minted)  |
                     +-----+-----+
                           |
                  decorateBannyWith(outfits)
                           |
                     +-----v-----+
                     |  DRESSED  |<----+
                     |           |     |
                     +-----+-----+     |
                           |           |
             +-------------+-------+   |
             |                     |   |
    decorateBannyWith([])  decorateBannyWith(newOutfits)
             |                     |
       +-----v-----+              +---+
       |   NAKED   |
       +-----+-----+
             |
    lockOutfitChangesFor()
             |
       +-----v-----+
       |   LOCKED   |
       | (7 days)   |
       +-----+-----+
             |
       block.timestamp > lockUntil
             |
       +-----v-----+
       | UNLOCKED  |
       | (NAKED)   |
       +-----------+
```

The lock state applies equally to dressed and naked bodies. A dressed body can be locked, preventing outfit changes. A naked body can be locked, preventing outfit additions.

Body transfers do not change the resolver state. The new owner inherits the current state (dressed/naked, locked/unlocked) and all custody rights.
