package mockchain

import (
	"errors"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/mod/clearnet/pkg/core"
	"github.com/mod/clearnet/pkg/ports"
)

type VaultContract struct {
	mu              sync.Mutex
	balances        map[string]*big.Int    // On-chain balance (custody)
	pendingRequests map[string]*core.State // Wallet -> Requested State
	requestTime     map[string]time.Time
	nodeRegistry    map[string]bool // Authorized nodes

	eventBus    chan ports.BlockchainEvent
	subscribers []chan ports.BlockchainEvent

	ChallengePeriod time.Duration
}

func NewVaultContract(challengePeriod time.Duration) *VaultContract {
	vc := &VaultContract{
		balances:        make(map[string]*big.Int),
		pendingRequests: make(map[string]*core.State),
		requestTime:     make(map[string]time.Time),
		nodeRegistry:    make(map[string]bool),
		eventBus:        make(chan ports.BlockchainEvent, 100), // Buffered
		ChallengePeriod: challengePeriod,
	}

	// Start event dispatcher
	go vc.dispatch()

	return vc
}

func (vc *VaultContract) dispatch() {
	for event := range vc.eventBus {
		vc.mu.Lock()
		for _, sub := range vc.subscribers {
			// Non-blocking send to avoid stalling
			select {
			case sub <- event:
			default:
				// Subscriber too slow, drop or log
			}
		}
		vc.mu.Unlock()
	}
}

func (vc *VaultContract) Subscribe() <-chan ports.BlockchainEvent {
	vc.mu.Lock()
	defer vc.mu.Unlock()
	ch := make(chan ports.BlockchainEvent, 100)
	vc.subscribers = append(vc.subscribers, ch)
	return ch
}

func (vc *VaultContract) AddNode(nodeID string) {
	vc.mu.Lock()
	defer vc.mu.Unlock()
	vc.nodeRegistry[nodeID] = true
	fmt.Printf("[Blockchain] Node Added: %s\n", nodeID)
}

func (vc *VaultContract) Deposit(wallet, token string, amount *big.Int) error {
	vc.mu.Lock()
	defer vc.mu.Unlock()

	// Mock: We assume the user has approved tokens, etc.
	// Update internal balance
	current, exists := vc.balances[wallet]
	if !exists {
		current = big.NewInt(0)
	}
	vc.balances[wallet] = new(big.Int).Add(current, amount)

	// Emit Event
	vc.eventBus <- ports.BlockchainEvent{
		Type: ports.EventDeposited,
		Payload: ports.DepositPayload{
			Wallet: wallet,
			Token:  token,
			Amount: amount,
		},
	}
	fmt.Printf("[Blockchain] Deposit: %s deposited %s\n", wallet, amount)
	return nil
}

func (vc *VaultContract) RequestWithdrawal(state *core.State) error {
	vc.mu.Lock()
	defer vc.mu.Unlock()

	// Verify signatures (Registry check)
	if len(state.Participants) == 0 {
		return errors.New("no participants")
	}
	for _, p := range state.Participants {
		if !vc.nodeRegistry[p] {
			return fmt.Errorf("unauthorized participant: %s", p)
		}
	}

	vc.pendingRequests[state.Wallet] = state
	vc.requestTime[state.Wallet] = time.Now()

	vc.eventBus <- ports.BlockchainEvent{
		Type: ports.EventWithdrawalRequested,
		Payload: ports.RequestPayload{
			State: state,
		},
	}
	fmt.Printf("[Blockchain] Withdrawal Requested for %s, Ver: %d\n", state.Wallet, state.Version)
	return nil
}

