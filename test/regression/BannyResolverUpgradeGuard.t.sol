// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BannySvgStorage} from "../../src/BannySvgStorage.sol";
import {BannyResolverUpgradeGuard} from "../../script/helpers/BannyResolverUpgradeGuard.sol";

contract UpgradeStoreMock {
    address public resolver;
    uint256 public supply;
    uint256 public maxTierId = 1;
    mapping(address => mapping(uint256 => uint256)) public numberOfBurnedFor;

    function setBurn(address hook, uint256 tierId, uint256 value) external {
        numberOfBurnedFor[hook][tierId] = value;
    }

    function tokenUriResolverOf(address) external view returns (address) {
        return resolver;
    }

    function totalSupplyOf(address) external view returns (uint256) {
        return supply;
    }

    function maxTierIdOf(address) external view returns (uint256) {
        return maxTierId;
    }

    function setResolver(address value) external {
        resolver = value;
    }

    function setSupply(uint256 value) external {
        supply = value;
    }

    function setMaxTierId(uint256 value) external {
        maxTierId = value;
    }
}

contract UpgradeHookMock {
    UpgradeStoreMock public STORE;
    mapping(address => uint256) public balanceOf;

    constructor(UpgradeStoreMock store) {
        STORE = store;
    }

    function setBalance(address account, uint256 amount) external {
        balanceOf[account] = amount;
    }

    function switchResolver(address replacement) external {
        STORE.setResolver(replacement);
    }
}

contract UpgradeResolverMock {
    BannySvgStorage public SVG_STORAGE;
    address public owner;
    address public trustedForwarder;
    string public svgDescription = "description";
    string public svgExternalUrl = "url";
    string public svgBaseUri = "base";
    string public bannyBody = "body";
    string public defaultNecklace = "necklace";
    string public defaultMouth = "mouth";
    string public defaultStandardEyes = "eyes";
    string public defaultAlienEyes = "alien";
    string public productName = "product";
    string public svg = "fallback";
    mapping(uint256 => bytes32) public svgHashOf;

    constructor(address account) {
        owner = account;
        svgHashOf[1] = keccak256("art");
    }

    function namesOf(address, uint256) external view returns (string memory, string memory, string memory) {
        return ("full", "category", productName);
    }

    function svgOf(address, uint256, bool, bool) external view returns (string memory) {
        return svg;
    }

    function setSvgStorage(BannySvgStorage value) external {
        SVG_STORAGE = value;
    }

    function setSvg(string memory value) external {
        svg = value;
    }

    function setProductName(string memory value) external {
        productName = value;
    }

    function setOwner(address value) external {
        owner = value;
    }
}

