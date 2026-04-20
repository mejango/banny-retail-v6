# Banny Retail

Banny Retail is an on-chain avatar system for Juicebox 721 collections. A body NFT can wear outfit NFTs, sit on a background NFT, and resolve to a base64-encoded JSON token URI whose image field contains an on-chain SVG.

Docs: <https://docs.juicebox.money>
Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)  
User journeys: [USER_JOURNEYS.md](./USER_JOURNEYS.md)  
Skills: [SKILLS.md](./SKILLS.md)  
Risks: [RISKS.md](./RISKS.md)  
Administration: [ADMINISTRATION.md](./ADMINISTRATION.md)  
Audit instructions: [AUDIT_INSTRUCTIONS.md](./AUDIT_INSTRUCTIONS.md)

## Overview

This is a resolver-centric application built on top of [`@bananapus/721-hook-v6`](https://www.npmjs.com/package/@bananapus/721-hook-v6). The resolver owns attached outfit and background NFTs while a body is decorated, then composes the active layers into a single token URI response.

The main user flows are:

- mint body, outfit, and background NFTs through a Juicebox 721 hook
- attach accessories to a body with `decorateBannyWith`
- optionally freeze the current look for seven days with `lockOutfitChangesFor`
- upload SVG payloads lazily after an owner registers their content hashes

Use this repo when you need collection-specific, fully on-chain metadata composition on top of Juicebox NFTs. Do not use it as a generic 721 hook; it is an application-layer resolver, not a protocol NFT primitive.

If a bug changes tier pricing, mint eligibility, or treasury flow, it is probably not here first. Start in the 721 hook repo and only come here once the issue is clearly in attachment, custody, or rendering behavior.

## Key Contract

| Contract | Role |
| --- | --- |
| `Banny721TokenUriResolver` | Resolves token metadata, stores equipped accessories, enforces outfit locks, and renders layered SVG output for Banny collections. |

## Mental Model

This repo owns three things:

1. custody of attached outfit and background NFTs while equipped
2. rules around what a body can wear and when that can change
3. rendering of the final token metadata payload

It does not own mint pricing, tier issuance, or project accounting.

## Read These Files First

1. `src/Banny721TokenUriResolver.sol`
2. `test/DecorateFlow.t.sol`
3. `test/OutfitTransferLifecycle.t.sol`
4. `nana-721-hook-v6/src/JB721TiersHook.sol` for upstream mint and tier behavior

## High-Signal Tests

1. `test/DecorateFlow.t.sol`
2. `test/OutfitTransferLifecycle.t.sol`
3. `test/audit/BurnedBodyStrandsAssets.t.sol`
4. `test/audit/TryTransferFromStrandsAssets.t.sol`
5. `test/TestQALastMile.t.sol`

## Integration Traps

- the resolver custodies equipped assets, so transfer edge cases matter as much as rendering output
- transferred bodies carry their equipped assets, so a new body holder can inherit control of those items
- burned bodies and non-safe transfer patterns can strand expectations around resolver-held assets unless integrations model the attachment lifecycle correctly
- outfit locks persist across body transfers until expiry, so a new holder can inherit a still-locked body
- metadata quality depends on lazily uploaded asset payloads, not only on the token state
- collection logic here assumes a Juicebox 721 hook upstream and should not be read as a generic NFT renderer

## Where State Lives

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
forge build
forge test
```

Useful scripts:

- `npm run deploy:mainnets`
- `npm run deploy:testnets`
- `npm run deploy:mainnets:drop:1`
- `npm run deploy:testnets:drop:1`

## Deployment Notes

Deployments are handled through Sphinx using the environments configured in `script/Deploy.s.sol`. The resolver is intended to be plugged into a Juicebox 721 hook as that hook's token URI resolver.

## Repository Layout

```text
src/
  Banny721TokenUriResolver.sol
  interfaces/
test/
  unit, attack, fork, audit, QA, and regression coverage
script/
  Deploy.s.sol
  Drop1.s.sol
  Add.Denver.s.sol
  helpers/
```

## Risks And Notes

- attached outfits and backgrounds are custodied by the resolver while equipped
- outfit locks are fixed-duration and cannot be shortened once set
- on-chain SVG content is immutable once uploaded for a given registered hash
- ERC-721 `transferFrom` paths that bypass safe-receive checks can still create asset-tracking surprises around resolver custody
- rendering quality and metadata correctness depend on the integrity of uploaded SVG assets

## For AI Agents

- Treat this repo as an application-layer resolver, not as the NFT issuance primitive.
- Start with `Banny721TokenUriResolver` and the lifecycle tests before summarizing attachment behavior.
- If the question is about mint economics or tier availability, inspect `nana-721-hook-v6` instead of inferring from this repo.
