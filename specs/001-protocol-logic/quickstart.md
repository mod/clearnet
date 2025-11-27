# Quickstart: Protocol Logic & Smart Contracts

**Feature**: Protocol Logic & Smart Contracts
**Date**: 2025-11-27

## Simulation (Go)

The `cmd/demo` tool simulates the protocol lifecycle.

```bash
# Run the happy path simulation
go run cmd/demo/main.go --scenario happy-path

# Run the fraud challenge simulation
go run cmd/demo/main.go --scenario fraud-challenge
```

## Smart Contracts (Foundry)

### Setup

```bash
cd contracts/evm
forge install
```

### Running Tests

```bash
# Run all vault tests
forge test --match-contract VaultTest -vv

# Test specific flows
forge test --match-test test_Deposit -vv
forge test --match-test test_RequestWithdrawal -vv
forge test --match-test test_ChallengeFraud -vv
```

### Contract Deployment

```bash
# Deploy to local anvil chain
forge create src/Vault.sol:Vault --constructor-args 3 600 --private-key $PRIVATE_KEY
```

## Key Configuration

*   **`minQuorum`**: Minimum signatures required (default: 3).
*   **`challengePeriod`**: Time window for challenges (default: 600s).
