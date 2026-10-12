# Banny Retail

`@bannynet/core-v6` is the onchain avatar layer for Juicebox 721 collections. It defines how a body NFT wears outfit NFTs, uses a background NFT, and resolves to a base64 JSON token URI whose image is an onchain SVG.


## Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — system structure and contract responsibilities
- [USER_JOURNEYS.md](./USER_JOURNEYS.md) — end-to-end flows for body owners and asset holders
- [INVARIANTS.md](./INVARIANTS.md) — properties guaranteed by the resolver
- [RISKS.md](./RISKS.md) — known risks and edge cases
- [ADMINISTRATION.md](./ADMINISTRATION.md) — owner-only actions and operational levers
- [AUDIT_INSTRUCTIONS.md](./AUDIT_INSTRUCTIONS.md) — guidance for security reviewers
- [SKILLS.md](./SKILLS.md) — repo-specific gotchas and integration notes
- [STYLE_GUIDE.md](./STYLE_GUIDE.md) — coding and naming conventions
- [CHANGELOG.md](./CHANGELOG.md) - V5 to V6 migration changelog

## Overview

This is a resolver-centric app built on top of [`@bananapus/721-hook-v6`](https://www.npmjs.com/package/@bananapus/721-hook-v6). The resolver holds attached outfit and background NFTs while a body is decorated, then composes the active layers into a single token URI response.

The main user flows are:

- mint body, outfit, and background NFTs through a Juicebox 721 hook
- attach accessories to a body with `decorateBannyWith`
- optionally freeze the look for seven days with `lockOutfitChangesFor`
- upload SVG payloads after an owner registers the content hashes

Use this repo when you need collection-specific, fully onchain metadata composition on top of Juicebox NFTs. Do not use it as a generic 721 hook. It is an app-layer resolver, not a protocol NFT primitive.

## Key contract

| Contract | Role |
| --- | --- |
| `Banny721TokenUriResolver` | Resolves metadata, stores equipped accessories, enforces outfit locks, and renders layered SVG output for Banny collections. |

## Mental model

This repo owns three things:

1. custody of outfit and background NFTs while they are equipped
2. rules for what a body can wear and when that can change
3. rendering of the final metadata payload

It does not own mint pricing, tier issuance, or treasury accounting.

## Read these files first

1. `src/Banny721TokenUriResolver.sol`
2. `test/DecorateFlow.t.sol`
3. `test/OutfitTransferLifecycle.t.sol`
4. `nana-721-hook-v6/src/JB721TiersHook.sol` for upstream mint and tier behavior

## High-signal tests

1. `test/DecorateFlow.t.sol`
2. `test/OutfitTransferLifecycle.t.sol`
3. `test/regression/BurnedBodyStrandsAssets.t.sol`
4. `test/regression/TryTransferFromStrandsAssets.t.sol`
5. `test/TestQALastMile.t.sol`

## Integration traps

- the resolver holds equipped assets, so transfer edge cases matter as much as rendering output
- transferred bodies carry their equipped assets, so a new body holder can inherit control of them
- burned bodies and non-safe transfer patterns can strand expectations around resolver-held assets
- outfit locks survive body transfers until expiry
- metadata quality depends on lazily uploaded asset payloads, not only token state

## Where state lives

- equipped outfit and background state live in `Banny721TokenUriResolver`
- layer rendering and token URI generation live in the same resolver
- mint pricing, tier inventory, and treasury behavior live upstream in `nana-721-hook-v6`

## Install

```bash
npm install @bannynet/core-v6
```

## Development

The contract stack relies on `via_ir = true` in `foundry.toml`.

```bash
npm install
forge build --deny notes
forge test --deny notes
```

Useful scripts:

- `npm run deploy:mainnets`
- `npm run deploy:testnets`
- `npm run deploy:mainnets:drop:1`
- `npm run deploy:testnets:drop:1`

## Deployment notes

Deployments are handled through Sphinx using the environments configured in `script/Deploy.s.sol`. The resolver is meant to be plugged into a Juicebox 721 hook as that hook's token URI resolver.

### Airdrop through Sphinx

Use the repository's proposal command so the airdrop uses the same guarded, atomic mint-and-migration batches as the Safe exports:

```sh
npm run deploy:testnets:airdrop -- --dry-run
npm run deploy:testnets:airdrop
npm run deploy:mainnets:airdrop -- --dry-run
npm run deploy:mainnets:airdrop
```

The owned adapter collects project/Safe/module configuration from `AirdropV4Bannys.s.sol`, prepares the canonical distribution, and tests signed actions in separate transactions on pinned local forks through the real relay, module and Safe. It checks action success events, completed roots, exact NFT recipients/outfits and empty custody before upload. Proposal-time collection alone is insufficient: its warm gas measurements previously underestimated a cold migration action. Qualification reports and upload progress are saved under `safe-airdrop/sphinx-*`, outside Foundry's regenerable cache.

The command splits consecutive actions into ordered proposal parts whose complete execution estimate fits the chain's transaction budget. Cold measurements set signed gas; where the usual extra padding exceeds that budget, a capped allowance is permitted only with at least 120,000 measured gas of headroom and successful exact-root replay. A large block gas limit is not additional transaction capacity. The existing `:batch1` through `:batch8` aliases retain original chunk selection, and `:combined`/`:unchunked` use the same bounded path. Use these npm commands rather than invoking `npx sphinx propose` directly for this airdrop or relying on `SPHINX_ALLOW_HIGH_GAS_ACTIONS`.

All parts are verified first, but a live command submits **one part**. Approve and execute it in Sphinx on every participating chain, then run the printed resume command:

```sh
node ./script/outfit_drop/propose-sphinx-airdrop.js resume safe-airdrop/sphinx-YOUR_PREPARATION
```

Resume checks the exact prior roots completed, current module nonces, unchanged sources and canonical remaining calls before submitting the next part. It refuses duplicates while a part is pending or its submission is uncertain. `--dry-run` previews without uploading. Keep the preparation directory and its `proposal-progress.json`; a normal new proposal command starts a new preparation. The published platform [cancels an earlier pending proposal when a different root is proposed](https://github.com/sphinx-labs/sphinx-platform/blob/11e36f431de70bdd5374f21c30f393ee2432931e/website/server/api/propose/index.ts#L266-L309), so parts must follow this serial flow.

Local qualification cannot certify the service's current transaction-gas settings. An upload rejection must be investigated before retrying; retain any successful proposal roots. Sphinx module execution does not consume the ordinary Safe nonce. Existing native approvals remain authorized: keep the old native airdrop queue untouched while using this route, and coordinate with the other signer. This tooling does not repair the separately identified artwork configuration.

### Airdrop without Sphinx

Prepare unsigned Safe Transaction Builder files from the same snapshot, recipients and V6 token assignments as `AirdropV4Bannys.s.sol`:

```sh
npm run export:testnets:airdrop:safe
npm run export:mainnets:airdrop:safe
```

These commands build the required contracts, load RPCs from `.env`, check the destination chain, deployed hook/resolver, Safe mint permission and batching/deployment contracts, and write `safe-airdrop/testnets/` or `safe-airdrop/mainnets/`. They do not sign, queue or execute transactions. `BANNY_AIRDROP_DEPLOYMENTS_PATH` retains the deployment-artifact override. The default Safe comes from `banny-core` in `sphinx.lock`, currently `0x9E2a10aB3BD22831f19d02C648Bc2Cb49B127450`.

The original large chunks exceed Ethereum's [16,777,216 gas transaction ceiling](https://eips.ethereum.org/EIPS/eip-7825), even with deployment separated. The exporter partitions each original chunk into at most 40 tokens, preserving the original per-tier mint order and keeping each body with all its attached assets. Cyclic ordering dependencies stay together. It reuses the existing parameterized migration helper through a small `SafeAirdropExecutor` that accepts only calls from the Safe; recipient callbacks cannot invoke migration methods on its custody. No original snapshot or generated Sphinx migration is changed.

Each chain directory contains numbered Builder `.json` files and matching `.safe-tx.json` native envelopes. Execute setup first, followed by migration files in numeric order. Setup deploys the implementation and executor and mints zero NFTs. Each migration atomically mints, dresses, transfers and checks the executor retains no tokens. Do not split its calls; combine files only through the verified native-bundling workflow below. `manifest.json` lists the precise order and token counts. A verified predeployed setup can be reused; conflicting code or configuration aborts export.

For Ethereum, Optimism, Base, Arbitrum, Ethereum Sepolia and Base Sepolia, open the Safe on the matching network, choose **New transaction → Transaction Builder**, import a numbered Builder file (not its `.safe-tx.json` companion), review the calls, and submit to the queue. Choose consecutive available Safe nonces in file order, accounting for existing queued transactions. Owners confirm through the usual multisig flow. [Safe's Transaction Builder documentation](https://help.safe.global/articles/4180673514-transaction-builder) describes JSON import.

Safe's hosted configuration excludes OP Sepolia and Arbitrum Sepolia (checked 2026-10-07). Their native transactions work onchain, but these networks have no hosted Safe queue. To coordinate approvals onchain, choose an unused starting Safe nonce with the owners, then bind an export to it (replace `NEXT_NONCE`):

```sh
npm run export:testnets:airdrop:safe -- --chain 11155420 --start-nonce NEXT_NONCE --out safe-airdrop/op-sepolia-approved
```

Use chain 421614 for Arbitrum Sepolia. Every native envelope then includes `safeTxHash` and `approveHashTransaction`. Each owner sends the approval **from their own owner wallet**, or uses [Safe CLI](https://docs.safe.global/advanced/cli-reference/common-commands) `approve_hash HASH OWNER` after loading their hardware wallet. These approvals cost testnet gas and authorize the exact chain, nonce and transaction hash; they do not execute the airdrop. Keep the envelope unchanged between owners.

For MetaMask, [Remix supports loading an existing contract from its ABI](https://remix-ide.readthedocs.io/en/latest/run.html#using-the-abi-to-load-contracts). Open a `.abi` file containing the Safe's `approveHash(bytes32)`, `approvedHashes(address,bytes32)`, `nonce()`, `getOwners()` and `getThreshold()` entries from the installed Safe artifact. In **Deploy & Run**, select **Browser Extension → MetaMask**, then **Deployed Contracts → Add Contract** using the Safe address. This loads the existing Safe without compiling or deploying. Select the correct testnet, read `nonce()` to check the prepared setup nonce, then call `approveHash` with the envelope's `safeTxHash`, sending zero ETH. Each of two current owners performs that approval separately; `approvedHashes(owner, hash)` returns `1` after confirmation. The Safe nonce is not MetaMask's account transaction nonce. These testnet explorers do not currently provide a usable proxy/custom-ABI write flow, so do not assume a `Write as Proxy` link will work.

Once enough current owners have approved and that file's nonce is the Safe's current nonce, prepare its execution:

```sh
npm run prepare:airdrop:safe-execution -- path/to/numbered-file.safe-tx.json
```

This read-only command verifies the live nonce, hash, current owners and stored approvals, then writes a `.safe-tx.execution.json` file. An executor wallet sends the `transaction.to`, `transaction.value` and `transaction.data` fields to execute the approved Safe transaction. For example, a Ledger user can send those fields with Foundry:

```sh
set -a
source ./.env
set +a
cast send --ledger --rpc-url "$RPC_OPTIMISM_SEPOLIA" \
  "$(jq -r '.transaction.to' path/to/file.safe-tx.execution.json)" \
  --data "$(jq -r '.transaction.data' path/to/file.safe-tx.execution.json)"
```

That final command broadcasts and executes; the export/preparation commands do not. Safe CLI's `send_custom` in blockchain mode requires threshold signers loaded together and does not replace this stored-approval execution step.

Rehearse the exact files using local forks before queueing:

```sh
npm run simulate:airdrop:safe -- safe-airdrop/testnets
npm run simulate:airdrop:safe -- safe-airdrop/mainnets
```

This requires `anvil`. It executes the actual Safe path using locally impersonated owners, verifies every recipient and outfit, records gas, and checks rollback for mint drift, replay and out-of-order batches. Use `--chain ID` for one network and `--chain ID --block NUMBER` to pin its fork. `simulation.json` records status, source blocks and exact file hashes; only `passed` for all expected chains proves the full rehearsal.

Different exports are never silently overwritten; use a new `--out` directory when inputs change. Rehearse again after snapshot, code, deployment or chain-state changes. Mainnet V4 ownership/outfit changes must be investigated, not bypassed. Retain successful receipts and continue only with unexecuted files; replaying completed migration files reverts. Previously approved transactions remain authorized until their nonce is consumed, so do not queue overlapping Sphinx and native migrations.

### Fewer signatures through native Safe bundles

Consecutive migrations can share one Safe MultiSend transaction while preserving every original mint/helper call and its order. Setup remains separate. The selector minimizes contiguous merges of the existing atomic shards under 95% of each verified cap: 15,938,355 gas on Ethereum, Optimism and Base networks, and 30,400,000 execution gas on Arbitrum networks, excluding L1 posting gas. This minimum applies to the complete interval graph tested against original-shard prefix states; the chosen sequence is separately replayed at its actual nonces. First run the exact current setup, prerequisite and original migration files through the fork selector:

```sh
npm run simulate:airdrop:safe -- PATH_TO_REVIEWED_INPUT --select-bundles --report safe-airdrop/bundle-selection.json
npm run bundle:airdrop:safe -- --source PATH_TO_ORIGINAL_SITE_PROPOSALS --audit safe-airdrop/audit-2026-10-08 --report safe-airdrop/bundle-selection.json --out safe-airdrop/bundled-NEW_REVIEW
```

Repeat `--report` for separate per-chain reports. The export requires successful exact-fork hashes for every chain, verifies original audit checksums and checks that setup is still unexecuted and old distribution hashes remain unapproved. It writes fresh nonce-bound envelopes, Builder companions, `proposals.json`, the original `source-proposals.json` and verification evidence without overwriting previous exports. Combined or renumbered bundles need new approvals; unchanged hashes retain existing approvals. Keep the exact native envelopes between signers because a Builder UI may change the batching contract and therefore the signed hash. Neither command signs or broadcasts to upstream chains.

For actual Arbitrum execution, use a fresh Nitro gas estimate including L1 posting gas; the recorded 30,400,000 execution budget is not a cap on the wallet transaction's total gas limit.

A two-bundle certificate is also supported with `--two-bundle-split N` on the simulator: the whole distribution must actually run out of gas at the reviewed limit, then both selected bundles must pass the full replay. Transport or mining timeouts never establish that lower bound. If an earlier complete report used a frozen runner revision, pass its exact archived file with `--runner-source PATH` to the exporter; composer and generator hashes must still match current files.

### Uploading the reviewed bundles through Safe

Safe's hosted Transaction Builder uses a different `MultiSendCallOnly` deployment for these Safes. The UI exporter changes only that outer batching address, rebinds the existing nonces and hashes, and preserves every Builder file byte for byte. Ethereum, Optimism, Base, Arbitrum, Sepolia and Base Sepolia use the uploads; OP Sepolia and Arbitrum Sepolia retain their unchanged Site approvals. Existing setup and prerequisite proposals remain unchanged.

```sh
npm run export:airdrop:safe-ui -- --source safe-airdrop/bundled-2026-10-08/proposals.json --inventory PATH_TO_FRESH_QUEUE_INVENTORY --prerequisites safe-airdrop/bundle-selection-2026-10-08/input --out PATH_TO_PREPARED_INPUT
npm run simulate:airdrop:safe -- PATH_TO_PREPARED_INPUT/CHAIN_ID --chain CHAIN_ID --report PATH_TO_CHAIN_REPORT
npm run export:airdrop:safe-ui -- --prepared PATH_TO_PREPARED_INPUT --source safe-airdrop/bundled-2026-10-08/proposals.json --report PATH_TO_CHAIN_REPORT --out safe-airdrop/safe-ui-NEW_REVIEW
```

Run the exact replay for all six supported chains and repeat `--report` for their passed reports. This replays the already selected bundles at the same reviewed gas budgets; it does not repeat the partition search. Final export checks exact input hashes, nonces, recipients, outfits, rollback guards and fresh queue/approval state. The final manifest records the new Safe UI hashes and the prior native-envelope proof as provenance. Import one distribution JSON at a time, retain its listed Safe nonce, and compare the Safe review hash with the manifest before signing; Builder JSON does not itself fix the nonce. Both exporter phases are read-only on upstream chains.

## Repository layout

```text
src/
  Banny721TokenUriResolver.sol
  interfaces/
test/
  unit, attack, fork, review, QA, and regression coverage
script/
  Deploy.s.sol
  Drop1.s.sol
  Add.Denver.s.sol
  helpers/
```

## Risks and notes

- attached outfits and backgrounds are held by the resolver while equipped
- outfit locks are fixed-duration and cannot be shortened once set
- onchain SVG content is immutable once uploaded for a committed hash
- plain `transferFrom` can still create asset-tracking surprises around resolver custody
- rendering quality depends on the integrity of uploaded SVG assets

## For AI agents

- Treat this repo as an app-layer resolver, not as the NFT issuance primitive.
- Start with `Banny721TokenUriResolver` and the lifecycle tests before summarizing attachment behavior.
- If the question is about mint economics or tier availability, inspect `nana-721-hook-v6` instead.
