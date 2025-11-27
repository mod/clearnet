# Feature Specification: Protocol Logic & Smart Contracts

**Feature Branch**: `001-protocol-logic`
**Created**: 2025-11-27
**Status**: Draft
**Input**: User description: "Define the blockchain protocol and how to implement valid smart-contract for clearnet"

## Clarifications

### Session 2025-11-27
- Q: How to handle signatures from nodes removed from registry? → A: Check Current Status (Signers must be active in registry at transaction time).
- Q: How to handle token transfer failures (e.g. blacklists)? → A: Revert (Transaction fails, state remains pending, user can retry later).
- Q: How is quorum size determined for the MVP? → A: System-wide Config (Global variable on Vault, service provider pays per replica).
- Q: What is the default CHALLENGE_PERIOD duration? → A: 10 Minutes.
-   Q: How should `participants` be ordered for state hashing? → A: Kademlia Distance (Ordered by XOR distance to stateHash; hashing algorithm is Keccak256).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Deposit & Withdrawal (Happy Path) (Priority: P1)

A user wants to bridge funds into the Layer 3 network, transact, and eventually withdraw their remaining balance back to L1/L2.

**Why this priority**: Core value proposition. Without this, funds cannot enter or leave the system.

**Independent Test**: Can be tested via simulation (`cmd/demo`) and local chain (Anvil/Local Validator) by performing a full cycle: Deposit -> Wait -> Withdraw.

**Acceptance Scenarios**:

1.  **Given** a user has 100 USDC and the Vault contract is deployed, **When** the user calls `deposit(userAddr, usdcAddr, 100)`, **Then** the Vault balance increases by 100 and a `Deposited` event is emitted.
2.  **Given** a user has a valid off-chain State (height 5) signed by a quorum of nodes, **When** they call `request(state, 20)`, **Then** the request is recorded, `Requested` event is emitted, and the Challenge Period starts.
3.  **Given** the Challenge Period has expired with no challenges, **When** the user calls `withdraw(state)`, **Then** the Vault transfers the 20 USDC to the user and `Withdrawn` event is emitted.

---

### User Story 2 - Fraud Prevention via Challenge (Priority: P1)

A Node (Validator) watches for malicious withdrawal requests (using old states) and submits a fraud proof to protect the integrity of the ledger.

**Why this priority**: Critical security requirement. Without this, the system is susceptible to double-spending/replay attacks.

**Independent Test**: Can be tested by manually submitting a "stale" state request, then submitting a "fresh" state challenge.

**Acceptance Scenarios**:

1.  **Given** a pending withdrawal request for State Height 5, **When** a Node submits a valid State Height 6 (signed by quorum) via `challenge(state)`, **Then** the pending request is immediately cancelled/deleted.
2.  **Given** a pending withdrawal request, **When** a challenge is submitted with an *older* or *equal* height (Height 4), **Then** the challenge is reverted/ignored.
3.  **Given** a challenge is successful, **Then** a `Rejected` event is emitted.

---

### User Story 3 - Node Authorization (Priority: P2)

The protocol must ensure that only states signed by authorized Nodes are accepted.

**Why this priority**: Prevents Sybil attacks where an attacker spins up fake nodes to sign invalid states.

**Independent Test**: verifiable by attempting to submit a state signed by a non-registered key.

**Acceptance Scenarios**:

1.  **Given** a State signed by random keys (not in Node Registry), **When** submitted to `request` or `challenge`, **Then** the transaction reverts with "Invalid Signatures".
2.  **Given** a State signed by a valid quorum of registered Nodes, **When** submitted, **Then** the signature verification passes.

## Requirements *(mandatory)*

### Functional Requirements

-   **FR-001**: The system MUST support a `State` data structure containing: `wallet`, `token`, `height`, `balance`, `participants`, and `sigs`.
-   **FR-002**: The Vault contract MUST verify that the `sigs` on a submitted `State` belong to valid, registered Nodes listed in `participants`.
-   **FR-003**: The Vault contract MUST enforce a global, system-wide quorum configuration (e.g., `minQuorum` or percentage) for the MVP phase.
-   **FR-004**: The `deposit` function MUST accept ERC20 (EVM) or SPL Tokens (SVM) and record the deposit on-chain via `Deposited` event.
-   **FR-005**: The `request` function MUST lock the withdrawal for a configurable `CHALLENGE_PERIOD` (set to 10 minutes for MVP).
-   **FR-006**: The `challenge` function MUST accept a `State` and compare its `height` against the pending request.
-   **FR-007**: The `withdraw` function MUST only succeed if `block.timestamp > request.timestamp + CHALLENGE_PERIOD` and the `finalize` state matches the requested state.
-   **FR-008**: The protocol MUST prevent replay attacks by ensuring used heights cannot be reused for the same channel if applicable, or by strictly enforcing monotonic height increases for challenges.
-   **FR-009**: The Vault contract MUST validate node status at transaction time; if a signer is no longer active in the Node Registry at the moment of submission, their signature MUST be considered invalid.
-   **FR-010**: If a token transfer fails during `withdraw` (e.g., blacklist), the transaction MUST revert completely, leaving the request in a pending state to allow retries.
-   **FR-011**: The `stateHash` computation MUST use `Keccak256` (standard EVM hash) of the ABI-encoded `State` fields. Contracts MUST recalculate this hash from the submitted `State` struct before verification.
-   **FR-012**: The `participants` list in the State MUST be canonically ordered by Kademlia binary distance (XOR) between the `stateHash` (Keccak256) and the node's public address to ensure deterministic validation.

### Key Entities

-   **State**: The off-chain ledger snapshot.
    -   Attributes: `wallet` (address), `token` (address), `height` (uint256), `balance` (uint256), `participants` (address[]), `sigs` (bytes[]).
-   **Vault**: The smart contract holding assets.
-   **NodeRegistry**: On-chain mapping or list of authorized Validator public keys (`isNode` in EVM).

## Success Criteria *(mandatory)*

### Measurable Outcomes

-   **SC-001**: 100% of invalid withdrawal requests (attempting to withdraw with height < current_height) are rejected when a valid challenge is submitted.
-   **SC-002**: Valid withdrawals can be finalized in `CHALLENGE_PERIOD + 2 block times` (latency), which for MVP will be 10 minutes + 2 block times.
-   **SC-003**: Gas cost for `deposit`, `request`, `challenge`, and `withdraw` transactions is optimized (target < 300k gas for `deposit` and `withdraw`, < 500k gas for `challenge`) to ensure economic viability.
-   **SC-004**: System supports a configurable system-wide quorum size (MVP).

### Edge Cases

-   **EC-001**: **Registry Updates**: Signatures are checked against the registry state at the time of transaction execution (per FR-009). Users must re-gather signatures if a signer is removed before submission.
-   **EC-002**: **Token Blacklists**: Handling of ERC20 transfer failures (e.g., USDC blacklist) results in a revert (per FR-010). The user can retry later if the issue resolves.