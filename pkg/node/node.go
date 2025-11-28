package node

import (
	"context"
	"crypto/sha256"
	"fmt"
	"math/big"
	"sync"

	"github.com/mod/clearnet/pkg/core"
	"github.com/mod/clearnet/pkg/ports"
)

type Node struct {
	ID    string
	store map[string]*core.State // Wallet -> State
	mu    sync.RWMutex

	chain    ports.BlockchainAdapter
	p2p      ports.P2PAdapter
	registry ports.Registry
}

func NewNode(id string, chain ports.BlockchainAdapter, p2p ports.P2PAdapter, registry ports.Registry) *Node {
	n := &Node{
		ID:       id,
		store:    make(map[string]*core.State),
		chain:    chain,
		p2p:      p2p,
		registry: registry,
	}
	return n
}

func (n *Node) Start() {
	// Register with P2P
	n.p2p.RegisterNode(n.ID, n)

	// Subscribe to Blockchain events
	events := n.chain.Subscribe()
	go n.handleBlockchainEvents(events)

	// Register with Node Registry
	// Generate a mock [32]byte ID from string ID
	var nodeID [32]byte
	hash := sha256.Sum256([]byte(n.ID))
	copy(nodeID[:], hash[:])

	// Mock stake
	stake := big.NewInt(250000)
	
	err := n.registry.Register(context.Background(), nodeID, "localhost", 9000, stake)
	if err != nil {
		fmt.Printf("[Node %s] Failed to register: %v\n", n.ID, err)
	}

	fmt.Printf("[Node %s] Started\n", n.ID)
}

func (n *Node) handleBlockchainEvents(events <-chan ports.BlockchainEvent) {
	for evt := range events {
		switch evt.Type {
		case ports.EventDeposited:
			payload := evt.Payload.(ports.DepositPayload)
			n.handleDeposit(payload)
		case ports.EventWithdrawalRequested:
			payload := evt.Payload.(ports.RequestPayload)
			n.handleWithdrawalRequest(payload)
		case ports.EventChallenged:
			// Log or update status
		case ports.EventWithdrawn:
			// Update local balance to 0? Or just log.
		}
	}
}

func (n *Node) handleDeposit(p ports.DepositPayload) {
	// In a real system, we might create the initial state v0 here.
	n.mu.Lock()
	defer n.mu.Unlock()

	// Create or update initial state
	// If state doesn't exist, create version 1 (or 0)
	_, exists := n.store[p.Wallet]
	if !exists {
		// Version 0 usually implies empty or just deposited.
		// Let's assume the Client creates the first State v1 after deposit.
		// But the node should know the on-chain balance to validate the first off-chain transition.
		// For simplicity, we just log.
	}
}

func (n *Node) handleWithdrawalRequest(p ports.RequestPayload) {
	reqState := p.State

	n.mu.RLock()
	localState, exists := n.store[reqState.Wallet]
	n.mu.RUnlock()

	if !exists {
		// We don't have data for this wallet, ignore.
		return
	}

	fmt.Printf("[Node %s] Checking withdrawal request for %s. ReqVer: %d, LocalVer: %d\n",
		n.ID, reqState.Wallet, reqState.Version, localState.Version)

	if localState.Version > reqState.Version {
		// FRAUD DETECTED!
		fmt.Printf("[Node %s] 🚨 FRAUD DETECTED! Challenging...\n", n.ID)
		err := n.chain.Challenge(localState, n.ID)
		if err != nil {
			fmt.Printf("[Node %s] Challenge failed: %v\n", n.ID, err)
		}
	}
}

// --- NodeHandler Interface ---

func (n *Node) OnNewState(state *core.State) {
	n.mu.Lock()
	defer n.mu.Unlock()

	current, exists := n.store[state.Wallet]
	if exists && current.Version >= state.Version {
		// Old or same state, ignore
		return
	}

	// In reality: Verify signatures of Quorum.
	// We assume if it reached us via P2P and looks valid, we store it.
	n.store[state.Wallet] = state
	fmt.Printf("[Node %s] Updated local state for %s to Ver: %d Balance: %s\n", n.ID, state.Wallet, state.Version, state.Balance)
}

func (n *Node) OnSignRequest(state *core.State) ([]byte, error) {
	// In reality: Validate transition (Balance check, etc)
	// For this mock: We just sign it.

	sig := []byte(fmt.Sprintf("sig:%s:%s", n.ID, state.Hash()))
	return sig, nil
}
