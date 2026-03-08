// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {JB721TierConfig} from "@bananapus/721-hook-v6/src/structs/JB721TierConfig.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";

import "./helpers/BannyverseDeploymentLib.sol";
import "@rev-net/core-v6/script/helpers/RevnetCoreDeploymentLib.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

contract Drop1Script is Script, Sphinx {
    /// @notice tracks the deployment of the revnet contracts for the chain we are deploying to.
    RevnetCoreDeployment revnet;
    /// @notice tracks the deployment of the bannyverse contracts for the chain we are deploying to.
    BannyverseDeployment bannyverse;

    JB721TiersHook hook;
    address reserveBeneficiary;

    function configureSphinx() public override {
        // TODO: Update to contain revnet devs.
        sphinxConfig.projectName = "banny-core-v6";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public {
        reserveBeneficiary = safeAddress();

        // Get the deployment addresses for the revnet contracts for this chain.
        revnet = RevnetCoreDeploymentLib.getDeployment(
            vm.envOr("REVNET_CORE_DEPLOYMENT_PATH", string("node_modules/@rev-net/core-v6/deployments/"))
        );

        // Get the deployment addresses for the 721 hook contracts for this chain.
        bannyverse = BannyverseDeploymentLib.getDeployment(
            vm.envOr("BANNYVERSE_CORE_DEPLOYMENT_PATH", string("deployments/")),
            vm.envOr("BANNYVERSE_REVNET_ID", uint256(4))
        );

        // Get the hook address by using the deployer.
        hook = JB721TiersHook(address(revnet.basic_deployer.tiered721HookOf(bannyverse.revnetId)));
        deploy();
    }

    function deploy() public sphinx {
        uint256 decimals = 18;

        string[] memory names = new string[](1);
        bytes32[] memory svgHashes = new bytes32[](1);
        JB721TierConfig[] memory products = new JB721TierConfig[](1);

        names[0] = "Denver 2025";
        svgHashes[0] = bytes32(0x62f97f668e227ab9d6eaf5bd35504974f3df175ee2d952c39add59b7d141c0de);
        products[0] = JB721TierConfig({
            price: uint104(1 * (10 ** (decimals - 2))),
            initialSupply: 250,
            votingUnits: 0,
            reserveFrequency: 0,
            reserveBeneficiary: address(0),
            encodedIPFSUri: bytes32(0x233dd4173ef4ed0f60822a469277bb328b5ae056d8980301f7bd7ad9df780099),
            category: 1,
            discountPercent: 0,
            cannotIncreaseDiscountPercent: false,
            allowOwnerMint: false,
            useReserveBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: false,
            cannotBeRemoved: false,
            splitPercent: 0,
            splits: new JBSplit[](0)
        });

        // Get the next tier ID so we can set names and hashes for the new product.
        uint256 nextTierId = hook.STORE().maxTierIdOf(address(hook)) + 1;

        hook.adjustTiers(products, new uint256[](0));

        // Build the product IDs array for the newly added tier(s).
        uint256[] memory productIds = new uint256[](1);
        productIds[0] = nextTierId;

        bannyverse.resolver.setSvgHashesOf(productIds, svgHashes);
        bannyverse.resolver.setProductNames(productIds, names);
    }
}
