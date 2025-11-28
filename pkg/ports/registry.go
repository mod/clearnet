package ports

import (
    "context"
    "math/big"
)

// Manifest represents the network configuration
type Manifest struct {
    Version  uint32
    URL      string
    Checksum [32]byte
}

// NodeInfo represents a discovered peer
type NodeInfo struct {
    Owner   string   // Hex address
    ID      [32]byte // Node ID Hash
    Address string   // "domain:port"
}

// Registry defines the interface for interacting with the Node Registry
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