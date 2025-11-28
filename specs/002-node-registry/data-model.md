# Data Model: Node Registry

## Smart Contract Entities (Solidity)

### `NodeRecord`
Stored in a mapping `mapping(address => NodeRecord) public nodes`.

| Field | Type | Description |
|-------|------|-------------|
| `nodeId` | `bytes` | Public Key (variable length or fixed 32/64 bytes depending on crypto, assume generic `bytes` or `bytes32` if Ed25519/Secp256k1 compressed. Spec says "Public Key", usually 32 bytes for Ed25519). |
| `domain` | `string` | DNS domain or IP address. |
| `port` | `uint16` | TCP/UDP port. |
| `registrationTime` | `uint64` | Timestamp of registration. |
| `stakedAmount` | `uint256` | Amount of tokens staked (typically 250,000 * 10^18). |
| `cooldownEnd` | `uint64` | Timestamp when withdrawal is allowed (0 if active). |
| `index` | `uint256` | Index in the `activeNodes` array (for O(1) removal). |

### `NetworkManifest`
Singleton struct/variables.

| Field | Type | Description |
|-------|------|-------------|
| `protocolVersion` | `uint32` | Monotonically increasing version number. |
| `ipfsHash` | `string` | IPFS CID (string) or bytes. |
| `checksum` | `bytes32` | Checksum of the manifest file. |

### Global State

| Variable | Type | Description |
|----------|------|-------------|
| `yellowToken` | `IERC20` | The staking token contract. |
| `stakeAmount` | `uint256` | Required stake (250,000 * 10^18). |
| `cooldownPeriod` | `uint256` | Unbonding period (7 days). |
| `activeNodes` | `address[]` | List of addresses of currently active nodes. |
| `nodeIdUsed` | `mapping(bytes => bool)` | Uniqueness check for Node IDs. |

---

## Go Entities (Domain Layer)

### `NodeInfo`
Represents a discovered peer.

```go
type NodeInfo struct {
    ID      []byte // Public Key
    Address string // "domain:port"
}
```

### `Manifest`
Represents the network configuration.

```go
type Manifest struct {
    Version  uint32
    IPFSHash string
    Checksum [32]byte
}
```

---

## Interfaces

### Solidity Interface (`IRegistry.sol`)

```solidity
interface IRegistry {
    // Write
    function register(bytes calldata nodeId, string calldata domain, uint16 port) external;
    function updateNode(string calldata domain, uint16 port) external;
    function unregister() external;
    function withdrawStake() external;
    
    // Admin
    function updateNetworkConfig(uint32 version, string calldata ipfsHash, bytes32 checksum) external;

    // Read
    function getNode(address operator) external view returns (NodeRecord memory);
    function getNodeByPublicKey(bytes calldata nodeId) external view returns (NodeRecord memory); // Might need separate mapping or iterate if not optimized
    function getActiveNodes(uint256 offset, uint256 limit) external view returns (NodeRecord[] memory);
    function getManifest() external view returns (uint32, string memory, bytes32);
    function totalActiveNodes() external view returns (uint256);
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
    Register(ctx context.Context, nodeID []byte, domain string, port uint16, stake *big.Int) error
    UpdateNode(ctx context.Context, domain string, port uint16) error
    Unregister(ctx context.Context) error
    Withdraw(ctx context.Context) error
}
```
