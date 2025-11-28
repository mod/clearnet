// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Represents a registered node in the network
struct NodeRecord {
    /// @notice Internal index in the activeNodes array (used for swap-and-pop)
    uint256 index;
    /// @notice Unique composite hash identifying the node (keccak256(network, chainId, address))
    bytes32 nodeId;
    /// @notice The Ethereum address of the node operator
    address operator;
    /// @notice DNS domain or IP address of the node
    string domain;
    /// @notice TCP/UDP listening port
    uint16 port;
    /// @notice Amount of tokens staked by the operator
    uint256 amount;
    /// @notice Timestamp when the node first registered
    uint64 registredAt;
    /// @notice Timestamp when the stake unlocks (0 if active)
    uint64 unlockAt;
}

/// @title IRegistry
/// @notice Interface for the Clearnet Node Registry, handling node lifecycle and network configuration.
interface IRegistry {
    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new node registers.
    event NodeRegistered(address indexed operator, bytes32 nodeId);

    /// @notice Emitted when a node updates its connection details.
    event NodeUpdated(address indexed operator, string domain, uint16 port);

    /// @notice Emitted when a node unregisters and starts the cooldown.
    event NodeUnregistered(address indexed operator, uint64 cooldownEnd);

    /// @notice Emitted when a node withdraws its stake after cooldown.
    event CollateralWithdrawn(address indexed operator, uint256 amount);

    /// @notice Emitted when the DAO updates the network protocol version.
    event VersionUpdated(uint32 version, string url);

    // -------------------------------------------------------------------------
    // Write Functions (Node Operator)
    // -------------------------------------------------------------------------

    /// @notice Registers a new node by staking tokens.
    /// @param nodeId The unique composite hash of the node.
    /// @param domain The DNS domain or IP address.
    /// @param port The listening port.
    function register(bytes32 nodeId, string calldata domain, uint16 port) external;

    /// @notice Unregisters the node, removing it from active discovery and starting the withdrawal cooldown.
    function unregister() external;

    /// @notice Updates the node's connection details without affecting stake.
    /// @param domain The new DNS domain or IP address.
    /// @param port The new listening port.
    function updateNode(string calldata domain, uint16 port) external;

    /// @notice Withdraws the staked tokens after the cooldown period has elapsed.
    function withdraw() external;

    // -------------------------------------------------------------------------
    // Governance Functions
    // -------------------------------------------------------------------------

    /// @notice Updates the global network protocol version and manifest.
    /// @dev Can only be called by the contract owner/governor.
    /// @param version The new protocol version number.
    /// @param url The URL to the new network manifest (HTTPS or IPFS).
    /// @param checksum The SHA-256 checksum of the manifest file.
    function updateVersion(uint32 version, string calldata url, bytes32 checksum) external;

    // -------------------------------------------------------------------------
    // Read Functions
    // -------------------------------------------------------------------------

    /// @notice Retrieves a node's details by its unique Node ID.
    /// @param nodeId The unique composite hash of the node.
    /// @return The NodeRecord struct.
    function getNodeById(bytes32 nodeId) external view returns (NodeRecord memory);

    /// @notice Retrieves a page of active nodes.
    /// @dev Ordering is unstable (swap-and-pop).
    /// @param offset The starting index.
    /// @param limit The maximum number of nodes to return.
    /// @return An array of NodeRecord structs.
    function getActiveNodes(uint256 offset, uint256 limit) external view returns (NodeRecord[] memory);

    /// @notice Returns the total count of currently active nodes.
    function totalActiveNodes() external view returns (uint256);

    /// @notice Retrieves the current network protocol version and manifest.
    /// @return version The current version number.
    /// @return url The URL of the manifest file.
    /// @return checksum The SHA-256 checksum of the manifest.
    function getVersion() external view returns (uint32 version, string memory url, bytes32 checksum);
}
