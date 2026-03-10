# banny-retail-v6 -- Risks

Deep implementation-level risk analysis of `Banny721TokenUriResolver`. All line references are to `src/Banny721TokenUriResolver.sol` unless otherwise noted.

## Trust Assumptions

1. **Contract Owner (Ownable)** -- Can commit SVG hashes, set metadata, rename products. Cannot modify stored content or hashes once committed. Cannot touch user NFTs. See ADMINISTRATION.md for full scope.
2. **JB721TiersHook** -- The resolver treats the `hook` address parameter as a trusted 721 contract. It calls `IERC721(hook).ownerOf()`, `hook.STORE()`, and `hook.safeTransferFrom()` without verifying that `hook` implements any particular interface. A malicious hook could manipulate ownership returns or transfer behavior.
3. **Trusted Forwarder (ERC-2771)** -- Set immutably at construction (line 175). The forwarder can spoof `_msgSender()` for all authorization checks. If the forwarder is compromised or misconfigured, all ownership checks can be bypassed.
4. **On-Chain SVG Storage** -- Content is permanent and censorship-resistant once stored. Hash-then-reveal pattern prevents unauthorized content. Owner controls which hashes are committed.

## Risk Register

### CRITICAL -- Outfit Custody and Asset Loss

**Risk: Equipped NFTs held by resolver contract**
- Severity: **CRITICAL** | Tested: **YES** (Fork.t.sol lines 931-956, BannyAttacks.t.sol)
- When outfits or backgrounds are equipped via `decorateBannyWith()`, the NFT is transferred to the resolver contract via `safeTransferFrom` (lines 1191, 1325, 1366). The resolver holds custody until the body owner unequips.
- **Impact**: If the resolver contract has a bug, equipped NFTs could become permanently locked. All value of equipped outfits depends on the resolver's correctness.
- **Mitigation**: ReentrancyGuard on `decorateBannyWith` (line 977). `_tryTransferFrom` (lines 1375-1378) uses try-catch for returning old outfits, so burned/removed-tier tokens do not block redecoration. Tested in regression BurnedTokenCheck.t.sol.
- **Residual risk**: The resolver is not upgradeable. If a critical bug is found post-deployment, there is no admin mechanism to rescue stuck NFTs. The owner has no function to force-return assets.

**Risk: Body transfer transfers outfit control**
- Severity: **HIGH** | Tested: **YES** (Fork.t.sol lines 931-956)
- When a banny body NFT is transferred, all equipped outfits remain associated with that body. The new body owner can unequip all outfits and receive the outfit NFTs. This is by design but creates a significant gotcha for sellers.
- **Impact**: A seller who forgets to unequip before selling a body loses all equipped outfit NFTs to the buyer.
- **Mitigation**: Lock mechanism (`lockOutfitChangesFor`, line 1005) allows sellers to lock outfits to the body for 7 days, guaranteeing buyers receive the advertised outfits. The lock persists across transfers (tested in Fork.t.sol lines 581-603).
- **Residual risk**: No automated warning at the hook/marketplace level. Users must know to unequip or lock before listing.

### HIGH -- Front-Running and Griefing

**Risk: Outfit strip front-running before sale**
- Severity: **HIGH** | Tested: **YES** (Fork.t.sol lines 1172-1228)
- A seller can list a dressed banny, then front-run the sale by stripping all outfits. The buyer receives a naked body.
- **Mitigation**: The lock mechanism exists precisely for this. Tested in `test_fork_grief_lockPreventsFrontRunStrip` (Fork.t.sol line 1196). A locked body cannot have outfits changed during the lock period.
- **Residual risk**: Requires buyer awareness. Buyers should verify `outfitLockedUntil` before purchasing dressed bannys.

**Risk: Lock cannot be shortened (anti-griefing)**
- Severity: **LOW** | Tested: **YES** (Banny721TokenUriResolver.t.sol lines 393-403, Fork.t.sol lines 568-579)
- `lockOutfitChangesFor` checks `currentLockedUntil > newLockUntil` (line 1016) and reverts with `CantAccelerateTheLock` if the new lock would expire sooner. Equal values are allowed (same-block re-lock succeeds).
- **Impact**: A body owner who locks cannot undo the lock early. This is intentional -- it provides a guarantee to buyers.
- **Note**: The owner role has no ability to override locks. The 7-day `_LOCK_DURATION` constant (line 63) is not configurable.

