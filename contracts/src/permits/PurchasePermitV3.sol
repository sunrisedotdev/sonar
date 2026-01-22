// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @notice A permit that allows a wallet to purchase (or commit to purchase) tokens in a sale.
/// @dev This permit includes minimum and maximum amounts of payment token that can be spent/committed/bid.
/// These limits can be per-wallet or per-entity depending on the implementation of the sale contract.
/// If the wallet or entity has no limits, then the fields will be set to 0 or MAX_UINT256 respectively.
/// This permit also includes minimum and maximum prices per token, which can be useful for auction sales.
/// For sales with a fixed price, the minimum and maximum prices will be set to the same value.
///
/// The permit contains a time window during which the permit is valid for commitments.
/// The window is [opensAt, closesAt) - opensAt is inclusive, closesAt is exclusive.
/// This enables use cases like automatic commitment opening or closing at a specific time,
/// or staggered access windows for different user tiers.
///
/// The above constraints SHOULD be enforced by the sale contract.
struct PurchasePermitV3 {
    bytes16 saleSpecificEntityID;
    bytes16 saleUUID;
    address wallet;
    uint64 expiresAt;
    uint256 minAmount;
    uint256 maxAmount;
    uint64 minPrice;
    uint64 maxPrice;
    uint64 opensAt;
    uint64 closesAt;
    bytes payload; // Generic extra data field for future use.
}

library PurchasePermitV3Lib {
    function digest(PurchasePermitV3 memory permit) internal pure returns (bytes32) {
        return MessageHashUtils.toEthSignedMessageHash(abi.encode(permit));
    }

    function recoverSigner(PurchasePermitV3 memory permit, bytes calldata signature) internal pure returns (address) {
        return ECDSA.recover(digest(permit), signature);
    }
}
