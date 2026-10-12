// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {AirdropV4BannysCombinedBase} from "../../script/AirdropV4BannysCombinedBase.sol";
import {SafeAirdropExecutor} from "../../script/helpers/SafeAirdropExecutor.sol";

contract SafeAirdropRecorder {
    address public executor;
    address public sender;
    uint256 public step;

    function record(address executor_, address sender_, uint256 step_) external {
        require(step_ == step + 1, "Wrong call order");
        executor = executor_;
        sender = sender_;
        step = step_;
    }
}

contract SafeAirdropExecutionProbe {
    error SafeAirdropExecutionProbe_Rejected(uint256 step);

    function record(SafeAirdropRecorder recorder, uint256 step) external {
        recorder.record({executor_: address(this), sender_: msg.sender, step_: step});
    }

    function reject(uint256 step) external pure {
        revert SafeAirdropExecutionProbe_Rejected({step: step});
    }
}

contract SafeAirdropTestToken is ERC721 {
    constructor() ERC721("Airdrop test", "DROP") {}

    function mint(address beneficiary, uint256 tokenId) external {
        _mint({to: beneficiary, tokenId: tokenId});
    }
}

contract SafeAirdropCallbackAttacker is IERC721Receiver {
    SafeAirdropExecutor public immutable EXECUTOR;
    address public immutable IMPLEMENTATION;
    bytes private _attack;

    bool public executorAccepted;
    bool public implementationAccepted;
    bool public alternateEntrypointAccepted;
    bytes public executorRevert;

    constructor(SafeAirdropExecutor executor, address implementation, bytes memory attack) {
        EXECUTOR = executor;
        IMPLEMENTATION = implementation;
        _attack = attack;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        bytes[] memory calls = new bytes[](1);
        calls[0] = _attack;
        (executorAccepted, executorRevert) =
            address(EXECUTOR).call(abi.encodeCall(SafeAirdropExecutor.execute, (calls)));
        (implementationAccepted,) = IMPLEMENTATION.call(_attack);
        (alternateEntrypointAccepted,) = address(EXECUTOR).call(_attack);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract SafeAirdropExecutorTest is Test {
    SafeAirdropExecutor internal executor;
    SafeAirdropExecutionProbe internal implementation;
    SafeAirdropRecorder internal recorder;

    function setUp() public {
        implementation = new SafeAirdropExecutionProbe();
        recorder = new SafeAirdropRecorder();
        executor = new SafeAirdropExecutor({safe: address(this), implementation: address(implementation)});
    }

    function testRejectsInvalidConfiguration() public {
        address noCode = makeAddr("no code");
        vm.expectRevert(
            abi.encodeWithSelector(SafeAirdropExecutor.SafeAirdropExecutor_InvalidSafe.selector, address(0))
        );
        new SafeAirdropExecutor({safe: address(0), implementation: address(implementation)});
        vm.expectRevert(abi.encodeWithSelector(SafeAirdropExecutor.SafeAirdropExecutor_InvalidSafe.selector, noCode));
        new SafeAirdropExecutor({safe: noCode, implementation: address(implementation)});
        vm.expectRevert(
            abi.encodeWithSelector(SafeAirdropExecutor.SafeAirdropExecutor_InvalidImplementation.selector, address(0))
        );
        new SafeAirdropExecutor({safe: address(this), implementation: address(0)});
        vm.expectRevert(
            abi.encodeWithSelector(SafeAirdropExecutor.SafeAirdropExecutor_InvalidImplementation.selector, noCode)
        );
        new SafeAirdropExecutor({safe: address(this), implementation: noCode});
    }

    function testOnlyBoundSafeCanExecute() public {
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(SafeAirdropExecutionProbe.record, (recorder, 1));
        address attacker = makeAddr("attacker");
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeAirdropExecutor.SafeAirdropExecutor_Unauthorized.selector, attacker, address(this)
            )
        );
        vm.prank(attacker);
        executor.execute({calls: calls});
        assertEq(recorder.step(), 0);
    }

    function testAuthorizedCallsPreserveDelegateContextAndOrder() public {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(SafeAirdropExecutionProbe.record, (recorder, 1));
        calls[1] = abi.encodeCall(SafeAirdropExecutionProbe.record, (recorder, 2));
        executor.execute({calls: calls});
        assertEq(recorder.step(), 2);
        assertEq(recorder.executor(), address(executor));
        assertEq(recorder.sender(), address(this));
        assertEq(executor.SAFE(), address(this));
        assertEq(executor.IMPLEMENTATION(), address(implementation));
    }

    function testRevertBubblesAndRollsBackEarlierCalls() public {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(SafeAirdropExecutionProbe.record, (recorder, 1));
        calls[1] = abi.encodeCall(SafeAirdropExecutionProbe.reject, (2));
        vm.expectRevert(
            abi.encodeWithSelector(SafeAirdropExecutionProbe.SafeAirdropExecutionProbe_Rejected.selector, 2)
        );
        executor.execute({calls: calls});
        assertEq(recorder.step(), 0);
        assertEq(recorder.executor(), address(0));
    }

    function testGenericHelperCannotBeRedirectedByRecipientCallback() public {
        AirdropV4BannysCombinedBase generic = new AirdropV4BannysCombinedBase();
        SafeAirdropExecutor guarded = new SafeAirdropExecutor({safe: address(this), implementation: address(generic)});
        SafeAirdropTestToken token = new SafeAirdropTestToken();
        address honest = makeAddr("honest recipient");
        address thief = makeAddr("thief");
        address[] memory attackRecipients = new address[](1);
        attackRecipients[0] = thief;
        uint256[] memory attackTokenIds = new uint256[](1);
        attackTokenIds[0] = 2;
        bytes memory attack = _transferCall(address(token), attackRecipients, attackTokenIds);
        SafeAirdropCallbackAttacker receiver =
            new SafeAirdropCallbackAttacker({executor: guarded, implementation: address(generic), attack: attack});
        token.mint({beneficiary: address(guarded), tokenId: 1});
        token.mint({beneficiary: address(guarded), tokenId: 2});
        address[] memory recipients = new address[](2);
        recipients[0] = address(receiver);
        recipients[1] = honest;
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        bytes[] memory calls = new bytes[](2);
        calls[0] = _transferCall(address(token), recipients, tokenIds);
        calls[1] = abi.encodeCall(AirdropV4BannysCombinedBase.requireNoBalance, (address(token)));
        guarded.execute({calls: calls});
        assertFalse(receiver.executorAccepted());
        assertFalse(receiver.implementationAccepted());
        assertFalse(receiver.alternateEntrypointAccepted());
        assertEq(
            receiver.executorRevert(),
            abi.encodeWithSelector(
                SafeAirdropExecutor.SafeAirdropExecutor_Unauthorized.selector, address(receiver), address(this)
            )
        );
        assertEq(token.ownerOf(1), address(receiver));
        assertEq(token.ownerOf(2), honest);
        assertEq(token.balanceOf(address(guarded)), 0);
    }

    function _transferCall(
        address token,
        address[] memory recipients,
        uint256[] memory tokenIds
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            AirdropV4BannysCombinedBase.transferRegular,
            (
                token,
                address(1),
                address(2),
                address(3),
                false,
                recipients,
                tokenIds,
                tokenIds,
                new bool[](tokenIds.length)
            )
        );
    }
}
