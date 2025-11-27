---
description: "Task list template for feature implementation"
---

# Tasks: Protocol Logic & Smart Contracts

**Input**: Design documents from `/specs/001-protocol-logic/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are OPTIONAL but included here as Foundry tests and Go simulation are core requirements of the spec.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Initialize Foundry project in contracts/evm
- [x] T002 [P] Configure Go simulation environment in cmd/demo/main.go
- [x] T003 [P] Create initial interfaces/IDeposit.sol and interfaces/IWithdraw.sol in contracts/evm/src/interfaces/

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Implement State struct and hashing helpers in contracts/evm/src/libraries/StateUtils.sol
- [x] T005 [P] Implement corresponding State struct and hash logic in Go for simulation (pkg/core/types.go or similar)
- [x] T006 Create base Vault.sol contract shell with storage layout (registry, requests mappings)
- [x] T007 Implement NodeRegistry logic (add/remove node) in contracts/evm/src/Vault.sol
- [x] T008 [P] Implement MockVault struct and NodeRegistry logic in cmd/demo/main.go

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

## Phase 3: User Story 1 - Secure Deposit & Withdrawal (Happy Path) (Priority: P1) 🎯 MVP

**Goal**: Enable users to deposit funds, request withdrawal with valid state, and finalize withdrawal after challenge period.

**Independent Test**: Full cycle test: Deposit -> Request -> Wait -> Withdraw in both Forge and Go Simulation.

### Tests for User Story 1

- [x] T009 [P] [US1] Create Foundry test file contracts/evm/test/Vault.t.sol with test_Deposit and test_RequestWithdrawal
- [x] T010 [P] [US1] Create Go test scenario "happy-path" in cmd/demo/main.go

### Implementation for User Story 1

- [x] T011 [US1] Implement deposit() function in contracts/evm/src/Vault.sol
- [x] T012 [US1] Implement request() function in contracts/evm/src/Vault.sol (signature verification, storage)
- [x] T013 [US1] Implement withdraw() function in contracts/evm/src/Vault.sol (timelock check, transfer)
- [x] T014 [US1] Implement Deposit, Request, Withdraw logic in Go simulation (cmd/demo/main.go)
- [x] T015 [US1] Verify Happy Path scenario passes in both environments

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

## Phase 4: User Story 2 - Fraud Prevention via Challenge (Priority: P1)

**Goal**: Allow validators to submit fraud proofs (newer states) to cancel invalid withdrawal requests.

**Independent Test**: Submit stale request -> Submit challenge with fresh state -> Verify request cancelled.

### Tests for User Story 2

- [x] T016 [P] [US2] Add test_ChallengeFraud to contracts/evm/test/Vault.t.sol
- [x] T017 [P] [US2] Add Go test scenario "fraud-challenge" in cmd/demo/main.go

### Implementation for User Story 2

- [x] T018 [US2] Implement challenge() function in contracts/evm/src/Vault.sol
- [x] T019 [US2] Implement Challenge logic in Go simulation (cmd/demo/main.go)
- [x] T020 [US2] Verify Fraud Prevention scenario passes in both environments

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

## Phase 5: User Story 3 - Node Authorization (Priority: P2)

**Goal**: Ensure only signatures from currently registered nodes are accepted.

**Independent Test**: Submit state signed by non-node -> Revert. Remove node -> Submit old sig -> Revert.

### Tests for User Story 3

- [x] T021 [P] [US3] Add test_InvalidSignatures and test_NodeRemoval to contracts/evm/test/Vault.t.sol

### Implementation for User Story 3

- [x] T022 [US3] Refine signature verification in contracts/evm/src/Vault.sol to check current registry status (FR-009)
- [x] T023 [US3] Update Go simulation to enforce registry checks
- [x] T024 [US3] Verify Node Authorization logic

**Checkpoint**: All user stories should now be independently functional

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T026 Validate Kademlia ordering logic in signature verification
- [x] T027 Ensure SHA256/Keccak consistency between Go and Solidity (FR-011)
- [x] T028 Update quickstart.md with final test commands
- [x] T029 Run full simulation suite

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup
- **User Stories (Phase 3+)**: Depend on Foundational
- **Polish (Phase 6)**: Depends on all stories

### User Story Dependencies

- **US1 (P1)**: Independent after Foundational
- **US2 (P1)**: Can be built after US1 logic exists (sharing state structure)
- **US3 (P2)**: Refines US1/US2 logic, best implemented last to ensure core flows work first

### Parallel Opportunities

- Foundry (Solidity) and Go (Simulation) tasks can run in parallel by different developers (or sequential context switches)
- Tests can be written in parallel with implementation
- Documentation updates can happen anytime

## Implementation Strategy

### MVP First (User Story 1 & 2)

1. Complete Setup & Foundation.
2. Implement Happy Path (US1) -> Verify deposits/withdrawals.
3. Implement Fraud Path (US2) -> Verify security.
4. Refine with Authorization (US3).
5. Polish & Gas Optimize.