#!/bin/bash
set -e

ABI=$(forge inspect --root ./contracts ICommitmentDataReader abi --json)
echo "export const commitmentDataReaderAbi = ${ABI} as const;" > ./contracts/scripts/abis/ICommitmentDataReader.ts

ABI=$(forge inspect --root ./contracts IEntityAllocationDataReader abi --json)
echo "export const entityAllocationDataReaderAbi = ${ABI} as const;" > ./contracts/scripts/abis/IEntityAllocationDataReader.ts
