# banny-retail-v6 -- User Journeys

All interaction paths through `Banny721TokenUriResolver`, traced from entry point to final state. All function signatures, events, and revert names are verified against `src/Banny721TokenUriResolver.sol` and `src/interfaces/IBanny721TokenUriResolver.sol`.

---

## Journey 1: Buy a Naked Banny

The resolver does not handle minting. Banny bodies are minted through the Juicebox 721 tier system. This journey is included for context because it produces the token that all other journeys depend on.

**Entry point**: Payment to a `JBMultiTerminal` for the project that owns the `JB721TiersHook`. The hook's `afterPayRecordedWith` callback mints a 721 token from the appropriate tier.

**Who can call**: Anyone (via `JBMultiTerminal.pay`).

After minting, when any caller requests the token URI:

```
JB721TiersHook.tokenURI(tokenId)
  -> Banny721TokenUriResolver.tokenUriOf(hook, tokenId)
```

**Function**: `tokenUriOf(address hook, uint256 tokenId) external view returns (string memory)`

**Parameters**:
- `hook` -- The `JB721TiersHook` contract address
- `tokenId` -- The minted token ID (e.g., `4_000_000_001` for Original Banny #1)

**State read**:
1. `_productOfTokenId(hook, tokenId)` calls `hook.STORE().tierOfTokenId(hook, tokenId, false)`
2. If `product.category == 0` (body), calls `svgOf(hook, tokenId, true, true)`
3. `svgOf` calls `assetIdsOf(hook, tokenId)` which returns empty arrays (no outfits or background attached)
4. The body SVG is composed with default accessories (necklace, eyes, mouth) and no custom outfits

**Result**: A base64-encoded data URI containing JSON metadata with:
- Product name (Alien, Pink, Orange, or Original)
- Category name ("Banny body")
- An SVG image with the naked banny body and default accessories
- Empty `outfitIds` array, `backgroundId: 0`

**Events**: None (view function).

**Edge cases**:
- **Token ID does not exist**: `_productOfTokenId` returns a tier with `id == 0`. Function returns `""`
- **SVG content not uploaded**: Falls back to IPFS URI via `JBIpfsDecoder`
- **Token from category > 17**: Falls back to hook's `baseURI()` for IPFS resolution
- **Unrecognized product**: Reverts `Banny721TokenUriResolver_UnrecognizedProduct`

---

## Journey 2: Dress a Banny with Outfits

**Entry point**: `Banny721TokenUriResolver.decorateBannyWith(address hook, uint256 bannyBodyId, uint256 backgroundId, uint256[] calldata outfitIds)`

**Who can call**: The owner of the banny body NFT (`IERC721(hook).ownerOf(bannyBodyId) == _msgSender()`). Protected by `ReentrancyGuard`. ERC-2771 meta-transactions supported.

**Prerequisites**:
- Caller owns the banny body NFT
- Body is not locked (`outfitLockedUntil[hook][bannyBodyId] <= block.timestamp`)
- Caller owns each outfit NFT directly, or owns the banny body currently wearing that outfit
- Caller owns the background NFT directly (or owns the banny body currently using it), if `backgroundId != 0`
- Caller has approved the resolver for the hook contract (`hook.setApprovalForAll(resolver, true)`)

**Parameters**:
- `hook` -- The `JB721TiersHook` contract address
- `bannyBodyId` -- Token ID of the banny body being dressed. Must be category 0
- `backgroundId` -- Token ID of the background to attach. Pass `0` for no background
- `outfitIds` -- Array of outfit token IDs. Must be in ascending category order (categories 2--17). Pass `[]` for no outfits

**State changes**:
1. `_checkIfSenderIsOwner(hook, bannyBodyId)` -- verifies caller owns the body
2. `_productOfTokenId(hook, bannyBodyId).category` must equal `_BODY_CATEGORY` (0)
3. `outfitLockedUntil[hook][bannyBodyId]` must be `<= block.timestamp`
4. Background processing (`_decorateBannyWithBackground`) -- only executes if the background is changing (new `backgroundId` differs from the current one, or the current background is no longer assigned to this body):
   - `_attachedBackgroundIdOf[hook][bannyBodyId]` updated to `backgroundId` (or cleared to 0)
   - If `backgroundId != 0`: `_userOf[hook][backgroundId]` set to `bannyBodyId`
   - If a previous background was assigned to this body: old background NFT returned to caller via `_tryTransferFrom` (silent failure OK)
   - If `backgroundId != 0` and the resolver does not already hold the new background: new background NFT transferred into the resolver via `_transferFrom` (reverts on failure)
5. Outfit processing (`_decorateBannyWithOutfits`):
   - For each new outfit not already worn by this body: `_wearerOf[hook][outfitId]` set to `bannyBodyId`
   - If there are previous outfits in categories up to the current one: old outfits transferred out via `_tryTransferFrom`
   - For each new outfit not already held by the resolver: transferred into the resolver via `_transferFrom`
   - `_attachedOutfitIdsOf[hook][bannyBodyId]` overwritten with the new `outfitIds` array

**Events**: `DecorateBanny(address indexed hook, uint256 indexed bannyBodyId, uint256 indexed backgroundId, uint256[] outfitIds, address caller)` -- emitted before state changes, where `caller = _msgSender()`

**Edge cases**:
- **Empty outfitIds with backgroundId=0**: Strips all outfits and background. All previously equipped NFTs returned to caller
- **Outfit already worn by this body**: Not re-transferred. `_wearerOf` retains existing value. The outfit stays in resolver custody
- **Outfit worn by another body owned by caller**: Authorized via `ownerOf(wearerId) == _msgSender()`. The outfit is unlinked from the old body and transferred to the new body's custody
- **Burned outfit in previous set**: `_tryTransferFrom` silently fails. The burned outfit is removed from the attachment array but no NFT is returned
- **Removed tier in previous set**: `_productOfTokenId` returns category 0. The while loop processes it (category 0 <= any new category) and transfers it out
- **Categories not ascending**: Reverts `Banny721TokenUriResolver_UnorderedCategories`
- **Duplicate categories**: Reverts `Banny721TokenUriResolver_UnorderedCategories` (equality fails the `<` check)
- **Category outside 2--17 as outfit**: Reverts `Banny721TokenUriResolver_UnrecognizedCategory`
- **Head category conflict**: Reverts `Banny721TokenUriResolver_HeadAlreadyAdded`
- **Suit category conflict**: Reverts `Banny721TokenUriResolver_SuitAlreadyAdded`
- **Unauthorized background**: Reverts `Banny721TokenUriResolver_UnauthorizedBackground`
- **Unauthorized outfit**: Reverts `Banny721TokenUriResolver_UnauthorizedOutfit`
- **Unrecognized background category**: Reverts `Banny721TokenUriResolver_UnrecognizedBackground`
- **Source body is locked**: Reverts `Banny721TokenUriResolver_OutfitChangesLocked` (via `_revertIfBodyLocked`)
- **Reentrancy via safeTransferFrom callback**: Blocked by `nonReentrant` modifier

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

---

## Journey 3: Undress a Banny

Undressing is not a separate function. It is performed by calling `decorateBannyWith` with empty arrays.

**Entry point**: `Banny721TokenUriResolver.decorateBannyWith(address hook, uint256 bannyBodyId, 0, [])`

**Who can call**: The owner of the banny body NFT.

**Parameters**:
- `hook` -- The hook address
- `bannyBodyId` -- The banny body to undress
- `backgroundId` -- `0` (remove background)
- `outfitIds` -- `[]` (remove all outfits)

**State changes**:
1. All checks pass (ownership, not locked, body category)
2. If a background was attached: `_attachedBackgroundIdOf[hook][bannyBodyId]` set to 0, and old background NFT returned to caller via `_tryTransferFrom` (silent failure if burned)
3. The new `outfitIds` array is empty, so the merge loop does not execute. If there are previous outfits: the tail loop transfers out all previous outfits still assigned to this body via `_tryTransferFrom`
4. `_attachedOutfitIdsOf[hook][bannyBodyId]` set to `[]`
5. All previously equipped outfit and background NFTs that still exist are returned to `_msgSender()`

**Events**: `DecorateBanny(hook, bannyBodyId, 0, [], caller)`

**Partial undress**: To remove some outfits but keep others, pass only the outfits you want to keep:

```
Before: outfitIds = [hat, glasses, necklace]
Call:    decorateBannyWith(hook, bodyId, backgroundId, [necklace])
After:  hat and glasses returned to caller, necklace stays equipped.
```

**Edge cases**:
- **Body is locked**: Reverts `Banny721TokenUriResolver_OutfitChangesLocked`. Cannot undress during lock period
- **Some equipped outfits were burned**: `_tryTransferFrom` silently fails for burned tokens. No revert, no NFT returned for those tokens
- **Caller is not the current owner**: Reverts `Banny721TokenUriResolver_UnauthorizedBannyBody`. This can happen if the body was recently transferred

---

## Journey 4: Lock a Banny

**Entry point**: `Banny721TokenUriResolver.lockOutfitChangesFor(address hook, uint256 bannyBodyId)`

**Who can call**: The owner of the banny body NFT (`IERC721(hook).ownerOf(bannyBodyId) == _msgSender()`).

**Parameters**:
- `hook` -- The hook address
- `bannyBodyId` -- The banny body to lock

**State changes**:
1. `_checkIfSenderIsOwner(hook, bannyBodyId)` -- verifies caller owns the body
2. `newLockUntil = block.timestamp + 7 days` (constant `_LOCK_DURATION`)
3. If `currentLockedUntil > newLockUntil`, reverts
4. `outfitLockedUntil[hook][bannyBodyId] = newLockUntil`

**Events**: None. The `lockOutfitChangesFor` function does not emit an event.

**Edge cases**:
- **Relocking while already locked**: Succeeds if the new expiry is >= the current expiry. Since `newLockUntil = block.timestamp + 7 days`, this effectively extends the lock by whatever time remains
- **Attempting to shorten the lock**: Reverts `Banny721TokenUriResolver_CantAccelerateTheLock`
- **Locking an undressed body**: Valid. The body is locked with no outfits. No outfits can be added during the lock period
- **Lock after transfer**: The new owner can lock. The old owner cannot (they no longer pass `_checkIfSenderIsOwner`)
- **Lock does not prevent body transfer**: The lock only affects `decorateBannyWith`. The body NFT can still be transferred on the hook contract
- **No admin override**: The contract owner cannot unlock a body. The lock must expire naturally

### Use Case: Marketplace Sale

```
1. Alice owns body #1 dressed with rare hat and suit.
2. Alice calls lockOutfitChangesFor(hook, bodyId).
3. Alice lists body #1 on marketplace.
4. Bob buys body #1. Body transfers to Bob.
5. Lock persists -- Bob receives the body with guaranteed outfits.
6. After 7 days, Bob can undress and receive the hat and suit NFTs.
```

---

## Journey 5: Transfer a Decorated Banny

The resolver does not intercept or control body transfers. Body transfers happen on the `JB721TiersHook` contract. The resolver observes the ownership change lazily.

**Entry point**: `JB721TiersHook.safeTransferFrom(address from, address to, uint256 tokenId)` (standard ERC-721 transfer on the hook contract, not the resolver)

**Who can call**: The body owner, or an approved operator on the hook contract.

**State changes**:
1. No resolver functions are called during the transfer
2. Resolver state remains unchanged:
   - `_attachedOutfitIdsOf[hook][bodyId]` still contains the outfit array
   - `_attachedBackgroundIdOf[hook][bodyId]` still contains the background ID
   - `_wearerOf[hook][outfitId]` still maps each outfit to `bodyId`
   - `_userOf[hook][backgroundId]` still maps to `bodyId`
3. All equipped outfit and background NFTs remain held by the resolver

**Events**: None from the resolver. The hook emits the standard ERC-721 `Transfer(from, to, tokenId)`.

**What the new owner (Bob) can do**:
- **Undress**: `decorateBannyWith(hook, bodyId, 0, [])` returns all equipped NFTs to Bob
- **Redress**: `decorateBannyWith(hook, bodyId, newBg, [newOutfits])` replaces outfits. Old outfits returned to Bob (even though Alice originally equipped them)
- **Lock**: `lockOutfitChangesFor(hook, bodyId)` locks the body under Bob's control

**What Alice can no longer do**: Alice cannot call `decorateBannyWith` or `lockOutfitChangesFor` for that body -- she no longer owns it.

**Edge cases**:
- **Alice equipped valuable outfits and forgot to undress before selling**: Bob receives full control of all equipped NFTs. This is the intended behavior but creates a seller gotcha. The lock mechanism exists to make this explicit (sellers lock, then sell at a higher price including outfits)
- **Body transferred while locked**: Lock persists. Bob cannot change outfits until the lock expires
- **Body transferred to a contract**: The new contract owner must be able to call `decorateBannyWith`. If the contract does not implement this call, equipped outfits are effectively locked forever (until the contract is upgraded or has a function to make this call)
- **Double transfer (Alice -> Bob -> Charlie)**: Only Charlie can interact with the body's outfits. Each transfer implicitly transfers outfit control

---

## Journey 6: Move an Outfit Between Bodies

A user who owns multiple bodies can move an equipped outfit from one body to another in a single call.

**Entry point**: `Banny721TokenUriResolver.decorateBannyWith(address hook, uint256 newBodyId, 0, [outfitId])`

Where `outfitId` is currently equipped on `oldBodyId`, and the caller owns both bodies.

**Who can call**: An address that owns both `newBodyId` and the body currently wearing the outfit (`oldBodyId`).

**Prerequisites**:
- Caller owns `newBodyId`
- Caller owns `oldBodyId` (which currently wears the outfit)
- `newBodyId` is not locked
- `oldBodyId` is not locked (enforced by `_revertIfBodyLocked`)

**State changes**:
1. Authorization passes: caller does not own the outfit directly (resolver holds it), but caller owns `oldBodyId` which is the `wearerOf(hook, outfitId)`
2. `_wearerOf[hook][outfitId]` updated to `newBodyId`
3. The outfit is not transferred (resolver already holds it)
4. `_attachedOutfitIdsOf[hook][newBodyId]` set to the new array including this outfit
5. `_attachedOutfitIdsOf[hook][oldBodyId]` is NOT explicitly updated. However, `wearerOf(hook, outfitId)` now returns `newBodyId`, so `assetIdsOf(hook, oldBodyId)` will exclude this outfit from its filtered result

**Events**: `DecorateBanny(hook, newBodyId, 0, [outfitId], caller)`

**Edge cases**:
- **Old body is locked**: Reverts `Banny721TokenUriResolver_OutfitChangesLocked` via `_revertIfBodyLocked`. A locked source body keeps its outfits and background until the lock expires, even if the caller owns both bodies

---

## Journey 7: Admin -- Store SVG Content

### Step 1: Commit Hashes

**Entry point**: `Banny721TokenUriResolver.setSvgHashesOf(uint256[] memory upcs, bytes32[] memory svgHashes)`

**Who can call**: Contract owner only (`onlyOwner` modifier, from OpenZeppelin `Ownable`).

**Parameters**:
- `upcs` -- Array of universal product codes to set hashes for
- `svgHashes` -- Array of `keccak256` hashes of the SVG content strings

**State changes**:
1. For each pair: `svgHashOf[upc] = svgHash`

**Events**: `SetSvgHash(uint256 indexed upc, bytes32 indexed svgHash, address caller)` -- emitted once per UPC in the array

**Edge cases**:
- **UPC already has a hash**: Reverts `Banny721TokenUriResolver_HashAlreadyStored` (write-once)
- **Array length mismatch**: Reverts `Banny721TokenUriResolver_ArrayLengthMismatch`
- **Partial failure**: The entire call reverts if any single UPC fails

### Step 2: Upload Content

**Entry point**: `Banny721TokenUriResolver.setSvgContentsOf(uint256[] memory upcs, string[] calldata svgContents)`

**Who can call**: Anyone. Not restricted to owner -- anyone can upload content as long as it matches the committed hash.

**Parameters**:
- `upcs` -- Array of universal product codes to upload content for
- `svgContents` -- Array of SVG content strings (without wrapping `<svg>` tags)

**State changes**:
1. For each pair: `_svgContentOf[upc] = svgContent`

**Events**: `SetSvgContent(uint256 indexed upc, string svgContent, address caller)` -- emitted once per UPC in the array

**Edge cases**:
- **Content already stored**: Reverts `Banny721TokenUriResolver_ContentsAlreadyStored` (write-once)
- **No hash set for UPC**: Reverts `Banny721TokenUriResolver_HashNotFound`
- **Content does not match hash**: Reverts `Banny721TokenUriResolver_ContentsMismatch` (checks `keccak256(abi.encodePacked(svgContent)) != svgHashOf[upc]`)
- **Array length mismatch**: Reverts `Banny721TokenUriResolver_ArrayLengthMismatch`
- **Hash set but content never uploaded**: `_svgOf` falls back to IPFS resolution. Tokens render with IPFS images instead of on-chain SVG
- **Content with special characters**: Stored verbatim. No sanitization. A `<script>` tag in SVG content would be included in the data URI

---

## Journey 8: Admin -- Set Metadata and Product Names

### Set Metadata

**Entry point**: `Banny721TokenUriResolver.setMetadata(string calldata description, string calldata url, string calldata baseUri)`

**Who can call**: Contract owner only (`onlyOwner` modifier).

**Parameters**:
- `description` -- The description to use in token metadata
- `url` -- The external URL to use in token metadata
- `baseUri` -- The base URI of the SVG files (used for IPFS fallback)

**State changes**:
1. `svgDescription = description`
2. `svgExternalUrl = url`
3. `svgBaseUri = baseUri`
4. All three fields are always overwritten. Pass current values for fields you do not want to change. Pass `""` to clear

**Events**: `SetMetadata(string description, string externalUrl, string baseUri, address caller)`

**Edge cases**:
- **Empty strings**: Valid. Clears the respective metadata field
- **Non-owner caller**: Reverts with OpenZeppelin `OwnableUnauthorizedAccount`

### Set Product Names

**Entry point**: `Banny721TokenUriResolver.setProductNames(uint256[] memory upcs, string[] memory names)`

**Who can call**: Contract owner only (`onlyOwner` modifier).

**Parameters**:
- `upcs` -- Array of universal product codes to name
- `names` -- Array of display names for each product

**State changes**:
1. For each pair: `_customProductNameOf[upc] = name`

**Events**: `SetProductName(uint256 indexed upc, string name, address caller)` -- emitted once per UPC in the array

**Edge cases**:
- **Overwriting a product name**: No revert. The old name is replaced. This could change how existing NFTs display (names are mutable, unlike SVG hashes/content)
- **Setting name for UPCs 1--4**: The `_customProductNameOf` mapping is written, but `_productNameOf` returns the hardcoded name first (Alien, Pink, Orange, Original). The custom name is never read for these UPCs
- **Empty name string**: Valid. Sets the custom name to empty, causing `_productNameOf` to return `""` for that UPC
- **Array length mismatch**: Reverts `Banny721TokenUriResolver_ArrayLengthMismatch`

---

## Journey 9: View Functions -- Query Banny State

All view functions. No access restrictions, no state changes, no events.

### Get Attached Assets

**Entry point**: `Banny721TokenUriResolver.assetIdsOf(address hook, uint256 bannyBodyId) public view returns (uint256 backgroundId, uint256[] memory outfitIds)`

**Who can call**: Anyone (view function).

**Parameters**:
- `hook` -- The hook address of the collection
- `bannyBodyId` -- The banny body to query

Returns the currently attached background and outfits. Filters by checking `wearerOf` and `userOf` for each stored ID, excluding outfits that have been moved to other bodies.

### Get Outfit Wearer

**Entry point**: `Banny721TokenUriResolver.wearerOf(address hook, uint256 outfitId) public view returns (uint256)`

**Who can call**: Anyone (view function).

**Parameters**:
- `hook` -- The hook address of the collection
- `outfitId` -- The outfit token ID to query

Returns the body ID wearing this outfit, or 0 if unworn. Verifies the outfit is still in the body's `_attachedOutfitIdsOf` array.

### Get Background User

**Entry point**: `Banny721TokenUriResolver.userOf(address hook, uint256 backgroundId) public view returns (uint256)`

**Who can call**: Anyone (view function).

**Parameters**:
- `hook` -- The hook address of the collection
- `backgroundId` -- The background token ID to query

Returns the body ID using this background, or 0 if unused. Verifies the background is still the body's `_attachedBackgroundIdOf` entry.

### Get SVG

**Entry point**: `Banny721TokenUriResolver.svgOf(address hook, uint256 tokenId, bool shouldDressBannyBody, bool shouldIncludeBackgroundOnBannyBody) public view returns (string memory)`

**Who can call**: Anyone (view function).

**Parameters**:
- `hook` -- The hook address of the collection
- `tokenId` -- The token ID to render
- `shouldDressBannyBody` -- Whether to include the banny body's attached outfits
- `shouldIncludeBackgroundOnBannyBody` -- Whether to include the banny body's attached background

Returns the composed SVG for any token. For bodies, can toggle dressing and background. For non-bodies, returns the outfit/background SVG alone.

### Get Names

**Entry point**: `Banny721TokenUriResolver.namesOf(address hook, uint256 tokenId) public view returns (string memory, string memory, string memory)`

**Who can call**: Anyone (view function).

**Parameters**:
- `hook` -- The hook address of the collection
- `tokenId` -- The token ID to look up

Returns `(fullName, categoryName, productName)`.

### Get Lock Status

**Entry point**: `Banny721TokenUriResolver.outfitLockedUntil(address hook, uint256 upc) public view returns (uint256)`

**Who can call**: Anyone (public mapping).

**Parameters**:
- `hook` -- The hook address of the collection
- `upc` -- The banny body token ID

Returns the timestamp until which the body is locked, or 0 if never locked.

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
                    +--+--+--+--+     |
                       |  |  |        |
          +------------+  |  +--------+
          |               |  decorateBannyWith(newOutfits)
 decorateBannyWith([])    |
          |               | lockOutfitChangesFor()
    +-----v-----+         |
    |   NAKED   |         |
    +-----+-----+         |
          |               |
 lockOutfitChangesFor()   |
          |               |
    +-----v---------------v--+
    |        LOCKED           |
    |       (7 days)          |
    +-----+-------------------+
          |
    block.timestamp > lockUntil
          |
    +-----v-----------+
    | UNLOCKED        |
    | (NAKED or       |
    |  DRESSED)       |
    +-----------------+
```

The lock state applies equally to dressed and naked bodies. A dressed body can be locked, preventing outfit changes. A naked body can be locked, preventing outfit additions.

Body transfers do not change the resolver state. The new owner inherits the current state (dressed/naked, locked/unlocked) and all custody rights.

---

## Events Reference

All events defined in `IBanny721TokenUriResolver`:

| Event | Emitted by | Signature |
|-------|-----------|-----------|
| `DecorateBanny` | `decorateBannyWith` | `DecorateBanny(address indexed hook, uint256 indexed bannyBodyId, uint256 indexed backgroundId, uint256[] outfitIds, address caller)` |
| `SetMetadata` | `setMetadata` | `SetMetadata(string description, string externalUrl, string baseUri, address caller)` |
| `SetProductName` | `setProductNames` | `SetProductName(uint256 indexed upc, string name, address caller)` |
| `SetSvgContent` | `setSvgContentsOf` | `SetSvgContent(uint256 indexed upc, string svgContent, address caller)` |
| `SetSvgHash` | `setSvgHashesOf` | `SetSvgHash(uint256 indexed upc, bytes32 indexed svgHash, address caller)` |

## Custom Errors Reference

All custom errors defined in `Banny721TokenUriResolver`:

| Error | Trigger |
|-------|---------|
| `Banny721TokenUriResolver_ArrayLengthMismatch` | `upcs` and values arrays have different lengths |
| `Banny721TokenUriResolver_BannyBodyNotBodyCategory` | `bannyBodyId` is not a category 0 (body) token |
| `Banny721TokenUriResolver_CantAccelerateTheLock` | New lock expiry would be earlier than current lock |
| `Banny721TokenUriResolver_ContentsAlreadyStored` | SVG content already uploaded for this UPC |
| `Banny721TokenUriResolver_ContentsMismatch` | SVG content hash does not match committed hash |
| `Banny721TokenUriResolver_HashAlreadyStored` | SVG hash already committed for this UPC |
| `Banny721TokenUriResolver_HashNotFound` | No hash committed for this UPC |
| `Banny721TokenUriResolver_HeadAlreadyAdded` | Outfit conflicts with an already-equipped head item |
| `Banny721TokenUriResolver_OutfitChangesLocked` | Body is locked and cannot change outfits |
| `Banny721TokenUriResolver_SuitAlreadyAdded` | Outfit conflicts with an already-equipped suit item |
| `Banny721TokenUriResolver_UnauthorizedBackground` | Caller does not own the background or the body using it |
| `Banny721TokenUriResolver_UnauthorizedBannyBody` | Caller does not own the banny body |
| `Banny721TokenUriResolver_UnauthorizedOutfit` | Caller does not own the outfit or the body wearing it |
| `Banny721TokenUriResolver_UnauthorizedTransfer` | NFT received from an external sender (not this contract) |
| `Banny721TokenUriResolver_UnorderedCategories` | Outfit categories are not in ascending order |
| `Banny721TokenUriResolver_UnrecognizedBackground` | Token is not a valid background category |
| `Banny721TokenUriResolver_UnrecognizedCategory` | Outfit category is not in the valid range (2--17) |
| `Banny721TokenUriResolver_UnrecognizedProduct` | Token does not belong to a recognized product tier |
