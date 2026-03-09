# banny-retail-v6 — Risks

## Trust Assumptions

1. **Contract Owner** — Can store asset content, add products, and configure categories. Full control over available artwork and composition rules.
2. **JB721TiersHook** — Relies on the 721 hook to correctly call `tokenURI`. Resolver trusts the hook's tier and token data.
3. **On-Chain Storage** — All SVG artwork stored on-chain. Storage costs are significant but artwork is permanent and censorship-resistant.

## Known Risks

| Risk | Description | Mitigation |
|------|-------------|------------|
| Outfit lock griefing | Outfit NFTs are transferred to the resolver when equipped — if resolver is compromised, outfits are stuck | ReentrancyGuard protects dress/undress; owner can set lock duration |
| Lock duration abuse | Owner can set outfit lock durations, preventing undressing | Lock can only be shortened, not extended (`CantAccelerateTheLock`) |
| SVG rendering | Complex SVG composition may render incorrectly in some clients | Tested across major NFT marketplaces |
| Gas-intensive tokenURI | On-chain SVG generation is gas-heavy for view calls | Only affects off-chain reads (view function) |
| Content immutability | Once stored, content chunks cannot be modified (keyed by hash) | By design — ensures NFT artwork stability |
| Category ordering | Categories must be added in order (`UnorderedCategories` revert) | Validate category order off-chain |

## Privileged Roles

| Role | Capabilities | Scope |
|------|-------------|-------|
| Owner | Store content, add products, configure categories, set lock durations | Global |
| NFT holders | Dress/undress their body NFTs | Per-token |
| JB721TiersHook | Request tokenURI generation | Per-hook |
