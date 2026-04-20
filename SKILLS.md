# Banny Retail

## Use This File For

- Use this file when the task involves Banny outfit attachment, layered SVG rendering, token URI composition, or asset custody and lock behavior.
- Start here, then decide whether the issue is custody state, lock timing, stored SVG content, or final token-URI composition.

## Read This Next

| If you need... | Open this next |
|---|---|
| Repo overview and user-facing behavior | [`README.md`](./README.md), [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Resolver implementation | [`src/Banny721TokenUriResolver.sol`](./src/Banny721TokenUriResolver.sol) |
| Runtime and content-management invariants | [`references/runtime.md`](./references/runtime.md), [`references/operations.md`](./references/operations.md) |
| Deployment or scripted drops | [`script/Deploy.s.sol`](./script/Deploy.s.sol), [`script/Drop1.s.sol`](./script/Drop1.s.sol), [`script/Add.Denver.s.sol`](./script/Add.Denver.s.sol) |
| Decoration lifecycle and custody invariants | [`test/DecorateFlow.t.sol`](./test/DecorateFlow.t.sol), [`test/OutfitTransferLifecycle.t.sol`](./test/OutfitTransferLifecycle.t.sol) |
| Adversarial, fork, or final QA coverage | [`test/BannyAttacks.t.sol`](./test/BannyAttacks.t.sol), [`test/Fork.t.sol`](./test/Fork.t.sol), [`test/TestAuditGaps.sol`](./test/TestAuditGaps.sol), [`test/TestQALastMile.t.sol`](./test/TestQALastMile.t.sol) |

## Repo Map

| Area | Where to look |
|---|---|
| Main contract | [`src/Banny721TokenUriResolver.sol`](./src/Banny721TokenUriResolver.sol) |
| Scripts | [`script/`](./script/) |
| Tests | [`test/`](./test/) |

## Purpose

App-layer token URI resolver for Juicebox 721 collections. It lets Banny body NFTs equip outfit and background NFTs, holds them while equipped, and renders fully onchain layered SVG metadata.

## Reference Files

- Open [`references/runtime.md`](./references/runtime.md) for attachment and custody behavior, rendering order, and the main invariants that protect equipped assets.
- Open [`references/operations.md`](./references/operations.md) for upload and metadata-management behavior, deployment breadcrumbs, and common stale-data traps around SVG content.

## Working Rules

- Start in [`src/Banny721TokenUriResolver.sol`](./src/Banny721TokenUriResolver.sol) for both rendering and attachment behavior.
- Treat custody, stale attachment cleanup, and lock timing as high-risk. Rendering bugs are visible, but custody bugs are worse.
- Equipped outfits and backgrounds travel with the body NFT. Treat that inheritance as intentional before calling it a bug.
- When a task mentions minting, pricing, or terminal accounting, verify that the problem is not actually in the upstream 721 hook repo.
- If you touch SVG or metadata behavior, check whether the issue is in stored content, rendering composition, or the hook-to-resolver integration point before patching.
