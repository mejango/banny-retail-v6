# Audit Instructions

This repo is the Banny avatar composition layer. It does not mint the base NFTs, but it does custody equipped accessories and define the metadata users see.

## Audit Objective

Find issues that:
- strand outfits or backgrounds in resolver custody
- let the wrong actor equip, unequip, overwrite, or recover accessories
- break outfit-lock timing or freeze a body longer than intended
- return metadata that does not match stored attachment state
- bypass category or layering constraints

## Scope

In scope:
- `src/Banny721TokenUriResolver.sol`
- `src/interfaces/IBanny721TokenUriResolver.sol`
- all deployment helpers in `script/`

## Start Here

1. `src/Banny721TokenUriResolver.sol`
2. accessory receipt and release paths
3. deployment wiring in `script/`

## Security Model

The resolver is an attachment and rendering layer around a `JB721TiersHook` collection.
- the underlying 721 hook remains the token contract and source of body ownership
- the resolver temporarily holds accessory NFTs while they are equipped
- body ownership should be the only authority that changes equipped state
- accessory contracts may be hostile or malformed, so receipt and release ordering matters

## Roles And Privileges

| Role | Powers | How constrained |
|------|--------|-----------------|
| Body owner | Equip, unequip, and lock accessories | Must be derived from the current hook-reported owner |
| Resolver owner | Update metadata and SVG-related admin state | Must not control equipped-state authorization |
| Accessory NFT contract | Execute callbacks during custody changes | Must not corrupt bookkeeping or steal custody |

## Integration Assumptions

| Dependency | Assumption | What breaks if wrong |
|------------|------------|----------------------|
| `JB721TiersHook` | Reports authentic body ownership and tier metadata | Unauthorized decoration or incorrect rendering |
| Accessory ERC-721s | Behave like standard transferable NFTs | Custody or release flows fail unexpectedly |

## Critical Invariants

1. Every accessory transferred into the resolver remains attributable to one body or is recoverable by the rightful owner.
2. Only the current body owner or an intended delegate can change that body's equipped state.
3. Conflicting categories cannot be equipped together, including through replacement or invalidation edge paths.
4. Outfit-lock state only affects the intended body for the intended duration.
5. Metadata and SVG generation reflect current state and do not expose impossible combinations.

## Attack Surfaces

- decoration entrypoints that replace one accessory with another
- ERC-721 receipt hooks and any path that accepts custody
- release paths after redecorating, burning, or invalid token state
- category validation and conflict checks
- metadata assembly that assumes on-chain assets or tier data remain available

## Accepted Risks Or Behaviors

- Equipped accessories intentionally follow the body unless they are unequipped first.
- Preserving attribution on failed transfer-out is safer than dropping custody state.

## Verification

- `npm install`
- `forge build`
- `forge test`
