// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

contract AirdropV4BannysGenerationTest is Test {
    uint256 private constant _CHUNK_COUNT = 19;
    uint256 private constant _BODY_COUNT = 241;

    function testTopLevelUsesSphinxOperatorMintOnly() public view {
        string memory script = vm.readFile("script/AirdropV4Bannys.s.sol");

        assertEq(_countOccurrences(script, "hook.mintFor("), _CHUNK_COUNT, "unexpected operator mint count");
        assertEq(_countOccurrences(script, "_mintViaPay"), 0, "pay mint helper should not be present");
        assertEq(_countOccurrences(script, "IJBTerminal"), 0, "terminal dependency should not be present");
        assertEq(_countOccurrences(script, "JBMetadataResolver"), 0, "pay metadata dependency should not be present");
        assertEq(_countOccurrences(script, "vm.startBroadcast()"), 0, "script should run through Sphinx");
        assertTrue(
            _contains(script, "import {Sphinx} from \"@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol\";"),
            "Sphinx import missing"
        );
        assertTrue(_contains(script, "contract AirdropV4BannysScript is Script, Sphinx"), "Sphinx inheritance missing");
        assertTrue(
            _contains(script, "vm.envOr(\"BANNY_AIRDROP_SPHINX_PROJECT\", string(\"banny-core\"))"),
            "Sphinx project mismatch"
        );
        assertTrue(
            _contains(
                script,
                "sphinxConfig.testnets = [\"ethereum_sepolia\", \"optimism_sepolia\", \"base_sepolia\", \"arbitrum_sepolia\"]"
            ),
            "Sphinx testnet config missing"
        );
        assertTrue(_contains(script, "function run() public {"), "plain run entry missing");
        assertTrue(_contains(script, "function deploy() public sphinx"), "Sphinx deploy modifier missing");
        assertTrue(_contains(script, "JB721TiersHook__ProjectBAN"), "deploy-all-v6 hook artifact missing");
        assertTrue(_contains(script, "BANNY_AIRDROP_DEPLOYMENTS_PATH"), "deployment path override missing");
        assertTrue(_contains(script, "../deploy-all-v6/deployments/"), "deploy-all-v6 default path missing");
        assertTrue(_contains(script, "V6_MAINNET_HOOK"), "mainnet hook guard missing");
        assertTrue(_contains(script, "0x37e35937ecF949d7a44a9Fe878107DE264618B8f"), "V6 hook address missing");
        assertTrue(_contains(script, "0xfF80c37a57016EFf3d19fb286e9C740eC4537Dd3"), "fallback resolver missing");
    }

    function testTopLevelMapsTestnetsToMainnetSourcePlans() public view {
        string memory script = vm.readFile("script/AirdropV4Bannys.s.sol");

        assertTrue(_contains(script, "chainId == 1 || chainId == 11155111"), "Ethereum Sepolia missing");
        assertTrue(_contains(script, "chainId == 10 || chainId == 11155420"), "OP Sepolia missing");
        assertTrue(_contains(script, "chainId == 8453 || chainId == 84532"), "Base Sepolia missing");
        assertTrue(_contains(script, "chainId == 42161 || chainId == 421614"), "Arbitrum Sepolia missing");
        assertTrue(_contains(script, "if (block.chainid == 11155111) return \"sepolia\""), "Sepolia folder missing");
        assertTrue(
            _contains(script, "if (block.chainid == 11155420) return \"optimism_sepolia\""), "OP Sepolia folder missing"
        );
        assertTrue(
            _contains(script, "if (block.chainid == 84532) return \"base_sepolia\""), "Base Sepolia folder missing"
        );
        assertTrue(
            _contains(script, "if (block.chainid == 421614) return \"arbitrum_sepolia\""),
            "Arbitrum Sepolia folder missing"
        );
        assertTrue(_contains(script, "function _shouldVerifyV4State() internal view returns (bool)"), "V4 mode missing");
    }

    function testEveryGeneratedChunkChecksMintedTokenIds() public view {
        string[_CHUNK_COUNT] memory files = _chunkFiles();

        for (uint256 i; i < files.length; i++) {
            string memory chunk = vm.readFile(files[i]);
            assertEq(
                _countOccurrences(chunk, "function requireMintedTokenIds"),
                1,
                string.concat(files[i], " missing minted token check")
            );
            assertEq(
                _countOccurrences(chunk, "function executeMigration"), 1, string.concat(files[i], " execute count")
            );
        }
    }

    function testEveryRawBodyIsVerifiedAgainstV4Resolvers() public view {
        string[_CHUNK_COUNT] memory files = _chunkFiles();
        uint256 verifyCount;
        uint256 bodyGuardCount;

        for (uint256 i; i < files.length; i++) {
            string memory chunk = vm.readFile(files[i]);
            verifyCount += _countOccurrences(chunk, "MigrationHelper.verifyV4AssetMatch(");
            bodyGuardCount += _countOccurrences(chunk, "Body token ID changed");
        }

        assertEq(verifyCount, _BODY_COUNT, "every V4 body should be resolver-verified");
        assertEq(bodyGuardCount, _BODY_COUNT, "every V4 body should preserve its token id");
    }

    function testStandaloneChunksHandleFallbackResolverOwnership() public view {
        string[4] memory files = [
            "script/AirdropV4BannysEthereum7.sol",
            "script/AirdropV4BannysEthereum8.sol",
            "script/AirdropV4BannysBase6.sol",
            "script/AirdropV4BannysArbitrum4.sol"
        ];

        for (uint256 i; i < files.length; i++) {
            string memory chunk = vm.readFile(files[i]);
            assertTrue(_contains(chunk, "v4Owner == address(fallbackV4ResolverAddress)"), files[i]);
            assertTrue(_contains(chunk, "Token owned by main resolver in V4 - should not be standalone"), files[i]);
        }
    }

    function testResolverStrandedItemTransfersLooseToBodyOwner() public view {
        string memory script = vm.readFile("script/AirdropV4Bannys.s.sol");
        string memory chunk = vm.readFile("script/AirdropV4BannysEthereum8.sol");

        assertTrue(
            _contains(script, "transferOwners[139] = 0x817738DC393d682Ca5fBb268707b99F2aAe96baE;"),
            "body owner should receive the loose item"
        );
        assertTrue(_contains(chunk, "targetTokenIds[139] = 10000000014; // V4 10000000003"), "target id missing");
        assertTrue(_contains(chunk, "v4TokenIds[139] = 10000000003; // V4 10000000003"), "v4 id missing");
        assertTrue(_contains(chunk, "allowResolverOwners[139] = true;"), "resolver allowance missing");
    }

    function _chunkFiles() private pure returns (string[_CHUNK_COUNT] memory files) {
        files[0] = "script/AirdropV4BannysEthereum1.sol";
        files[1] = "script/AirdropV4BannysEthereum2.sol";
        files[2] = "script/AirdropV4BannysEthereum3.sol";
        files[3] = "script/AirdropV4BannysEthereum4.sol";
        files[4] = "script/AirdropV4BannysEthereum5.sol";
        files[5] = "script/AirdropV4BannysEthereum6.sol";
        files[6] = "script/AirdropV4BannysEthereum7.sol";
        files[7] = "script/AirdropV4BannysEthereum8.sol";
        files[8] = "script/AirdropV4BannysOptimism.sol";
        files[9] = "script/AirdropV4BannysBase1.sol";
        files[10] = "script/AirdropV4BannysBase2.sol";
        files[11] = "script/AirdropV4BannysBase3.sol";
        files[12] = "script/AirdropV4BannysBase4.sol";
        files[13] = "script/AirdropV4BannysBase5.sol";
        files[14] = "script/AirdropV4BannysBase6.sol";
        files[15] = "script/AirdropV4BannysArbitrum1.sol";
        files[16] = "script/AirdropV4BannysArbitrum2.sol";
        files[17] = "script/AirdropV4BannysArbitrum3.sol";
        files[18] = "script/AirdropV4BannysArbitrum4.sol";
    }

    function _contains(string memory haystack, string memory needle) private pure returns (bool) {
        return _countOccurrences(haystack, needle) > 0;
    }

    function _countOccurrences(string memory haystack, string memory needle) private pure returns (uint256 count) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length == 0 || haystackBytes.length < needleBytes.length) {
            return 0;
        }

        for (uint256 i; i <= haystackBytes.length - needleBytes.length; i++) {
            bool matches = true;
            for (uint256 j; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    matches = false;
                    break;
                }
            }

            if (matches) {
                count++;
            }
        }
    }
}
