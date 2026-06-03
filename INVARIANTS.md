# Invariants of Banny NFT resolver

Scope: `Banny721TokenUriResolver` (the single src/ contract) — the custom on-chain URI resolver attached to the Banny project (revnet 4 / BAN) of the Juicebox V6 deployment. The resolver is wired to a `JB721TiersHook` instance; the hook handles tier minting and ownership, while the resolver composes equipped outfits + background SVGs into a single token URI.

Banny model in one sentence: **bodies are the carrier NFTs**; outfits and backgrounds are separate tier NFTs that, while "equipped", are held in the resolver's custody so their composed appearance follows the body wherever it goes.

| Concept | What it is | Custody when equipped |
|---|---|---|
| Body | tier with `category = _BODY_CATEGORY` (0) — carrier NFT | always owned by user |
| Background | tier with `category = _BACKGROUND_CATEGORY` (1) | held by resolver; `userOf(bg) = body` |
| Outfit | tiers with `category ∈ [2, 17]` | held by resolver; `wearerOf(outfit) = body` |
| Lock | `outfitLockedUntil[hook][body]`, max `7 days` from now | applies to a body, set by body owner only |

The resolver has one `Ownable` owner (referred to as the **resolver owner** below). The resolver owner is *not* the project's owner, the hook's owner, or any caller of the tiers hook directly — it only governs metadata strings, custom product names, and the SVG-hash pre-commit registry. All on-chain decoration is gated on **NFT ownership of the bodies/outfits/backgrounds**, not on the resolver owner.

---

## Section A — Guarantees to Banny NFT collectors

## A.1 Decoration authority is NFT-ownership-bound

`decorateBannyWith(hook, bannyBodyId, backgroundId, outfitIds[])` is the only mutating entrypoint that can change what a body wears. The function enforces ALL of the following before writing any state (`Banny721TokenUriResolver.sol:1127-1173`):

- **Caller owns the body.** Reads `IERC721(hook).ownerOf(bannyBodyId)`; reverts `Banny721TokenUriResolver_UnauthorizedBannyBody` if `!= _msgSender()`. The body cannot be dressed by anyone but its current ERC-721 owner.
- **Body is actually a body tier.** Reads the tier category and reverts `Banny721TokenUriResolver_BannyBodyNotBodyCategory` unless `category == _BODY_CATEGORY` (0). You cannot "decorate" an outfit/background tier.
- **Body is not locked.** Reads `outfitLockedUntil[hook][bannyBodyId]` and reverts `Banny721TokenUriResolver_OutfitChangesLocked` if `> block.timestamp`. A locked body's outfits cannot be changed by anyone — including its owner — until the lock expires.
- **For each outfit:** either the caller is the outfit's current ERC-721 owner, OR the outfit is currently worn by another body and the caller owns *that* body. In the second case, the source body must not itself be locked (`_revertIfBodyLocked`). An unworn outfit can only be equipped by its current owner — never "stolen" through the worn-body branch.
- **For the background:** identical rule — caller owns the background, or the background is in use by another body owned by the caller (and that body is not locked).
- **Categories are recognized and strictly ascending.** Reverts `Banny721TokenUriResolver_UnrecognizedCategory` if outside `[_BACKSIDE_CATEGORY=2, _SPECIAL_BODY_CATEGORY=17]`. Reverts `Banny721TokenUriResolver_UnorderedCategories` if any non-first outfit's category `≤` the previous one.
- **Full-coverage exclusivity.** A full `_HEAD_CATEGORY` (4) outfit blocks individual face accessories (`_EYES_CATEGORY=5`, `_GLASSES_CATEGORY=6`, `_MOUTH_CATEGORY=7`, `_HEADTOP_CATEGORY=12`); a full `_SUIT_CATEGORY` (9) outfit blocks `_SUIT_BOTTOM_CATEGORY=10` and `_SUIT_TOP_CATEGORY=11`. Violations revert `HeadAlreadyAdded` / `SuitAlreadyAdded`.
- **Reentrancy.** The function is `nonReentrant` (OpenZeppelin `ReentrancyGuard`).

## A.2 Equipped assets follow the body — with a clear warning

When an outfit or background is equipped, the resolver `safeTransferFrom`s it into its own custody and tracks logical ownership via `_wearerOf[hook][outfitId] = bannyBodyId` (resp. `_userOf[hook][backgroundId] = bannyBodyId`).

