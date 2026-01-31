export const settlementSaleAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "PAUSER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "PURCHASE_PERMIT_SIGNER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "REFUNDER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "SALE_MANAGER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "SETTLEMENT_FINALIZER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "SETTLER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "TOKEN_RECOVERER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "cancelBid",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimRefund",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimRefundEnabled",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "closeCommitment",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "entitiesIn",
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
        "type": "bytes16[]",
        "internalType": "bytes16[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "entityAt",
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
        "type": "bytes16",
        "internalType": "bytes16"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "entityStateByID",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "internalType": "bytes16"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct SettlementSale.EntityStateView",
        "components": [
          {
            "name": "entityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "bidTimestamp",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "cancelled",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "refunded",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "currentBid",
            "type": "tuple",
            "internalType": "struct SettlementSale.Bid",
            "components": [
              {
                "name": "lockup",
                "type": "bool",
                "internalType": "bool"
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
              }
            ]
          },
          {
            "name": "walletStates",
            "type": "tuple[]",
            "internalType": "struct SettlementSale.WalletStateView[]",
            "components": [
              {
                "name": "addr",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "entityID",
                "type": "bytes16",
                "internalType": "bytes16"
              },
              {
                "name": "acceptedAmountByToken",
                "type": "tuple[]",
                "internalType": "struct TokenAmount[]",
                "components": [
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
                "name": "committedAmountByToken",
                "type": "tuple[]",
                "internalType": "struct TokenAmount[]",
                "components": [
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
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "entityStatesByIDs",
    "inputs": [
      {
        "name": "entityIDs",
        "type": "bytes16[]",
        "internalType": "bytes16[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "internalType": "struct SettlementSale.EntityStateView[]",
        "components": [
          {
            "name": "entityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "bidTimestamp",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "cancelled",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "refunded",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "currentBid",
            "type": "tuple",
            "internalType": "struct SettlementSale.Bid",
            "components": [
              {
                "name": "lockup",
                "type": "bool",
                "internalType": "bool"
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
              }
            ]
          },
          {
            "name": "walletStates",
            "type": "tuple[]",
            "internalType": "struct SettlementSale.WalletStateView[]",
            "components": [
              {
                "name": "addr",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "entityID",
                "type": "bytes16",
                "internalType": "bytes16"
              },
              {
                "name": "acceptedAmountByToken",
                "type": "tuple[]",
                "internalType": "struct TokenAmount[]",
                "components": [
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
                "name": "committedAmountByToken",
                "type": "tuple[]",
                "internalType": "struct TokenAmount[]",
                "components": [
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
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "entityStatesIn",
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
        "internalType": "struct SettlementSale.EntityStateView[]",
        "components": [
          {
            "name": "entityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "bidTimestamp",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "cancelled",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "refunded",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "currentBid",
            "type": "tuple",
            "internalType": "struct SettlementSale.Bid",
            "components": [
              {
                "name": "lockup",
                "type": "bool",
                "internalType": "bool"
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
              }
            ]
          },
          {
            "name": "walletStates",
            "type": "tuple[]",
            "internalType": "struct SettlementSale.WalletStateView[]",
            "components": [
              {
                "name": "addr",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "entityID",
                "type": "bytes16",
                "internalType": "bytes16"
              },
              {
                "name": "acceptedAmountByToken",
                "type": "tuple[]",
                "internalType": "struct TokenAmount[]",
                "components": [
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
                "name": "committedAmountByToken",
                "type": "tuple[]",
                "internalType": "struct TokenAmount[]",
                "components": [
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
        ]
      }
    ],
    "stateMutability": "view"
  },
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
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRoleMember",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRoleMemberCount",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
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
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "init",
        "type": "tuple",
        "internalType": "struct SettlementSale.Init",
        "components": [
          {
            "name": "saleUUID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "admin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "extraManagers",
            "type": "address[]",
            "internalType": "address[]"
          },
          {
            "name": "extraPausers",
            "type": "address[]",
            "internalType": "address[]"
          },
          {
            "name": "extraSettler",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "extraRefunder",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "purchasePermitSigner",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "proceedsReceiver",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "claimRefundEnabled",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "maxWalletsPerEntity",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "paymentTokens",
            "type": "address[]",
            "internalType": "contract IERC20Metadata[]"
          },
          {
            "name": "expectedPaymentTokenDecimals",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "maxWalletsPerEntity",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "stateMutability": "view"
  },
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
    "name": "numEntities",
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
    "name": "openCancellation",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "openCommitment",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "openSettlement",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "pause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "paymentTokens",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address[]",
        "internalType": "contract IERC20[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "proceedsReceiver",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "processRefunds",
    "inputs": [
      {
        "name": "entityIDs",
        "type": "bytes16[]",
        "internalType": "bytes16[]"
      },
      {
        "name": "skipAlreadyRefunded",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
  },
  {
    "type": "function",
    "name": "recoverTokens",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "contract IERC20"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "callerConfirmation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "replaceBidWithApproval",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "contract IERC20"
      },
      {
        "name": "bid",
        "type": "tuple",
        "internalType": "struct SettlementSale.Bid",
        "components": [
          {
            "name": "lockup",
            "type": "bool",
            "internalType": "bool"
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
          }
        ]
      },
      {
        "name": "purchasePermit",
        "type": "tuple",
        "internalType": "struct PurchasePermitV3",
        "components": [
          {
            "name": "saleSpecificEntityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "saleUUID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "wallet",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "expiresAt",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "minAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minPrice",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "maxPrice",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "opensAt",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "closesAt",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "payload",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      },
      {
        "name": "purchasePermitSignature",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "replaceBidWithPermit",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "contract IERC20"
      },
      {
        "name": "bid",
        "type": "tuple",
        "internalType": "struct SettlementSale.Bid",
        "components": [
          {
            "name": "lockup",
            "type": "bool",
            "internalType": "bool"
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
          }
        ]
      },
      {
        "name": "purchasePermit",
        "type": "tuple",
        "internalType": "struct PurchasePermitV3",
        "components": [
          {
            "name": "saleSpecificEntityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "saleUUID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "wallet",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "expiresAt",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "minAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minPrice",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "maxPrice",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "opensAt",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "closesAt",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "payload",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      },
      {
        "name": "purchasePermitSignature",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "erc20PermitDeadline",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "erc20PermitSignature",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "saleUUID",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes16",
        "internalType": "bytes16"
      }
    ],
    "stateMutability": "view"
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
            "name": "saleSpecificEntityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
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
  },
  {
    "type": "function",
    "name": "setClaimRefundEnabled",
    "inputs": [
      {
        "name": "enabled",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxWalletsPerEntity",
    "inputs": [
      {
        "name": "max",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setPaused",
    "inputs": [
      {
        "name": "isPaused",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setProceedsReceiver",
    "inputs": [
      {
        "name": "newProceedsReceiver",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "stage",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "enum SettlementSale.Stage"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalAcceptedAmount",
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
    "name": "totalAcceptedAmountByToken",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "internalType": "struct TokenAmount[]",
        "components": [
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
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalCommittedAmount",
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
    "name": "totalCommittedAmountByToken",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "internalType": "struct TokenAmount[]",
        "components": [
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
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalRefundedAmount",
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
    "name": "totalRefundedAmountByToken",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "internalType": "struct TokenAmount[]",
        "components": [
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
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "unsafeSetStage",
    "inputs": [
      {
        "name": "newStage",
        "type": "uint8",
        "internalType": "enum SettlementSale.Stage"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "version",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "walletStateByAddress",
    "inputs": [
      {
        "name": "addr",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct SettlementSale.WalletStateView",
        "components": [
          {
            "name": "addr",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "entityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "acceptedAmountByToken",
            "type": "tuple[]",
            "internalType": "struct TokenAmount[]",
            "components": [
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
            "name": "committedAmountByToken",
            "type": "tuple[]",
            "internalType": "struct TokenAmount[]",
            "components": [
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
    "name": "walletStatesByAddresses",
    "inputs": [
      {
        "name": "addrs",
        "type": "address[]",
        "internalType": "address[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "internalType": "struct SettlementSale.WalletStateView[]",
        "components": [
          {
            "name": "addr",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "entityID",
            "type": "bytes16",
            "internalType": "bytes16"
          },
          {
            "name": "acceptedAmountByToken",
            "type": "tuple[]",
            "internalType": "struct TokenAmount[]",
            "components": [
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
            "name": "committedAmountByToken",
            "type": "tuple[]",
            "internalType": "struct TokenAmount[]",
            "components": [
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
    "name": "withdraw",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "withdrawPartial",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "contract IERC20"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "withdrawnAmount",
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
    "name": "withdrawnAmountByToken",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "internalType": "struct TokenAmount[]",
        "components": [
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
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "AllocationSet",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "indexed": true,
        "internalType": "bytes16"
      },
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "token",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "acceptedAmount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "BidCancelled",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "indexed": true,
        "internalType": "bytes16"
      },
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "BidPlaced",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "indexed": true,
        "internalType": "bytes16"
      },
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "bid",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct SettlementSale.Bid",
        "components": [
          {
            "name": "lockup",
            "type": "bool",
            "internalType": "bool"
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
          }
        ]
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ClaimRefundEnabledChanged",
    "inputs": [
      {
        "name": "enabled",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "EntityInitialized",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "indexed": true,
        "internalType": "bytes16"
      },
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "EntityRefunded",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "indexed": true,
        "internalType": "bytes16"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxWalletsPerEntityChanged",
    "inputs": [
      {
        "name": "previousMax",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "newMax",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PausedStateChanged",
    "inputs": [
      {
        "name": "paused",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProceedsReceiverChanged",
    "inputs": [
      {
        "name": "previousReceiver",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newReceiver",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProceedsWithdrawn",
    "inputs": [
      {
        "name": "receiver",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "token",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RefundedEntitySkipped",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "indexed": true,
        "internalType": "bytes16"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "StageChanged",
    "inputs": [
      {
        "name": "previousStage",
        "type": "uint8",
        "indexed": true,
        "internalType": "enum SettlementSale.Stage"
      },
      {
        "name": "newStage",
        "type": "uint8",
        "indexed": true,
        "internalType": "enum SettlementSale.Stage"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TokensRecovered",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "to",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "WalletInitialized",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "indexed": true,
        "internalType": "bytes16"
      },
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "WalletRefunded",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "indexed": true,
        "internalType": "bytes16"
      },
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "token",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AccessControlBadConfirmation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AccessControlUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "neededRole",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "AddressEmptyCode",
    "inputs": [
      {
        "name": "target",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "AddressInsufficientBalance",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "AllocationAlreadySet",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "internalType": "bytes16"
      },
      {
        "name": "acceptedAmount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "AllocationExceedsCommitment",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "internalType": "bytes16"
      },
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
        "name": "allocation",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "commitment",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "AlreadyRefunded",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "internalType": "bytes16"
      }
    ]
  },
  {
    "type": "error",
    "name": "BidAlreadyCancelled",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "internalType": "bytes16"
      }
    ]
  },
  {
    "type": "error",
    "name": "BidAmountCannotBeLowered",
    "inputs": [
      {
        "name": "got",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "want",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "BidBelowMinAmount",
    "inputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "min",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "BidExceedsMaxAmount",
    "inputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "max",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "BidLockupCannotBeUndone",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BidMustHaveLockup",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BidOutsideAllowedWindow",
    "inputs": [
      {
        "name": "opensAt",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "closesAt",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "currentTime",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "BidPriceBelowMinPrice",
    "inputs": [
      {
        "name": "price",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "min",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "BidPriceCannotBeLowered",
    "inputs": [
      {
        "name": "got",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "want",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "BidPriceExceedsMaxPrice",
    "inputs": [
      {
        "name": "price",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "max",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "ClaimRefundDisabled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DuplicatePaymentToken",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignature",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignatureLength",
    "inputs": [
      {
        "name": "length",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignatureS",
    "inputs": [
      {
        "name": "s",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "EntityNotInitialized",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "internalType": "bytes16"
      }
    ]
  },
  {
    "type": "error",
    "name": "FailedInnerCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidPaymentToken",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "InvalidPaymentTokenDecimals",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "got",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "want",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "InvalidSaleUUID",
    "inputs": [
      {
        "name": "got",
        "type": "bytes16",
        "internalType": "bytes16"
      },
      {
        "name": "want",
        "type": "bytes16",
        "internalType": "bytes16"
      }
    ]
  },
  {
    "type": "error",
    "name": "InvalidSender",
    "inputs": [
      {
        "name": "got",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "want",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "InvalidStage",
    "inputs": [
      {
        "name": "got",
        "type": "uint8",
        "internalType": "enum SettlementSale.Stage"
      },
      {
        "name": "want",
        "type": "uint8[]",
        "internalType": "enum SettlementSale.Stage[]"
      }
    ]
  },
  {
    "type": "error",
    "name": "MaxWalletsPerEntityExceeded",
    "inputs": [
      {
        "name": "entityID",
        "type": "bytes16",
        "internalType": "bytes16"
      },
      {
        "name": "count",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "max",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "NoPaymentTokens",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "PurchasePermitExpired",
    "inputs": [
      {
        "name": "expiresAt",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "currentTime",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "SafeERC20FailedOperation",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "SalePaused",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UnauthorizedSigner",
    "inputs": [
      {
        "name": "signer",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "UnexpectedTotalAcceptedAmount",
    "inputs": [
      {
        "name": "got",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "want",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "WalletNotAssociatedWithEntity",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "entityID",
        "type": "bytes16",
        "internalType": "bytes16"
      }
    ]
  },
  {
    "type": "error",
    "name": "WalletNotInitialized",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "WalletTiedToAnotherEntity",
    "inputs": [
      {
        "name": "got",
        "type": "bytes16",
        "internalType": "bytes16"
      },
      {
        "name": "want",
        "type": "bytes16",
        "internalType": "bytes16"
      },
      {
        "name": "wallet",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "WithdrawalExceedsAvailable",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "requested",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "available",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroAmount",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroEntityID",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroMaxWalletsPerEntity",
    "inputs": []
  }
] as const;
