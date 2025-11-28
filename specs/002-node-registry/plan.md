# Implementation Plan: Node Registry

**Branch**: `002-node-registry` | **Date**: 2025-11-28 | **Spec**: [specs/002-node-registry/spec.md](./spec.md)
**Input**: Feature specification from `specs/002-node-registry/spec.md`

## Summary

The Node Registry is an Ethereum smart contract serving as the central directory for all clearnet nodes. It handles node registration (requiring a 250k YELLOW token stake), node discovery (with pagination/sequential indexing), and network configuration updates managed by a DAO (via an external governor). The system must scale to support 10k+ nodes and ensures unique node IDs.

## Technical Context

**Language/Version**: Solidity 0.8.20 (Contract), Go 1.22+ (Simulation/Node Integration), TypeScript (Tests/Scripts)
**Primary Dependencies**: OpenZeppelin Contracts (ERC20, Ownable/AccessControl), Foundry (Development/Testing)
**Storage**: On-chain EVM storage (Structs, Mappings, Arrays)
**Testing**: Foundry (`forge test`) for contract logic, Go simulation (`cmd/demo`) for integration.
**Target Platform**: Ethereum Mainnet (EVM compatible)
**Project Type**: Smart Contract + Node Integration
**Performance Goals**: Support 10k active nodes; O(1) read/write for registration/updates; Gas efficient pagination.
**Constraints**: Max 10k nodes; 7-day withdrawal cooldown; Immutable core logic (upgradability not specified, assumed immutable with config pointers).
**Scale/Scope**: 1 Smart Contract, ~300 LOC Solidity, Integration into existing Go node.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Spec-Driven Development**: ✅ Spec is written (`specs/002-node-registry/spec.md`).
- **II. Simulation-First Verification**: ✅ Plan includes Go simulation integration (`cmd/demo`).
- **III. Protocol Agnosticism**: ✅ Contract is an implementation detail; Go node will define an interface (`IRegistry`).
- **IV. Security & Custody Safety**: ✅ Staking logic requires rigorous testing (Foundry). Separation of duties (slashing vs unregister) adhered to.
- **V. Atomic Modularity**: ✅ Registry is a standalone component.

## Project Structure

### Documentation (this feature)

```text
specs/002-node-registry/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (Solidity interfaces/ABIs)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
contracts/evm/
├── src/
│   ├── Registry.sol         # The main registry contract
│   └── interfaces/
│       └── IRegistry.sol    # Solidity interface
└── test/
    └── Registry.t.sol       # Foundry tests

pkg/
├── ports/
│   └── registry.go          # Go Interface definition (IRegistry)
└── adapters/
    └── ethregistry/         # Ethereum adapter implementation
        └── registry.go      # Interacts with deployed contract
```

**Structure Decision**: Standard "Clean Architecture" as per Constitution (Ports & Adapters).