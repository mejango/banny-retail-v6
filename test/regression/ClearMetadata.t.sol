// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @notice setMetadata should allow clearing fields to empty string.
contract ClearMetadataTest is Test {
    Banny721TokenUriResolver resolver;
    address deployer = makeAddr("deployer");

    function setUp() public {
        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );
    }

    function test_setMetadata_canClearToEmpty() public {
        // First, set some values.
        vm.prank(deployer);
        resolver.setMetadata("Initial desc", "https://initial.url", "https://initial.base/");

        assertEq(resolver.svgDescription(), "Initial desc");
        assertEq(resolver.svgExternalUrl(), "https://initial.url");
        assertEq(resolver.svgBaseUri(), "https://initial.base/");

        // Now clear all fields by passing empty strings.
        vm.prank(deployer);
        resolver.setMetadata("", "", "");

        // Fields should now be empty (cleared), not still holding old values.
        assertEq(resolver.svgDescription(), "", "description should be cleared");
        assertEq(resolver.svgExternalUrl(), "", "url should be cleared");
        assertEq(resolver.svgBaseUri(), "", "baseUri should be cleared");
    }

    function test_setMetadata_canClearIndividualField() public {
        // Set all fields.
        vm.prank(deployer);
        resolver.setMetadata("desc", "https://url", "https://base/");

        // Clear only description, keep others.
        vm.prank(deployer);
        resolver.setMetadata("", "https://url", "https://base/");

        assertEq(resolver.svgDescription(), "", "description should be cleared");
        assertEq(resolver.svgExternalUrl(), "https://url", "url should be unchanged");
        assertEq(resolver.svgBaseUri(), "https://base/", "baseUri should be unchanged");
    }
}
