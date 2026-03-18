# RISKS.md -- banny-retail-v6

## 1. Trust Assumptions

- **Trusted forwarder.** ERC-2771 `_msgSender()` is trusted for all ownership checks in `decorateBannyWith`, `lockOutfitChangesFor`, and admin functions. A compromised forwarder can dress/undress any banny and steal equipped outfits.
- **Hook contract.** The `hook` parameter is caller-supplied and not validated against any registry. A malicious hook contract could return arbitrary tier data, manipulate ownership checks, or trap NFTs.
- **Owner (Ownable).** The contract owner controls SVG hashes, product names, and metadata URIs. A compromised owner can set malicious SVG content hashes, enabling XSS via on-chain SVG injection after the matching content is uploaded.
- **721 hook store.** `_storeOf(hook)` calls `IJB721TiersHook(hook).STORE()` -- trusts the hook to return a legitimate store. A malicious hook can return a fake store with manipulated tier data.

## 2. Economic / Manipulation Risks

- **Outfit theft via banny body transfer.** Equipped outfits and backgrounds travel with the banny body NFT on transfer. If a banny body is sold with valuable outfits equipped, the buyer gains control of all equipped items. Sellers must unequip before selling. Marketplaces may not surface this risk.
- **try-catch silent failures.** `_tryTransferFrom` silently catches all transfer failures. If an outfit NFT is burned or its tier removed, the transfer fails silently. The outfit remains logically "equipped" in state but the NFT is lost. This can create phantom outfits that show in SVG rendering but cannot be recovered.
- **Lock griefing.** `lockOutfitChangesFor` extends the lock to `block.timestamp + 7 days`. Locking just before selling prevents the buyer from changing outfits for up to 7 days.

## 3. Access Control

- **No hook validation.** Any address can be passed as `hook`. A malicious hook can return `_msgSender()` from `ownerOf()` to pass authorization checks, execute arbitrary code during `safeTransferFrom`, or return manipulated tier data from `STORE().tierOfTokenId()`.
- **SVG content upload is permissionless (with hash).** `setSvgContentsOf` only requires the content to match a pre-committed hash. Safe if hashes are correctly committed.
- **onERC721Received restriction.** Only accepts NFTs when `operator == address(this)`. `transferFrom` (non-safe) bypasses this -- NFTs sent via `transferFrom` are permanently locked with no rescue function.

## 4. DoS Vectors

- **Unbounded outfit iteration.** `_attachedOutfitIdsOf` array grows with each decoration and is never compacted. Over time with repeated equip/unequip cycles, gas costs increase.
- **On-chain SVG rendering gas.** `tokenUriOf` constructs full SVGs on-chain with string concatenation. Complex outfits with many layers can exceed block gas limits for `view` calls, making tokens unrenderable by off-chain indexers. Measured gas ceiling: ~609K gas for the worst case (9 non-conflicting outfits + background with on-chain SVG content), well within typical RPC node limits (30M+). Regression test: `test_tokenUri_gasSnapshot_9outfits` in `test/TestQALastMile.t.sol`.
- **External hook calls in view functions.** `tokenUriOf` and `svgOf` call into the hook's store multiple times per outfit. A malicious hook that consumes excessive gas or reverts can make token metadata unretrievable.

## 5. Integration Risks

- **Cross-contract NFT custody.** Outfits are held by `Banny721TokenUriResolver` via `safeTransferFrom`. If approval is revoked on the hook contract, equipping fails.
- **Tier removal desync.** If a tier is removed from the 721 hook while an outfit from that tier is equipped, `_productOfTokenId` returns a product with `id == 0`. The outfit remains equipped but renders as empty. `_tryTransferFrom` may fail silently when trying to return it.
- **Non-safe transfer loss.** Outfits sent directly to this contract via `transferFrom` (not `safeTransferFrom`) are permanently stuck since there is no rescue function.
- **ReentrancyGuard.** `decorateBannyWith` uses `nonReentrant`, but `lockOutfitChangesFor` and view functions do not. Reentrancy through hook callbacks is possible but state updates follow CEI pattern.

## 6. Invariants to Verify

- Every outfit held by this contract has a corresponding `_wearerOf[hook][outfitId]` pointing to a valid banny body.
- Every background held by this contract has a corresponding `_userOf[hook][backgroundId]` pointing to a valid banny body.
- `outfitLockedUntil[hook][bannyBodyId]` is monotonically non-decreasing per banny body (lock can only be extended, never shortened).
- After `decorateBannyWith`, all previously equipped outfits not in the new set are transferred back to `_msgSender()` (or silently failed via try-catch).
- `_attachedOutfitIdsOf[hook][bannyBodyId]` matches the outfitIds passed to the most recent `decorateBannyWith` call.
- SVG content integrity: `keccak256(_svgContentOf[upc]) == svgHashOf[upc]` for all populated entries.