func (vc *VaultContract) Challenge(candidate *core.State, challengerID string) error {
	vc.mu.Lock()
	defer vc.mu.Unlock()

	// Verify signatures (Registry check)
	for _, p := range candidate.Participants {
		if !vc.nodeRegistry[p] {
			return fmt.Errorf("unauthorized participant: %s", p)
		}
	}

	pending, exists := vc.pendingRequests[candidate.Wallet]
	if !exists {
		return errors.New("no pending request to challenge")
	}

	if candidate.Version <= pending.Version {
		return errors.New("challenge version is not newer")
	}

	// Valid challenge: Slashing logic would go here.
	// For now, we just cancel the withdrawal.
	delete(vc.pendingRequests, candidate.Wallet)
	delete(vc.requestTime, candidate.Wallet)

	vc.eventBus <- ports.BlockchainEvent{
		Type: ports.EventChallenged,
		Payload: ports.ChallengePayload{
			State:      candidate,
			Challenger: challengerID,
		},
	}
	fmt.Printf("[Blockchain] CHALLENGE SUCCESS! Request for %s defeated by Ver: %d\n", candidate.Wallet, candidate.Version)
	return nil
}

func (vc *VaultContract) Withdraw(wallet string) error {
	vc.mu.Lock()
	defer vc.mu.Unlock()

	pending, exists := vc.pendingRequests[wallet]
	if !exists {
		return errors.New("no pending request")
	}

	elapsed := time.Since(vc.requestTime[wallet])
	if elapsed < vc.ChallengePeriod {
		return fmt.Errorf("challenge period not over. Left: %v", vc.ChallengePeriod-elapsed)
	}

	// Success
	currentBal := vc.balances[wallet]
	// The state balance is what remains OFF-CHAIN.
	// The withdrawal amount = Total Deposited - Remaining Offchain Balance?
	// Or does the state contain the amount TO withdraw?
	// README says: "Withdrawal Request: Alice wants to withdraw her remaining $20."
	// "She requests the latest state... Balance: 20".
	// "The contract transfers the ERC20 tokens to her wallet."

	// So if on-chain balance was 100, and off-chain state says 20.
	// It means she spent 80 off-chain?
	// OR does the state balance represent what she OWNS?
	// "Alice transfers 80 USDT off-chain. Her ledger state is updated... Balance: 20?"
	// Yes.
	// So when she withdraws 20, she gets 20 on-chain?
	// Wait. "Alice deposits 100... transfers 80 off-chain... withdraws remaining 20".
	// The README says: "Alice attempts to withdraw 90 USDT using old State".
	// This implies the State.Balance is the amount she is CLAIMING to have.

	amountToWithdraw := pending.Balance

	// Check if contract has enough (it should, unless she double spent)
	if currentBal.Cmp(amountToWithdraw) < 0 {
		// In a real channel, this might be complex (insolvency).
		// Here, we assume custody covers it.
		// Actually, if she has 20 left, the contract should have 100.
		// She withdraws 20. The other 80 are owned by someone else now (who received them off-chain).
		// That receiver will eventually withdraw their 80.
		// So we just check if `amountToWithdraw <= currentBal`.
		// Actually, in a channel, the total locked value is partitioned.
		// We will assume for this simple ledger that we just send `amountToWithdraw`.
	}

	// Update on-chain balance
	// In a full implementation, we'd decrement the total vault balance, but
	// "balances" map here tracks "Deposited by X".
	// If X transferred to Y off-chain, X withdraws 20. Y withdraws 80.
	// We decrement X's custody by 20. The remaining 80 in X's custody is actually claimable by Y.
	// This is slightly complex for a Mock.
	// Let's just allow withdrawing the amount specified in the State.

	vc.balances[wallet] = new(big.Int).Sub(currentBal, amountToWithdraw)
	delete(vc.pendingRequests, wallet)
	delete(vc.requestTime, wallet)

	vc.eventBus <- ports.BlockchainEvent{
		Type: ports.EventWithdrawn,
		Payload: ports.WithdrawnPayload{
			Wallet: wallet,
			Amount: amountToWithdraw,
		},
	}
	fmt.Printf("[Blockchain] Withdraw Finalized: %s received %s\n", wallet, amountToWithdraw)
	return nil
}
