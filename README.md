# Clearnet

Clearnet is a decentralized network of Go nodes designed to replicate and manage ledger entries for Web3 users. It functions as a simplified virtual state channel network, synchronizing data from on-chain blockchain events (EVM & SVM) and off-chain libp2p Kademlia writes.

## Tech Stack

*   **Node Core:** Go (Golang)
*   **Database:** DuckDB (SQLite) / In-Memory (Mock)
*   **Networking:** libp2p (Kademlia DHT)
*   **Smart Contracts (EVM):** Solidity (Foundry/Forge)
*   **Smart Contracts (SVM):** Rust (Anchor Framework)

## Architecture

The system consists of three main components:

1.  **Vault Smart Contract (Multi-Chain):**
    *   **EVM (Ethereum/L2s):** `Vault.sol` - Manages ERC20/Native custody, withdrawal requests, and challenges.
    *   **SVM (Solana):** `clearnet` Program - Manages SPL Token custody via PDAs and Anchor instructions.
    *   Implements the core lifecycle: `Deposit` -> `Request` -> `Challenge` (optional) -> `Withdraw`.

2.  **P2P Network (Go Nodes):**
    *   Maintains the replicated ledger state off-chain.
    *   Listens for on-chain events (`WithdrawalRequested`).
    *   Compares on-chain requests against local off-chain state to detect fraud.
    *   Participates in the challenge mechanism.

3.  **Clients & Applications:**
    *   Users and dApps interacting with the ledger to perform transfers and withdrawals.
    *   Responsible for collecting quorum signatures for state updates.

## Functional Specification

### User Flows

#### Happy Case (Valid Withdrawal)

1.  **Deposit:** Alice deposits 100 USDT into the Vault contract. This emits a `Deposited` event.
2.  **Off-chain Transfer:** Alice transfers 80 USDT off-chain. Her ledger state is updated (Version 2) and replicated across the P2P network.
3.  **Withdrawal Request:** Alice wants to withdraw her remaining 20 USDT. She requests the latest state from the network.
4.  **On-chain Request:** Alice calls `request()` on the Vault contract with State Version 2.
5.  **Verification:** Nodes consume the `Requested` event. They verify if the submitted state matches the latest known state in the network.
6.  **Challenge Period:** A challenge window (e.g., 10 minutes) begins.
7.  **Finalize:** No dispute occurs. The challenge period expires.
8.  **Withdraw:** Alice calls `withdraw()`. The contract transfers the tokens to her wallet.

#### Unhappy Case (Fraud Attempt)

1.  **Deposit:** Alice deposits 100 USDT (State Version 1).
2.  **Spend:** Alice spends 40 USDT off-chain (State Version 2, Balance 60).
3.  **Fraudulent Request:** Alice attempts to withdraw 100 USDT using the old State Version 1.
4.  **Challenge:** A Node detects the discrepancy via the `WithdrawalRequested` event. It holds a signed State Version 2 (which supersedes Version 1).
5.  **Rejection:** The Node calls `challenge()` on the Vault contract with the newer proof (Version 2).
6.  **Slash/Reject:** The smart contract validates the newer state (`candidate.height > current.height`) and rejects the withdrawal request.

## Data Structures & Consensus

### State Hash

A unique identifier for a specific state of a channel entry.

**EVM Construction:**
```solidity
keccak256(abi.encode(wallet, token, height, balance, participants));
```

**Go/Core Construction:**
```go
// SHA256 of formatted string
fmt.Sprintf("%s:%s:%d:%s:%s", wallet, token, version, balance, participants)
```

### Core Structs

*   **State:** The signed data package containing the ledger snapshot:
    *   `wallet` (Address/Pubkey): The user's identifier.
    *   `token` (Address/Mint): The asset identifier.
    *   `version` / `height` (uint64): Incremental counter for ordering.
    *   `balance` (BigInt/u64): The user's current claimable balance.
    *   `participants` (Array): List of nodes/validators forming the quorum.
    *   `sigs` (Array): Signatures validating the state.

### Quorum & Replication

*   **Quorum:** A valid State requires a specific quorum of signatures (e.g., 3 out of N closest nodes) to be considered authoritative.
*   **Publication:** States are published to the P2P network.
*   **Verification:** Smart contracts verify that `sigs` correspond to valid `participants` and that `participants` are authorized Nodes.

## Smart Contracts Interface

Both EVM and SVM implementations follow a similar pattern:

### 1. Deposit
*   **Input:** Token Address, Amount.
*   **Action:** Transfers funds from User to Vault.
*   **Event:** `Deposited(wallet, token, amount)`.

### 2. Request (Initiate Exit)
*   **Input:** `State` object (candidate).
*   **Action:**
    *   Verifies signatures.
    *   Checks `amount <= state.balance`.
    *   Sets expiration time (`block.timestamp + CHALLENGE_PERIOD`).
    *   Stores pending request.
*   **Event:** `Requested` / `Challenged`.

### 3. Challenge (Fraud Proof)
*   **Input:** `State` object (newer version).
*   **Action:**
    *   Checks if a request exists.
    *   Verifies `candidate.version > request.version`.
    *   Verifies signatures of candidate.
*   **Outcome:** Deletes/Cancels the pending request.
*   **Event:** `Rejected`.

### 4. Withdraw (Finalize)
*   **Input:** `State` object (finalize).
*   **Action:**
    *   Checks `block.timestamp >= expiration`.
    *   Checks `state` matches stored request.
    *   Transfers funds to User.
*   **Event:** `Withdrawn`.

### Implementation Details

#### EVM (`contracts/evm`)
*   **Language:** Solidity 0.8.20
*   **Framework:** Foundry
*   **Key Files:** `Vault.sol`, `IDeposit.sol`, `IWithdraw.sol`.
*   **Security:** Uses `ecrecover` for signature verification. Maintains `isNode` mapping for participant authorization.

#### SVM (`contracts/svm`)
*   **Language:** Rust
*   **Framework:** Anchor
*   **Key Files:** `programs/clearnet/src/lib.rs`
*   **Security:** Uses `VaultConfig` and `NodeEntry` PDAs. Validates accounts passed as `participants`. (Note: Full Ed25519 signature verification requires `ed25519_program` instruction introspection, currently mocked or simplified in prototype).

## Simulation & Demo

The project includes a Go-based simulation to verify the protocol logic without a live blockchain.

**Location:** `cmd/demo/main.go`

**Features:**
*   **MockChain:** Simulates block time, event emission, and contract logic (in-memory).
*   **MockP2P:** Simulates node discovery (DHT) and latency.
*   **Scenarios:**
    1.  **Happy Path:** Deposit -> State Update -> Request -> Wait -> Withdraw.
    2.  **Fraud Path:** Deposit -> State Update -> Old State Request -> Auto-Challenge by Node -> Withdrawal Blocked.

**Running the Demo:**
```bash
go run cmd/demo/main.go
```

## Security & Economic Model

### Node Licensing
*   **Registry:** Nodes must register their public keys in an on-chain registry (`NodeEntry` in SVM, `isNode` in EVM).
*   **Staking:** Nodes stake tokens to participate (Future Scope).

### Fraud Prevention
*   **Watcher Nodes:** Nodes continuously monitor `Requested` events.
*   **Incentives:** Challengers can be rewarded with a portion of the slashed funds (Future Scope).