- Re-equipping or swapping that outfit returns the resolver-held NFT to the **current body owner** — which is also the caller.
- Transferring the body to a new ERC-721 owner does **not** automatically transfer the equipped outfit ERC-721s — they stay in the resolver — but it does transfer **logical control** of them. The new body owner can call `decorateBannyWith` to unequip them and receive the underlying outfit NFTs.
- This is explicitly documented in the source: "Sellers should unequip valuable outfits before transferring a banny body" (`Banny721TokenUriResolver.sol:1116-1120`).

## A.3 No stranding on swap

When a new outfit/background replaces an old one, the resolver attempts `_tryTransferFrom` (try/catch) to return the old asset to the caller (the body owner). If that transfer fails (e.g., the underlying tier was removed and the NFT is in an awkward state, or the recipient now rejects ERC-721 pushes):

- **Outfit path:** the previous outfit's slot is retained — `_storeOutfitsWithRetained` merges retained entries back into the attached list, re-validates category exclusivity, sorts, and rejects duplicate categories. The owner can retry. No outfit NFT is silently lost.
- **Background path:** when changing to a new background, a failed return of the old background causes the function to `return` without updating attachment state — the old background stays equipped and recoverable. When clearing the background (`backgroundId == 0`), a failed return leaves the old attachment record in place so the owner can retry.

## A.4 Locks are monotonic and bounded

`lockOutfitChangesFor(hook, bannyBodyId)` (`Banny721TokenUriResolver.sol:1178-1197`):

- Only callable by the body's current ERC-721 owner (`_checkIfSenderIsOwner`).
- Sets `outfitLockedUntil[hook][bannyBodyId] = block.timestamp + 7 days` — fixed at `_LOCK_DURATION`.
- **Monotonically non-decreasing.** If the current lock end exceeds the new computed end (i.e., the previous lock was already extended further into the future), the call reverts `CantAccelerateTheLock`. A body owner cannot shorten an existing lock — they can only refresh or extend it.

## A.5 Push-rejection on direct NFT transfers

`onERC721Received` (`Banny721TokenUriResolver.sol:1209-1230`) accepts a transfer only when `operator == address(this)` — i.e., only transfers the resolver itself initiated. External pushes via `safeTransferFrom` revert `Banny721TokenUriResolver_UnauthorizedTransfer`.

- An NFT pushed to the resolver via the **non-safe** `transferFrom` cannot be rejected (this is an inherent ERC-721 limitation, documented in the source). Such NFTs would be stranded in the resolver with no associated wearer/user record. UIs and users must always use `safeTransferFrom`.

## A.6 SVG content is owner-pre-committed and immutable once published

A renderable SVG for a UPC can only be published if the resolver owner has pre-committed the keccak256 hash (`setSvgHashesOf`, owner-only, one-shot per UPC). Once `setSvgContentsOf(upc, svgContent)` succeeds, the content is permanent — no method exists to overwrite or delete `_svgContentOf[upc]`.

- This means **what you see when your body or outfit renders cannot be changed out from under you** by the resolver owner after publication.
- The only mutable display elements the resolver owner controls are `svgDescription`, `svgExternalUrl`, `svgBaseUri`, and `_customProductNameOf` (display names) — none of which alter image content.

## A.7 Token-URI fallback

