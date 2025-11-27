// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Simple Mock ERC20
contract MockERC20 is IERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function name() external pure returns (string memory) {
        return "Mock Token";
    }

    function symbol() external pure returns (string memory) {
        return "MCK";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}

contract VaultTest is Test {
    Vault public vault;
    MockERC20 public token;

    uint256 public alicePk = 0xA11CE;
    address public alice;
    
    uint256 public bobPk = 0xB0B;
    address public bob;

    // Nodes
    uint256[] public nodePks;
    address[] public nodes;

    function setUp() public {
        vault = new Vault();
        token = new MockERC20();

        alice = vm.addr(alicePk);
        bob = vm.addr(bobPk);

        // Setup Nodes (Quorum of 3)
        for (uint i = 1; i <= 3; i++) {
            uint256 pk = 0x100 + i;
            nodePks.push(pk);
            address node = vm.addr(pk);
            nodes.push(node);
            vault.setNodeStatus(node, true);
        }

        // Mint tokens
        token.mint(alice, 1000 ether);
        token.mint(bob, 1000 ether);

        // Approve Vault
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
        
        vm.prank(bob);
        token.approve(address(vault), type(uint256).max);
    }

    function _signState(State memory state, uint256[] memory pks) internal returns (bytes[] memory) {
        bytes32 stateHash = keccak256(abi.encode(
            state.wallet,
            state.token,
            state.height,
            state.balance,
            state.participants
        ));
        
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", stateHash));

        bytes[] memory sigs = new bytes[](pks.length);
        for (uint i = 0; i < pks.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(pks[i], digest);
            sigs[i] = abi.encodePacked(r, s, v);
        }
        return sigs;
    }

    function test_HappyCase() public {
        uint256 depositAmount = 100 ether;
        
        // 1. Deposit
        vm.prank(alice);
        vault.deposit(alice, address(token), depositAmount);

        // 2. Off-chain state transition (Alice spends 80, keeps 20)
        uint256 withdrawAmount = 20 ether;
        
        State memory state = State({
            wallet: alice,
            token: address(token),
            height: 2,
            balance: withdrawAmount,
            participants: nodes,
            sigs: new bytes[](0)
        });

        // Sign by nodes
        state.sigs = _signState(state, nodePks);

        // 3. Request Withdrawal
        vm.prank(alice);
        vault.request(state, withdrawAmount);

        // 4. Wait for Challenge Period
        vm.warp(block.timestamp + 10 minutes + 1 seconds);

        // 5. Withdraw
        uint256 preBalance = token.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(state);
        uint256 postBalance = token.balanceOf(alice);

        assertEq(postBalance - preBalance, withdrawAmount);
    }

    function test_FraudCase() public {
        uint256 depositAmount = 100 ether;

        // 1. Deposit
        vm.prank(bob);
        vault.deposit(bob, address(token), depositAmount);

        // 2. Bob tries to withdraw with OLD state (Version 1, Balance 100)
        // Even though real state might be Version 2, Balance 50.
        
        State memory oldState = State({
            wallet: bob,
            token: address(token),
            height: 1,
            balance: depositAmount,
            participants: nodes,
            sigs: new bytes[](0)
        });
        oldState.sigs = _signState(oldState, nodePks);

        vm.prank(bob);
        vault.request(oldState, depositAmount);

        // 3. Challenge! (Node detects fraud)
        // Real state: Version 2, Balance 50
        State memory newState = State({
            wallet: bob,
            token: address(token),
            height: 2,
            balance: 50 ether,
            participants: nodes,
            sigs: new bytes[](0)
        });
        newState.sigs = _signState(newState, nodePks);

        address challenger = nodes[0];
        vm.prank(challenger);
        vault.challenge(newState);

        // 4. Try to withdraw (Should fail)
        vm.warp(block.timestamp + 10 minutes + 1 seconds);
        
        vm.prank(bob);
        vm.expectRevert("No pending request");
        vault.withdraw(oldState);
    }

    function test_CannotWithdrawDuringChallengePeriod() public {
         uint256 depositAmount = 100 ether;
        
        vm.prank(alice);
        vault.deposit(alice, address(token), depositAmount);

        State memory state = State({
            wallet: alice,
            token: address(token),
            height: 2,
            balance: 20 ether,
            participants: nodes,
            sigs: new bytes[](0)
        });
        state.sigs = _signState(state, nodePks);

        vm.prank(alice);
        vault.request(state, 20 ether);

        // Try immediately
        vm.prank(alice);
        vm.expectRevert("Challenge period not expired");
        vault.withdraw(state);
    }

    function test_InvalidSignatures() public {
        uint256 depositAmount = 100 ether;
        vm.prank(alice);
        vault.deposit(alice, address(token), depositAmount);

        // Create random keys
        uint256[] memory randomPks = new uint256[](3);
        randomPks[0] = 0xBAD1;
        randomPks[1] = 0xBAD2;
        randomPks[2] = 0xBAD3;

        address[] memory randomNodes = new address[](3);
        randomNodes[0] = vm.addr(randomPks[0]);
        randomNodes[1] = vm.addr(randomPks[1]);
        randomNodes[2] = vm.addr(randomPks[2]);

        State memory state = State({
            wallet: alice,
            token: address(token),
            height: 2,
            balance: 20 ether,
            participants: randomNodes,
            sigs: new bytes[](0)
        });
        
        // Sign with random keys
        state.sigs = _signState(state, randomPks);

        vm.prank(alice);
        vm.expectRevert("Unauthorized participant");
        vault.request(state, 20 ether);
    }

    function test_NodeRemoval() public {
        uint256 depositAmount = 100 ether;
        vm.prank(alice);
        vault.deposit(alice, address(token), depositAmount);

        State memory state = State({
            wallet: alice,
            token: address(token),
            height: 2,
            balance: 20 ether,
            participants: nodes,
            sigs: new bytes[](0)
        });
        state.sigs = _signState(state, nodePks);

        // Remove a node
        address nodeToRemove = nodes[0];
        vm.prank(vault.owner());
        vault.setNodeStatus(nodeToRemove, false);

        vm.prank(alice);
        vm.expectRevert("Unauthorized participant");
        vault.request(state, 20 ether);
    }
}
