// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@bananapus/721-hook-v6/script/helpers/Hook721DeploymentLib.sol";
import "@bananapus/core-v6/script/helpers/CoreDeploymentLib.sol";
import "@bananapus/suckers-v6/script/helpers/SuckerDeploymentLib.sol";
import "@bananapus/router-terminal-v6/script/helpers/RouterTerminalDeploymentLib.sol";
import "@rev-net/core-v6/script/helpers/RevnetCoreDeploymentLib.sol";

import {IJB721TokenUriResolver} from "@bananapus/721-hook-v6/src/interfaces/IJB721TokenUriResolver.sol";
import {JB721InitTiersConfig} from "@bananapus/721-hook-v6/src/structs/JB721InitTiersConfig.sol";
import {JB721TierConfig} from "@bananapus/721-hook-v6/src/structs/JB721TierConfig.sol";
import {JB721TiersHookFlags} from "@bananapus/721-hook-v6/src/structs/JB721TiersHookFlags.sol";
import {JBDeploy721TiersHookConfig} from "@bananapus/721-hook-v6/src/structs/JBDeploy721TiersHookConfig.sol";
import {IJBPrices} from "@bananapus/core-v6/src/interfaces/IJBPrices.sol";
import {IJBSplitHook} from "@bananapus/core-v6/src/interfaces/IJBSplitHook.sol";
import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "@bananapus/core-v6/src/libraries/JBCurrencyIds.sol";
import {JBAccountingContext} from "@bananapus/core-v6/src/structs/JBAccountingContext.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";
import {JBTerminalConfig} from "@bananapus/core-v6/src/structs/JBTerminalConfig.sol";
import {JBTokenMapping} from "@bananapus/suckers-v6/src/structs/JBTokenMapping.sol";
import {REVAutoIssuance} from "@rev-net/core-v6/src/structs/REVAutoIssuance.sol";
import {REVConfig} from "@rev-net/core-v6/src/structs/REVConfig.sol";
import {REVCroptopAllowedPost} from "@rev-net/core-v6/src/structs/REVCroptopAllowedPost.sol";
import {REVDeploy721TiersHookConfig} from "@rev-net/core-v6/src/structs/REVDeploy721TiersHookConfig.sol";
import {REVDescription} from "@rev-net/core-v6/src/structs/REVDescription.sol";
import {REVStageConfig} from "@rev-net/core-v6/src/structs/REVStageConfig.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core-v6/src/structs/REVSuckerDeploymentConfig.sol";
import {JBSuckerDeployerConfig} from "@bananapus/suckers-v6/src/structs/JBSuckerDeployerConfig.sol";
import {IJBTerminal} from "@bananapus/core-v6/src/interfaces/IJBTerminal.sol";

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

import {Banny721TokenUriResolver} from "./../src/Banny721TokenUriResolver.sol";

struct BannyverseRevnetConfig {
    REVConfig configuration;
    JBTerminalConfig[] terminalConfigurations;
    REVSuckerDeploymentConfig suckerDeploymentConfiguration;
    REVDeploy721TiersHookConfig hookConfiguration;
}

