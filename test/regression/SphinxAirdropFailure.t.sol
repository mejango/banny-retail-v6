// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IGnosisSafe} from "@sphinx-labs/contracts/contracts/foundry/interfaces/IGnosisSafe.sol";
import {ISphinxModule} from "@sphinx-labs/contracts/contracts/core/interfaces/ISphinxModule.sol";
import {
    ISphinxModuleProxyFactory
} from "@sphinx-labs/contracts/contracts/core/interfaces/ISphinxModuleProxyFactory.sol";
import {
    SphinxLeaf,
    SphinxLeafType,
    SphinxLeafWithProof,
    MerkleRootStatus
} from "@sphinx-labs/contracts/contracts/core/SphinxDataTypes.sol";
import {SafeAirdropExecutor} from "../../script/helpers/SafeAirdropExecutor.sol";
import {SafeAirdropExecutionProbe, SafeAirdropTestToken} from "./SafeAirdropExecutor.t.sol";

interface ISphinxFailureSafe is IGnosisSafe {
    function enableModule(address module) external;
    function isModuleEnabled(address module) external view returns (bool);
    function nonce() external view returns (uint256);
    function getTransactionHash(
        address,
        uint256,
        bytes calldata,
        uint8,
        uint256,
        uint256,
        uint256,
        address,
        address,
        uint256
    )
        external
        view
        returns (bytes32);
    function execTransaction(
        address,
        uint256,
        bytes calldata,
        uint8,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes calldata
    )
        external
        payable
        returns (bool);
}

