package main

import (
	"fmt"
	"math/big"
	"time"

	"github.com/mod/clearnet/pkg/adapters/mockchain"
	"github.com/mod/clearnet/pkg/adapters/mockp2p"
	"github.com/mod/clearnet/pkg/core"
	"github.com/mod/clearnet/pkg/node"
)

const (
	NumNodes = 10
	Quorum   = 3
)

func main() {
	fmt.Println("=== Clearnet Simulation ===")

	// 1. Setup Infrastructure
	chain := mockchain.NewVaultContract(2 * time.Second) // 2s challenge period for demo
	network := mockp2p.NewMockP2P()

	// 2. Bootstrap Nodes
	nodes := make([]*node.Node, NumNodes)
	for i := 0; i < NumNodes; i++ {
		id := fmt.Sprintf("node_%d", i)
		chain.AddNode(id)
		n := node.NewNode(id, chain, network)
		n.Start()
		nodes[i] = n
	}

	// Allow nodes to start
	time.Sleep(100 * time.Millisecond)

	// 3. Run Scenarios
	runHappyPath(chain, network)

	fmt.Println("\n--------------------------------------------------\n")

	runFraudPath(chain, network)

	// Keep main alive for events to process if needed
	time.Sleep(1 * time.Second)
}

func runHappyPath(chain *mockchain.VaultContract, network *mockp2p.MockP2P) {
	fmt.Println(">>> Starting HAPPY PATH <<<")
	wallet := "0xAlice_Happy"
	token := "0xUSDT"

	// 1. Deposit
	chain.Deposit(wallet, token, big.NewInt(100))

	// 2. Off-chain Logic (Client Side)
	// Alice wants to create State v1 (Balance 100)
	// Typically v1 is just matching deposit, or she transfers immediately.
	// Let's say she transfers 80 off-chain, so she owns 20.

	state := &core.State{
		Wallet:  wallet,
		Token:   token,
		Version: 2, // v1 was initial, v2 is current
		Balance: big.NewInt(20),
	}

	// Get Quorum and Sign
	// In reality client finds closest nodes.
	targetNodes := network.GetQuorumNodes(wallet, Quorum)
	state.Participants = targetNodes

	fmt.Printf("[Client] Collecting signatures from %v\n", targetNodes)
	for _, nid := range targetNodes {
		sig, err := network.RequestSignature(nid, state)
		if err != nil {
			panic(err)
		}
		state.Sigs = append(state.Sigs, sig)
	}

	// Publish to Network (So nodes persist it)
	network.PublishState(state)
	time.Sleep(500 * time.Millisecond) // Wait for propagation

	// 3. Withdrawal
	fmt.Println("[Client] Requesting Withdrawal for State v2...")
	err := chain.RequestWithdrawal(state)
	if err != nil {
		fmt.Printf("Withdraw request failed: %v\n", err)
		return
	}

	// 4. Wait Challenge Period
	fmt.Println("[Client] Waiting for challenge period...")
	time.Sleep(3 * time.Second)

	// 5. Finalize
	err = chain.Withdraw(wallet)
	if err != nil {
		fmt.Printf("Withdraw failed: %v\n", err)
	} else {
		fmt.Println("[Client] Withdraw Successful!")
	}
}

func runFraudPath(chain *mockchain.VaultContract, network *mockp2p.MockP2P) {
	fmt.Println(">>> Starting FRAUD PATH <<<")
	wallet := "0xBob_Fraud"
	token := "0xUSDT"

	// 1. Deposit
	chain.Deposit(wallet, token, big.NewInt(100))

	// 2. Off-chain Logic
	// Bob makes a legit transfer (v2), balance 50.
	realState := &core.State{
		Wallet:  wallet,
		Token:   token,
		Version: 2,
		Balance: big.NewInt(50),
	}

	targetNodes := network.GetQuorumNodes(wallet, Quorum)
	realState.Participants = targetNodes

	for _, nid := range targetNodes {
		sig, _ := network.RequestSignature(nid, realState)
		realState.Sigs = append(realState.Sigs, sig)
	}

	// Publish REAL state to network
	network.PublishState(realState)
	time.Sleep(500 * time.Millisecond)

	// 3. Fraudulent Withdrawal
	// Bob tries to withdraw using v1 (Balance 100) or a fake v1.
	// We'll construct a v1 state.
	fakeState := &core.State{
		Wallet:       wallet,
		Token:        token,
		Version:      1,
		Balance:      big.NewInt(100),
		Participants: targetNodes, // Doesn't verify on chain in mock, but strictly should have sigs
	}
	// (Skipping sig collection for fake state because MockChain doesn't verify sigs,
	// but the challenge logic relies on Nodes having v2)

	fmt.Println("[Client] 😈 Bob attempting fraudulent withdrawal with old State v1...")
	chain.RequestWithdrawal(fakeState)

	// 4. Wait for Challenge (Should happen immediately)
	time.Sleep(1 * time.Second)

	// 5. Try to Withdraw (Should fail)
	err := chain.Withdraw(wallet)
	if err == nil {
		fmt.Println("❌ ERROR: Fraudulent withdraw succeeded!")
	} else {
		fmt.Printf("✅ SUCCESS: Fraudulent withdraw blocked: %v\n", err)
	}
}
