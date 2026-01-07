export const entityAllocationDataReaderAbi = [
  {
    "type": "function",
    "name": "numEntityAllocations",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "readEntityAllocationDataAt",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IEntityAllocationDataReader.EntityAllocationData",
        "components": [
          {
            "name": "saleSpecificEntityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "acceptedAmounts",
            "type": "tuple[]",
            "internalType": "struct WalletTokenAmount[]",
            "components": [
              {
                "name": "wallet",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "token",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "amount",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "readEntityAllocationDataIn",
    "inputs": [
      {
        "name": "from",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "to",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "internalType": "struct IEntityAllocationDataReader.EntityAllocationData[]",
        "components": [
          {
            "name": "saleSpecificEntityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "acceptedAmounts",
            "type": "tuple[]",
            "internalType": "struct WalletTokenAmount[]",
            "components": [
              {
                "name": "wallet",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "token",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "amount",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          }
        ]
      }
    ],
    "stateMutability": "view"
  }
] as const;
