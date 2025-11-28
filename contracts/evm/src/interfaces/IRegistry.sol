// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

struct NodeRecord {
    bytes nodeId;
    string domain;
    uint16 port;
    uint64 registrationTime;
    uint256 stakedAmount;
    uint64 cooldownEnd;
    uint256 index; // Internal tracking
}

interface IRegistry {
    // Events
    event NodeRegistered(address indexed operator, bytes nodeId);
    event NodeUpdated(address indexed operator, string domain, uint16 port);
    event NodeUnregistered(address indexed operator, uint64 cooldownEnd);
    event StakeWithdrawn(address indexed operator, uint256 amount);
    event NetworkConfigUpdated(uint32 version, string ipfsHash);

    // Write Functions
    function register(bytes calldata nodeId, string calldata domain, uint16 port) external;
    function updateNode(string calldata domain, uint16 port) external;
    function unregister() external;
    function withdrawStake() external;
    
    // Governance
    function updateNetworkConfig(uint32 version, string calldata ipfsHash, bytes32 checksum) external;

    // Read Functions
    function getNode(address operator) external view returns (NodeRecord memory);
    function getNodeByPublicKey(bytes calldata nodeId) external view returns (NodeRecord memory);
    function getActiveNodes(uint256 offset, uint256 limit) external view returns (NodeRecord[] memory);
    function getManifest() external view returns (uint32 version, string memory ipfsHash, bytes32 checksum);
    function totalActiveNodes() external view returns (uint256);
}
