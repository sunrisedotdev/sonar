# Sonar Smart Contracts

This directory contains Foundry-based smart contracts for Sonar, including reference implementations and examples for token sales and auctions.

## 🚨 WARNING: These contracts are untested and unaudited and should ONLY be used for reference purposes. 🚨

---

## Prerequisites

### Install Foundry

Follow the installation instructions by visiting the [official Foundry documentation](https://book.getfoundry.sh/getting-started/installation).

---

## Installation

1. Install dependencies

```bash
forge install
```

This will install:

- `forge-std` - Foundry's standard library for testing
- `openzeppelin-contracts` - OpenZeppelin's secure smart contract library

---

## Reference contracts

### ExampleSale

The `ExampleSale` contract is a toy sale implementation demonstrating entity-based purchase tracking where purchases from multiple wallets belonging to the same entity are aggregated and validated against entity-level limits.

### SettlementSale

The `SettlementSale` contract is a token sale implementation based on commitments and offchain settlement.

**Key Features:**

- Integration with Sonar's purchase permit system
- Multi-stage sale process (PreOpen → Open → Closed → Cancellation → Settlement → Done)
- Allocations are computed offchain and submitted to the contract
- Built-in refund and withdrawal mechanisms

---

## Scripts

This repo includes some node.js scripts in the `scripts` directory for conveniently interacting with deployed contracts.

### commitment-data-csv

Fetches all commitment data from a contract in CSV format.

```
pnpm commitment-data-csv --sale-address <contract-address> --rpc-url <url>
```

---

## Testing

### Run All Tests

```bash
forge test
```

## Additional Resources

- [Foundry Book](https://book.getfoundry.sh/) - Complete Foundry documentation
- [Foundry GitHub](https://github.com/foundry-rs/foundry) - Source code and issue tracker
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) - Contract library documentation
