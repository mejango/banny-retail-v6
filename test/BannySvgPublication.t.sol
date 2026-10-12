// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base64} from "lib/base64/base64.sol";
import {BannySvgStorage} from "../src/BannySvgStorage.sol";
import {Test} from "forge-std/Test.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {Banny721TokenUriResolver} from "../src/Banny721TokenUriResolver.sol";
import {MockHook, MockStore} from "./Banny721TokenUriResolver.t.sol";

contract SvgPublicationHarness is Banny721TokenUriResolver {
    constructor()
        Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", msg.sender, address(0)
        )
    {}

    function fragment(address hook, uint256 upc) external view returns (string memory) {
        return _svgOf(hook, upc);
    }

    function stored(uint256 upc) external view returns (string memory) {
        return _storedSvgOf(upc);
    }
}

/// @notice Exact public originals and legacy setter semantics, across every code-storage boundary.
contract BannySvgPublicationTest is Test {
    SvgPublicationHarness resolver;
    MockStore store;
    MockHook hook;

    function setUp() public {
        resolver = new SvgPublicationHarness();
        store = new MockStore();
        hook = new MockHook(address(store));
    }

    function test_all64PublicOriginalsRoundTripByteExactly() public {
        string memory json = vm.readFile("test/fixtures/banny-svg-originals.json");
        uint256 total;
        for (uint256 i; i < 64; ++i) {
            string memory prefix = string.concat(".assets[", vm.toString(i), "]");
            uint256 upc = vm.parseJsonUint(json, string.concat(prefix, ".upc"));
            string memory content = vm.parseJsonString(json, string.concat(prefix, ".svgString"));
            bytes32 hash = vm.parseJsonBytes32(json, string.concat(prefix, ".svgHash"));
            uint256 size = vm.parseJsonUint(json, string.concat(prefix, ".bytes"));
            assertEq(bytes(content).length, size);
            assertEq(keccak256(bytes(content)), hash);
            assertGt(bytes(vm.parseJsonString(json, string.concat(prefix, ".CID"))).length, 0);
            _commit(upc, hash);
            vm.prank(address(0xBEEF));
            resolver.setSvgContentsOf(_upcs(upc), _contents(content));
            assertEq(bytes(resolver.stored(upc)), bytes(content));
            assertEq(bytes(resolver.fragment(address(hook), upc)), bytes(content));
            total += size;
        }
        assertEq(total, 240_146);
    }

    function test_codeChunkBoundariesRoundTrip() public {
        uint256[5] memory sizes = [uint256(24_574), 24_575, 24_576, 49_150, 49_151];
        for (uint256 i; i < sizes.length; ++i) {
            bytes memory content = new bytes(sizes[i]);
            for (uint256 j; j < content.length; ++j) {
                content[j] = bytes1(uint8(j % 251));
            }
            address writer = address(resolver.SVG_STORAGE());
            uint256 firstNonce = vm.getNonce(writer);
            _publish(100 + i, string(content));
            uint256 chunks = (sizes[i] + 24_574) / 24_575;
            assertEq(vm.getNonce(writer), firstNonce + chunks);
            for (uint256 j; j < chunks; ++j) {
                address chunk = vm.computeCreateAddress(writer, firstNonce + j);
                assertLe(chunk.code.length, 24_576);
                assertGt(chunk.code.length, 1);
                assertEq(chunk.code[0], bytes1(0));
            }
            assertEq(bytes(resolver.stored(100 + i)), content);
        }
    }

    function test_rejectMissingMismatchRepeatedAndArrayLengths() public {
        vm.expectRevert(
            abi.encodeWithSelector(Banny721TokenUriResolver.Banny721TokenUriResolver_HashNotFound.selector, 90)
        );
        resolver.setSvgContentsOf(_upcs(90), _contents("missing"));
        _commit(90, keccak256("correct"));
        vm.expectRevert(
            abi.encodeWithSelector(
                Banny721TokenUriResolver.Banny721TokenUriResolver_ContentsMismatch.selector,
                90,
                keccak256("correct"),
                keccak256("wrong")
            )
        );
        resolver.setSvgContentsOf(_upcs(90), _contents("wrong"));
        resolver.setSvgContentsOf(_upcs(90), _contents("correct"));
        vm.expectRevert(
            abi.encodeWithSelector(Banny721TokenUriResolver.Banny721TokenUriResolver_ContentsAlreadyStored.selector, 90)
        );
        resolver.setSvgContentsOf(_upcs(90), _contents("correct"));
        vm.expectRevert(
            abi.encodeWithSelector(Banny721TokenUriResolver.Banny721TokenUriResolver_ArrayLengthMismatch.selector, 1, 0)
        );
        resolver.setSvgContentsOf(_upcs(91), new string[](0));
    }

    function test_multiAssetFailureRollsBackPreviouslyWrittenChunks() public {
        string memory large = string(new bytes(49_151));
        _commit(100, keccak256(bytes(large)));
        _commit(101, keccak256("expected"));
        uint256[] memory upcs = new uint256[](2);
        upcs[0] = 100;
        upcs[1] = 101;
        string[] memory contents = new string[](2);
        contents[0] = large;
        contents[1] = "wrong";
        vm.expectRevert(
            abi.encodeWithSelector(
                Banny721TokenUriResolver.Banny721TokenUriResolver_ContentsMismatch.selector,
                101,
                keccak256("expected"),
                keccak256("wrong")
            )
        );
        resolver.setSvgContentsOf(upcs, contents);
        assertEq(resolver.stored(100), "");
        resolver.setSvgContentsOf(_upcs(100), _contents(large));
        assertEq(bytes(resolver.stored(100)), bytes(large));
    }

    function test_emptyPublicationPreservesLegacyRepeatAndFallback() public {
        string memory fallback_ = resolver.fragment(address(hook), 100);
        _commit(100, keccak256(""));
        resolver.setSvgContentsOf(_upcs(100), _contents(""));
        resolver.setSvgContentsOf(_upcs(100), _contents(""));
        assertEq(resolver.stored(100), "");
        assertEq(resolver.fragment(address(hook), 100), fallback_);
    }

    function test_publishedArtFeedsDecoratedSvgAndTokenUri() public {
        _tier(4_000_000_001, 4, 0);
        _tier(5_000_000_001, 5, 1);
        _tier(10_000_000_001, 10, 3);
        hook.setApprovalForAll(address(resolver), true);
        _publish(5, '<path id="background"/>');
        _publish(10, '<path id="outfit"/>');
        uint256[] memory outfits = _upcs(10_000_000_001);
        resolver.decorateBannyWith(address(hook), 4_000_000_001, 5_000_000_001, outfits);
        string memory svg = resolver.svgOf(address(hook), 4_000_000_001, true, true);
        assertTrue(_contains(svg, '<path id="background"/>'));
        assertTrue(_contains(svg, '<path id="outfit"/>'));
        assertFalse(_contains(svg, '<image href="'));
        string memory uri = resolver.tokenUriOf(address(hook), 4_000_000_001);
        string memory metadata = string(Base64.decode(_strip(uri, bytes("data:application/json;base64,").length)));
        string memory image = vm.parseJsonString(metadata, ".image");
        string memory decodedSvg = string(Base64.decode(_strip(image, bytes("data:image/svg+xml;base64,").length)));
        assertEq(decodedSvg, svg);
        assertFalse(_contains(decodedSvg, '<image href="'));
    }

    function test_storeCannotBeWrittenAroundResolverCommitments() public {
        BannySvgStorage storage_ = resolver.SVG_STORAGE();
        assertEq(storage_.WRITER(), address(resolver));
        vm.expectRevert(abi.encodeWithSelector(BannySvgStorage.BannySvgStorage_Unauthorized.selector, address(this)));
        storage_.write(100, bytes("uncommitted"));
        assertFalse(storage_.isStored(100));
        assertEq(storage_.read(100), bytes(""));
    }

    function test_deploymentsFitRuntimeAndInitcodeCaps() public {
        Banny721TokenUriResolver production = new Banny721TokenUriResolver(
            "<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", address(this), address(0)
        );
        assertLe(address(production).code.length, 24_576);
        assertLe(address(resolver.SVG_STORAGE()).code.length, 24_576);
        assertLe(type(BannySvgStorage).creationCode.length, 49_152);
        assertLe(
            type(Banny721TokenUriResolver).creationCode.length
                + abi.encode("<path/>", "<necklace/>", "<mouth/>", "<eyes/>", "<alieneyes/>", address(this), address(0))
                .length,
            49_152
        );
    }

    function _strip(string memory value, uint256 prefixLength) internal pure returns (string memory) {
        bytes memory v = bytes(value);
        bytes memory suffix = new bytes(v.length - prefixLength);
        for (uint256 i; i < suffix.length; ++i) {
            suffix[i] = v[i + prefixLength];
        }
        return string(suffix);
    }

    function _publish(uint256 upc, string memory content) internal {
        _commit(upc, keccak256(bytes(content)));
        resolver.setSvgContentsOf(_upcs(upc), _contents(content));
    }

    function _commit(uint256 upc, bytes32 hash) internal {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = hash;
        resolver.setSvgHashesOf(_upcs(upc), hashes);
    }

    function _upcs(uint256 upc) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = upc;
    }

    function _contents(string memory content) internal pure returns (string[] memory a) {
        a = new string[](1);
        a[0] = content;
    }

    function _tier(uint256 token, uint32 upc, uint24 category) internal {
        JB721Tier memory tier;
        tier.id = upc;
        tier.category = category;
        store.setTier(address(hook), token, tier);
        hook.setTier(token, upc, category);
        hook.setOwner(token, address(this));
    }

    function _contains(string memory value, string memory needle) internal pure returns (bool) {
        bytes memory v = bytes(value);
        bytes memory n = bytes(needle);
        if (n.length > v.length) return false;
        for (uint256 i; i <= v.length - n.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < n.length; ++j) {
                if (v[i + j] != n[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) return true;
        }
        return false;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
