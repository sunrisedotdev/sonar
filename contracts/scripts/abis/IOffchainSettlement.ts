export const offchainSettlementAbi = [
  {
    "type": "function",
    "name": "finalizeSettlement",
    "inputs": [
      {
        "name": "expectedTotalAcceptedAmount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setAllocations",
    "inputs": [
      {
        "name": "allocations",
        "type": "tuple[]",
        "internalType": "struct IOffchainSettlement.Allocation[]",
        "components": [
          {
            "name": "committer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "acceptedAmount",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "allowOverwrite",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  }
] as const;
