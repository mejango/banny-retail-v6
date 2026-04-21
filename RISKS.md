# Banny Retail Risk Register

This file focuses on the failure modes that can break NFT custody, bypass hook assumptions, or leave a rendered Banny in a state that does not match the assets users think they own.

## How to use this file

- Read `Priority risks` first.
- Use `Accepted Behaviors` to separate intentional tradeoffs from bugs.
- Treat `Invariants to Verify` as required test and audit targets.

## Priority risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P0 | Untrusted `hook` or store integration | The resolver trusts the supplied hook for ownership checks, tier metadata, and transfers. A bad hook can fake authority or trap assets. | Restrict supported hooks, scrutinize the hook boundary, and test hostile hook behavior. |
| P1 | Silent transfer-failure retention | Failed returns intentionally keep attachment records to avoid stranding NFTs, but this can leave phantom render state if the asset is gone forever. | Explicit accepted-behavior rules, retained-item handling, and custody/state invariants. |
| P1 | Sale-time outfit-lock griefing | A seller can transfer a locked body and force the buyer to wait up to 7 days before changing outfits. | Fixed-duration lock, marketplace disclosure, and user education. |

## 1. Trust Assumptions

- **Trusted forwarder.** ERC-2771 `_msgSender()` is trusted for ownership checks and admin functions.
- **Hook contract.** The `hook` parameter is caller-supplied and not validated against a registry.
- **Owner.** The contract owner controls SVG hashes, product names, and metadata URIs.
- **721 hook store.** `_storeOf(hook)` trusts the hook to return a legitimate store.

## 2. Economic And Manipulation Risks

- **Outfit theft via body transfer.** Equipped outfits and backgrounds move with the body NFT. If a body is sold while wearing valuable items, the buyer gains control of them.
- **Try-catch silent failures with retention.** Failed transfer-outs preserve attachment records instead of clearing state. This avoids stranding but can create phantom render entries for burned or removed assets.
- **Lock griefing.** `lockOutfitChangesFor` extends the lock to `block.timestamp + 7 days`. Locking just before a sale can block the buyer from changing the look for up to 7 days.

## 3. Access Control

- **No hook validation.** Any address can be passed as `hook`. A malicious hook can fake `ownerOf`, execute arbitrary code during transfers, or return manipulated tier data.
- **SVG content upload is permissionless once the hash is committed.** This is safe only if the committed hash is correct.
- **`onERC721Received` restriction.** The contract only accepts NFTs when `operator == address(this)`. Plain `transferFrom` bypasses that and can permanently lock NFTs.

## 4. DoS Vectors

- **External call iteration scales with outfit count.** `decorateBannyWith` iterates both old and new outfit arrays, so gas cost scales with the number of outfits changed in one call.
- **External hook calls in view functions.** `tokenUriOf` and `svgOf` call into the hook's store multiple times. A malicious or gas-heavy hook can make metadata unreadable.

## 5. Integration Risks

- **Cross-contract NFT custody.** Outfits are held by the resolver via `safeTransferFrom`. If approval is revoked on the hook contract, equipping fails.
- **Tier removal desync.** If a tier is removed while an outfit from that tier is equipped, the outfit may remain attached but render empty.
- **Non-safe transfer loss.** Outfits sent directly via `transferFrom` can be permanently stuck because there is no rescue function.
- **Reentrancy assumptions.** `decorateBannyWith` uses `nonReentrant`, but other functions rely on ordering and limited state impact instead.

## 6. Invariants to Verify

- Every outfit held by the contract has a corresponding wearer mapping to a valid body.
- Every background held by the contract has a corresponding user mapping to a valid body.
- `outfitLockedUntil` is monotonically non-decreasing per body.
- After `decorateBannyWith`, old outfits not in the new set are either returned or explicitly retained because transfer-out failed.
- Category exclusivity holds on the merged set of retained and newly supplied outfits.
- SVG content integrity holds for all populated entries.
- The number of held outfit NFTs should match the number of outfits still tracked as equipped for that hook.

## 7. Accepted Behaviors

### 7.1 Failed transfers retain attachment records

If returning a previously equipped item fails, the resolver keeps the attachment record instead of dropping it. This avoids stranding NFTs held by the resolver, but it can leave cosmetic phantom state for permanently unrecoverable assets.

### 7.2 Lock griefing is bounded at 7 days

`lockOutfitChangesFor` can force a buyer to wait, but the window is fixed and cannot be extended arbitrarily beyond the current maximum.

### 7.3 Onchain SVG rendering gas is acceptable

Full `tokenUriOf` rendering is expensive but still within practical RPC limits for the supported outfit counts.

### 7.4 Outfits burn alongside the body

If a body NFT is burned while outfits are equipped, those outfits are intentionally unrecoverable. Users who want to keep them must unequip first.

### 7.5 Reentrancy in non-guarded functions is treated as harmless under the current model

`lockOutfitChangesFor` only extends a timestamp, and view functions do not write storage. That keeps the remaining reentrancy surface narrow.
