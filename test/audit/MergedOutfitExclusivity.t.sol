// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";

/// @dev Mock hook that supports safeTransferFrom with ERC721Receiver checks.
contract ExclusivityMockHook {
    // Maps token IDs to their current owner.
    mapping(uint256 tokenId => address) public ownerOf;
    // Maps owners to operator approvals.
    mapping(address owner => mapping(address operator => bool)) public isApprovedForAll;

    // The mock store address, returned by STORE().
    address public immutable MOCK_STORE;

    constructor(address store) {
        // Store the mock store address at construction time.
        MOCK_STORE = store;
    }

    /// @dev Returns the mock store address for tier lookups.
    function STORE() external view returns (address) {
        return MOCK_STORE;
    }

    /// @dev Sets the owner of a token ID (test helper).
    function setOwner(uint256 tokenId, address owner) external {
        ownerOf[tokenId] = owner;
    }

    /// @dev Sets operator approval for the caller.
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    /// @dev Safe transfer that checks ERC721Receiver on contract recipients.
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        // Verify the caller is authorized to transfer this token.
        require(
            msg.sender == ownerOf[tokenId] || msg.sender == from || isApprovedForAll[from][msg.sender],
            "ExclusivityMockHook: not authorized"
        );

        // Update ownership to the new owner.
        ownerOf[tokenId] = to;

        // If the recipient is a contract, check ERC721Receiver.
        if (to.code.length > 0) {
            // Call onERC721Received and verify the return selector.
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            // Revert if the receiver rejects the transfer.
            require(retval == IERC721Receiver.onERC721Received.selector, "ExclusivityMockHook: receiver rejected");
        }
    }

    /// @dev Returns mock pricing context (currency=1, decimals=18, prices=0).
    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    /// @dev Returns a mock base URI for metadata.
    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @dev Mock store that returns tier data for token IDs.
