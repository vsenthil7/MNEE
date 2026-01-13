# MNEE — Modular Networked Execution Engine

MNEE is a programmable execution framework for policy-driven money movement, treasury control, and portfolio-level orchestration.

This repository is structured around a strict separation between **core execution primitives** and **products** built on top of that core.

---

## Repository Structure

## Repository Structure

```text
MNEE/
├─ core/                  # Shared execution primitives (no product logic)
├─ PFTA/                  # Programmable Finance & Treasury Automation
├─ PV/                    # PortView — portfolio orchestration kernel
├─ docs/                  # Architecture and design notes
├─ bootstrap-core-and-pv.ps1
└─ .gitignore
```
---

## Core Layer (`/core`)

The core layer contains reusable, product-agnostic execution logic.

### Responsibilities

- Treasury vault logic  
- Policy enforcement engines  
- Payment scheduling primitives  
- Explicit authorization patterns  
- Shared interfaces  

### Rules

- Core does NOT deploy independently  
- Core has NO environment configuration  
- Core contains NO product assumptions  
- Products must explicitly consume core logic  
- Core exists to reduce duplication and centralize control  

---

## Product: PFTA  
### Programmable Finance & Treasury Automation

PFTA is a treasury execution engine supporting:

- ERC-20 based treasury vaults  
- Policy-bounded payments  
- Time-scheduled execution  
- Explicit admin and scheduler roles  
- Deterministic fund release  
- Full unit and integration tests  

### Run PFTA Locally

```bash
cd PFTA
npm install
npx hardhat compile
npx hardhat test
```

**Status:** Stable and tested


## Product: PV (PortView)
### Portfolio-Level Orchestration

PV is a portfolio orchestration kernel built on MNEE core logic.

It composes:

- TreasuryVault
- PolicyEngine
- PaymentScheduler

into a single portfolio execution contract.

### Characteristics

- Explicit admin ownership
- No implicit initialization
- Authorization done deliberately
- No UI dependency
- Ready for multi-portfolio expansion

### Run PV Locally

```bash
cd PV
npm install
npx hardhat compile
npx hardhat test

## Tooling

- **Node.js:** 18.x (warnings acknowledged)
- **Hardhat:** Local per product
- **Solidity:** ^0.8.20
- **Testing:** Hardhat + Chai

---

## Git Hygiene

### Tracked

- Source code
- Tests
- Configuration

### Ignored

```bash
node_modules/
artifacts/
cache/
coverage/
.env

Repository history has been rewritten to remove committed dependencies.

---

## What MNEE Is Not

- Not UI-first
- Not dashboard-driven
- Not a single-contract system
- Not an opinionated frontend product

---

## Design Philosophy

- Explicit > Implicit
- Authorization before execution
- Policy before transfer
- Deterministic over convenience
- Execution kernels over apps

---

## License

MIT







