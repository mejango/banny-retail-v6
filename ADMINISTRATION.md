# Administration

## At A Glance

| Item | Details |
| --- | --- |
| Scope | `Banny721TokenUriResolver` metadata, SVG commitments, and outfit-state control |
| Control posture | Global `Ownable` metadata control plus per-body owner control |
| Highest-risk actions | Wrong SVG hash commitments, incorrect metadata updates, and long outfit locks |
| Recovery posture | Metadata is editable, but committed hashes, uploaded SVGs, and active locks are not reversible |

## Purpose

`banny-retail-v6` has a small but real control plane. The resolver owner controls collection-wide metadata and SVG commitments. Body owners control decoration and outfit locks. No admin can rescue equipped NFTs if resolver logic fails.

## Control Model

- `Banny721TokenUriResolver` is `Ownable`.
- Global admin power is limited to metadata, product naming, and SVG hash commitments.
- Actual SVG upload is permissionless once the hash is committed.
- Body owners control decoration and locking for their own bodies.
- Equipped accessories are held by the resolver while attached.

## Roles

| Role | How Assigned | Scope | Notes |
| --- | --- | --- | --- |
| Resolver owner | `Ownable(owner)` at construction | Global | Can transfer ownership with `transferOwnership()` |
| Body owner | `IERC721(hook).ownerOf(bannyBodyId)` | Per body | Can decorate and lock that body |
| Anyone | No assignment | Global | Can upload SVG bytes only if they match a committed hash |

## Privileged Surfaces

| Contract | Function | Who Can Call | Effect |
| --- | --- | --- | --- |
| `Banny721TokenUriResolver` | `setMetadata(...)` | Resolver owner | Changes global description, URL, and base URI |
| `Banny721TokenUriResolver` | `setProductNames(...)` | Resolver owner | Changes display names for products |
| `Banny721TokenUriResolver` | `setSvgHashesOf(...)` | Resolver owner | Commits write-once SVG hashes for UPCs |
| `Banny721TokenUriResolver` | `setSvgContentsOf(...)` | Anyone with matching bytes | Uploads write-once SVG payloads for committed hashes |
| `Banny721TokenUriResolver` | `decorateBannyWith(...)` | Current body owner | Equips or unequips accessories and updates custody |
| `Banny721TokenUriResolver` | `lockOutfitChangesFor(...)` | Current body owner | Extends the outfit lock window for that body |

## Immutable And One-Way

- SVG hash commitments are write-once.
- SVG contents are write-once once uploaded.
- `lockOutfitChangesFor(...)` only extends the active lock.
- The lock duration is fixed by `_LOCK_DURATION`.
- Default art fragments, category semantics, and the trusted forwarder are constructor or code immutables.

## Operational Notes

- Treat `setSvgHashesOf(...)` like a release gate. A wrong hash usually means a new resolver or new UPC strategy, not a small edit.
- Treat `setMetadata(...)` and `setProductNames(...)` as collection-wide display changes.
- Remind users that equipped assets are in resolver custody while attached.
- Only lock outfits when temporary non-editability is the intended experience.
- Use safe ERC-721 transfer flows when assets enter the resolver path. Plain `transferFrom` can strand NFTs without a recovery path.

## Machine Notes

- Do not assume there is a rescue path for equipped assets. There is none.
- Treat `src/Banny721TokenUriResolver.sol` as the source of truth for lock extension and write-once SVG behavior.
- If a committed hash and intended asset bytes differ, stop. The contract does not support overwrite repair.
- If an asset arrived through non-safe ERC-721 transfer semantics, do not assume the resolver can detect or recover it.

## Recovery

- Bad metadata can be changed by the owner.
- Bad SVG commitments or uploaded content cannot be corrected in place.
- If equipped assets become stuck because of resolver logic, there is no owner rescue path.
- If NFTs are stranded through non-safe transfer semantics, this contract does not provide recovery.

## Admin Boundaries

- The owner cannot arbitrarily withdraw equipped user NFTs.
- The owner cannot overwrite committed hashes or uploaded SVG contents.
- The owner cannot bypass body-owner checks on decoration or locking.
- Nobody can shorten an active outfit lock.
- There is no pause, upgrade, or rescue mechanism.

## Source Map

- `src/Banny721TokenUriResolver.sol`
- `src/interfaces/IBanny721TokenUriResolver.sol`
- `script/Deploy.s.sol`
- `test/TestAuditGaps.sol`
- `test/TestQALastMile.t.sol`
