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

### set-allocations

Sets allocations for entities on the sale contract based on a CSV file. This script validates all allocations against on-chain commitment data before submitting transactions.

Note: This script sets allocations but does not finalize (process) them. Finalization is a separate step.

#### Getting commitment data

Before creating your allocations CSV, fetch all current commitments using the `commitment-data-csv` script documented above.

#### CSV format

The allocations CSV must have the following columns:

| Column                    | Description                                                             |
| ------------------------- | ----------------------------------------------------------------------- |
| `SALE_SPECIFIC_ENTITY_ID` | The entity's ID in the sale (bytes16, hex format)                       |
| `WALLET`                  | The wallet address (0x-prefixed)                                        |
| `TOKEN`                   | The payment token address (0x-prefixed)                                 |
| `ACCEPTED_AMOUNT`         | The amount to allocate (in token base units, e.g., 6 decimals for USDC) |

#### Dry run (default)

By default, the script runs in dry-run mode, which validates everything without submitting transactions:

```bash
PRIVATE_KEY=<key> pnpm set-allocations \
  --allocations-csv allocations.csv \
  --sale-address <address> \
  --rpc-url <url>
```

This will output validation results and exit without modifying on-chain state.

#### Submitting transactions

To actually submit transactions, disable dry-run mode. You will be prompted for confirmation:

```bash
PRIVATE_KEY=<key> pnpm set-allocations \
  --allocations-csv allocations.csv \
  --sale-address <address> \
  --rpc-url <url> \
  --dry-run false
```

#### Handling batch failures

Allocations are submitted in batches of 500. If a batch fails mid-way:

1. Check the transaction hash in the error output to see what failed
2. The script does not automatically resume—you'll need to re-run it
3. If `--allowed-overwrites false` (default), already-set allocations will cause the transaction to revert
4. To resume after a partial failure, either:
    - Remove already-set allocations from your CSV, or
    - Re-run with `--allowed-overwrites true` to overwrite existing allocations

#### Overwriting existing allocations

By default, attempting to set an allocation that already exists on-chain will fail. To allow overwrites:

```bash
PRIVATE_KEY=<key> pnpm set-allocations \
  --allocations-csv allocations.csv \
  --sale-address <address> \
  --rpc-url <url> \
  --allowed-overwrites true \
  --dry-run false
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
