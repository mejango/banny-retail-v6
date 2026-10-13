# Before-mint resolver replacement

## Sphinx execution

Use the reviewed resolver-upgrade adapter before starting fresh airdrop proposals. It keeps the original `AirdropV4Bannys.s.sol` project configuration and collects only its configuration getter; it substitutes the same canonical Safe batches described below. It qualifies every chain and the complete exact root on loopback before uploading anything. Deployment, storage writer binding and configuration are checked against reviewed compiler artifacts and pinned collection state.

One proposal contains two ordered actions: deployment of the storage, resolver and stateless guard, then atomic configuration, guard verification and the collection resolver switch. The second action contains no deployments. The Sphinx module enforces leaf order; one root consumes one module nonce per chain. Its intermediate JSON files are marked **Sphinx root only**; use the native preparer below to create files for Safe Builder rather than importing these Sphinx intermediates. The native switch batch deploys its guard if absent so out-of-order execution fails safely.

Before each upload, the adapter also replays that exact frozen root at a fresh pinned block on loopback, both as separate cold actions and with the installed Sphinx SDK execution batching policy. It keeps the signed gas, action bytes and module nonce unchanged, checks runtime identity and current gas headroom, and verifies that part's resulting state. Each attempt retains a separate `replay-part-N-*/replay.json`, including failures. A failed replay prevents upload; it does not repair or cancel an existing proposal. A dry run previews the initially qualified parts without uploading them.

```sh
forge build
npm run deploy:testnets:resolver-upgrade -- --dry-run
npm run deploy:testnets:resolver-upgrade
```

The live `npm run deploy:testnets:resolver-upgrade` command uploads one proposal containing both actions. Both owners sign this root once in Sphinx, then execute it on every participating testnet. Configuration and the collection's `setMetadata` resolver switch remain one atomic Safe action. Deployment and activation may occur in separate execution transactions; the whole proposal is not atomic. Use the **exact resume command printed by the adapter**, with `.env` exported in your shell, to verify completion: it checks the active resolver, all settings, names, artwork commitments, storage binding and zero mint/burn/custody. Resume does not request a second activation signature or upload a duplicate proposal. Pending, uncertain, failed or partially completed execution stays fail-closed.

The gas budget applies to each execution transaction, not the sum of the proposal's actions. The adapter sets the existing uploaded Sphinx `networkConfig.blockGasLimit` execution setting to a conservative SDK batching ceiling, while preserving the actual pinned header gas limit separately as `observedBlockGasLimit`. The installed executor derives its maximum batch gas from this setting. Qualification and before-upload replay use the SDK's exported batching routine and verify each selected transaction against the reviewed budget. The configured ceiling is preserved on replay, checked against the fresh real header and uploaded unchanged. This relies on the managed service honoring the submitted Sphinx execution configuration; an executor that ignores it has not been qualified.

Repeat with `npm run deploy:mainnets:resolver-upgrade -- --dry-run` and `npm run deploy:mainnets:resolver-upgrade` for mainnets. Each profile requires one owner-approved root. Use `--dry-run` without `--confirm`; the SDK rejects that option pair.

Saved two-root preparations use the previous workflow version and cannot become one-root proposals. If an old root has already been submitted, retain its ledger and exact root, and reconcile its state before starting a fresh proposal. Do not submit a replacement that competes at the same module nonce. The new entrypoint rejects old preparations; use their reviewed original workflow checkout for any authorized continuation.

After both resolver upgrades complete, generate and qualify **fresh** distribution preparations:

```sh
npm run generate:airdrop
forge build
npm run deploy:testnets:airdrop -- --dry-run
npm run deploy:testnets:airdrop
```

Continue distributions using their printed resume commands after each proposal has executed on every participating chain. Repeat the fresh dry run and proposal with `deploy:mainnets:airdrop` for mainnets. The resolver upgrade mints zero NFTs; the distribution proposals perform the airdrop. Saved preparations from before activation remain unusable for this flow. Existing native Safe signatures require the separate nonce reconciliation described below.

Shared distribution preparation requires the reviewed replacement resolver runtime, its bound storage runtime, Safe ownership/configurator and matching publication writer. An old resolver cannot qualify merely because it has code. Compiler identity version 2 pins semantic deployment fields and exact transitive source hashes; selected build-info source text must also match those hashes and current files. Earlier preparation directories require new qualification after these workflow changes.

`prepare-resolver-upgrade.js` reads a pinned chain and creates unsigned Safe Transaction Builder JSONs. It never sends a proposal, approval or transaction. Use the collection's metadata-authorized Safe. Build the reviewed storage, resolver and guard first.

The replacement keeps `setSvgContentsOf(uint256[],string[])` unchanged. Hash-matching original fragments are stored in immutable STOP-prefixed data contracts, with at most 24,575 content bytes per contract. The resolver reads their exact concatenation. Publish one large asset per transaction; the array interface is not a promise that all artwork fits in one transaction. Publication remains permissionless and one-shot for nonempty content; existing empty-content behavior is preserved.

```sh
node script/outfit_drop/prepare-resolver-upgrade.js \
  --rpc-env RPC_ETHEREUM_MAINNET \
  --hook 0x37e35937ecF949d7a44a9Fe878107DE264618B8f \
  --safe 0x9E2a10aB3BD22831f19d02C648Bc2Cb49B127450 \
  --out safe-airdrop/resolver-upgrade-ethereum
```

Import and execute these stages in order, verifying each receipt before advancing:

