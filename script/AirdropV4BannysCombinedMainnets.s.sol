// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, stdJson} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
import {AirdropV4BannysCombinedEthereum} from "./AirdropV4BannysCombinedEthereum.sol";
import {AirdropV4BannysCombinedOptimism} from "./AirdropV4BannysCombinedOptimism.sol";
import {AirdropV4BannysCombinedBase} from "./AirdropV4BannysCombinedBase.sol";
import {AirdropV4BannysCombinedArbitrum} from "./AirdropV4BannysCombinedArbitrum.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";

contract AirdropV4BannysCombinedMainnetsScript is Script, Sphinx {
    using stdJson for string;

    address private constant V6_MAINNET_HOOK = 0x37e35937ecF949d7a44a9Fe878107DE264618B8f;
    address private constant V4_HOOK = 0x2da41CdC79Ae49F2725AB549717B2DBcfc42b958;
    address private constant V4_RESOLVER = 0xa5F8911d4CFd60a6697479f078409434424fe666;
    address private constant V4_RESOLVER_FALLBACK = 0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3;

    JB721TiersHook private v6Hook;

    // All raw.json items are minted by this script.

    function configureSphinx() public override {
        sphinxConfig.projectName = vm.envOr("BANNY_AIRDROP_SPHINX_PROJECT", string("banny-core"));
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = new string[](0);
    }

    function run() public {
        v6Hook = JB721TiersHook(_deploymentAddressOf("JB721TiersHook__ProjectBAN"));
        if (_shouldVerifyV4State()) {
            require(address(v6Hook) == V6_MAINNET_HOOK, "Unexpected mainnet V6 hook");
        }
        deploy();
    }

    function deploy() public sphinx {
        _run();
    }

    function _run() internal {
        uint256 chainId = _sourceChainId();

        if (chainId == 1) {
            _runEthereum();
        } else if (chainId == 10) {
            _runOptimism();
        } else if (chainId == 8453) {
            _runBase();
        } else if (chainId == 42161) {
            _runArbitrum();
        } else {
            revert("Unsupported chain");
        }
    }

    function _sourceChainId() internal view returns (uint256) {
        uint256 chainId = block.chainid;

        if (chainId == 1 || chainId == 11155111) return 1;
        if (chainId == 10 || chainId == 11155420) return 10;
        if (chainId == 8453 || chainId == 84532) return 8453;
        if (chainId == 42161 || chainId == 421614) return 42161;

        revert("Unsupported chain");
    }

    function _shouldVerifyV4State() internal view returns (bool) {
        uint256 chainId = block.chainid;
        return chainId == 1 || chainId == 10 || chainId == 8453 || chainId == 42161;
    }

    function _v6Hook() internal view returns (JB721TiersHook) {
        require(address(v6Hook) != address(0), "V6 hook not set");
        return v6Hook;
    }

    function _resolverOf(JB721TiersHook hook) internal view returns (address resolverAddress) {
        resolverAddress = address(hook.STORE().tokenUriResolverOf(address(hook)));
        require(resolverAddress != address(0), "V6 resolver not set");
    }

    function _deploymentAddressOf(string memory name) internal view returns (address addr) {
        string memory root = vm.envOr("BANNY_AIRDROP_DEPLOYMENTS_PATH", string("../deploy-all-v6/deployments/"));
        string memory path = string.concat(root, _chainFolder(), "/", name, ".json");
        string memory json = vm.readFile(path);
        addr = json.readAddress(".address");
        require(addr != address(0), "Missing deployment address");
    }

    function _chainFolder() internal view returns (string memory) {
        if (block.chainid == 1) return "ethereum";
        if (block.chainid == 11155111) return "sepolia";
        if (block.chainid == 10) return "optimism";
        if (block.chainid == 11155420) return "optimism_sepolia";
        if (block.chainid == 8453) return "base";
        if (block.chainid == 84532) return "base_sepolia";
        if (block.chainid == 42161) return "arbitrum";
        if (block.chainid == 421614) return "arbitrum_sepolia";
        revert("Unsupported chain");
    }

    function _chunkFilter() internal view returns (uint256) {
        return vm.envOr("BANNY_AIRDROP_CHUNK", uint256(0));
    }

    function _maxChunkFilter() internal view returns (uint256) {
        return vm.envOr("BANNY_AIRDROP_MAX_CHUNK", uint256(0));
    }

    function _requireValidChunkFilters(uint256 chunkFilter, uint256 maxChunkFilter, uint256 maxChunk) internal pure {
        require(chunkFilter == 0 || maxChunkFilter == 0, "Choose exact chunk or max chunk");
        require(chunkFilter <= maxChunk, "Invalid BANNY_AIRDROP_CHUNK");
        require(maxChunkFilter <= maxChunk, "Invalid BANNY_AIRDROP_MAX_CHUNK");
    }

    function _shouldRunChunk(uint256 chunkFilter, uint256 maxChunkFilter, uint256 chunk) internal pure returns (bool) {
        if (chunkFilter != 0) return chunkFilter == chunk;
        if (maxChunkFilter != 0) return chunk <= maxChunkFilter;
        return true;
    }

    function _runEthereum() internal {
        JB721TiersHook hook = _v6Hook();
        address hookAddress = address(hook);
        address resolverAddress = _resolverOf(hook);
        bool verifyV4State = _shouldVerifyV4State();
        uint256 chunkFilter = _chunkFilter();
        uint256 maxChunkFilter = _maxChunkFilter();
        _requireValidChunkFilters(chunkFilter, maxChunkFilter, 1);

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 1)) {
            uint16[] memory tierIds = new uint16[](536);

            // Add 1 instances of tier ID 1
            for (uint256 i = 0; i < 1; i++) {
                tierIds[0 + i] = 1;
            }
            // Add 6 instances of tier ID 2
            for (uint256 i = 0; i < 6; i++) {
                tierIds[1 + i] = 2;
            }
            // Add 13 instances of tier ID 3
            for (uint256 i = 0; i < 13; i++) {
                tierIds[7 + i] = 3;
            }
            // Add 3 instances of tier ID 5
            for (uint256 i = 0; i < 3; i++) {
                tierIds[20 + i] = 5;
            }
            // Add 3 instances of tier ID 6
            for (uint256 i = 0; i < 3; i++) {
                tierIds[23 + i] = 6;
            }
            // Add 2 instances of tier ID 7
            for (uint256 i = 0; i < 2; i++) {
                tierIds[26 + i] = 7;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds[28 + i] = 10;
            }
            // Add 2 instances of tier ID 14
            for (uint256 i = 0; i < 2; i++) {
                tierIds[29 + i] = 14;
            }
            // Add 1 instances of tier ID 17
            for (uint256 i = 0; i < 1; i++) {
                tierIds[31 + i] = 17;
            }
            // Add 1 instances of tier ID 18
            for (uint256 i = 0; i < 1; i++) {
                tierIds[32 + i] = 18;
            }
            // Add 3 instances of tier ID 19
            for (uint256 i = 0; i < 3; i++) {
                tierIds[33 + i] = 19;
            }
            // Add 1 instances of tier ID 21
            for (uint256 i = 0; i < 1; i++) {
                tierIds[36 + i] = 21;
            }
            // Add 1 instances of tier ID 23
            for (uint256 i = 0; i < 1; i++) {
                tierIds[37 + i] = 23;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds[38 + i] = 25;
            }
            // Add 3 instances of tier ID 26
            for (uint256 i = 0; i < 3; i++) {
                tierIds[39 + i] = 26;
            }
            // Add 2 instances of tier ID 31
            for (uint256 i = 0; i < 2; i++) {
                tierIds[42 + i] = 31;
            }
            // Add 2 instances of tier ID 32
            for (uint256 i = 0; i < 2; i++) {
                tierIds[44 + i] = 32;
            }
            // Add 4 instances of tier ID 35
            for (uint256 i = 0; i < 4; i++) {
                tierIds[46 + i] = 35;
            }
            // Add 1 instances of tier ID 37
            for (uint256 i = 0; i < 1; i++) {
                tierIds[50 + i] = 37;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds[51 + i] = 39;
            }
            // Add 3 instances of tier ID 43
            for (uint256 i = 0; i < 3; i++) {
                tierIds[52 + i] = 43;
            }
            // Add 2 instances of tier ID 44
            for (uint256 i = 0; i < 2; i++) {
                tierIds[55 + i] = 44;
            }
            // Add 1 instances of tier ID 46
            for (uint256 i = 0; i < 1; i++) {
                tierIds[57 + i] = 46;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds[58 + i] = 47;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds[59 + i] = 48;
            }
            // Add 13 instances of tier ID 3
            for (uint256 i = 0; i < 13; i++) {
                tierIds[60 + i] = 3;
            }
            // Add 7 instances of tier ID 4
            for (uint256 i = 0; i < 7; i++) {
                tierIds[73 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds[80 + i] = 5;
            }
            // Add 2 instances of tier ID 6
            for (uint256 i = 0; i < 2; i++) {
                tierIds[81 + i] = 6;
            }
            // Add 1 instances of tier ID 14
            for (uint256 i = 0; i < 1; i++) {
                tierIds[83 + i] = 14;
            }
            // Add 1 instances of tier ID 15
            for (uint256 i = 0; i < 1; i++) {
                tierIds[84 + i] = 15;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds[85 + i] = 19;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds[86 + i] = 25;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds[88 + i] = 28;
            }
            // Add 1 instances of tier ID 29
            for (uint256 i = 0; i < 1; i++) {
                tierIds[89 + i] = 29;
            }
            // Add 1 instances of tier ID 37
            for (uint256 i = 0; i < 1; i++) {
                tierIds[90 + i] = 37;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds[91 + i] = 38;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds[92 + i] = 39;
            }
            // Add 1 instances of tier ID 42
            for (uint256 i = 0; i < 1; i++) {
                tierIds[93 + i] = 42;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds[94 + i] = 48;
            }
            // Add 1 instances of tier ID 49
            for (uint256 i = 0; i < 1; i++) {
                tierIds[95 + i] = 49;
            }
            // Add 20 instances of tier ID 4
            for (uint256 i = 0; i < 20; i++) {
                tierIds[96 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds[116 + i] = 5;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds[117 + i] = 6;
            }
            // Add 4 instances of tier ID 10
            for (uint256 i = 0; i < 4; i++) {
                tierIds[118 + i] = 10;
            }
            // Add 1 instances of tier ID 15
            for (uint256 i = 0; i < 1; i++) {
                tierIds[122 + i] = 15;
            }
            // Add 1 instances of tier ID 18
            for (uint256 i = 0; i < 1; i++) {
                tierIds[123 + i] = 18;
            }
            // Add 3 instances of tier ID 19
            for (uint256 i = 0; i < 3; i++) {
                tierIds[124 + i] = 19;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds[127 + i] = 20;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds[128 + i] = 25;
            }
            // Add 1 instances of tier ID 26
            for (uint256 i = 0; i < 1; i++) {
                tierIds[130 + i] = 26;
            }
            // Add 2 instances of tier ID 31
            for (uint256 i = 0; i < 2; i++) {
                tierIds[131 + i] = 31;
            }
            // Add 1 instances of tier ID 35
            for (uint256 i = 0; i < 1; i++) {
                tierIds[133 + i] = 35;
            }
            // Add 1 instances of tier ID 42
            for (uint256 i = 0; i < 1; i++) {
                tierIds[134 + i] = 42;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds[135 + i] = 43;
            }
            // Add 1 instances of tier ID 44
            for (uint256 i = 0; i < 1; i++) {
                tierIds[136 + i] = 44;
            }
            // Add 1 instances of tier ID 49
            for (uint256 i = 0; i < 1; i++) {
                tierIds[137 + i] = 49;
            }
            // Add 20 instances of tier ID 4
            for (uint256 i = 0; i < 20; i++) {
                tierIds[138 + i] = 4;
            }
            // Add 1 instances of tier ID 13
            for (uint256 i = 0; i < 1; i++) {
                tierIds[158 + i] = 13;
            }
            // Add 1 instances of tier ID 16
            for (uint256 i = 0; i < 1; i++) {
                tierIds[159 + i] = 16;
            }
            // Add 1 instances of tier ID 17
            for (uint256 i = 0; i < 1; i++) {
                tierIds[160 + i] = 17;
            }
            // Add 2 instances of tier ID 19
            for (uint256 i = 0; i < 2; i++) {
                tierIds[161 + i] = 19;
            }
            // Add 4 instances of tier ID 23
            for (uint256 i = 0; i < 4; i++) {
                tierIds[163 + i] = 23;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds[167 + i] = 25;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds[169 + i] = 31;
            }
            // Add 1 instances of tier ID 32
            for (uint256 i = 0; i < 1; i++) {
                tierIds[170 + i] = 32;
            }
            // Add 1 instances of tier ID 33
            for (uint256 i = 0; i < 1; i++) {
                tierIds[171 + i] = 33;
            }
            // Add 4 instances of tier ID 41
            for (uint256 i = 0; i < 4; i++) {
                tierIds[172 + i] = 41;
            }
            // Add 1 instances of tier ID 42
            for (uint256 i = 0; i < 1; i++) {
                tierIds[176 + i] = 42;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds[177 + i] = 43;
            }
            // Add 2 instances of tier ID 48
            for (uint256 i = 0; i < 2; i++) {
                tierIds[178 + i] = 48;
            }
            // Add 20 instances of tier ID 4
            for (uint256 i = 0; i < 20; i++) {
                tierIds[180 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds[200 + i] = 5;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds[201 + i] = 6;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds[202 + i] = 10;
            }
            // Add 1 instances of tier ID 13
            for (uint256 i = 0; i < 1; i++) {
                tierIds[203 + i] = 13;
            }
            // Add 2 instances of tier ID 15
            for (uint256 i = 0; i < 2; i++) {
                tierIds[204 + i] = 15;
            }
            // Add 1 instances of tier ID 18
            for (uint256 i = 0; i < 1; i++) {
                tierIds[206 + i] = 18;
            }
            // Add 3 instances of tier ID 19
            for (uint256 i = 0; i < 3; i++) {
                tierIds[207 + i] = 19;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds[210 + i] = 20;
            }
            // Add 1 instances of tier ID 23
            for (uint256 i = 0; i < 1; i++) {
                tierIds[211 + i] = 23;
            }
            // Add 1 instances of tier ID 26
            for (uint256 i = 0; i < 1; i++) {
                tierIds[212 + i] = 26;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds[213 + i] = 28;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds[214 + i] = 31;
            }
            // Add 1 instances of tier ID 35
            for (uint256 i = 0; i < 1; i++) {
                tierIds[215 + i] = 35;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds[216 + i] = 38;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds[217 + i] = 39;
            }
            // Add 1 instances of tier ID 40
            for (uint256 i = 0; i < 1; i++) {
                tierIds[218 + i] = 40;
            }
            // Add 2 instances of tier ID 44
            for (uint256 i = 0; i < 2; i++) {
                tierIds[219 + i] = 44;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds[221 + i] = 47;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds[222 + i] = 48;
            }
            // Add 1 instances of tier ID 49
            for (uint256 i = 0; i < 1; i++) {
                tierIds[223 + i] = 49;
            }
            // Add 18 instances of tier ID 4
            for (uint256 i = 0; i < 18; i++) {
                tierIds[224 + i] = 4;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds[242 + i] = 6;
            }
            // Add 1 instances of tier ID 15
            for (uint256 i = 0; i < 1; i++) {
                tierIds[243 + i] = 15;
            }
            // Add 3 instances of tier ID 19
            for (uint256 i = 0; i < 3; i++) {
                tierIds[244 + i] = 19;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds[247 + i] = 25;
            }
            // Add 1 instances of tier ID 29
            for (uint256 i = 0; i < 1; i++) {
                tierIds[249 + i] = 29;
            }
            // Add 2 instances of tier ID 31
            for (uint256 i = 0; i < 2; i++) {
                tierIds[250 + i] = 31;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds[252 + i] = 38;
            }
            // Add 2 instances of tier ID 43
            for (uint256 i = 0; i < 2; i++) {
                tierIds[253 + i] = 43;
            }
            // Add 2 instances of tier ID 5
            for (uint256 i = 0; i < 2; i++) {
                tierIds[255 + i] = 5;
            }
            // Add 5 instances of tier ID 6
            for (uint256 i = 0; i < 5; i++) {
                tierIds[257 + i] = 6;
            }
            // Add 7 instances of tier ID 10
            for (uint256 i = 0; i < 7; i++) {
                tierIds[262 + i] = 10;
            }
            // Add 1 instances of tier ID 11
            for (uint256 i = 0; i < 1; i++) {
                tierIds[269 + i] = 11;
            }
            // Add 2 instances of tier ID 13
            for (uint256 i = 0; i < 2; i++) {
                tierIds[270 + i] = 13;
            }
            // Add 3 instances of tier ID 14
            for (uint256 i = 0; i < 3; i++) {
                tierIds[272 + i] = 14;
            }
            // Add 3 instances of tier ID 17
            for (uint256 i = 0; i < 3; i++) {
                tierIds[275 + i] = 17;
            }
            // Add 7 instances of tier ID 19
            for (uint256 i = 0; i < 7; i++) {
                tierIds[278 + i] = 19;
            }
            // Add 6 instances of tier ID 20
            for (uint256 i = 0; i < 6; i++) {
                tierIds[285 + i] = 20;
            }
            // Add 1 instances of tier ID 21
            for (uint256 i = 0; i < 1; i++) {
                tierIds[291 + i] = 21;
            }
            // Add 2 instances of tier ID 23
            for (uint256 i = 0; i < 2; i++) {
                tierIds[292 + i] = 23;
            }
            // Add 3 instances of tier ID 25
            for (uint256 i = 0; i < 3; i++) {
                tierIds[294 + i] = 25;
            }
            // Add 2 instances of tier ID 26
            for (uint256 i = 0; i < 2; i++) {
                tierIds[297 + i] = 26;
            }
            // Add 7 instances of tier ID 28
            for (uint256 i = 0; i < 7; i++) {
                tierIds[299 + i] = 28;
            }
            // Add 1 instances of tier ID 29
            for (uint256 i = 0; i < 1; i++) {
                tierIds[306 + i] = 29;
            }
            // Add 5 instances of tier ID 31
            for (uint256 i = 0; i < 5; i++) {
                tierIds[307 + i] = 31;
            }
            // Add 2 instances of tier ID 32
            for (uint256 i = 0; i < 2; i++) {
                tierIds[312 + i] = 32;
            }
            // Add 1 instances of tier ID 33
            for (uint256 i = 0; i < 1; i++) {
                tierIds[314 + i] = 33;
            }
            // Add 3 instances of tier ID 35
            for (uint256 i = 0; i < 3; i++) {
                tierIds[315 + i] = 35;
            }
            // Add 2 instances of tier ID 37
            for (uint256 i = 0; i < 2; i++) {
                tierIds[318 + i] = 37;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds[320 + i] = 39;
            }
            // Add 2 instances of tier ID 40
            for (uint256 i = 0; i < 2; i++) {
                tierIds[321 + i] = 40;
            }
            // Add 1 instances of tier ID 41
            for (uint256 i = 0; i < 1; i++) {
                tierIds[323 + i] = 41;
            }
            // Add 16 instances of tier ID 42
            for (uint256 i = 0; i < 16; i++) {
                tierIds[324 + i] = 42;
            }
            // Add 11 instances of tier ID 43
            for (uint256 i = 0; i < 11; i++) {
                tierIds[340 + i] = 43;
            }
            // Add 29 instances of tier ID 44
            for (uint256 i = 0; i < 29; i++) {
                tierIds[351 + i] = 44;
            }
            // Add 12 instances of tier ID 47
            for (uint256 i = 0; i < 12; i++) {
                tierIds[380 + i] = 47;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds[392 + i] = 48;
            }
            // Add 3 instances of tier ID 49
            for (uint256 i = 0; i < 3; i++) {
                tierIds[393 + i] = 49;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds[396 + i] = 10;
            }
            // Add 139 instances of tier ID 49
            for (uint256 i = 0; i < 139; i++) {
                tierIds[397 + i] = 49;
            }
            address[] memory transferOwners = _getEthereumTransferOwners();
            AirdropV4BannysCombinedEthereum migration = new AirdropV4BannysCombinedEthereum();
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds, address(migration));
            migration.requireMintedTokenIds(mintedTokenIds, _expectedTokenIdsEthereum());
            migration.decorateBannys(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                _bannyV4TokenIdsEthereum(),
                _bannyTargetTokenIdsEthereum(),
                _bannyBackgroundTokenIdsEthereum(),
                _bannyOutfitOffsetsEthereum(),
                _bannyOutfitTokenIdsEthereum()
            );
            migration.transferRegular(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                transferOwners,
                _regularTargetTokenIdsEthereum(),
                _regularV4TokenIdsEthereum(),
                _regularAllowResolverOwnersEthereum()
            );
            migration.transferUnused(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                transferOwners,
                118,
                _unusedTargetTokenIdsEthereum(),
                _unusedV4TokenIdsEthereum(),
                _unusedAllowResolverOwnersEthereum()
            );
            migration.requireNoBalance(hookAddress);
            console.log("AirdropV4BannysCombinedEthereum migrated", mintedTokenIds.length, "tokens");
        }
    }

    function _runOptimism() internal {
        JB721TiersHook hook = _v6Hook();
        address hookAddress = address(hook);
        address resolverAddress = _resolverOf(hook);
        bool verifyV4State = _shouldVerifyV4State();
        uint256 chunkFilter = _chunkFilter();
        uint256 maxChunkFilter = _maxChunkFilter();
        _requireValidChunkFilters(chunkFilter, maxChunkFilter, 1);

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 1)) {
            uint16[] memory tierIds = new uint16[](11);

            // Add 2 instances of tier ID 3
            for (uint256 i = 0; i < 2; i++) {
                tierIds[0 + i] = 3;
            }
            // Add 3 instances of tier ID 4
            for (uint256 i = 0; i < 3; i++) {
                tierIds[2 + i] = 4;
            }
            // Add 1 instances of tier ID 11
            for (uint256 i = 0; i < 1; i++) {
                tierIds[5 + i] = 11;
            }
            // Add 1 instances of tier ID 17
            for (uint256 i = 0; i < 1; i++) {
                tierIds[6 + i] = 17;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds[7 + i] = 19;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds[8 + i] = 25;
            }
            // Add 1 instances of tier ID 44
            for (uint256 i = 0; i < 1; i++) {
                tierIds[9 + i] = 44;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds[10 + i] = 47;
            }
            address[] memory transferOwners = _getOptimismTransferOwners();
            AirdropV4BannysCombinedOptimism migration = new AirdropV4BannysCombinedOptimism();
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds, address(migration));
            migration.requireMintedTokenIds(mintedTokenIds, _expectedTokenIdsOptimism());
            migration.decorateBannys(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                _bannyV4TokenIdsOptimism(),
                _bannyTargetTokenIdsOptimism(),
                _bannyBackgroundTokenIdsOptimism(),
                _bannyOutfitOffsetsOptimism(),
                _bannyOutfitTokenIdsOptimism()
            );
            migration.transferRegular(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                transferOwners,
                _regularTargetTokenIdsOptimism(),
                _regularV4TokenIdsOptimism(),
                _regularAllowResolverOwnersOptimism()
            );
            migration.transferUnused(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                transferOwners,
                6,
                _unusedTargetTokenIdsOptimism(),
                _unusedV4TokenIdsOptimism(),
                _unusedAllowResolverOwnersOptimism()
            );
            migration.requireNoBalance(hookAddress);
            console.log("AirdropV4BannysCombinedOptimism migrated", mintedTokenIds.length, "tokens");
        }
    }

    function _runBase() internal {
        JB721TiersHook hook = _v6Hook();
        address hookAddress = address(hook);
        address resolverAddress = _resolverOf(hook);
        bool verifyV4State = _shouldVerifyV4State();
        uint256 chunkFilter = _chunkFilter();
        uint256 maxChunkFilter = _maxChunkFilter();
        _requireValidChunkFilters(chunkFilter, maxChunkFilter, 1);

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 1)) {
            uint16[] memory tierIds = new uint16[](228);

            // Add 3 instances of tier ID 2
            for (uint256 i = 0; i < 3; i++) {
                tierIds[0 + i] = 2;
            }
            // Add 10 instances of tier ID 3
            for (uint256 i = 0; i < 10; i++) {
                tierIds[3 + i] = 3;
            }
            // Add 9 instances of tier ID 4
            for (uint256 i = 0; i < 9; i++) {
                tierIds[13 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds[22 + i] = 5;
            }
            // Add 4 instances of tier ID 6
            for (uint256 i = 0; i < 4; i++) {
                tierIds[23 + i] = 6;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds[27 + i] = 10;
            }
            // Add 1 instances of tier ID 11
            for (uint256 i = 0; i < 1; i++) {
                tierIds[28 + i] = 11;
            }
            // Add 2 instances of tier ID 14
            for (uint256 i = 0; i < 2; i++) {
                tierIds[29 + i] = 14;
            }
            // Add 2 instances of tier ID 15
            for (uint256 i = 0; i < 2; i++) {
                tierIds[31 + i] = 15;
            }
            // Add 4 instances of tier ID 19
            for (uint256 i = 0; i < 4; i++) {
                tierIds[33 + i] = 19;
            }
            // Add 4 instances of tier ID 25
            for (uint256 i = 0; i < 4; i++) {
                tierIds[37 + i] = 25;
            }
            // Add 4 instances of tier ID 28
            for (uint256 i = 0; i < 4; i++) {
                tierIds[41 + i] = 28;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds[45 + i] = 31;
            }
            // Add 1 instances of tier ID 32
            for (uint256 i = 0; i < 1; i++) {
                tierIds[46 + i] = 32;
            }
            // Add 1 instances of tier ID 33
            for (uint256 i = 0; i < 1; i++) {
                tierIds[47 + i] = 33;
            }
            // Add 2 instances of tier ID 37
            for (uint256 i = 0; i < 2; i++) {
                tierIds[48 + i] = 37;
            }
            // Add 1 instances of tier ID 40
            for (uint256 i = 0; i < 1; i++) {
                tierIds[50 + i] = 40;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds[51 + i] = 43;
            }
            // Add 2 instances of tier ID 44
            for (uint256 i = 0; i < 2; i++) {
                tierIds[52 + i] = 44;
            }
            // Add 1 instances of tier ID 45
            for (uint256 i = 0; i < 1; i++) {
                tierIds[54 + i] = 45;
            }
            // Add 2 instances of tier ID 47
            for (uint256 i = 0; i < 2; i++) {
                tierIds[55 + i] = 47;
            }
            // Add 44 instances of tier ID 4
            for (uint256 i = 0; i < 44; i++) {
                tierIds[57 + i] = 4;
            }
            // Add 3 instances of tier ID 10
            for (uint256 i = 0; i < 3; i++) {
                tierIds[101 + i] = 10;
            }
            // Add 1 instances of tier ID 14
            for (uint256 i = 0; i < 1; i++) {
                tierIds[104 + i] = 14;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds[105 + i] = 19;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds[106 + i] = 25;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds[107 + i] = 28;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds[108 + i] = 31;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds[109 + i] = 38;
            }
            // Add 2 instances of tier ID 43
            for (uint256 i = 0; i < 2; i++) {
                tierIds[110 + i] = 43;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds[112 + i] = 47;
            }
            // Add 22 instances of tier ID 4
            for (uint256 i = 0; i < 22; i++) {
                tierIds[113 + i] = 4;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds[135 + i] = 10;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds[136 + i] = 19;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds[137 + i] = 25;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds[139 + i] = 43;
            }
            // Add 19 instances of tier ID 4
            for (uint256 i = 0; i < 19; i++) {
                tierIds[140 + i] = 4;
            }
            // Add 2 instances of tier ID 5
            for (uint256 i = 0; i < 2; i++) {
                tierIds[159 + i] = 5;
            }
            // Add 1 instances of tier ID 13
            for (uint256 i = 0; i < 1; i++) {
                tierIds[161 + i] = 13;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds[162 + i] = 19;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds[163 + i] = 20;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds[164 + i] = 25;
            }
            // Add 1 instances of tier ID 27
            for (uint256 i = 0; i < 1; i++) {
                tierIds[165 + i] = 27;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds[166 + i] = 28;
            }
            // Add 1 instances of tier ID 35
            for (uint256 i = 0; i < 1; i++) {
                tierIds[167 + i] = 35;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds[168 + i] = 38;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds[169 + i] = 39;
            }
            // Add 1 instances of tier ID 41
            for (uint256 i = 0; i < 1; i++) {
                tierIds[170 + i] = 41;
            }
            // Add 2 instances of tier ID 43
            for (uint256 i = 0; i < 2; i++) {
                tierIds[171 + i] = 43;
            }
            // Add 1 instances of tier ID 44
            for (uint256 i = 0; i < 1; i++) {
                tierIds[173 + i] = 44;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds[174 + i] = 48;
            }
            // Add 2 instances of tier ID 5
            for (uint256 i = 0; i < 2; i++) {
                tierIds[175 + i] = 5;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds[177 + i] = 6;
            }
            // Add 1 instances of tier ID 7
            for (uint256 i = 0; i < 1; i++) {
                tierIds[178 + i] = 7;
            }
            // Add 6 instances of tier ID 10
            for (uint256 i = 0; i < 6; i++) {
                tierIds[179 + i] = 10;
            }
            // Add 2 instances of tier ID 11
            for (uint256 i = 0; i < 2; i++) {
                tierIds[185 + i] = 11;
            }
            // Add 1 instances of tier ID 13
            for (uint256 i = 0; i < 1; i++) {
                tierIds[187 + i] = 13;
            }
            // Add 1 instances of tier ID 14
            for (uint256 i = 0; i < 1; i++) {
                tierIds[188 + i] = 14;
            }
            // Add 1 instances of tier ID 17
            for (uint256 i = 0; i < 1; i++) {
                tierIds[189 + i] = 17;
            }
            // Add 5 instances of tier ID 19
            for (uint256 i = 0; i < 5; i++) {
                tierIds[190 + i] = 19;
            }
            // Add 1 instances of tier ID 24
            for (uint256 i = 0; i < 1; i++) {
                tierIds[195 + i] = 24;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds[196 + i] = 25;
            }
            // Add 4 instances of tier ID 28
            for (uint256 i = 0; i < 4; i++) {
                tierIds[197 + i] = 28;
            }
            // Add 4 instances of tier ID 31
            for (uint256 i = 0; i < 4; i++) {
                tierIds[201 + i] = 31;
            }
            // Add 1 instances of tier ID 32
            for (uint256 i = 0; i < 1; i++) {
                tierIds[205 + i] = 32;
            }
            // Add 1 instances of tier ID 34
            for (uint256 i = 0; i < 1; i++) {
                tierIds[206 + i] = 34;
            }
            // Add 3 instances of tier ID 35
            for (uint256 i = 0; i < 3; i++) {
                tierIds[207 + i] = 35;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds[210 + i] = 38;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds[211 + i] = 39;
            }
            // Add 2 instances of tier ID 40
            for (uint256 i = 0; i < 2; i++) {
                tierIds[212 + i] = 40;
            }
            // Add 1 instances of tier ID 41
            for (uint256 i = 0; i < 1; i++) {
                tierIds[214 + i] = 41;
            }
            // Add 2 instances of tier ID 42
            for (uint256 i = 0; i < 2; i++) {
                tierIds[215 + i] = 42;
            }
            // Add 2 instances of tier ID 43
            for (uint256 i = 0; i < 2; i++) {
                tierIds[217 + i] = 43;
            }
            // Add 2 instances of tier ID 44
            for (uint256 i = 0; i < 2; i++) {
                tierIds[219 + i] = 44;
            }
            // Add 5 instances of tier ID 47
            for (uint256 i = 0; i < 5; i++) {
                tierIds[221 + i] = 47;
            }
            // Add 2 instances of tier ID 49
            for (uint256 i = 0; i < 2; i++) {
                tierIds[226 + i] = 49;
            }
            address[] memory transferOwners = _getBaseTransferOwners();
            AirdropV4BannysCombinedBase migration = new AirdropV4BannysCombinedBase();
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds, address(migration));
            migration.requireMintedTokenIds(mintedTokenIds, _expectedTokenIdsBase());
            migration.decorateBannys(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                _bannyV4TokenIdsBase(),
                _bannyTargetTokenIdsBase(),
                _bannyBackgroundTokenIdsBase(),
                _bannyOutfitOffsetsBase(),
                _bannyOutfitTokenIdsBase()
            );
            migration.transferRegular(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                transferOwners,
                _regularTargetTokenIdsBase(),
                _regularV4TokenIdsBase(),
                _regularAllowResolverOwnersBase()
            );
            migration.transferUnused(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                transferOwners,
                107,
                _unusedTargetTokenIdsBase(),
                _unusedV4TokenIdsBase(),
                _unusedAllowResolverOwnersBase()
            );
            migration.requireNoBalance(hookAddress);
            console.log("AirdropV4BannysCombinedBase migrated", mintedTokenIds.length, "tokens");
        }
    }

    function _runArbitrum() internal {
        JB721TiersHook hook = _v6Hook();
        address hookAddress = address(hook);
        address resolverAddress = _resolverOf(hook);
        bool verifyV4State = _shouldVerifyV4State();
        uint256 chunkFilter = _chunkFilter();
        uint256 maxChunkFilter = _maxChunkFilter();
        _requireValidChunkFilters(chunkFilter, maxChunkFilter, 1);

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 1)) {
            uint16[] memory tierIds = new uint16[](205);

            // Add 2 instances of tier ID 3
            for (uint256 i = 0; i < 2; i++) {
                tierIds[0 + i] = 3;
            }
            // Add 2 instances of tier ID 4
            for (uint256 i = 0; i < 2; i++) {
                tierIds[2 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds[4 + i] = 5;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds[5 + i] = 19;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds[6 + i] = 25;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds[7 + i] = 38;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds[8 + i] = 47;
            }
            // Add 4 instances of tier ID 4
            for (uint256 i = 0; i < 4; i++) {
                tierIds[9 + i] = 4;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds[13 + i] = 6;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds[14 + i] = 10;
            }
            // Add 1 instances of tier ID 11
            for (uint256 i = 0; i < 1; i++) {
                tierIds[15 + i] = 11;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds[16 + i] = 19;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds[17 + i] = 20;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds[18 + i] = 28;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds[19 + i] = 31;
            }
            // Add 1 instances of tier ID 49
            for (uint256 i = 0; i < 1; i++) {
                tierIds[20 + i] = 49;
            }
            // Add 3 instances of tier ID 4
            for (uint256 i = 0; i < 3; i++) {
                tierIds[21 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds[24 + i] = 5;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds[25 + i] = 10;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds[26 + i] = 20;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds[27 + i] = 28;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds[28 + i] = 43;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds[29 + i] = 5;
            }
            // Add 2 instances of tier ID 19
            for (uint256 i = 0; i < 2; i++) {
                tierIds[30 + i] = 19;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds[32 + i] = 31;
            }
            // Add 1 instances of tier ID 32
            for (uint256 i = 0; i < 1; i++) {
                tierIds[33 + i] = 32;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds[34 + i] = 39;
            }
            // Add 26 instances of tier ID 47
            for (uint256 i = 0; i < 26; i++) {
                tierIds[35 + i] = 47;
            }
            // Add 144 instances of tier ID 49
            for (uint256 i = 0; i < 144; i++) {
                tierIds[61 + i] = 49;
            }
            address[] memory transferOwners = _getArbitrumTransferOwners();
            AirdropV4BannysCombinedArbitrum migration = new AirdropV4BannysCombinedArbitrum();
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds, address(migration));
            migration.requireMintedTokenIds(mintedTokenIds, _expectedTokenIdsArbitrum());
            migration.decorateBannys(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                _bannyV4TokenIdsArbitrum(),
                _bannyTargetTokenIdsArbitrum(),
                _bannyBackgroundTokenIdsArbitrum(),
                _bannyOutfitOffsetsArbitrum(),
                _bannyOutfitTokenIdsArbitrum()
            );
            migration.transferRegular(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                transferOwners,
                _regularTargetTokenIdsArbitrum(),
                _regularV4TokenIdsArbitrum(),
                _regularAllowResolverOwnersArbitrum()
            );
            migration.transferUnused(
                hookAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State,
                transferOwners,
                11,
                _unusedTargetTokenIdsArbitrum(),
                _unusedV4TokenIdsArbitrum(),
                _unusedAllowResolverOwnersArbitrum()
            );
            migration.requireNoBalance(hookAddress);
            console.log("AirdropV4BannysCombinedArbitrum migrated", mintedTokenIds.length, "tokens");
        }
    }


    function _getEthereumTransferOwners() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](399);
        transferOwners[0] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[1] = 0xA2Fa6144168751D116336B58C5288feaF8bb12C1;
        transferOwners[2] = 0x63A2368F4B509438ca90186cb1C15156713D5834;
        transferOwners[3] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[4] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[5] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[6] = 0x5dee86b297755b3F2ce65e09BA3A700579A9020B;
        transferOwners[7] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        transferOwners[8] = 0xa13d49fCbf79EAF6A0a58cBDD3361422DB4eAfF1;
        transferOwners[9] = 0x516cAfD745Ec780D20f61c0d71fe258eA765222D;
        transferOwners[10] = 0x126eeFa566ABF5aC3EfDAeF52d79E962CFFdB448;
        transferOwners[11] = 0x289715fFBB2f4b482e2917D2f183FeAb564ec84F;
        transferOwners[12] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[13] = 0x1786D033D5CbCC235B673e872c7613c2F83DA583;
        transferOwners[14] = 0x38EED3CCeED88f380E436eb21811250797c453C5;
        transferOwners[15] = 0xE16a238d207B9ac8B419C7A866b0De013c73357B;
        transferOwners[16] = 0x0b2c9E0ee3057f4B9b0c2e42894a3D5A9B32b5Af;
        transferOwners[17] = 0x0Cb1D93daEc77Df2ED7Db31C040Fd2174452bD9F;
        transferOwners[18] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[19] = 0x6a099Bb96DDF3963d5AddCAbDC0221914cF80b1F;
        transferOwners[20] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        transferOwners[21] = 0x79d1E7F1A6E0Bbb3278a9d2B782e3A8983444cb6;
        transferOwners[22] = 0x546B4A7A30b3193Badf70E1d43D8142928F3db0b;
        transferOwners[23] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[24] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[25] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[26] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[27] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[28] = 0x7D0068d0D8fC2Aa15d897448B348Fa9B30f6d4c9;
        transferOwners[29] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[30] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        transferOwners[31] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        transferOwners[32] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[33] = 0x961d4191965C49537c88F764D88318872CE405bE;
        transferOwners[34] = 0x21a8f5A6bF893D43d3964dDaf4E04766BBBE9b07;
        transferOwners[35] = 0x7a16eABD1413Bfd468aE9fEBF7C26c62f1fFdc59;
        transferOwners[36] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[37] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[38] = 0xa13d49fCbf79EAF6A0a58cBDD3361422DB4eAfF1;
        transferOwners[39] = 0xe7879a2D05dBA966Fcca34EE9C3F99eEe7eDEFd1;
        transferOwners[40] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        transferOwners[41] = 0x5706d5aD7A68bf8692bD341234bE44ca7Bf2f654;
        transferOwners[42] = 0x679d87D8640e66778c3419D164998E720D7495f6;
        transferOwners[43] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        transferOwners[44] = 0x4A290F18c35bBFE97B2557cf765De9387726dE39;
        transferOwners[45] = 0x25171bD3cD3231c3057c96F38E32E3bA6681497a;
        transferOwners[46] = 0xa7226e53F3100C093A0a5BCb6E3D0976EB3db1D6;
        transferOwners[47] = 0x76A6D08b82034b397E7e09dAe4377C18F132BbB8;
        transferOwners[48] = 0x809C9f8dd8CA93A41c3adca4972Fa234C28F7714;
        transferOwners[49] = 0x809C9f8dd8CA93A41c3adca4972Fa234C28F7714;
        transferOwners[50] = 0x126eeFa566ABF5aC3EfDAeF52d79E962CFFdB448;
        transferOwners[51] = 0x77fb4fa1ABA92576942aD34BC47834059b84e693;
        transferOwners[52] = 0x08cEb8Bba685ee708C9c4c65576837cbE19B9dea;
        transferOwners[53] = 0x690C01b4b1389D9D9265820F77DCbD2A6Ad04e6c;
        transferOwners[54] = 0x690C01b4b1389D9D9265820F77DCbD2A6Ad04e6c;
        transferOwners[55] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[56] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[57] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[58] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[59] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[60] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[61] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[62] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[63] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[64] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[65] = 0x5A00e8683f37e8B08C744054a0EF606a18b1aEF7;
        transferOwners[66] = 0x59E98040E53d7dC1900B4daf36D9Fbbd4a8f1dA2;
        transferOwners[67] = 0x59E98040E53d7dC1900B4daf36D9Fbbd4a8f1dA2;
        transferOwners[68] = 0x59E98040E53d7dC1900B4daf36D9Fbbd4a8f1dA2;
        transferOwners[69] = 0x46f3cC6a1c00A5cD8864d2B92f128196CAE07D15;
        transferOwners[70] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[71] = 0x381CC779761212344f8400373a994d29E17522c6;
        transferOwners[72] = 0x849151d7D0bF1F34b70d5caD5149D28CC2308bf1;
        transferOwners[73] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[74] = 0x63A2368F4B509438ca90186cb1C15156713D5834;
        transferOwners[75] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[76] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[77] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[78] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[79] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[80] = 0xf32dd1Bd55bD14d929218499a2E7D106F72f79c7;
        transferOwners[81] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[82] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[83] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[84] = 0x80581C6e88Ce00095F85cdf24bB760f16d6eC0D6;
        transferOwners[85] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[86] = 0x30670D81E487c80b9EDc54370e6EaF943B6EAB39;
        transferOwners[87] = 0x60535A6605958fFf6cEC5B1e92892601EFb3473b;
        transferOwners[88] = 0x34724D71cE674FcD4d06e60Dd1BaA88c14D36b75;
        transferOwners[89] = 0xA99c384f43e72B65BB51fE33b85CE12A32C09526;
        transferOwners[90] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        transferOwners[91] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        transferOwners[92] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[93] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[94] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[95] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[96] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[97] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[98] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[99] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[100] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[101] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[102] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[103] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[104] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[105] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[106] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[107] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[108] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[109] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[110] = 0xAAeD9fFF9858d48925904E391B77892BA5Fda824;
        transferOwners[111] = 0x2feb329b9289b60064904Fa61Fc347157a5AEd6a;
        transferOwners[112] = 0xDfd60a8E1e17FBb78E8CA332906A822D862f3D57;
        transferOwners[113] = 0xBD07B7Ab42cE411A752DB600604ECA7fE5501947;
        transferOwners[114] = 0x9f729294b308f79243285348A7Be3f58ae5ED31A;
        transferOwners[115] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[116] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        transferOwners[117] = 0x5138a42C3D5065debE950deBDa10C1f38150a908;
        transferOwners[118] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[119] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[120] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[121] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[122] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[123] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[124] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[125] = 0x4A290F18c35bBFE97B2557cf765De9387726dE39;
        transferOwners[126] = 0xf0FE43a75Ff248FD2E75D33fa1ebde71c6d1abAd;
        transferOwners[127] = 0x7044d88283c8FFF0679b711C0cd81f1a6754C843;
        transferOwners[128] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[129] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[130] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[131] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[132] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[133] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[134] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[135] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        transferOwners[136] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[137] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[138] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[139] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[140] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[141] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        transferOwners[142] = 0x516cAfD745Ec780D20f61c0d71fe258eA765222D;
        transferOwners[143] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[144] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        transferOwners[145] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[146] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[147] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[148] = 0x289715fFBB2f4b482e2917D2f183FeAb564ec84F;
        transferOwners[149] = 0x79d1E7F1A6E0Bbb3278a9d2B782e3A8983444cb6;
        transferOwners[150] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[151] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[152] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[153] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[154] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[155] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[156] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[157] = 0xe7879a2D05dBA966Fcca34EE9C3F99eEe7eDEFd1;
        transferOwners[158] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[159] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[160] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[161] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        transferOwners[162] = 0x21a8f5A6bF893D43d3964dDaf4E04766BBBE9b07;
        transferOwners[163] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        transferOwners[164] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        transferOwners[165] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[166] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[167] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[168] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[169] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[170] = 0x7a16eABD1413Bfd468aE9fEBF7C26c62f1fFdc59;
        transferOwners[171] = 0xf0FE43a75Ff248FD2E75D33fa1ebde71c6d1abAd;
        transferOwners[172] = 0x08cEb8Bba685ee708C9c4c65576837cbE19B9dea;
        transferOwners[173] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[174] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[175] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[176] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[177] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[178] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[179] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[180] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[181] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[182] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[183] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[184] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[185] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        transferOwners[186] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        transferOwners[187] = 0x961d4191965C49537c88F764D88318872CE405bE;
        transferOwners[188] = 0xf0FE43a75Ff248FD2E75D33fa1ebde71c6d1abAd;
        transferOwners[189] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[190] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[191] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[192] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[193] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[194] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[195] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[196] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[197] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[198] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[199] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[200] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[201] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[202] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[203] = 0x21a8f5A6bF893D43d3964dDaf4E04766BBBE9b07;
        transferOwners[204] = 0xe7879a2D05dBA966Fcca34EE9C3F99eEe7eDEFd1;
        transferOwners[205] = 0x1786D033D5CbCC235B673e872c7613c2F83DA583;
        transferOwners[206] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[207] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[208] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[209] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[210] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[211] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[212] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[213] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[214] = 0x4A290F18c35bBFE97B2557cf765De9387726dE39;
        transferOwners[215] = 0x38EED3CCeED88f380E436eb21811250797c453C5;
        transferOwners[216] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[217] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[218] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[219] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[220] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[221] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[222] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[223] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[224] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[225] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[226] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[227] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[228] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[229] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[230] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[231] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[232] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[233] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[234] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[235] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[236] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[237] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[238] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[239] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[240] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[241] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[242] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[243] = 0x7a16eABD1413Bfd468aE9fEBF7C26c62f1fFdc59;
        transferOwners[244] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        transferOwners[245] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[246] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[247] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[248] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[249] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[250] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[251] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[252] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[253] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[254] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[255] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[256] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[257] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[258] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[259] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[260] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[261] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[262] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[263] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[264] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[265] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[266] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[267] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[268] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[269] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[270] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[271] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[272] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[273] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[274] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[275] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[276] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[277] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[278] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[279] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[280] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[281] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[282] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[283] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[284] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[285] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[286] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[287] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[288] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[289] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[290] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[291] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[292] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[293] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[294] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[295] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[296] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[297] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[298] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[299] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[300] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[301] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[302] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[303] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[304] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[305] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[306] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[307] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[308] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[309] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[310] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[311] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[312] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[313] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[314] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[315] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[316] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[317] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[318] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[319] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[320] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[321] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[322] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[323] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[324] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[325] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[326] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[327] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[328] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[329] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[330] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[331] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[332] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[333] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[334] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[335] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[336] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[337] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[338] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[339] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[340] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[341] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[342] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[343] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[344] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[345] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[346] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[347] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[348] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[349] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[350] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[351] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[352] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[353] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[354] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[355] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[356] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[357] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[358] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[359] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[360] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[361] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[362] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[363] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[364] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[365] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[366] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[367] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[368] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[369] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[370] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[371] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[372] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[373] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[374] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[375] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[376] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[377] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[378] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[379] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[380] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[381] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[382] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[383] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[384] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[385] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[386] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[387] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[388] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[389] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[390] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[391] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[392] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[393] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[394] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[395] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[396] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[397] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[398] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        return transferOwners;
    }

    function _getOptimismTransferOwners() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](6);
        transferOwners[0] = 0x25910143C255828F623786f46fe9A8941B7983bB;
        transferOwners[1] = 0x292ff025168D2B51f0Ef49f164D281c36761BA2b;
        transferOwners[2] = 0xA7a5A2745f10D5C23d75a6fd228A408cEDe1CAE5;
        transferOwners[3] = 0x57700212B1cB7b67bD7DF3801DA43CA634513fE0;
        transferOwners[4] = 0x292ff025168D2B51f0Ef49f164D281c36761BA2b;
        transferOwners[5] = 0xA2Fa6144168751D116336B58C5288feaF8bb12C1;
        return transferOwners;
    }

    function _getBaseTransferOwners() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](160);
        transferOwners[0] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[1] = 0x565B93a15d38aCD79c120b15432D21E21eD274d6;
        transferOwners[2] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[3] = 0x25171bD3cD3231c3057c96F38E32E3bA6681497a;
        transferOwners[4] = 0x4718ce007293bCe1E514887E6F55ea71d9A992d6;
        transferOwners[5] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[6] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[7] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[8] = 0xAAeD9fFF9858d48925904E391B77892BA5Fda824;
        transferOwners[9] = 0xDf087B724174A3E4eD2338C0798193932E851F1b;
        transferOwners[10] = 0x28C173B8F20488eEF1b0f48Df8453A2f59C38337;
        transferOwners[11] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[12] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[13] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        transferOwners[14] = 0xAAeD9fFF9858d48925904E391B77892BA5Fda824;
        transferOwners[15] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[16] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[17] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[18] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[19] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[20] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[21] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[22] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[23] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[24] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[25] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[26] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[27] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[28] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[29] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[30] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[31] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[32] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[33] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[34] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[35] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[36] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[37] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[38] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[39] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[40] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[41] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[42] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[43] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[44] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[45] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[46] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[47] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[48] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[49] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[50] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[51] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[52] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[53] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[54] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[55] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[56] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[57] = 0x67BcBE602e870e2286C19E4E0044E583967c9665;
        transferOwners[58] = 0x18deEE9699526f8C8a87004b2e4e55029Fb26b9a;
        transferOwners[59] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        transferOwners[60] = 0xAcD59e854adf632d2322404198624F757C868C97;
        transferOwners[61] = 0xAcD59e854adf632d2322404198624F757C868C97;
        transferOwners[62] = 0xa13d49fCbf79EAF6A0a58cBDD3361422DB4eAfF1;
        transferOwners[63] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[64] = 0xbeC26FFa12c90217943D1b2958f60A821aE6E549;
        transferOwners[65] = 0x8Ec174c5d86469D1A74094E10485357eBFe2e08e;
        transferOwners[66] = 0xC5704f77f94087CC644d361A5A57295851d242aB;
        transferOwners[67] = 0x99Fa48ccEa8a38CDE6B437450fF9bBdDAFAA4Fc8;
        transferOwners[68] = 0xb6ECb51e3638Eb7aa0C6289ef058DCa27494Acb2;
        transferOwners[69] = 0x57700212B1cB7b67bD7DF3801DA43CA634513fE0;
        transferOwners[70] = 0x57700212B1cB7b67bD7DF3801DA43CA634513fE0;
        transferOwners[71] = 0x9342E2aC6dd4A907948E91E80D2734ecAC1D70eC;
        transferOwners[72] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[73] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[74] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[75] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[76] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[77] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[78] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[79] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[80] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[81] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[82] = 0x46f3cC6a1c00A5cD8864d2B92f128196CAE07D15;
        transferOwners[83] = 0x8e2B25dF2484000B9127b2D2F8E92079dcEE3E48;
        transferOwners[84] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        transferOwners[85] = 0x224aBa5D489675a7bD3CE07786FAda466b46FA0F;
        transferOwners[86] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[87] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[88] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[89] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[90] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[91] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[92] = 0x3c2736f995535b5a755F3CE2BEb754362820671e;
        transferOwners[93] = 0x6877be9E00d0bc5886c28419901E8cC98C1c2739;
        transferOwners[94] = 0x8DFBdEEC8c5d4970BB5F481C6ec7f73fa1C65be5;
        transferOwners[95] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[96] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[97] = 0x39a7B6fa1597BB6657Fe84e64E3B836c37d6F75d;
        transferOwners[98] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[99] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[100] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[101] = 0xDdB4938755C243a4f60a2f2f8f95dF4F894c58Cc;
        transferOwners[102] = 0x34aA3F359A9D614239015126635CE7732c18fDF3;
        transferOwners[103] = 0x34aA3F359A9D614239015126635CE7732c18fDF3;
        transferOwners[104] = 0x34aA3F359A9D614239015126635CE7732c18fDF3;
        transferOwners[105] = 0xF6cC71878e23c05406B35946CD9d378E0f2f4f2F;
        transferOwners[106] = 0xd2e44E40B5FB960A8A74dD7B9D6b7f14B805b50d;
        transferOwners[107] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[108] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[109] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[110] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[111] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        transferOwners[112] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[113] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[114] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[115] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[116] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[117] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[118] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[119] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[120] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[121] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[122] = 0x18deEE9699526f8C8a87004b2e4e55029Fb26b9a;
        transferOwners[123] = 0xbeC26FFa12c90217943D1b2958f60A821aE6E549;
        transferOwners[124] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[125] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[126] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[127] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[128] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        transferOwners[129] = 0x18deEE9699526f8C8a87004b2e4e55029Fb26b9a;
        transferOwners[130] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[131] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[132] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[133] = 0x99Fa48ccEa8a38CDE6B437450fF9bBdDAFAA4Fc8;
        transferOwners[134] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[135] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[136] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[137] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[138] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[139] = 0x565B93a15d38aCD79c120b15432D21E21eD274d6;
        transferOwners[140] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[141] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[142] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[143] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[144] = 0x8DFBdEEC8c5d4970BB5F481C6ec7f73fa1C65be5;
        transferOwners[145] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[146] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[147] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[148] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[149] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[150] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[151] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[152] = 0xbeC26FFa12c90217943D1b2958f60A821aE6E549;
        transferOwners[153] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        transferOwners[154] = 0x99Fa48ccEa8a38CDE6B437450fF9bBdDAFAA4Fc8;
        transferOwners[155] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[156] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[157] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[158] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[159] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        return transferOwners;
    }

    function _getArbitrumTransferOwners() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](187);
        transferOwners[0] = 0x2aa64E6d80390F5C017F0313cB908051BE2FD35e;
        transferOwners[1] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[2] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[3] = 0xfD282d9f4d06C4BDc6a41af1Ae920A0AD70D18a3;
        transferOwners[4] = 0x08B3e694caA2F1fcF8eF71095CED1326f3454B89;
        transferOwners[5] = 0x9fDf876a50EA8f95017dCFC7709356887025B5BB;
        transferOwners[6] = 0x187089B33E5812310Ed32A57F53B3fAD0383a19D;
        transferOwners[7] = 0xc6404f24DB2f573F07F3A60758765caad198c0c3;
        transferOwners[8] = 0xB2d3900807094D4Fe47405871B0C8AdB58E10D42;
        transferOwners[9] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[10] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[11] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[12] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[13] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[14] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[15] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[16] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[17] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[18] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[19] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[20] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[21] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[22] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[23] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[24] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[25] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[26] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[27] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[28] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[29] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[30] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[31] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[32] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[33] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[34] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[35] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[36] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[37] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[38] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[39] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[40] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[41] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[42] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[43] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[44] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[45] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[46] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[47] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[48] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[49] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[50] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[51] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[52] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[53] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[54] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[55] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[56] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[57] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[58] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[59] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[60] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[61] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[62] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[63] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[64] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[65] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[66] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[67] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[68] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[69] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[70] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[71] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[72] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[73] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[74] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[75] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[76] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[77] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[78] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[79] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[80] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[81] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[82] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[83] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[84] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[85] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[86] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[87] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[88] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[89] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[90] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[91] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[92] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[93] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[94] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[95] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[96] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[97] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[98] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[99] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[100] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[101] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[102] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[103] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[104] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[105] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[106] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[107] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[108] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[109] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[110] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[111] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[112] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[113] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[114] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[115] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[116] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[117] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[118] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[119] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[120] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[121] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[122] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[123] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[124] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[125] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[126] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[127] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[128] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[129] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[130] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[131] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[132] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[133] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[134] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[135] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[136] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[137] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[138] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[139] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[140] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[141] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[142] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[143] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[144] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[145] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[146] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[147] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[148] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[149] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[150] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[151] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[152] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[153] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[154] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[155] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[156] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[157] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[158] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[159] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[160] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[161] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[162] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[163] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[164] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[165] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[166] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[167] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[168] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[169] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[170] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[171] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[172] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[173] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[174] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[175] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[176] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[177] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[178] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[179] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[180] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[181] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[182] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[183] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[184] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[185] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[186] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        return transferOwners;
    }


    function _expectedTokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](536);
        values[0] = 1000000001;
        values[1] = 2000000001;
        values[2] = 2000000002;
        values[3] = 2000000003;
        values[4] = 2000000004;
        values[5] = 2000000005;
        values[6] = 2000000006;
        values[7] = 3000000001;
        values[8] = 3000000002;
        values[9] = 3000000003;
        values[10] = 3000000004;
        values[11] = 3000000005;
        values[12] = 3000000006;
        values[13] = 3000000007;
        values[14] = 3000000008;
        values[15] = 3000000009;
        values[16] = 3000000010;
        values[17] = 3000000011;
        values[18] = 3000000012;
        values[19] = 3000000013;
        values[20] = 5000000001;
        values[21] = 5000000002;
        values[22] = 5000000003;
        values[23] = 6000000001;
        values[24] = 6000000002;
        values[25] = 6000000003;
        values[26] = 7000000001;
        values[27] = 7000000002;
        values[28] = 10000000001;
        values[29] = 14000000001;
        values[30] = 14000000002;
        values[31] = 17000000001;
        values[32] = 18000000001;
        values[33] = 19000000001;
        values[34] = 19000000002;
        values[35] = 19000000003;
        values[36] = 21000000001;
        values[37] = 23000000001;
        values[38] = 25000000001;
        values[39] = 26000000001;
        values[40] = 26000000002;
        values[41] = 26000000003;
        values[42] = 31000000001;
        values[43] = 31000000002;
        values[44] = 32000000001;
        values[45] = 32000000002;
        values[46] = 35000000001;
        values[47] = 35000000002;
        values[48] = 35000000003;
        values[49] = 35000000004;
        values[50] = 37000000001;
        values[51] = 39000000001;
        values[52] = 43000000001;
        values[53] = 43000000002;
        values[54] = 43000000003;
        values[55] = 44000000001;
        values[56] = 44000000002;
        values[57] = 46000000001;
        values[58] = 47000000001;
        values[59] = 48000000001;
        values[60] = 3000000014;
        values[61] = 3000000015;
        values[62] = 3000000016;
        values[63] = 3000000017;
        values[64] = 3000000018;
        values[65] = 3000000019;
        values[66] = 3000000020;
        values[67] = 3000000021;
        values[68] = 3000000022;
        values[69] = 3000000023;
        values[70] = 3000000024;
        values[71] = 3000000025;
        values[72] = 3000000026;
        values[73] = 4000000001;
        values[74] = 4000000002;
        values[75] = 4000000003;
        values[76] = 4000000004;
        values[77] = 4000000005;
        values[78] = 4000000006;
        values[79] = 4000000007;
        values[80] = 5000000004;
        values[81] = 6000000004;
        values[82] = 6000000005;
        values[83] = 14000000003;
        values[84] = 15000000001;
        values[85] = 19000000004;
        values[86] = 25000000002;
        values[87] = 25000000003;
        values[88] = 28000000001;
        values[89] = 29000000001;
        values[90] = 37000000002;
        values[91] = 38000000001;
        values[92] = 39000000002;
        values[93] = 42000000001;
        values[94] = 48000000002;
        values[95] = 49000000001;
        values[96] = 4000000008;
        values[97] = 4000000009;
        values[98] = 4000000010;
        values[99] = 4000000011;
        values[100] = 4000000012;
        values[101] = 4000000013;
        values[102] = 4000000014;
        values[103] = 4000000015;
        values[104] = 4000000016;
        values[105] = 4000000017;
        values[106] = 4000000018;
        values[107] = 4000000019;
        values[108] = 4000000020;
        values[109] = 4000000021;
        values[110] = 4000000022;
        values[111] = 4000000023;
        values[112] = 4000000024;
        values[113] = 4000000025;
        values[114] = 4000000026;
        values[115] = 4000000027;
        values[116] = 5000000005;
        values[117] = 6000000006;
        values[118] = 10000000002;
        values[119] = 10000000003;
        values[120] = 10000000004;
        values[121] = 10000000005;
        values[122] = 15000000002;
        values[123] = 18000000002;
        values[124] = 19000000005;
        values[125] = 19000000006;
        values[126] = 19000000007;
        values[127] = 20000000001;
        values[128] = 25000000004;
        values[129] = 25000000005;
        values[130] = 26000000004;
        values[131] = 31000000003;
        values[132] = 31000000004;
        values[133] = 35000000005;
        values[134] = 42000000002;
        values[135] = 43000000004;
        values[136] = 44000000003;
        values[137] = 49000000002;
        values[138] = 4000000028;
        values[139] = 4000000029;
        values[140] = 4000000030;
        values[141] = 4000000031;
        values[142] = 4000000032;
        values[143] = 4000000033;
        values[144] = 4000000034;
        values[145] = 4000000035;
        values[146] = 4000000036;
        values[147] = 4000000037;
        values[148] = 4000000038;
        values[149] = 4000000039;
        values[150] = 4000000040;
        values[151] = 4000000041;
        values[152] = 4000000042;
        values[153] = 4000000043;
        values[154] = 4000000044;
        values[155] = 4000000045;
        values[156] = 4000000046;
        values[157] = 4000000047;
        values[158] = 13000000001;
        values[159] = 16000000001;
        values[160] = 17000000002;
        values[161] = 19000000008;
        values[162] = 19000000009;
        values[163] = 23000000002;
        values[164] = 23000000003;
        values[165] = 23000000004;
        values[166] = 23000000005;
        values[167] = 25000000006;
        values[168] = 25000000007;
        values[169] = 31000000005;
        values[170] = 32000000003;
        values[171] = 33000000001;
        values[172] = 41000000001;
        values[173] = 41000000002;
        values[174] = 41000000003;
        values[175] = 41000000004;
        values[176] = 42000000003;
        values[177] = 43000000005;
        values[178] = 48000000003;
        values[179] = 48000000004;
        values[180] = 4000000048;
        values[181] = 4000000049;
        values[182] = 4000000050;
        values[183] = 4000000051;
        values[184] = 4000000052;
        values[185] = 4000000053;
        values[186] = 4000000054;
        values[187] = 4000000055;
        values[188] = 4000000056;
        values[189] = 4000000057;
        values[190] = 4000000058;
        values[191] = 4000000059;
        values[192] = 4000000060;
        values[193] = 4000000061;
        values[194] = 4000000062;
        values[195] = 4000000063;
        values[196] = 4000000064;
        values[197] = 4000000065;
        values[198] = 4000000066;
        values[199] = 4000000067;
        values[200] = 5000000006;
        values[201] = 6000000007;
        values[202] = 10000000006;
        values[203] = 13000000002;
        values[204] = 15000000003;
        values[205] = 15000000004;
        values[206] = 18000000003;
        values[207] = 19000000010;
        values[208] = 19000000011;
        values[209] = 19000000012;
        values[210] = 20000000002;
        values[211] = 23000000006;
        values[212] = 26000000005;
        values[213] = 28000000002;
        values[214] = 31000000006;
        values[215] = 35000000006;
        values[216] = 38000000002;
        values[217] = 39000000003;
        values[218] = 40000000001;
        values[219] = 44000000004;
        values[220] = 44000000005;
        values[221] = 47000000002;
        values[222] = 48000000005;
        values[223] = 49000000003;
        values[224] = 4000000068;
        values[225] = 4000000069;
        values[226] = 4000000070;
        values[227] = 4000000071;
        values[228] = 4000000072;
        values[229] = 4000000073;
        values[230] = 4000000074;
        values[231] = 4000000075;
        values[232] = 4000000076;
        values[233] = 4000000077;
        values[234] = 4000000078;
        values[235] = 4000000079;
        values[236] = 4000000080;
        values[237] = 4000000081;
        values[238] = 4000000082;
        values[239] = 4000000083;
        values[240] = 4000000084;
        values[241] = 4000000085;
        values[242] = 6000000008;
        values[243] = 15000000005;
        values[244] = 19000000013;
        values[245] = 19000000014;
        values[246] = 19000000015;
        values[247] = 25000000008;
        values[248] = 25000000009;
        values[249] = 29000000002;
        values[250] = 31000000007;
        values[251] = 31000000008;
        values[252] = 38000000003;
        values[253] = 43000000006;
        values[254] = 43000000007;
        values[255] = 5000000007;
        values[256] = 5000000008;
        values[257] = 6000000009;
        values[258] = 6000000010;
        values[259] = 6000000011;
        values[260] = 6000000012;
        values[261] = 6000000013;
        values[262] = 10000000007;
        values[263] = 10000000008;
        values[264] = 10000000009;
        values[265] = 10000000010;
        values[266] = 10000000011;
        values[267] = 10000000012;
        values[268] = 10000000013;
        values[269] = 11000000001;
        values[270] = 13000000003;
        values[271] = 13000000004;
        values[272] = 14000000004;
        values[273] = 14000000005;
        values[274] = 14000000006;
        values[275] = 17000000003;
        values[276] = 17000000004;
        values[277] = 17000000005;
        values[278] = 19000000016;
        values[279] = 19000000017;
        values[280] = 19000000018;
        values[281] = 19000000019;
        values[282] = 19000000020;
        values[283] = 19000000021;
        values[284] = 19000000022;
        values[285] = 20000000003;
        values[286] = 20000000004;
        values[287] = 20000000005;
        values[288] = 20000000006;
        values[289] = 20000000007;
        values[290] = 20000000008;
        values[291] = 21000000002;
        values[292] = 23000000007;
        values[293] = 23000000008;
        values[294] = 25000000010;
        values[295] = 25000000011;
        values[296] = 25000000012;
        values[297] = 26000000006;
        values[298] = 26000000007;
        values[299] = 28000000003;
        values[300] = 28000000004;
        values[301] = 28000000005;
        values[302] = 28000000006;
        values[303] = 28000000007;
        values[304] = 28000000008;
        values[305] = 28000000009;
        values[306] = 29000000003;
        values[307] = 31000000009;
        values[308] = 31000000010;
        values[309] = 31000000011;
        values[310] = 31000000012;
        values[311] = 31000000013;
        values[312] = 32000000004;
        values[313] = 32000000005;
        values[314] = 33000000002;
        values[315] = 35000000007;
        values[316] = 35000000008;
        values[317] = 35000000009;
        values[318] = 37000000003;
        values[319] = 37000000004;
        values[320] = 39000000004;
        values[321] = 40000000002;
        values[322] = 40000000003;
        values[323] = 41000000005;
        values[324] = 42000000004;
        values[325] = 42000000005;
        values[326] = 42000000006;
        values[327] = 42000000007;
        values[328] = 42000000008;
        values[329] = 42000000009;
        values[330] = 42000000010;
        values[331] = 42000000011;
        values[332] = 42000000012;
        values[333] = 42000000013;
        values[334] = 42000000014;
        values[335] = 42000000015;
        values[336] = 42000000016;
        values[337] = 42000000017;
        values[338] = 42000000018;
        values[339] = 42000000019;
        values[340] = 43000000008;
        values[341] = 43000000009;
        values[342] = 43000000010;
        values[343] = 43000000011;
        values[344] = 43000000012;
        values[345] = 43000000013;
        values[346] = 43000000014;
        values[347] = 43000000015;
        values[348] = 43000000016;
        values[349] = 43000000017;
        values[350] = 43000000018;
        values[351] = 44000000006;
        values[352] = 44000000007;
        values[353] = 44000000008;
        values[354] = 44000000009;
        values[355] = 44000000010;
        values[356] = 44000000011;
        values[357] = 44000000012;
        values[358] = 44000000013;
        values[359] = 44000000014;
        values[360] = 44000000015;
        values[361] = 44000000016;
        values[362] = 44000000017;
        values[363] = 44000000018;
        values[364] = 44000000019;
        values[365] = 44000000020;
        values[366] = 44000000021;
        values[367] = 44000000022;
        values[368] = 44000000023;
        values[369] = 44000000024;
        values[370] = 44000000025;
        values[371] = 44000000026;
        values[372] = 44000000027;
        values[373] = 44000000028;
        values[374] = 44000000029;
        values[375] = 44000000030;
        values[376] = 44000000031;
        values[377] = 44000000032;
        values[378] = 44000000033;
        values[379] = 44000000034;
        values[380] = 47000000003;
        values[381] = 47000000004;
        values[382] = 47000000005;
        values[383] = 47000000006;
        values[384] = 47000000007;
        values[385] = 47000000008;
        values[386] = 47000000009;
        values[387] = 47000000010;
        values[388] = 47000000011;
        values[389] = 47000000012;
        values[390] = 47000000013;
        values[391] = 47000000014;
        values[392] = 48000000006;
        values[393] = 49000000004;
        values[394] = 49000000005;
        values[395] = 49000000006;
        values[396] = 10000000014;
        values[397] = 49000000007;
        values[398] = 49000000008;
        values[399] = 49000000009;
        values[400] = 49000000010;
        values[401] = 49000000011;
        values[402] = 49000000012;
        values[403] = 49000000013;
        values[404] = 49000000014;
        values[405] = 49000000015;
        values[406] = 49000000016;
        values[407] = 49000000017;
        values[408] = 49000000018;
        values[409] = 49000000019;
        values[410] = 49000000020;
        values[411] = 49000000021;
        values[412] = 49000000022;
        values[413] = 49000000023;
        values[414] = 49000000024;
        values[415] = 49000000025;
        values[416] = 49000000026;
        values[417] = 49000000027;
        values[418] = 49000000028;
        values[419] = 49000000029;
        values[420] = 49000000030;
        values[421] = 49000000031;
        values[422] = 49000000032;
        values[423] = 49000000033;
        values[424] = 49000000034;
        values[425] = 49000000035;
        values[426] = 49000000036;
        values[427] = 49000000037;
        values[428] = 49000000038;
        values[429] = 49000000039;
        values[430] = 49000000040;
        values[431] = 49000000041;
        values[432] = 49000000042;
        values[433] = 49000000043;
        values[434] = 49000000044;
        values[435] = 49000000045;
        values[436] = 49000000046;
        values[437] = 49000000047;
        values[438] = 49000000048;
        values[439] = 49000000049;
        values[440] = 49000000050;
        values[441] = 49000000051;
        values[442] = 49000000052;
        values[443] = 49000000053;
        values[444] = 49000000054;
        values[445] = 49000000055;
        values[446] = 49000000056;
        values[447] = 49000000057;
        values[448] = 49000000058;
        values[449] = 49000000059;
        values[450] = 49000000060;
        values[451] = 49000000061;
        values[452] = 49000000062;
        values[453] = 49000000063;
        values[454] = 49000000064;
        values[455] = 49000000065;
        values[456] = 49000000066;
        values[457] = 49000000067;
        values[458] = 49000000068;
        values[459] = 49000000069;
        values[460] = 49000000070;
        values[461] = 49000000071;
        values[462] = 49000000072;
        values[463] = 49000000073;
        values[464] = 49000000074;
        values[465] = 49000000075;
        values[466] = 49000000076;
        values[467] = 49000000077;
        values[468] = 49000000078;
        values[469] = 49000000079;
        values[470] = 49000000080;
        values[471] = 49000000081;
        values[472] = 49000000082;
        values[473] = 49000000083;
        values[474] = 49000000084;
        values[475] = 49000000085;
        values[476] = 49000000086;
        values[477] = 49000000087;
        values[478] = 49000000088;
        values[479] = 49000000089;
        values[480] = 49000000090;
        values[481] = 49000000091;
        values[482] = 49000000092;
        values[483] = 49000000093;
        values[484] = 49000000094;
        values[485] = 49000000095;
        values[486] = 49000000096;
        values[487] = 49000000097;
        values[488] = 49000000098;
        values[489] = 49000000099;
        values[490] = 49000000100;
        values[491] = 49000000101;
        values[492] = 49000000102;
        values[493] = 49000000103;
        values[494] = 49000000104;
        values[495] = 49000000105;
        values[496] = 49000000106;
        values[497] = 49000000107;
        values[498] = 49000000108;
        values[499] = 49000000109;
        values[500] = 49000000110;
        values[501] = 49000000111;
        values[502] = 49000000112;
        values[503] = 49000000113;
        values[504] = 49000000114;
        values[505] = 49000000115;
        values[506] = 49000000116;
        values[507] = 49000000117;
        values[508] = 49000000118;
        values[509] = 49000000119;
        values[510] = 49000000120;
        values[511] = 49000000121;
        values[512] = 49000000122;
        values[513] = 49000000123;
        values[514] = 49000000124;
        values[515] = 49000000125;
        values[516] = 49000000126;
        values[517] = 49000000127;
        values[518] = 49000000128;
        values[519] = 49000000129;
        values[520] = 49000000130;
        values[521] = 49000000131;
        values[522] = 49000000132;
        values[523] = 49000000133;
        values[524] = 49000000134;
        values[525] = 49000000135;
        values[526] = 49000000136;
        values[527] = 49000000137;
        values[528] = 49000000138;
        values[529] = 49000000139;
        values[530] = 49000000140;
        values[531] = 49000000141;
        values[532] = 49000000142;
        values[533] = 49000000143;
        values[534] = 49000000144;
        values[535] = 49000000145;
        return values;
    }

    function _bannyV4TokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](118);
        values[0] = 1000000001;
        values[1] = 2000000001;
        values[2] = 2000000002;
        values[3] = 2000000003;
        values[4] = 2000000004;
        values[5] = 2000000005;
        values[6] = 2000000006;
        values[7] = 3000000001;
        values[8] = 3000000002;
        values[9] = 3000000003;
        values[10] = 3000000004;
        values[11] = 3000000005;
        values[12] = 3000000006;
        values[13] = 3000000007;
        values[14] = 3000000008;
        values[15] = 3000000009;
        values[16] = 3000000010;
        values[17] = 3000000011;
        values[18] = 3000000012;
        values[19] = 3000000013;
        values[20] = 3000000014;
        values[21] = 3000000015;
        values[22] = 3000000016;
        values[23] = 3000000017;
        values[24] = 3000000018;
        values[25] = 3000000019;
        values[26] = 3000000020;
        values[27] = 3000000021;
        values[28] = 3000000022;
        values[29] = 3000000023;
        values[30] = 3000000024;
        values[31] = 3000000025;
        values[32] = 3000000026;
        values[33] = 4000000001;
        values[34] = 4000000002;
        values[35] = 4000000003;
        values[36] = 4000000004;
        values[37] = 4000000005;
        values[38] = 4000000006;
        values[39] = 4000000007;
        values[40] = 4000000008;
        values[41] = 4000000009;
        values[42] = 4000000010;
        values[43] = 4000000011;
        values[44] = 4000000012;
        values[45] = 4000000013;
        values[46] = 4000000014;
        values[47] = 4000000015;
        values[48] = 4000000016;
        values[49] = 4000000017;
        values[50] = 4000000018;
        values[51] = 4000000019;
        values[52] = 4000000020;
        values[53] = 4000000021;
        values[54] = 4000000022;
        values[55] = 4000000023;
        values[56] = 4000000024;
        values[57] = 4000000025;
        values[58] = 4000000026;
        values[59] = 4000000027;
        values[60] = 4000000028;
        values[61] = 4000000029;
        values[62] = 4000000030;
        values[63] = 4000000031;
        values[64] = 4000000032;
        values[65] = 4000000033;
        values[66] = 4000000034;
        values[67] = 4000000035;
        values[68] = 4000000036;
        values[69] = 4000000037;
        values[70] = 4000000038;
        values[71] = 4000000039;
        values[72] = 4000000040;
        values[73] = 4000000041;
        values[74] = 4000000042;
        values[75] = 4000000043;
        values[76] = 4000000044;
        values[77] = 4000000045;
        values[78] = 4000000046;
        values[79] = 4000000047;
        values[80] = 4000000048;
        values[81] = 4000000049;
        values[82] = 4000000050;
        values[83] = 4000000051;
        values[84] = 4000000052;
        values[85] = 4000000053;
        values[86] = 4000000054;
        values[87] = 4000000055;
        values[88] = 4000000056;
        values[89] = 4000000057;
        values[90] = 4000000058;
        values[91] = 4000000059;
        values[92] = 4000000060;
        values[93] = 4000000061;
        values[94] = 4000000062;
        values[95] = 4000000063;
        values[96] = 4000000064;
        values[97] = 4000000065;
        values[98] = 4000000066;
        values[99] = 4000000067;
        values[100] = 4000000068;
        values[101] = 4000000069;
        values[102] = 4000000070;
        values[103] = 4000000071;
        values[104] = 4000000072;
        values[105] = 4000000073;
        values[106] = 4000000074;
        values[107] = 4000000075;
        values[108] = 4000000076;
        values[109] = 4000000077;
        values[110] = 4000000078;
        values[111] = 4000000079;
        values[112] = 4000000080;
        values[113] = 4000000081;
        values[114] = 4000000082;
        values[115] = 4000000083;
        values[116] = 4000000084;
        values[117] = 4000000085;
        return values;
    }

    function _bannyTargetTokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](118);
        values[0] = 1000000001;
        values[1] = 2000000001;
        values[2] = 2000000002;
        values[3] = 2000000003;
        values[4] = 2000000004;
        values[5] = 2000000005;
        values[6] = 2000000006;
        values[7] = 3000000001;
        values[8] = 3000000002;
        values[9] = 3000000003;
        values[10] = 3000000004;
        values[11] = 3000000005;
        values[12] = 3000000006;
        values[13] = 3000000007;
        values[14] = 3000000008;
        values[15] = 3000000009;
        values[16] = 3000000010;
        values[17] = 3000000011;
        values[18] = 3000000012;
        values[19] = 3000000013;
        values[20] = 3000000014;
        values[21] = 3000000015;
        values[22] = 3000000016;
        values[23] = 3000000017;
        values[24] = 3000000018;
        values[25] = 3000000019;
        values[26] = 3000000020;
        values[27] = 3000000021;
        values[28] = 3000000022;
        values[29] = 3000000023;
        values[30] = 3000000024;
        values[31] = 3000000025;
        values[32] = 3000000026;
        values[33] = 4000000001;
        values[34] = 4000000002;
        values[35] = 4000000003;
        values[36] = 4000000004;
        values[37] = 4000000005;
        values[38] = 4000000006;
        values[39] = 4000000007;
        values[40] = 4000000008;
        values[41] = 4000000009;
        values[42] = 4000000010;
        values[43] = 4000000011;
        values[44] = 4000000012;
        values[45] = 4000000013;
        values[46] = 4000000014;
        values[47] = 4000000015;
        values[48] = 4000000016;
        values[49] = 4000000017;
        values[50] = 4000000018;
        values[51] = 4000000019;
        values[52] = 4000000020;
        values[53] = 4000000021;
        values[54] = 4000000022;
        values[55] = 4000000023;
        values[56] = 4000000024;
        values[57] = 4000000025;
        values[58] = 4000000026;
        values[59] = 4000000027;
        values[60] = 4000000028;
        values[61] = 4000000029;
        values[62] = 4000000030;
        values[63] = 4000000031;
        values[64] = 4000000032;
        values[65] = 4000000033;
        values[66] = 4000000034;
        values[67] = 4000000035;
        values[68] = 4000000036;
        values[69] = 4000000037;
        values[70] = 4000000038;
        values[71] = 4000000039;
        values[72] = 4000000040;
        values[73] = 4000000041;
        values[74] = 4000000042;
        values[75] = 4000000043;
        values[76] = 4000000044;
        values[77] = 4000000045;
        values[78] = 4000000046;
        values[79] = 4000000047;
        values[80] = 4000000048;
        values[81] = 4000000049;
        values[82] = 4000000050;
        values[83] = 4000000051;
        values[84] = 4000000052;
        values[85] = 4000000053;
        values[86] = 4000000054;
        values[87] = 4000000055;
        values[88] = 4000000056;
        values[89] = 4000000057;
        values[90] = 4000000058;
        values[91] = 4000000059;
        values[92] = 4000000060;
        values[93] = 4000000061;
        values[94] = 4000000062;
        values[95] = 4000000063;
        values[96] = 4000000064;
        values[97] = 4000000065;
        values[98] = 4000000066;
        values[99] = 4000000067;
        values[100] = 4000000068;
        values[101] = 4000000069;
        values[102] = 4000000070;
        values[103] = 4000000071;
        values[104] = 4000000072;
        values[105] = 4000000073;
        values[106] = 4000000074;
        values[107] = 4000000075;
        values[108] = 4000000076;
        values[109] = 4000000077;
        values[110] = 4000000078;
        values[111] = 4000000079;
        values[112] = 4000000080;
        values[113] = 4000000081;
        values[114] = 4000000082;
        values[115] = 4000000083;
        values[116] = 4000000084;
        values[117] = 4000000085;
        return values;
    }

    function _bannyBackgroundTokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](118);
        values[0] = 5000000001;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;
        values[5] = 5000000002;
        values[6] = 5000000003;
        values[7] = 6000000001;
        values[8] = 0;
        values[9] = 0;
        values[10] = 0;
        values[11] = 0;
        values[12] = 0;
        values[13] = 6000000002;
        values[14] = 0;
        values[15] = 0;
        values[16] = 6000000003;
        values[17] = 0;
        values[18] = 0;
        values[19] = 0;
        values[20] = 0;
        values[21] = 0;
        values[22] = 0;
        values[23] = 5000000004;
        values[24] = 0;
        values[25] = 0;
        values[26] = 0;
        values[27] = 0;
        values[28] = 6000000004;
        values[29] = 0;
        values[30] = 0;
        values[31] = 0;
        values[32] = 6000000005;
        values[33] = 0;
        values[34] = 0;
        values[35] = 0;
        values[36] = 0;
        values[37] = 0;
        values[38] = 0;
        values[39] = 0;
        values[40] = 0;
        values[41] = 0;
        values[42] = 5000000005;
        values[43] = 0;
        values[44] = 0;
        values[45] = 0;
        values[46] = 0;
        values[47] = 0;
        values[48] = 6000000006;
        values[49] = 0;
        values[50] = 0;
        values[51] = 0;
        values[52] = 0;
        values[53] = 0;
        values[54] = 0;
        values[55] = 0;
        values[56] = 0;
        values[57] = 0;
        values[58] = 0;
        values[59] = 0;
        values[60] = 0;
        values[61] = 0;
        values[62] = 0;
        values[63] = 0;
        values[64] = 0;
        values[65] = 0;
        values[66] = 0;
        values[67] = 0;
        values[68] = 0;
        values[69] = 0;
        values[70] = 0;
        values[71] = 0;
        values[72] = 0;
        values[73] = 0;
        values[74] = 0;
        values[75] = 0;
        values[76] = 0;
        values[77] = 0;
        values[78] = 0;
        values[79] = 0;
        values[80] = 0;
        values[81] = 0;
        values[82] = 0;
        values[83] = 0;
        values[84] = 5000000006;
        values[85] = 0;
        values[86] = 6000000007;
        values[87] = 0;
        values[88] = 0;
        values[89] = 0;
        values[90] = 0;
        values[91] = 0;
        values[92] = 0;
        values[93] = 0;
        values[94] = 0;
        values[95] = 0;
        values[96] = 0;
        values[97] = 0;
        values[98] = 0;
        values[99] = 0;
        values[100] = 0;
        values[101] = 0;
        values[102] = 0;
        values[103] = 0;
        values[104] = 0;
        values[105] = 0;
        values[106] = 0;
        values[107] = 0;
        values[108] = 0;
        values[109] = 0;
        values[110] = 0;
        values[111] = 0;
        values[112] = 6000000008;
        values[113] = 0;
        values[114] = 0;
        values[115] = 0;
        values[116] = 0;
        values[117] = 0;
        return values;
    }

    function _bannyOutfitOffsetsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](119);
        values[0] = 0;
        values[1] = 4;
        values[2] = 4;
        values[3] = 9;
        values[4] = 9;
        values[5] = 10;
        values[6] = 11;
        values[7] = 13;
        values[8] = 16;
        values[9] = 16;
        values[10] = 18;
        values[11] = 18;
        values[12] = 18;
        values[13] = 20;
        values[14] = 22;
        values[15] = 22;
        values[16] = 24;
        values[17] = 27;
        values[18] = 30;
        values[19] = 30;
        values[20] = 34;
        values[21] = 34;
        values[22] = 34;
        values[23] = 34;
        values[24] = 36;
        values[25] = 36;
        values[26] = 36;
        values[27] = 36;
        values[28] = 36;
        values[29] = 39;
        values[30] = 43;
        values[31] = 43;
        values[32] = 43;
        values[33] = 46;
        values[34] = 46;
        values[35] = 46;
        values[36] = 46;
        values[37] = 47;
        values[38] = 47;
        values[39] = 47;
        values[40] = 47;
        values[41] = 47;
        values[42] = 51;
        values[43] = 55;
        values[44] = 55;
        values[45] = 55;
        values[46] = 56;
        values[47] = 60;
        values[48] = 62;
        values[49] = 63;
        values[50] = 63;
        values[51] = 63;
        values[52] = 66;
        values[53] = 66;
        values[54] = 66;
        values[55] = 66;
        values[56] = 67;
        values[57] = 67;
        values[58] = 67;
        values[59] = 67;
        values[60] = 67;
        values[61] = 67;
        values[62] = 67;
        values[63] = 67;
        values[64] = 67;
        values[65] = 67;
        values[66] = 69;
        values[67] = 69;
        values[68] = 69;
        values[69] = 69;
        values[70] = 69;
        values[71] = 69;
        values[72] = 73;
        values[73] = 74;
        values[74] = 79;
        values[75] = 79;
        values[76] = 81;
        values[77] = 83;
        values[78] = 85;
        values[79] = 87;
        values[80] = 89;
        values[81] = 93;
        values[82] = 93;
        values[83] = 93;
        values[84] = 93;
        values[85] = 96;
        values[86] = 96;
        values[87] = 99;
        values[88] = 102;
        values[89] = 106;
        values[90] = 109;
        values[91] = 109;
        values[92] = 109;
        values[93] = 111;
        values[94] = 111;
        values[95] = 111;
        values[96] = 111;
        values[97] = 111;
        values[98] = 111;
        values[99] = 111;
        values[100] = 111;
        values[101] = 111;
        values[102] = 111;
        values[103] = 111;
        values[104] = 111;
        values[105] = 111;
        values[106] = 111;
        values[107] = 111;
        values[108] = 111;
        values[109] = 114;
        values[110] = 114;
        values[111] = 116;
        values[112] = 119;
        values[113] = 122;
        values[114] = 122;
        values[115] = 122;
        values[116] = 122;
        values[117] = 122;
        values[118] = 123;
        return values;
    }

    function _bannyOutfitTokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](123);
        values[0] = 7000000002;
        values[1] = 17000000001;
        values[2] = 26000000003;
        values[3] = 46000000001;
        values[4] = 7000000001;
        values[5] = 14000000002;
        values[6] = 19000000002;
        values[7] = 26000000002;
        values[8] = 35000000004;
        values[9] = 18000000001;
        values[10] = 21000000001;
        values[11] = 19000000003;
        values[12] = 25000000001;
        values[13] = 14000000001;
        values[14] = 26000000001;
        values[15] = 35000000001;
        values[16] = 10000000001;
        values[17] = 44000000001;
        values[18] = 32000000001;
        values[19] = 44000000002;
        values[20] = 31000000001;
        values[21] = 47000000001;
        values[22] = 35000000002;
        values[23] = 43000000001;
        values[24] = 32000000002;
        values[25] = 35000000003;
        values[26] = 48000000001;
        values[27] = 23000000001;
        values[28] = 39000000001;
        values[29] = 43000000002;
        values[30] = 19000000001;
        values[31] = 31000000002;
        values[32] = 37000000001;
        values[33] = 43000000003;
        values[34] = 25000000002;
        values[35] = 49000000001;
        values[36] = 19000000004;
        values[37] = 38000000001;
        values[38] = 48000000002;
        values[39] = 14000000003;
        values[40] = 25000000003;
        values[41] = 37000000002;
        values[42] = 42000000001;
        values[43] = 15000000001;
        values[44] = 29000000001;
        values[45] = 39000000002;
        values[46] = 28000000001;
        values[47] = 10000000002;
        values[48] = 19000000005;
        values[49] = 25000000004;
        values[50] = 43000000004;
        values[51] = 10000000003;
        values[52] = 18000000002;
        values[53] = 20000000001;
        values[54] = 44000000003;
        values[55] = 31000000003;
        values[56] = 10000000004;
        values[57] = 19000000006;
        values[58] = 25000000005;
        values[59] = 49000000002;
        values[60] = 15000000002;
        values[61] = 26000000004;
        values[62] = 10000000005;
        values[63] = 19000000007;
        values[64] = 35000000005;
        values[65] = 42000000002;
        values[66] = 31000000004;
        values[67] = 19000000008;
        values[68] = 43000000005;
        values[69] = 13000000001;
        values[70] = 19000000009;
        values[71] = 25000000006;
        values[72] = 42000000003;
        values[73] = 25000000007;
        values[74] = 16000000001;
        values[75] = 17000000002;
        values[76] = 31000000005;
        values[77] = 33000000001;
        values[78] = 48000000003;
        values[79] = 32000000003;
        values[80] = 48000000004;
        values[81] = 23000000002;
        values[82] = 41000000001;
        values[83] = 23000000004;
        values[84] = 41000000003;
        values[85] = 23000000005;
        values[86] = 41000000004;
        values[87] = 23000000003;
        values[88] = 41000000002;
        values[89] = 19000000010;
        values[90] = 31000000006;
        values[91] = 35000000006;
        values[92] = 47000000002;
        values[93] = 10000000006;
        values[94] = 18000000003;
        values[95] = 20000000002;
        values[96] = 15000000003;
        values[97] = 26000000005;
        values[98] = 44000000004;
        values[99] = 19000000011;
        values[100] = 39000000003;
        values[101] = 44000000005;
        values[102] = 15000000004;
        values[103] = 23000000006;
        values[104] = 40000000001;
        values[105] = 49000000003;
        values[106] = 19000000012;
        values[107] = 28000000002;
        values[108] = 38000000002;
        values[109] = 13000000002;
        values[110] = 48000000005;
        values[111] = 19000000013;
        values[112] = 29000000002;
        values[113] = 38000000003;
        values[114] = 31000000007;
        values[115] = 43000000006;
        values[116] = 19000000014;
        values[117] = 25000000008;
        values[118] = 43000000007;
        values[119] = 15000000005;
        values[120] = 19000000015;
        values[121] = 25000000009;
        values[122] = 31000000008;
        return values;
    }

    function _regularTargetTokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](118);
        values[0] = 1000000001;
        values[1] = 2000000001;
        values[2] = 2000000002;
        values[3] = 2000000003;
        values[4] = 2000000004;
        values[5] = 2000000005;
        values[6] = 2000000006;
        values[7] = 3000000001;
        values[8] = 3000000002;
        values[9] = 3000000003;
        values[10] = 3000000004;
        values[11] = 3000000005;
        values[12] = 3000000006;
        values[13] = 3000000007;
        values[14] = 3000000008;
        values[15] = 3000000009;
        values[16] = 3000000010;
        values[17] = 3000000011;
        values[18] = 3000000012;
        values[19] = 3000000013;
        values[20] = 3000000014;
        values[21] = 3000000015;
        values[22] = 3000000016;
        values[23] = 3000000017;
        values[24] = 3000000018;
        values[25] = 3000000019;
        values[26] = 3000000020;
        values[27] = 3000000021;
        values[28] = 3000000022;
        values[29] = 3000000023;
        values[30] = 3000000024;
        values[31] = 3000000025;
        values[32] = 3000000026;
        values[33] = 4000000001;
        values[34] = 4000000002;
        values[35] = 4000000003;
        values[36] = 4000000004;
        values[37] = 4000000005;
        values[38] = 4000000006;
        values[39] = 4000000007;
        values[40] = 4000000008;
        values[41] = 4000000009;
        values[42] = 4000000010;
        values[43] = 4000000011;
        values[44] = 4000000012;
        values[45] = 4000000013;
        values[46] = 4000000014;
        values[47] = 4000000015;
        values[48] = 4000000016;
        values[49] = 4000000017;
        values[50] = 4000000018;
        values[51] = 4000000019;
        values[52] = 4000000020;
        values[53] = 4000000021;
        values[54] = 4000000022;
        values[55] = 4000000023;
        values[56] = 4000000024;
        values[57] = 4000000025;
        values[58] = 4000000026;
        values[59] = 4000000027;
        values[60] = 4000000028;
        values[61] = 4000000029;
        values[62] = 4000000030;
        values[63] = 4000000031;
        values[64] = 4000000032;
        values[65] = 4000000033;
        values[66] = 4000000034;
        values[67] = 4000000035;
        values[68] = 4000000036;
        values[69] = 4000000037;
        values[70] = 4000000038;
        values[71] = 4000000039;
        values[72] = 4000000040;
        values[73] = 4000000041;
        values[74] = 4000000042;
        values[75] = 4000000043;
        values[76] = 4000000044;
        values[77] = 4000000045;
        values[78] = 4000000046;
        values[79] = 4000000047;
        values[80] = 4000000048;
        values[81] = 4000000049;
        values[82] = 4000000050;
        values[83] = 4000000051;
        values[84] = 4000000052;
        values[85] = 4000000053;
        values[86] = 4000000054;
        values[87] = 4000000055;
        values[88] = 4000000056;
        values[89] = 4000000057;
        values[90] = 4000000058;
        values[91] = 4000000059;
        values[92] = 4000000060;
        values[93] = 4000000061;
        values[94] = 4000000062;
        values[95] = 4000000063;
        values[96] = 4000000064;
        values[97] = 4000000065;
        values[98] = 4000000066;
        values[99] = 4000000067;
        values[100] = 4000000068;
        values[101] = 4000000069;
        values[102] = 4000000070;
        values[103] = 4000000071;
        values[104] = 4000000072;
        values[105] = 4000000073;
        values[106] = 4000000074;
        values[107] = 4000000075;
        values[108] = 4000000076;
        values[109] = 4000000077;
        values[110] = 4000000078;
        values[111] = 4000000079;
        values[112] = 4000000080;
        values[113] = 4000000081;
        values[114] = 4000000082;
        values[115] = 4000000083;
        values[116] = 4000000084;
        values[117] = 4000000085;
        return values;
    }

    function _regularV4TokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](118);
        values[0] = 1000000001;
        values[1] = 2000000001;
        values[2] = 2000000002;
        values[3] = 2000000003;
        values[4] = 2000000004;
        values[5] = 2000000005;
        values[6] = 2000000006;
        values[7] = 3000000001;
        values[8] = 3000000002;
        values[9] = 3000000003;
        values[10] = 3000000004;
        values[11] = 3000000005;
        values[12] = 3000000006;
        values[13] = 3000000007;
        values[14] = 3000000008;
        values[15] = 3000000009;
        values[16] = 3000000010;
        values[17] = 3000000011;
        values[18] = 3000000012;
        values[19] = 3000000013;
        values[20] = 3000000014;
        values[21] = 3000000015;
        values[22] = 3000000016;
        values[23] = 3000000017;
        values[24] = 3000000018;
        values[25] = 3000000019;
        values[26] = 3000000020;
        values[27] = 3000000021;
        values[28] = 3000000022;
        values[29] = 3000000023;
        values[30] = 3000000024;
        values[31] = 3000000025;
        values[32] = 3000000026;
        values[33] = 4000000001;
        values[34] = 4000000002;
        values[35] = 4000000003;
        values[36] = 4000000004;
        values[37] = 4000000005;
        values[38] = 4000000006;
        values[39] = 4000000007;
        values[40] = 4000000008;
        values[41] = 4000000009;
        values[42] = 4000000010;
        values[43] = 4000000011;
        values[44] = 4000000012;
        values[45] = 4000000013;
        values[46] = 4000000014;
        values[47] = 4000000015;
        values[48] = 4000000016;
        values[49] = 4000000017;
        values[50] = 4000000018;
        values[51] = 4000000019;
        values[52] = 4000000020;
        values[53] = 4000000021;
        values[54] = 4000000022;
        values[55] = 4000000023;
        values[56] = 4000000024;
        values[57] = 4000000025;
        values[58] = 4000000026;
        values[59] = 4000000027;
        values[60] = 4000000028;
        values[61] = 4000000029;
        values[62] = 4000000030;
        values[63] = 4000000031;
        values[64] = 4000000032;
        values[65] = 4000000033;
        values[66] = 4000000034;
        values[67] = 4000000035;
        values[68] = 4000000036;
        values[69] = 4000000037;
        values[70] = 4000000038;
        values[71] = 4000000039;
        values[72] = 4000000040;
        values[73] = 4000000041;
        values[74] = 4000000042;
        values[75] = 4000000043;
        values[76] = 4000000044;
        values[77] = 4000000045;
        values[78] = 4000000046;
        values[79] = 4000000047;
        values[80] = 4000000048;
        values[81] = 4000000049;
        values[82] = 4000000050;
        values[83] = 4000000051;
        values[84] = 4000000052;
        values[85] = 4000000053;
        values[86] = 4000000054;
        values[87] = 4000000055;
        values[88] = 4000000056;
        values[89] = 4000000057;
        values[90] = 4000000058;
        values[91] = 4000000059;
        values[92] = 4000000060;
        values[93] = 4000000061;
        values[94] = 4000000062;
        values[95] = 4000000063;
        values[96] = 4000000064;
        values[97] = 4000000065;
        values[98] = 4000000066;
        values[99] = 4000000067;
        values[100] = 4000000068;
        values[101] = 4000000069;
        values[102] = 4000000070;
        values[103] = 4000000071;
        values[104] = 4000000072;
        values[105] = 4000000073;
        values[106] = 4000000074;
        values[107] = 4000000075;
        values[108] = 4000000076;
        values[109] = 4000000077;
        values[110] = 4000000078;
        values[111] = 4000000079;
        values[112] = 4000000080;
        values[113] = 4000000081;
        values[114] = 4000000082;
        values[115] = 4000000083;
        values[116] = 4000000084;
        values[117] = 4000000085;
        return values;
    }

    function _regularAllowResolverOwnersEthereum() internal pure returns (bool[] memory values) {
        values = new bool[](118);
        return values;
    }

    function _unusedTargetTokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](281);
        values[0] = 5000000007;
        values[1] = 5000000008;
        values[2] = 6000000009;
        values[3] = 6000000010;
        values[4] = 6000000011;
        values[5] = 6000000012;
        values[6] = 6000000013;
        values[7] = 10000000007;
        values[8] = 10000000008;
        values[9] = 10000000009;
        values[10] = 10000000010;
        values[11] = 10000000011;
        values[12] = 10000000012;
        values[13] = 10000000013;
        values[14] = 11000000001;
        values[15] = 13000000003;
        values[16] = 13000000004;
        values[17] = 14000000004;
        values[18] = 14000000005;
        values[19] = 14000000006;
        values[20] = 17000000003;
        values[21] = 17000000004;
        values[22] = 17000000005;
        values[23] = 19000000016;
        values[24] = 19000000017;
        values[25] = 19000000018;
        values[26] = 19000000019;
        values[27] = 19000000020;
        values[28] = 19000000021;
        values[29] = 19000000022;
        values[30] = 20000000003;
        values[31] = 20000000004;
        values[32] = 20000000005;
        values[33] = 20000000006;
        values[34] = 20000000007;
        values[35] = 20000000008;
        values[36] = 21000000002;
        values[37] = 23000000007;
        values[38] = 23000000008;
        values[39] = 25000000010;
        values[40] = 25000000011;
        values[41] = 25000000012;
        values[42] = 26000000006;
        values[43] = 26000000007;
        values[44] = 28000000003;
        values[45] = 28000000004;
        values[46] = 28000000005;
        values[47] = 28000000006;
        values[48] = 28000000007;
        values[49] = 28000000008;
        values[50] = 28000000009;
        values[51] = 29000000003;
        values[52] = 31000000009;
        values[53] = 31000000010;
        values[54] = 31000000011;
        values[55] = 31000000012;
        values[56] = 31000000013;
        values[57] = 32000000004;
        values[58] = 32000000005;
        values[59] = 33000000002;
        values[60] = 35000000007;
        values[61] = 35000000008;
        values[62] = 35000000009;
        values[63] = 37000000003;
        values[64] = 37000000004;
        values[65] = 39000000004;
        values[66] = 40000000002;
        values[67] = 40000000003;
        values[68] = 41000000005;
        values[69] = 42000000004;
        values[70] = 42000000005;
        values[71] = 42000000006;
        values[72] = 42000000007;
        values[73] = 42000000008;
        values[74] = 42000000009;
        values[75] = 42000000010;
        values[76] = 42000000011;
        values[77] = 42000000012;
        values[78] = 42000000013;
        values[79] = 42000000014;
        values[80] = 42000000015;
        values[81] = 42000000016;
        values[82] = 42000000017;
        values[83] = 42000000018;
        values[84] = 42000000019;
        values[85] = 43000000008;
        values[86] = 43000000009;
        values[87] = 43000000010;
        values[88] = 43000000011;
        values[89] = 43000000012;
        values[90] = 43000000013;
        values[91] = 43000000014;
        values[92] = 43000000015;
        values[93] = 43000000016;
        values[94] = 43000000017;
        values[95] = 43000000018;
        values[96] = 44000000006;
        values[97] = 44000000007;
        values[98] = 44000000008;
        values[99] = 44000000009;
        values[100] = 44000000010;
        values[101] = 44000000011;
        values[102] = 44000000012;
        values[103] = 44000000013;
        values[104] = 44000000014;
        values[105] = 44000000015;
        values[106] = 44000000016;
        values[107] = 44000000017;
        values[108] = 44000000018;
        values[109] = 44000000019;
        values[110] = 44000000020;
        values[111] = 44000000021;
        values[112] = 44000000022;
        values[113] = 44000000023;
        values[114] = 44000000024;
        values[115] = 44000000025;
        values[116] = 44000000026;
        values[117] = 44000000027;
        values[118] = 44000000028;
        values[119] = 44000000029;
        values[120] = 44000000030;
        values[121] = 44000000031;
        values[122] = 44000000032;
        values[123] = 44000000033;
        values[124] = 44000000034;
        values[125] = 47000000003;
        values[126] = 47000000004;
        values[127] = 47000000005;
        values[128] = 47000000006;
        values[129] = 47000000007;
        values[130] = 47000000008;
        values[131] = 47000000009;
        values[132] = 47000000010;
        values[133] = 47000000011;
        values[134] = 47000000012;
        values[135] = 47000000013;
        values[136] = 47000000014;
        values[137] = 48000000006;
        values[138] = 49000000004;
        values[139] = 49000000005;
        values[140] = 49000000006;
        values[141] = 49000000007;
        values[142] = 49000000008;
        values[143] = 49000000009;
        values[144] = 49000000010;
        values[145] = 49000000011;
        values[146] = 49000000012;
        values[147] = 49000000013;
        values[148] = 49000000014;
        values[149] = 49000000015;
        values[150] = 49000000016;
        values[151] = 49000000017;
        values[152] = 49000000018;
        values[153] = 49000000019;
        values[154] = 49000000020;
        values[155] = 49000000021;
        values[156] = 49000000022;
        values[157] = 49000000023;
        values[158] = 49000000024;
        values[159] = 49000000025;
        values[160] = 49000000026;
        values[161] = 49000000027;
        values[162] = 49000000028;
        values[163] = 49000000029;
        values[164] = 49000000030;
        values[165] = 49000000031;
        values[166] = 49000000032;
        values[167] = 49000000033;
        values[168] = 49000000034;
        values[169] = 49000000035;
        values[170] = 49000000036;
        values[171] = 49000000037;
        values[172] = 49000000038;
        values[173] = 49000000039;
        values[174] = 49000000040;
        values[175] = 49000000041;
        values[176] = 49000000042;
        values[177] = 49000000043;
        values[178] = 49000000044;
        values[179] = 49000000045;
        values[180] = 49000000046;
        values[181] = 49000000047;
        values[182] = 49000000048;
        values[183] = 49000000049;
        values[184] = 49000000050;
        values[185] = 49000000051;
        values[186] = 49000000052;
        values[187] = 49000000053;
        values[188] = 49000000054;
        values[189] = 49000000055;
        values[190] = 49000000056;
        values[191] = 49000000057;
        values[192] = 49000000058;
        values[193] = 49000000059;
        values[194] = 49000000060;
        values[195] = 49000000061;
        values[196] = 49000000062;
        values[197] = 49000000063;
        values[198] = 49000000064;
        values[199] = 49000000065;
        values[200] = 49000000066;
        values[201] = 49000000067;
        values[202] = 49000000068;
        values[203] = 49000000069;
        values[204] = 49000000070;
        values[205] = 49000000071;
        values[206] = 49000000072;
        values[207] = 49000000073;
        values[208] = 49000000074;
        values[209] = 49000000075;
        values[210] = 49000000076;
        values[211] = 49000000077;
        values[212] = 49000000078;
        values[213] = 49000000079;
        values[214] = 49000000080;
        values[215] = 49000000081;
        values[216] = 49000000082;
        values[217] = 49000000083;
        values[218] = 49000000084;
        values[219] = 49000000085;
        values[220] = 49000000086;
        values[221] = 49000000087;
        values[222] = 49000000088;
        values[223] = 49000000089;
        values[224] = 49000000090;
        values[225] = 49000000091;
        values[226] = 49000000092;
        values[227] = 49000000093;
        values[228] = 49000000094;
        values[229] = 49000000095;
        values[230] = 49000000096;
        values[231] = 49000000097;
        values[232] = 49000000098;
        values[233] = 49000000099;
        values[234] = 49000000100;
        values[235] = 49000000101;
        values[236] = 49000000102;
        values[237] = 49000000103;
        values[238] = 49000000104;
        values[239] = 49000000105;
        values[240] = 49000000106;
        values[241] = 49000000107;
        values[242] = 49000000108;
        values[243] = 49000000109;
        values[244] = 49000000110;
        values[245] = 49000000111;
        values[246] = 49000000112;
        values[247] = 49000000113;
        values[248] = 49000000114;
        values[249] = 49000000115;
        values[250] = 49000000116;
        values[251] = 49000000117;
        values[252] = 49000000118;
        values[253] = 49000000119;
        values[254] = 49000000120;
        values[255] = 49000000121;
        values[256] = 49000000122;
        values[257] = 49000000123;
        values[258] = 49000000124;
        values[259] = 49000000125;
        values[260] = 49000000126;
        values[261] = 49000000127;
        values[262] = 49000000128;
        values[263] = 49000000129;
        values[264] = 49000000130;
        values[265] = 49000000131;
        values[266] = 49000000132;
        values[267] = 49000000133;
        values[268] = 49000000134;
        values[269] = 49000000135;
        values[270] = 49000000136;
        values[271] = 49000000137;
        values[272] = 49000000138;
        values[273] = 49000000139;
        values[274] = 49000000140;
        values[275] = 49000000141;
        values[276] = 49000000142;
        values[277] = 49000000143;
        values[278] = 49000000144;
        values[279] = 49000000145;
        values[280] = 10000000014;
        return values;
    }

    function _unusedV4TokenIdsEthereum() internal pure returns (uint256[] memory values) {
        values = new uint256[](281);
        values[0] = 5000000003;
        values[1] = 5000000007;
        values[2] = 6000000005;
        values[3] = 6000000006;
        values[4] = 6000000007;
        values[5] = 6000000008;
        values[6] = 6000000009;
        values[7] = 10000000004;
        values[8] = 10000000008;
        values[9] = 10000000009;
        values[10] = 10000000010;
        values[11] = 10000000011;
        values[12] = 10000000013;
        values[13] = 10000000014;
        values[14] = 11000000001;
        values[15] = 13000000002;
        values[16] = 13000000004;
        values[17] = 14000000002;
        values[18] = 14000000004;
        values[19] = 14000000006;
        values[20] = 17000000003;
        values[21] = 17000000004;
        values[22] = 17000000005;
        values[23] = 19000000001;
        values[24] = 19000000003;
        values[25] = 19000000006;
        values[26] = 19000000007;
        values[27] = 19000000010;
        values[28] = 19000000014;
        values[29] = 19000000022;
        values[30] = 20000000002;
        values[31] = 20000000003;
        values[32] = 20000000004;
        values[33] = 20000000005;
        values[34] = 20000000006;
        values[35] = 20000000007;
        values[36] = 21000000002;
        values[37] = 23000000006;
        values[38] = 23000000008;
        values[39] = 25000000001;
        values[40] = 25000000004;
        values[41] = 25000000012;
        values[42] = 26000000006;
        values[43] = 26000000007;
        values[44] = 28000000001;
        values[45] = 28000000003;
        values[46] = 28000000004;
        values[47] = 28000000005;
        values[48] = 28000000006;
        values[49] = 28000000007;
        values[50] = 28000000009;
        values[51] = 29000000001;
        values[52] = 31000000001;
        values[53] = 31000000004;
        values[54] = 31000000005;
        values[55] = 31000000008;
        values[56] = 31000000012;
        values[57] = 32000000004;
        values[58] = 32000000005;
        values[59] = 33000000002;
        values[60] = 35000000005;
        values[61] = 35000000008;
        values[62] = 35000000009;
        values[63] = 37000000002;
        values[64] = 37000000004;
        values[65] = 39000000004;
        values[66] = 40000000002;
        values[67] = 40000000003;
        values[68] = 41000000005;
        values[69] = 42000000001;
        values[70] = 42000000003;
        values[71] = 42000000005;
        values[72] = 42000000006;
        values[73] = 42000000008;
        values[74] = 42000000009;
        values[75] = 42000000010;
        values[76] = 42000000011;
        values[77] = 42000000012;
        values[78] = 42000000013;
        values[79] = 42000000014;
        values[80] = 42000000015;
        values[81] = 42000000016;
        values[82] = 42000000017;
        values[83] = 42000000018;
        values[84] = 42000000019;
        values[85] = 43000000001;
        values[86] = 43000000002;
        values[87] = 43000000004;
        values[88] = 43000000009;
        values[89] = 43000000010;
        values[90] = 43000000011;
        values[91] = 43000000012;
        values[92] = 43000000013;
        values[93] = 43000000014;
        values[94] = 43000000015;
        values[95] = 43000000016;
        values[96] = 44000000002;
        values[97] = 44000000005;
        values[98] = 44000000006;
        values[99] = 44000000007;
        values[100] = 44000000010;
        values[101] = 44000000011;
        values[102] = 44000000012;
        values[103] = 44000000013;
        values[104] = 44000000014;
        values[105] = 44000000015;
        values[106] = 44000000016;
        values[107] = 44000000017;
        values[108] = 44000000018;
        values[109] = 44000000019;
        values[110] = 44000000020;
        values[111] = 44000000021;
        values[112] = 44000000022;
        values[113] = 44000000023;
        values[114] = 44000000024;
        values[115] = 44000000025;
        values[116] = 44000000026;
        values[117] = 44000000027;
        values[118] = 44000000028;
        values[119] = 44000000029;
        values[120] = 44000000030;
        values[121] = 44000000031;
        values[122] = 44000000032;
        values[123] = 44000000033;
        values[124] = 44000000034;
        values[125] = 47000000001;
        values[126] = 47000000002;
        values[127] = 47000000004;
        values[128] = 47000000006;
        values[129] = 47000000007;
        values[130] = 47000000008;
        values[131] = 47000000009;
        values[132] = 47000000010;
        values[133] = 47000000011;
        values[134] = 47000000012;
        values[135] = 47000000013;
        values[136] = 47000000014;
        values[137] = 48000000004;
        values[138] = 49000000003;
        values[139] = 49000000005;
        values[140] = 49000000006;
        values[141] = 49000000007;
        values[142] = 49000000008;
        values[143] = 49000000009;
        values[144] = 49000000010;
        values[145] = 49000000011;
        values[146] = 49000000012;
        values[147] = 49000000013;
        values[148] = 49000000014;
        values[149] = 49000000015;
        values[150] = 49000000016;
        values[151] = 49000000017;
        values[152] = 49000000018;
        values[153] = 49000000019;
        values[154] = 49000000020;
        values[155] = 49000000021;
        values[156] = 49000000022;
        values[157] = 49000000023;
        values[158] = 49000000024;
        values[159] = 49000000025;
        values[160] = 49000000026;
        values[161] = 49000000027;
        values[162] = 49000000028;
        values[163] = 49000000029;
        values[164] = 49000000030;
        values[165] = 49000000031;
        values[166] = 49000000032;
        values[167] = 49000000033;
        values[168] = 49000000034;
        values[169] = 49000000035;
        values[170] = 49000000036;
        values[171] = 49000000037;
        values[172] = 49000000038;
        values[173] = 49000000039;
        values[174] = 49000000040;
        values[175] = 49000000041;
        values[176] = 49000000042;
        values[177] = 49000000043;
        values[178] = 49000000044;
        values[179] = 49000000045;
        values[180] = 49000000046;
        values[181] = 49000000047;
        values[182] = 49000000048;
        values[183] = 49000000049;
        values[184] = 49000000050;
        values[185] = 49000000051;
        values[186] = 49000000052;
        values[187] = 49000000053;
        values[188] = 49000000054;
        values[189] = 49000000055;
        values[190] = 49000000056;
        values[191] = 49000000057;
        values[192] = 49000000058;
        values[193] = 49000000059;
        values[194] = 49000000060;
        values[195] = 49000000061;
        values[196] = 49000000062;
        values[197] = 49000000063;
        values[198] = 49000000064;
        values[199] = 49000000065;
        values[200] = 49000000066;
        values[201] = 49000000067;
        values[202] = 49000000068;
        values[203] = 49000000069;
        values[204] = 49000000070;
        values[205] = 49000000071;
        values[206] = 49000000072;
        values[207] = 49000000073;
        values[208] = 49000000074;
        values[209] = 49000000075;
        values[210] = 49000000076;
        values[211] = 49000000077;
        values[212] = 49000000078;
        values[213] = 49000000079;
        values[214] = 49000000080;
        values[215] = 49000000081;
        values[216] = 49000000082;
        values[217] = 49000000083;
        values[218] = 49000000084;
        values[219] = 49000000085;
        values[220] = 49000000086;
        values[221] = 49000000087;
        values[222] = 49000000088;
        values[223] = 49000000089;
        values[224] = 49000000090;
        values[225] = 49000000091;
        values[226] = 49000000092;
        values[227] = 49000000093;
        values[228] = 49000000094;
        values[229] = 49000000095;
        values[230] = 49000000096;
        values[231] = 49000000097;
        values[232] = 49000000098;
        values[233] = 49000000099;
        values[234] = 49000000100;
        values[235] = 49000000101;
        values[236] = 49000000102;
        values[237] = 49000000103;
        values[238] = 49000000104;
        values[239] = 49000000105;
        values[240] = 49000000106;
        values[241] = 49000000107;
        values[242] = 49000000108;
        values[243] = 49000000109;
        values[244] = 49000000110;
        values[245] = 49000000111;
        values[246] = 49000000112;
        values[247] = 49000000113;
        values[248] = 49000000114;
        values[249] = 49000000115;
        values[250] = 49000000116;
        values[251] = 49000000117;
        values[252] = 49000000118;
        values[253] = 49000000119;
        values[254] = 49000000120;
        values[255] = 49000000121;
        values[256] = 49000000122;
        values[257] = 49000000123;
        values[258] = 49000000124;
        values[259] = 49000000125;
        values[260] = 49000000126;
        values[261] = 49000000127;
        values[262] = 49000000128;
        values[263] = 49000000129;
        values[264] = 49000000130;
        values[265] = 49000000131;
        values[266] = 49000000132;
        values[267] = 49000000133;
        values[268] = 49000000134;
        values[269] = 49000000135;
        values[270] = 49000000136;
        values[271] = 49000000137;
        values[272] = 49000000138;
        values[273] = 49000000139;
        values[274] = 49000000140;
        values[275] = 49000000141;
        values[276] = 49000000142;
        values[277] = 49000000143;
        values[278] = 49000000144;
        values[279] = 49000000145;
        values[280] = 10000000003;
        return values;
    }

    function _unusedAllowResolverOwnersEthereum() internal pure returns (bool[] memory values) {
        values = new bool[](281);
        values[280] = true;
        return values;
    }

    function _expectedTokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](11);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        values[5] = 11000000001;
        values[6] = 17000000001;
        values[7] = 19000000001;
        values[8] = 25000000001;
        values[9] = 44000000001;
        values[10] = 47000000001;
        return values;
    }

    function _bannyV4TokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](5);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        return values;
    }

    function _bannyTargetTokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](5);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        return values;
    }

    function _bannyBackgroundTokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](5);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;
        return values;
    }

    function _bannyOutfitOffsetsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](6);
        values[0] = 0;
        values[1] = 4;
        values[2] = 4;
        values[3] = 5;
        values[4] = 5;
        values[5] = 5;
        return values;
    }

    function _bannyOutfitTokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](5);
        values[0] = 11000000001;
        values[1] = 19000000001;
        values[2] = 25000000001;
        values[3] = 44000000001;
        values[4] = 47000000001;
        return values;
    }

    function _regularTargetTokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](6);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        values[5] = 17000000001;
        return values;
    }

    function _regularV4TokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](6);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        values[5] = 17000000001;
        return values;
    }

    function _regularAllowResolverOwnersOptimism() internal pure returns (bool[] memory values) {
        values = new bool[](6);
        return values;
    }

    function _unusedTargetTokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](0);
        return values;
    }

    function _unusedV4TokenIdsOptimism() internal pure returns (uint256[] memory values) {
        values = new uint256[](0);
        return values;
    }

    function _unusedAllowResolverOwnersOptimism() internal pure returns (bool[] memory values) {
        values = new bool[](0);
        return values;
    }

    function _expectedTokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](228);
        values[0] = 2000000001;
        values[1] = 2000000002;
        values[2] = 2000000003;
        values[3] = 3000000001;
        values[4] = 3000000002;
        values[5] = 3000000003;
        values[6] = 3000000004;
        values[7] = 3000000005;
        values[8] = 3000000006;
        values[9] = 3000000007;
        values[10] = 3000000008;
        values[11] = 3000000009;
        values[12] = 3000000010;
        values[13] = 4000000001;
        values[14] = 4000000002;
        values[15] = 4000000003;
        values[16] = 4000000004;
        values[17] = 4000000005;
        values[18] = 4000000006;
        values[19] = 4000000007;
        values[20] = 4000000008;
        values[21] = 4000000009;
        values[22] = 5000000001;
        values[23] = 6000000001;
        values[24] = 6000000002;
        values[25] = 6000000003;
        values[26] = 6000000004;
        values[27] = 10000000001;
        values[28] = 11000000001;
        values[29] = 14000000001;
        values[30] = 14000000002;
        values[31] = 15000000001;
        values[32] = 15000000002;
        values[33] = 19000000001;
        values[34] = 19000000002;
        values[35] = 19000000003;
        values[36] = 19000000004;
        values[37] = 25000000001;
        values[38] = 25000000002;
        values[39] = 25000000003;
        values[40] = 25000000004;
        values[41] = 28000000001;
        values[42] = 28000000002;
        values[43] = 28000000003;
        values[44] = 28000000004;
        values[45] = 31000000001;
        values[46] = 32000000001;
        values[47] = 33000000001;
        values[48] = 37000000001;
        values[49] = 37000000002;
        values[50] = 40000000001;
        values[51] = 43000000001;
        values[52] = 44000000001;
        values[53] = 44000000002;
        values[54] = 45000000001;
        values[55] = 47000000001;
        values[56] = 47000000002;
        values[57] = 4000000010;
        values[58] = 4000000011;
        values[59] = 4000000012;
        values[60] = 4000000013;
        values[61] = 4000000014;
        values[62] = 4000000015;
        values[63] = 4000000016;
        values[64] = 4000000017;
        values[65] = 4000000018;
        values[66] = 4000000019;
        values[67] = 4000000020;
        values[68] = 4000000021;
        values[69] = 4000000022;
        values[70] = 4000000023;
        values[71] = 4000000024;
        values[72] = 4000000025;
        values[73] = 4000000026;
        values[74] = 4000000027;
        values[75] = 4000000028;
        values[76] = 4000000029;
        values[77] = 4000000030;
        values[78] = 4000000031;
        values[79] = 4000000032;
        values[80] = 4000000033;
        values[81] = 4000000034;
        values[82] = 4000000035;
        values[83] = 4000000036;
        values[84] = 4000000037;
        values[85] = 4000000038;
        values[86] = 4000000039;
        values[87] = 4000000040;
        values[88] = 4000000041;
        values[89] = 4000000042;
        values[90] = 4000000043;
        values[91] = 4000000044;
        values[92] = 4000000045;
        values[93] = 4000000046;
        values[94] = 4000000047;
        values[95] = 4000000048;
        values[96] = 4000000049;
        values[97] = 4000000050;
        values[98] = 4000000051;
        values[99] = 4000000052;
        values[100] = 4000000053;
        values[101] = 10000000002;
        values[102] = 10000000003;
        values[103] = 10000000004;
        values[104] = 14000000003;
        values[105] = 19000000005;
        values[106] = 25000000005;
        values[107] = 28000000005;
        values[108] = 31000000002;
        values[109] = 38000000001;
        values[110] = 43000000002;
        values[111] = 43000000003;
        values[112] = 47000000003;
        values[113] = 4000000054;
        values[114] = 4000000055;
        values[115] = 4000000056;
        values[116] = 4000000057;
        values[117] = 4000000058;
        values[118] = 4000000059;
        values[119] = 4000000060;
        values[120] = 4000000061;
        values[121] = 4000000062;
        values[122] = 4000000063;
        values[123] = 4000000064;
        values[124] = 4000000065;
        values[125] = 4000000066;
        values[126] = 4000000067;
        values[127] = 4000000068;
        values[128] = 4000000069;
        values[129] = 4000000070;
        values[130] = 4000000071;
        values[131] = 4000000072;
        values[132] = 4000000073;
        values[133] = 4000000074;
        values[134] = 4000000075;
        values[135] = 10000000005;
        values[136] = 19000000006;
        values[137] = 25000000006;
        values[138] = 25000000007;
        values[139] = 43000000004;
        values[140] = 4000000076;
        values[141] = 4000000077;
        values[142] = 4000000078;
        values[143] = 4000000079;
        values[144] = 4000000080;
        values[145] = 4000000081;
        values[146] = 4000000082;
        values[147] = 4000000083;
        values[148] = 4000000084;
        values[149] = 4000000085;
        values[150] = 4000000086;
        values[151] = 4000000087;
        values[152] = 4000000088;
        values[153] = 4000000089;
        values[154] = 4000000090;
        values[155] = 4000000091;
        values[156] = 4000000092;
        values[157] = 4000000093;
        values[158] = 4000000094;
        values[159] = 5000000002;
        values[160] = 5000000003;
        values[161] = 13000000001;
        values[162] = 19000000007;
        values[163] = 20000000001;
        values[164] = 25000000008;
        values[165] = 27000000001;
        values[166] = 28000000006;
        values[167] = 35000000001;
        values[168] = 38000000002;
        values[169] = 39000000001;
        values[170] = 41000000001;
        values[171] = 43000000005;
        values[172] = 43000000006;
        values[173] = 44000000003;
        values[174] = 48000000001;
        values[175] = 5000000004;
        values[176] = 5000000005;
        values[177] = 6000000005;
        values[178] = 7000000001;
        values[179] = 10000000006;
        values[180] = 10000000007;
        values[181] = 10000000008;
        values[182] = 10000000009;
        values[183] = 10000000010;
        values[184] = 10000000011;
        values[185] = 11000000002;
        values[186] = 11000000003;
        values[187] = 13000000002;
        values[188] = 14000000004;
        values[189] = 17000000001;
        values[190] = 19000000008;
        values[191] = 19000000009;
        values[192] = 19000000010;
        values[193] = 19000000011;
        values[194] = 19000000012;
        values[195] = 24000000001;
        values[196] = 25000000009;
        values[197] = 28000000007;
        values[198] = 28000000008;
        values[199] = 28000000009;
        values[200] = 28000000010;
        values[201] = 31000000003;
        values[202] = 31000000004;
        values[203] = 31000000005;
        values[204] = 31000000006;
        values[205] = 32000000002;
        values[206] = 34000000001;
        values[207] = 35000000002;
        values[208] = 35000000003;
        values[209] = 35000000004;
        values[210] = 38000000003;
        values[211] = 39000000002;
        values[212] = 40000000002;
        values[213] = 40000000003;
        values[214] = 41000000002;
        values[215] = 42000000001;
        values[216] = 42000000002;
        values[217] = 43000000007;
        values[218] = 43000000008;
        values[219] = 44000000004;
        values[220] = 44000000005;
        values[221] = 47000000004;
        values[222] = 47000000005;
        values[223] = 47000000006;
        values[224] = 47000000007;
        values[225] = 47000000008;
        values[226] = 49000000001;
        values[227] = 49000000002;
        return values;
    }

    function _bannyV4TokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](107);
        values[0] = 2000000001;
        values[1] = 2000000002;
        values[2] = 2000000003;
        values[3] = 3000000001;
        values[4] = 3000000002;
        values[5] = 3000000003;
        values[6] = 3000000004;
        values[7] = 3000000005;
        values[8] = 3000000006;
        values[9] = 3000000007;
        values[10] = 3000000008;
        values[11] = 3000000009;
        values[12] = 3000000010;
        values[13] = 4000000001;
        values[14] = 4000000002;
        values[15] = 4000000003;
        values[16] = 4000000004;
        values[17] = 4000000005;
        values[18] = 4000000006;
        values[19] = 4000000007;
        values[20] = 4000000008;
        values[21] = 4000000009;
        values[22] = 4000000010;
        values[23] = 4000000011;
        values[24] = 4000000012;
        values[25] = 4000000013;
        values[26] = 4000000014;
        values[27] = 4000000015;
        values[28] = 4000000016;
        values[29] = 4000000017;
        values[30] = 4000000018;
        values[31] = 4000000019;
        values[32] = 4000000020;
        values[33] = 4000000021;
        values[34] = 4000000022;
        values[35] = 4000000023;
        values[36] = 4000000024;
        values[37] = 4000000025;
        values[38] = 4000000026;
        values[39] = 4000000027;
        values[40] = 4000000028;
        values[41] = 4000000029;
        values[42] = 4000000030;
        values[43] = 4000000031;
        values[44] = 4000000032;
        values[45] = 4000000033;
        values[46] = 4000000034;
        values[47] = 4000000035;
        values[48] = 4000000036;
        values[49] = 4000000037;
        values[50] = 4000000038;
        values[51] = 4000000039;
        values[52] = 4000000040;
        values[53] = 4000000041;
        values[54] = 4000000042;
        values[55] = 4000000043;
        values[56] = 4000000044;
        values[57] = 4000000045;
        values[58] = 4000000046;
        values[59] = 4000000047;
        values[60] = 4000000048;
        values[61] = 4000000049;
        values[62] = 4000000050;
        values[63] = 4000000051;
        values[64] = 4000000052;
        values[65] = 4000000053;
        values[66] = 4000000054;
        values[67] = 4000000055;
        values[68] = 4000000056;
        values[69] = 4000000057;
        values[70] = 4000000058;
        values[71] = 4000000059;
        values[72] = 4000000060;
        values[73] = 4000000061;
        values[74] = 4000000062;
        values[75] = 4000000063;
        values[76] = 4000000064;
        values[77] = 4000000065;
        values[78] = 4000000066;
        values[79] = 4000000067;
        values[80] = 4000000068;
        values[81] = 4000000069;
        values[82] = 4000000070;
        values[83] = 4000000071;
        values[84] = 4000000072;
        values[85] = 4000000073;
        values[86] = 4000000074;
        values[87] = 4000000075;
        values[88] = 4000000076;
        values[89] = 4000000077;
        values[90] = 4000000078;
        values[91] = 4000000079;
        values[92] = 4000000080;
        values[93] = 4000000081;
        values[94] = 4000000082;
        values[95] = 4000000083;
        values[96] = 4000000084;
        values[97] = 4000000085;
        values[98] = 4000000086;
        values[99] = 4000000087;
        values[100] = 4000000088;
        values[101] = 4000000089;
        values[102] = 4000000090;
        values[103] = 4000000091;
        values[104] = 4000000092;
        values[105] = 4000000093;
        values[106] = 4000000094;
        return values;
    }

    function _bannyTargetTokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](107);
        values[0] = 2000000001;
        values[1] = 2000000002;
        values[2] = 2000000003;
        values[3] = 3000000001;
        values[4] = 3000000002;
        values[5] = 3000000003;
        values[6] = 3000000004;
        values[7] = 3000000005;
        values[8] = 3000000006;
        values[9] = 3000000007;
        values[10] = 3000000008;
        values[11] = 3000000009;
        values[12] = 3000000010;
        values[13] = 4000000001;
        values[14] = 4000000002;
        values[15] = 4000000003;
        values[16] = 4000000004;
        values[17] = 4000000005;
        values[18] = 4000000006;
        values[19] = 4000000007;
        values[20] = 4000000008;
        values[21] = 4000000009;
        values[22] = 4000000010;
        values[23] = 4000000011;
        values[24] = 4000000012;
        values[25] = 4000000013;
        values[26] = 4000000014;
        values[27] = 4000000015;
        values[28] = 4000000016;
        values[29] = 4000000017;
        values[30] = 4000000018;
        values[31] = 4000000019;
        values[32] = 4000000020;
        values[33] = 4000000021;
        values[34] = 4000000022;
        values[35] = 4000000023;
        values[36] = 4000000024;
        values[37] = 4000000025;
        values[38] = 4000000026;
        values[39] = 4000000027;
        values[40] = 4000000028;
        values[41] = 4000000029;
        values[42] = 4000000030;
        values[43] = 4000000031;
        values[44] = 4000000032;
        values[45] = 4000000033;
        values[46] = 4000000034;
        values[47] = 4000000035;
        values[48] = 4000000036;
        values[49] = 4000000037;
        values[50] = 4000000038;
        values[51] = 4000000039;
        values[52] = 4000000040;
        values[53] = 4000000041;
        values[54] = 4000000042;
        values[55] = 4000000043;
        values[56] = 4000000044;
        values[57] = 4000000045;
        values[58] = 4000000046;
        values[59] = 4000000047;
        values[60] = 4000000048;
        values[61] = 4000000049;
        values[62] = 4000000050;
        values[63] = 4000000051;
        values[64] = 4000000052;
        values[65] = 4000000053;
        values[66] = 4000000054;
        values[67] = 4000000055;
        values[68] = 4000000056;
        values[69] = 4000000057;
        values[70] = 4000000058;
        values[71] = 4000000059;
        values[72] = 4000000060;
        values[73] = 4000000061;
        values[74] = 4000000062;
        values[75] = 4000000063;
        values[76] = 4000000064;
        values[77] = 4000000065;
        values[78] = 4000000066;
        values[79] = 4000000067;
        values[80] = 4000000068;
        values[81] = 4000000069;
        values[82] = 4000000070;
        values[83] = 4000000071;
        values[84] = 4000000072;
        values[85] = 4000000073;
        values[86] = 4000000074;
        values[87] = 4000000075;
        values[88] = 4000000076;
        values[89] = 4000000077;
        values[90] = 4000000078;
        values[91] = 4000000079;
        values[92] = 4000000080;
        values[93] = 4000000081;
        values[94] = 4000000082;
        values[95] = 4000000083;
        values[96] = 4000000084;
        values[97] = 4000000085;
        values[98] = 4000000086;
        values[99] = 4000000087;
        values[100] = 4000000088;
        values[101] = 4000000089;
        values[102] = 4000000090;
        values[103] = 4000000091;
        values[104] = 4000000092;
        values[105] = 4000000093;
        values[106] = 4000000094;
        return values;
    }

    function _bannyBackgroundTokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](107);
        values[0] = 0;
        values[1] = 6000000001;
        values[2] = 6000000003;
        values[3] = 0;
        values[4] = 0;
        values[5] = 0;
        values[6] = 0;
        values[7] = 0;
        values[8] = 6000000002;
        values[9] = 0;
        values[10] = 0;
        values[11] = 0;
        values[12] = 5000000001;
        values[13] = 0;
        values[14] = 0;
        values[15] = 6000000004;
        values[16] = 0;
        values[17] = 0;
        values[18] = 0;
        values[19] = 0;
        values[20] = 0;
        values[21] = 0;
        values[22] = 0;
        values[23] = 0;
        values[24] = 0;
        values[25] = 0;
        values[26] = 0;
        values[27] = 0;
        values[28] = 0;
        values[29] = 0;
        values[30] = 0;
        values[31] = 0;
        values[32] = 0;
        values[33] = 0;
        values[34] = 0;
        values[35] = 0;
        values[36] = 0;
        values[37] = 0;
        values[38] = 0;
        values[39] = 0;
        values[40] = 0;
        values[41] = 0;
        values[42] = 0;
        values[43] = 0;
        values[44] = 0;
        values[45] = 0;
        values[46] = 0;
        values[47] = 0;
        values[48] = 0;
        values[49] = 0;
        values[50] = 0;
        values[51] = 0;
        values[52] = 0;
        values[53] = 0;
        values[54] = 0;
        values[55] = 0;
        values[56] = 0;
        values[57] = 0;
        values[58] = 0;
        values[59] = 0;
        values[60] = 0;
        values[61] = 0;
        values[62] = 0;
        values[63] = 0;
        values[64] = 0;
        values[65] = 0;
        values[66] = 0;
        values[67] = 0;
        values[68] = 0;
        values[69] = 0;
        values[70] = 0;
        values[71] = 0;
        values[72] = 0;
        values[73] = 0;
        values[74] = 0;
        values[75] = 0;
        values[76] = 0;
        values[77] = 0;
        values[78] = 0;
        values[79] = 0;
        values[80] = 0;
        values[81] = 0;
        values[82] = 0;
        values[83] = 0;
        values[84] = 0;
        values[85] = 0;
        values[86] = 0;
        values[87] = 0;
        values[88] = 0;
        values[89] = 0;
        values[90] = 0;
        values[91] = 0;
        values[92] = 5000000002;
        values[93] = 0;
        values[94] = 0;
        values[95] = 0;
        values[96] = 5000000003;
        values[97] = 0;
        values[98] = 0;
        values[99] = 0;
        values[100] = 0;
        values[101] = 0;
        values[102] = 0;
        values[103] = 0;
        values[104] = 0;
        values[105] = 0;
        values[106] = 0;
        return values;
    }

    function _bannyOutfitOffsetsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](108);
        values[0] = 0;
        values[1] = 2;
        values[2] = 4;
        values[3] = 7;
        values[4] = 9;
        values[5] = 10;
        values[6] = 14;
        values[7] = 14;
        values[8] = 14;
        values[9] = 17;
        values[10] = 20;
        values[11] = 22;
        values[12] = 22;
        values[13] = 24;
        values[14] = 25;
        values[15] = 25;
        values[16] = 30;
        values[17] = 30;
        values[18] = 30;
        values[19] = 30;
        values[20] = 30;
        values[21] = 30;
        values[22] = 30;
        values[23] = 30;
        values[24] = 30;
        values[25] = 30;
        values[26] = 30;
        values[27] = 30;
        values[28] = 30;
        values[29] = 30;
        values[30] = 30;
        values[31] = 30;
        values[32] = 30;
        values[33] = 30;
        values[34] = 30;
        values[35] = 30;
        values[36] = 30;
        values[37] = 30;
        values[38] = 30;
        values[39] = 30;
        values[40] = 30;
        values[41] = 30;
        values[42] = 30;
        values[43] = 30;
        values[44] = 30;
        values[45] = 30;
        values[46] = 30;
        values[47] = 30;
        values[48] = 30;
        values[49] = 30;
        values[50] = 30;
        values[51] = 30;
        values[52] = 30;
        values[53] = 30;
        values[54] = 30;
        values[55] = 30;
        values[56] = 30;
        values[57] = 30;
        values[58] = 33;
        values[59] = 34;
        values[60] = 34;
        values[61] = 37;
        values[62] = 38;
        values[63] = 42;
        values[64] = 42;
        values[65] = 42;
        values[66] = 42;
        values[67] = 43;
        values[68] = 43;
        values[69] = 43;
        values[70] = 43;
        values[71] = 43;
        values[72] = 43;
        values[73] = 43;
        values[74] = 43;
        values[75] = 43;
        values[76] = 43;
        values[77] = 43;
        values[78] = 43;
        values[79] = 43;
        values[80] = 43;
        values[81] = 43;
        values[82] = 43;
        values[83] = 43;
        values[84] = 43;
        values[85] = 43;
        values[86] = 47;
        values[87] = 47;
        values[88] = 47;
        values[89] = 47;
        values[90] = 47;
        values[91] = 47;
        values[92] = 50;
        values[93] = 53;
        values[94] = 57;
        values[95] = 58;
        values[96] = 58;
        values[97] = 60;
        values[98] = 61;
        values[99] = 61;
        values[100] = 61;
        values[101] = 61;
        values[102] = 61;
        values[103] = 61;
        values[104] = 61;
        values[105] = 61;
        values[106] = 61;
        values[107] = 61;
        return values;
    }

    function _bannyOutfitTokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](61);
        values[0] = 28000000002;
        values[1] = 37000000001;
        values[2] = 14000000001;
        values[3] = 32000000001;
        values[4] = 25000000003;
        values[5] = 37000000002;
        values[6] = 45000000001;
        values[7] = 25000000002;
        values[8] = 47000000001;
        values[9] = 31000000001;
        values[10] = 10000000001;
        values[11] = 19000000002;
        values[12] = 28000000003;
        values[13] = 47000000002;
        values[14] = 14000000002;
        values[15] = 19000000003;
        values[16] = 28000000001;
        values[17] = 19000000004;
        values[18] = 28000000004;
        values[19] = 44000000002;
        values[20] = 15000000002;
        values[21] = 40000000001;
        values[22] = 25000000004;
        values[23] = 43000000001;
        values[24] = 15000000001;
        values[25] = 11000000001;
        values[26] = 19000000001;
        values[27] = 25000000001;
        values[28] = 33000000001;
        values[29] = 44000000001;
        values[30] = 10000000002;
        values[31] = 25000000005;
        values[32] = 43000000002;
        values[33] = 47000000003;
        values[34] = 10000000003;
        values[35] = 19000000005;
        values[36] = 28000000005;
        values[37] = 10000000004;
        values[38] = 14000000003;
        values[39] = 31000000002;
        values[40] = 38000000001;
        values[41] = 43000000003;
        values[42] = 25000000006;
        values[43] = 10000000005;
        values[44] = 19000000006;
        values[45] = 25000000007;
        values[46] = 43000000004;
        values[47] = 27000000001;
        values[48] = 38000000002;
        values[49] = 48000000001;
        values[50] = 13000000001;
        values[51] = 20000000001;
        values[52] = 44000000003;
        values[53] = 19000000007;
        values[54] = 25000000008;
        values[55] = 35000000001;
        values[56] = 43000000005;
        values[57] = 43000000006;
        values[58] = 39000000001;
        values[59] = 41000000001;
        values[60] = 28000000006;
        return values;
    }

    function _regularTargetTokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](107);
        values[0] = 2000000001;
        values[1] = 2000000002;
        values[2] = 2000000003;
        values[3] = 3000000001;
        values[4] = 3000000002;
        values[5] = 3000000003;
        values[6] = 3000000004;
        values[7] = 3000000005;
        values[8] = 3000000006;
        values[9] = 3000000007;
        values[10] = 3000000008;
        values[11] = 3000000009;
        values[12] = 3000000010;
        values[13] = 4000000001;
        values[14] = 4000000002;
        values[15] = 4000000003;
        values[16] = 4000000004;
        values[17] = 4000000005;
        values[18] = 4000000006;
        values[19] = 4000000007;
        values[20] = 4000000008;
        values[21] = 4000000009;
        values[22] = 4000000010;
        values[23] = 4000000011;
        values[24] = 4000000012;
        values[25] = 4000000013;
        values[26] = 4000000014;
        values[27] = 4000000015;
        values[28] = 4000000016;
        values[29] = 4000000017;
        values[30] = 4000000018;
        values[31] = 4000000019;
        values[32] = 4000000020;
        values[33] = 4000000021;
        values[34] = 4000000022;
        values[35] = 4000000023;
        values[36] = 4000000024;
        values[37] = 4000000025;
        values[38] = 4000000026;
        values[39] = 4000000027;
        values[40] = 4000000028;
        values[41] = 4000000029;
        values[42] = 4000000030;
        values[43] = 4000000031;
        values[44] = 4000000032;
        values[45] = 4000000033;
        values[46] = 4000000034;
        values[47] = 4000000035;
        values[48] = 4000000036;
        values[49] = 4000000037;
        values[50] = 4000000038;
        values[51] = 4000000039;
        values[52] = 4000000040;
        values[53] = 4000000041;
        values[54] = 4000000042;
        values[55] = 4000000043;
        values[56] = 4000000044;
        values[57] = 4000000045;
        values[58] = 4000000046;
        values[59] = 4000000047;
        values[60] = 4000000048;
        values[61] = 4000000049;
        values[62] = 4000000050;
        values[63] = 4000000051;
        values[64] = 4000000052;
        values[65] = 4000000053;
        values[66] = 4000000054;
        values[67] = 4000000055;
        values[68] = 4000000056;
        values[69] = 4000000057;
        values[70] = 4000000058;
        values[71] = 4000000059;
        values[72] = 4000000060;
        values[73] = 4000000061;
        values[74] = 4000000062;
        values[75] = 4000000063;
        values[76] = 4000000064;
        values[77] = 4000000065;
        values[78] = 4000000066;
        values[79] = 4000000067;
        values[80] = 4000000068;
        values[81] = 4000000069;
        values[82] = 4000000070;
        values[83] = 4000000071;
        values[84] = 4000000072;
        values[85] = 4000000073;
        values[86] = 4000000074;
        values[87] = 4000000075;
        values[88] = 4000000076;
        values[89] = 4000000077;
        values[90] = 4000000078;
        values[91] = 4000000079;
        values[92] = 4000000080;
        values[93] = 4000000081;
        values[94] = 4000000082;
        values[95] = 4000000083;
        values[96] = 4000000084;
        values[97] = 4000000085;
        values[98] = 4000000086;
        values[99] = 4000000087;
        values[100] = 4000000088;
        values[101] = 4000000089;
        values[102] = 4000000090;
        values[103] = 4000000091;
        values[104] = 4000000092;
        values[105] = 4000000093;
        values[106] = 4000000094;
        return values;
    }

    function _regularV4TokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](107);
        values[0] = 2000000001;
        values[1] = 2000000002;
        values[2] = 2000000003;
        values[3] = 3000000001;
        values[4] = 3000000002;
        values[5] = 3000000003;
        values[6] = 3000000004;
        values[7] = 3000000005;
        values[8] = 3000000006;
        values[9] = 3000000007;
        values[10] = 3000000008;
        values[11] = 3000000009;
        values[12] = 3000000010;
        values[13] = 4000000001;
        values[14] = 4000000002;
        values[15] = 4000000003;
        values[16] = 4000000004;
        values[17] = 4000000005;
        values[18] = 4000000006;
        values[19] = 4000000007;
        values[20] = 4000000008;
        values[21] = 4000000009;
        values[22] = 4000000010;
        values[23] = 4000000011;
        values[24] = 4000000012;
        values[25] = 4000000013;
        values[26] = 4000000014;
        values[27] = 4000000015;
        values[28] = 4000000016;
        values[29] = 4000000017;
        values[30] = 4000000018;
        values[31] = 4000000019;
        values[32] = 4000000020;
        values[33] = 4000000021;
        values[34] = 4000000022;
        values[35] = 4000000023;
        values[36] = 4000000024;
        values[37] = 4000000025;
        values[38] = 4000000026;
        values[39] = 4000000027;
        values[40] = 4000000028;
        values[41] = 4000000029;
        values[42] = 4000000030;
        values[43] = 4000000031;
        values[44] = 4000000032;
        values[45] = 4000000033;
        values[46] = 4000000034;
        values[47] = 4000000035;
        values[48] = 4000000036;
        values[49] = 4000000037;
        values[50] = 4000000038;
        values[51] = 4000000039;
        values[52] = 4000000040;
        values[53] = 4000000041;
        values[54] = 4000000042;
        values[55] = 4000000043;
        values[56] = 4000000044;
        values[57] = 4000000045;
        values[58] = 4000000046;
        values[59] = 4000000047;
        values[60] = 4000000048;
        values[61] = 4000000049;
        values[62] = 4000000050;
        values[63] = 4000000051;
        values[64] = 4000000052;
        values[65] = 4000000053;
        values[66] = 4000000054;
        values[67] = 4000000055;
        values[68] = 4000000056;
        values[69] = 4000000057;
        values[70] = 4000000058;
        values[71] = 4000000059;
        values[72] = 4000000060;
        values[73] = 4000000061;
        values[74] = 4000000062;
        values[75] = 4000000063;
        values[76] = 4000000064;
        values[77] = 4000000065;
        values[78] = 4000000066;
        values[79] = 4000000067;
        values[80] = 4000000068;
        values[81] = 4000000069;
        values[82] = 4000000070;
        values[83] = 4000000071;
        values[84] = 4000000072;
        values[85] = 4000000073;
        values[86] = 4000000074;
        values[87] = 4000000075;
        values[88] = 4000000076;
        values[89] = 4000000077;
        values[90] = 4000000078;
        values[91] = 4000000079;
        values[92] = 4000000080;
        values[93] = 4000000081;
        values[94] = 4000000082;
        values[95] = 4000000083;
        values[96] = 4000000084;
        values[97] = 4000000085;
        values[98] = 4000000086;
        values[99] = 4000000087;
        values[100] = 4000000088;
        values[101] = 4000000089;
        values[102] = 4000000090;
        values[103] = 4000000091;
        values[104] = 4000000092;
        values[105] = 4000000093;
        values[106] = 4000000094;
        return values;
    }

    function _regularAllowResolverOwnersBase() internal pure returns (bool[] memory values) {
        values = new bool[](107);
        return values;
    }

    function _unusedTargetTokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](53);
        values[0] = 5000000004;
        values[1] = 5000000005;
        values[2] = 6000000005;
        values[3] = 7000000001;
        values[4] = 10000000006;
        values[5] = 10000000007;
        values[6] = 10000000008;
        values[7] = 10000000009;
        values[8] = 10000000010;
        values[9] = 10000000011;
        values[10] = 11000000002;
        values[11] = 11000000003;
        values[12] = 13000000002;
        values[13] = 14000000004;
        values[14] = 17000000001;
        values[15] = 19000000008;
        values[16] = 19000000009;
        values[17] = 19000000010;
        values[18] = 19000000011;
        values[19] = 19000000012;
        values[20] = 24000000001;
        values[21] = 25000000009;
        values[22] = 28000000007;
        values[23] = 28000000008;
        values[24] = 28000000009;
        values[25] = 28000000010;
        values[26] = 31000000003;
        values[27] = 31000000004;
        values[28] = 31000000005;
        values[29] = 31000000006;
        values[30] = 32000000002;
        values[31] = 34000000001;
        values[32] = 35000000002;
        values[33] = 35000000003;
        values[34] = 35000000004;
        values[35] = 38000000003;
        values[36] = 39000000002;
        values[37] = 40000000002;
        values[38] = 40000000003;
        values[39] = 41000000002;
        values[40] = 42000000001;
        values[41] = 42000000002;
        values[42] = 43000000007;
        values[43] = 43000000008;
        values[44] = 44000000004;
        values[45] = 44000000005;
        values[46] = 47000000004;
        values[47] = 47000000005;
        values[48] = 47000000006;
        values[49] = 47000000007;
        values[50] = 47000000008;
        values[51] = 49000000001;
        values[52] = 49000000002;
        return values;
    }

    function _unusedV4TokenIdsBase() internal pure returns (uint256[] memory values) {
        values = new uint256[](53);
        values[0] = 5000000002;
        values[1] = 5000000005;
        values[2] = 6000000002;
        values[3] = 7000000001;
        values[4] = 10000000002;
        values[5] = 10000000006;
        values[6] = 10000000008;
        values[7] = 10000000009;
        values[8] = 10000000010;
        values[9] = 10000000011;
        values[10] = 11000000002;
        values[11] = 11000000003;
        values[12] = 13000000002;
        values[13] = 14000000004;
        values[14] = 17000000001;
        values[15] = 19000000002;
        values[16] = 19000000004;
        values[17] = 19000000010;
        values[18] = 19000000011;
        values[19] = 19000000012;
        values[20] = 24000000001;
        values[21] = 25000000003;
        values[22] = 28000000003;
        values[23] = 28000000006;
        values[24] = 28000000009;
        values[25] = 28000000010;
        values[26] = 31000000003;
        values[27] = 31000000004;
        values[28] = 31000000005;
        values[29] = 31000000006;
        values[30] = 32000000002;
        values[31] = 34000000001;
        values[32] = 35000000001;
        values[33] = 35000000003;
        values[34] = 35000000004;
        values[35] = 38000000003;
        values[36] = 39000000002;
        values[37] = 40000000002;
        values[38] = 40000000003;
        values[39] = 41000000002;
        values[40] = 42000000001;
        values[41] = 42000000002;
        values[42] = 43000000001;
        values[43] = 43000000004;
        values[44] = 44000000002;
        values[45] = 44000000003;
        values[46] = 47000000002;
        values[47] = 47000000004;
        values[48] = 47000000006;
        values[49] = 47000000007;
        values[50] = 47000000008;
        values[51] = 49000000001;
        values[52] = 49000000002;
        return values;
    }

    function _unusedAllowResolverOwnersBase() internal pure returns (bool[] memory values) {
        values = new bool[](53);
        return values;
    }

    function _expectedTokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](205);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 5000000001;
        values[5] = 19000000001;
        values[6] = 25000000001;
        values[7] = 38000000001;
        values[8] = 47000000001;
        values[9] = 4000000003;
        values[10] = 4000000004;
        values[11] = 4000000005;
        values[12] = 4000000006;
        values[13] = 6000000001;
        values[14] = 10000000001;
        values[15] = 11000000001;
        values[16] = 19000000002;
        values[17] = 20000000001;
        values[18] = 28000000001;
        values[19] = 31000000001;
        values[20] = 49000000001;
        values[21] = 4000000007;
        values[22] = 4000000008;
        values[23] = 4000000009;
        values[24] = 5000000002;
        values[25] = 10000000002;
        values[26] = 20000000002;
        values[27] = 28000000002;
        values[28] = 43000000001;
        values[29] = 5000000003;
        values[30] = 19000000003;
        values[31] = 19000000004;
        values[32] = 31000000002;
        values[33] = 32000000001;
        values[34] = 39000000001;
        values[35] = 47000000002;
        values[36] = 47000000003;
        values[37] = 47000000004;
        values[38] = 47000000005;
        values[39] = 47000000006;
        values[40] = 47000000007;
        values[41] = 47000000008;
        values[42] = 47000000009;
        values[43] = 47000000010;
        values[44] = 47000000011;
        values[45] = 47000000012;
        values[46] = 47000000013;
        values[47] = 47000000014;
        values[48] = 47000000015;
        values[49] = 47000000016;
        values[50] = 47000000017;
        values[51] = 47000000018;
        values[52] = 47000000019;
        values[53] = 47000000020;
        values[54] = 47000000021;
        values[55] = 47000000022;
        values[56] = 47000000023;
        values[57] = 47000000024;
        values[58] = 47000000025;
        values[59] = 47000000026;
        values[60] = 47000000027;
        values[61] = 49000000002;
        values[62] = 49000000003;
        values[63] = 49000000004;
        values[64] = 49000000005;
        values[65] = 49000000006;
        values[66] = 49000000007;
        values[67] = 49000000008;
        values[68] = 49000000009;
        values[69] = 49000000010;
        values[70] = 49000000011;
        values[71] = 49000000012;
        values[72] = 49000000013;
        values[73] = 49000000014;
        values[74] = 49000000015;
        values[75] = 49000000016;
        values[76] = 49000000017;
        values[77] = 49000000018;
        values[78] = 49000000019;
        values[79] = 49000000020;
        values[80] = 49000000021;
        values[81] = 49000000022;
        values[82] = 49000000023;
        values[83] = 49000000024;
        values[84] = 49000000025;
        values[85] = 49000000026;
        values[86] = 49000000027;
        values[87] = 49000000028;
        values[88] = 49000000029;
        values[89] = 49000000030;
        values[90] = 49000000031;
        values[91] = 49000000032;
        values[92] = 49000000033;
        values[93] = 49000000034;
        values[94] = 49000000035;
        values[95] = 49000000036;
        values[96] = 49000000037;
        values[97] = 49000000038;
        values[98] = 49000000039;
        values[99] = 49000000040;
        values[100] = 49000000041;
        values[101] = 49000000042;
        values[102] = 49000000043;
        values[103] = 49000000044;
        values[104] = 49000000045;
        values[105] = 49000000046;
        values[106] = 49000000047;
        values[107] = 49000000048;
        values[108] = 49000000049;
        values[109] = 49000000050;
        values[110] = 49000000051;
        values[111] = 49000000052;
        values[112] = 49000000053;
        values[113] = 49000000054;
        values[114] = 49000000055;
        values[115] = 49000000056;
        values[116] = 49000000057;
        values[117] = 49000000058;
        values[118] = 49000000059;
        values[119] = 49000000060;
        values[120] = 49000000061;
        values[121] = 49000000062;
        values[122] = 49000000063;
        values[123] = 49000000064;
        values[124] = 49000000065;
        values[125] = 49000000066;
        values[126] = 49000000067;
        values[127] = 49000000068;
        values[128] = 49000000069;
        values[129] = 49000000070;
        values[130] = 49000000071;
        values[131] = 49000000072;
        values[132] = 49000000073;
        values[133] = 49000000074;
        values[134] = 49000000075;
        values[135] = 49000000076;
        values[136] = 49000000077;
        values[137] = 49000000078;
        values[138] = 49000000079;
        values[139] = 49000000080;
        values[140] = 49000000081;
        values[141] = 49000000082;
        values[142] = 49000000083;
        values[143] = 49000000084;
        values[144] = 49000000085;
        values[145] = 49000000086;
        values[146] = 49000000087;
        values[147] = 49000000088;
        values[148] = 49000000089;
        values[149] = 49000000090;
        values[150] = 49000000091;
        values[151] = 49000000092;
        values[152] = 49000000093;
        values[153] = 49000000094;
        values[154] = 49000000095;
        values[155] = 49000000096;
        values[156] = 49000000097;
        values[157] = 49000000098;
        values[158] = 49000000099;
        values[159] = 49000000100;
        values[160] = 49000000101;
        values[161] = 49000000102;
        values[162] = 49000000103;
        values[163] = 49000000104;
        values[164] = 49000000105;
        values[165] = 49000000106;
        values[166] = 49000000107;
        values[167] = 49000000108;
        values[168] = 49000000109;
        values[169] = 49000000110;
        values[170] = 49000000111;
        values[171] = 49000000112;
        values[172] = 49000000113;
        values[173] = 49000000114;
        values[174] = 49000000115;
        values[175] = 49000000116;
        values[176] = 49000000117;
        values[177] = 49000000118;
        values[178] = 49000000119;
        values[179] = 49000000120;
        values[180] = 49000000121;
        values[181] = 49000000122;
        values[182] = 49000000123;
        values[183] = 49000000124;
        values[184] = 49000000125;
        values[185] = 49000000126;
        values[186] = 49000000127;
        values[187] = 49000000128;
        values[188] = 49000000129;
        values[189] = 49000000130;
        values[190] = 49000000131;
        values[191] = 49000000132;
        values[192] = 49000000133;
        values[193] = 49000000134;
        values[194] = 49000000135;
        values[195] = 49000000136;
        values[196] = 49000000137;
        values[197] = 49000000138;
        values[198] = 49000000139;
        values[199] = 49000000140;
        values[200] = 49000000141;
        values[201] = 49000000142;
        values[202] = 49000000143;
        values[203] = 49000000144;
        values[204] = 49000000145;
        return values;
    }

    function _bannyV4TokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](11);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        values[5] = 4000000004;
        values[6] = 4000000005;
        values[7] = 4000000006;
        values[8] = 4000000007;
        values[9] = 4000000008;
        values[10] = 4000000009;
        return values;
    }

    function _bannyTargetTokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](11);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        values[5] = 4000000004;
        values[6] = 4000000005;
        values[7] = 4000000006;
        values[8] = 4000000007;
        values[9] = 4000000008;
        values[10] = 4000000009;
        return values;
    }

    function _bannyBackgroundTokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](11);
        values[0] = 5000000001;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 6000000001;
        values[5] = 0;
        values[6] = 0;
        values[7] = 0;
        values[8] = 5000000002;
        values[9] = 0;
        values[10] = 0;
        return values;
    }

    function _bannyOutfitOffsetsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](12);
        values[0] = 0;
        values[1] = 4;
        values[2] = 4;
        values[3] = 4;
        values[4] = 4;
        values[5] = 7;
        values[6] = 9;
        values[7] = 11;
        values[8] = 11;
        values[9] = 14;
        values[10] = 14;
        values[11] = 15;
        return values;
    }

    function _bannyOutfitTokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](15);
        values[0] = 19000000001;
        values[1] = 25000000001;
        values[2] = 38000000001;
        values[3] = 47000000001;
        values[4] = 11000000001;
        values[5] = 19000000002;
        values[6] = 28000000001;
        values[7] = 10000000001;
        values[8] = 20000000001;
        values[9] = 31000000001;
        values[10] = 49000000001;
        values[11] = 10000000002;
        values[12] = 20000000002;
        values[13] = 43000000001;
        values[14] = 28000000002;
        return values;
    }

    function _regularTargetTokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](11);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        values[5] = 4000000004;
        values[6] = 4000000005;
        values[7] = 4000000006;
        values[8] = 4000000007;
        values[9] = 4000000008;
        values[10] = 4000000009;
        return values;
    }

    function _regularV4TokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](11);
        values[0] = 3000000001;
        values[1] = 3000000002;
        values[2] = 4000000001;
        values[3] = 4000000002;
        values[4] = 4000000003;
        values[5] = 4000000004;
        values[6] = 4000000005;
        values[7] = 4000000006;
        values[8] = 4000000007;
        values[9] = 4000000008;
        values[10] = 4000000009;
        return values;
    }

    function _regularAllowResolverOwnersArbitrum() internal pure returns (bool[] memory values) {
        values = new bool[](11);
        return values;
    }

    function _unusedTargetTokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](176);
        values[0] = 5000000003;
        values[1] = 19000000003;
        values[2] = 19000000004;
        values[3] = 31000000002;
        values[4] = 32000000001;
        values[5] = 39000000001;
        values[6] = 47000000002;
        values[7] = 47000000003;
        values[8] = 47000000004;
        values[9] = 47000000005;
        values[10] = 47000000006;
        values[11] = 47000000007;
        values[12] = 47000000008;
        values[13] = 47000000009;
        values[14] = 47000000010;
        values[15] = 47000000011;
        values[16] = 47000000012;
        values[17] = 47000000013;
        values[18] = 47000000014;
        values[19] = 47000000015;
        values[20] = 47000000016;
        values[21] = 47000000017;
        values[22] = 47000000018;
        values[23] = 47000000019;
        values[24] = 47000000020;
        values[25] = 47000000021;
        values[26] = 47000000022;
        values[27] = 47000000023;
        values[28] = 47000000024;
        values[29] = 47000000025;
        values[30] = 47000000026;
        values[31] = 47000000027;
        values[32] = 49000000002;
        values[33] = 49000000003;
        values[34] = 49000000004;
        values[35] = 49000000005;
        values[36] = 49000000006;
        values[37] = 49000000007;
        values[38] = 49000000008;
        values[39] = 49000000009;
        values[40] = 49000000010;
        values[41] = 49000000011;
        values[42] = 49000000012;
        values[43] = 49000000013;
        values[44] = 49000000014;
        values[45] = 49000000015;
        values[46] = 49000000016;
        values[47] = 49000000017;
        values[48] = 49000000018;
        values[49] = 49000000019;
        values[50] = 49000000020;
        values[51] = 49000000021;
        values[52] = 49000000022;
        values[53] = 49000000023;
        values[54] = 49000000024;
        values[55] = 49000000025;
        values[56] = 49000000026;
        values[57] = 49000000027;
        values[58] = 49000000028;
        values[59] = 49000000029;
        values[60] = 49000000030;
        values[61] = 49000000031;
        values[62] = 49000000032;
        values[63] = 49000000033;
        values[64] = 49000000034;
        values[65] = 49000000035;
        values[66] = 49000000036;
        values[67] = 49000000037;
        values[68] = 49000000038;
        values[69] = 49000000039;
        values[70] = 49000000040;
        values[71] = 49000000041;
        values[72] = 49000000042;
        values[73] = 49000000043;
        values[74] = 49000000044;
        values[75] = 49000000045;
        values[76] = 49000000046;
        values[77] = 49000000047;
        values[78] = 49000000048;
        values[79] = 49000000049;
        values[80] = 49000000050;
        values[81] = 49000000051;
        values[82] = 49000000052;
        values[83] = 49000000053;
        values[84] = 49000000054;
        values[85] = 49000000055;
        values[86] = 49000000056;
        values[87] = 49000000057;
        values[88] = 49000000058;
        values[89] = 49000000059;
        values[90] = 49000000060;
        values[91] = 49000000061;
        values[92] = 49000000062;
        values[93] = 49000000063;
        values[94] = 49000000064;
        values[95] = 49000000065;
        values[96] = 49000000066;
        values[97] = 49000000067;
        values[98] = 49000000068;
        values[99] = 49000000069;
        values[100] = 49000000070;
        values[101] = 49000000071;
        values[102] = 49000000072;
        values[103] = 49000000073;
        values[104] = 49000000074;
        values[105] = 49000000075;
        values[106] = 49000000076;
        values[107] = 49000000077;
        values[108] = 49000000078;
        values[109] = 49000000079;
        values[110] = 49000000080;
        values[111] = 49000000081;
        values[112] = 49000000082;
        values[113] = 49000000083;
        values[114] = 49000000084;
        values[115] = 49000000085;
        values[116] = 49000000086;
        values[117] = 49000000087;
        values[118] = 49000000088;
        values[119] = 49000000089;
        values[120] = 49000000090;
        values[121] = 49000000091;
        values[122] = 49000000092;
        values[123] = 49000000093;
        values[124] = 49000000094;
        values[125] = 49000000095;
        values[126] = 49000000096;
        values[127] = 49000000097;
        values[128] = 49000000098;
        values[129] = 49000000099;
        values[130] = 49000000100;
        values[131] = 49000000101;
        values[132] = 49000000102;
        values[133] = 49000000103;
        values[134] = 49000000104;
        values[135] = 49000000105;
        values[136] = 49000000106;
        values[137] = 49000000107;
        values[138] = 49000000108;
        values[139] = 49000000109;
        values[140] = 49000000110;
        values[141] = 49000000111;
        values[142] = 49000000112;
        values[143] = 49000000113;
        values[144] = 49000000114;
        values[145] = 49000000115;
        values[146] = 49000000116;
        values[147] = 49000000117;
        values[148] = 49000000118;
        values[149] = 49000000119;
        values[150] = 49000000120;
        values[151] = 49000000121;
        values[152] = 49000000122;
        values[153] = 49000000123;
        values[154] = 49000000124;
        values[155] = 49000000125;
        values[156] = 49000000126;
        values[157] = 49000000127;
        values[158] = 49000000128;
        values[159] = 49000000129;
        values[160] = 49000000130;
        values[161] = 49000000131;
        values[162] = 49000000132;
        values[163] = 49000000133;
        values[164] = 49000000134;
        values[165] = 49000000135;
        values[166] = 49000000136;
        values[167] = 49000000137;
        values[168] = 49000000138;
        values[169] = 49000000139;
        values[170] = 49000000140;
        values[171] = 49000000141;
        values[172] = 49000000142;
        values[173] = 49000000143;
        values[174] = 49000000144;
        values[175] = 49000000145;
        return values;
    }

    function _unusedV4TokenIdsArbitrum() internal pure returns (uint256[] memory values) {
        values = new uint256[](176);
        values[0] = 5000000003;
        values[1] = 19000000002;
        values[2] = 19000000004;
        values[3] = 31000000002;
        values[4] = 32000000001;
        values[5] = 39000000001;
        values[6] = 47000000002;
        values[7] = 47000000003;
        values[8] = 47000000004;
        values[9] = 47000000005;
        values[10] = 47000000006;
        values[11] = 47000000007;
        values[12] = 47000000008;
        values[13] = 47000000009;
        values[14] = 47000000010;
        values[15] = 47000000011;
        values[16] = 47000000012;
        values[17] = 47000000013;
        values[18] = 47000000014;
        values[19] = 47000000015;
        values[20] = 47000000016;
        values[21] = 47000000017;
        values[22] = 47000000018;
        values[23] = 47000000019;
        values[24] = 47000000020;
        values[25] = 47000000021;
        values[26] = 47000000022;
        values[27] = 47000000023;
        values[28] = 47000000024;
        values[29] = 47000000025;
        values[30] = 47000000026;
        values[31] = 47000000027;
        values[32] = 49000000001;
        values[33] = 49000000003;
        values[34] = 49000000004;
        values[35] = 49000000005;
        values[36] = 49000000006;
        values[37] = 49000000007;
        values[38] = 49000000008;
        values[39] = 49000000009;
        values[40] = 49000000010;
        values[41] = 49000000011;
        values[42] = 49000000012;
        values[43] = 49000000013;
        values[44] = 49000000014;
        values[45] = 49000000015;
        values[46] = 49000000016;
        values[47] = 49000000017;
        values[48] = 49000000018;
        values[49] = 49000000019;
        values[50] = 49000000020;
        values[51] = 49000000021;
        values[52] = 49000000022;
        values[53] = 49000000023;
        values[54] = 49000000024;
        values[55] = 49000000025;
        values[56] = 49000000026;
        values[57] = 49000000027;
        values[58] = 49000000028;
        values[59] = 49000000029;
        values[60] = 49000000030;
        values[61] = 49000000031;
        values[62] = 49000000032;
        values[63] = 49000000033;
        values[64] = 49000000034;
        values[65] = 49000000035;
        values[66] = 49000000036;
        values[67] = 49000000037;
        values[68] = 49000000038;
        values[69] = 49000000039;
        values[70] = 49000000040;
        values[71] = 49000000041;
        values[72] = 49000000042;
        values[73] = 49000000043;
        values[74] = 49000000044;
        values[75] = 49000000045;
        values[76] = 49000000046;
        values[77] = 49000000047;
        values[78] = 49000000048;
        values[79] = 49000000049;
        values[80] = 49000000050;
        values[81] = 49000000051;
        values[82] = 49000000052;
        values[83] = 49000000053;
        values[84] = 49000000054;
        values[85] = 49000000055;
        values[86] = 49000000056;
        values[87] = 49000000057;
        values[88] = 49000000058;
        values[89] = 49000000059;
        values[90] = 49000000060;
        values[91] = 49000000061;
        values[92] = 49000000062;
        values[93] = 49000000063;
        values[94] = 49000000064;
        values[95] = 49000000065;
        values[96] = 49000000066;
        values[97] = 49000000067;
        values[98] = 49000000068;
        values[99] = 49000000069;
        values[100] = 49000000070;
        values[101] = 49000000071;
        values[102] = 49000000072;
        values[103] = 49000000073;
        values[104] = 49000000074;
        values[105] = 49000000075;
        values[106] = 49000000076;
        values[107] = 49000000077;
        values[108] = 49000000078;
        values[109] = 49000000079;
        values[110] = 49000000080;
        values[111] = 49000000081;
        values[112] = 49000000082;
        values[113] = 49000000083;
        values[114] = 49000000084;
        values[115] = 49000000085;
        values[116] = 49000000086;
        values[117] = 49000000087;
        values[118] = 49000000088;
        values[119] = 49000000089;
        values[120] = 49000000090;
        values[121] = 49000000091;
        values[122] = 49000000092;
        values[123] = 49000000093;
        values[124] = 49000000094;
        values[125] = 49000000095;
        values[126] = 49000000096;
        values[127] = 49000000097;
        values[128] = 49000000098;
        values[129] = 49000000099;
        values[130] = 49000000100;
        values[131] = 49000000101;
        values[132] = 49000000102;
        values[133] = 49000000103;
        values[134] = 49000000104;
        values[135] = 49000000105;
        values[136] = 49000000106;
        values[137] = 49000000107;
        values[138] = 49000000108;
        values[139] = 49000000109;
        values[140] = 49000000110;
        values[141] = 49000000111;
        values[142] = 49000000112;
        values[143] = 49000000113;
        values[144] = 49000000114;
        values[145] = 49000000115;
        values[146] = 49000000116;
        values[147] = 49000000117;
        values[148] = 49000000118;
        values[149] = 49000000119;
        values[150] = 49000000120;
        values[151] = 49000000121;
        values[152] = 49000000122;
        values[153] = 49000000123;
        values[154] = 49000000124;
        values[155] = 49000000125;
        values[156] = 49000000126;
        values[157] = 49000000127;
        values[158] = 49000000128;
        values[159] = 49000000129;
        values[160] = 49000000130;
        values[161] = 49000000131;
        values[162] = 49000000132;
        values[163] = 49000000133;
        values[164] = 49000000134;
        values[165] = 49000000135;
        values[166] = 49000000136;
        values[167] = 49000000137;
        values[168] = 49000000138;
        values[169] = 49000000139;
        values[170] = 49000000140;
        values[171] = 49000000141;
        values[172] = 49000000142;
        values[173] = 49000000143;
        values[174] = 49000000144;
        values[175] = 49000000145;
        return values;
    }

    function _unusedAllowResolverOwnersArbitrum() internal pure returns (bool[] memory values) {
        values = new bool[](176);
        return values;
    }

}
