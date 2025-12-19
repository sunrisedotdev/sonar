#!/bin/bash
set -e

ABI=$(forge inspect --root ./contracts ICommitmentDataReader abi --json)
echo "export const commitmentDataReaderAbi = ${ABI} as const;" > ./contracts/scripts/abis/ICommitmentDataReader.ts

ABI=$(forge inspect --root ./contracts IEntityAllocationDataReader abi --json)
echo "export const entityAllocationDataReaderAbi = ${ABI} as const;" > ./contracts/scripts/abis/IEntityAllocationDataReader.ts

ABI=$(forge inspect --root ./contracts IOffchainSettlement abi --json)
echo "export const offchainSettlementAbi = ${ABI} as const;" > ./contracts/scripts/abis/IOffchainSettlement.ts

ABI=$(forge inspect --root ./contracts ITotalCommitmentsReader abi --json)
echo "export const totalCommitmentsReaderAbi = ${ABI} as const;" > ./contracts/scripts/abis/ITotalCommitmentsReader.ts

ABI=$(forge inspect --root ./contracts ITotalAllocationsReader abi --json)
echo "export const totalAllocationsReaderAbi = ${ABI} as const;" > ./contracts/scripts/abis/ITotalAllocationsReader.ts