### HIGH -- Reentrancy

**Risk: Reentrancy via safeTransferFrom callbacks**
- Severity: **HIGH** | Tested: **YES** (Fork.t.sol lines 853-925)
- `decorateBannyWith` calls `safeTransferFrom` (lines 1191, 1325, 1366) which triggers `onERC721Received` on receiving contracts. A malicious hook could attempt to re-enter `decorateBannyWith` during these callbacks.
- **Mitigation**: `decorateBannyWith` has `nonReentrant` modifier (line 977, OpenZeppelin ReentrancyGuard). Tested with a purpose-built `ReentrantHook` (Fork.t.sol line 46) that re-enters during `safeTransferFrom`. The reentrancy attempt is caught and silently fails via try-catch.
- **CEI pattern**: Background replacement follows Checks-Effects-Interactions. State updates (`_attachedBackgroundIdOf`, `_userOf`) happen at lines 1181-1182 before external transfers at lines 1186-1192. Verified in regression CEIReorder.t.sol.
- **Residual risk**: None identified. The ReentrancyGuard provides a hard block, and CEI ordering provides defense-in-depth.

### MEDIUM -- Hook Trust Boundary

**Risk: Untrusted hook address parameter**
- Severity: **MEDIUM** | Tested: **PARTIAL** (Fork.t.sol lines 1085-1114 for cross-hook isolation)
- The `hook` parameter in `decorateBannyWith`, `tokenUriOf`, and all view functions is caller-supplied. The resolver calls `IERC721(hook).ownerOf()`, `IJB721TiersHook(hook).STORE()`, and `IERC721(hook).safeTransferFrom()` on this address.
- **Impact**: A malicious hook contract could return arbitrary data from `ownerOf()`, `STORE()`, and `tierOfTokenId()`. However, since outfit custody is per-hook (the mapping is `address hook => mapping(...)` at lines 127-152), a malicious hook cannot access NFTs custodied from a different hook.
- **Mitigation**: Per-hook state isolation. Cross-hook interference tested in `test_fork_edge_crossHookIsolation` (Fork.t.sol line 1085).
- **Residual risk**: If a user interacts with a malicious hook, they could lose the NFTs they equip on that hook. The resolver cannot distinguish legitimate from malicious hooks.

**Risk: Removed tier desynchronization**
- Severity: **MEDIUM** | Tested: **YES** (RemovedTierDesync.t.sol, 6 test cases)
- When a tier is removed from the JB721TiersHookStore, `_productOfTokenId()` returns a zeroed struct (category=0, id=0). Previously equipped outfits from that tier have category 0 in the redecoration loop.
- **Impact**: Without proper handling, removed-tier outfits could cause the `_decorateBannyWithOutfits` loop to malfunction -- the category-0 entries would be processed incorrectly by the `while` loop (line 1297).
- **Mitigation**: The current code handles this correctly. Category-0 entries are processed and transferred out by the while loop. The `_tryTransferFrom` (line 1303, 1345) silently handles cases where the token no longer exists. Six regression tests verify: first/middle/last tier removal, all tiers removed, replacement after removal, and two consecutive removed tiers.

### MEDIUM -- SVG and Rendering

**Risk: Gas-intensive tokenURI view calls**
- Severity: **MEDIUM** | Tested: **YES** (Fork.t.sol lines 280-334, 793-847)
- `tokenUriOf()` (line 192) performs extensive string concatenation, Base64 encoding, and multi-layer SVG composition. For a fully dressed banny with 9 outfits + background, the view function iterates through all outfit layers, composes SVGs, builds JSON metadata with attributes, and encodes everything.
- **Impact**: Off-chain callers (marketplaces, wallets, indexers) may hit gas limits on `eth_call`. This does not affect on-chain operations since `tokenUriOf` is a view function.
- **Residual risk**: RPC providers may time out or gas-limit view calls for heavily dressed bannys. No on-chain mitigation needed.

