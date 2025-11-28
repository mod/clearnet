// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IDeposit.sol";
import "./interfaces/IWithdraw.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract Vault is IDeposit, IWithdraw {
    // --- State Variables ---

    // Mapping of authorized nodes (Signers)
    // In a real system, this would be managed by a staking/licensing contract.
    // For this implementation, we allow the deployer to manage it.
    mapping(address => bool) public isNode;
    address public owner;

    // Challenge period duration (e.g., 10 minutes)
    uint256 public constant CHALLENGE_PERIOD = 10 minutes;

    struct WithdrawalRequestData {
        uint256 amount;
        uint256 expiration;
        uint256 height;
        address token;
    }

    // Pending withdrawal requests: Wallet => Request Data
    mapping(address => WithdrawalRequestData) public requests;

    // --- Modifiers ---

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // --- Constructor ---

    constructor() {
        owner = msg.sender;
    }

    // --- Admin Functions ---

    function setNodeStatus(address node, bool status) external onlyOwner {
        isNode[node] = status;
    }

    // --- IDeposit Implementation ---

    function deposit(address account, address token, uint256 amount) external payable override {
        if (token == address(0)) {
            require(msg.value == amount, "Invalid ETH amount");
        } else {
            require(msg.value == 0, "No ETH allowed for ERC20 deposit");
            // Transfer tokens from sender to this contract
            // We assume the user has approved this contract
            bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
            require(success, "ERC20 transfer failed");
        }

        emit Deposited(account, token, amount);
    }

    // --- IWithdraw Implementation ---

    function request(State calldata candidate, uint256 amount) external override {
        require(msg.sender == candidate.wallet, "Not wallet owner");
        require(amount <= candidate.balance, "Withdrawal exceeds state balance");
        require(requests[msg.sender].expiration == 0, "Request already pending");

        // Verify that the state is signed by a valid quorum
        _verifyStateSignatures(candidate);

        uint256 expiration = block.timestamp + CHALLENGE_PERIOD;

        requests[msg.sender] = WithdrawalRequestData({
            amount: amount, expiration: expiration, height: candidate.height, token: candidate.token
        });

        // The interface defines `event Challenged(address indexed wallet, State state, uint256 expiration);`
        // Since `request` starts the challenge period, we emit it here.
        emit Requested(candidate.wallet, candidate.token, amount);
        emit Challenged(candidate.wallet, candidate, expiration);
    }

    function challenge(State calldata candidate) external override {
        WithdrawalRequestData memory req = requests[candidate.wallet];
        require(req.expiration > 0, "No pending request");
        require(candidate.height > req.height, "Candidate state not newer");
        require(candidate.wallet == msg.sender || isNode[msg.sender], "Only owner or node can challenge");
        // Actually, usually ONLY Nodes challenge. But maybe the user can self-correct?
        // README: "A Node detects the discrepancy... It calls challenge()"
        // I'll allow nodes.

        // Verify signatures of the newer state
        _verifyStateSignatures(candidate);

        // Valid challenge: Cancel the withdrawal
        emit Rejected(candidate.wallet, req.token, req.amount);

        delete requests[candidate.wallet];
    }

    function withdraw(State calldata finalize) external override {
        WithdrawalRequestData memory req = requests[finalize.wallet];
        require(req.expiration > 0, "No pending request");
        require(block.timestamp >= req.expiration, "Challenge period not expired");
        require(finalize.height == req.height, "State mismatch");

        // Verify signatures again?
        // Not strictly necessary if we trusted it at `request` and no challenge occurred.
        // But `finalize` passed as calldata might differ from what was requested if we only stored hash?
        // We stored `height`. We trust `req.amount`.
        // We assume `finalize` matches the `request` state.

        uint256 amount = req.amount;
        address token = req.token;
        address payable recipient = payable(finalize.wallet);

        // Delete request BEFORE transfer to prevent reentrancy
        delete requests[finalize.wallet];

        if (token == address(0)) {
            (bool success,) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            bool success = IERC20(token).transfer(recipient, amount);
            require(success, "ERC20 transfer failed");
        }

        emit Withdrawn(recipient, token, amount);
    }

    // --- Internal Helpers ---

    function _verifyStateSignatures(State calldata state) internal view {
        // 1. Reconstruct State Hash
        // keccak256(abi.encode(wallet, token, height, balance, participants));
        bytes32 stateHash =
            keccak256(abi.encode(state.wallet, state.token, state.height, state.balance, state.participants));

        // 2. ECDSA Prefix
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", stateHash));

        // 3. Check Quorum
        // We assume `sigs` aligns with `participants`?
        // Or `sigs` is just a list of signatures from ANY participants?
        // Struct: `address[] participants; bytes[] sigs;`
        // Usually implies 1-to-1 or logic to map them.
        // "A valid State requires a specific quorum... to be considered authoritative."
        // For simplicity: We require `sigs.length == participants.length` and each `sigs[i]` corresponds to `participants[i]`.
        // AND we require that a sufficient number of participants are valid Nodes.

        require(state.sigs.length == state.participants.length, "Sig length mismatch");
        require(state.participants.length > 0, "No participants");

        // We require ALL listed participants to have signed?
        // Or just that the signatures provided are valid for the listed participants?
        // The README says "participants: List of nodes forming the quorum".
        // So we verify all of them.

        for (uint256 i = 0; i < state.participants.length; i++) {
            address participant = state.participants[i];
            // Ensure participant is authorized node (Mock check)
            require(isNode[participant], "Unauthorized participant");

            bytes memory sig = state.sigs[i];
            require(sig.length == 65, "Invalid signature length");

            // Split signature
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(sig, 32))
                s := mload(add(sig, 64))
                v := byte(0, mload(add(sig, 96)))
            }

            address signer = ecrecover(signedHash, v, r, s);
            require(signer == participant, "Invalid signature");
        }
    }
}
