// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Registry} from "../src/Registry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {NodeRecord, IRegistry} from "../src/interfaces/IRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RegistryTest is Test {
    Registry registry;
    MockERC20 token;

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);

    event NodeRegistered(address indexed operator, bytes32 nodeId);
    event NodeUpdated(address indexed operator, string domain, uint16 port);

    function setUp() public {
        vm.startPrank(owner);
        token = new MockERC20();
        token.initialize("Yellow Token", "YELLOW", 18);
        registry = new Registry(address(token));
        vm.stopPrank();

        // Fund Alice
        token.mint(alice, 1_000_000 ether);
        vm.prank(alice);
        token.approve(address(registry), type(uint256).max);

        // Fund Bob
        token.mint(bob, 1_000_000 ether);
        vm.prank(bob);
        token.approve(address(registry), type(uint256).max);
    }

    function test_InitialState() public {
        (uint32 version, string memory url,) = registry.getVersion();
        assertEq(version, 0);
        assertEq(url, "");
        assertEq(registry.totalActiveNodes(), 0);
    }

    // -------------------------------------------------------------------------
    // Phase 3: Registration Tests
    // -------------------------------------------------------------------------

    function testRegister_Success() public {
        vm.startPrank(alice);
        bytes32 nodeId = keccak256(abi.encode("test", 1, alice));

        vm.expectEmit(true, false, false, true);
        emit NodeRegistered(alice, nodeId);

        registry.register(nodeId, "alice.node", 9000);

        NodeRecord memory node = registry.getNodeById(nodeId);
        assertEq(node.operator, alice);
        assertEq(node.nodeId, nodeId);
        assertEq(node.domain, "alice.node");
        assertEq(node.port, 9000);
        assertEq(node.amount, 250_000 ether);
        assertEq(node.unlockAt, 0);
        assertEq(registry.totalActiveNodes(), 1);
        vm.stopPrank();
    }

    function testRegister_RevertInsufficientStake() public {
        vm.startPrank(alice);
        // Burn alice's tokens so she has < 250k
        token.transfer(address(0xdead), 800_000 ether);
        // Now she has 200k

        bytes32 nodeId = keccak256(abi.encode("test", 1, alice));
        vm.expectRevert("Insufficient stake");
        registry.register(nodeId, "alice.node", 9000);
        vm.stopPrank();
    }

    function testRegister_RevertDuplicateId() public {
        vm.startPrank(alice);
        bytes32 nodeId = keccak256(abi.encode("test", 1, alice));
        registry.register(nodeId, "alice.node", 9000);
        vm.stopPrank();

        vm.startPrank(bob);
        // Bob tries to register same ID
        vm.expectRevert("Node ID already used");
        registry.register(nodeId, "bob.node", 9001);
        vm.stopPrank();
    }

    function testUpdateNode() public {
        vm.startPrank(alice);
        bytes32 nodeId = keccak256(abi.encode("test", 1, alice));
        registry.register(nodeId, "alice.node", 9000);

        vm.expectEmit(true, false, false, true);
        emit NodeUpdated(alice, "alice.updated", 9001);

        registry.updateNode("alice.updated", 9001);

        NodeRecord memory node = registry.getNodeById(nodeId);
        assertEq(node.domain, "alice.updated");
        assertEq(node.port, 9001);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Phase 4: Discovery Tests
    // -------------------------------------------------------------------------

    function testPagination() public {
        // Register Alice
        vm.startPrank(alice);
        bytes32 id1 = keccak256(abi.encode("test", 1, alice));
        registry.register(id1, "alice", 9000);
        vm.stopPrank();

        // Register Bob
        vm.startPrank(bob);
        bytes32 id2 = keccak256(abi.encode("test", 1, bob));
        registry.register(id2, "bob", 9001);
        vm.stopPrank();

        // Register Charlie (mock)
        address charlie = address(0x4);
        token.mint(charlie, 1_000_000 ether);
        vm.startPrank(charlie);
        token.approve(address(registry), type(uint256).max);
        bytes32 id3 = keccak256(abi.encode("test", 1, charlie));
        registry.register(id3, "charlie", 9002);
        vm.stopPrank();

        assertEq(registry.totalActiveNodes(), 3);

        // Fetch Page 1 (Offset 0, Limit 2)
        NodeRecord[] memory page1 = registry.getActiveNodes(0, 2);
        assertEq(page1.length, 2);
        assertEq(page1[0].operator, alice);
        assertEq(page1[1].operator, bob);

        // Fetch Page 2 (Offset 2, Limit 2)
        NodeRecord[] memory page2 = registry.getActiveNodes(2, 2);
        assertEq(page2.length, 1);
        assertEq(page2[0].operator, charlie);

        // Fetch Out of Bounds
        NodeRecord[] memory page3 = registry.getActiveNodes(3, 2);
        assertEq(page3.length, 0);
    }

    // -------------------------------------------------------------------------
    // Phase 5: Configuration Tests
    // -------------------------------------------------------------------------

    function testUpdateConfig_OnlyOwner() public {
        vm.startPrank(alice);
        bytes32 checksum = keccak256("manifest");
        // Expect OpenZeppelin 5.0 custom error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        registry.updateVersion(1, "https://v1", checksum);
        vm.stopPrank();
    }

    event VersionUpdated(uint32 version, string url);

    function testUpdateConfig_IncrementsVersion() public {
        vm.startPrank(owner);
        bytes32 checksum = keccak256("manifest");

        vm.expectEmit(false, false, false, true);
        emit VersionUpdated(1, "https://v1");

        registry.updateVersion(1, "https://v1", checksum);

        (uint32 ver, string memory url, bytes32 sum) = registry.getVersion();
        assertEq(ver, 1);
        assertEq(url, "https://v1");
        assertEq(sum, checksum);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Phase 6: Unregister & Withdraw Tests
    // -------------------------------------------------------------------------

    event NodeUnregistered(address indexed operator, uint64 cooldownEnd);
    event CollateralWithdrawn(address indexed operator, uint256 amount);

    function testUnregister_RemovesFromActive() public {
        vm.startPrank(alice);
        bytes32 id = keccak256(abi.encode("test", 1, alice));
        registry.register(id, "alice", 9000);

        assertEq(registry.totalActiveNodes(), 1);

        vm.expectEmit(true, false, false, true);
        emit NodeUnregistered(alice, uint64(block.timestamp + 7 days));

        registry.unregister();

        assertEq(registry.totalActiveNodes(), 0);

        NodeRecord memory node = registry.getNodeById(id);
        assertEq(node.unlockAt, block.timestamp + 7 days);
        // Verify balance remains locked (amount > 0)
        assertEq(node.amount, 250_000 ether);

        // Ensure not in active list (this might revert or return empty depending on impl of getActiveNodes for OOB)
        NodeRecord[] memory active = registry.getActiveNodes(0, 10);
        assertEq(active.length, 0);
        vm.stopPrank();
    }

    function testWithdraw_RevertDuringCooldown() public {
        vm.startPrank(alice);
        bytes32 id = keccak256(abi.encode("test", 1, alice));
        registry.register(id, "alice", 9000);
        registry.unregister();

        // Try immediately
        vm.expectRevert("Cooldown not ended");
        registry.withdraw();

        // Try after 6 days
        vm.warp(block.timestamp + 6 days);
        vm.expectRevert("Cooldown not ended");
        registry.withdraw();
        vm.stopPrank();
    }

    function testWithdraw_SuccessAfterCooldown() public {
        vm.startPrank(alice);
        bytes32 id = keccak256(abi.encode("test", 1, alice));
        registry.register(id, "alice", 9000);
        registry.unregister();

        vm.warp(block.timestamp + 7 days + 1 seconds);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.expectEmit(true, false, false, true);
        emit CollateralWithdrawn(alice, 250_000 ether);

        registry.withdraw();

        uint256 balanceAfter = token.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, 250_000 ether);

        // Verify state cleared
        vm.expectRevert("Node not found");
        registry.getNodeById(id);

        vm.stopPrank();
    }

    function testGas_GetActiveNodes() public {
        // Register 20 nodes
        for (uint256 i = 0; i < 20; i++) {
            address op = address(uint160(0x1000 + i));
            token.mint(op, 250_000 ether);
            vm.startPrank(op);
            token.approve(address(registry), type(uint256).max);
            bytes32 id = keccak256(abi.encode(i));
            registry.register(id, "node", 9000);
            vm.stopPrank();
        }

        uint256 startGas = gasleft();
        registry.getActiveNodes(0, 20);
        uint256 used = startGas - gasleft();
        console2.log("Gas used for 20 nodes:", used);

        // Assert reasonable gas limit (e.g. < 100k for read? No, view functions are free off-chain but good to know limit)
        // Copying struct arrays is expensive.
        // 20 items * (fields...)
        // Just ensuring it doesn't explode.
        assertTrue(used < 500_000);
    }
}
