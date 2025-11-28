# Roadmap

This document outlines the development path for Clearnet, moving from the current simulation prototype to a fully decentralized production network.

## Milestone 1: Protocol Foundation & Simulation (Current State)

*Focus: Core logic verification, smart contract safety, and simulation.*

- [x] **001-protocol-logic**: Core `Vault` contract (EVM), `State` hashing, and "Happy/Fraud" path simulation.
- [x] **002-node-registry**: Node registration, staking (250k YELLOW), and discovery logic (on-chain & mock).

## Milestone 2: Off-chain Node Protocol Logic

*Focus: Solidifying the Node's "Brain" - handling state transitions, quorum consensus, and fraud detection rules in `pkg/core`.*

- [ ] **003-core-state-machine**: Implement the formal State Transition Engine.
  - Define strict `Transition(State, Action) -> State` logic (e.g. Apply Transfer).
    - *Test*: `go test ./pkg/core/state_test.go` (Unit tests for transition rules).
  - Input Validation & Consistency Checks (e.g. Sequence validity, Balance checks).
    - *Test*: `go test ./pkg/core/validator_test.go` (Fuzzing inputs).

- [ ] **004-quorum-manager**: Logic for collecting and verifying signatures.
  - Implement `SignatureVerifier` (Recover signer from hash).
    - *Test*: `go test ./pkg/crypto` (Verify against known vectors).
  - Implement `QuorumCollector` (Aggregating signatures to meet threshold).
    - *Test*: `go test ./pkg/consensus` (Simulate partial/full quorums).
  - Registry Integration (Verify signers against `IRegistry` interface).
    - *Test*: `go test ./pkg/consensus` (Mock Registry with authorized/unauthorized peers).

- [ ] **005-fraud-sentinel**: The decision engine for monitoring and challenging.
  - `ComparisonEngine` (Compare On-chain Request vs Local State).
    - *Test*: `go test ./pkg/engine` (Table-driven tests: Newer/Older/Equal versions).
  - Challenge Trigger Logic (When to fire `chain.Challenge()`).
    - *Test*: `cmd/demo --scenario fraud-unit` (Mock Chain interaction).

## Milestone 3: Persistence & Local Storage

*Focus: Replacing in-memory storage with durable DuckDB. The "Memory".*

- [ ] **006-duckdb-adapter**: Base database integration.
  - Schema Definition & Migration Engine.
    - *Test*: `go test ./pkg/adapters/duckdb` (Verify tables created).
  - CRUD Operations for `State` and `Transactions`.
    - *Test*: `go test ./pkg/adapters/duckdb` (Insert/Select consistency).
  - Concurrency & Transaction Safety.
    - *Test*: `go test ./pkg/adapters/duckdb` (Concurrent writes).

- [ ] **007-state-persistence**: Wiring DB to the Core.
  - `PersistedStore` implementation (Replacing memory map).
    - *Test*: Restart Node -> `GetState` returns data.
  - Historical State Log (Storing history, not just head).
    - *Test*: Query state at height H.

- [ ] **008-crash-recovery**: Ensuring data integrity.
  - Write-Ahead Log (WAL) or Atomic Commit configuration.
    - *Test*: Kill process during write -> Verify DB integrity.
  - Reconstruction from Peers (Basic sync placeholder).
    - *Test*: Start empty node -> Sync from mock peer.

## Milestone 4: Decentralized Networking (P2P)

*Focus: Replacing mock networking with Libp2p Kademlia. The "Voice".*

- [ ] **009-libp2p-host**: Base networking layer.
  - Host Setup & Identity Generation.
    - *Test*: `go test ./pkg/p2p` (Node can start and generate ID).
  - Peer Discovery (DHT integration).
    - *Test*: Two local nodes discover each other via bootstrap.
  - Connection Management (Gating, Limits).
    - *Test*: Connect max peers, verify rejection.

- [ ] **010-p2p-protocol**: Application layer protocols.
  - `PublishState` (GossipSub or Direct Send).
    - *Test*: Node A publishes -> Node B receives event.
  - `GetState` (Request/Response RPC).
    - *Test*: Node A requests Hash -> Node B responds with State.
  - Signature Request Protocol.
    - *Test*: Node A requests Sign -> Node B validates & signs.

- [ ] **011-p2p-hardening**: Robustness.
  - Message Validation & Anti-Spam.
    - *Test*: Send malformed packets -> Node drops them.
  - NAT Traversal & Relay.
    - *Test*: Connect across simulated NAT.
  - Metric Export (Bandwidth, Peers).
    - *Test*: Verify Prometheus metrics.

## Milestone 5: EVM Chain Integration

*Focus: Real Blockchain Interaction. The "Eyes".*

- [ ] **012-evm-listener**: Monitoring the chain.
  - Create a build pipeline to compile Solidity artifacts using abigen
    - Test: Automate build process using `go generate`
  - Create a SimulatedBackend with artifacts deployed for unit tests
    - Test: Test Read and Write on Registry
  - `EthClient` Adapter Setup.
    - *Test*: Connect to Anvil/Goerli.
  - Event Subscription (`Requested`, `Deposited`).
    - *Test*: Emit event on Anvil -> Go Node logs it.
  - Reorganization Handling.
    - *Test*: Simulate chain reorg -> Node adjusts state.

- [ ] **013-evm-writer**: Submitting transactions.
  - Transaction Manager (Nonce handling, Gas estimation).
    - *Test*: Send ETH self-transfer.
  - `Challenge` Submission Logic.
    - *Test*: Detect fraud -> Successfully land challenge tx on Anvil.
  - `Request` Submission Logic.
    - *Test*: Submit valid withdrawal request.

- [ ] **014-integration-safety**: Production readiness.
  - Wallet/Key Management (Keystores).
    - *Test*: Load key from encrypted file.
  - Circuit Breakers (Pause on high gas/errors).
    - *Test*: Simulate high gas -> Tx delayed.
  - Multi-Chain Config (ChainID checks).
    - *Test*: Config mismatch -> Panic/Warn.

## Milestone 6: System Integration

*Focus: Putting it all together.*

- [ ] **015-local-integration**: Wiring components in a local environment.
  - Core + DB + P2P (No Chain).
    - *Test*: Local docker cluster, nodes syncing and persisting.
  - Core + Chain (No P2P).
    - *Test*: Single node interacting with Anvil.
  - Full Local Stack.
    - *Test*: 3 Nodes + Anvil + DuckDB running User Story 1 & 2.

- [ ] **016-testnet-alpha**: Deployment to public testnet.
  - Prepare Terraform files with OpenTofu
  - Infrastructure Setup (Bootnodes, Registry deployment).
  - Node Operator Guide & CLI Polish.
  - Public "War Game" (Incentivized Fraud Test).

## Milestone 7: SVM

*Focus: Support for SVM Chain.*

- [ ] **017-svm-support**: Solana integration.

