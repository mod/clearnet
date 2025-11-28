package mockregistry

import (
	"context"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"sync"

	"github.com/mod/clearnet/pkg/ports"
)

// MockRegistry implements ports.Registry for testing/simulation
type MockRegistry struct {
	mu          sync.RWMutex
	nodes       map[string]ports.NodeInfo
	activeNodes []string // List of Node IDs (hex string) for pagination
	manifest    ports.Manifest
}

func New() *MockRegistry {
	return &MockRegistry{
		nodes:       make(map[string]ports.NodeInfo),
		activeNodes: make([]string, 0),
		manifest: ports.Manifest{
			Version:  1,
			URL:      "https://example.com/manifest.yaml",
			Checksum: [32]byte{},
		},
	}
}

func (m *MockRegistry) GetManifest(ctx context.Context) (*ports.Manifest, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return &m.manifest, nil
}

func (m *MockRegistry) GetNodes(ctx context.Context, offset, limit uint64) ([]ports.NodeInfo, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	total := uint64(len(m.activeNodes))
	if offset >= total {
		return []ports.NodeInfo{}, nil
	}

	end := offset + limit
	if end > total {
		end = total
	}

	result := make([]ports.NodeInfo, 0, end-offset)
	for i := offset; i < end; i++ {
		nodeID := m.activeNodes[i]
		if node, exists := m.nodes[nodeID]; exists {
			result = append(result, node)
		}
	}

	return result, nil
}

func (m *MockRegistry) Register(ctx context.Context, nodeID [32]byte, domain string, port uint16, stake *big.Int) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	idStr := hex.EncodeToString(nodeID[:])
	if _, exists := m.nodes[idStr]; exists {
		return errors.New("node already registered")
	}

	// Mock Staking check
	if stake.Cmp(big.NewInt(250000)) < 0 {
		return errors.New("insufficient stake")
	}

	newNode := ports.NodeInfo{
		Owner:   "0xMockOwner",
		ID:      nodeID,
		Address: fmt.Sprintf("%s:%d", domain, port),
	}
	
	m.nodes[idStr] = newNode
	m.activeNodes = append(m.activeNodes, idStr)

	return nil
}

func (m *MockRegistry) UpdateNode(ctx context.Context, domain string, port uint16) error {
	// Not implemented for mock yet, or simple no-op
	return nil
}

func (m *MockRegistry) Unregister(ctx context.Context) error {
	// In a real adapter, this would use the caller's key/address.
	// In this mock, we don't have authentication context easily unless passed.
	// For simulation simplicity, we might need to pass the ID or assume a single node context.
	// But the interface follows the contract which implies msg.sender.
	// Since we can't easily determine "who" is calling in this mock without changing the interface,
	// we will leave this as a no-op or require extending the interface/context values.
	// However, for the purpose of the demo (US2 - Discovery), Unregister isn't critical.
	// I'll leave it as no-op.
	return nil
}

func (m *MockRegistry) Withdraw(ctx context.Context) error {
	return nil
}
