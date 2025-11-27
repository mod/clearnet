package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"math/rand"
	"sort"
	"sync"
	"time"
)

// --- Constants ---
const (
	IDLength = 20 // SHA1 produces 20 bytes
	K        = 3  // Bucket size (kept small for this 10-node demo)
	Alpha    = 3  // Concurrency parameter
)

// --- Type Definitions ---

type ID [IDLength]byte

// Node represents a participant in the network
type Node struct {
	ID    ID
	Addr  string        // In a real app, this would be "IP:Port"
	Store map[ID][]byte // Local Key-Value store
	Table *RoutingTable
	// Network simulation
	Network *Network
	mu      sync.RWMutex
}

// Network simulates the "Internet" allowing nodes to find each other by address
type Network struct {
	Nodes map[string]*Node
	mu    sync.RWMutex
}

// RoutingTable holds K-Buckets
type RoutingTable struct {
	Self    ID
	Buckets [IDLength * 8][]*Node // 160 buckets
	mu      sync.RWMutex
}

// --- Helper Functions ---

// NewID creates a random ID
func NewID() ID {
	var id ID
	rand.Read(id[:])
	return id
}

// HashKey hashes a string key to an ID
func HashKey(key string) ID {
	hash := sha1.Sum([]byte(key))
	return ID(hash)
}

// Xor calculates distance between two IDs
func Xor(a, b ID) ID {
	var res ID
	for i := 0; i < IDLength; i++ {
		res[i] = a[i] ^ b[i]
	}
	return res
}

// PrefixLen finds the bucket index (number of leading zero bits in XOR distance)
func PrefixLen(id1, id2 ID) int {
	dist := Xor(id1, id2)
	for i := 0; i < IDLength; i++ {
		for j := 0; j < 8; j++ {
			if (dist[i]>>uint8(7-j))&0x1 != 0 {
				return i*8 + j
			}
		}
	}
	return IDLength*8 - 1
}

// String representation for logging
func (id ID) String() string {
	return hex.EncodeToString(id[:])[0:6] // Shorten for readability
}

// --- Routing Table Implementation ---

func NewRoutingTable(self ID) *RoutingTable {
	return &RoutingTable{
		Self:    self,
		Buckets: [IDLength * 8][]*Node{},
	}
}

// Update adds a node to the routing table (simplification of K-Bucket logic)
func (rt *RoutingTable) Update(n *Node) {
	if n.ID == rt.Self {
		return
	}
	bucketIdx := PrefixLen(rt.Self, n.ID)

	rt.mu.Lock()
	defer rt.mu.Unlock()

	bucket := rt.Buckets[bucketIdx]

	// Check if already exists
	for _, peer := range bucket {
		if peer.ID == n.ID {
			return // Already known, in real Kad we would move to tail
		}
	}

	// Add if bucket not full
	if len(bucket) < K {
		rt.Buckets[bucketIdx] = append(bucket, n)
	} else {
		// In real Kad, we would ping the head, drop if dead, etc.
		// Here we just ignore to keep it simple.
	}
}

// FindClosest returns K closest nodes to a target ID
func (rt *RoutingTable) FindClosest(target ID, count int) []*Node {
	rt.mu.RLock()
	defer rt.mu.RUnlock()

	var candidates []*Node

	// Flatten buckets
	for _, bucket := range rt.Buckets {
		candidates = append(candidates, bucket...)
	}

	// Sort by distance to target
	sort.Slice(candidates, func(i, j int) bool {
		distI := Xor(candidates[i].ID, target)
		distJ := Xor(candidates[j].ID, target)
		return bytes.Compare(distI[:], distJ[:]) < 0
	})

	if len(candidates) > count {
		return candidates[:count]
	}
	return candidates
}

// --- Node Implementation (RPC Simulation) ---

func NewNode(addr string, net *Network) *Node {
	n := &Node{
		ID:      NewID(),
		Addr:    addr,
		Store:   make(map[ID][]byte),
		Network: net,
	}
	n.Table = NewRoutingTable(n.ID)
	return n
}

// Bootstrap connects a node to the network via a known peer
func (n *Node) Bootstrap(entryNode *Node) {
	n.Table.Update(entryNode)
	// In real Kad, we would perform a node lookup on our own ID to populate buckets
	n.FindNode(n.ID)
}

// StoreValue (RPC handling)
func (n *Node) HandleStore(key ID, val []byte) {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.Store[key] = val
	// fmt.Printf("[%s] Stored data for key %s\n", n.ID, key)
}

// FindNode (RPC handling)
func (n *Node) HandleFindNode(target ID) []*Node {
	return n.Table.FindClosest(target, K)
}

// FindValue (RPC handling) returns value OR closest nodes
func (n *Node) HandleFindValue(key ID) ([]byte, []*Node) {
	n.mu.RLock()
	val, ok := n.Store[key]
	n.mu.RUnlock()

	if ok {
		return val, nil
	}
	return nil, n.Table.FindClosest(key, K)
}

// --- Core Client Operations ---

