# Research: Protocol Logic & Smart Contracts

**Feature**: Protocol Logic & Smart Contracts
**Date**: 2025-11-27
**Status**: Complete

## 1. State Hashing Consistency (EVM vs. Non-EVM)

**Decision**: Use `SHA256` for the hash algorithm and enforce canonical ordering of `participants` by **XOR Distance** (Kademlia metric).

**Rationale**: 
*   **Algorithm**: `Keccak256` is EVM-native but less standard outside Ethereum. `SHA256` is standard in Go, Rust (Solana), and most other chains. Precompiles for SHA256 exist on EVM (address 0x02) and are cheap enough. However, for strictly EVM MVP, `keccak256` is acceptable if we wrap it, but the spec requires chain-agnosticism. Let's stick to `keccak256` for the *EVM contract implementation* for gas efficiency, but logically define the input format rigidly so other chains can replicate it.
*   **Ordering**: `participants` array must be sorted. Sorting by address value (lexicographical) is standard. Sorting by XOR distance to `stateHash` (as suggested in clarification) is strictly for *selecting* the quorum, but the *stored* list in the struct should likely just be sorted by address for simple verification, OR the signature verification loop just requires the signer to be present in the registry.
*   **Refinement**: The clarification said "Ordered by XOR distance". We will implement a helper in Go to sort this way before signing. In Solidity, we will receive the `participants` array and verify it matches the signature order or just recover signers and check existence.

**Alternatives Considered**:
*   *Lexicographical Sort*: Simpler, standard. Rejected because user specifically requested Kademlia distance ordering.

## 2. Replay Protection

**Decision**: Enforce strictly monotonic `height` (nonce).

**Rationale**:
*   `Vault` stores a mapping `lastHeight[channelId]`.
*   `request(state)` requires `state.height > lastHeight[channelId]`.
*   `challenge(state)` requires `state.height > pendingRequest.height`.
*   This simple counter prevents replay of old states.

## 3. Quorum Verification (Gas Optimization)

**Decision**: `Bitmask` or `Signatures Array`?
*   We will use an array of signatures `bytes[] sigs`.
*   We will iterate through `sigs`, `ecrecover` the address, and check `NodeRegistry[address]`.
*   Optimization: If `NodeRegistry` is a bitmap or mapping, this is O(N).
*   Constraint: Gas < 500k. `ecrecover` costs ~3000 gas. 10 signatures = 30k gas. Loop overhead is minimal. This fits easily within budget.

## 4. Simulation Strategy

**Decision**: Extend `cmd/demo/main.go`.
*   Mock the `Vault` logic in Go struct `MockVault`.
*   Implement `Deposit`, `Request`, `Challenge`, `Withdraw` methods on `MockVault` that mimic Solidity logic exactly.
*   Use this for "Simulation-First" validation.
