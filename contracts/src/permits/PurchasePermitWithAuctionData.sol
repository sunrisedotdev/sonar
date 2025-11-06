// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {PurchasePermit} from "./PurchasePermit.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @notice A permit that allows a wallet to place bids in an auction sale.
/// @dev This permit includes minimum and maximum amounts of payment token that can be bid, as well as minimum and maximum
/// prices per token. These constraints are enforced by the sale contract to ensure bids fall within the permitted ranges.
struct PurchasePermitWithAuctionData {
    PurchasePermit permit;
    uint256 minAmount;
    uint256 maxAmount;
    uint64 minPrice;
    uint64 maxPrice;
}

library PurchasePermitWithAuctionDataLib {
    function digest(PurchasePermitWithAuctionData memory permit) internal pure returns (bytes32) {
        return MessageHashUtils.toEthSignedMessageHash(abi.encode(permit));
    }

    function recoverSigner(PurchasePermitWithAuctionData memory permit, bytes calldata signature)
        internal
        pure
        returns (address)
    {
        return ECDSA.recover(digest(permit), signature);
    }
}
