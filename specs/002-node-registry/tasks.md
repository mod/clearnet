# Tasks: Node Registry

**Branch**: `002-node-registry` | **Feature**: Node Registry | **Status**: Pending

## Implementation Strategy

We will implement the Node Registry starting with the Solidity smart contract logic, prioritized by user story (Registration -> Discovery -> Updates -> Withdrawals). Once the contract logic is verified with Foundry tests, we will implement the Go integration layer.

**Execution Phases**:
1. **Setup**: Initialize Solidity project and define shared interfaces.
2. **Foundational**: Create the base Registry contract state variables and access control.
3. **User Story 1**: Implement Registration and Staking logic.
4. **User Story 2**: Implement Discovery (pagination) and Manifest retrieval.
5. **User Story 3**: Implement DAO/Owner configuration updates.
6. **User Story 4**: Implement Unregistration and Withdrawals.
7. **Polish**: Final integration, Go adapters, and end-to-end simulation.

## Dependencies

```mermaid
graph TD
    Phase1[Phase 1: Setup] --> Phase2[Phase 2: Foundation]
    Phase2 --> US1[Phase 3: Registration (US1)]
    US1 --> US2[Phase 4: Discovery (US2)]
    US2 --> US3[Phase 5: Config Update (US3)]
    US2 --> US4[Phase 6: Withdrawal (US4)]
    US3 --> Polish[Phase 7: Polish]
    US4 --> Polish
```

## Phase 1: Setup (Project Initialization)

*Goal: Initialize the Solidity environment and shared interfaces.*

- [ ] T001 Initialize Solidity project structure (mappings, structs) in `contracts/evm/src/Registry.sol`
- [ ] T002 [P] Define Solidity interface in `contracts/evm/src/interfaces/IRegistry.sol` (Already scaffolded)
- [ ] T003 [P] Define Go interface in `pkg/ports/registry.go`
- [ ] T004 [P] Create initial Foundry test file `contracts/evm/test/Registry.t.sol`

## Phase 2: Foundational (Blocking Prerequisites)

*Goal: Establish storage layout, events, and access control.*

- [ ] T005 Implement `Registry` constructor with token address and stake amount in `contracts/evm/src/Registry.sol`
- [ ] T006 Implement storage variables (nodes mapping, activeNodes array, nodeIdUsed) in `contracts/evm/src/Registry.sol`
- [ ] T007 Implement events (NodeRegistered, NodeUpdated, etc.) in `contracts/evm/src/Registry.sol`
- [ ] T008 [P] Add setup/deploy helper in `contracts/evm/test/Registry.t.sol`

## Phase 3: Node Registration (User Story 1 - P1)

*Goal: Allow nodes to register by staking tokens.*

**Independent Test**: `forge test --match-test testRegister`

- [ ] T009 [US1] Implement `register` function with staking logic in `contracts/evm/src/Registry.sol`
- [ ] T010 [US1] Implement `updateNode` function for existing users in `contracts/evm/src/Registry.sol`
- [ ] T011 [US1] Implement unique Node ID check (revert if used) in `contracts/evm/src/Registry.sol`
- [ ] T012 [P] [US1] Create test `testRegister_Success` in `contracts/evm/test/Registry.t.sol`
- [ ] T013 [P] [US1] Create test `testRegister_RevertInsufficientStake` in `contracts/evm/test/Registry.t.sol`
- [ ] T014 [P] [US1] Create test `testRegister_RevertDuplicateId` in `contracts/evm/test/Registry.t.sol`
- [ ] T015 [P] [US1] Create test `testUpdateNode` in `contracts/evm/test/Registry.t.sol`

## Phase 4: Discovery & Startup (User Story 2 - P1)

*Goal: Enable nodes to fetch peer lists and network config.*

**Independent Test**: `forge test --match-test testDiscovery`

- [ ] T016 [US1] Implement `getActiveNodes` with pagination in `contracts/evm/src/Registry.sol`
- [ ] T017 [US2] Implement `getNode` and `getNodeByPublicKey` in `contracts/evm/src/Registry.sol`
- [ ] T018 [US2] Implement `getManifest` reader in `contracts/evm/src/Registry.sol`
- [ ] T019 [US2] Implement `totalActiveNodes` helper in `contracts/evm/src/Registry.sol`
- [ ] T020 [P] [US2] Create test `testPagination` in `contracts/evm/test/Registry.t.sol`
- [ ] T021 [P] [US2] Implement Go adapter `GetNodes` in `pkg/adapters/ethregistry/registry.go`
- [ ] T022 [P] [US2] Implement Go adapter `GetManifest` in `pkg/adapters/ethregistry/registry.go`

## Phase 5: Configuration Update (User Story 3 - P2)

*Goal: Allow DAO to update network parameters.*

**Independent Test**: `forge test --match-test testConfigUpdate`

- [ ] T023 [US3] Implement `updateNetworkConfig` with access control in `contracts/evm/src/Registry.sol`
- [ ] T024 [P] [US3] Create test `testUpdateConfig_OnlyOwner` in `contracts/evm/test/Registry.t.sol`
- [ ] T025 [P] [US3] Create test `testUpdateConfig_IncrementsVersion` in `contracts/evm/test/Registry.t.sol`

## Phase 6: Unregistration & Withdrawal (User Story 4 - P3)

*Goal: Allow safe exit with cooldown.*

**Independent Test**: `forge test --match-test testWithdrawal`

- [ ] T026 [US4] Implement `unregister` logic (starts cooldown, removes from active array) in `contracts/evm/src/Registry.sol`
- [ ] T027 [US4] Implement `withdrawStake` logic (checks cooldown) in `contracts/evm/src/Registry.sol`
- [ ] T028 [P] [US4] Create test `testUnregister_RemovesFromActive` in `contracts/evm/test/Registry.t.sol`
- [ ] T029 [P] [US4] Create test `testWithdraw_RevertDuringCooldown` in `contracts/evm/test/Registry.t.sol`
- [ ] T030 [P] [US4] Create test `testWithdraw_SuccessAfterCooldown` in `contracts/evm/test/Registry.t.sol`

## Phase 7: Polish & Cross-Cutting

*Goal: Finalize integration and verify scaling.*

- [ ] T031 Implement full Go adapter methods (Register, Unregister, etc.) in `pkg/adapters/ethregistry/registry.go`
- [ ] T032 Verify gas usage for `getActiveNodes` with 20 items in `contracts/evm/test/Registry.t.sol`
- [ ] T033 Update `cmd/demo/main.go` to use the new `ethregistry` adapter
- [ ] T034 Run full simulation with multiple mock nodes
