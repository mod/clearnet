# Requirements Checklist: Protocol & Contract Safety

**Purpose**: Validation of requirements for protocol security, data integrity, and cross-chain consistency (EVM MVP).
**Created**: 2025-11-27
**Feature**: Protocol Logic & Smart Contracts

## Protocol Security (Fraud & Custody)

- [x] CHK001 Are the conditions for `challenge()` (fraud proof) explicitly defined and cover all replay/rollback scenarios? [Completeness, Spec §FR-006]
- [x] CHK002 Is the `CHALLENGE_PERIOD` explicitly defined with a default value safe for the MVP? [Clarity, Spec §FR-005]
- [x] CHK003 Are requirements for preventing double-spending via replay attacks (reusing old states) clearly specified? [Coverage, Spec §FR-008]
- [x] CHK004 Is the behavior for failed token transfers (blacklists, pauses) explicitly defined to prevent locked protocol states? [Edge Case, Spec §FR-010]
- [x] CHK005 Are node authorization requirements (registry checks) defined for the exact moment of transaction execution? [Security, Spec §FR-009]

## Data Integrity & Cross-Chain Consistency

- [x] CHK006 Is the hashing algorithm for `State` defined in a way that is identical across EVM (Solidity) and Backend (Go/Rust)? [Consistency, Spec §FR-011]
- [x] CHK007 Is the canonical ordering of `participants` (e.g., XOR distance) explicitly required to ensure deterministic state hashes? [Clarity, Spec §FR-012]
- [x] CHK008 Are data types for `State` attributes (e.g., uint256 vs uint64) consistent between the Data Model and Functional Requirements? [Consistency, Data Model]
- [x] CHK009 Are requirements for `minQuorum` defined as a system-wide or per-channel configuration for the MVP? [Scope, Spec §FR-003]

## Implementation Readiness (Spec Author Focus)

- [x] CHK010 Are all key entities (`Vault`, `State`, `Request`) defined with their required fields and types? [Completeness, Data Model]
- [x] CHK011 Are the acceptance criteria for "Happy Path" (Deposit -> Withdraw) complete and testable? [Measurability, Spec §US-1]
- [x] CHK012 Are the acceptance criteria for "Fraud Path" (Challenge success/fail) complete and testable? [Measurability, Spec §US-2]
- [x] CHK013 Are gas cost targets (specifically <300k for `deposit` and `withdraw`, <500k for `challenge`) defined as a non-functional requirement? [Performance, Spec §SC-003]
- [x] CHK014 Is the behavior for handling "removed nodes" (signatures from formerly active nodes) clearly specified? [Edge Case, Spec §EC-001]
