// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SSTORE2} from "solady/src/utils/SSTORE2.sol";

/// @notice Stores committed SVG fragments as immutable, STOP-prefixed contract bytecode.
/// @dev The deploying resolver validates commitments and publication uniqueness before writing.
contract BannySvgStorage {
    error BannySvgStorage_Unauthorized(address caller);

    /// @notice The resolver allowed to publish artwork.
    address public immutable WRITER = msg.sender;

    // EIP-170 allows 24,576 bytes of runtime code; SSTORE2 reserves one byte for STOP.
    uint256 internal constant _CHUNK_SIZE = 24_575;

    mapping(uint256 upc => address[]) internal _pointersOf;

    /// @notice Whether nonempty artwork has been published for a product.
    function isStored(uint256 upc) external view returns (bool) {
        return _pointersOf[upc].length != 0;
    }

    /// @notice Publish artwork already validated by the resolver.
    /// @dev Empty content creates no chunks, preserving the resolver's existing empty-content behavior.
    function write(uint256 upc, bytes calldata contents) external {
        if (msg.sender != WRITER) revert BannySvgStorage_Unauthorized(msg.sender);

        for (uint256 start; start < contents.length;) {
            uint256 end = start + _CHUNK_SIZE;
            if (end > contents.length) end = contents.length;
            _pointersOf[upc].push(SSTORE2.write(contents[start:end]));
            start = end;
        }
    }

    /// @notice Read the exact original fragment, or empty bytes before publication.
    function read(uint256 upc) external view returns (bytes memory contents) {
        address[] storage pointers = _pointersOf[upc];
        // ponytail: current original artwork needs at most three chunks; use one allocation if larger assets require
        // it.
        for (uint256 i; i < pointers.length; ++i) {
            contents = bytes.concat(contents, SSTORE2.read(pointers[i]));
        }
    }
}
