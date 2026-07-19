// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, stdJson} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
import {AirdropV4BannysEthereum1} from "./AirdropV4BannysEthereum1.sol";
import {AirdropV4BannysEthereum2} from "./AirdropV4BannysEthereum2.sol";
import {AirdropV4BannysEthereum3} from "./AirdropV4BannysEthereum3.sol";
import {AirdropV4BannysEthereum4} from "./AirdropV4BannysEthereum4.sol";
import {AirdropV4BannysEthereum5} from "./AirdropV4BannysEthereum5.sol";
import {AirdropV4BannysEthereum6} from "./AirdropV4BannysEthereum6.sol";
import {AirdropV4BannysEthereum7} from "./AirdropV4BannysEthereum7.sol";
import {AirdropV4BannysEthereum8} from "./AirdropV4BannysEthereum8.sol";
import {AirdropV4BannysOptimism} from "./AirdropV4BannysOptimism.sol";
import {AirdropV4BannysBase1} from "./AirdropV4BannysBase1.sol";
import {AirdropV4BannysBase2} from "./AirdropV4BannysBase2.sol";
import {AirdropV4BannysBase3} from "./AirdropV4BannysBase3.sol";
import {AirdropV4BannysBase4} from "./AirdropV4BannysBase4.sol";
import {AirdropV4BannysBase5} from "./AirdropV4BannysBase5.sol";
import {AirdropV4BannysBase6} from "./AirdropV4BannysBase6.sol";
import {AirdropV4BannysArbitrum1} from "./AirdropV4BannysArbitrum1.sol";
import {AirdropV4BannysArbitrum2} from "./AirdropV4BannysArbitrum2.sol";
import {AirdropV4BannysArbitrum3} from "./AirdropV4BannysArbitrum3.sol";
import {AirdropV4BannysArbitrum4} from "./AirdropV4BannysArbitrum4.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";

