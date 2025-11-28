# Quickstart: Node Registry

## Prerequisites

- Foundry installed (`forge`)
- Go 1.22+ installed
- Ethereum RPC URL (or use Anvil for local dev)
- Private Key with ETH for gas and YELLOW tokens for staking

## Deploying the Registry (Local)

1. Start Anvil:
   ```bash
   anvil
   ```

2. Deploy Mock Token and Registry:
   ```bash
   cd contracts/evm
   forge script script/DeployRegistry.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
   ```

## Registering a Node

1. Approve Tokens:
   ```bash
   cast send <TOKEN_ADDR> "approve(address,uint256)" <REGISTRY_ADDR> 250000000000000000000000 --private-key <KEY>
   ```

2. Register:
   ```bash
   cast send <REGISTRY_ADDR> "register(bytes,string,uint16)" 0x1234... "node.example.com" 9000 --private-key <KEY>
   ```

## Running the Simulation

The Go simulation allows you to spin up a mock p2p network and verify registry interactions.

```bash
cd cmd/demo
go run main.go --registry <REGISTRY_ADDR> --role node
```
