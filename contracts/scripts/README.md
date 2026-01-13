# Contract Scripts

TypeScript scripts for managing allocations and processing refunds on the Gensyn sale contract.

## Prerequisites

- Node.js 18+
- pnpm

Install dependencies:

```bash
pnpm install
```

## Workflow

The typical flow for setting allocations and processing refunds after a sale.
See the script sections below for detailed options.

1. **Export commitments** from the contract:

    ```bash
    pnpm commitments-data-csv --sale-address 0x... --rpc-url https://... --output-csv bids.csv
    ```

2. **Prepare allocations** by creating a CSV with accepted amounts for each unique entity, wallet and payment token

3. **Validate** your allocations CSV (dry run):

    ```bash
    pnpm set-allocations \
      --allocations-csv allocations.csv \
      --sale-address 0x... \
      --rpc-url https://... \
      --dry-run true
    ```

4. **Submit** transactions once validation passes:

    ```bash
    PRIVATE_KEY=0x... pnpm set-allocations \
      --allocations-csv allocations.csv \
      --sale-address 0x... \
      --rpc-url https://... \
      --dry-run false
    ```

5. **Process refunds** after all allocations are set:
    ```bash
    PRIVATE_KEY=0x... pnpm process-refunds \
      --sale-address 0x... \
      --rpc-url https://... \
      --dry-run false
    ```

## Scripts

### Export Commitment Data (`commitment-data-csv`)

Exports all committer data from the sale contract to CSV format. This is useful for analyzing bids and preparing allocation files.

```bash
pnpm commitment-data-csv \
  --sale-address 0x... \
  --rpc-url https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY \
  --output-csv bids.csv
```

**Options:**

| Option           | Required | Default | Description              |
| ---------------- | -------- | ------- | ------------------------ |
| `--sale-address` | Yes      | -       | Sale contract address    |
| `--rpc-url`      | Yes      | -       | Ethereum RPC URL         |
| `--output-csv`   | No       | stdout  | Path to write CSV output |

**Output columns:**

- `SALE_SPECIFIC_ENTITY_ID` - sale-specific entity identifier
- `COMMITMENT_ID` - unique id for this commitment
- `WALLET` - wallet address
- `TOKEN` - payment token address
- `TIMESTAMP` - commitment timestamp
- `PRICE` - commitment price
- `COMMITTED_AMOUNT` - committed amount for this wallet and token
- `ACCEPTED_AMOUNT` - accepted amount for this wallet and token
- `REFUNDED` - whether the commitment was refunded
- `EXTRA_DATA` - extra data for this commitment

### Set Allocations (`set-allocations`)

Sets accepted allocations on the sale contract from a CSV file. Includes validation and dry-run mode for safety.

The script automatically skips allocations where the contract already has the correct accepted amount, reducing unnecessary transactions.
To modify an existing allocation (change its accepted amount), you must pass `--allow-overwrites true`. Without this flag, the script will fail if it tries to set an allocation that already exists.

```bash
pnpm set-allocations \
  --allocations-csv allocations.csv \
  --sale-address 0x... \
  --rpc-url https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY \
  --dry-run true
```

**Options:**

| Option                     | Required | Default | Description                                 |
| -------------------------- | -------- | ------- | ------------------------------------------- |
| `--allocations-csv`        | Yes      | -       | Path to CSV file with allocations           |
| `--sale-address`           | Yes      | -       | Sale contract address                       |
| `--rpc-url`                | Yes      | -       | Ethereum RPC URL                            |
| `--payment-token-decimals` | No       | 6       | Token decimals (USDC = 6)                   |
| `--allow-overwrites`       | No       | false   | Allow overwriting existing allocations      |
| `--dry-run`                | No       | true    | Validate without submitting transactions    |
| `--batch-size`             | No       | 200     | Number of allocations per transaction batch |

**CSV format:**

```csv
SALE_SPECIFIC_ENTITY_ID,WALLET,TOKEN,ACCEPTED_AMOUNT
0x1234567890abcdef1234567890abcdef12345678,0x1234567890abcdef1234567890abcdef12345678,0x1234567890abcdef1234567890abcdef12345678,1000000
0xabcdefabcdefabcdefabcdefabcdefabcdefabcd,0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd,0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd,500000
```

The header row is optional. Amounts should be in the token's smallest unit (for example, 1 USDC = 1000000 with 6 decimals). Acceptance amounts should not be zero.

### Process Refunds (`process-refunds`)

Processes refunds for all entities who have unrefunded balances. This should be run after all allocations have been set. The script refunds the difference between each entity's committed amount and their accepted amount.

The script automatically skips entities who have already been refunded.

```bash
pnpm process-refunds \
  --sale-address 0x... \
  --rpc-url https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY \
  --dry-run true
```

**Options:**

| Option                     | Required | Default | Description                              |
| -------------------------- | -------- | ------- | ---------------------------------------- |
| `--sale-address`           | Yes      | -       | Sale contract address                    |
| `--rpc-url`                | Yes      | -       | Ethereum RPC URL                         |
| `--payment-token-decimals` | No       | 6       | Token decimals (USDC = 6)                |
| `--dry-run`                | No       | true    | Validate without submitting transactions |
| `--batch-size`             | No       | 200     | Number of entities per transaction batch |

## Environment Variables

| Variable      | Required               | Description                                                                                                                                            |
| ------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `PRIVATE_KEY` | When `--dry-run false` | Private key for signing transactions. Must be the key of an account with permission to call `setAllocations` or `processRefunds` on the sale contract. |

The private key can be provided with or without the `0x` prefix.

## Testing

```bash
pnpm test
```
