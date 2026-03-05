// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v5/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

/// @notice Migration contract for Base to handle standalone outfits and backgrounds
/// that are not worn/used by any banny. These assets are minted to this contract
/// and then transferred directly to their owners.
contract MigrationContractBase5 {
    address[] private transferOwners;

    constructor(address[] memory _transferOwners) {
        transferOwners = _transferOwners;
    }

    function executeMigration(
        address hookAddress,
        address resolverAddress,
        address v4HookAddress,
        address v4ResolverAddress,
        address fallbackV4ResolverAddress
    )
        external
    {
        // Validate addresses
        require(hookAddress != address(0), "Hook address not set");
        require(resolverAddress != address(0), "Resolver address not set");
        require(v4HookAddress != address(0), "V4 Hook address not set");
        require(v4ResolverAddress != address(0), "V4 Resolver address not set");
        require(fallbackV4ResolverAddress != address(0), "V4 fallback resolver address not set");

        JB721TiersHook hook = JB721TiersHook(hookAddress);
        IERC721 v4Hook = IERC721(v4HookAddress);

        // Base migration - Standalone outfits and backgrounds (53 items)
        // These are assets that are NOT being worn/used by any banny

        // Assets are already minted to this contract by the deployer
        // V5 token IDs are calculated based on mint order (continuing from previous chunks)
        // V4 token IDs are the original token IDs from V4

        // Generate token IDs - store both V5 minted token IDs and original V4 token IDs
        uint256[] memory v5TokenIds = new uint256[](transferOwners.length);
        uint256[] memory v4TokenIds = new uint256[](transferOwners.length);
        v5TokenIds[0] = 5_000_000_004; // Minted V5 Token ID
        v4TokenIds[0] = 5_000_000_002; // Original V4 Token ID
        v5TokenIds[1] = 5_000_000_005; // Minted V5 Token ID
        v4TokenIds[1] = 5_000_000_005; // Original V4 Token ID
        v5TokenIds[2] = 6_000_000_005; // Minted V5 Token ID
        v4TokenIds[2] = 6_000_000_002; // Original V4 Token ID
        v5TokenIds[3] = 7_000_000_001; // Minted V5 Token ID
        v4TokenIds[3] = 7_000_000_001; // Original V4 Token ID
        v5TokenIds[4] = 10_000_000_006; // Minted V5 Token ID
        v4TokenIds[4] = 10_000_000_002; // Original V4 Token ID
        v5TokenIds[5] = 10_000_000_007; // Minted V5 Token ID
        v4TokenIds[5] = 10_000_000_006; // Original V4 Token ID
        v5TokenIds[6] = 10_000_000_008; // Minted V5 Token ID
        v4TokenIds[6] = 10_000_000_008; // Original V4 Token ID
        v5TokenIds[7] = 10_000_000_009; // Minted V5 Token ID
        v4TokenIds[7] = 10_000_000_009; // Original V4 Token ID
        v5TokenIds[8] = 10_000_000_010; // Minted V5 Token ID
        v4TokenIds[8] = 10_000_000_010; // Original V4 Token ID
        v5TokenIds[9] = 10_000_000_011; // Minted V5 Token ID
        v4TokenIds[9] = 10_000_000_011; // Original V4 Token ID
        v5TokenIds[10] = 11_000_000_002; // Minted V5 Token ID
        v4TokenIds[10] = 11_000_000_002; // Original V4 Token ID
        v5TokenIds[11] = 11_000_000_003; // Minted V5 Token ID
        v4TokenIds[11] = 11_000_000_003; // Original V4 Token ID
        v5TokenIds[12] = 13_000_000_002; // Minted V5 Token ID
        v4TokenIds[12] = 13_000_000_002; // Original V4 Token ID
        v5TokenIds[13] = 14_000_000_004; // Minted V5 Token ID
        v4TokenIds[13] = 14_000_000_004; // Original V4 Token ID
        v5TokenIds[14] = 17_000_000_001; // Minted V5 Token ID
        v4TokenIds[14] = 17_000_000_001; // Original V4 Token ID
        v5TokenIds[15] = 19_000_000_008; // Minted V5 Token ID
        v4TokenIds[15] = 19_000_000_002; // Original V4 Token ID
        v5TokenIds[16] = 19_000_000_009; // Minted V5 Token ID
        v4TokenIds[16] = 19_000_000_004; // Original V4 Token ID
        v5TokenIds[17] = 19_000_000_010; // Minted V5 Token ID
        v4TokenIds[17] = 19_000_000_010; // Original V4 Token ID
        v5TokenIds[18] = 19_000_000_011; // Minted V5 Token ID
        v4TokenIds[18] = 19_000_000_011; // Original V4 Token ID
        v5TokenIds[19] = 19_000_000_012; // Minted V5 Token ID
        v4TokenIds[19] = 19_000_000_012; // Original V4 Token ID
        v5TokenIds[20] = 24_000_000_001; // Minted V5 Token ID
        v4TokenIds[20] = 24_000_000_001; // Original V4 Token ID
        v5TokenIds[21] = 25_000_000_009; // Minted V5 Token ID
        v4TokenIds[21] = 25_000_000_003; // Original V4 Token ID
        v5TokenIds[22] = 28_000_000_007; // Minted V5 Token ID
        v4TokenIds[22] = 28_000_000_003; // Original V4 Token ID
        v5TokenIds[23] = 28_000_000_008; // Minted V5 Token ID
        v4TokenIds[23] = 28_000_000_006; // Original V4 Token ID
        v5TokenIds[24] = 28_000_000_009; // Minted V5 Token ID
        v4TokenIds[24] = 28_000_000_009; // Original V4 Token ID
        v5TokenIds[25] = 28_000_000_010; // Minted V5 Token ID
        v4TokenIds[25] = 28_000_000_010; // Original V4 Token ID
        v5TokenIds[26] = 31_000_000_003; // Minted V5 Token ID
        v4TokenIds[26] = 31_000_000_003; // Original V4 Token ID
        v5TokenIds[27] = 31_000_000_004; // Minted V5 Token ID
        v4TokenIds[27] = 31_000_000_004; // Original V4 Token ID
        v5TokenIds[28] = 31_000_000_005; // Minted V5 Token ID
        v4TokenIds[28] = 31_000_000_005; // Original V4 Token ID
        v5TokenIds[29] = 31_000_000_006; // Minted V5 Token ID
        v4TokenIds[29] = 31_000_000_006; // Original V4 Token ID
        v5TokenIds[30] = 32_000_000_002; // Minted V5 Token ID
        v4TokenIds[30] = 32_000_000_002; // Original V4 Token ID
        v5TokenIds[31] = 34_000_000_001; // Minted V5 Token ID
        v4TokenIds[31] = 34_000_000_001; // Original V4 Token ID
        v5TokenIds[32] = 35_000_000_002; // Minted V5 Token ID
        v4TokenIds[32] = 35_000_000_001; // Original V4 Token ID
        v5TokenIds[33] = 35_000_000_003; // Minted V5 Token ID
        v4TokenIds[33] = 35_000_000_003; // Original V4 Token ID
        v5TokenIds[34] = 35_000_000_004; // Minted V5 Token ID
        v4TokenIds[34] = 35_000_000_004; // Original V4 Token ID
        v5TokenIds[35] = 38_000_000_003; // Minted V5 Token ID
        v4TokenIds[35] = 38_000_000_003; // Original V4 Token ID
        v5TokenIds[36] = 39_000_000_002; // Minted V5 Token ID
        v4TokenIds[36] = 39_000_000_002; // Original V4 Token ID
        v5TokenIds[37] = 40_000_000_002; // Minted V5 Token ID
        v4TokenIds[37] = 40_000_000_002; // Original V4 Token ID
        v5TokenIds[38] = 40_000_000_003; // Minted V5 Token ID
        v4TokenIds[38] = 40_000_000_003; // Original V4 Token ID
        v5TokenIds[39] = 41_000_000_002; // Minted V5 Token ID
        v4TokenIds[39] = 41_000_000_002; // Original V4 Token ID
        v5TokenIds[40] = 42_000_000_001; // Minted V5 Token ID
        v4TokenIds[40] = 42_000_000_001; // Original V4 Token ID
        v5TokenIds[41] = 42_000_000_002; // Minted V5 Token ID
        v4TokenIds[41] = 42_000_000_002; // Original V4 Token ID
        v5TokenIds[42] = 43_000_000_007; // Minted V5 Token ID
        v4TokenIds[42] = 43_000_000_001; // Original V4 Token ID
        v5TokenIds[43] = 43_000_000_008; // Minted V5 Token ID
        v4TokenIds[43] = 43_000_000_004; // Original V4 Token ID
        v5TokenIds[44] = 44_000_000_004; // Minted V5 Token ID
        v4TokenIds[44] = 44_000_000_002; // Original V4 Token ID
        v5TokenIds[45] = 44_000_000_005; // Minted V5 Token ID
        v4TokenIds[45] = 44_000_000_003; // Original V4 Token ID
        v5TokenIds[46] = 47_000_000_004; // Minted V5 Token ID
        v4TokenIds[46] = 47_000_000_002; // Original V4 Token ID
        v5TokenIds[47] = 47_000_000_005; // Minted V5 Token ID
        v4TokenIds[47] = 47_000_000_004; // Original V4 Token ID
        v5TokenIds[48] = 47_000_000_006; // Minted V5 Token ID
        v4TokenIds[48] = 47_000_000_006; // Original V4 Token ID
        v5TokenIds[49] = 47_000_000_007; // Minted V5 Token ID
        v4TokenIds[49] = 47_000_000_007; // Original V4 Token ID
        v5TokenIds[50] = 47_000_000_008; // Minted V5 Token ID
        v4TokenIds[50] = 47_000_000_008; // Original V4 Token ID
        v5TokenIds[51] = 49_000_000_001; // Minted V5 Token ID
        v4TokenIds[51] = 49_000_000_001; // Original V4 Token ID
        v5TokenIds[52] = 49_000_000_002; // Minted V5 Token ID
        v4TokenIds[52] = 49_000_000_002; // Original V4 Token ID

        uint256 successfulTransfers = 0;

        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 v5TokenId = v5TokenIds[i];
            uint256 v4TokenId = v4TokenIds[i];

            // Verify V4 ownership using the original V4 token ID
            // This will revert if the token doesn't exist, which indicates a data issue
            address v4Owner = v4Hook.ownerOf(v4TokenId);
            address expectedOwner = transferOwners[i];

            // If V4 owner is the main resolver, this token is being worn/used and shouldn't be in unused assets
            // contract
            require(
                v4Owner != address(v4ResolverAddress),
                "Token owned by main resolver in V4 - should not be in unused assets contract"
            );

            // Special case: If V4 owner is the fallback resolver BUT expected owner is NOT a resolver,
            // this is valid - the asset is being worn in V4 but we're minting directly to the actual owner in V5
            // raw.json already accounts for this and has the correct owner
            if (v4Owner == address(fallbackV4ResolverAddress)) {
                // Allow if expected owner is not a resolver (we're minting directly to owner in V5)
                require(
                    expectedOwner != address(v4ResolverAddress) && expectedOwner != address(fallbackV4ResolverAddress),
                    "Token owned by fallback resolver in V4 but expected owner is also a resolver - should not be in unused assets contract"
                );
                // Skip ownership verification in this case - we trust raw.json
            } else {
                // For all other cases, verify V4 owner matches expected owner
                require(v4Owner == expectedOwner, "V4/V5 ownership mismatch for token");
            }

            // Verify this contract owns the V5 token before transferring
            require(hook.ownerOf(v5TokenId) == address(this), "Contract does not own token");

            // Transfer using the minted V5 token ID
            IERC721(address(hook)).safeTransferFrom(address(this), transferOwners[i], v5TokenId);
            successfulTransfers++;
        }

        // Verify all expected items were transferred
        require(successfulTransfers == transferOwners.length, "Not all items were transferred");

        // Final verification: Ensure this contract no longer owns any tokens
        // This ensures all transfers completed successfully and no tokens were left behind
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");

        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)

        // // Collect unique owners
        // address[] memory uniqueOwners = new address[](12);

        // uniqueOwners[0] = 0x8b80755C441d355405CA7571443Bb9247B77Ec16;
        // uniqueOwners[1] = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
        // uniqueOwners[2] = 0x328809A567b87b6123462c3062e8438BBB75c1c5;
        // uniqueOwners[3] = 0xFB46349c0A3F04150E8c731B3A4fC415b0850CE3;
        // uniqueOwners[4] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        // uniqueOwners[5] = 0xFd37f4625CA5816157D55a5b3F7Dd8DD5F8a0C2F;
        // uniqueOwners[6] = 0x18deEE9699526f8C8a87004b2e4e55029Fb26b9a;
        // uniqueOwners[7] = 0xbeC26FFa12c90217943D1b2958f60A821aE6E549;
        // uniqueOwners[8] = 0x99Fa48ccEa8a38CDE6B437450fF9bBdDAFAA4Fc8;
        // uniqueOwners[9] = 0x565B93a15d38aCD79c120b15432D21E21eD274d6;
        // uniqueOwners[10] = 0x8DFBdEEC8c5d4970BB5F481C6ec7f73fa1C65be5;
        // uniqueOwners[11] = 0x1C51517d8277C9aD6d701Fb5394ceC0C18219eDb;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](25);

        // uniqueTierIds[0] = 5;
        // uniqueTierIds[1] = 6;
        // uniqueTierIds[2] = 7;
        // uniqueTierIds[3] = 10;
        // uniqueTierIds[4] = 11;
        // uniqueTierIds[5] = 13;
        // uniqueTierIds[6] = 14;
        // uniqueTierIds[7] = 17;
        // uniqueTierIds[8] = 19;
        // uniqueTierIds[9] = 24;
        // uniqueTierIds[10] = 25;
        // uniqueTierIds[11] = 28;
        // uniqueTierIds[12] = 31;
        // uniqueTierIds[13] = 32;
        // uniqueTierIds[14] = 34;
        // uniqueTierIds[15] = 35;
        // uniqueTierIds[16] = 38;
        // uniqueTierIds[17] = 39;
        // uniqueTierIds[18] = 40;
        // uniqueTierIds[19] = 41;
        // uniqueTierIds[20] = 42;
        // uniqueTierIds[21] = 43;
        // uniqueTierIds[22] = 44;
        // uniqueTierIds[23] = 47;
        // uniqueTierIds[24] = 49;

        // // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)
        // MigrationHelper.verifyTierBalances(
        //     hookAddress,
        //     v4HookAddress,
        //     fallbackV4ResolverAddress,
        //     uniqueOwners,
        //     uniqueTierIds
        // );
    }
}