/// @notice Local lifecycle regression using installed Sphinx and Safe bytecode and real owner signatures.
/// @dev This proves module semantics, not the cause of a particular hosted simulation or real airdrop gas fit.
contract SphinxAirdropFailureTest is Test {
    string private constant ARTIFACTS = "node_modules/@sphinx-labs/contracts/contract-artifacts/";
    uint256 private constant OWNER_KEY_A = 0xA11CE;
    uint256 private constant OWNER_KEY_B = 0xB0B;
    bytes32 private constant ACTION_SUCCEEDED = keccak256("SphinxActionSucceeded(bytes32,uint256)");
    bytes32 private constant ACTION_FAILED = keccak256("SphinxActionFailed(bytes32,uint256)");
    bytes32 private constant ROOT_FAILED = keccak256("SphinxMerkleRootFailed(bytes32,uint256)");

    ISphinxFailureSafe private safe;
    ISphinxModule private module;
    SafeAirdropTestToken private token;
    SafeAirdropExecutionProbe private implementation;
    SafeAirdropExecutor private executor;
    address private multiSend;

    function setUp() public {
        // Deploy precompiled 0.8.4 Sphinx artifacts rather than importing them into the 0.8.28 build.
        address singleton = deployCode(string.concat(ARTIFACTS, "gnosis-safe/v1.3.0/GnosisSafe.sol/GnosisSafe.json"));
        safe = ISphinxFailureSafe(
            deployCode(
                string.concat(ARTIFACTS, "gnosis-safe/v1.3.0/proxies/GnosisSafeProxy.sol/GnosisSafeProxy.json"),
                abi.encode(singleton)
            )
        );
        address[] memory owners = new address[](2);
        owners[0] = vm.addr(OWNER_KEY_A);
        owners[1] = vm.addr(OWNER_KEY_B);
        safe.setup(owners, 2, address(0), "", address(0), address(0), 0, payable(address(0)));

        ISphinxModuleProxyFactory factory = ISphinxModuleProxyFactory(
            deployCode(string.concat(ARTIFACTS, "sphinx/SphinxModuleProxyFactory.sol/SphinxModuleProxyFactory.json"))
        );
        module = ISphinxModule(factory.deploySphinxModuleProxy(address(safe), 0));
        bytes memory enable = abi.encodeCall(ISphinxFailureSafe.enableModule, (address(module)));
        bytes32 hash = safe.getTransactionHash(address(safe), 0, enable, 0, 0, 0, 0, address(0), address(0), 0);
        assertTrue(
            safe.execTransaction(address(safe), 0, enable, 0, 0, 0, 0, address(0), payable(address(0)), _sign(hash))
        );
        assertTrue(safe.isModuleEnabled(address(module)));
        assertEq(safe.getThreshold(), 2);
        assertEq(module.VERSION(), "1.0.0");

        multiSend = deployCode(
            string.concat(ARTIFACTS, "gnosis-safe/v1.3.0/libraries/MultiSendCallOnly.sol/MultiSendCallOnly.json")
        );
        token = new SafeAirdropTestToken();
        implementation = new SafeAirdropExecutionProbe();
        executor = new SafeAirdropExecutor(address(safe), address(implementation));
    }

    function testSeparateLeavesPreserveMintWhenMigrationFailsAndNextExecuteHasNoActiveRoot() public {
        SphinxLeaf[4] memory leaves = _leaves(false);
        bytes32 root = _approve(leaves);
        vm.recordLogs();
        vm.expectCall(address(implementation), abi.encodeCall(SafeAirdropExecutionProbe.reject, (2)));
        (bool outerSuccess, bytes memory result) =
            address(module).call(abi.encodeCall(ISphinxModule.execute, (_actions(leaves))));
        assertTrue(outerSuccess, "Required inner failure must not revert the outer module call");
        assertEq(result.length, 0);
        _assertEvents(vm.getRecordedLogs(), root, 2, 1);
        assertEq(token.ownerOf(1), address(executor), "Earlier successful mint must remain committed");
        assertEq(token.balanceOf(address(executor)), 1);
        _assertFailedAndCannotContinue(root, leaves, 3);
    }

    function testAtomicMintAndMigrationLeafRollsBackMintOnTheSameRejection() public {
        SphinxLeaf[4] memory leaves = _leaves(true);
        bytes32 root = _approve(leaves);
        vm.recordLogs();
        vm.expectCall(address(implementation), abi.encodeCall(SafeAirdropExecutionProbe.reject, (2)));
        (bool outerSuccess, bytes memory result) =
            address(module).call(abi.encodeCall(ISphinxModule.execute, (_actions(leaves))));
        assertTrue(outerSuccess);
        assertEq(result.length, 0);
        _assertEvents(vm.getRecordedLogs(), root, 1, 0);
        assertEq(token.balanceOf(address(executor)), 0, "Failed atomic leaf must roll the mint back");
        vm.expectRevert();
        token.ownerOf(1);
        _assertFailedAndCannotContinue(root, leaves, 2);
    }

    function _leaves(bool atomic) private view returns (SphinxLeaf[4] memory leaves) {
        leaves[0] = SphinxLeaf({
            chainId: block.chainid,
            index: 0,
            leafType: SphinxLeafType.APPROVE,
            data: abi.encode(address(safe), address(module), module.merkleRootNonce(), 4, address(this), "", false)
        });
        bytes memory mint = abi.encodeCall(SafeAirdropTestToken.mint, (address(executor), 1));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(SafeAirdropExecutionProbe.reject, (2));
        bytes memory reject = abi.encodeCall(SafeAirdropExecutor.execute, (calls));
        if (atomic) {
            bytes memory packed =
                bytes.concat(_packedCall(address(token), mint), _packedCall(address(executor), reject));
            leaves[1] = _action(1, multiSend, abi.encodeWithSignature("multiSend(bytes)", packed), 1);
        } else {
            leaves[1] = _action(1, address(token), mint, 0);
        }
        leaves[2] = _action(2, address(executor), reject, 0);
        // An unexecuted remainder distinguishes failure from normal root completion.
        leaves[3] = _action(3, address(token), abi.encodeCall(SafeAirdropTestToken.mint, (address(executor), 3)), 0);
    }

    function _action(
        uint256 index,
        address to,
        bytes memory data,
        uint8 operation
    )
        private
        view
        returns (SphinxLeaf memory)
    {
        return
            SphinxLeaf(
                block.chainid, index, SphinxLeafType.EXECUTE, abi.encode(to, 0, 1_000_000, data, operation, true)
            );
    }

    function _packedCall(address to, bytes memory data) private pure returns (bytes memory) {
        return abi.encodePacked(uint8(0), to, uint256(0), data.length, data);
    }

    function _approve(SphinxLeaf[4] memory leaves) private returns (bytes32 root) {
        root =
            _pair(_pair(_leafHash(leaves[0]), _leafHash(leaves[1])), _pair(_leafHash(leaves[2]), _leafHash(leaves[3])));
        bytes32 domain = keccak256(
            abi.encode(keccak256("EIP712Domain(string name,string version)"), keccak256("Sphinx"), keccak256("1.0.0"))
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domain, keccak256(abi.encode(keccak256("MerkleRoot(bytes32 root)"), root)))
        );
        module.approve(root, _proof(leaves, 0), _sign(digest));
        assertEq(module.activeMerkleRoot(), root);
    }

    function _sign(bytes32 digest) private pure returns (bytes memory) {
        (uint8 vA, bytes32 rA, bytes32 sA) = vm.sign(OWNER_KEY_A, digest);
        (uint8 vB, bytes32 rB, bytes32 sB) = vm.sign(OWNER_KEY_B, digest);
        return vm.addr(OWNER_KEY_A) < vm.addr(OWNER_KEY_B)
            ? abi.encodePacked(rA, sA, vA, rB, sB, vB)
            : abi.encodePacked(rB, sB, vB, rA, sA, vA);
    }

    function _actions(SphinxLeaf[4] memory leaves) private pure returns (SphinxLeafWithProof[] memory actions) {
        actions = new SphinxLeafWithProof[](3);
        for (uint256 i; i < 3; i++) {
            actions[i] = _proof(leaves, i + 1);
        }
    }

    function _proof(SphinxLeaf[4] memory leaves, uint256 index) private pure returns (SphinxLeafWithProof memory) {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = _leafHash(leaves[index ^ 1]);
        uint256 otherPair = index < 2 ? 2 : 0;
        proof[1] = _pair(_leafHash(leaves[otherPair]), _leafHash(leaves[otherPair + 1]));
        return SphinxLeafWithProof(leaves[index], proof);
    }

    function _leafHash(SphinxLeaf memory leaf) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(keccak256(abi.encode(leaf))));
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _assertEvents(Vm.Log[] memory logs, bytes32 root, uint256 failedIndex, uint256 successes) private view {
        uint256 actualSuccesses;
        uint256 failures;
        uint256 rootFailures;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].emitter != address(module)) continue;
            assertEq(logs[i].topics[1], root);
            uint256 index = abi.decode(logs[i].data, (uint256));
            if (logs[i].topics[0] == ACTION_SUCCEEDED) {
                actualSuccesses++;
                assertEq(index, 1);
            } else if (logs[i].topics[0] == ACTION_FAILED) {
                failures++;
                assertEq(index, failedIndex);
            } else if (logs[i].topics[0] == ROOT_FAILED) {
                rootFailures++;
                assertEq(index, failedIndex);
            } else {
                revert("Unexpected Sphinx lifecycle event");
            }
        }
        assertEq(actualSuccesses, successes);
        assertEq(failures, 1);
        assertEq(rootFailures, 1);
    }

    function _assertFailedAndCannotContinue(bytes32 root, SphinxLeaf[4] memory leaves, uint256 executed) private {
        (uint256 count, uint256 actualExecuted,, address rootExecutor, MerkleRootStatus status,) =
            module.merkleRootStates(root);
        assertEq(count, 4);
        assertEq(actualExecuted, executed);
        assertEq(rootExecutor, address(this));
        assertEq(uint256(status), uint256(MerkleRootStatus.FAILED));
        assertEq(module.activeMerkleRoot(), bytes32(0));
        assertEq(module.merkleRootNonce(), 1);
        assertEq(safe.nonce(), 1, "Module execution does not consume queued Safe nonces");
        SphinxLeafWithProof[] memory remaining = new SphinxLeafWithProof[](1);
        remaining[0] = _proof(leaves, 3);
        vm.expectRevert(bytes("SphinxModule: no active root"));
        module.execute(remaining);
        vm.expectRevert();
        token.ownerOf(3);
    }
}
