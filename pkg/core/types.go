package core

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/big"
	"strings"
)

// State represents the snapshot of a ledger entry
type State struct {
	Wallet       string   // Address of the user
	Token        string   // Token Address
	Version      uint64   // Incremental version
	Balance      *big.Int // Balance
	Participants []string // List of Node IDs (Quorum)
	Sigs         [][]byte // Signatures
}

// Hash calculates the unique identifier for this state
// imitating: keccak256(abi.encode(wallet, token, version, balance, participants));
func (s *State) Hash() string {
	// Sort participants to ensure consistent hashing
	// (Assuming the contract requires sorted or specific order, strictly we should preserve order if the contract does,
	// but usually for deterministic hashing sets are sorted).
	// For this simulation, we assume 'Participants' is already the correct ordered list.

	raw := fmt.Sprintf("%s:%s:%d:%s:%s",
		s.Wallet,
		s.Token,
		s.Version,
		s.Balance.String(),
		strings.Join(s.Participants, ","),
	)

	hasher := sha256.New()
	hasher.Write([]byte(raw))
	return hex.EncodeToString(hasher.Sum(nil))
}

// Clone creates a deep copy of the state
func (s *State) Clone() *State {
	newBal := new(big.Int).Set(s.Balance)
	newParts := make([]string, len(s.Participants))
	copy(newParts, s.Participants)
	newSigs := make([][]byte, len(s.Sigs))
	for i, sig := range s.Sigs {
		newSig := make([]byte, len(sig))
		copy(newSig, sig)
		newSigs[i] = newSig
	}

	return &State{
		Wallet:       s.Wallet,
		Token:        s.Token,
		Version:      s.Version,
		Balance:      newBal,
		Participants: newParts,
		Sigs:         newSigs,
	}
}
