// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice Dual-implemented (Halmos `check_` + Foundry `testFuzz_`) functional-correctness proofs for the pure /
/// view helpers of `Banny721TokenUriResolver` that gate composition, naming, fill selection and membership.
///
/// @dev These exercise the SMT-tractable surface (category-name table totality, recognized-product fill domain,
/// `_isInArray` membership, the layered-SVG wrapper structure, and `_fullNameOf` token-id stripping). Stateful
/// custody / access-control properties live in `BannyResolverInvariant.t.sol`.
contract BannyResolverProperties is Test, Banny721TokenUriResolver {
    // Category constants mirrored from the contract (private there) so assertions read clearly.
    uint256 internal constant CAT_BODY = 0;
    uint256 internal constant CAT_BACKGROUND = 1;
    uint256 internal constant CAT_SPECIAL_BODY = 17; // last recognized category.

    constructor()
        Banny721TokenUriResolver("<body/>", "<neck/>", "<mouth/>", "<eyes/>", "<alien/>", address(1), address(0))
    {}

    //*********************************************************************//
    // ----------- category-name table: total + injective-ish ------------ //
    //*********************************************************************//

    /// @notice Every category in the recognized range [0, 17] maps to a NON-empty display name, and every value
    /// strictly above the last recognized category (17) maps to the empty string. This is the totality/domain
    /// contract `_categoryNameOf` must satisfy for `tokenUriOf` / `namesOf` metadata to be well-formed.
    function check_categoryNameDomain(uint256 category) public pure {
        if (category <= CAT_SPECIAL_BODY) {
            // Recognized categories must produce a non-empty label.
            assert(bytes(_categoryNameOf(category)).length != 0);
        } else {
            // Out-of-range categories produce the empty label.
            assert(bytes(_categoryNameOf(category)).length == 0);
        }
    }

    /// @notice Fuzz mirror of {check_categoryNameDomain}.
    function testFuzz_categoryNameDomain(uint256 category) public pure {
        if (category <= CAT_SPECIAL_BODY) {
            assertGt(bytes(_categoryNameOf(category)).length, 0, "recognized category has empty name");
        } else {
            assertEq(bytes(_categoryNameOf(category)).length, 0, "out-of-range category has non-empty name");
        }
    }

    //*********************************************************************//
    // ------------------ fills: recognized-product domain --------------- //
    //*********************************************************************//

    /// @notice On a recognized UPC {1,2,3,4} `_fillsFor` returns 7 non-empty 6-hex fill strings (the body palette).
    /// This is the contract that `_bannyBodySvgOf` relies on to never produce a malformed `<style>` block. The
    /// out-of-domain revert branch is proven separately by {testFuzz_fillsRevertOutsideDomain} (revert detection
    /// requires an external call, which is not `pure`).
    function check_fillsRecognizedPalette(uint256 upc) public pure {
        // Restrict to the recognized set; this is the totality half of the domain contract.
        if (upc < 1 || upc > 4) return;
        uint256[7] memory lens = _fillLengths(upc);
        // Each palette entry is a 6-character hex color.
        for (uint256 i; i < 7; ++i) {
            assert(lens[i] == 6);
        }
    }

    /// @dev Collects the byte-lengths of the 7 palette fills into a fixed array, isolating the deep 7-tuple
    /// destructure in its own stack frame (avoids stack-too-deep in the `check_`/fuzz bodies under via-IR).
    function _fillLengths(uint256 upc) internal pure returns (uint256[7] memory lens) {
        (
            string memory b1,
            string memory b2,
            string memory b3,
            string memory b4,
            string memory a1,
            string memory a2,
            string memory a3
        ) = _fillsFor(upc);
        lens[0] = bytes(b1).length;
        lens[1] = bytes(b2).length;
        lens[2] = bytes(b3).length;
        lens[3] = bytes(b4).length;
        lens[4] = bytes(a1).length;
        lens[5] = bytes(a2).length;
        lens[6] = bytes(a3).length;
    }

    /// @notice External wrapper used to detect the revert branch of the internal pure helper.
    function fillsForExternal(uint256 upc)
        external
        pure
        returns (
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory
        )
    {
        return _fillsFor(upc);
    }

    /// @notice Outside the recognized UPC set {1,2,3,4}, `_fillsFor` must revert (no silent empty palette).
    function testFuzz_fillsRevertOutsideDomain(uint256 upc) public {
        vm.assume(upc < 1 || upc > 4);
        vm.expectRevert();
        this.fillsForExternal(upc);
    }

    /// @notice Fuzz mirror of {check_fillsRecognizedPalette} over the recognized set.
    function testFuzz_fillsRecognizedPalette(uint256 upc) public pure {
        upc = bound(upc, 1, 4);
        uint256[7] memory lens = _fillLengths(upc);
        for (uint256 i; i < 7; ++i) {
            assertEq(lens[i], 6, "palette entry not 6 hex chars");
        }
    }

    //*********************************************************************//
    // ----------------------- membership helper ------------------------- //
    //*********************************************************************//

    /// @notice For an arbitrary array, `_isInArray(value, array)` returns true IFF some slot equals `value`.
    /// Proven over a symbolic length-4 array; the helper's loop is otherwise length-agnostic.
    function check_isInArrayCorrect(uint256 a, uint256 b, uint256 c, uint256 d, uint256 value) public pure {
        uint256[] memory arr = new uint256[](4);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;

        bool present = (value == a) || (value == b) || (value == c) || (value == d);
        assert(_isInArray({value: value, array: arr}) == present);
    }

    /// @notice Fuzz mirror over a dynamically-sized array.
    function testFuzz_isInArrayCorrect(uint256[] memory arr, uint256 value, uint256 hitIndex) public pure {
        // Reference implementation: linear scan.
        bool expected;
        for (uint256 i; i < arr.length; ++i) {
            if (arr[i] == value) {
                expected = true;
                break;
            }
        }
        assertEq(_isInArray({value: value, array: arr}), expected, "membership mismatch");

        // If the array is non-empty, planting `value` at a valid index must always be found.
        if (arr.length != 0) {
            arr[hitIndex % arr.length] = value;
            assertTrue(_isInArray({value: value, array: arr}), "planted value not found");
        }
    }

    //*********************************************************************//
    // ------------------- layered-SVG wrapper structure ----------------- //
    //*********************************************************************//

    /// @notice `_layeredSvg` wraps arbitrary inner content in exactly one `<svg ...>...</svg>` envelope: the result
    /// length equals the input length plus the fixed envelope overhead (the length of the empty wrapping), and the
    /// result ends with "</svg>". This is the structural contract every rendered token image relies on. The overhead
    /// is derived from the implementation itself (not a magic number) so it can never drift.
    function check_layeredSvgWraps(bytes32 seed) public pure {
        // Build a short deterministic content string from the seed (keeps the path count tiny for halmos).
        bytes memory inner = abi.encodePacked(seed);
        uint256 overhead = bytes(_layeredSvg("")).length; // envelope length with empty content.

        bytes memory w = bytes(_layeredSvg(string(inner)));

        // The wrapper adds exactly the envelope overhead, so the output grows linearly with the content.
        assert(w.length == inner.length + overhead);

        // It must end with "</svg>".
        assert(w[w.length - 6] == "<");
        assert(w[w.length - 5] == "/");
        assert(w[w.length - 4] == "s");
        assert(w[w.length - 3] == "v");
        assert(w[w.length - 2] == "g");
        assert(w[w.length - 1] == ">");
    }

    /// @notice Fuzz mirror of {check_layeredSvgWraps} over arbitrary-length content.
    function testFuzz_layeredSvgWraps(bytes memory inner) public pure {
        uint256 overhead = bytes(_layeredSvg("")).length;
        bytes memory w = bytes(_layeredSvg(string(inner)));

        assertEq(w.length, inner.length + overhead, "wrapper length");
        // Suffix is "</svg>".
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(w[w.length - 6], bytes1("<"));
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(w[w.length - 1], bytes1(">"));
    }

    //*********************************************************************//
    // ----------------- full-name token-id stripping ------------------- //
    //*********************************************************************//

    /// @notice `_fullNameOf` strips the product prefix via `tokenId % 1e9`. The produced name is always non-empty
    /// for a recognized product (id 1..4 have hard-coded names) regardless of the token sequence number. This guards
    /// the metadata `name` field from ever being empty for a real banny body.
    function testFuzz_fullNameNonEmptyForKnownProduct(uint256 tokenId, uint8 prodId, uint32 supply) public view {
        prodId = uint8(bound(prodId, 1, 4)); // recognized hard-coded product names.
        JB721TierLite memory lite;
        lite.id = prodId;
        lite.initialSupply = supply == 0 ? 1 : supply;
        lite.remainingSupply = lite.initialSupply;

        // Re-pack into the real struct via assembly-free path: call the contract helper through a tier.
        string memory name = _fullNameOf({tokenId: tokenId, product: _toTier(lite)});
        assertGt(bytes(name).length, 0, "known product produced empty name");
    }

    // Minimal mirror used only to build a tier in-test without importing the full struct boilerplate.
    struct JB721TierLite {
        uint32 id;
        uint32 initialSupply;
        uint32 remainingSupply;
        uint24 category;
    }

    function _toTier(JB721TierLite memory lite) internal pure returns (JB721Tier memory tier) {
        tier.id = lite.id;
        tier.initialSupply = lite.initialSupply;
        tier.remainingSupply = lite.remainingSupply;
        tier.category = lite.category;
    }
}
