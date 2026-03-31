# Banny Retail Risk Register

This file focuses on failure modes that can break NFT custody, let untrusted hook integrations bypass assumptions, or leave a rendered Banny in a state that does not match the assets users think they own.

## How to use this file

- Read `Priority risks` first; those are the highest-signal failure modes for operators, auditors, and integrators.
- Use `Accepted Behaviors` to separate intentional tradeoffs from genuine bugs.
- Treat `Invariants to Verify` as required test and audit targets.

## Priority risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P0 | Untrusted `hook` or store integration | The caller chooses the hook, and the resolver trusts it for ownership checks, tier metadata, and transfers. A bad hook can fake authority or trap assets. | Operationally restrict supported hooks, scrutinize sections 1, 3, and 5, and test with hostile hook behavior. |
| P1 | Silent transfer failure retention | Failed returns intentionally keep attachment records to avoid stranding NFTs, but this can leave phantom render state if the underlying asset is gone forever. | Explicit accepted-behavior rules, retained-item handling, and invariants around custody/state correspondence. |
| P1 | Sale-time outfit lock griefing | A seller can transfer a locked body and force the buyer to wait up to 7 days before changing outfits. | Fixed-duration lock, marketplace disclosure, and user education before secondary sales. |


## 1. Trust Assumptions

- **Trusted forwarder.** ERC-2771 `_msgSender()` is trusted for all ownership checks in `decorateBannyWith`, `lockOutfitChangesFor`, and admin functions. A compromised forwarder can dress/undress any banny and steal equipped outfits.
- **Hook contract.** The `hook` parameter is caller-supplied and not validated against any registry. A malicious hook contract could return arbitrary tier data, manipulate ownership checks, or trap NFTs.
- **Owner (Ownable).** The contract owner controls SVG hashes, product names, and metadata URIs. A compromised owner can set malicious SVG content hashes, enabling XSS via on-chain SVG injection after the matching content is uploaded.
- **721 hook store.** `_storeOf(hook)` calls `IJB721TiersHook(hook).STORE()` -- trusts the hook to return a legitimate store. A malicious hook can return a fake store with manipulated tier data.

## 2. Economic / Manipulation Risks

- **Outfit theft via banny body transfer.** Equipped outfits and backgrounds travel with the banny body NFT on transfer. If a banny body is sold with valuable outfits equipped, the buyer gains control of all equipped items. Sellers must unequip before selling. Marketplaces may not surface this risk.
- **try-catch silent failures with retention.** `_tryTransferFrom` silently catches all transfer failures and returns `false`. When a transfer fails, the resolver preserves the attachment record instead of clearing state. For backgrounds, the entire background change is aborted. For outfits, failed-to-return items are retained in the attached list via `_storeOutfitsWithRetained`. This prevents NFT stranding — assets remain tracked and recoverable once the transfer issue is resolved (e.g., the owner contract becomes receivable). However, if an outfit NFT is burned or its tier removed, the retained record refers to a non-existent asset, creating a phantom entry in the SVG rendering.
- **Lock griefing.** `lockOutfitChangesFor` extends the lock to `block.timestamp + 7 days`. Locking just before selling prevents the buyer from changing outfits for up to 7 days. The lock now also freezes reassignment of currently equipped outfits/backgrounds away from that body during the lock window.

## 3. Access Control

- **No hook validation (HIGH impact).** Any address can be passed as `hook`. A malicious hook can return `_msgSender()` from `ownerOf()` to pass authorization checks, execute arbitrary code during `safeTransferFrom`, or return manipulated tier data from `STORE().tierOfTokenId()`.
- **SVG content upload is permissionless (with hash).** `setSvgContentsOf` only requires the content to match a pre-committed hash. Safe if hashes are correctly committed.
- **onERC721Received restriction.** Only accepts NFTs when `operator == address(this)`. `transferFrom` (non-safe) bypasses this -- NFTs sent via `transferFrom` are permanently locked with no rescue function.

## 4. DoS Vectors

- **External call iteration scales with outfit count.** `_attachedOutfitIdsOf[hook][bannyBodyId]` is replaced wholesale on each `decorateBannyWith` call (not appended to), so the array is bounded by the number of currently equipped outfits, not cumulative history. However, `decorateBannyWith` iterates over both the previous and new outfit arrays to diff them (transferring removed outfits back and new outfits in), so gas cost scales with the number of outfits being equipped/unequipped in a single call.
- **External hook calls in view functions.** `tokenUriOf` and `svgOf` call into the hook's store multiple times per outfit. A malicious hook that consumes excessive gas or reverts can make token metadata unretrievable. Measured: `tokenUriOf` with a well-behaved hook and 9 equipped outfits costs ~609k gas (see `test_tokenUri_gasSnapshot_9outfits`). The practical ceiling for a malicious hook is bounded only by the caller's gas limit — RPC nodes typically cap `eth_call` at 30M+ gas, so even expensive hooks won't fail for off-chain reads, but on-chain consumers (e.g., other contracts calling `tokenURI`) could revert.

## 5. Integration Risks

