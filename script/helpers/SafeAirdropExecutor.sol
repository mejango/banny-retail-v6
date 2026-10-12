// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Holds migration NFTs while the bound Safe invokes an existing stateless migration implementation.
contract SafeAirdropExecutor {
    error SafeAirdropExecutor_InvalidImplementation(address implementation);
    error SafeAirdropExecutor_InvalidSafe(address safe);
    error SafeAirdropExecutor_Unauthorized(address caller, address safe);

    address public immutable IMPLEMENTATION;
    address public immutable SAFE;

    constructor(address safe, address implementation) {
        if (safe.code.length == 0) revert SafeAirdropExecutor_InvalidSafe({safe: safe});
        if (implementation.code.length == 0) {
            revert SafeAirdropExecutor_InvalidImplementation({implementation: implementation});
        }
        IMPLEMENTATION = implementation;
        SAFE = safe;
    }

    /// @notice Run the reviewed migration calls in order, preserving this contract's custody and Safe authority.
    /// @param calls Calldata for the fixed migration implementation, reviewed by the Safe owners.
    function execute(bytes[] calldata calls) external {
        if (msg.sender != SAFE) revert SafeAirdropExecutor_Unauthorized({caller: msg.sender, safe: SAFE});
        for (uint256 i; i < calls.length; i++) {
            (bool success, bytes memory result) = IMPLEMENTATION.delegatecall(calls[i]);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(result, 0x20), mload(result))
                }
            }
        }
    }
}