If the body/outfit/background has no on-chain SVG (e.g., the owner hasn't pre-committed a hash and nobody has published bytes), `tokenUriOf` falls back to an IPFS URI decoded from the tiers-hook store via `JBIpfsDecoder.decode` — the standard 721-tiers fallback path. NFTs continue to resolve; the on-chain composition simply shows the IPFS asset instead.

---

## Section B — Guarantees and powers of the resolver owner

## B.1 What the resolver owner CAN do (`onlyOwner`)

- **`setMetadata(description, url, baseUri)`** — overwrites the three metadata strings (`svgDescription`, `svgExternalUrl`, `svgBaseUri`). Mutable at any time, all three written every call. Intended use: adjust collection-level display text or repoint IPFS gateways.
- **`setProductNames(upcs[], names[])`** — writes `_customProductNameOf[upc]`. **Mutable, intentionally.** The source comment explicitly notes mutability is for corrections and localization; names are display-only and do not affect on-chain logic or composition.
- **`setSvgHashesOf(upcs[], svgHashes[])`** — pre-commits the `keccak256` hash of the SVG bytes for each UPC.
  - **One-shot per UPC.** Reverts `HashAlreadyStored` if `svgHashOf[upc] != bytes32(0)`. The owner cannot rotate or correct a hash once set — a wrong commit is permanently bricked for that UPC (it falls back to IPFS).

## B.2 What the resolver owner CANNOT do

- Cannot mint, burn, or transfer any Banny tier NFT (those flow through the JB 721 tiers hook).
- Cannot decorate any body — `decorateBannyWith` checks only ERC-721 ownership.
- Cannot lock any body — `lockOutfitChangesFor` checks ERC-721 ownership.
- Cannot rotate an already-committed SVG hash (one-shot per UPC).
- Cannot overwrite already-published SVG content (one-shot per UPC, regardless of owner).
- Cannot block or filter permissionless `setSvgContentsOf` calls — anyone may publish bytes matching a pre-committed hash.
- Cannot recover NFTs stranded by non-safe `transferFrom` pushes (no recovery surface exists).

## B.3 What the permissionless content-publication function guarantees

`setSvgContentsOf(upcs[], svgContents[])` (`Banny721TokenUriResolver.sol:1284-1323`) — callable by anyone:

- Reverts `ContentsAlreadyStored` if `_svgContentOf[upc]` is non-empty (one-shot per UPC).
- Reverts `HashNotFound` if `svgHashOf[upc] == bytes32(0)` (owner must pre-commit first).
- Reverts `ContentsMismatch` if `keccak256(abi.encodePacked(svgContent)) != svgHashOf[upc]`.

Net effect: any third party can complete the upload after owner pre-commit, but the published bytes are bit-exactly what the owner committed to. **The owner trusts the hash, not the publisher.**

---

## Section C — Per-contract operation inventory

There is exactly one contract in `src/`: `Banny721TokenUriResolver` (`src/Banny721TokenUriResolver.sol`). It implements `IJB721TokenUriResolver`, `IBanny721TokenUriResolver`, `IERC721Receiver`, `Ownable`, `ERC2771Context`, `ReentrancyGuard`.

## C.1 Banny721TokenUriResolver — external/public surface

### NFT-holder-gated mutating functions

- **`decorateBannyWith(address hook, uint256 bannyBodyId, uint256 backgroundId, uint256[] calldata outfitIds)`** (`:1127`)
  - Caller: anyone, but must own `bannyBodyId` via `IERC721(hook).ownerOf`.
  - Effect: dresses the body — updates `_attachedBackgroundIdOf`, `_userOf`, `_attachedOutfitIdsOf`, `_wearerOf`; safe-transfers outfit/background NFTs into resolver custody on equip and back to caller on unequip.
  - **Invariants preserved:** body category = 0; body not locked; per-asset ownership rule (own outright OR own current wearer/user, source body not locked); ascending categories; full-head/full-suit exclusivity; reentrancy guard; no NFT stranding on swap (`_tryTransferFrom` + retained-list merge).
  - **Cannot:** equip non-body in the body slot; equip while locked; equip an unworn outfit/background you don't own; equip an outfit worn by a body whose owner you are not; equip from a locked source body.
  - Emits `DecorateBanny(hook, bannyBodyId, backgroundId, outfitIds, caller)`.

- **`lockOutfitChangesFor(address hook, uint256 bannyBodyId)`** (`:1178`)
  - Caller: anyone, but must own `bannyBodyId`.
  - Effect: sets `outfitLockedUntil[hook][bannyBodyId] = block.timestamp + 7 days`.
  - **Invariants:** caller is body owner; new lock end ≥ existing lock end (monotonic — reverts `CantAccelerateTheLock` otherwise).
  - **Cannot:** shorten an existing lock; lock a body the caller doesn't own.

### ERC-721 receiver

- **`onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) → bytes4`** (`:1209`)
  - Caller: any ERC-721 contract during a `safeTransferFrom`.
  - **Invariant:** reverts `UnauthorizedTransfer` unless `operator == address(this)`. The resolver only accepts NFT pushes that it initiated itself.
  - **Cannot:** be used as a deposit gateway by third parties.

### Resolver-owner-only (`onlyOwner`)

- **`setMetadata(string description, string url, string baseUri)`** (`:1238`) — overwrites all three metadata strings. Mutable. Emits `SetMetadata`.
- **`setProductNames(uint256[] upcs, string[] names)`** (`:1259`) — array lengths must match. Names mutable. Emits `SetProductName` per entry.
- **`setSvgHashesOf(uint256[] upcs, bytes32[] svgHashes)`** (`:1329`) — array lengths must match. **One-shot per UPC** — reverts `HashAlreadyStored` if `svgHashOf[upc] != 0`. Emits `SetSvgHash` per entry.

### Permissionless

- **`setSvgContentsOf(uint256[] upcs, string[] svgContents)`** (`:1284`) — array lengths must match. Requires: `svgHashOf[upc] != 0` (else `HashNotFound`), `_svgContentOf[upc]` empty (else `ContentsAlreadyStored`), `keccak256(abi.encodePacked(svgContent)) == svgHashOf[upc]` (else `ContentsMismatch`). Emits `SetSvgContent`.

### Views

- **`tokenUriOf(address hook, uint256 tokenId) → string`** (`:218`) — implements `IJB721TokenUriResolver`. Composes attributes JSON + base64-encoded SVG; falls back to IPFS via `JBIpfsDecoder` when on-chain SVG bytes are absent. For bodies, recursively iterates equipped outfits/background.
- **`assetIdsOf(address hook, uint256 bannyBodyId) → (uint256 backgroundId, uint256[] outfitIds)`** (`:381`) — filters out stale `_attachedOutfitIdsOf` entries whose `wearerOf` no longer points back to the body (lazy reconciliation per the source comment at `:147-149`).
- **`namesOf(address hook, uint256 tokenId) → (string fullName, string categoryName, string productName)`** (`:434`).
- **`svgOf(address hook, uint256 tokenId, bool shouldDressBannyBody, bool shouldIncludeBackgroundOnBannyBody) → string`** (`:462`).
- **`userOf(address hook, uint256 backgroundId) → uint256`** (`:522`) — returns the body currently using the background (after the staleness check). Returns 0 if unused or stale.
- **`wearerOf(address hook, uint256 outfitId) → uint256`** (`:537`) — returns the body wearing the outfit (after scanning the attached list). Returns 0 if not worn or stale.
- Auto-getters: `outfitLockedUntil(hook, body)`, `svgBaseUri`, `svgDescription`, `svgExternalUrl`, `svgHashOf(upc)`, `defaultAlienEyes`, `defaultMouth`, `defaultNecklace`, `defaultStandardEyes`, `bannyBody`.

### Inherited surface

- `Ownable`: `owner()`, `transferOwnership(newOwner)`, `renounceOwnership()` — standard. `owner` is set in constructor.
- `ERC2771Context`: trusted-forwarder-aware `_msgSender()` / `_msgData()`. Used everywhere internally so that gasless meta-transactions through the configured forwarder are correctly attributed for the caller-is-owner ERC-721 checks.

## C.2 No other contracts in `src/`

`src/` contains only `Banny721TokenUriResolver.sol`, `interfaces/IBanny721TokenUriResolver.sol`, and an (empty) `structs/` directory.

---

## Section D — Cross-cutting invariants

1. **Decoration is NFT-ownership-bound, never owner-bound.** `decorateBannyWith` and `lockOutfitChangesFor` consult `IERC721(hook).ownerOf` for *every* asset they touch. The resolver owner cannot dress, lock, or unequip any body or asset.

2. **Outfits in custody are still "owned" by the body, logically.** The mapping `_wearerOf[hook][outfit] → body` (resp. `_userOf` for backgrounds) records the body. Transferring the body transfers control over all currently-equipped outfits/backgrounds — the new body owner can unequip them via `decorateBannyWith` and receive the underlying NFTs. The source comment at `:142-143` codifies this as intentional design.

3. **Lock prevents detachment from the lock's body, not from others.** A locked body's equipped outfits cannot be moved off — `_revertIfBodyLocked` is invoked whenever an outfit/background is sourced from a *different* body. The lock-holding body itself also cannot redecorate because `decorateBannyWith` checks the body's own lock at the top.

4. **SVG content is hash-bound and one-shot.** Once `svgHashOf[upc]` is committed by the resolver owner, exactly one `_svgContentOf[upc]` payload can match — and once stored, it is immutable. Publication is permissionless but constrained; the owner trusts the hash, not the publisher.

5. **Stale tracking is filtered at read time, not write time.** `wearerOf`, `userOf`, and `assetIdsOf` each check current ownership/attachment and skip stale entries. The mutation paths don't aggressively clean state when external transfers happen — this is documented at `:144-149` and is a deliberate gas/correctness tradeoff. Reads stay correct.

6. **Try-transfer-and-retain prevents NFT stranding.** All resolver-initiated outbound `safeTransferFrom`s during `decorateBannyWith` swap-out paths use `_tryTransferFrom`. If the underlying NFT is in a state that rejects the transfer, the corresponding attachment record is preserved (outfits) or the entire state change is skipped (background-change path) so the owner can retry. No equipped NFT can be lost by the resolver due to a downstream transfer revert.

7. **Reentrancy + ERC-2771 discipline.** `decorateBannyWith` is `nonReentrant`. All caller checks use `_msgSender()` (ERC-2771-aware), so meta-transactions are correctly attributed to the relayed signer. The owner-only and ownership-based checks both rely on the same forwarder-extracted sender.

8. **Push rejection.** `onERC721Received` rejects any incoming `safeTransferFrom` not initiated by the resolver itself. The only way for an outfit/background to enter resolver custody is through `decorateBannyWith` (which itself calls the underlying ERC-721's `safeTransferFrom`).

9. **Category model is fixed at compile time.** Categories `_BODY_CATEGORY` (0) through `_SPECIAL_BODY_CATEGORY` (17) and the special UPCs (`ALIEN_UPC=1`, `PINK_UPC=2`, `ORANGE_UPC=3`, `ORIGINAL_UPC=4`) are `private constant` (`:75-97`). Adding a new category requires a contract upgrade — which, given there is no upgrade surface, means a redeploy and reattachment to a new hook configuration.

10. **Display strings vs image content.** Display metadata (description, external URL, base URI, custom product names) is owner-mutable. Image content (`_svgContentOf`) is one-shot and hash-bound. The contract draws a hard line between cosmetic metadata and image bytes.

---

## Section E — Out-of-scope centralization caveats

These are NOT third-party attack vectors but are powers held by the resolver owner. They are scoped *narrowly* compared to the protocol-level owners enumerated in the top-level `INVARIANTS.md`.

- **Single Ownable address.** The resolver has one `owner()`. That owner can:
  - rewrite `svgDescription`, `svgExternalUrl`, `svgBaseUri` at any time (e.g., to repoint the IPFS gateway or change collection-level prose);
  - rewrite custom product names at any time (display only — no on-chain logic depends on these);
  - pre-commit new SVG hashes for new UPCs (one-shot per UPC).
- **The owner cannot:** alter image content for any UPC where bytes have already been published; rotate a hash once committed; touch any user's equipped state; mint, burn, or transfer any tier NFT.
- **Trusted forwarder is set at construction and is immutable** (`ERC2771Context` immutable). If the configured forwarder is compromised, that forwarder could relay arbitrary `_msgSender()` for any caller-gated function — equivalent to letting it impersonate any user for `decorateBannyWith` / `lockOutfitChangesFor`. Operator-side hazard.
- **Non-safe `transferFrom` pushes strand the NFT.** Anyone who calls `IERC721.transferFrom(..., to=resolver, ...)` (instead of `safeTransferFrom`) bypasses `onERC721Received` and leaves the NFT in the resolver with no wearer/user record. There is no recovery function. UIs must use `safeTransferFrom`.

---

## Section F — Key code references

- Decoration gate (caller-is-body-owner check): `banny-retail-v6/src/Banny721TokenUriResolver.sol:1140-1145`
- Body-category check during decoration: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1148-1153`
- Body-lock check during decoration: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1158-1162`
- Per-outfit ownership / borrow-from-worn-body rule: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1504-1525`
- Per-background ownership / borrow-from-using-body rule: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1383-1408`
- Source-body lock guard when sourcing equipped asset: `banny-retail-v6/src/Banny721TokenUriResolver.sol:970-978`
- Category exclusivity (`HeadAlreadyAdded` / `SuitAlreadyAdded`): `banny-retail-v6/src/Banny721TokenUriResolver.sol:1055-1093, 1542-1558`
- Ascending-category enforcement: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1530-1540`
- Monotonic lock (`CantAccelerateTheLock`): `banny-retail-v6/src/Banny721TokenUriResolver.sol:1183-1197`
- `onERC721Received` push rejection: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1224-1229`
- No-strand swap (try-transfer + retained-list merge): `banny-retail-v6/src/Banny721TokenUriResolver.sol:1570-1592, 1620-1640, 1656-1719, 1738-1742`
- Owner-only metadata: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1238-1252`
- Owner-only product names: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1259-1276`
- Owner-only one-shot SVG hash pre-commit: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1329-1354`
- Permissionless hash-bound SVG publication: `banny-retail-v6/src/Banny721TokenUriResolver.sol:1284-1323`
- `wearerOf` / `userOf` stale-entry filter: `banny-retail-v6/src/Banny721TokenUriResolver.sol:522-531, 537-557`
- `assetIdsOf` stale-entry filter: `banny-retail-v6/src/Banny721TokenUriResolver.sol:381-426`
- Lock duration constant (`7 days`): `banny-retail-v6/src/Banny721TokenUriResolver.sol:73`
- Tier-category constants (`_BODY_CATEGORY` … `_SPECIAL_BODY_CATEGORY`): `banny-retail-v6/src/Banny721TokenUriResolver.sol:75-92`
- IPFS fallback in `tokenUriOf`: `banny-retail-v6/src/Banny721TokenUriResolver.sol:322-332`
