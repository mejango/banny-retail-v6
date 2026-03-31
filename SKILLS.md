# Banny Retail

## Use This File For

- Use this file when the task involves Banny outfit attachment, layered SVG rendering, token URI composition, or asset custody and lock behavior.
- Start here, then open the resolver, scripts, or tests that match the exact rendering or attachment path in question.

## Read This Next

| If you need... | Open this next |
|---|---|
| Repo overview and user-facing behavior | [`README.md`](./README.md), [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Resolver implementation | [`src/Banny721TokenUriResolver.sol`](./src/Banny721TokenUriResolver.sol) |
| Deployment or scripted drops | [`script/Deploy.s.sol`](./script/Deploy.s.sol), [`script/Drop1.s.sol`](./script/Drop1.s.sol), [`script/Add.Denver.s.sol`](./script/Add.Denver.s.sol) |
| Decoration lifecycle and regressions | [`test/DecorateFlow.t.sol`](./test/DecorateFlow.t.sol), [`test/OutfitTransferLifecycle.t.sol`](./test/OutfitTransferLifecycle.t.sol), [`test/regression/`](./test/regression/) |
| Adversarial or QA coverage | [`test/BannyAttacks.t.sol`](./test/BannyAttacks.t.sol), [`test/TestQALastMile.t.sol`](./test/TestQALastMile.t.sol), [`test/audit/`](./test/audit/) |

## Repo Map

| Area | Where to look |
|---|---|
| Main contract | [`src/Banny721TokenUriResolver.sol`](./src/Banny721TokenUriResolver.sol) |
| Scripts | [`script/`](./script/) |
| Tests | [`test/`](./test/) |

## Purpose

Application-layer token URI resolver for Juicebox 721 collections that lets Banny body NFTs equip outfit and background NFTs, custody them while equipped, and render fully on-chain layered SVG metadata.

## Reference Files

- Open [`references/runtime.md`](./references/runtime.md) when you need attachment and custody behavior, rendering order, or the main invariants that protect equipped assets.
- Open [`references/operations.md`](./references/operations.md) when you need upload and metadata-management behavior, deployment breadcrumbs, or the common stale-data traps around SVG content and scripts.

## Working Rules

- Start in [`src/Banny721TokenUriResolver.sol`](./src/Banny721TokenUriResolver.sol) for both rendering and attachment behavior. This repo is mostly one contract with several tightly coupled responsibilities.
- Treat custody, stale attachment cleanup, and lock timing as high-risk. Rendering bugs are visible, but custody bugs are worse.
- When a task mentions minting, pricing, or terminal accounting, verify that the problem is not actually in the upstream 721 hook repo.
- If you touch SVG or metadata behavior, check whether the issue is in stored content, rendering composition, or the hook-to-resolver integration point before patching.
