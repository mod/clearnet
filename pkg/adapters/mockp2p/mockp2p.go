package mockp2p

import (
	"errors"
	"fmt"
	"hash/crc32"
	"sort"
	"sync"
	"time"

	"github.com/mod/clearnet/pkg/core"
	"github.com/mod/clearnet/pkg/ports"
)

type MockP2P struct {
	mu      sync.RWMutex
	nodes   map[string]ports.NodeHandler
	nodeIDs []string // Sorted list for hashing
}

func NewMockP2P() *MockP2P {
	return &MockP2P{
		nodes: make(map[string]ports.NodeHandler),
	}
}

func (p *MockP2P) RegisterNode(nodeID string, handler ports.NodeHandler) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.nodes[nodeID] = handler
	p.nodeIDs = append(p.nodeIDs, nodeID)
	sort.Strings(p.nodeIDs)
}

// GetQuorumNodes finds the k closest nodes to the wallet address
func (p *MockP2P) GetQuorumNodes(wallet string, k int) []string {
	p.mu.RLock()
	defer p.mu.RUnlock()

	if len(p.nodeIDs) == 0 {
		return nil
	}

	// Simple hashing: hash(wallet) % N
	hash := crc32.ChecksumIEEE([]byte(wallet))
	idx := int(hash) % len(p.nodeIDs)

	quorum := make([]string, 0, k)
	for i := 0; i < k; i++ {
		// Ring wrap around
		targetIdx := (idx + i) % len(p.nodeIDs)
		quorum = append(quorum, p.nodeIDs[targetIdx])
	}
	return quorum
}

func (p *MockP2P) PublishState(state *core.State) error {
	// In Kademlia, we find the closest nodes and store it there.
	// We use Quorum of 3.
	nodes := p.GetQuorumNodes(state.Wallet, 3)

	// Send asynchronously to simulate network
	for _, nodeID := range nodes {
		go func(nid string) {
			// Simulate latency
			time.Sleep(10 * time.Millisecond)

			p.mu.RLock()
			handler, ok := p.nodes[nid]
			p.mu.RUnlock()

			if ok {
				handler.OnNewState(state)
			}
		}(nodeID)
	}

	fmt.Printf("[P2P] Published state v%d for %s to nodes %v\n", state.Version, state.Wallet, nodes)
	return nil
}

func (p *MockP2P) GetLatestState(wallet string) (*core.State, error) {
	// In reality, we query the DHT.
	// Here, we'll cheat a bit and ask the quorum nodes, returning the highest version.
	// BUT, the interface `GetLatestState` is called BY A NODE (usually).
	// If a client calls it, they are external.
	// Let's assume this is a Client-side library function or Node function.

	// nodes := p.GetQuorumNodes(wallet, 3)
	// var latest *core.State

	// We need to ask the handlers?
	// The `NodeHandler` interface I defined doesn't have `GetState`.
	// I should probably add it or relying on the local storage of the calling node.
	// But `GetLatestState` is on the P2P adapter...
	// Let's implement a simple query simulation.
	// We will assume the P2P adapter can "RPC" into the nodes.

	// NOTE: For this mock, since I didn't add GetState to NodeHandler,
	// I'll skip querying others and assume the caller (Node) relies on its own peer store,
	// or I'll add `GetState` to NodeHandler now.
	return nil, errors.New("not implemented in mock")
}
func (p *MockP2P) RequestSignature(nodeID string, state *core.State) ([]byte, error) {
	p.mu.RLock()
	handler, ok := p.nodes[nodeID]
	p.mu.RUnlock()

	if !ok {
		return nil, errors.New("node not found")
	}

	return handler.OnSignRequest(state)
}