contract BannyResolverUpgradeGuardTest is Test {
    BannyResolverUpgradeGuard guard;
    UpgradeStoreMock store;
    UpgradeHookMock hook;
    UpgradeResolverMock previous;
    UpgradeResolverMock replacement;
    bytes32 digest;

    function setUp() public {
        guard = new BannyResolverUpgradeGuard();
        store = new UpgradeStoreMock();
        hook = new UpgradeHookMock(store);
        previous = new UpgradeResolverMock(address(this));
        replacement = new UpgradeResolverMock(address(this));
        BannySvgStorage svgStorage = new BannySvgStorage(address(this));
        svgStorage.setWriter(address(replacement));
        replacement.setSvgStorage(svgStorage);
        store.setResolver(address(previous));
        digest = guard.configurationHash(address(hook), address(previous), 1);
    }

    function switchBatch() external {
        guard.check(
            address(hook),
            address(previous),
            address(replacement),
            address(previous).codehash,
            address(replacement).codehash,
            digest,
            1
        );
        hook.switchResolver(address(replacement));
    }

    function testUnboundStoragePreventsSwitch() public {
        BannySvgStorage svgStorage = new BannySvgStorage(address(this));
        replacement.setSvgStorage(svgStorage);
        vm.expectRevert("Storage writer");
        this.switchBatch();
        assertEq(store.resolver(), address(previous));
        svgStorage.setWriter(address(replacement));
        this.switchBatch();
        assertEq(store.resolver(), address(replacement));
    }

    function testWrongWriterPreventsSwitch() public {
        BannySvgStorage svgStorage = new BannySvgStorage(address(this));
        svgStorage.setWriter(address(previous));
        replacement.setSvgStorage(svgStorage);
        vm.expectRevert("Storage writer");
        this.switchBatch();
        assertEq(store.resolver(), address(previous));
    }

    function testBeforeMintAtomicSwitch() public {
        this.switchBatch();
        assertEq(store.resolver(), address(replacement));
    }

    function testMintedCollectionAndRollbackRejected() public {
        store.setSupply(1);
        vm.expectRevert("Already minted");
        this.switchBatch();
        assertEq(store.resolver(), address(previous));
    }

    function testMintedThenBurnedCollectionRejected() public {
        replacement.setProductName("unconfigured");
        store.setBurn(address(hook), 1, 1);
        vm.expectRevert("Mint history");
        this.configureAndSwitchBatch();
        assertEq(store.resolver(), address(previous));
        (,, string memory name) = replacement.namesOf(address(hook), 1);
        assertEq(name, "unconfigured");
        assertGt(address(replacement).code.length, 0);
    }

    function testCustodyRejected() public {
        hook.setBalance(address(previous), 1);
        vm.expectRevert("Previous custody");
        this.switchBatch();
        hook.setBalance(address(previous), 0);
        hook.setBalance(address(replacement), 1);
        vm.expectRevert("Replacement custody");
        this.switchBatch();
        assertEq(store.resolver(), address(previous));
    }

    function testPreviousConfigurationDriftRejected() public {
        previous.setProductName("changed");
        vm.expectRevert("Previous config changed");
        this.switchBatch();
        assertEq(store.resolver(), address(previous));
    }

    function testReplacementConfigurationDriftRejected() public {
        replacement.setProductName("changed");
        vm.expectRevert("Replacement config changed");
        this.switchBatch();
    }

    function testCorrectCachePublicationDoesNotBlockSwitch() public {
        replacement.setSvg("published artwork");
        this.switchBatch();
        assertEq(store.resolver(), address(replacement));
    }

    function testPreviousCachePublicationKeepsImmutableCommitmentAuthority() public {
        previous.setSvg("published previous artwork");
        this.switchBatch();
        assertEq(store.resolver(), address(replacement));
    }

    function testGuardFailureRollsBackConfigurationAndCanRetryDeployment() public {
        replacement.setProductName("unconfigured");
        store.setSupply(1);
        vm.expectRevert("Already minted");
        this.configureAndSwitchBatch();
        (,, string memory name) = replacement.namesOf(address(hook), 1);
        assertEq(name, "unconfigured");
        assertGt(address(replacement).code.length, 0);
        store.setSupply(0);
        this.configureAndSwitchBatch();
        assertEq(store.resolver(), address(replacement));
    }

    function configureAndSwitchBatch() external {
        replacement.setProductName("product");
        this.switchBatch();
    }

    function testProductsAndResolverDriftRejected() public {
        store.setMaxTierId(2);
        vm.expectRevert("Products changed");
        this.switchBatch();
        store.setMaxTierId(1);
        store.setResolver(address(0x123));
        vm.expectRevert("Resolver changed");
        this.switchBatch();
    }

    function testUnreviewedRuntimeAndOwnerRejected() public {
        vm.expectRevert("Runtime changed");
        guard.check(
            address(hook),
            address(previous),
            address(replacement),
            bytes32(uint256(1)),
            address(replacement).codehash,
            digest,
            1
        );
        replacement.setOwner(address(0x123));
        vm.expectRevert("Replacement owner");
        this.switchBatch();
    }
}
