// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MigrationHelper} from "./helpers/MigrationHelper.sol";

contract MigrationContractEthereum6 {
    // Define struct to hold all UPC minted tokenIds
    struct MintedIds {
        uint256[18] upc4;
        uint256[1] upc6;
        uint256[1] upc15;
        uint256[3] upc19;
        uint256[2] upc25;
        uint256[1] upc29;
        uint256[2] upc31;
        uint256[1] upc38;
        uint256[2] upc43;
    }

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
        Banny721TokenUriResolver resolver = Banny721TokenUriResolver(resolverAddress);
        IERC721 v4Hook = IERC721(v4HookAddress);
        Banny721TokenUriResolver v4Resolver = Banny721TokenUriResolver(v4ResolverAddress);
        Banny721TokenUriResolver fallbackV4Resolver = Banny721TokenUriResolver(fallbackV4ResolverAddress);

        // Ethereum migration chunk 6/6 - 31 items

        // Step 1: Assets are already minted to this contract by the deployer

        // Assets are already minted to this contract by the deployer

        // Create and populate the struct
        // Token IDs follow formula: upc * 1000000000 + unitNumber (unitNumber starts at 1 per UPC)
        MintedIds memory sortedMintedIds;

        // Populate UPC 4 minted tokenIds (18 items)
        sortedMintedIds.upc4[0] = 4_000_000_068; // Token ID: 4 * 1000000000 + 1
        sortedMintedIds.upc4[1] = 4_000_000_069; // Token ID: 4 * 1000000000 + 2
        sortedMintedIds.upc4[2] = 4_000_000_070; // Token ID: 4 * 1000000000 + 3
        sortedMintedIds.upc4[3] = 4_000_000_071; // Token ID: 4 * 1000000000 + 4
        sortedMintedIds.upc4[4] = 4_000_000_072; // Token ID: 4 * 1000000000 + 5
        sortedMintedIds.upc4[5] = 4_000_000_073; // Token ID: 4 * 1000000000 + 6
        sortedMintedIds.upc4[6] = 4_000_000_074; // Token ID: 4 * 1000000000 + 7
        sortedMintedIds.upc4[7] = 4_000_000_075; // Token ID: 4 * 1000000000 + 8
        sortedMintedIds.upc4[8] = 4_000_000_076; // Token ID: 4 * 1000000000 + 9
        sortedMintedIds.upc4[9] = 4_000_000_077; // Token ID: 4 * 1000000000 + 10
        sortedMintedIds.upc4[10] = 4_000_000_078; // Token ID: 4 * 1000000000 + 11
        sortedMintedIds.upc4[11] = 4_000_000_079; // Token ID: 4 * 1000000000 + 12
        sortedMintedIds.upc4[12] = 4_000_000_080; // Token ID: 4 * 1000000000 + 13
        sortedMintedIds.upc4[13] = 4_000_000_081; // Token ID: 4 * 1000000000 + 14
        sortedMintedIds.upc4[14] = 4_000_000_082; // Token ID: 4 * 1000000000 + 15
        sortedMintedIds.upc4[15] = 4_000_000_083; // Token ID: 4 * 1000000000 + 16
        sortedMintedIds.upc4[16] = 4_000_000_084; // Token ID: 4 * 1000000000 + 17
        sortedMintedIds.upc4[17] = 4_000_000_085; // Token ID: 4 * 1000000000 + 18
        // Populate UPC 6 minted tokenIds (1 items)
        sortedMintedIds.upc6[0] = 6_000_000_008; // Token ID: 6 * 1000000000 + 1
        // Populate UPC 15 minted tokenIds (1 items)
        sortedMintedIds.upc15[0] = 15_000_000_005; // Token ID: 15 * 1000000000 + 1
        // Populate UPC 19 minted tokenIds (3 items)
        sortedMintedIds.upc19[0] = 19_000_000_013; // Token ID: 19 * 1000000000 + 1
        sortedMintedIds.upc19[1] = 19_000_000_014; // Token ID: 19 * 1000000000 + 2
        sortedMintedIds.upc19[2] = 19_000_000_015; // Token ID: 19 * 1000000000 + 3
        // Populate UPC 25 minted tokenIds (2 items)
        sortedMintedIds.upc25[0] = 25_000_000_008; // Token ID: 25 * 1000000000 + 1
        sortedMintedIds.upc25[1] = 25_000_000_009; // Token ID: 25 * 1000000000 + 2
        // Populate UPC 29 minted tokenIds (1 items)
        sortedMintedIds.upc29[0] = 29_000_000_002; // Token ID: 29 * 1000000000 + 1
        // Populate UPC 31 minted tokenIds (2 items)
        sortedMintedIds.upc31[0] = 31_000_000_007; // Token ID: 31 * 1000000000 + 1
        sortedMintedIds.upc31[1] = 31_000_000_008; // Token ID: 31 * 1000000000 + 2
        // Populate UPC 38 minted tokenIds (1 items)
        sortedMintedIds.upc38[0] = 38_000_000_003; // Token ID: 38 * 1000000000 + 1
        // Populate UPC 43 minted tokenIds (2 items)
        sortedMintedIds.upc43[0] = 43_000_000_006; // Token ID: 43 * 1000000000 + 1
        sortedMintedIds.upc43[1] = 43_000_000_007; // Token ID: 43 * 1000000000 + 2
        // Step 1.5: Approve resolver to transfer all tokens owned by this contract
        // The resolver needs approval to transfer outfits and backgrounds to itself during decoration
        IERC721(address(hook)).setApprovalForAll(address(resolver), true);

        // Step 2: Process each Banny body and dress them

        // Dress Banny 4000000076 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19_000_000_013; // V4: 19000000018 -> V5: 19000000013
            outfitIds[1] = 29_000_000_002; // V4: 29000000002 -> V5: 29000000002
            outfitIds[2] = 38_000_000_003; // V4: 38000000001 -> V5: 38000000003

            resolver.decorateBannyWith(address(hook), 4_000_000_076, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_076
            );
        }

        // Dress Banny 4000000078 (Original)
        {
            uint256[] memory outfitIds = new uint256[](2);
            outfitIds[0] = 31_000_000_007; // V4: 31000000011 -> V5: 31000000007
            outfitIds[1] = 43_000_000_006; // V4: 43000000017 -> V5: 43000000006

            resolver.decorateBannyWith(address(hook), 4_000_000_078, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_078
            );
        }

        // Dress Banny 4000000079 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 19_000_000_014; // V4: 19000000020 -> V5: 19000000014
            outfitIds[1] = 25_000_000_008; // V4: 25000000010 -> V5: 25000000008
            outfitIds[2] = 43_000_000_007; // V4: 43000000018 -> V5: 43000000007

            resolver.decorateBannyWith(address(hook), 4_000_000_079, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_079
            );
        }

        // Dress Banny 4000000080 (Original)
        {
            uint256[] memory outfitIds = new uint256[](3);
            outfitIds[0] = 15_000_000_005; // V4: 15000000005 -> V5: 15000000005
            outfitIds[1] = 19_000_000_015; // V4: 19000000021 -> V5: 19000000015
            outfitIds[2] = 25_000_000_009; // V4: 25000000011 -> V5: 25000000009

            resolver.decorateBannyWith(address(hook), 4_000_000_080, 6_000_000_008, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_080
            );
        }

        // Dress Banny 4000000085 (Original)
        {
            uint256[] memory outfitIds = new uint256[](1);
            outfitIds[0] = 31_000_000_008; // V4: 31000000013 -> V5: 31000000008

            resolver.decorateBannyWith(address(hook), 4_000_000_085, 0, outfitIds);

            MigrationHelper.verifyV4AssetMatch(
                resolver, v4Resolver, fallbackV4Resolver, address(hook), v4HookAddress, 4_000_000_085
            );
        }

        // Step 3: Transfer all assets to rightful owners using constructor data
        // Generate token IDs in the same order as items appear (matching mint order)
        // Token ID format: UPC * 1000000000 + unitNumber
        // Note: Only banny body token IDs are guaranteed to match between V4 and V5.
        // Outfits/backgrounds being worn by bannys may have different IDs, but that's OK
        // since they're not transferred (only used in decorateBannyWith calls).
        uint256[] memory generatedTokenIds = new uint256[](transferOwners.length);

        generatedTokenIds[0] = 4_000_000_068; // Token ID (V4: 4000000068)
        generatedTokenIds[1] = 4_000_000_069; // Token ID (V4: 4000000069)
        generatedTokenIds[2] = 4_000_000_070; // Token ID (V4: 4000000070)
        generatedTokenIds[3] = 4_000_000_071; // Token ID (V4: 4000000071)
        generatedTokenIds[4] = 4_000_000_072; // Token ID (V4: 4000000072)
        generatedTokenIds[5] = 4_000_000_073; // Token ID (V4: 4000000073)
        generatedTokenIds[6] = 4_000_000_074; // Token ID (V4: 4000000074)
        generatedTokenIds[7] = 4_000_000_075; // Token ID (V4: 4000000075)
        generatedTokenIds[8] = 4_000_000_076; // Token ID (V4: 4000000076)
        generatedTokenIds[9] = 4_000_000_077; // Token ID (V4: 4000000077)
        generatedTokenIds[10] = 4_000_000_078; // Token ID (V4: 4000000078)
        generatedTokenIds[11] = 4_000_000_079; // Token ID (V4: 4000000079)
        generatedTokenIds[12] = 4_000_000_080; // Token ID (V4: 4000000080)
        generatedTokenIds[13] = 4_000_000_081; // Token ID (V4: 4000000081)
        generatedTokenIds[14] = 4_000_000_082; // Token ID (V4: 4000000082)
        generatedTokenIds[15] = 4_000_000_083; // Token ID (V4: 4000000083)
        generatedTokenIds[16] = 4_000_000_084; // Token ID (V4: 4000000084)
        generatedTokenIds[17] = 4_000_000_085; // Token ID (V4: 4000000085)

        uint256 successfulTransfers = 0;
        uint256 skippedResolverOwned = 0;

        for (uint256 i = 0; i < transferOwners.length; i++) {
            uint256 tokenId = generatedTokenIds[i];
            // Verify V4 ownership before transferring V5
            address v4Owner = v4Hook.ownerOf(tokenId);
            require(
                v4Owner == transferOwners[i] || v4Owner == address(fallbackV4ResolverAddress),
                "V4/V5 ownership mismatch for token"
            );

            // Skip transfer if V4 owner is the resolver (resolver holds these tokens, we shouldn't transfer to
            // resolver)
            if (v4Owner == address(v4ResolverAddress) || v4Owner == address(fallbackV4ResolverAddress)) {
                // Token is held by resolver, skip transfer
                skippedResolverOwned++;
                continue;
            }

            IERC721(address(hook)).safeTransferFrom(address(this), transferOwners[i], tokenId);
            successfulTransfers++;
        }

        // Verify all expected items were processed (transferred or skipped as expected)
        require(successfulTransfers + skippedResolverOwned == transferOwners.length, "Not all items were processed");

        // Final verification: Ensure this contract no longer owns any tokens
        // This ensures all transfers completed successfully and no tokens were left behind
        require(hook.balanceOf(address(this)) == 0, "Contract still owns tokens after migration");

        // Verify tier balances: V5 should never exceed V4 (except for tiers owned by fallback resolver in V4)

        // // Collect unique owners
        // address[] memory uniqueOwners = new address[](10);

        // uniqueOwners[0] = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        // uniqueOwners[1] = 0xaECD6D9172d602b93dBA3981991268b44af8096e;
        // uniqueOwners[2] = 0xAAeD9fFF9858d48925904E391B77892BA5Fda824;
        // uniqueOwners[3] = 0x2feb329b9289b60064904Fa61Fc347157a5AEd6a;
        // uniqueOwners[4] = 0xDfd60a8E1e17FBb78E8CA332906A822D862f3D57;
        // uniqueOwners[5] = 0xBD07B7Ab42cE411A752DB600604ECA7fE5501947;
        // uniqueOwners[6] = 0x9f729294b308f79243285348A7Be3f58ae5ED31A;
        // uniqueOwners[7] = 0x35a21F7c053Aed0Dcf9E24BfB100acA163aeDdB2;
        // uniqueOwners[8] = 0x1c6d61F3d8976A8aCDd311ecdFa533B8ECd0AC61;
        // uniqueOwners[9] = 0x5138a42C3D5065debE950deBDa10C1f38150a908;

        // // Collect unique tier IDs
        // uint256[] memory uniqueTierIds = new uint256[](9);

        // uniqueTierIds[0] = 4;
        // uniqueTierIds[1] = 6;
        // uniqueTierIds[2] = 15;
        // uniqueTierIds[3] = 19;
        // uniqueTierIds[4] = 25;
        // uniqueTierIds[5] = 29;
        // uniqueTierIds[6] = 31;
        // uniqueTierIds[7] = 38;
        // uniqueTierIds[8] = 43;

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
