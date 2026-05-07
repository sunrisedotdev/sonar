export const messages = {
  entityState: {
    noEntityFound:
      "No entity found. You must have an entity in Sonar with a linked wallet matching the currently connected wallet.",
    setupIncomplete: "Entity not ready to invest — Please complete the entity setup process.",
    inReview:
      "Entity not ready to invest — Please wait for the review to finish before you can make investments.",
    reviewStatus: "Entity not ready to invest — Review your entity status in Sonar.",
    technicalIssue: "There's an issue with your account — Please contact Sonar support to resolve it.",
    readyToParticipate: "Your entity is ready to participate in the sale.",
    notQualified: "Entity not qualified to invest.",
    unknown: "Unknown status",
  },
  purchaseReadiness: {
    ready: "You are ready to commit funds",
    requiresLiveness: "Complete a liveness check in order to commit funds.",
    walletRisk: "The connected wallet is not eligible for this sale. Connect a different wallet.",
    maxWalletsUsed:
      "Maximum number of wallets reached — This entity can't use the connected wallet. Use a previous wallet.",
    walletNotLinked:
      "Wallet not linked — The connected wallet is not linked to your entity. Please link it first.",
    saleNotActive: "The sale is not currently active.",
    outsideTimeWindow: "The sale is not currently accepting commitments.",
    unknown: "An unknown error occurred — Please try again or contact support.",
  },
  errors: {
    dataLoadFailed: "Failed to load your data",
    purchaseInfoFailed: "Failed to load purchase information",
    contactSupport: "Please try again or contact Sonar support.",
    unexpectedError: "An unexpected error occurred.",
    networkError: "Network error — please check your connection and try again.",
    permitFailed: "Failed to generate your purchase permit — please try again.",
    toastTitle: "Error",
  },
  contractErrors: {
    userRejected: "Transaction cancelled.",
    walletNotConnected: "No wallet connected — please connect a wallet and try again.",
    transactionExpired: "Transaction expired before it was confirmed — please try again.",
    // Keyed by Anchor IDL error name — used by parseError.ts to build the override map.
    // Unrecognised codes fall back to the IDL's own msg field.
    programErrors: {
      PermitExpired: "Your purchase permit has expired — please try again.",
      BidTooEarly: "The commitment window is not currently open.",
      BidTooLate: "The commitment window is not currently open.",
      BidBelowMinAmount: "Amount is outside the range allowed by your purchase permit.",
      BidExceedsMaxAmount: "Amount is outside the range allowed by your purchase permit.",
      PriceBelowMinPrice: "Price is outside the range allowed by your purchase permit.",
      PriceExceedsMaxPrice: "Price is outside the range allowed by your purchase permit.",
      ZeroAmount: "Amount must be greater than zero.",
      AmountCannotDecrease: "You cannot reduce an existing commitment.",
      PriceCannotDecrease: "You cannot lower the price on an existing bid.",
      BidMustHaveLockup: "This bid requires a lockup commitment.",
      BidLockupCannotBeUndone: "Lockup cannot be removed once committed.",
      EntityIdMismatch: "Wallet address mismatch — please reconnect your wallet.",
      WalletBoundToDifferentEntity: "This wallet is already registered to a different entity.",
      MaxWalletsPerEntityExceeded: "Maximum number of wallets reached for this entity.",
      InvalidStage: "This action is not permitted at the current stage of the sale.",
      SalePaused: "The sale is currently paused.",
    },
  },
  commitSection: {
    insufficientBalance: "Insufficient USDC balance",
    awaitingConfirmation: "Waiting for confirmation...",
  },
} as const;

export type Messages = typeof messages;
