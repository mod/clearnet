<!--
SYNC IMPACT REPORT
Version: 0.0.0 -> 1.0.0
Change Type: Major (Initial Ratification)

Modified Principles:
- Defined I. Spec-Driven Development
- Defined II. Simulation-First Verification
- Defined III. Protocol Agnosticism
- Defined IV. Security & Custody Safety
- Defined V. Atomic Modularity

Added Sections:
- Technical Constraints
- Workflow & Quality

Templates Status:
- .specify/templates/plan-template.md: ✅ Compatible
- .specify/templates/spec-template.md: ✅ Compatible
- .specify/templates/tasks-template.md: ✅ Compatible

Follow-up TODOs:
- None
-->
# Clearnet Constitution

## Core Principles

### I. Spec-Driven Development
Every feature starts with a written specification. No code is written until a Plan (Problem/Solution) and Spec (Requirements/Data Model) are defined in the `.specify` directory. We think before we type.

### II. Simulation-First Verification
Given the distributed nature of Clearnet, unit tests are insufficient. All core protocol logic must be verifiable via the `cmd/demo` simulation. We validate happy paths and fraud scenarios (unhappy paths) in a controlled, deterministic environment before deploying to testnets.

### III. Protocol Agnosticism
The Core Node logic (`pkg/`) must remain decoupled from specific chain implementations (EVM/SVM). We define clear Interfaces (`pkg/ports`) and implement Adapters (`contracts/`) to bridge specific blockchains. The core business logic should not know it is running on Ethereum or Solana.

### IV. Security & Custody Safety
Smart contracts hold user funds. Security is non-negotiable. All contract changes require rigorous testing (Foundry/Anchor) and, where applicable, formal verification or audit. We assume the network is adversarial; "Don't trust, verify" applies to every state transition.

### V. Atomic Modularity
Libraries and modules must be small, self-contained, and independently testable. We avoid monolithic coupling. A change in the P2P layer should not require a re-compile of the Consensus layer unless interfaces change.

## Technical Constraints

*   **Languages:** Go (Node), Solidity (EVM), Rust (SVM).
*   **Formatting:** Strictly enforce `gofmt`, `forge fmt`, and `cargo fmt`.
*   **Dependencies:** Minimize external dependencies. Prefer standard libraries where possible to reduce attack surface.
*   **Secrets:** No secrets or private keys in the codebase. Use environment variables or secure vaults.

## Workflow & Quality

*   **Branching:** Feature branches (`feature/xyz`) merge into `main` via Pull Request.
*   **Testing:** CI must pass all unit tests and the `cmd/demo` simulation suite.
*   **Documentation:** Public interfaces must be documented. Specs in `.specify` must be kept in sync with implementation.
*   **Reviews:** Code must be reviewed by at least one peer.

## Governance

This Constitution is the supreme authority on engineering practices for Clearnet. It supersedes oral tradition.

*   **Amendments:** Changes to this document require a Pull Request labeled `governance` and consensus from core maintainers.
*   **Compliance:** All PRs must verify compliance with these principles.
*   **Guidance:** Use `.specify/templates/` for all new workflows to ensure consistency.

**Version**: 1.0.0 | **Ratified**: 2025-11-27 | **Last Amended**: 2025-11-27