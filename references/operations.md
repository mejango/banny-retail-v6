# Banny Operations

## Content and Deployment Surface

- [`script/Deploy.s.sol`](../script/Deploy.s.sol) is the main deployment entry point.
- [`script/Drop1.s.sol`](../script/Drop1.s.sol) and [`script/Add.Denver.s.sol`](../script/Add.Denver.s.sol) are the first places to check when a problem is drop-specific rather than core resolver logic.
- The resolver's metadata and SVG-content management functions live in [`src/Banny721TokenUriResolver.sol`](../src/Banny721TokenUriResolver.sol), not in separate admin helpers.

## Change Checklist

- If you edit decoration behavior, verify both attachment and return-to-owner paths.
- If you edit SVG rendering, re-check default layer injection and non-body preview rendering.
- If you edit content upload assumptions, verify hash registration and one-time content storage still match.
- If you edit metadata fields, check whether the issue belongs in resolver config or in the upstream hook that points to the resolver.

## Common Failure Modes

- Visible rendering issue is really stale or missing SVG content rather than code logic.
- Resolver is blamed for minting or tier problems that actually live upstream in the 721 hook repo.
- Attachment state looks inconsistent because a prior transfer or return failed and the resolver intentionally preserved safety over convenience.

## Useful Proof Points

- [`test/BannyAttacks.t.sol`](../test/BannyAttacks.t.sol) and [`test/TestAuditGaps.sol`](../test/TestAuditGaps.sol) for security-sensitive assumptions.
- [`script/Drop1.s.sol`](../script/Drop1.s.sol) and [`script/Add.Denver.s.sol`](../script/Add.Denver.s.sol) when a deployment issue is really a script/config problem.
