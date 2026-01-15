#!/bin/bash
set -e

ABI=$(forge inspect --root ./contracts SettlementSale abi --json)
echo "export const settlementSaleAbi = ${ABI} as const;" > ./contracts/scripts/abis/SettlementSale.ts