**Risk: SVG injection via stored content**
- Severity: **LOW** | Tested: **NO** (content validation is hash-based, not sanitization-based)
- SVG content is stored verbatim in `_svgContentOf` (line 1109) after hash verification. The content is concatenated directly into the SVG output (lines 537-554, 928-934) without sanitization.
- **Impact**: If the owner commits a hash for malicious SVG content (e.g., containing `<script>` tags or external references), it would be embedded in all token URIs that reference that UPC. Modern SVG renderers in browsers and wallets typically sandbox SVG content, but some clients may be vulnerable.
- **Mitigation**: The hash-commit pattern means only intentionally chosen content can be stored. The owner is the trust boundary here. Content is also immutable once stored, so a compromised owner cannot retroactively inject malicious content into existing assets.

### MEDIUM -- Outfit Array Bounds

**Risk: Unbounded outfit iteration in _outfitContentsFor**
- Severity: **MEDIUM** | Tested: **YES** (Fork.t.sol line 400, max 9 outfits)
- `_outfitContentsFor()` (line 789) iterates `numberOfOutfits + 1` times. The outfit array is bounded by the number of valid categories (18 total, but only ~12 are usable as outfits due to body/background exclusion and conflict rules).
- **Impact**: Gas cost scales linearly with outfit count. With maximum 9 non-conflicting outfits (tested in `test_fork_decorateMaxOutfits`), gas is manageable. The category ordering constraint (line 1269-1271) and conflict rules (lines 1273-1289) naturally limit the array size.
- **Mitigation**: Category ordering enforcement means outfits cannot be duplicated or out of order. The practical maximum is ~12 outfits (one per non-body, non-background category minus conflicts).

**Risk: Unbounded _attachedOutfitIdsOf growth (theoretical)**
- Severity: **LOW** | Tested: **PARTIAL**
- The `_attachedOutfitIdsOf` array (line 127) is replaced wholesale on each `decorateBannyWith` call (line 1357). It is not appended to -- it is fully overwritten with the new `outfitIds` array. The old array's storage is not explicitly cleared but is overwritten.
- **Impact**: No unbounded growth risk in practice since the array is replaced, not extended.

### LOW -- ERC-2771 Meta-Transaction

**Risk: Trusted forwarder compromise**
- Severity: **LOW** (deployment-dependent) | Tested: **NO** (no meta-tx-specific tests)
- If `trustedForwarder` is set to a non-zero address at construction (line 175), that contract can append arbitrary sender addresses to calldata, causing `_msgSender()` to return any address.
- **Impact**: Complete bypass of all ownership checks (`_checkIfSenderIsOwner`, `onlyOwner`, outfit/background authorization).
- **Mitigation**: The constructor parameter is typically set to `address(0)` (as seen in all test setups), which disables meta-transactions entirely. If used, the forwarder must be a well-audited, immutable contract.

### LOW -- Content Immutability Edge Cases

**Risk: SVG hash set but content never uploaded**
- Severity: **LOW** | Tested: **YES** (Banny721TokenUriResolver.t.sol lines 316-324)
- If the owner sets a hash via `setSvgHashesOf` but nobody ever uploads matching content, `_svgContentOf[upc]` remains empty. The `_svgOf` function (line 922) falls back to IPFS resolution via `JBIpfsDecoder.decode()` (lines 928-934).
- **Impact**: Tokens render using IPFS fallback URI instead of on-chain SVG. Not a loss of functionality, just a different rendering path.

**Risk: Product name overwrite**
- Severity: **LOW** | Tested: **NO** (no test for overwriting names)
- `setProductNames()` (line 1073) can overwrite previously set custom product names. Unlike SVG hashes and content, names have no write-once protection.
- **Impact**: The owner can rename products at any time, changing how NFTs display in wallets. Could be used to mislead users about what they hold.
- **Mitigation**: Built-in names for UPCs 1-4 (Alien, Pink, Orange, Original) are hardcoded (lines 890-901) and cannot be overridden.

