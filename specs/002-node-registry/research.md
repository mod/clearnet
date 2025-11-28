# Research: Node Registry

**Feature**: Node Registry
**Date**: 2025-11-28

## Decisions

### 1. Pagination Strategy
- **Decision**: Sequential Indexing with `mapping(uint256 => address) activeNodeIndex` and `address[] activeNodes`.
- **Rationale**: 
    - Gas efficiency: Access by index is O(1).
    - Simplicity: "Fetch last 20" becomes "fetch `totalNodes - 1` down to `totalNodes - 20`".
    - Deletion handling: When a node unregisters, swap the last element into its place and pop the last element (Swap-and-Pop). This keeps the array dense and maintains O(1) removal cost, though it changes indices (acceptable for a discovery registry where order isn't strictly chronological or critical).
- **Alternatives Considered**:
    - Linked List: Too expensive for "jump to page X" random access.
    - EnumerableMap (OpenZeppelin): Good, but custom implementation allows optimization for specific struct data vs generic storage.

### 2. Governance / Updates
- **Decision**: `Ownable` (or `AccessControl`) with a dedicated `governor` address.
- **Rationale**: 
    - The requirement specifies an "External Controller" pattern.
    - Keeps the registry simple. The `governor` can be a DAO Timelock, a Multisig, or an EOA initially.
    - Updates to `manifest` (IPFS hash) are restricted to this modifier.

### 3. Staking Mechanism
- **Decision**: `transferFrom` pattern with a predefined `yellowToken` address.
- **Rationale**: Standard ERC20 staking.
- **Alternatives Considered**: Native ETH staking (rejected: requirement specifies YELLOW token).

### 4. Interface Definition
- **Decision**: Define a Go interface `IRegistry` in `pkg/ports` matching the core behaviors, not the contract methods 1:1.
- **Rationale**: Decoupling. The node needs `Register`, `GetManifest`, `GetNodes`. It doesn't care about `approve` or implementation details.

### 5. Slashing Placeholder
- **Decision**: The spec mentions slashing is for a "later release". The contract will NOT implement a `slash()` function now, but the data model (staked amount) will be kept flexible. Actually, to support future slashing without migration, we might need a `slash` function restricted to an empty `slasher` role that can be set later.
- **Refinement**: To strictly follow "YAGNI" (You Ain't Gonna Need It) but allow for the "later release" mentioned, we will ensure the `withdraw` logic calculates amount based on a stored balance, not a constant. However, the spec says "require stake of EXACTLY 250,000". If slashing happens, they have < 250,000. Re-registering might be needed.
- **Final Decision**: Simplify. Store `stakedAmount`. Future slashing contract can be authorized to reduce this amount. For now, just standard staking.

## Unknowns Resolution

- **Pagination for 10k nodes**: Resolved via Swap-and-Pop array strategy.
- **DAO Interaction**: Resolved via External Governor (`onlyOwner` style).
