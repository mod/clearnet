package ports

import (
	"github.com/mod/clearnet/pkg/core"
	"math/big"
)

// EventType defines the type of blockchain event
type EventType string

const (
	EventDeposited           EventType = "Deposited"
	EventWithdrawalRequested EventType = "WithdrawalRequested"
	EventChallenged          EventType = "Challenged"
	EventWithdrawn           EventType = "Withdrawn"
)

// BlockchainEvent generic event structure
type BlockchainEvent struct {
	Type    EventType
	Payload interface{} // Specific struct depending on Type
}

// Payload structs
type DepositPayload struct {
	Wallet string
	Token  string
	Amount *big.Int
}

type RequestPayload struct {
	State *core.State
}

type ChallengePayload struct {
	State      *core.State
	Challenger string
}

type WithdrawnPayload struct {
	Wallet string
	Amount *big.Int
}

// BlockchainAdapter defines interaction with the On-Chain world
type BlockchainAdapter interface {
	// Methods called by Users/Nodes
	Deposit(wallet, token string, amount *big.Int) error
	RequestWithdrawal(state *core.State) error
	Challenge(state *core.State, challengerID string) error
	Withdraw(wallet string) error

	// Event Subscription
	Subscribe() <-chan BlockchainEvent
}

// P2PAdapter defines interaction between nodes
type P2PAdapter interface {
	// Publish a new state to the network
	PublishState(state *core.State) error

	// Get the latest known state for a wallet
	GetLatestState(wallet string) (*core.State, error)

	// Request signature from a specific node (Simplified RPC)
	RequestSignature(nodeID string, state *core.State) ([]byte, error)

	// Register this node to the network
	RegisterNode(nodeID string, handler NodeHandler)
}

// NodeHandler defines callbacks for incoming P2P requests
type NodeHandler interface {
	OnSignRequest(state *core.State) ([]byte, error)
	OnNewState(state *core.State)
}
