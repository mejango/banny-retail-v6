// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, stdJson} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";

import {IJBController} from "@bananapus/core-v6/src/interfaces/IJBController.sol";
import {IJBRulesets} from "@bananapus/core-v6/src/interfaces/IJBRulesets.sol";
import {IJBSplits} from "@bananapus/core-v6/src/interfaces/IJBSplits.sol";
import {IJBSplitHook} from "@bananapus/core-v6/src/interfaces/IJBSplitHook.sol";
import {JBRuleset} from "@bananapus/core-v6/src/structs/JBRuleset.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";
import {JBSplitGroup} from "@bananapus/core-v6/src/structs/JBSplitGroup.sol";
import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBSplitGroupIds} from "@bananapus/core-v6/src/libraries/JBSplitGroupIds.sol";

/// @notice Repoint Banny's (project 4) reserved-token split hook to the fixed JBP6FeeLPSplitHook instance.
///
/// Banny is a revnet whose reserved-token split routes 100% to an LP split hook clone. That clone was first wired at
/// deploy time and still points at an older implementation that carries the `findHighestValueTerminalTokenOf` DoS bug;
/// the fixed clone lives at `_NEW_LP_SPLIT_HOOK`. The three revnet stages were each laid down as a distinct ruleset
/// (ids form a `basedOnId` chain), and every one already carries the old hook — so this walks the chain and updates
/// each stage's reserved split to the fixed instance.
///
/// Submitted to the `banny-core` Safe, which is Banny's revnet operator and holds `SET_SPLIT_GROUPS` (permission 19)
/// on project 4 — so `JBController.setSplitGroupsOf` passes the permission gate directly (no REVDeployer
/// indirection).
/// Idempotent: a ruleset already on the fixed hook, or a beneficiary-only split (e.g. OP Sepolia, which has no LP
/// stack), is skipped. Propose per `deploy:banny-lp-split-hook:{testnets,mainnets}`.
contract SetBannyLpSplitHook is Script, Sphinx {
    using stdJson for string;

    uint256 private constant _BAN_PROJECT_ID = 4;

    /// @notice The fixed LP split hook instance (a clone of the DoS-fixed implementation).
    IJBSplitHook private constant _NEW_LP_SPLIT_HOOK = IJBSplitHook(0xe9493BC776699714A89aA982Cf828d843f040d2a);

    /// @notice Upper bound on the stage walk (Banny has 3 stages; the loop also stops at `basedOnId == 0`).
    uint256 private constant _MAX_STAGES = 12;

    function configureSphinx() public override {
        sphinxConfig.projectName = "banny-core";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public {
        deploy();
    }

    function deploy() public sphinx {
        IJBController controller = IJBController(_deploymentAddressOf("JBController"));
        IJBRulesets rulesets = controller.RULESETS();
        IJBSplits splits = controller.SPLITS();

        // The new reserved-token split group: 100% routed to the fixed LP hook. Mirrors the deploy config, which uses
        // a zero beneficiary in LP-hook mode.
        JBSplit[] memory newSplits = new JBSplit[](1);
        newSplits[0] = JBSplit({
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(address(0)),
            preferAddToBalance: false,
            lockedUntil: 0,
            hook: _NEW_LP_SPLIT_HOOK
        });
        JBSplitGroup[] memory newGroups = new JBSplitGroup[](1);
        newGroups[0] = JBSplitGroup({groupId: JBSplitGroupIds.RESERVED_TOKENS, splits: newSplits});

        // Walk the stage rulesets (latest queued → `basedOnId` chain) and repoint each whose reserved split still
        // routes to an OLD hook. A cycling ruleset keeps the same id across cycles, so one update per stage covers it.
        (JBRuleset memory latestQueued,) = rulesets.latestQueuedOf(_BAN_PROJECT_ID);
        uint256 rulesetId = latestQueued.id;
        uint256 updated;
        for (uint256 i; i < _MAX_STAGES && rulesetId != 0; i++) {
            JBSplit[] memory current = splits.splitsOf(_BAN_PROJECT_ID, rulesetId, JBSplitGroupIds.RESERVED_TOKENS);
            if (
                current.length == 1 && address(current[0].hook) != address(0)
                    && address(current[0].hook) != address(_NEW_LP_SPLIT_HOOK)
            ) {
                controller.setSplitGroupsOf(_BAN_PROJECT_ID, rulesetId, newGroups);
                updated++;
            }
            rulesetId = rulesets.getRulesetOf(_BAN_PROJECT_ID, rulesetId).basedOnId;
        }

        console.log("[SetBannyLpSplitHook] chain", block.chainid, "rulesets repointed:", updated);
    }

    function _deploymentAddressOf(string memory name) internal view returns (address addr) {
        string memory root = vm.envOr("BANNY_DEPLOYMENTS_PATH", string("../deploy-all-v6/deployments/"));
        string memory path = string.concat(root, _chainFolder(), "/", name, ".json");
        addr = vm.readFile(path).readAddress(".address");
        require(addr != address(0), "Missing deployment address");
    }

    function _chainFolder() internal view returns (string memory) {
        if (block.chainid == 1) return "ethereum";
        if (block.chainid == 11_155_111) return "sepolia";
        if (block.chainid == 10) return "optimism";
        if (block.chainid == 11_155_420) return "optimism_sepolia";
        if (block.chainid == 8453) return "base";
        if (block.chainid == 84_532) return "base_sepolia";
        if (block.chainid == 42_161) return "arbitrum";
        if (block.chainid == 421_614) return "arbitrum_sepolia";
        revert("Unsupported chain");
    }
}
