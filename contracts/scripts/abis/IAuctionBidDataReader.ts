export const auctionBidDataReaderAbi = [
  {
    "type": "function",
    "name": "numBids",
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
    "name": "readBidDataAt",
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
        "internalType": "struct IAuctionBidDataReader.BidData",
        "components": [
          {
            "name": "bidID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "committer",
            "type": "address",
            "internalType": "address"
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
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "refunded",
            "type": "bool",
            "internalType": "bool"
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
    "name": "readBidDataIn",
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
        "internalType": "struct IAuctionBidDataReader.BidData[]",
        "components": [
          {
            "name": "bidID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "committer",
            "type": "address",
            "internalType": "address"
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
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "refunded",
            "type": "bool",
            "internalType": "bool"
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
