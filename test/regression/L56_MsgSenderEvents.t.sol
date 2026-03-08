// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Banny721TokenUriResolver} from "../../src/Banny721TokenUriResolver.sol";
import {IBanny721TokenUriResolver} from "../../src/interfaces/IBanny721TokenUriResolver.sol";

/// @notice Minimal mock hook.
contract MockHook56 {
    mapping(uint256 => address) public ownerOf;
    address public immutable MOCK_STORE;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    constructor(address store) {
        MOCK_STORE = store;
    }

    function STORE() external view returns (address) {
        return MOCK_STORE;
    }

    function setOwner(uint256 tokenId, address owner) external {
        ownerOf[tokenId] = owner;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(
            msg.sender == ownerOf[tokenId] || msg.sender == from || isApprovedForAll[from][msg.sender],
            "MockHook: not authorized"
        );
        ownerOf[tokenId] = to;
        if (to.code.length > 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            require(retval == IERC721Receiver.onERC721Received.selector, "MockHook: receiver rejected");
        }
    }

    function pricingContext() external pure returns (uint256, uint256, uint256) {
        return (1, 18, 0);
    }

    function baseURI() external pure returns (string memory) {
        return "ipfs://";
    }
}

/// @notice Minimal mock store.
contract MockStore56 {
    mapping(address => mapping(uint256 => JB721Tier)) public tiers;

    function setTier(address hook, uint256 tokenId, JB721Tier memory tier) external {
        tiers[hook][tokenId] = tier;
    }

    function tierOfTokenId(address hook, uint256 tokenId, bool) external view returns (JB721Tier memory) {
        return tiers[hook][tokenId];
    }

    function encodedIPFSUriOf(address, uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/// @notice Regression test: L-56 -- events should emit _msgSender(), not msg.sender.
contract L56_MsgSenderEventsTest is Test {
    Banny721TokenUriResolver resolver;
    MockHook56 hook;
    MockStore56 store;

    address deployer = makeAddr("deployer");

    function setUp() public {
        store = new MockStore56();
        hook = new MockHook56(address(store));

        vm.prank(deployer);
        resolver = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", deployer, address(0)
        );
    }

    /// @notice Verify SetProductName event emits _msgSender() (== deployer) not msg.sender.
    function test_setProductNames_emitsCorrectCaller() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        string[] memory names = new string[](1);
        names[0] = "Test";

        vm.expectEmit(true, true, true, true);
        emit IBanny721TokenUriResolver.SetProductName({upc: 100, name: "Test", caller: deployer});

        vm.prank(deployer);
        resolver.setProductNames(upcs, names);
    }

    /// @notice Verify SetMetadata event emits _msgSender() (== deployer) not msg.sender.
    function test_setMetadata_emitsCorrectCaller() public {
        vm.expectEmit(true, true, true, true);
        emit IBanny721TokenUriResolver.SetMetadata({
            description: "desc", externalUrl: "url", baseUri: "base", caller: deployer
        });

        vm.prank(deployer);
        resolver.setMetadata("desc", "url", "base");
    }

    /// @notice Verify SetSvgHash event emits _msgSender() (== deployer) not msg.sender.
    function test_setSvgHashesOf_emitsCorrectCaller() public {
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("test");

        vm.expectEmit(true, true, true, true);
        emit IBanny721TokenUriResolver.SetSvgHash({upc: 100, svgHash: keccak256("test"), caller: deployer});

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);
    }

    /// @notice Verify SetSvgContent event emits _msgSender() not msg.sender.
    function test_setSvgContentsOf_emitsCorrectCaller() public {
        string memory content = "test-svg-content";

        // Store hash first.
        uint256[] memory upcs = new uint256[](1);
        upcs[0] = 100;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encodePacked(content));

        vm.prank(deployer);
        resolver.setSvgHashesOf(upcs, hashes);

        // Now store content -- anyone can call this.
        string[] memory contents = new string[](1);
        contents[0] = content;

        address alice = makeAddr("alice");
        vm.expectEmit(true, true, true, true);
        emit IBanny721TokenUriResolver.SetSvgContent({upc: 100, svgContent: content, caller: alice});

        vm.prank(alice);
        resolver.setSvgContentsOf(upcs, contents);
    }
}
