# Before-mint resolver replacement

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

1. `01-deploy`: in ONE atomic Safe batch, deterministically deploy the SVG storage, replacement resolver and stateless guard, then bind the storage writer to the resolver. The storage configurator is the Safe; its address is independent of the resolver. The resolver receives that storage address through its constructor. Existing matching deployments are reused; unbound storage is bound, a matching writer is retained, and a different writer is rejected before files are written.
2. `02-configure-and-switch`: keep ALL calls in ONE atomic Safe batch. Copy metadata, every committed artwork hash and every product name, then run the guard and switch. Constructor arguments preserve body/default layers, trusted forwarder and owner. The guard’s normal CALL precedes the hook’s `setMetadata` CALL, which changes only the resolver. Any failure rolls back configuration and switching together.

The evidence JSON records pinned state, complete product inventory, configuration fingerprint, constructor/code hashes, expected addresses and observed storage writer. Existing different exports are never overwritten. Preparing files does not establish execution authority or prove their gas limits: require the exact Safe batches to pass fork rehearsal before signing.

Check total publication gas against a fresh local capped Anvil, using a preparation's evidence file:

```sh
node script/outfit_drop/qualify-svg-publication.js \
  safe-airdrop/resolver-upgrade-ethereum/1-evidence.json \
  safe-airdrop/svg-publication-report.json
```

This check publishes all 64 hash-verified originals from `test/fixtures/banny-svg-originals.json` on loopback only and compares read-back bytes. Each receipt includes calldata, creation and event costs. Storage deployment, resolver deployment and one-time writer binding gas are recorded separately and as a combined total. The optional third argument writes sample NFT images using the production resolver with the existing mock ownership hook; it requires compiled test artifacts. These local Osaka proofs do not certify Nitro-specific behavior or future chain gas rules; obtain current estimates before real publication.

The switch guard rejects any circulating supply or mint/burn history, old/new resolver NFT custody, changed current resolver, runtime, storage writer, owner, product inventory, names, artwork commitments, templates or metadata. The candidate must have no preexisting artwork commitments. If its configuration stage failed atomically, the deployment remains reusable because commitments rolled back. A separately configured candidate is rejected; review a fresh deployment salt and regenerate all evidence rather than overriding this gate. Atomic configuration and switching leaves no intermediate commitment-publication window.

Publish artwork AFTER the switch. It can also happen after distribution without reminting. The execution guard deliberately binds immutable artwork commitments rather than rendering caches. There are no minted tokens or NFT custody to migrate. Offchain preparation records every standalone rendering and refuses an existing old inline cache pending a preservation review. Later permissionless publication cannot change the committed originals. Replacement publication cannot interleave the atomic configure-and-switch transaction.

Do not use the previously prepared airdrop directories after switching. They embed the previous resolver. Fresh airdrop preparation must read the replacement and rerun qualification. The current Sphinx resume validation rejects stale preparations. Previously signed native Safe distribution transactions do not automatically lose authorization and their migration helper can still use the obsolete resolver. Inventory existing signatures with the owners; any old authorized distributions must be invalidated with reviewed cancellation/replacement transactions at their Safe nonces or evidence that those nonces were consumed. Deleting a queue entry is insufficient. Consuming one nonce does not invalidate later nonces.

Choose executable Safe nonces for these stages, accounting for unrelated pending prerequisites. Do not append the upgrade behind old distributions or silently replace unrelated configuration transactions. Builder JSON does not enforce a nonce. OP Sepolia and Arbitrum Sepolia need their established direct native Safe approval/execution route if the hosted Safe app still does not support them; these Builder files alone do not provide that transport.

After deployment and the collection switch are verified, update the resolver deployment registry record used by `BannyverseDeploymentLib`, `Drop1.s.sol` and `Add.Denver.s.sol`. Those catalog scripts otherwise target the old resolver. Do not update registry addresses before the deployment is verified.

A switch back to the old resolver is safe only while the collection has never minted (including any later burns) and both resolvers hold no NFTs. The guard requires injected storage on its replacement target, so it cannot be reused to activate the original resolver, which has no storage getter. A reversal requires a separately reviewed guard for that target and verified fingerprints in the same atomic batch as the reverse setter. After minting or dressing, this rollout deliberately refuses rollback; resolver-owned custody and outfit state would require a separate migration.
