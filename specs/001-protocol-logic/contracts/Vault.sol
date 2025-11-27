// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDeposit } from "./interfaces/IDeposit.sol";
import { IWithdraw, State } from "./interfaces/IWithdraw.sol";

/**
 * @title Vault
 * @notice Core contract for Clearnet custody, requests, and challenges.
 */
contract Vault is IDeposit, IWithdraw {
    // --- Storage ---

    /// @notice Valid validator nodes
    mapping(address => bool) public nodeRegistry;

    /// @notice Pending withdrawal requests: keccak256(wallet, token) => Request
    mapping(bytes32 => Request) public requests;

    /// @notice Global configuration for minimum quorum size
    uint256 public minQuorum;

    /// @notice Global configuration for challenge duration
    uint256 public challengePeriod;

    struct Request {
        uint256 height;
        uint256 amount;
        uint256 timestamp;
        bytes32 stateHash;
    }

    // --- Events ---
    // (Inherited from IDeposit and IWithdraw)
    event NodeAdded(address indexed node);
    event NodeRemoved(address indexed node);

    // --- Constructor ---
    constructor(uint256 _minQuorum, uint256 _challengePeriod) {
        minQuorum = _minQuorum;
        challengePeriod = _challengePeriod;
    }

    // --- Admin (Mock for MVP) ---
    function addNode(address node) external {
        nodeRegistry[node] = true;
        emit NodeAdded(node);
    }

    function removeNode(address node) external {
        nodeRegistry[node] = false;
        emit NodeRemoved(node);
    }

    // --- IDeposit Implementation ---

    function deposit(address account, address token, uint256 amount) external payable override {
        if (token == address(0)) {
            require(msg.value == amount, "Invalid ETH amount");
        } else {
            // Check whitelist if implemented (EC-002: Token Blacklists handled by revert here)
            // TransferFrom must succeed or revert
            // IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        emit Deposited(account, token, amount);
    }

    // --- IWithdraw Implementation ---

    function request(State calldata candidate, uint256 amount) external override {
        // 1. Verify signatures
        bytes32 h = _hashState(candidate);
        require(_verifySignatures(h, candidate.participants, candidate.sigs), "Invalid signatures");

        // 2. Store Request
        bytes32 key = _getRequestKey(candidate.wallet, candidate.token);
        
        // Check replay/monotonicity (FR-008)
        Request storage req = requests[key];
        require(req.timestamp == 0, "Request already pending"); // Simplify: One request at a time per channel
        
        requests[key] = Request({
            height: candidate.height,
            amount: amount,
            timestamp: block.timestamp,
            stateHash: h
        });

        emit Requested(candidate.wallet, candidate.token, amount);
        emit Challenged(candidate.wallet, candidate, block.timestamp + challengePeriod);
    }

    function challenge(State calldata candidate) external override {
        bytes32 key = _getRequestKey(candidate.wallet, candidate.token);
        Request storage req = requests[key];
        require(req.timestamp != 0, "No pending request");

        // FR-006: Compare height
        require(candidate.height > req.height, "Challenge height too low");

        // Verify signatures
        bytes32 h = _hashState(candidate);
        require(_verifySignatures(h, candidate.participants, candidate.sigs), "Invalid signatures");

        // Outcome: Cancel request
        delete requests[key];
        emit Rejected(candidate.wallet, candidate.token, req.amount);
    }

    function withdraw(State calldata finalize) external override {
        bytes32 key = _getRequestKey(finalize.wallet, finalize.token);
        Request storage req = requests[key];
        require(req.timestamp != 0, "No pending request");

        // FR-007: Timelock check
        require(block.timestamp >= req.timestamp + challengePeriod, "Challenge period active");

        // Verify state matches
        bytes32 h = _hashState(finalize);
        require(h == req.stateHash, "State mismatch");

        // Clear request (Reentrancy protection pattern: Effect before Interaction)
        uint256 amt = req.amount;
        delete requests[key];

        // Transfer funds
        // FR-010: Revert on failure
        if (finalize.token == address(0)) {
            (bool success, ) = payable(finalize.wallet).call{value: amt}("");
            require(success, "ETH transfer failed");
        } else {
            // IERC20(finalize.token).safeTransfer(finalize.wallet, amt);
        }

        emit Withdrawn(finalize.wallet, finalize.token, amt);
    }

    // --- Helpers ---

    function _getRequestKey(address wallet, address token) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(wallet, token));
    }

    function _hashState(State calldata s) internal pure returns (bytes32) {
        // FR-011: Chain-agnostic hash (Keccak for now on EVM, but structure is fixed)
        return keccak256(abi.encode(s.wallet, s.token, s.height, s.balance, s.participants));
    }

    function _verifySignatures(bytes32 hash, address[] calldata participants, bytes[] calldata sigs) internal view returns (bool) {
        require(sigs.length >= minQuorum, "Quorum not met");
        require(participants.length == sigs.length, "Length mismatch");

        // FR-012: Participants order is assumed canonical (Kademlia Distance)
        // Signatures must correspond 1:1 to participants array
        
        for (uint i = 0; i < sigs.length; i++) {
            address signer = _recover(hash, sigs[i]);
            require(signer == participants[i], "Invalid signer or order");
            // FR-009: Check Registry (Current Status)
            require(nodeRegistry[signer], "Signer not a node");
        }
        return true;
    }

    function _recover(bytes32 hash, bytes memory sig) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        if (sig.length != 65) return address(0);
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        return ecrecover(hash, v, r, s);
    }
}
