# banny-retail-v5

On-chain composable avatar system for Juicebox 721 collections -- manages Banny character bodies, backgrounds, and outfit NFTs with layered SVG rendering.

## Architecture

| Contract | Description |
|----------|-------------|
| `Banny721TokenUriResolver` | The sole contract. Implements `IJB721TokenUriResolver` to serve fully on-chain SVG token URIs for any Juicebox 721 hook. Manages a composable asset system where Banny body NFTs can be dressed with outfit NFTs and placed on background NFTs, all rendered as layered SVGs with base64-encoded JSON metadata. Owner can register SVG content and hashes for product IDs (UPCs). |

### Asset Categories

| Category ID | Name | Role |
|-------------|------|------|
| 0 | Body | The base Banny character. Owns outfits and backgrounds. |
| 1 | Background | Scene behind the Banny. One per body. |
| 2 | Backside | Layer behind the body. |
| 3 | Necklace | Accessory layer (default provided). |
| 4 | Head | Head accessory. One per body. |
| 5 | Eyes | Eye style (defaults: standard, alien). |
| 6 | Glasses | Eyewear layer. |
| 7 | Mouth | Mouth expression (default provided). |
| 8 | Legs | Lower body clothing. |
| 9 | Suit | Full body suit (one-piece). |
| 10 | Suit Bottom | Lower suit piece. |
| 11 | Suit Top | Upper suit piece. |
| 12 | Headtop | Top-of-head accessory. |
| 13 | Hand | Held item layer. |
| 14-17 | Special variants | Special suit, legs, head, and body overlays. |

## Install

```bash
npm install @bannynet/core-v5
```

## Develop

`banny-retail-v5` uses [npm](https://www.npmjs.com/) for package management and [Foundry](https://github.com/foundry-rs/foundry) for builds, tests, and deployments. Requires `via-ir = true` in foundry.toml.

```bash
curl -L https://foundry.paradigm.xyz | sh
npm install && forge install
```

| Command | Description |
|---------|-------------|
| `forge build` | Compile contracts and write artifacts to `out`. |
| `forge test` | Run the test suite. |
| `forge fmt` | Lint Solidity files. |
| `forge build --sizes` | Get contract sizes. |
| `forge coverage` | Generate a test coverage report. |
| `forge clean` | Remove build artifacts and cache. |
