// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SSTORE2} from "solady/src/utils/SSTORE2.sol";

/// @notice Stores committed SVG fragments as immutable, STOP-prefixed contract bytecode.
/// @dev The deploying resolver validates commitments and publication uniqueness before writing.
contract BannySvgStorage {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    /// @notice Thrown when a caller other than the deploying resolver attempts to publish artwork.
    error BannySvgStorage_Unauthorized(address caller);

    //*********************************************************************//
    // ------------------------ internal constants ----------------------- //
    //*********************************************************************//

    /// @notice The maximum number of artwork bytes stored in each immutable chunk.
    /// @dev EIP-170 allows 24,576 bytes of runtime code; SSTORE2 reserves one byte for STOP.
    uint256 internal constant _CHUNK_SIZE = 24_575;

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The resolver allowed to publish artwork.
    /// @dev Bound to the deploying resolver so external callers cannot bypass commitment validation.
    address public immutable WRITER = msg.sender;

    //*********************************************************************//
    // -------------------- internal stored properties ------------------- //
    //*********************************************************************//

    /// @notice The immutable bytecode addresses containing each product's artwork, in fragment order.
    /// @dev Appended only by the resolver after it validates the complete fragment and publication uniqueness.
    /// @custom:param upc The universal product code whose artwork chunks are stored.
    mapping(uint256 upc => address[]) internal _pointersOf;

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Publish a product's SVG fragment in immutable bytecode chunks.
    /// @dev Only the deploying resolver can write. Empty content creates no chunks and remains unpublished.
    /// @param upc The universal product code whose artwork to publish.
    /// @param contents The complete fragment validated by the resolver against its committed hash.
    function write(uint256 upc, bytes calldata contents) external {
        // Keep commitment validation and publication uniqueness under the resolver's authority.
        if (msg.sender != WRITER) revert BannySvgStorage_Unauthorized({caller: msg.sender});

        // Keep every deployed chunk within the runtime code limit while preserving fragment order.
        for (uint256 start; start < contents.length;) {
            uint256 end = start + _CHUNK_SIZE;
            // The final chunk contains only the remaining fragment bytes.
            if (end > contents.length) end = contents.length;
            _pointersOf[upc].push(SSTORE2.write(contents[start:end]));
            start = end;
        }
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Whether nonempty artwork has been published for a product.
    /// @param upc The universal product code whose publication status to check.
    /// @return stored Whether at least one immutable artwork chunk exists.
    function isStored(uint256 upc) external view returns (bool stored) {
        return _pointersOf[upc].length != 0;
    }

    /// @notice Read a product's complete SVG fragment, or empty bytes before publication.
    /// @param upc The universal product code whose artwork to read.
    /// @return contents The exact fragment reconstructed in publication order.
    function read(uint256 upc) external view returns (bytes memory contents) {
        address[] storage pointers = _pointersOf[upc];
        // ponytail: fragments up to 73,725 bytes need at most three chunks; use one allocation if larger assets
        // require it.
        for (uint256 i; i < pointers.length; ++i) {
            contents = bytes.concat(contents, SSTORE2.read(pointers[i]));
        }
    }
}
