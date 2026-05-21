// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice Halmos smoke proofs for Banny resolver helpers that gate composition metadata and retained outfit state.
contract BannyResolverHalmos is Banny721TokenUriResolver {
    constructor() Banny721TokenUriResolver("", "", "", "", "", address(1), address(0)) {}

    /// @notice Checks that all supported category IDs resolve to their intended display names.
    function check_categoryNameBoundaryTable() public pure {
        assert(keccak256(bytes(_categoryNameOf(0))) == keccak256(bytes("Banny body")));
        assert(keccak256(bytes(_categoryNameOf(1))) == keccak256(bytes("Background")));
        assert(keccak256(bytes(_categoryNameOf(2))) == keccak256(bytes("Backside")));
        assert(keccak256(bytes(_categoryNameOf(3))) == keccak256(bytes("Necklace")));
        assert(keccak256(bytes(_categoryNameOf(4))) == keccak256(bytes("Head")));
        assert(keccak256(bytes(_categoryNameOf(5))) == keccak256(bytes("Eyes")));
        assert(keccak256(bytes(_categoryNameOf(6))) == keccak256(bytes("Glasses")));
        assert(keccak256(bytes(_categoryNameOf(7))) == keccak256(bytes("Mouth")));
        assert(keccak256(bytes(_categoryNameOf(8))) == keccak256(bytes("Legs")));
        assert(keccak256(bytes(_categoryNameOf(9))) == keccak256(bytes("Suit")));
        assert(keccak256(bytes(_categoryNameOf(10))) == keccak256(bytes("Suit bottom")));
        assert(keccak256(bytes(_categoryNameOf(11))) == keccak256(bytes("Suit top")));
        assert(keccak256(bytes(_categoryNameOf(12))) == keccak256(bytes("Head top")));
        assert(keccak256(bytes(_categoryNameOf(13))) == keccak256(bytes("Fist")));
        assert(keccak256(bytes(_categoryNameOf(14))) == keccak256(bytes("Special Suit")));
        assert(keccak256(bytes(_categoryNameOf(15))) == keccak256(bytes("Special Legs")));
        assert(keccak256(bytes(_categoryNameOf(16))) == keccak256(bytes("Special Head")));
        assert(keccak256(bytes(_categoryNameOf(17))) == keccak256(bytes("Special Body")));
        assert(bytes(_categoryNameOf(18)).length == 0);
    }

    /// @notice Proves the retained-outfit membership helper finds a value in every checked slot.
    /// @param first The first array entry.
    /// @param second The second array entry.
    /// @param third The third array entry.
    function check_isInArrayFindsEachSlot(uint64 first, uint64 second, uint64 third) public pure {
        uint256[] memory values = new uint256[](3);
        values[0] = first;
        values[1] = second;
        values[2] = third;

        assert(_isInArray({value: first, array: values}));
        assert(_isInArray({value: second, array: values}));
        assert(_isInArray({value: third, array: values}));
    }

    /// @notice Proves the membership helper rejects a missing value.
    /// @param first The first array entry.
    /// @param second The second array entry.
    /// @param third The third array entry.
    /// @param missing The value that must not be present.
    function check_isInArrayRejectsMissingValue(uint64 first, uint64 second, uint64 third, uint64 missing) public pure {
        if (missing == first || missing == second || missing == third) return;

        uint256[] memory values = new uint256[](3);
        values[0] = first;
        values[1] = second;
        values[2] = third;

        assert(!_isInArray({value: missing, array: values}));
    }

    /// @notice Proves the membership helper handles the empty and single-value cases.
    /// @param value The value to search for.
    function check_isInArraySingleValue(uint64 value) public pure {
        uint256[] memory emptyValues = new uint256[](0);
        assert(!_isInArray({value: value, array: emptyValues}));

        uint256[] memory values = new uint256[](1);
        values[0] = value;

        assert(_isInArray({value: value, array: values}));
    }
}
