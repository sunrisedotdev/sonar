# Sonar Smart Contracts

This directory contains Foundry-based smart contracts for Sonar, including reference implementations and examples for token sales and auctions.

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

```
contracts/
├── src/
│   └── EnglishAuctionSale.sol
├── test/
│   └── EnglishAuctionSale.t.sol
├── lib/                    # Dependencies (git submodules)
```

---

## Examples

### EnglishAuctionSale

The `EnglishAuctionSale` contract is a reference implementation of a token sale using an English-auction-style mechanism. 

**Key Features:**
- Integration with Sonar's purchase permit system
- Multi-stage sale process (PreOpen → Auction → Closed → Cancellation → Settlement → Done)
- Offchain auction clearing with onchain settlement
- Built-in refund and withdrawal mechanisms

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