// Lookup finds the K closest nodes to a target ID in the network
func (n *Node) FindNode(target ID) []*Node {
	// Start with local closest
	closest := n.Table.FindClosest(target, K)
	visited := make(map[ID]bool)
	visited[n.ID] = true

	// Simplified iterative lookup
	// In real Kad, this is parallel (Alpha) and handles timeouts
	changed := true
	for changed {
		changed = false
		// Sort current list
		sort.Slice(closest, func(i, j int) bool {
			distI := Xor(closest[i].ID, target)
			distJ := Xor(closest[j].ID, target)
			return bytes.Compare(distI[:], distJ[:]) < 0
		})

		// Pick 'Alpha' unvisited nodes
		queriedCount := 0
		for _, peer := range closest {
			if visited[peer.ID] {
				continue
			}
			if queriedCount >= Alpha {
				break
			}
			visited[peer.ID] = true
			queriedCount++

			// Simulate RPC
			newPeers := peer.HandleFindNode(target)

			// Update local table with seen peers
			n.Table.Update(peer)
			for _, np := range newPeers {
				n.Table.Update(np)

				// Add to closest list if not present
				exists := false
				for _, c := range closest {
					if c.ID == np.ID {
						exists = true
						break
					}
				}
				if !exists {
					closest = append(closest, np)
					changed = true
				}
			}
		}
	}

	// Final sort and cut
	sort.Slice(closest, func(i, j int) bool {
		distI := Xor(closest[i].ID, target)
		distJ := Xor(closest[j].ID, target)
		return bytes.Compare(distI[:], distJ[:]) < 0
	})
	if len(closest) > K {
		return closest[:K]
	}
	return closest
}

// Store data in the network
func (n *Node) Put(keyStr string, value string) {
	key := HashKey(keyStr)
	nodes := n.FindNode(key)

	fmt.Printf("[%s] Storing '%s' on %d nodes closest to key %s\n", n.ID, keyStr, len(nodes), key)

	for _, peer := range nodes {
		peer.HandleStore(key, []byte(value))
	}
}

// Get data from the network
func (n *Node) Get(keyStr string) (string, bool) {
	key := HashKey(keyStr)
	closest := n.Table.FindClosest(key, K)
	visited := make(map[ID]bool)

	// Simple iterative search for value
	queue := closest

	for len(queue) > 0 {
		peer := queue[0]
		queue = queue[1:] // pop

		if visited[peer.ID] {
			continue
		}
		visited[peer.ID] = true

		// RPC call
		val, nextNodes := peer.HandleFindValue(key)

		if val != nil {
			return string(val), true
		}

		// Update table and queue
		n.Table.Update(peer)
		for _, next := range nextNodes {
			if !visited[next.ID] {
				queue = append(queue, next)
			}
		}

		// Sort queue by distance to keep searching closer nodes
		sort.Slice(queue, func(i, j int) bool {
			distI := Xor(queue[i].ID, key)
			distJ := Xor(queue[j].ID, key)
			return bytes.Compare(distI[:], distJ[:]) < 0
		})
	}

	return "", false
}

// --- Main Execution ---

func main() {
	rand.Seed(time.Now().UnixNano())

	// 1. Setup Network Wrapper
	net := &Network{Nodes: make(map[string]*Node)}

	var nodes []*Node
	numNodes := 10

	fmt.Println("--- Bootstrapping Network ---")

	// 2. Start 10 Nodes
	// Node 0 is the seed
	node0 := NewNode("node0", net)
	net.Nodes["node0"] = node0
	nodes = append(nodes, node0)

	var wg sync.WaitGroup

	for i := 1; i < numNodes; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			addr := fmt.Sprintf("node%d", idx)
			newNode := NewNode(addr, net)

			// Simulate registering to network
			net.mu.Lock()
			net.Nodes[addr] = newNode
			net.mu.Unlock()

			// Bootstrap via Node 0
			// In a real network, this takes time
			time.Sleep(time.Duration(rand.Intn(100)) * time.Millisecond)
			newNode.Bootstrap(node0)

			// Mutex lock for safely appending to the slice in main (just for tracking)
			// In reality, we don't need a global list of nodes
			net.mu.Lock()
			nodes = append(nodes, newNode)
			net.mu.Unlock()

			fmt.Printf("Node %d joined. ID: %s\n", idx, newNode.ID)
		}(i)
	}

	wg.Wait()
	time.Sleep(500 * time.Millisecond) // Let bootstrapping settle

	fmt.Println("\n--- Storing Data ---")

	// 3. Node 9 wants to store "SecretData" under key "MyKey"
	// It doesn't know where it goes, it relies on Kademlia routing
	storingNode := nodes[9]
	storingNode.Put("MyKey", "SecretData")

	time.Sleep(100 * time.Millisecond)

	fmt.Println("\n--- Retrieving Data ---")

	// 4. Node 2 (far away from Node 9) tries to retrieve it
	retrievingNode := nodes[2]
	val, found := retrievingNode.Get("MyKey")

	if found {
		fmt.Printf("SUCCESS: Node %s found data: '%s'\n", retrievingNode.ID, val)
	} else {
		fmt.Printf("FAILURE: Data not found.\n")
	}

	// Verify who actually holds the data
	keyID := HashKey("MyKey")
	fmt.Printf("\n--- Verification (Key ID: %s) ---\n", keyID)
	for _, n := range nodes {
		n.mu.RLock()
		if _, ok := n.Store[keyID]; ok {
			dist := Xor(n.ID, keyID)
			fmt.Printf("Node %s HAS the data (Dist: %x)\n", n.ID, dist[:2])
		}
		n.mu.RUnlock()
	}
}