contract AirdropV4BannysScript is Script, Sphinx {
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
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
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
        _requireValidChunkFilters(chunkFilter, maxChunkFilter, 8);

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 1)) {
            uint16[] memory tierIds1 = new uint16[](60);

            // Add 1 instances of tier ID 1
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[0 + i] = 1;
            }
            // Add 6 instances of tier ID 2
            for (uint256 i = 0; i < 6; i++) {
                tierIds1[1 + i] = 2;
            }
            // Add 13 instances of tier ID 3
            for (uint256 i = 0; i < 13; i++) {
                tierIds1[7 + i] = 3;
            }
            // Add 3 instances of tier ID 5
            for (uint256 i = 0; i < 3; i++) {
                tierIds1[20 + i] = 5;
            }
            // Add 3 instances of tier ID 6
            for (uint256 i = 0; i < 3; i++) {
                tierIds1[23 + i] = 6;
            }
            // Add 2 instances of tier ID 7
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[26 + i] = 7;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[28 + i] = 10;
            }
            // Add 2 instances of tier ID 14
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[29 + i] = 14;
            }
            // Add 1 instances of tier ID 17
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[31 + i] = 17;
            }
            // Add 1 instances of tier ID 18
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[32 + i] = 18;
            }
            // Add 3 instances of tier ID 19
            for (uint256 i = 0; i < 3; i++) {
                tierIds1[33 + i] = 19;
            }
            // Add 1 instances of tier ID 21
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[36 + i] = 21;
            }
            // Add 1 instances of tier ID 23
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[37 + i] = 23;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[38 + i] = 25;
            }
            // Add 3 instances of tier ID 26
            for (uint256 i = 0; i < 3; i++) {
                tierIds1[39 + i] = 26;
            }
            // Add 2 instances of tier ID 31
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[42 + i] = 31;
            }
            // Add 2 instances of tier ID 32
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[44 + i] = 32;
            }
            // Add 4 instances of tier ID 35
            for (uint256 i = 0; i < 4; i++) {
                tierIds1[46 + i] = 35;
            }
            // Add 1 instances of tier ID 37
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[50 + i] = 37;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[51 + i] = 39;
            }
            // Add 3 instances of tier ID 43
            for (uint256 i = 0; i < 3; i++) {
                tierIds1[52 + i] = 43;
            }
            // Add 2 instances of tier ID 44
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[55 + i] = 44;
            }
            // Add 1 instances of tier ID 46
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[57 + i] = 46;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[58 + i] = 47;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[59 + i] = 48;
            }
            address[] memory transferOwners1 = _getEthereumTransferOwners1();
            AirdropV4BannysEthereum1 migration1 = new AirdropV4BannysEthereum1(transferOwners1);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds1, address(migration1));
            migration1.requireMintedTokenIds(mintedTokenIds);
            migration1.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysEthereum1 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 2)) {
            uint16[] memory tierIds2 = new uint16[](36);

            // Add 13 instances of tier ID 3
            for (uint256 i = 0; i < 13; i++) {
                tierIds2[0 + i] = 3;
            }
            // Add 7 instances of tier ID 4
            for (uint256 i = 0; i < 7; i++) {
                tierIds2[13 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[20 + i] = 5;
            }
            // Add 2 instances of tier ID 6
            for (uint256 i = 0; i < 2; i++) {
                tierIds2[21 + i] = 6;
            }
            // Add 1 instances of tier ID 14
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[23 + i] = 14;
            }
            // Add 1 instances of tier ID 15
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[24 + i] = 15;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[25 + i] = 19;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds2[26 + i] = 25;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[28 + i] = 28;
            }
            // Add 1 instances of tier ID 29
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[29 + i] = 29;
            }
            // Add 1 instances of tier ID 37
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[30 + i] = 37;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[31 + i] = 38;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[32 + i] = 39;
            }
            // Add 1 instances of tier ID 42
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[33 + i] = 42;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[34 + i] = 48;
            }
            // Add 1 instances of tier ID 49
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[35 + i] = 49;
            }
            address[] memory transferOwners2 = _getEthereumTransferOwners2();
            AirdropV4BannysEthereum2 migration2 = new AirdropV4BannysEthereum2(transferOwners2);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds2, address(migration2));
            migration2.requireMintedTokenIds(mintedTokenIds);
            migration2.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysEthereum2 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 3)) {
            uint16[] memory tierIds3 = new uint16[](42);

            // Add 20 instances of tier ID 4
            for (uint256 i = 0; i < 20; i++) {
                tierIds3[0 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[20 + i] = 5;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[21 + i] = 6;
            }
            // Add 4 instances of tier ID 10
            for (uint256 i = 0; i < 4; i++) {
                tierIds3[22 + i] = 10;
            }
            // Add 1 instances of tier ID 15
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[26 + i] = 15;
            }
            // Add 1 instances of tier ID 18
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[27 + i] = 18;
            }
            // Add 3 instances of tier ID 19
            for (uint256 i = 0; i < 3; i++) {
                tierIds3[28 + i] = 19;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[31 + i] = 20;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds3[32 + i] = 25;
            }
            // Add 1 instances of tier ID 26
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[34 + i] = 26;
            }
            // Add 2 instances of tier ID 31
            for (uint256 i = 0; i < 2; i++) {
                tierIds3[35 + i] = 31;
            }
            // Add 1 instances of tier ID 35
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[37 + i] = 35;
            }
            // Add 1 instances of tier ID 42
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[38 + i] = 42;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[39 + i] = 43;
            }
            // Add 1 instances of tier ID 44
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[40 + i] = 44;
            }
            // Add 1 instances of tier ID 49
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[41 + i] = 49;
            }
            address[] memory transferOwners3 = _getEthereumTransferOwners3();
            AirdropV4BannysEthereum3 migration3 = new AirdropV4BannysEthereum3(transferOwners3);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds3, address(migration3));
            migration3.requireMintedTokenIds(mintedTokenIds);
            migration3.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysEthereum3 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 4)) {
            uint16[] memory tierIds4 = new uint16[](42);

            // Add 20 instances of tier ID 4
            for (uint256 i = 0; i < 20; i++) {
                tierIds4[0 + i] = 4;
            }
            // Add 1 instances of tier ID 13
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[20 + i] = 13;
            }
            // Add 1 instances of tier ID 16
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[21 + i] = 16;
            }
            // Add 1 instances of tier ID 17
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[22 + i] = 17;
            }
            // Add 2 instances of tier ID 19
            for (uint256 i = 0; i < 2; i++) {
                tierIds4[23 + i] = 19;
            }
            // Add 4 instances of tier ID 23
            for (uint256 i = 0; i < 4; i++) {
                tierIds4[25 + i] = 23;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds4[29 + i] = 25;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[31 + i] = 31;
            }
            // Add 1 instances of tier ID 32
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[32 + i] = 32;
            }
            // Add 1 instances of tier ID 33
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[33 + i] = 33;
            }
            // Add 4 instances of tier ID 41
            for (uint256 i = 0; i < 4; i++) {
                tierIds4[34 + i] = 41;
            }
            // Add 1 instances of tier ID 42
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[38 + i] = 42;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[39 + i] = 43;
            }
            // Add 2 instances of tier ID 48
            for (uint256 i = 0; i < 2; i++) {
                tierIds4[40 + i] = 48;
            }
            address[] memory transferOwners4 = _getEthereumTransferOwners4();
            AirdropV4BannysEthereum4 migration4 = new AirdropV4BannysEthereum4(transferOwners4);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds4, address(migration4));
            migration4.requireMintedTokenIds(mintedTokenIds);
            migration4.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysEthereum4 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 5)) {
            uint16[] memory tierIds5 = new uint16[](44);

            // Add 20 instances of tier ID 4
            for (uint256 i = 0; i < 20; i++) {
                tierIds5[0 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[20 + i] = 5;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[21 + i] = 6;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[22 + i] = 10;
            }
            // Add 1 instances of tier ID 13
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[23 + i] = 13;
            }
            // Add 2 instances of tier ID 15
            for (uint256 i = 0; i < 2; i++) {
                tierIds5[24 + i] = 15;
            }
            // Add 1 instances of tier ID 18
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[26 + i] = 18;
            }
            // Add 3 instances of tier ID 19
            for (uint256 i = 0; i < 3; i++) {
                tierIds5[27 + i] = 19;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[30 + i] = 20;
            }
            // Add 1 instances of tier ID 23
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[31 + i] = 23;
            }
            // Add 1 instances of tier ID 26
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[32 + i] = 26;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[33 + i] = 28;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[34 + i] = 31;
            }
            // Add 1 instances of tier ID 35
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[35 + i] = 35;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[36 + i] = 38;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[37 + i] = 39;
            }
            // Add 1 instances of tier ID 40
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[38 + i] = 40;
            }
            // Add 2 instances of tier ID 44
            for (uint256 i = 0; i < 2; i++) {
                tierIds5[39 + i] = 44;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[41 + i] = 47;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[42 + i] = 48;
            }
            // Add 1 instances of tier ID 49
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[43 + i] = 49;
            }
            address[] memory transferOwners5 = _getEthereumTransferOwners5();
            AirdropV4BannysEthereum5 migration5 = new AirdropV4BannysEthereum5(transferOwners5);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds5, address(migration5));
            migration5.requireMintedTokenIds(mintedTokenIds);
            migration5.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysEthereum5 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 6)) {
            uint16[] memory tierIds6 = new uint16[](31);

            // Add 18 instances of tier ID 4
            for (uint256 i = 0; i < 18; i++) {
                tierIds6[0 + i] = 4;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[18 + i] = 6;
            }
            // Add 1 instances of tier ID 15
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[19 + i] = 15;
            }
            // Add 3 instances of tier ID 19
            for (uint256 i = 0; i < 3; i++) {
                tierIds6[20 + i] = 19;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[23 + i] = 25;
            }
            // Add 1 instances of tier ID 29
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[25 + i] = 29;
            }
            // Add 2 instances of tier ID 31
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[26 + i] = 31;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[28 + i] = 38;
            }
            // Add 2 instances of tier ID 43
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[29 + i] = 43;
            }
            address[] memory transferOwners6 = _getEthereumTransferOwners6();
            AirdropV4BannysEthereum6 migration6 = new AirdropV4BannysEthereum6(transferOwners6);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds6, address(migration6));
            migration6.requireMintedTokenIds(mintedTokenIds);
            migration6.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysEthereum6 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 7)) {
            uint16[] memory tierIds7 = new uint16[](141);

            // Add 2 instances of tier ID 5
            for (uint256 i = 0; i < 2; i++) {
                tierIds7[0 + i] = 5;
            }
            // Add 5 instances of tier ID 6
            for (uint256 i = 0; i < 5; i++) {
                tierIds7[2 + i] = 6;
            }
            // Add 7 instances of tier ID 10
            for (uint256 i = 0; i < 7; i++) {
                tierIds7[7 + i] = 10;
            }
            // Add 1 instances of tier ID 11
            for (uint256 i = 0; i < 1; i++) {
                tierIds7[14 + i] = 11;
            }
            // Add 2 instances of tier ID 13
            for (uint256 i = 0; i < 2; i++) {
                tierIds7[15 + i] = 13;
            }
            // Add 3 instances of tier ID 14
            for (uint256 i = 0; i < 3; i++) {
                tierIds7[17 + i] = 14;
            }
            // Add 3 instances of tier ID 17
            for (uint256 i = 0; i < 3; i++) {
                tierIds7[20 + i] = 17;
            }
            // Add 7 instances of tier ID 19
            for (uint256 i = 0; i < 7; i++) {
                tierIds7[23 + i] = 19;
            }
            // Add 6 instances of tier ID 20
            for (uint256 i = 0; i < 6; i++) {
                tierIds7[30 + i] = 20;
            }
            // Add 1 instances of tier ID 21
            for (uint256 i = 0; i < 1; i++) {
                tierIds7[36 + i] = 21;
            }
            // Add 2 instances of tier ID 23
            for (uint256 i = 0; i < 2; i++) {
                tierIds7[37 + i] = 23;
            }
            // Add 3 instances of tier ID 25
            for (uint256 i = 0; i < 3; i++) {
                tierIds7[39 + i] = 25;
            }
            // Add 2 instances of tier ID 26
            for (uint256 i = 0; i < 2; i++) {
                tierIds7[42 + i] = 26;
            }
            // Add 7 instances of tier ID 28
            for (uint256 i = 0; i < 7; i++) {
                tierIds7[44 + i] = 28;
            }
            // Add 1 instances of tier ID 29
            for (uint256 i = 0; i < 1; i++) {
                tierIds7[51 + i] = 29;
            }
            // Add 5 instances of tier ID 31
            for (uint256 i = 0; i < 5; i++) {
                tierIds7[52 + i] = 31;
            }
            // Add 2 instances of tier ID 32
            for (uint256 i = 0; i < 2; i++) {
                tierIds7[57 + i] = 32;
            }
            // Add 1 instances of tier ID 33
            for (uint256 i = 0; i < 1; i++) {
                tierIds7[59 + i] = 33;
            }
            // Add 3 instances of tier ID 35
            for (uint256 i = 0; i < 3; i++) {
                tierIds7[60 + i] = 35;
            }
            // Add 2 instances of tier ID 37
            for (uint256 i = 0; i < 2; i++) {
                tierIds7[63 + i] = 37;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds7[65 + i] = 39;
            }
            // Add 2 instances of tier ID 40
            for (uint256 i = 0; i < 2; i++) {
                tierIds7[66 + i] = 40;
            }
            // Add 1 instances of tier ID 41
            for (uint256 i = 0; i < 1; i++) {
                tierIds7[68 + i] = 41;
            }
            // Add 16 instances of tier ID 42
            for (uint256 i = 0; i < 16; i++) {
                tierIds7[69 + i] = 42;
            }
            // Add 11 instances of tier ID 43
            for (uint256 i = 0; i < 11; i++) {
                tierIds7[85 + i] = 43;
            }
            // Add 29 instances of tier ID 44
            for (uint256 i = 0; i < 29; i++) {
                tierIds7[96 + i] = 44;
            }
            // Add 12 instances of tier ID 47
            for (uint256 i = 0; i < 12; i++) {
                tierIds7[125 + i] = 47;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds7[137 + i] = 48;
            }
            // Add 3 instances of tier ID 49
            for (uint256 i = 0; i < 3; i++) {
                tierIds7[138 + i] = 49;
            }
            address[] memory transferOwners7 = _getEthereumTransferOwners7();
            AirdropV4BannysEthereum7 migration7 = new AirdropV4BannysEthereum7(transferOwners7);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds7, address(migration7));
            migration7.requireMintedTokenIds(mintedTokenIds);
            migration7.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysEthereum7 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 8)) {
            uint16[] memory tierIds8 = new uint16[](140);

            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds8[0 + i] = 10;
            }
            // Add 139 instances of tier ID 49
            for (uint256 i = 0; i < 139; i++) {
                tierIds8[1 + i] = 49;
            }
            address[] memory transferOwners8 = _getEthereumTransferOwners8();
            AirdropV4BannysEthereum8 migration8 = new AirdropV4BannysEthereum8(transferOwners8);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds8, address(migration8));
            migration8.requireMintedTokenIds(mintedTokenIds);
            migration8.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysEthereum8 migrated", mintedTokenIds.length, "tokens");
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
            AirdropV4BannysOptimism migration = new AirdropV4BannysOptimism(transferOwners);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds, address(migration));
            migration.requireMintedTokenIds(mintedTokenIds);
            migration.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysOptimism migrated", mintedTokenIds.length, "tokens");
        }
    }

    function _runBase() internal {
        JB721TiersHook hook = _v6Hook();
        address hookAddress = address(hook);
        address resolverAddress = _resolverOf(hook);
        bool verifyV4State = _shouldVerifyV4State();
        uint256 chunkFilter = _chunkFilter();
        uint256 maxChunkFilter = _maxChunkFilter();
        _requireValidChunkFilters(chunkFilter, maxChunkFilter, 6);

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 1)) {
            uint16[] memory tierIds1 = new uint16[](57);

            // Add 3 instances of tier ID 2
            for (uint256 i = 0; i < 3; i++) {
                tierIds1[0 + i] = 2;
            }
            // Add 10 instances of tier ID 3
            for (uint256 i = 0; i < 10; i++) {
                tierIds1[3 + i] = 3;
            }
            // Add 9 instances of tier ID 4
            for (uint256 i = 0; i < 9; i++) {
                tierIds1[13 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[22 + i] = 5;
            }
            // Add 4 instances of tier ID 6
            for (uint256 i = 0; i < 4; i++) {
                tierIds1[23 + i] = 6;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[27 + i] = 10;
            }
            // Add 1 instances of tier ID 11
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[28 + i] = 11;
            }
            // Add 2 instances of tier ID 14
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[29 + i] = 14;
            }
            // Add 2 instances of tier ID 15
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[31 + i] = 15;
            }
            // Add 4 instances of tier ID 19
            for (uint256 i = 0; i < 4; i++) {
                tierIds1[33 + i] = 19;
            }
            // Add 4 instances of tier ID 25
            for (uint256 i = 0; i < 4; i++) {
                tierIds1[37 + i] = 25;
            }
            // Add 4 instances of tier ID 28
            for (uint256 i = 0; i < 4; i++) {
                tierIds1[41 + i] = 28;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[45 + i] = 31;
            }
            // Add 1 instances of tier ID 32
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[46 + i] = 32;
            }
            // Add 1 instances of tier ID 33
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[47 + i] = 33;
            }
            // Add 2 instances of tier ID 37
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[48 + i] = 37;
            }
            // Add 1 instances of tier ID 40
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[50 + i] = 40;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[51 + i] = 43;
            }
            // Add 2 instances of tier ID 44
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[52 + i] = 44;
            }
            // Add 1 instances of tier ID 45
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[54 + i] = 45;
            }
            // Add 2 instances of tier ID 47
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[55 + i] = 47;
            }
            address[] memory transferOwners1 = _getBaseTransferOwners1();
            AirdropV4BannysBase1 migration1 = new AirdropV4BannysBase1(transferOwners1);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds1, address(migration1));
            migration1.requireMintedTokenIds(mintedTokenIds);
            migration1.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysBase1 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 2)) {
            uint16[] memory tierIds2 = new uint16[](22);

            // Add 22 instances of tier ID 4
            for (uint256 i = 0; i < 22; i++) {
                tierIds2[0 + i] = 4;
            }
            address[] memory transferOwners2 = _getBaseTransferOwners2();
            AirdropV4BannysBase2 migration2 = new AirdropV4BannysBase2(transferOwners2);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds2, address(migration2));
            migration2.requireMintedTokenIds(mintedTokenIds);
            migration2.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysBase2 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 3)) {
            uint16[] memory tierIds3 = new uint16[](34);

            // Add 22 instances of tier ID 4
            for (uint256 i = 0; i < 22; i++) {
                tierIds3[0 + i] = 4;
            }
            // Add 3 instances of tier ID 10
            for (uint256 i = 0; i < 3; i++) {
                tierIds3[22 + i] = 10;
            }
            // Add 1 instances of tier ID 14
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[25 + i] = 14;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[26 + i] = 19;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[27 + i] = 25;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[28 + i] = 28;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[29 + i] = 31;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[30 + i] = 38;
            }
            // Add 2 instances of tier ID 43
            for (uint256 i = 0; i < 2; i++) {
                tierIds3[31 + i] = 43;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[33 + i] = 47;
            }
            address[] memory transferOwners3 = _getBaseTransferOwners3();
            AirdropV4BannysBase3 migration3 = new AirdropV4BannysBase3(transferOwners3);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds3, address(migration3));
            migration3.requireMintedTokenIds(mintedTokenIds);
            migration3.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysBase3 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 4)) {
            uint16[] memory tierIds4 = new uint16[](27);

            // Add 22 instances of tier ID 4
            for (uint256 i = 0; i < 22; i++) {
                tierIds4[0 + i] = 4;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[22 + i] = 10;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[23 + i] = 19;
            }
            // Add 2 instances of tier ID 25
            for (uint256 i = 0; i < 2; i++) {
                tierIds4[24 + i] = 25;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[26 + i] = 43;
            }
            address[] memory transferOwners4 = _getBaseTransferOwners4();
            AirdropV4BannysBase4 migration4 = new AirdropV4BannysBase4(transferOwners4);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds4, address(migration4));
            migration4.requireMintedTokenIds(mintedTokenIds);
            migration4.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysBase4 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 5)) {
            uint16[] memory tierIds5 = new uint16[](35);

            // Add 19 instances of tier ID 4
            for (uint256 i = 0; i < 19; i++) {
                tierIds5[0 + i] = 4;
            }
            // Add 2 instances of tier ID 5
            for (uint256 i = 0; i < 2; i++) {
                tierIds5[19 + i] = 5;
            }
            // Add 1 instances of tier ID 13
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[21 + i] = 13;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[22 + i] = 19;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[23 + i] = 20;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[24 + i] = 25;
            }
            // Add 1 instances of tier ID 27
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[25 + i] = 27;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[26 + i] = 28;
            }
            // Add 1 instances of tier ID 35
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[27 + i] = 35;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[28 + i] = 38;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[29 + i] = 39;
            }
            // Add 1 instances of tier ID 41
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[30 + i] = 41;
            }
            // Add 2 instances of tier ID 43
            for (uint256 i = 0; i < 2; i++) {
                tierIds5[31 + i] = 43;
            }
            // Add 1 instances of tier ID 44
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[33 + i] = 44;
            }
            // Add 1 instances of tier ID 48
            for (uint256 i = 0; i < 1; i++) {
                tierIds5[34 + i] = 48;
            }
            address[] memory transferOwners5 = _getBaseTransferOwners5();
            AirdropV4BannysBase5 migration5 = new AirdropV4BannysBase5(transferOwners5);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds5, address(migration5));
            migration5.requireMintedTokenIds(mintedTokenIds);
            migration5.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysBase5 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 6)) {
            uint16[] memory tierIds6 = new uint16[](53);

            // Add 2 instances of tier ID 5
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[0 + i] = 5;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[2 + i] = 6;
            }
            // Add 1 instances of tier ID 7
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[3 + i] = 7;
            }
            // Add 6 instances of tier ID 10
            for (uint256 i = 0; i < 6; i++) {
                tierIds6[4 + i] = 10;
            }
            // Add 2 instances of tier ID 11
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[10 + i] = 11;
            }
            // Add 1 instances of tier ID 13
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[12 + i] = 13;
            }
            // Add 1 instances of tier ID 14
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[13 + i] = 14;
            }
            // Add 1 instances of tier ID 17
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[14 + i] = 17;
            }
            // Add 5 instances of tier ID 19
            for (uint256 i = 0; i < 5; i++) {
                tierIds6[15 + i] = 19;
            }
            // Add 1 instances of tier ID 24
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[20 + i] = 24;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[21 + i] = 25;
            }
            // Add 4 instances of tier ID 28
            for (uint256 i = 0; i < 4; i++) {
                tierIds6[22 + i] = 28;
            }
            // Add 4 instances of tier ID 31
            for (uint256 i = 0; i < 4; i++) {
                tierIds6[26 + i] = 31;
            }
            // Add 1 instances of tier ID 32
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[30 + i] = 32;
            }
            // Add 1 instances of tier ID 34
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[31 + i] = 34;
            }
            // Add 3 instances of tier ID 35
            for (uint256 i = 0; i < 3; i++) {
                tierIds6[32 + i] = 35;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[35 + i] = 38;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[36 + i] = 39;
            }
            // Add 2 instances of tier ID 40
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[37 + i] = 40;
            }
            // Add 1 instances of tier ID 41
            for (uint256 i = 0; i < 1; i++) {
                tierIds6[39 + i] = 41;
            }
            // Add 2 instances of tier ID 42
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[40 + i] = 42;
            }
            // Add 2 instances of tier ID 43
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[42 + i] = 43;
            }
            // Add 2 instances of tier ID 44
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[44 + i] = 44;
            }
            // Add 5 instances of tier ID 47
            for (uint256 i = 0; i < 5; i++) {
                tierIds6[46 + i] = 47;
            }
            // Add 2 instances of tier ID 49
            for (uint256 i = 0; i < 2; i++) {
                tierIds6[51 + i] = 49;
            }
            address[] memory transferOwners6 = _getBaseTransferOwners6();
            AirdropV4BannysBase6 migration6 = new AirdropV4BannysBase6(transferOwners6);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds6, address(migration6));
            migration6.requireMintedTokenIds(mintedTokenIds);
            migration6.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysBase6 migrated", mintedTokenIds.length, "tokens");
        }
    }

    function _runArbitrum() internal {
        JB721TiersHook hook = _v6Hook();
        address hookAddress = address(hook);
        address resolverAddress = _resolverOf(hook);
        bool verifyV4State = _shouldVerifyV4State();
        uint256 chunkFilter = _chunkFilter();
        uint256 maxChunkFilter = _maxChunkFilter();
        _requireValidChunkFilters(chunkFilter, maxChunkFilter, 4);

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 1)) {
            uint16[] memory tierIds1 = new uint16[](9);

            // Add 2 instances of tier ID 3
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[0 + i] = 3;
            }
            // Add 2 instances of tier ID 4
            for (uint256 i = 0; i < 2; i++) {
                tierIds1[2 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[4 + i] = 5;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[5 + i] = 19;
            }
            // Add 1 instances of tier ID 25
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[6 + i] = 25;
            }
            // Add 1 instances of tier ID 38
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[7 + i] = 38;
            }
            // Add 1 instances of tier ID 47
            for (uint256 i = 0; i < 1; i++) {
                tierIds1[8 + i] = 47;
            }
            address[] memory transferOwners1 = _getArbitrumTransferOwners1();
            AirdropV4BannysArbitrum1 migration1 = new AirdropV4BannysArbitrum1(transferOwners1);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds1, address(migration1));
            migration1.requireMintedTokenIds(mintedTokenIds);
            migration1.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysArbitrum1 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 2)) {
            uint16[] memory tierIds2 = new uint16[](12);

            // Add 4 instances of tier ID 4
            for (uint256 i = 0; i < 4; i++) {
                tierIds2[0 + i] = 4;
            }
            // Add 1 instances of tier ID 6
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[4 + i] = 6;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[5 + i] = 10;
            }
            // Add 1 instances of tier ID 11
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[6 + i] = 11;
            }
            // Add 1 instances of tier ID 19
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[7 + i] = 19;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[8 + i] = 20;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[9 + i] = 28;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[10 + i] = 31;
            }
            // Add 1 instances of tier ID 49
            for (uint256 i = 0; i < 1; i++) {
                tierIds2[11 + i] = 49;
            }
            address[] memory transferOwners2 = _getArbitrumTransferOwners2();
            AirdropV4BannysArbitrum2 migration2 = new AirdropV4BannysArbitrum2(transferOwners2);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds2, address(migration2));
            migration2.requireMintedTokenIds(mintedTokenIds);
            migration2.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysArbitrum2 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 3)) {
            uint16[] memory tierIds3 = new uint16[](8);

            // Add 3 instances of tier ID 4
            for (uint256 i = 0; i < 3; i++) {
                tierIds3[0 + i] = 4;
            }
            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[3 + i] = 5;
            }
            // Add 1 instances of tier ID 10
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[4 + i] = 10;
            }
            // Add 1 instances of tier ID 20
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[5 + i] = 20;
            }
            // Add 1 instances of tier ID 28
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[6 + i] = 28;
            }
            // Add 1 instances of tier ID 43
            for (uint256 i = 0; i < 1; i++) {
                tierIds3[7 + i] = 43;
            }
            address[] memory transferOwners3 = _getArbitrumTransferOwners3();
            AirdropV4BannysArbitrum3 migration3 = new AirdropV4BannysArbitrum3(transferOwners3);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds3, address(migration3));
            migration3.requireMintedTokenIds(mintedTokenIds);
            migration3.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysArbitrum3 migrated", mintedTokenIds.length, "tokens");
        }

        if (_shouldRunChunk(chunkFilter, maxChunkFilter, 4)) {
            uint16[] memory tierIds4 = new uint16[](176);

            // Add 1 instances of tier ID 5
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[0 + i] = 5;
            }
            // Add 2 instances of tier ID 19
            for (uint256 i = 0; i < 2; i++) {
                tierIds4[1 + i] = 19;
            }
            // Add 1 instances of tier ID 31
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[3 + i] = 31;
            }
            // Add 1 instances of tier ID 32
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[4 + i] = 32;
            }
            // Add 1 instances of tier ID 39
            for (uint256 i = 0; i < 1; i++) {
                tierIds4[5 + i] = 39;
            }
            // Add 26 instances of tier ID 47
            for (uint256 i = 0; i < 26; i++) {
                tierIds4[6 + i] = 47;
            }
            // Add 144 instances of tier ID 49
            for (uint256 i = 0; i < 144; i++) {
                tierIds4[32 + i] = 49;
            }
            address[] memory transferOwners4 = _getArbitrumTransferOwners4();
            AirdropV4BannysArbitrum4 migration4 = new AirdropV4BannysArbitrum4(transferOwners4);
            uint256[] memory mintedTokenIds = hook.mintFor(tierIds4, address(migration4));
            migration4.requireMintedTokenIds(mintedTokenIds);
            migration4.executeMigration(
                hookAddress,
                resolverAddress,
                V4_HOOK,
                V4_RESOLVER,
                V4_RESOLVER_FALLBACK,
                verifyV4State
            );
            console.log("AirdropV4BannysArbitrum4 migrated", mintedTokenIds.length, "tokens");
        }
    }


    function _getEthereumTransferOwners1() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](20);
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
        return transferOwners;
    }

    function _getEthereumTransferOwners2() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](20);
        transferOwners[0] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        transferOwners[1] = 0x79d1E7F1A6E0Bbb3278a9d2B782e3A8983444cb6;
        transferOwners[2] = 0x546B4A7A30b3193Badf70E1d43D8142928F3db0b;
        transferOwners[3] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[4] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[5] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[6] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[7] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[8] = 0x7D0068d0D8fC2Aa15d897448B348Fa9B30f6d4c9;
        transferOwners[9] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[10] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        transferOwners[11] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        transferOwners[12] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[13] = 0x961d4191965C49537c88F764D88318872CE405bE;
        transferOwners[14] = 0x21a8f5A6bF893D43d3964dDaf4E04766BBBE9b07;
        transferOwners[15] = 0x7a16eABD1413Bfd468aE9fEBF7C26c62f1fFdc59;
        transferOwners[16] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[17] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[18] = 0xa13d49fCbf79EAF6A0a58cBDD3361422DB4eAfF1;
        transferOwners[19] = 0xe7879a2D05dBA966Fcca34EE9C3F99eEe7eDEFd1;
        return transferOwners;
    }

    function _getEthereumTransferOwners3() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](20);
        transferOwners[0] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        transferOwners[1] = 0x5706d5aD7A68bf8692bD341234bE44ca7Bf2f654;
        transferOwners[2] = 0x679d87D8640e66778c3419D164998E720D7495f6;
        transferOwners[3] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        transferOwners[4] = 0x4A290F18c35bBFE97B2557cf765De9387726dE39;
        transferOwners[5] = 0x25171bD3cD3231c3057c96F38E32E3bA6681497a;
        transferOwners[6] = 0xa7226e53F3100C093A0a5BCb6E3D0976EB3db1D6;
        transferOwners[7] = 0x76A6D08b82034b397E7e09dAe4377C18F132BbB8;
        transferOwners[8] = 0x809C9f8dd8CA93A41c3adca4972Fa234C28F7714;
        transferOwners[9] = 0x809C9f8dd8CA93A41c3adca4972Fa234C28F7714;
        transferOwners[10] = 0x126eeFa566ABF5aC3EfDAeF52d79E962CFFdB448;
        transferOwners[11] = 0x77fb4fa1ABA92576942aD34BC47834059b84e693;
        transferOwners[12] = 0x08cEb8Bba685ee708C9c4c65576837cbE19B9dea;
        transferOwners[13] = 0x690C01b4b1389D9D9265820F77DCbD2A6Ad04e6c;
        transferOwners[14] = 0x690C01b4b1389D9D9265820F77DCbD2A6Ad04e6c;
        transferOwners[15] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[16] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[17] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[18] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[19] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        return transferOwners;
    }

    function _getEthereumTransferOwners4() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](20);
        transferOwners[0] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[1] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[2] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[3] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[4] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[5] = 0x5A00e8683f37e8B08C744054a0EF606a18b1aEF7;
        transferOwners[6] = 0x59E98040E53d7dC1900B4daf36D9Fbbd4a8f1dA2;
        transferOwners[7] = 0x59E98040E53d7dC1900B4daf36D9Fbbd4a8f1dA2;
        transferOwners[8] = 0x59E98040E53d7dC1900B4daf36D9Fbbd4a8f1dA2;
        transferOwners[9] = 0x46f3cC6a1c00A5cD8864d2B92f128196CAE07D15;
        transferOwners[10] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[11] = 0x381CC779761212344f8400373a994d29E17522c6;
        transferOwners[12] = 0x849151d7D0bF1F34b70d5caD5149D28CC2308bf1;
        transferOwners[13] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[14] = 0x63A2368F4B509438ca90186cb1C15156713D5834;
        transferOwners[15] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[16] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[17] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[18] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        transferOwners[19] = 0x95E9A0c113AA9931a4230f91AdE08A491D3f8d54;
        return transferOwners;
    }

    function _getEthereumTransferOwners5() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](20);
        transferOwners[0] = 0xf32dd1Bd55bD14d929218499a2E7D106F72f79c7;
        transferOwners[1] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[2] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[3] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[4] = 0x80581C6e88Ce00095F85cdf24bB760f16d6eC0D6;
        transferOwners[5] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[6] = 0x30670D81E487c80b9EDc54370e6EaF943B6EAB39;
        transferOwners[7] = 0x60535A6605958fFf6cEC5B1e92892601EFb3473b;
        transferOwners[8] = 0x34724D71cE674FcD4d06e60Dd1BaA88c14D36b75;
        transferOwners[9] = 0xA99c384f43e72B65BB51fE33b85CE12A32C09526;
        transferOwners[10] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        transferOwners[11] = 0x898e24EBC9dAf5a9930f10def8B6a373F859C101;
        transferOwners[12] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[13] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[14] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[15] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[16] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[17] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[18] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[19] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        return transferOwners;
    }

    function _getEthereumTransferOwners6() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](18);
        transferOwners[0] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[1] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[2] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[3] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[4] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[5] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[6] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[7] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[8] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[9] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[10] = 0xAAeD9fFF9858d48925904E391B77892BA5Fda824;
        transferOwners[11] = 0x2feb329b9289b60064904Fa61Fc347157a5AEd6a;
        transferOwners[12] = 0xDfd60a8E1e17FBb78E8CA332906A822D862f3D57;
        transferOwners[13] = 0xBD07B7Ab42cE411A752DB600604ECA7fE5501947;
        transferOwners[14] = 0x9f729294b308f79243285348A7Be3f58ae5ED31A;
        transferOwners[15] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[16] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        transferOwners[17] = 0x5138a42C3D5065debE950deBDa10C1f38150a908;
        return transferOwners;
    }

    function _getEthereumTransferOwners7() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](141);
        transferOwners[0] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[1] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[2] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[3] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[4] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[5] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[6] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[7] = 0x4A290F18c35bBFE97B2557cf765De9387726dE39;
        transferOwners[8] = 0xf0FE43a75Ff248FD2E75D33fa1ebde71c6d1abAd;
        transferOwners[9] = 0x7044d88283c8FFF0679b711C0cd81f1a6754C843;
        transferOwners[10] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[11] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[12] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[13] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[14] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[15] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[16] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[17] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        transferOwners[18] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[19] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[20] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[21] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[22] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[23] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        transferOwners[24] = 0x516cAfD745Ec780D20f61c0d71fe258eA765222D;
        transferOwners[25] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[26] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        transferOwners[27] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[28] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[29] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[30] = 0x289715fFBB2f4b482e2917D2f183FeAb564ec84F;
        transferOwners[31] = 0x79d1E7F1A6E0Bbb3278a9d2B782e3A8983444cb6;
        transferOwners[32] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[33] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[34] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[35] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[36] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[37] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[38] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[39] = 0xe7879a2D05dBA966Fcca34EE9C3F99eEe7eDEFd1;
        transferOwners[40] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[41] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[42] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[43] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        transferOwners[44] = 0x21a8f5A6bF893D43d3964dDaf4E04766BBBE9b07;
        transferOwners[45] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        transferOwners[46] = 0x87084347AeBADc626e8569E0D386928dade2ba09;
        transferOwners[47] = 0x7bE8c264c9DCebA3A35990c78d5C4220D8724B6e;
        transferOwners[48] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[49] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[50] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[51] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[52] = 0x7a16eABD1413Bfd468aE9fEBF7C26c62f1fFdc59;
        transferOwners[53] = 0xf0FE43a75Ff248FD2E75D33fa1ebde71c6d1abAd;
        transferOwners[54] = 0x08cEb8Bba685ee708C9c4c65576837cbE19B9dea;
        transferOwners[55] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[56] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[57] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[58] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[59] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[60] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[61] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[62] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[63] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[64] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[65] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[66] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[67] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        transferOwners[68] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        transferOwners[69] = 0x961d4191965C49537c88F764D88318872CE405bE;
        transferOwners[70] = 0xf0FE43a75Ff248FD2E75D33fa1ebde71c6d1abAd;
        transferOwners[71] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[72] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[73] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[74] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[75] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[76] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[77] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[78] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[79] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[80] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[81] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[82] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[83] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[84] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[85] = 0x21a8f5A6bF893D43d3964dDaf4E04766BBBE9b07;
        transferOwners[86] = 0xe7879a2D05dBA966Fcca34EE9C3F99eEe7eDEFd1;
        transferOwners[87] = 0x1786D033D5CbCC235B673e872c7613c2F83DA583;
        transferOwners[88] = 0x1Ae766cc5947e1E4C3538EE1F3f47063D2B40E79;
        transferOwners[89] = 0x4A8a9147ab0DF5A8949f964bDBA22dc4583280E2;
        transferOwners[90] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[91] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[92] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[93] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[94] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[95] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[96] = 0x4A290F18c35bBFE97B2557cf765De9387726dE39;
        transferOwners[97] = 0x38EED3CCeED88f380E436eb21811250797c453C5;
        transferOwners[98] = 0xa9d20b435A85fAAa002f32d66F7D21564130E9cf;
        transferOwners[99] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[100] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[101] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[102] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[103] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[104] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[105] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[106] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[107] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[108] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[109] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[110] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[111] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[112] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[113] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[114] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[115] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[116] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[117] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[118] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[119] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[120] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[121] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[122] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[123] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[124] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[125] = 0x7a16eABD1413Bfd468aE9fEBF7C26c62f1fFdc59;
        transferOwners[126] = 0x0447AD1BdC0fFA06f7029c8E63F4De21E65255d2;
        transferOwners[127] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[128] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[129] = 0xe21A272c4D22eD40678a0168b4acd006bca8A482;
        transferOwners[130] = 0x45C3d8Aacc0d537dAc234AD4C20Ef05d6041CeFe;
        transferOwners[131] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[132] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[133] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[134] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[135] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[136] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        transferOwners[137] = 0x15b61e9b0637f45dc0858f083cd240267924125d;
        transferOwners[138] = 0x08cF1208e638a5A3623be58d600e35c6199baa9C;
        transferOwners[139] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[140] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        return transferOwners;
    }

    function _getEthereumTransferOwners8() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](140);
        transferOwners[0] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[1] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[2] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[3] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[4] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[5] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[6] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[7] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[8] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[9] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[10] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[11] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[12] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[13] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[14] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
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
        transferOwners[43] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[44] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[45] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[46] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[47] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[48] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[49] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[50] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[51] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[52] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[53] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[54] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[55] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[56] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[57] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[58] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[59] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[60] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[61] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[62] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[63] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[64] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[65] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[66] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[67] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
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
        transferOwners[138] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        transferOwners[139] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
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

    function _getBaseTransferOwners1() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](22);
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
        return transferOwners;
    }

    function _getBaseTransferOwners2() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](22);
        transferOwners[0] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[1] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[2] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[3] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[4] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[5] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[6] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[7] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[8] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[9] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[10] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[11] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[12] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[13] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[14] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[15] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[16] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[17] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[18] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[19] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[20] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[21] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        return transferOwners;
    }

    function _getBaseTransferOwners3() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](22);
        transferOwners[0] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[1] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[2] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[3] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[4] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[5] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[6] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[7] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[8] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[9] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[10] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[11] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[12] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[13] = 0x67BcBE602e870e2286C19E4E0044E583967c9665;
        transferOwners[14] = 0x18deEE9699526f8C8a87004b2e4e55029Fb26b9a;
        transferOwners[15] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        transferOwners[16] = 0xAcD59e854adf632d2322404198624F757C868C97;
        transferOwners[17] = 0xAcD59e854adf632d2322404198624F757C868C97;
        transferOwners[18] = 0xa13d49fCbf79EAF6A0a58cBDD3361422DB4eAfF1;
        transferOwners[19] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[20] = 0xbeC26FFa12c90217943D1b2958f60A821aE6E549;
        transferOwners[21] = 0x8Ec174c5d86469D1A74094E10485357eBFe2e08e;
        return transferOwners;
    }

    function _getBaseTransferOwners4() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](22);
        transferOwners[0] = 0xC5704f77f94087CC644d361A5A57295851d242aB;
        transferOwners[1] = 0x99Fa48ccEa8a38CDE6B437450fF9bBdDAFAA4Fc8;
        transferOwners[2] = 0xb6ECb51e3638Eb7aa0C6289ef058DCa27494Acb2;
        transferOwners[3] = 0x57700212B1cB7b67bD7DF3801DA43CA634513fE0;
        transferOwners[4] = 0x57700212B1cB7b67bD7DF3801DA43CA634513fE0;
        transferOwners[5] = 0x9342E2aC6dd4A907948E91E80D2734ecAC1D70eC;
        transferOwners[6] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[7] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[8] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[9] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[10] = 0x96D087aba8552A0e111D7fB4Feb2e7621213E244;
        transferOwners[11] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[12] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[13] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[14] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[15] = 0x2830e21792019CE670fBc548AacB004b08c7f71f;
        transferOwners[16] = 0x46f3cC6a1c00A5cD8864d2B92f128196CAE07D15;
        transferOwners[17] = 0x8e2B25dF2484000B9127b2D2F8E92079dcEE3E48;
        transferOwners[18] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;
        transferOwners[19] = 0x224aBa5D489675a7bD3CE07786FAda466b46FA0F;
        transferOwners[20] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[21] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        return transferOwners;
    }

    function _getBaseTransferOwners5() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](19);
        transferOwners[0] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[1] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[2] = 0x29f4aE3c24681940E537f72830b4Fe4076bDF9fe;
        transferOwners[3] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[4] = 0x3c2736f995535b5a755F3CE2BEb754362820671e;
        transferOwners[5] = 0x6877be9E00d0bc5886c28419901E8cC98C1c2739;
        transferOwners[6] = 0x8DFBdEEC8c5d4970BB5F481C6ec7f73fa1C65be5;
        transferOwners[7] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[8] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[9] = 0x39a7B6fa1597BB6657Fe84e64E3B836c37d6F75d;
        transferOwners[10] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[11] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[12] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[13] = 0xDdB4938755C243a4f60a2f2f8f95dF4F894c58Cc;
        transferOwners[14] = 0x34aA3F359A9D614239015126635CE7732c18fDF3;
        transferOwners[15] = 0x34aA3F359A9D614239015126635CE7732c18fDF3;
        transferOwners[16] = 0x34aA3F359A9D614239015126635CE7732c18fDF3;
        transferOwners[17] = 0xF6cC71878e23c05406B35946CD9d378E0f2f4f2F;
        transferOwners[18] = 0xd2e44E40B5FB960A8A74dD7B9D6b7f14B805b50d;
        return transferOwners;
    }

    function _getBaseTransferOwners6() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](53);
        transferOwners[0] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[1] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[2] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[3] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[4] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        transferOwners[5] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[6] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[7] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[8] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[9] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[10] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[11] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[12] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[13] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[14] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[15] = 0x18deEE9699526f8C8a87004b2e4e55029Fb26b9a;
        transferOwners[16] = 0xbeC26FFa12c90217943D1b2958f60A821aE6E549;
        transferOwners[17] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[18] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[19] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[20] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[21] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        transferOwners[22] = 0x18deEE9699526f8C8a87004b2e4e55029Fb26b9a;
        transferOwners[23] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[24] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[25] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[26] = 0x99Fa48ccEa8a38CDE6B437450fF9bBdDAFAA4Fc8;
        transferOwners[27] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[28] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[29] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[30] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[31] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        transferOwners[32] = 0x565B93a15d38aCD79c120b15432D21E21eD274d6;
        transferOwners[33] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[34] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[35] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        transferOwners[36] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[37] = 0x8DFBdEEC8c5d4970BB5F481C6ec7f73fa1C65be5;
        transferOwners[38] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[39] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[40] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[41] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[42] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[43] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        transferOwners[44] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[45] = 0xbeC26FFa12c90217943D1b2958f60A821aE6E549;
        transferOwners[46] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        transferOwners[47] = 0x99Fa48ccEa8a38CDE6B437450fF9bBdDAFAA4Fc8;
        transferOwners[48] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[49] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[50] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        transferOwners[51] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        transferOwners[52] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        return transferOwners;
    }

    function _getArbitrumTransferOwners1() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](4);
        transferOwners[0] = 0x2aa64E6d80390F5C017F0313cB908051BE2FD35e;
        transferOwners[1] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[2] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[3] = 0xfD282d9f4d06C4BDc6a41af1Ae920A0AD70D18a3;
        return transferOwners;
    }

    function _getArbitrumTransferOwners2() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](4);
        transferOwners[0] = 0x08B3e694caA2F1fcF8eF71095CED1326f3454B89;
        transferOwners[1] = 0x9fDf876a50EA8f95017dCFC7709356887025B5BB;
        transferOwners[2] = 0x187089B33E5812310Ed32A57F53B3fAD0383a19D;
        transferOwners[3] = 0xc6404f24DB2f573F07F3A60758765caad198c0c3;
        return transferOwners;
    }

    function _getArbitrumTransferOwners3() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](3);
        transferOwners[0] = 0xB2d3900807094D4Fe47405871B0C8AdB58E10D42;
        transferOwners[1] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[2] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        return transferOwners;
    }

    function _getArbitrumTransferOwners4() internal pure returns (address[] memory) {
        address[] memory transferOwners = new address[](176);
        transferOwners[0] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[1] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
        transferOwners[2] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[3] = 0x57a482EA32c7F75A9C0734206f5BD4f9BCb38e12;
        transferOwners[4] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[5] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[6] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[7] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[8] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[9] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[10] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[11] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[12] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[13] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
        transferOwners[14] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
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
        transferOwners[32] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;
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
        transferOwners[43] = 0x7C3F14075F6477fea1aF6cf59f325afDfcD3Ddf7;
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
        return transferOwners;
    }


}
