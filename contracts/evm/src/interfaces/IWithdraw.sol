// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice State structure for state representation
 * @dev Contains application data, asset allocations, and signatures
 */
struct State {
    address wallet; // wallet on which the operation is made
    address token; // ERC-20 token contract address (address(0) for native tokens)
    uint256 height; // State version incremental number to compare most recent
    uint256 balance; // Token balance remaining after the operation
    address[] participants; // List of participants in the quorum
    bytes[] sigs; // stateHash signatures from participants
}

/**
 * @title IWithdraw Interface
 * @notice Main interface for the Clearnet withdrawing system
 * @dev Defines the core functions for challenging withdrawals
 */
interface IWithdraw {
    /**
     * @notice Emitted when tokens a withdraw is requested
     * @param wallet Address of the account whose ledger is changed
     * @param token Token address (use address(0) for native tokens)
     * @param amount Amount of tokens withdrawn
     */
    event Requested(address indexed wallet, address indexed token, uint256 amount);

    /**
     * @notice Emitted when tokens a withdraw is rejected
     * @param wallet Address of the account whose ledger is changed
     * @param token Token address (use address(0) for native tokens)
     * @param amount Amount of tokens withdrawn
     */
    event Rejected(address indexed wallet, address indexed token, uint256 amount);

    /**
     * @notice Emitted when tokens are withdrawn from the contract
     * @param wallet Address of the account whose ledger is changed
     * @param token Token address (use address(0) for native tokens)
     * @param amount Amount of tokens withdrawn
     */
    event Withdrawn(address indexed wallet, address indexed token, uint256 amount);

    /**
     * @notice Emitted when a wallet enters the challenge period
     * @param wallet Address of the account whose ledger is changed
     * @param state The state that initiated the challenge
     * @param expiration Timestamp when the challenge period expires
     */
    event Challenged(address indexed wallet, State state, uint256 expiration);

    /**
     * @notice Starts a withdraw request which initiate challange period
     * @param candidate is the latest valid state for this user account
     * @param amount amount of tokens to withdraw
     */
    function request(State calldata candidate, uint256 amount) external;

    /**
     * @notice withdraws tokens from the contract after challenge period
     * @param finalize The state to finalize the withdrawal for
     */
    function withdraw(State calldata finalize) external;

    /**
     * @notice Initiates or updates a challenge with a signed state
     * @dev Starts a challenge period during which participants can respond with newer states
     * @param candidate The state being submitted as the latest valid state
     */
    function challenge(State calldata candidate) external;
}