contract DeployScript is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;
    /// @notice tracks the deployment of the sucker contracts for the chain we are deploying to.
    SuckerDeployment suckers;
    /// @notice tracks the deployment of the revnet contracts for the chain we are deploying to.
    RevnetCoreDeployment revnet;
    /// @notice tracks the deployment of the 721 hook contracts for the chain we are deploying to.
    Hook721Deployment hook;
    /// @notice tracks the deployment of the router terminal.
    RouterTerminalDeployment routerTerminal;

    BannyverseRevnetConfig bannyverseConfig;

    uint32 PREMINT_CHAIN_ID = 1;
    bytes32 ERC20_SALT = "_BAN_ERC20V6_";
    bytes32 SUCKER_SALT = "_BAN_SUCKERV6_";
    bytes32 HOOK_SALT = "_BAN_HOOKV6_";
    bytes32 RESOLVER_SALT = "_BAN_RESOLVERV6_";
    string NAME = "Banny Network";
    string SYMBOL = "BAN";
    string PROJECT_URI = "ipfs://Qme34ww9HuwnsWF6sYDpDfpSdYHpPCGsEyJULk1BikCVYp";
    string BASE_URI = "ipfs://";
    uint32 NATIVE_CURRENCY = uint32(uint160(JBConstants.NATIVE_TOKEN));
    uint32 ETH_CURRENCY = JBCurrencyIds.ETH;
    uint8 DECIMALS = 18;
    uint256 DECIMAL_MULTIPLIER = 10 ** DECIMALS;
    uint24 BANNY_BODY_CATEGORY = 0;
    address OPERATOR;
    address TRUSTED_FORWARDER;
    uint48 BAN_START_TIME = 1_740_435_044;
    uint104 BAN_MAINNET_AUTO_ISSUANCE_ = 545_296_034_092_246_678_345_976;
    uint104 BAN_BASE_AUTO_ISSUANCE_ = 10_097_684_379_816_492_953_872;
    uint104 BAN_OP_AUTO_ISSUANCE_ = 328_366_065_858_064_488_000;
    uint104 BAN_ARB_AUTO_ISSUANCE_ = 2_825_980_000_000_000_000_000;

    function configureSphinx() public override {
        sphinxConfig.projectName = "banny-core-v6";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public {
        // Get the operator address.
        OPERATOR = safeAddress();

        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(
            vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("node_modules/@bananapus/core-v6/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        hook = Hook721DeploymentLib.getDeployment(
            vm.envOr("NANA_721_DEPLOYMENT_PATH", string("node_modules/@bananapus/721-hook-v6/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        revnet = RevnetCoreDeploymentLib.getDeployment(
            vm.envOr("REVNET_CORE_DEPLOYMENT_PATH", string("node_modules/@rev-net/core-v6/deployments/"))
        );
        // Get the deployment addresses for the suckers contracts for this chain.
        suckers = SuckerDeploymentLib.getDeployment(
            vm.envOr("NANA_SUCKERS_DEPLOYMENT_PATH", string("node_modules/@bananapus/suckers-v6/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        routerTerminal = RouterTerminalDeploymentLib.getDeployment(
            vm.envOr(
                "NANA_ROUTER_TERMINAL_DEPLOYMENT_PATH",
                string("node_modules/@bananapus/router-terminal-v6/deployments/")
            )
        );

        TRUSTED_FORWARDER = core.controller.trustedForwarder();

        bannyverseConfig = getBannyverseRevnetConfig();

        // Perform the deployment transactions.
        deploy();
    }

    function getBannyverseRevnetConfig() internal view returns (BannyverseRevnetConfig memory) {
        // The terminals that the project will accept funds through.
        JBTerminalConfig[] memory terminalConfigurations = new JBTerminalConfig[](2);
        JBAccountingContext[] memory accountingContextsToAccept = new JBAccountingContext[](1);

        // Accept the chain's native currency through the multi terminal.
        accountingContextsToAccept[0] =
            JBAccountingContext({token: JBConstants.NATIVE_TOKEN, decimals: DECIMALS, currency: NATIVE_CURRENCY});

        terminalConfigurations[0] =
            JBTerminalConfig({terminal: core.terminal, accountingContextsToAccept: accountingContextsToAccept});

        terminalConfigurations[1] = JBTerminalConfig({
            terminal: IJBTerminal(address(routerTerminal.registry)),
            accountingContextsToAccept: new JBAccountingContext[](0)
        });

        JBSplit[] memory splits = new JBSplit[](1);
        splits[0] = JBSplit({
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(OPERATOR),
            preferAddToBalance: false,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // The project's revnet stage configurations.
        REVStageConfig[] memory stageConfigurations = new REVStageConfig[](3);

        {
            REVAutoIssuance[] memory autoIssuances = new REVAutoIssuance[](4);
            autoIssuances[0] = REVAutoIssuance({chainId: 1, count: BAN_MAINNET_AUTO_ISSUANCE_, beneficiary: OPERATOR});
            autoIssuances[1] = REVAutoIssuance({chainId: 8453, count: BAN_BASE_AUTO_ISSUANCE_, beneficiary: OPERATOR});
            autoIssuances[2] = REVAutoIssuance({chainId: 10, count: BAN_OP_AUTO_ISSUANCE_, beneficiary: OPERATOR});
            autoIssuances[3] = REVAutoIssuance({chainId: 42_161, count: BAN_ARB_AUTO_ISSUANCE_, beneficiary: OPERATOR});

            stageConfigurations[0] = REVStageConfig({
                startsAtOrAfter: BAN_START_TIME,
                autoIssuances: autoIssuances,
                splitPercent: 3800, // 38%
                splits: splits,
                initialIssuance: uint112(10_000 * DECIMAL_MULTIPLIER),
                issuanceCutFrequency: 60 days,
                issuanceCutPercent: 380_000_000, // 38%,
                cashOutTaxRate: 1000, // 0.1
                extraMetadata: 4 // Allow adding suckers.
            });
        }

        {
            REVAutoIssuance[] memory autoIssuances = new REVAutoIssuance[](1);
            autoIssuances[0] = REVAutoIssuance({
                chainId: PREMINT_CHAIN_ID, count: uint104(1_000_000 * DECIMAL_MULTIPLIER), beneficiary: OPERATOR
            });

            // decrease by a smaller percent more frequently. 30 days, 7%-ish.
            stageConfigurations[1] = REVStageConfig({
                startsAtOrAfter: uint40(stageConfigurations[0].startsAtOrAfter + 360 days),
                autoIssuances: autoIssuances,
                splitPercent: 3800, // 38%
                splits: splits,
                initialIssuance: 1, // inherit from previous cycle.
                issuanceCutFrequency: 21 days,
                issuanceCutPercent: 70_000_000, // 7%
                cashOutTaxRate: 1000, // 0.1
                extraMetadata: 4 // Allow adding suckers.
            });
        }

        stageConfigurations[2] = REVStageConfig({
            startsAtOrAfter: uint40(stageConfigurations[1].startsAtOrAfter + (1200 days)),
            autoIssuances: new REVAutoIssuance[](0),
            splitPercent: 0,
            splits: splits,
            initialIssuance: 0, // no more issuance.
            issuanceCutFrequency: 0,
            issuanceCutPercent: 0,
            cashOutTaxRate: 1000, // 0.1
            extraMetadata: 4 // Allow adding suckers.
        });

        REVConfig memory revnetConfiguration = REVConfig({
            description: REVDescription(NAME, SYMBOL, PROJECT_URI, ERC20_SALT),
            baseCurrency: ETH_CURRENCY,
            splitOperator: OPERATOR,
            stageConfigurations: stageConfigurations
        });

        // The project's NFT tiers.
        JB721TierConfig[] memory tiers = new JB721TierConfig[](4);

        tiers[0] = JB721TierConfig({
            price: uint104(1 * (10 ** DECIMALS)),
            initialSupply: 100,
            votingUnits: 0,
            reserveFrequency: 0,
            reserveBeneficiary: address(0),
            encodedIPFSUri: bytes32(""),
            category: BANNY_BODY_CATEGORY,
            discountPercent: 0,
            cannotIncreaseDiscountPercent: true,
            allowOwnerMint: false,
            useReserveBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: false,
            cannotBeRemoved: true,
            splitPercent: 0,
            splits: new JBSplit[](0)
        });
        tiers[1] = JB721TierConfig({
            price: uint104(1 * (10 ** (DECIMALS - 1))),
            initialSupply: 1000,
            votingUnits: 0,
            reserveFrequency: 0,
            reserveBeneficiary: address(0),
            encodedIPFSUri: bytes32(""),
            category: BANNY_BODY_CATEGORY,
            discountPercent: 0,
            cannotIncreaseDiscountPercent: true,
            allowOwnerMint: false,
            useReserveBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: false,
            cannotBeRemoved: true,
            splitPercent: 0,
            splits: new JBSplit[](0)
        });
        tiers[2] = JB721TierConfig({
            price: uint104(1 * (10 ** (DECIMALS - 2))),
            initialSupply: 10_000,
            votingUnits: 0,
            reserveFrequency: 0,
            reserveBeneficiary: address(0),
            encodedIPFSUri: bytes32(""),
            category: BANNY_BODY_CATEGORY,
            discountPercent: 0,
            cannotIncreaseDiscountPercent: true,
            allowOwnerMint: false,
            useReserveBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: false,
            cannotBeRemoved: true,
            splitPercent: 0,
            splits: new JBSplit[](0)
        });
        tiers[3] = JB721TierConfig({
            price: uint104(1 * (10 ** (DECIMALS - 4))),
            initialSupply: 999_999_999, // MAX
            votingUnits: 0,
            reserveFrequency: 0,
            reserveBeneficiary: address(0),
            encodedIPFSUri: bytes32(""),
            category: BANNY_BODY_CATEGORY,
            discountPercent: 0,
            cannotIncreaseDiscountPercent: true,
            allowOwnerMint: false,
            useReserveBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: false,
            cannotBeRemoved: true,
            splitPercent: 0,
            splits: new JBSplit[](0)
        });

        // Organize the instructions for how this project will connect to other chains.
        JBTokenMapping[] memory tokenMappings = new JBTokenMapping[](1);
        tokenMappings[0] = JBTokenMapping({
            localToken: JBConstants.NATIVE_TOKEN,
            minGas: 200_000,
            remoteToken: bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN))),
            minBridgeAmount: 0.01 ether
        });

        JBSuckerDeployerConfig[] memory suckerDeployerConfigurations;
        if (block.chainid == 1 || block.chainid == 11_155_111) {
            suckerDeployerConfigurations = new JBSuckerDeployerConfig[](3);
            // OP
            suckerDeployerConfigurations[0] =
                JBSuckerDeployerConfig({deployer: suckers.optimismDeployer, mappings: tokenMappings});

            suckerDeployerConfigurations[1] =
                JBSuckerDeployerConfig({deployer: suckers.baseDeployer, mappings: tokenMappings});

            suckerDeployerConfigurations[2] =
                JBSuckerDeployerConfig({deployer: suckers.arbitrumDeployer, mappings: tokenMappings});
        } else {
            suckerDeployerConfigurations = new JBSuckerDeployerConfig[](1);
            // L2 -> Mainnet
            suckerDeployerConfigurations[0] = JBSuckerDeployerConfig({
                deployer: address(suckers.optimismDeployer) != address(0)
                    ? suckers.optimismDeployer
                    : address(suckers.baseDeployer) != address(0) ? suckers.baseDeployer : suckers.arbitrumDeployer,
                mappings: tokenMappings
            });

            if (address(suckerDeployerConfigurations[0].deployer) == address(0)) {
                revert("L2 > L1 Sucker is not configured");
            }
        }

        // Specify all sucker deployments.
        REVSuckerDeploymentConfig memory suckerDeploymentConfiguration =
            REVSuckerDeploymentConfig({deployerConfigurations: suckerDeployerConfigurations, salt: SUCKER_SALT});

        return BannyverseRevnetConfig({
            configuration: revnetConfiguration,
            terminalConfigurations: terminalConfigurations,
            suckerDeploymentConfiguration: suckerDeploymentConfiguration,
            hookConfiguration: REVDeploy721TiersHookConfig({
                baseline721HookConfiguration: JBDeploy721TiersHookConfig({
                    name: "Banny Retail",
                    symbol: "BANNY",
                    baseUri: BASE_URI,
                    tokenUriResolver: IJB721TokenUriResolver(address(0)), // This will be replaced once we know the
                    // address.
                    contractUri: "https://jbm.infura-ipfs.io/ipfs/Qmd2hgb1E4caEB51VvoC3GvonhwkCoVyXjJ3zqsCxHPTKK",
                    tiersConfig: JB721InitTiersConfig({
                        tiers: tiers, currency: ETH_CURRENCY, decimals: DECIMALS, prices: core.prices
                    }),
                    reserveBeneficiary: address(0),
                    flags: JB721TiersHookFlags({
                        noNewTiersWithReserves: false,
                        noNewTiersWithVotes: false,
                        noNewTiersWithOwnerMinting: false,
                        preventOverspending: false
                    })
                }),
                salt: HOOK_SALT,
                splitOperatorCanAdjustTiers: true,
                splitOperatorCanUpdateMetadata: true,
                splitOperatorCanMint: true,
                splitOperatorCanIncreaseDiscountPercent: true
            })
        });
    }

    function deploy() public sphinx {
        // Deploy the Banny URI Resolver.
        Banny721TokenUriResolver resolver;

        string memory _BANNY_BODY =
            '<g class="a1"><path d="M173 53h4v17h-4z"/></g><g class="a2"><path d="M167 57h3v10h-3z"/><path d="M169 53h4v17h-4z"/></g><g class="a3"><path d="M167 53h3v4h-3z"/><path d="M163 57h4v10h-4z"/><path d="M167 67h3v3h-3z"/></g><g class="b1"><path d="M213 253h-3v-3-3h-3v-7-3h-4v-10h-3v-7-7-3h-3v-73h-4v-10h-3v-10h-3v-7h-4v-7h-3v-3h-3v-3h-4v10h4v10h3v10h3v3h4v7 3 70 3h3v7h3v20h4v7h3v3h3v3h4v4h3v3h3v-3-4z"/><path d="M253 307v-4h-3v-3h-3v-3h-4v-4h-3v-3h-3v-3h-4v-4h-3v-3h-3v-3h-4v-4h-3v-6h-3v-7h-4v17h4v3h3v3h3 4v4h3v3h3v3h4v4h3v3h3v3h4v4h3v3h3v3h4v-6h-4z"/></g><g class="b2"><path d="M250 310v-3h-3v-4h-4v-3h-3v-3h-3v-4h-4v-3h-3v-3h-3v-4h-7v-3h-3v-3h-4v-17h-3v-3h-3v-4h-4v-3h-3v-3h-3v-7h-4v-20h-3v-7h-3v-73-3-7h-4v-3h-3v-10h-3v-10h-4V70h-3v-3l-3 100 3-100v40h-3v10h-4v6h-3v14h-3v3 13h-4v44h4v16h3v14h3v13h4v10h3v7h3v3h4v3h3v4h3v3h4v3h3v4h3v3h4v3h3v7h7v7h6v3h7v3h7v4h13v3h3v3h10v-3h-3zm-103-87v-16h3v-10h-3v6h-4v17h-3v10h3v-7h4z"/><path d="M143 230h4v7h-4zm4 10h3v3h-3zm3 7h3v3h-3zm3 6h4v4h-4z"/><path d="M163 257h-6v3h3v3h3v4h4v-4-3h-4v-3z"/></g><g class="b3"><path d="M143 197v6h4v-6h6v-44h4v-16h3v-14h3v-6h4v-10h3V97h-7v6h-3v4h-3v3h-4v3h-3v4 3h-3v3 4h-4v10h-3v16 4h-3v46h3v-6h3z"/><path d="M140 203h3v17h-3z"/><path d="M137 220h3v10h-3z"/><path d="M153 250h-3v-7h-3v-6h-4v-7h-3v10h3v7h4v6h3v4h3v-7zm-3 10h3v7h-3z"/><path d="M147 257h3v3h-3zm6 0h4v3h-4z"/><path d="M160 263v-3h-3v3 7h6v-7h-3zm-10-56v16h-3v7h3v10h3v7h4v6h6v4h7v-4-3h-3v-10h-4v-13h-3v-14h-3v-16h-4v10h-3z"/><path d="M243 313v-3h-3v-3h-10-3v-4h-7v-3h-7v-3h-6v-7h-7v-7h-3v-3h-4v-3h-3v-4h-3v-3h-4v-3h-3v-4h-3v-3h-4v-3h-3v10h-3v3h-4v3h-3v7h3v7h4v6h3v5h4v3h6v3h3v3h4 3v3h3 4v3h3 3v4h10v3h7 7 3v3h10 3v-3h10v-3h4v-4h-14z"/></g><g class="b4"><path d="M183 130h4v7h-4z"/><path d="M180 127h3v3h-3zm-27-4h4v7h-4z"/><path d="M157 117h3v6h-3z"/><path d="M160 110h3v7h-3z"/><path d="M163 107h4v3h-4zm-3 83h3v7h-3z"/><path d="M163 187h4v3h-4zm20 0h7v3h-7z"/><path d="M180 190h3v3h-3zm10-7h3v4h-3z"/><path d="M193 187h4v6h-4zm-20 53h4v7h-4z"/><path d="M177 247h3v6h-3z"/><path d="M180 253h3v7h-3z"/><path d="M183 260h7v3h-7z"/><path d="M190 263h3v4h-3zm0-20h3v4h-3z"/><path d="M187 240h3v3h-3z"/><path d="M190 237h3v3h-3zm13 23h4v3h-4z"/><path d="M207 263h3v7h-3z"/><path d="M210 270h3v3h-3zm-10 7h3v6h-3z"/><path d="M203 283h4v7h-4z"/><path d="M207 290h6v3h-6z"/></g><g class="o"><path d="M133 157h4v50h-4zm0 63h4v10h-4zm27-163h3v10h-3z"/><path d="M163 53h4v4h-4z"/><path d="M167 50h10v3h-10z"/><path d="M177 53h3v17h-3z"/><path d="M173 70h4v27h-4zm-6 0h3v27h-3z"/><path d="M163 67h4v3h-4zm0 30h4v3h-4z"/><path d="M160 100h3v3h-3z"/><path d="M157 103h3v4h-3z"/><path d="M153 107h4v3h-4z"/><path d="M150 110h3v3h-3z"/><path d="M147 113h3v7h-3z"/><path d="M143 120h4v7h-4z"/><path d="M140 127h3v10h-3z"/><path d="M137 137h3v20h-3zm56-10h4v10h-4z"/><path d="M190 117h3v10h-3z"/><path d="M187 110h3v7h-3z"/><path d="M183 103h4v7h-4z"/><path d="M180 100h3v3h-3z"/><path d="M177 97h3v3h-3zm-40 106h3v17h-3zm0 27h3v10h-3zm10 30h3v7h-3z"/><path d="M150 257v-4h-3v-6h-4v-7h-3v10h3v10h4v-3h3z"/><path d="M150 257h3v3h-3z"/><path d="M163 273v-3h-6v-10h-4v7h-3v3h3v3h4v7h3v-7h3z"/><path d="M163 267h4v3h-4z"/><path d="M170 257h-3-4v3h4v7h3v-10z"/><path d="M157 253h6v4h-6z"/><path d="M153 247h4v6h-4z"/><path d="M150 240h3v7h-3z"/><path d="M147 230h3v10h-3zm13 50h3v7h-3z"/><path d="M143 223h4v7h-4z"/><path d="M147 207h3v16h-3z"/><path d="M150 197h3v10h-3zm-10 0h3v6h-3zm50 113h7v3h-7zm23 10h17v3h-17z"/><path d="M230 323h13v4h-13z"/><path d="M243 320h10v3h-10z"/><path d="M253 317h4v3h-4z"/><path d="M257 307h3v10h-3z"/><path d="M253 303h4v4h-4z"/><path d="M250 300h3v3h-3z"/><path d="M247 297h3v3h-3z"/><path d="M243 293h4v4h-4z"/><path d="M240 290h3v3h-3z"/><path d="M237 287h3v3h-3z"/><path d="M233 283h4v4h-4z"/><path d="M230 280h3v3h-3z"/><path d="M227 277h3v3h-3z"/><path d="M223 273h4v4h-4z"/><path d="M220 267h3v6h-3z"/><path d="M217 260h3v7h-3z"/><path d="M213 253h4v7h-4z"/><path d="M210 247h3v6h-3z"/><path d="M207 237h3v10h-3z"/><path d="M203 227h4v10h-4zm-40 60h4v6h-4zm24 20h3v3h-3z"/><path d="M167 293h3v5h-3zm16 14h4v3h-4z"/><path d="M170 298h4v3h-4zm10 6h3v3h-3z"/><path d="M174 301h6v3h-6zm23 12h6v4h-6z"/><path d="M203 317h10v3h-10zm-2-107v-73h-4v73h3v17h3v-17h-2z"/></g><g class="o"><path d="M187 307v-4h3v-6h-3v-4h-4v-3h-3v-3h-7v-4h-6v4h-4v3h4v27h-4v13h-3v10h-4v7h4v3h3 10 14v-3h-4v-4h-3v-3h-3v-3h-4v-7h4v-10h3v-7h3v-3h7v-3h-3zm16 10v-4h-6v17h-4v10h-3v7h3v3h4 6 4 3 14v-3h-4v-4h-7v-3h-3v-3h-3v-10h3v-7h3v-3h-10z"/></g>';
        string memory _DEFAULT_NECKLACE =
            '<g class="o"><path d="M190 173h-37v-3h-10v-4h-6v4h3v3h-3v4h6v3h10v4h37v-4h3v-3h-3v-4zm-40 4h-3v-4h3v4zm7 3v-3h3v3h-3zm6 0v-3h4v3h-4zm7 0v-3h3v3h-3zm7 0v-3h3v3h-3zm10 0h-4v-3h4v3z"/><path d="M190 170h3v3h-3z"/><path d="M193 166h4v4h-4zm0 7h4v4h-4z"/></g><g class="w"><path d="M137 170h3v3h-3zm10 3h3v4h-3zm10 4h3v3h-3zm6 0h4v3h-4zm7 0h3v3h-3zm7 0h3v3h-3zm6 0h4v3h-4zm7-4h3v4h-3z"/><path d="M193 170h4v3h-4z"/></g>';
        string memory _DEFAULT_MOUTH =
            '<g class="o"><path d="M183 160v-4h-20v4h-3v3h3v4h24v-7h-4zm-13 3v-3h10v3h-10z" fill="#ad71c8"/><path d="M170 160h10v3h-10z"/></g>';
        string memory _DEFAULT_STANDARD_EYES =
            '<g class="o"><path d="M177 140v3h6v11h10v-11h4v-3h-20z"/><path d="M153 140v3h7v8 3h7 3v-11h3v-3h-20z"/></g><g class="w"><path d="M153 143h7v4h-7z"/><path d="M157 147h3v3h-3zm20-4h6v4h-6z"/><path d="M180 147h3v3h-3z"/></g>';
        string memory _DEFAULT_ALIEN_EYES =
            '<g class="o"><path d="M190 127h3v3h-3zm3 13h4v3h-4zm-42 0h6v6h-6z"/><path d="M151 133h3v7h-3zm10 0h6v4h-6z"/><path d="M157 137h17v6h-17zm3 13h14v3h-14zm17-13h7v16h-7z"/><path d="M184 137h6v6h-6zm0 10h10v6h-10z"/><path d="M187 143h10v4h-10z"/><path d="M190 140h3v3h-3zm-6-10h3v7h-3z"/><path d="M187 130h6v3h-6zm-36 0h10v3h-10zm16 13h7v7h-7zm-10 0h7v7h-7z"/><path d="M164 147h3v3h-3zm29-20h4v6h-4z"/><path d="M194 133h3v7h-3z"/></g><g class="w"><path d="M154 133h7v4h-7z"/><path d="M154 137h3v3h-3zm10 6h3v4h-3zm20 0h3v4h-3zm3-10h7v4h-7z"/><path d="M190 137h4v3h-4z"/></g>';
        {
            // Perform the check for the resolver..
            (address _resolver, bool _resolverIsDeployed) = _isDeployed(
                RESOLVER_SALT,
                type(Banny721TokenUriResolver).creationCode,
                abi.encode(
                    _BANNY_BODY,
                    _DEFAULT_NECKLACE,
                    _DEFAULT_MOUTH,
                    _DEFAULT_STANDARD_EYES,
                    _DEFAULT_ALIEN_EYES,
                    OPERATOR,
                    TRUSTED_FORWARDER
                )
            );
            // Deploy it if it has not been deployed yet.
            resolver = !_resolverIsDeployed
                ? new Banny721TokenUriResolver{salt: RESOLVER_SALT}(
                    _BANNY_BODY,
                    _DEFAULT_NECKLACE,
                    _DEFAULT_MOUTH,
                    _DEFAULT_STANDARD_EYES,
                    _DEFAULT_ALIEN_EYES,
                    OPERATOR,
                    TRUSTED_FORWARDER
                )
                : Banny721TokenUriResolver(_resolver);
        }

        // Set the resolver's metadata.
        resolver.setMetadata(
            "A piece of Banny Retail.", "https://retail.banny.eth.shop", "https://bannyverse.infura-ipfs.io/ipfs/"
        );

        // Update our config with its address.
        bannyverseConfig.hookConfiguration.baseline721HookConfiguration.tokenUriResolver = resolver;

        // Deploy the $BANNY Revnet.
        revnet.basic_deployer
            .deployWith721sFor({
                revnetId: 0,
                configuration: bannyverseConfig.configuration,
                terminalConfigurations: bannyverseConfig.terminalConfigurations,
                suckerDeploymentConfiguration: bannyverseConfig.suckerDeploymentConfiguration,
                tiered721HookConfiguration: bannyverseConfig.hookConfiguration,
                allowedPosts: new REVCroptopAllowedPost[](0)
            });
    }

    function _isDeployed(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory arguments
    )
        internal
        view
        returns (address, bool)
    {
        address _deployedTo = vm.computeCreate2Address({
            salt: salt,
            initCodeHash: keccak256(abi.encodePacked(creationCode, arguments)),
            // Arachnid/deterministic-deployment-proxy address.
            deployer: address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        });

        // Return if code is already present at this address.
        return (_deployedTo, address(_deployedTo).code.length != 0);
    }
}