### LOW -- Authorization Edge Cases

**Risk: Outfit reuse across bodies by same owner**
- Severity: **LOW** (intended behavior) | Tested: **YES** (BannyAttacks.t.sol line 181, Fork.t.sol line 421)
- When a user owns multiple bodies, they can move an equipped outfit from one body to another in a single `decorateBannyWith` call. The authorization check at lines 1246-1258 allows this: if the caller owns the body currently wearing the outfit, they can authorize its use on a different body.
- **Impact**: Expected behavior. No security issue.

**Risk: L18 -- ownerOf(0) authorization bypass (FIXED)**
- Severity: **CRITICAL (historical)** | Tested: **YES** (DecorateFlow.t.sol lines 179-239)
- The old code called `IERC721(hook).ownerOf(wearerOf(hook, outfitId))` without first checking if `wearerOf` returned 0. When an outfit was unworn, this resolved to `ownerOf(0)`, and if an attacker owned token 0, they could pass the auth check and steal any unworn outfit.
- **Fix**: The current code (lines 1248-1257) checks `wearerId == 0` first and reverts with `UnauthorizedOutfit` before any `ownerOf` call. Six regression tests in DecorateFlow.t.sol verify the fix.

## Test Coverage Summary

| Test File | Tests | What It Covers |
|-----------|-------|----------------|
| `Banny721TokenUriResolver.t.sol` | 22 | Unit tests: constructor, owner-only functions, lock mechanism, category conflicts, background/outfit equip, onERC721Received |
| `DecorateFlow.t.sol` | ~40 | L18 vulnerability proof, multi-body outfit reuse, authorization flows, three-party interactions, background replacement, edge cases |
| `BannyAttacks.t.sol` | 8 | Adversarial: outfit reuse, lock bypass, category conflicts, unauthorized decoration, out-of-order categories, body/background as outfit |
| `Fork.t.sol` | 40+ | E2E against real JB infrastructure: full lifecycle, multi-actor, reentrancy (ReentrantHook), griefing/front-running, cross-hook isolation, redressing cycles |
| `regression/CEIReorder.t.sol` | 3 | CEI ordering in background replacement |
| `regression/RemovedTierDesync.t.sol` | 6 | Removed tier handling during redecoration |
| `regression/ArrayLengthValidation.t.sol` | 3 | Array length mismatch reverts |
| `regression/BodyCategoryValidation.t.sol` | 2 | Non-body token as bannyBodyId rejection |
| `regression/MsgSenderEvents.t.sol` | 4 | Events emit `_msgSender()` not `msg.sender` |
| `regression/BurnedTokenCheck.t.sol` | 2 | Burned equipped tokens do not lock the body |
| `regression/ClearMetadata.t.sol` | 2 | setMetadata can clear fields to empty strings |

## Untested Areas

1. **Meta-transaction flows** -- No tests exercise the `trustedForwarder` path with a real forwarder contract. All tests use `address(0)` as forwarder.
2. **SVG content sanitization** -- No tests verify that stored SVG content is safe for rendering. The hash-commit pattern is tested, but content safety is not.
3. **Product name overwriting** -- No test verifies behavior when a custom product name is overwritten with a different name.
4. **Extreme gas consumption** -- No test measures gas for `tokenUriOf` with maximum outfit count and large SVG payloads.
5. **Ownership transfer of resolver** -- No test exercises `transferOwnership()` and verifies admin functions still work with the new owner.

## Invariants (Implied by Tests)

- Outfit NFTs held by the resolver are always retrievable by the current body owner (or returned on redecoration).
- Burned or removed-tier equipped tokens do not prevent body redecoration (`_tryTransferFrom` silently handles failures).
- Category ordering is strictly enforced (ascending, no duplicates).
- Category conflicts (head blocks face pieces; suit blocks top/bottom) are enforced.
- Cross-hook state is fully isolated.
- Lock duration can only increase, never decrease.
- SVG hashes and content are write-once per UPC.