contract ExclusivityMockStore {
    // Maps (hook, tokenId) to tier data.
    mapping(address hook => mapping(uint256 tokenId => JB721Tier)) public tiers;

    /// @dev Sets the tier data for a given (hook, tokenId) pair.
    function setTier(address hook, uint256 tokenId, JB721Tier memory tier) external {
        tiers[hook][tokenId] = tier;
    }

    /// @dev Returns the tier for a given (hook, tokenId) pair.
    function tierOfTokenId(address hook, uint256 tokenId, bool) external view returns (JB721Tier memory) {
        return tiers[hook][tokenId];
    }

    /// @dev Returns a zero IPFS URI (unused in these tests).
    // forge-lint: disable-next-line(mixed-case-function)
    function encodedIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/// @dev Contract that does NOT implement IERC721Receiver -- transfers to it will revert.
///      Used to simulate a scenario where returning an outfit fails.
contract ERC721Rejector {
    /// @dev Approves the resolver as an operator on the hook.
    function approveResolver(ExclusivityMockHook hook, address resolver) external {
        hook.setApprovalForAll(resolver, true);
    }

    /// @dev Calls decorateBannyWith on behalf of this contract.
    function decorate(
        Banny721TokenUriResolver resolver,
        address hook,
        uint256 bannyBodyId,
        uint256 backgroundId,
        uint256[] memory outfitIds
    )
        external
    {
        resolver.decorateBannyWith(hook, bannyBodyId, backgroundId, outfitIds);
    }
}

/// @title MergedOutfitExclusivityTest
/// @notice Tests that category exclusivity is enforced on the merged set (retained + new outfits),
///         not just the new outfit set alone.
contract MergedOutfitExclusivityTest is Test {
    // The resolver under test.
    Banny721TokenUriResolver resolver;
    // Mock hook for NFT ownership tracking.
    ExclusivityMockHook hook;
    // Mock store for tier/category lookups.
    ExclusivityMockStore store;
    // Contract that rejects ERC721 transfers (no IERC721Receiver).
    ERC721Rejector rejector;

    // Token IDs follow the pattern used in other banny tests:
    // body is category 0, tier ID 4 => token 4_000_000_001
    uint256 constant BODY_TOKEN = 4_000_000_001;
    // HEAD is category 4, tier ID 11 => token 11_000_000_001
    uint256 constant HEAD_TOKEN = 11_000_000_001;
    // EYES is category 5, tier ID 12 => token 12_000_000_001
    uint256 constant EYES_TOKEN = 12_000_000_001;

    function setUp() public {
        // Deploy mock store for tier lookups.
        store = new ExclusivityMockStore();
        // Deploy mock hook with the store.
        hook = new ExclusivityMockHook(address(store));
        // Deploy the contract that rejects incoming ERC721 transfers.
        rejector = new ERC721Rejector();

        // Deploy the resolver with placeholder SVG paths and no trusted forwarder.
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", address(this), address(0)
        );

        // Set up tier data: body (category 0), HEAD (category 4), EYES (category 5).
        _setupTier(BODY_TOKEN, 4, 0);
        _setupTier(HEAD_TOKEN, 11, 4);
        _setupTier(EYES_TOKEN, 12, 5);
    }

    // -----------------------------------------------------------------------
    // Test: Merged set exclusivity with retained outfits
    // -----------------------------------------------------------------------
    // Scenario: equip a HEAD outfit, make its return fail, then try to equip
    // an EYES outfit. The merged set (retained HEAD + new EYES) should violate
    // HEAD/EYES exclusivity and revert.
    function test_mergedSetExclusivity_retainedHeadBlocksNewEyes() public {
        // Give the rejector contract ownership of body, HEAD, and EYES tokens.
        hook.setOwner(BODY_TOKEN, address(rejector));
        hook.setOwner(HEAD_TOKEN, address(rejector));
        hook.setOwner(EYES_TOKEN, address(rejector));

        // Approve the resolver to transfer tokens on behalf of the rejector.
        rejector.approveResolver(hook, address(resolver));

        // Step 1: Equip the HEAD outfit on the banny body.
        uint256[] memory headOutfit = new uint256[](1);
        headOutfit[0] = HEAD_TOKEN;
        // This transfers HEAD_TOKEN to the resolver's custody.
        rejector.decorate(resolver, address(hook), BODY_TOKEN, 0, headOutfit);

        // Verify HEAD is now worn by the banny body.
        assertEq(resolver.wearerOf(address(hook), HEAD_TOKEN), BODY_TOKEN, "HEAD should be worn by body");
        // Verify HEAD is in the resolver's custody.
        assertEq(hook.ownerOf(HEAD_TOKEN), address(resolver), "HEAD should be in resolver custody");

        // Step 2: Try to replace HEAD with EYES.
        // The resolver will try to return HEAD to the rejector, but the rejector
        // does not implement IERC721Receiver, so the transfer fails silently.
        // HEAD is retained in the merged set. The new set contains only EYES.
        // The merged set = [EYES, HEAD] which violates HEAD/EYES exclusivity.
        uint256[] memory eyesOutfit = new uint256[](1);
        eyesOutfit[0] = EYES_TOKEN;

        // Expect revert because the merged set has both HEAD (retained) and EYES (new).
        vm.expectRevert(Banny721TokenUriResolver.Banny721TokenUriResolver_HeadAlreadyAdded.selector);
        // Attempt to decorate with EYES -- should revert due to exclusivity.
        rejector.decorate(resolver, address(hook), BODY_TOKEN, 0, eyesOutfit);
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /// @dev Sets up a tier in the mock store for a given token.
    function _setupTier(uint256 tokenId, uint32 tierId, uint24 category) internal {
        // Create tier data with the specified ID and category.
        JB721Tier memory tier = JB721Tier({
            id: tierId,
            price: 0.01 ether,
            remainingSupply: 100,
            initialSupply: 100,
            votingUnits: 0,
            reserveFrequency: 0,
            reserveBeneficiary: address(0),
            encodedIPFSUri: bytes32(0),
            category: category,
            discountPercent: 0,
            allowOwnerMint: false,
            transfersPausable: false,
            cannotBeRemoved: false,
            cannotIncreaseDiscountPercent: false,
            cantBuyWithCredits: false,
            splitPercent: 0,
            resolvedUri: ""
        });

        // Store the tier data in the mock store.
        store.setTier(address(hook), tokenId, tier);
    }
}
