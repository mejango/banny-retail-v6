# Banny Runtime

## Contract Role

- [`src/Banny721TokenUriResolver.sol`](../src/Banny721TokenUriResolver.sol) resolves token metadata, stores equipped outfits and backgrounds, enforces outfit locks, and composes layered SVG output for Banny collections.

## Runtime Path

1. The hook calls the resolver for `tokenURI`-style metadata.
2. The resolver reads tier and ownership context from the upstream 721 hook.
3. If the token is a body, it composes background, body, and equipped items into a single SVG.
4. If the token is an outfit or background, it renders a preview-style representation instead.
5. During decoration flows, the resolver takes custody of attached items and updates wearer/background mappings.

## High-Risk Areas

- Attachment custody: equipped items are held by the resolver, so transfer and return behavior matters.
- Outfit lock windows: lock duration is part of user-facing state and should not drift unexpectedly.
- Rendering composition: layer ordering and default-item behavior affect visible output and must stay deterministic.
- Stale attachment cleanup: views intentionally guard against inconsistent attachment state.

## Tests To Trust First

- [`test/DecorateFlow.t.sol`](../test/DecorateFlow.t.sol) for the main equip/unequip lifecycle.
- [`test/OutfitTransferLifecycle.t.sol`](../test/OutfitTransferLifecycle.t.sol) for custody and return behavior.
- [`test/BannyAttacks.t.sol`](../test/BannyAttacks.t.sol) for adversarial flows.
- [`test/Fork.t.sol`](../test/Fork.t.sol), [`test/TestAuditGaps.sol`](../test/TestAuditGaps.sol), and [`test/TestQALastMile.t.sol`](../test/TestQALastMile.t.sol) for integration and pinned edge cases.
