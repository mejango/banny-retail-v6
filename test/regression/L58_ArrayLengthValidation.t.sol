// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice Mismatched array lengths should revert.
contract L58_ArrayLengthValidationTest is Test {
    Banny721TokenUriResolver resolver;
    address deployer = makeAddr("deployer");

    function setUp() public {
        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );
    }

    function test_setProductNames_revertsOnMismatchedLengths() public {
        uint256[] memory upcs = new uint256[](2);
        upcs[0] = 1;
        upcs[1] = 2;

        string[] memory names = new string[](1);
        names[0] = "Only One";

        vm.prank(deployer);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_ArrayLengthMismatch.selector);
        resolver.setProductNames(upcs, names);
    }

    function test_setSvgContentsOf_revertsOnMismatchedLengths() public {
        uint256[] memory upcs = new uint256[](2);
        upcs[0] = 1;
        upcs[1] = 2;

        string[] memory contents = new string[](1);
        contents[0] = "only one";

        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_ArrayLengthMismatch.selector);
        resolver.setSvgContentsOf(upcs, contents);
    }

    function test_setSvgHashesOf_revertsOnMismatchedLengths() public {
        uint256[] memory upcs = new uint256[](2);
        upcs[0] = 1;
        upcs[1] = 2;

        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("test");

        vm.prank(deployer);
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_ArrayLengthMismatch.selector);
        resolver.setSvgHashesOf(upcs, hashes);
    }
}
