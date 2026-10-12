// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";
import {BannySvgStorage} from "../../src/BannySvgStorage.sol";

/// @notice Deploys a resolver with separately deployed, exclusively bound artwork storage for tests.
library BannyResolverDeployment {
    //*********************************************************************//
    // ----------------------- internal constants ------------------------ //
    //*********************************************************************//

    /// @notice The Foundry cheatcode interface used to bind storage as its configured owner.
    Vm internal constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice Deploy a resolver and bind its artwork storage under the configured owner's authority.
    /// @dev The owner controls configuration while the bound resolver exclusively controls artwork writes.
    /// @param bannyBodySvg The body SVG shared by each Banny.
    /// @param defaultNecklaceSvg The necklace SVG used when no necklace is selected.
    /// @param defaultMouthSvg The mouth SVG used when no mouth is selected.
    /// @param defaultStandardEyesSvg The standard eyes SVG used when no eyes are selected.
    /// @param defaultAlienEyesSvg The alien eyes SVG used when no eyes are selected.
    /// @param owner The account allowed to configure the resolver.
    /// @param trustedForwarder The trusted ERC-2771 forwarder.
    /// @return resolver The resolver with its exclusively bound artwork storage.
    function deploy(
        string memory bannyBodySvg,
        string memory defaultNecklaceSvg,
        string memory defaultMouthSvg,
        string memory defaultStandardEyesSvg,
        string memory defaultAlienEyesSvg,
        address owner,
        address trustedForwarder
    )
        internal
        returns (Banny721TokenUriResolver resolver)
    {
        // Match the production storage configurator to the resolver owner before binding publication authority.
        BannySvgStorage svgStorage = new BannySvgStorage(owner);
        resolver = new Banny721TokenUriResolver({
            bannyBodySvg: bannyBodySvg,
            defaultNecklaceSvg: defaultNecklaceSvg,
            defaultMouthSvg: defaultMouthSvg,
            defaultStandardEyesSvg: defaultStandardEyesSvg,
            defaultAlienEyesSvg: defaultAlienEyesSvg,
            owner: owner,
            trustedForwarder: trustedForwarder,
            svgStorage: svgStorage
        });
        // Impersonate only the authorized configurator; formal fixtures use the calling test as owner.
        if (owner != address(this)) _VM.prank(owner);
        svgStorage.setWriter(address(resolver));
    }
}
