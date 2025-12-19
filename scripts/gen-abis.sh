#!/bin/bash
set -e

ABI=$(forge inspect --root ./contracts IAuctionBidDataReader abi --json)
echo "export const auctionBidDataReaderAbi = ${ABI} as const;" > ./contracts/scripts/abis/IAuctionBidDataReader.ts
