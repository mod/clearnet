# clearnet Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-28

## Active Technologies

- **Smart Contracts**: Solidity 0.8.20, Foundry (Forge), OpenZeppelin Contracts (ERC20, Ownable, AccessControl).
- **Backend/Node**: Go 1.22+, Standard Library.
- **Simulation**: In-memory Go simulation (`cmd/demo`).

## Project Structure

```text
cmd/
└── demo/            # Protocol simulation and integration tests
contracts/
└── evm/             # Solidity smart contracts (Vault, Registry)
    ├── src/
    └── test/
pkg/                 # Go packages
├── adapters/        # Interface implementations (MockRegistry, etc.)
├── core/            # Core domain logic
└── ports/           # Interface definitions
specs/               # Feature specifications
```

## Commands

### Simulation (Go)

```bash
# Run simulation
go run cmd/demo/main.go
```

### Smart Contracts (Foundry)

```bash
# Run all tests
cd contracts/evm && forge test -vv

# Test specific contracts
forge test --match-contract RegistryTest
forge test --match-contract VaultTest
```

## Code Style

- **Solidity**: Standard Foundry/Solidity conventions.
- **Go**: Standard Go conventions.

## Recent Changes

- **002-node-registry**: Implemented `Registry.sol` for node discovery and staking (250k YELLOW tokens). Added `mockregistry` adapter in Go.
- **001-protocol-logic**: Implemented `Vault.sol` for custody, requests, and fraud proofs. Added core `State` and `Request` types.