1. `01-deploy`: in ONE atomic Safe batch, deterministically deploy the SVG storage and replacement resolver, then bind the storage writer to the resolver. The storage configurator is the Safe; its address is independent of the resolver. The resolver receives that storage address through its constructor. Existing matching deployments are reused; unbound storage is bound, a matching writer is retained, and a different writer is rejected before files are written.
2. `02-configure-and-switch`: keep ALL calls in ONE atomic Safe batch. Deploy the stateless guard first if it is absent, copy metadata, every committed artwork hash and every product name, then run the guard and switch. Deploying the guard in this stage ensures executing it before stage 01 fails on missing dependencies instead of silently calling an empty guard address. Constructor arguments preserve body/default layers, trusted forwarder and owner. The guard’s normal CALL precedes the hook’s `setMetadata` CALL, which changes only the resolver. Any failure rolls back configuration and switching together.

The evidence JSON records pinned state, complete product inventory, configuration fingerprint, constructor/code hashes, expected addresses and observed storage writer. Existing different exports are never overwritten. Preparing files does not establish execution authority or prove their gas limits: require the exact Safe batches to pass fork rehearsal before signing.

Check total publication gas against a fresh local capped Anvil, using a preparation's evidence file:

```sh
node script/outfit_drop/qualify-svg-publication.js \
  safe-airdrop/resolver-upgrade-ethereum/1-evidence.json \
  safe-airdrop/svg-publication-report.json
```

This check publishes all 64 hash-verified originals from `test/fixtures/banny-svg-originals.json` on loopback only and compares read-back bytes. Each receipt includes calldata, creation and event costs. Storage deployment, resolver deployment and one-time writer binding gas are recorded separately and as a combined total. The optional third argument writes sample NFT images using the production resolver with the existing mock ownership hook; it requires compiled test artifacts. These local Osaka proofs do not certify Nitro-specific behavior or future chain gas rules; obtain current estimates before real publication.

The switch guard rejects any circulating supply or mint/burn history, old/new resolver NFT custody, changed current resolver, runtime, storage writer, owner, product inventory, names, artwork commitments, templates or metadata. The candidate must have no preexisting artwork commitments. If its configuration stage failed atomically, the deployment remains reusable because commitments rolled back. A separately configured candidate is rejected; review a fresh deployment salt and regenerate all evidence rather than overriding this gate. Atomic configuration and switching leaves no intermediate commitment-publication window.

Publish artwork AFTER the switch. It can also happen after distribution without reminting. The execution guard deliberately binds immutable artwork commitments rather than rendering caches. There are no minted tokens or NFT custody to migrate. Offchain preparation records every standalone rendering, `inlineUpcs` and exact-preimage republication obligations. A correctly committed old publication can appear between roots without invalidating the signed calls; resume records a fresh artwork observation. Rendering changes for uncommitted products still fail freshness checks. Only hash-verified original fragments may be used as publication calldata, never the rendered wrapper. Verify replacement appearance after republication. Replacement publication cannot interleave the atomic configure-and-switch transaction.

Do not use the previously prepared airdrop directories after switching. They embed the previous resolver. Fresh airdrop preparation must read the replacement and rerun qualification. The current Sphinx resume validation rejects stale preparations. Previously signed native Safe distribution transactions do not automatically lose authorization and their migration helper can still use the obsolete resolver. Inventory existing signatures with the owners; any old authorized distributions must be invalidated with reviewed cancellation/replacement transactions at their Safe nonces or evidence that those nonces were consumed. Deleting a queue entry is insufficient. Consuming one nonce does not invalidate later nonces.

Choose executable Safe nonces for these stages, accounting for unrelated pending prerequisites. Do not append the upgrade behind old distributions or silently replace unrelated configuration transactions. Builder JSON does not enforce a nonce. OP Sepolia and Arbitrum Sepolia need their established direct native Safe approval/execution route if the hosted Safe app still does not support them; these Builder files alone do not provide that transport.

Treat direct tier purchases as an execution race until live terminal and ruleset checks prove otherwise. Hiding a website purchase button does not disable terminal minting. A purchase before activation closes the never-minted guard window; a purchase before a tier's distribution is complete can consume an exact required serial. Monitor supply, burns and mint events through activation and distribution, and complete activation verification immediately after the switch. If a mint intervenes, stop and prepare a separately reviewed recovery design; do not relax the guard or retry shifted IDs.

Failed or canceled roots remain fail-closed. Retain action-success/failure events, completed indices, mint history and custody evidence before preparing recovery. A new root must include only proven remaining atomic slices and use fresh module nonces and full qualification. The current tool cannot automatically continue a partially completed chunk or a mixed-chain failed rollout; it requires a reviewed recovery preparation. Current ownership alone cannot prove an action never ran, because recipients may sell after delivery. Likewise, public queues and known onchain approvals cannot rule out private retained signatures; reconcile those with the owners before execution.

After deployment and the collection switch are verified, update the resolver deployment registry record used by `BannyverseDeploymentLib`, `Drop1.s.sol` and `Add.Denver.s.sol`. Those catalog scripts otherwise target the old resolver. Do not update registry addresses before the deployment is verified.

A switch back to the old resolver is safe only while the collection has never minted (including any later burns) and both resolvers hold no NFTs. The guard requires injected storage on its replacement target, so it cannot be reused to activate the original resolver, which has no storage getter. A reversal requires a separately reviewed guard for that target and verified fingerprints in the same atomic batch as the reverse setter. After minting or dressing, this rollout deliberately refuses rollback; resolver-owned custody and outfit state would require a separate migration.
