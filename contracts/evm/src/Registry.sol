// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRegistry, NodeRecord} from "./interfaces/IRegistry.sol";

contract Registry is IRegistry, Ownable {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    // Configuration
    IERC20 public immutable yellowToken;
    uint256 public constant STAKE_AMOUNT = 250_000 ether; // Assuming 18 decimals
    uint256 public constant COOLDOWN_PERIOD = 7 days;

    // Node Storage
    // Mapping from Operator Address -> Node Details
    mapping(address => NodeRecord) public nodes;

    // Array of active operator addresses for enumeration (Swap-and-Pop)
    address[] public activeNodes;

    // Unique ID check: Public Key -> Is Registered
    mapping(bytes32 => bool) public nodeIdUsed;
    mapping(bytes32 => address) public nodeIdToOwner;

    // Network Manifest
    struct NetworkManifest {
        uint32 version;
        string url;
        bytes32 checksum;
    }
    NetworkManifest public manifest;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(address _token) Ownable(msg.sender) {
        yellowToken = IERC20(_token);
    }

    // -------------------------------------------------------------------------
    // Write Functions
    // -------------------------------------------------------------------------
    function register(bytes32 nodeId, string calldata domain, uint16 port) external override {
        require(!nodeIdUsed[nodeId], "Node ID already used");
        require(nodes[msg.sender].amount == 0, "Already registered");
        require(yellowToken.balanceOf(msg.sender) >= STAKE_AMOUNT, "Insufficient stake");

        // Transfer stake
        yellowToken.transferFrom(msg.sender, address(this), STAKE_AMOUNT);

        // Update state
        nodeIdUsed[nodeId] = true;
        nodeIdToOwner[nodeId] = msg.sender;

        activeNodes.push(msg.sender);
        uint256 index = activeNodes.length - 1;

        nodes[msg.sender] = NodeRecord({
            index: index,
            nodeId: nodeId,
            operator: msg.sender,
            domain: domain,
            port: port,
            amount: STAKE_AMOUNT,
            registredAt: uint64(block.timestamp),
            unlockAt: 0
        });

        emit NodeRegistered(msg.sender, nodeId);
    }

    function updateNode(string calldata domain, uint16 port) external override {
        require(nodes[msg.sender].amount > 0, "Not registered");
        require(nodes[msg.sender].unlockAt == 0, "In cooldown"); // Cannot update if unregistering

        NodeRecord storage node = nodes[msg.sender];
        node.domain = domain;
        node.port = port;

        emit NodeUpdated(msg.sender, domain, port);
    }

    function unregister() external override {
        require(nodes[msg.sender].amount > 0, "Not registered");
        require(nodes[msg.sender].unlockAt == 0, "Already unregistering");

        // Swap and Pop
        uint256 index = nodes[msg.sender].index;
        uint256 lastIndex = activeNodes.length - 1;

        if (index != lastIndex) {
            address lastOperator = activeNodes[lastIndex];
            activeNodes[index] = lastOperator;
            nodes[lastOperator].index = index;
        }
        activeNodes.pop();

        uint64 unlockTime = uint64(block.timestamp + COOLDOWN_PERIOD);
        nodes[msg.sender].unlockAt = unlockTime;

        emit NodeUnregistered(msg.sender, unlockTime);
    }

    function withdraw() external override {
        uint64 unlockAt = nodes[msg.sender].unlockAt;
        require(unlockAt != 0, "Not unregistering");
        require(block.timestamp >= unlockAt, "Cooldown not ended");

        uint256 amount = nodes[msg.sender].amount;
        require(amount > 0, "Nothing to withdraw");

        // Cleanup
        bytes32 nodeId = nodes[msg.sender].nodeId;
        delete nodeIdUsed[nodeId];
        delete nodeIdToOwner[nodeId];
        delete nodes[msg.sender];

        // Transfer
        yellowToken.transfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function updateManifest(uint32 version, string calldata url, bytes32 checksum) external override onlyOwner {
        require(version > manifest.version, "Version must increment");

        manifest = NetworkManifest({version: version, url: url, checksum: checksum});

        emit ManifestUpdated(version, url);
    }

    // -------------------------------------------------------------------------
    // Read Functions
    // -------------------------------------------------------------------------
    function getNodeById(bytes32 nodeId) external view override returns (NodeRecord memory) {
        address operator = nodeIdToOwner[nodeId];
        require(operator != address(0), "Node not found");
        return nodes[operator];
    }

    function getActiveNodes(uint256 offset, uint256 limit) external view override returns (NodeRecord[] memory) {
        uint256 total = activeNodes.length;
        if (offset >= total) {
            return new NodeRecord[](0);
        }

        uint256 count = limit;
        if (offset + count > total) {
            count = total - offset;
        }

        NodeRecord[] memory result = new NodeRecord[](count);
        for (uint256 i = 0; i < count; i++) {
            address op = activeNodes[offset + i];
            result[i] = nodes[op];
        }

        return result;
    }

    function getManifest() external view override returns (uint32 version, string memory url, bytes32 checksum) {
        return (manifest.version, manifest.url, manifest.checksum);
    }

    function totalActiveNodes() external view override returns (uint256) {
        return activeNodes.length;
    }
}
