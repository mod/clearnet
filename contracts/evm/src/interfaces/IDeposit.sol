// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Deposit Interface
 * @notice Interface for contracts that manage token deposits
 * @dev Handles funds that can be custodied to Clearnet
 */
interface IDeposit {
    /**
     * @notice Emitted when tokens are deposited into the contract
     * @param wallet Address of the account whose ledger is changed
     * @param token Token address (use address(0) for native tokens)
     * @param amount Amount of tokens deposited
     */
    event Deposited(address indexed wallet, address indexed token, uint256 amount);

    /**
     * @notice Deposits tokens into the contract
     * @dev For native tokens, the value should be sent with the transaction
     * @param account Address of the account whose ledger is changed
     * @param token Token address (use address(0) for native tokens)
     * @param amount Amount of tokens to deposit
     */
    function deposit(address account, address token, uint256 amount) external payable;
}
