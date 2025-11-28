# Feature Specification: Node Registry

**Feature Branch**: `002-node-registry`  
**Created**: 2025-11-28  
**Status**: Draft  
**Input**: User description: "Node Registry: On-chain smart-contract for node registration and configuration DAO..."

## Clarifications

### Session 2025-11-28
- Q: How should registered nodes update their connection details? → A: Option A - dedicated `updateNode(domain, port)` function.
- Q: Does unregistering ever trigger slashing automatically? → A: Option A - Separate Actions; unregistering is safe, slashing is distinct.
- Q: Can two different addresses register the same Node ID (Public Key)? → A: Option A - Strict Uniqueness; revert if ID exists.
- Q: How does the Registry interact with the DAO for updates? → A: Option A - External Controller; Registry checks `msg.sender == governor`.
- Q: How should pagination be implemented for 10k nodes? → A: Option A - Sequential Indexing; array/mapping+counter for O(1) access.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Node Registration (Priority: P1)

A node operator wants to register their clearnet node on the network so that other nodes can discover and connect to it. This requires staking tokens to ensure good behavior.

**Why this priority**: This is the core functionality. Without registered nodes, there is no network.

**Independent Test**: Can be fully tested by deploying the contract, approving tokens, and calling the register function, then verifying the node appears in the registry.

**Acceptance Scenarios**:

1. **Given** an operator has at least 250,000 YELLOW tokens and has approved the Registry contract, **When** they call `register` with their Node ID (Public Key), Domain, and Port, **Then** 250,000 YELLOW tokens are transferred to the contract, and the node is added to the active list.
2. **Given** an operator has less than 250,000 YELLOW tokens, **When** they try to register, **Then** the transaction reverts.
3. **Given** a node is already registered, **When** they try to register again with the same address, **Then** the transaction reverts (operators must use `updateNode` to change details).
4. **Given** a Node ID is already registered by User A, **When** User B tries to register with the same Node ID, **Then** the transaction reverts (strict uniqueness).

### User Story 2 - Node Discovery and Startup (Priority: P1)

A new node starting up needs to find the network configuration and other peers to connect to.

**Why this priority**: Essential for the node to function in the network.

**Independent Test**: Can be tested by simulating a node reading from the deployed contract and fetching the mock IPFS data.

**Acceptance Scenarios**:

1. **Given** a node is starting up and knows the Registry ENS name, **When** it resolves the Registry address, **Then** it successfully connects to the contract.
2. **Given** the node has a local protocol version lower than the Registry's version, **When** it checks the Registry, **Then** it retrieves the new Manifest IPFS hash and Checksum, fetches the file from IPFS, validates the checksum, and applies the configuration.
3. **Given** the node needs peers, **When** it requests the last 20 registered nodes, **Then** it receives a list of valid Node IDs and connection details.

### User Story 3 - DAO Network Configuration Update (Priority: P2)

The DAO needs to update global network parameters (e.g., block time, fees, supported versions) without redeploying the registry.

**Why this priority**: Allows the network to evolve and adapt parameters dynamically.

**Independent Test**: Can be tested by having the owner/governor call the update function and verifying the version number increments.

**Acceptance Scenarios**:

1. **Given** a valid governance proposal execution (simulated by owner call), **When** the `updateNetworkConfig` function is called with a new IPFS hash and checksum, **Then** the protocol version is incremented, and the new configuration pointer is stored.

### User Story 4 - Unregistration and Withdrawal (Priority: P3)

An operator wants to leave the network and retrieve their stake.

**Why this priority**: Necessary for the economic lifecycle of a node, but less critical than joining.

**Independent Test**: Test the time-lock mechanism by trying to withdraw immediately vs after 7 days.

**Acceptance Scenarios**:

1. **Given** a registered node, **When** the operator calls `unregister`, **Then** the node is removed from the active discovery list, and a 7-day cooldown timer starts.
2. **Given** a node is in the cooldown period, **When** the operator tries to `withdrawStake`, **Then** the transaction reverts.
3. **Given** the 7-day cooldown has passed, **When** the operator calls `withdrawStake`, **Then** the 250,000 YELLOW tokens are transferred back to the operator.

### Edge Cases

- What happens when the IPFS hash is invalid or content is missing? (Node should likely keep using last known good config or fail to start).
- What happens when the YELLOW token transfer fails? (Registration reverts).
- What happens if the registry exceeds 10,000 nodes? (Pagination ensures reads work; writes must remain executable within limits).
- Slashing is a separate administrative action and does not occur automatically during unregistration.
- Registration fails if the Node ID is already associated with another active operator.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The System MUST allow an address to register a node by providing a Node ID (Public Key), Domain, and Port.
- **FR-002**: The System MUST require a stake of exactly 250,000 YELLOW tokens for registration.
- **FR-003**: The System MUST store the Protocol Version, Manifest IPFS Hash, and Manifest Checksum.
- **FR-004**: The System MUST allow the DAO (authorized caller via governance role) to update the Protocol Version, Manifest Hash, and Checksum.
- **FR-005**: The System MUST provide a function to retrieve the current Protocol Version and Manifest details.
- **FR-006**: The System MUST provide a function to retrieve a list of registered nodes with pagination (e.g., fetch N nodes starting from index I) using sequential indexing.
- **FR-007**: The System MUST provide a function to look up a single node's details by its Node ID (Public Key).
- **FR-008**: The System MUST allow a registered operator to unregister, which removes them from the active list and initiates a 7-day cooldown.
- **FR-009**: The System MUST allow an operator to withdraw their stake ONLY after the 7-day cooldown has elapsed.
- **FR-010**: The System MUST support storing details for up to 10,000 active nodes.
- **FR-011**: The System MUST provide an `updateNode` function for operators to modify Domain and Port without restaking.
- **FR-012**: The System MUST NOT automatically slash tokens during unregistration; slashing is distinct.
- **FR-013**: The System MUST enforce uniqueness of Node IDs; no two active registrations can share the same Public Key.

### Key Entities

- **NodeRecord**:
    - Owner Address (Ethereum address)
    - Node ID (Public Key - bytes or string)
    - Connection Details (Domain, Port)
    - Registration Timestamp
    - Status (Active, Unregistering, Unregistered)
    - Cooldown End Timestamp
- **NetworkManifest**:
    - Protocol Version (Integer)
    - IPFS Hash (string/bytes)
    - Checksum (bytes32)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The registry contract supports at least 10,000 active nodes without exceeding transaction resource limits for read/write operations (pagination applied).
- **SC-002**: A node can fetch the latest 20 registered nodes in a single request.
- **SC-003**: Registration and Unregistration flows function correctly with the 250,000 YELLOW token requirement.
- **SC-004**: Nodes successfully detect a version change and resolve the new Manifest from the stored IPFS hash.

## Assumptions

- The YELLOW token is a standard ERC20 contract.
- The "DAO" mechanism for calling the update function is represented by an `owner` or `governor` address for the purpose of this registry spec.
- The Manifest file format is YAML.
- ENS resolution is handled by the client (Node), the contract just lives at an address.