- **Cross-contract NFT custody.** Outfits are held by `Banny721TokenUriResolver` via `safeTransferFrom`. If approval is revoked on the hook contract, equipping fails.
- **Tier removal desync.** If a tier is removed from the 721 hook while an outfit from that tier is equipped, `_productOfTokenId` returns a product with `id == 0`. The outfit remains equipped but renders as empty. `_tryTransferFrom` may fail silently when trying to return it.
- **Non-safe transfer loss.** Outfits sent directly to this contract via `transferFrom` (not `safeTransferFrom`) are permanently stuck since there is no rescue function.
- **ReentrancyGuard.** `decorateBannyWith` uses `nonReentrant`, but `lockOutfitChangesFor` and view functions do not. Reentrancy through hook callbacks is possible but state updates follow CEI pattern.

## 6. Invariants to Verify

- Every outfit held by this contract has a corresponding `_wearerOf[hook][outfitId]` pointing to a valid banny body.
- Every background held by this contract has a corresponding `_userOf[hook][backgroundId]` pointing to a valid banny body.
- `outfitLockedUntil[hook][bannyBodyId]` is monotonically non-decreasing per banny body (lock can only be extended, never shortened).
- After `decorateBannyWith`, all previously equipped outfits not in the new set are either transferred back to `_msgSender()` or retained in the attached list if the transfer failed.
- `_attachedOutfitIdsOf[hook][bannyBodyId]` contains the outfitIds passed to the most recent `decorateBannyWith` call, plus any retained outfits whose return transfer failed. Category exclusivity is enforced on the merged set (retained + new outfits), not just the new outfit set alone.
- SVG content integrity: `keccak256(_svgContentOf[upc]) == svgHashOf[upc]` for all populated entries.
- NFT custody balance: the number of outfit NFTs held by this contract (`IERC721(hook).balanceOf(address(this))`) equals the total number of outfits currently equipped across all banny bodies for that hook. Violations indicate phantom outfits (equipped in state but NFT lost via try-catch silent failure) or orphaned NFTs (held by contract but not tracked in `_wearerOf`).

## 7. Accepted Behaviors

### 7.1 Failed transfers retain attachment records (anti-stranding)

`_tryTransferFrom` catches all transfer failures and returns `false`. When returning a previously equipped item fails, the resolver preserves the attachment record rather than clearing state:

- **Backgrounds**: If returning the old background fails, the entire background change is aborted (`return` in `_decorateBannyWithBackground`). The old background stays attached and the new one is not equipped.
- **Background removal**: If returning the background fails during removal (backgroundId=0), `_attachedBackgroundIdOf` is not cleared. The background stays attached.
- **Outfits**: Failed-to-return outfits remain non-zero in the `previousOutfitIds` array. `_storeOutfitsWithRetained` appends them to the new outfit list, preserving their attachment record.

This prevents NFT stranding — assets held by the resolver stay tracked and recoverable. Once the transfer issue is resolved (e.g., the owner contract implements `IERC721Receiver`), a subsequent `decorateBannyWith` call will successfully return the retained items.

For permanently unrecoverable assets (burned NFTs, removed tiers), the retained record creates a phantom entry in the SVG rendering and attached list. This is cosmetically incorrect but not economically exploitable — phantom entries cannot be transferred or sold. The alternative — reverting on any failed transfer — would make `decorateBannyWith` fragile: a single burned outfit would prevent the banny owner from changing ANY outfits.

### 7.2 Lock griefing window is bounded at 7 days

`lockOutfitChangesFor` extends the lock to `block.timestamp + 7 days`. A seller who locks just before transferring the banny forces the buyer to wait up to 7 days. This is accepted because: (1) marketplaces can check `outfitLockedUntil` before displaying the item, (2) the lock duration is fixed (not owner-configurable), and (3) the lock prevents a more severe attack where a buyer immediately strips valuable outfits — the lock gives the previous owner time to arrange the sale intentionally.

### 7.3 On-chain SVG rendering gas is well within limits

`tokenUriOf` constructs full SVGs on-chain with string concatenation. Measured gas ceiling: ~609K gas for the worst case (9 non-conflicting outfits + background with on-chain SVG content), well within typical RPC node limits (30M+). Regression test: `test_tokenUri_gasSnapshot_9outfits` in `test/TestQALastMile.t.sol`.

### 7.4 Outfits burn alongside the body

When a banny body NFT is burned (e.g. via cash-out), any equipped outfits and backgrounds held by the resolver are permanently unrecoverable. The resolver has no recovery function and this is intentional — outfits are part of the body's identity and share its fate. Users who want to preserve outfits must unequip them before burning the body.

### 7.5 Reentrancy in non-guarded functions is harmless

`lockOutfitChangesFor` and all view functions (`tokenUriOf`, `svgOf`) are not protected by `nonReentrant`. A malicious hook's `STORE().tierOfTokenId()` could re-enter `lockOutfitChangesFor` during a `tokenUriOf` call, but this is harmless -- `lockOutfitChangesFor` only extends the lock timestamp (monotonically non-decreasing) and has no state that could be corrupted by reentrancy. The view functions themselves are read-only at the contract level (no storage writes), so reentrancy through them cannot extract value.
