# Data Model: Protocol Logic

**Feature**: Protocol Logic & Smart Contracts
**Date**: 2025-11-27

## Entities

### State (Off-chain & On-chain)

The core data structure representing a snapshot of the channel.

| Field | Type (Solidity) | Type (Go) | Description |
|-------|----------------|-----------|-------------|
| `wallet` | `address` | `common.Address` | User's wallet address (Channel owner) |
| `token` | `address` | `common.Address` | Asset address (`address(0)` for Native) |
| `height` | `uint256` | `uint64` | Monotonic counter (Version/Nonce) |
| `balance` | `uint256` | `*big.Int` | User's remaining balance |
| `participants` | `address[]` | `[]common.Address` | List of quorum nodes (Ordered by XOR distance) |
| `sigs` | `bytes[]` | `[][]byte` | Signatures from participants |

### Vault Storage (On-chain)

| Field | Type | Description |
|-------|------|-------------|
| `requests` | `mapping(bytes32 => Request)` | Pending withdrawal requests. Key: `keccak256(wallet, token)` |
| `nodeRegistry` | `mapping(address => bool)` | Set of valid Validator nodes |
| `minQuorum` | `uint256` | Minimum number of signatures required (Global Config) |
| `challengePeriod` | `uint256` | Duration in seconds (Default: 600 aka 10 mins) |

### Request (Struct)

| Field | Type | Description |
|-------|------|-------------|
| `height` | `uint256` | Height of the requested state |
| `amount` | `uint256` | Amount requested to withdraw |
| `timestamp` | `uint256` | Block timestamp when request was made |
| `stateHash` | `bytes32` | Hash of the full state for verification |

## Validation Rules

1.  **Quorum**: `count(valid_signatures) >= minQuorum`.
2.  **Registry**: `nodeRegistry[signer] == true`.
3.  **Monotonicity**: `request.height > last_known_height` (if tracked) OR just strict comparison during challenge (`challenge.height > request.height`).
4.  **Timelock**: `block.timestamp >= request.timestamp + challengePeriod` for finalization.

## State Transitions

```mermaid
graph TD
    A[Idle] -->|request(State)| B[Requested]
    B -->|challenge(NewerState)| A[Idle / Cancelled]
    B -->|wait(ChallengePeriod)| C[Finalizable]
    C -->|withdraw(State)| D[Withdrawn]
```
