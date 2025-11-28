# Quickstart: Node Registry Feature

## Overview

The Node Registry is the on-chain "phonebook" for Clearnet. It allows nodes to discover peers and fetch network configuration.

- **Contract**: `contracts/evm/src/Registry.sol`
- **Go Interface**: `pkg/ports/registry.go`
- **Staking**: 250,000 YELLOW tokens required.

## Key Concepts

1. **Registration**: Staking tokens to list your node.
   - **Input**: Node ID (bytes32 hash), Domain, Port.
   - **Cost**: 250k YELLOW tokens (transferFrom).
2. **Discovery**: Fetching active nodes.
   - **Method**: `getActiveNodes(offset, limit)`
   - **Note**: Order is UNSTABLE (Swap-and-Pop).
3. **Manifest**: Network configuration.
   - **Update**: Only via DAO/Owner.
   - **Format**: URL + Checksum (SHA-256).

## Development

### Prerequisites
- Foundry (`forge`)
- Go 1.22+

### Running Tests (Contract)
```bash
cd contracts/evm
forge test --match-path test/Registry.t.sol
```

### Running Simulation (Mock Mode)
The simulation currently uses an in-memory Mock Registry.

```bash
go run cmd/demo/main.go
```

## Integration Guide (for Node Operators)

To interact with the registry in Go:

```go
import "clearnet/pkg/ports"

// 1. Define ID
var nodeID [32]byte = ... // Hash of your key

// 2. Register
err := registry.Register(ctx, nodeID, "my-node.com", 9000, big.NewInt(250000))
```
