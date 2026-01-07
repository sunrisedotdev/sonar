export const commitmentDataReaderAbi = [
  {
    "type": "function",
    "name": "numCommitments",
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
    "name": "readCommitmentDataAt",
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
        "internalType": "struct ICommitmentDataReader.CommitmentData",
        "components": [
          {
            "name": "commitmentID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "saleSpecificEntityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "timestamp",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "price",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "lockup",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "refunded",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "amounts",
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
          },
          {
            "name": "extraData",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "readCommitmentDataIn",
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
        "internalType": "struct ICommitmentDataReader.CommitmentData[]",
        "components": [
          {
            "name": "commitmentID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "saleSpecificEntityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "timestamp",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "price",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "lockup",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "refunded",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "amounts",
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
          },
          {
            "name": "extraData",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      }
    ],
    "stateMutability": "view"
  }
] as const;
