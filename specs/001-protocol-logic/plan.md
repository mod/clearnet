# Implementation Plan: Protocol Logic & Smart Contracts

**Branch**: `001-protocol-logic` | **Date**: 2025-11-27 | **Spec**: [specs/001-protocol-logic/spec.md](spec.md)
**Input**: Feature specification from `/specs/001-protocol-logic/spec.md`

## Summary

Implement the core blockchain protocol logic for Clearnet, enabling secure deposits, withdrawals, and fraud challenges. This involves defining the data structures (`State`), implementing the `Vault` smart contract (EVM), and verifying the logic via simulation (`cmd/demo`).

## Technical Context

**Language/Version**: Solidity 0.8.20 (EVM), Go 1.22+ (Simulation/Node)
**Primary Dependencies**: Foundry (Forge) for EVM, Standard Go Library
**Storage**: On-chain (EVM Storage), In-memory (Simulation)
**Testing**: Foundry (`forge test`), Go Tests (`go test ./...`)
**Target Platform**: Ethereum/L2s (EVM), Local Simulation
**Project Type**: Smart Contracts + CLI Simulation
**Performance Goals**: `challenge` gas cost < 500k
**Constraints**: 
- `CHALLENGE_PERIOD` = 10 minutes (MVP)
- Quorum = System-wide config (MVP)
- Revert on failed transfers (No pull pattern yet)
**Scale/Scope**: Core protocol logic, no UI/Frontend yet.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

*   **I. Spec-Driven Development**: ✅ Spec created at `specs/001-protocol-logic/spec.md`.
*   **II. Simulation-First Verification**: ✅ Plan includes updating `cmd/demo` to verify protocol logic.
*   **III. Protocol Agnosticism**: ✅ Core logic defined abstractly; EVM implementation is an adapter.
*   **IV. Security & Custody Safety**: ✅ Challenge mechanism is the primary security focus. Revert-on-fail used for safety.
*   **V. Atomic Modularity**: ✅ Contracts are self-contained.

## Project Structure

### Documentation (this feature)

```text
specs/001-protocol-logic/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
contracts/evm/
├── src/
│   ├── Vault.sol        # Main contract implementation
│   ├── interfaces/
│   │   ├── IDeposit.sol # (Existing)
│   │   └── IWithdraw.sol # (Existing)
│   └── libraries/
│       └── StateUtils.sol # Helper for hashing/verification
└── test/
    └── Vault.t.sol      # Foundry tests

cmd/demo/
└── main.go              # Simulation update
```

**Structure Decision**: Standard Foundry layout for EVM contracts; `cmd/demo` for simulation.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |