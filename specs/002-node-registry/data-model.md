# Data Model: Node Registry

## Smart Contract Entities (Solidity)

### `NodeRecord`
Stored in a mapping `mapping(address => NodeRecord) public nodes`.

| Field | Type | Description |
|-------|------|-------------|
| `index` | `uint256` | Internal index in the activeNodes array (for O(1) removal). |
| `nodeId` | `bytes32` | Composite Hash: `keccak256(abi.encode("network_name", chainId, nodeAddress))`. |
| `operator` | `address` | The Ethereum address of the node operator. |
| `domain` | `string` | DNS domain or IP address. |
| `port` | `uint16` | TCP/UDP port. |
| `amount` | `uint256` | Amount of tokens staked. |
| `registredAt` | `uint64` | Timestamp of registration. |
| `unlockAt` | `uint64` | Timestamp when withdrawal is allowed (0 if active). |

### `NetworkManifest`
Singleton struct/variables.

| Field | Type | Description |
|-------|------|-------------|
| `version` | `uint32` | Monotonically increasing version number. |
| `url` | `string` | Fully qualified URL (e.g., `https://...` or `ipfs://...`). |
| `checksum` | `bytes32` | SHA-256 Checksum of the manifest file. |

### Global State

| Variable | Type | Description |
|----------|------|-------------|
| `yellowToken` | `IERC20` | The staking token contract. |
| `stakeAmount` | `uint256` | Required stake (250,000 * 10^18). |
| `cooldownPeriod` | `uint256` | Unbonding period (7 days). |
| `activeNodes` | `address[]` | List of addresses of currently active nodes. Uses **Swap-and-Pop** strategy for O(1) removals (order is unstable). |
| `nodeIdUsed` | `mapping(bytes32 => bool)` | Uniqueness check for Node IDs. |

---

## Go Entities (Domain Layer)

### `NodeInfo`
Represents a discovered peer.

```go
type NodeInfo struct {
    ID      [32]byte // Node ID Hash
    Address string   // "domain:port"
}
```

### `Manifest`
Represents the network configuration.

```go
type Manifest struct {
    Version  uint32
    URL      string
    Checksum [32]byte
}
```

---

## Interfaces

### Solidity Interface (`IRegistry.sol`)

```solidity
interface IRegistry {
    // Write
    function register(bytes32 nodeId, string calldata domain, uint16 port) external;
    function unregister() external;
    function updateNode(string calldata domain, uint16 port) external;
    function withdraw() external;
    
    // Admin
    function updateVersion(uint32 version, string calldata url, bytes32 checksum) external;

    // Read
    function getNodeById(bytes32 nodeId) external view returns (NodeRecord memory);
    function getActiveNodes(uint256 offset, uint256 limit) external view returns (NodeRecord[] memory);
    function totalActiveNodes() external view returns (uint256);
    function getVersion() external view returns (uint32 version, string memory url, bytes32 checksum);
}
```

### Go Interface (`pkg/ports/registry.go`)

```go
package ports

import (
    "context"
    "math/big"
)

type Registry interface {
    // Reads
    GetManifest(ctx context.Context) (*Manifest, error)
    GetNodes(ctx context.Context, offset, limit uint64) ([]NodeInfo, error)
    
    // Writes (Node Operator)
    Register(ctx context.Context, nodeID [32]byte, domain string, port uint16, stake *big.Int) error
    UpdateNode(ctx context.Context, domain string, port uint16) error
    Unregister(ctx context.Context) error
    Withdraw(ctx context.Context) error
}
```
