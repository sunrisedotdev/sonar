// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {Fixed6} from "../Fixed6.sol";
import {PurchasePermit} from "./PurchasePermit.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @notice A permit that allows a wallet to purchase a certain amount of tokens from a sale.
/// @dev Note that the amount is most commonly expressed in normalized USD units, but technically can be used for other units.
/// @dev This permits includes an amount which is reserved for the caller and a max amount that the caller can purchase. The
/// max amount could be enforced on a per-wallet or per-entity basis by the sale contract + Sonar backend.
struct PurchasePermitWithAllocationFixed6 {
    PurchasePermit permit;
    Fixed6 reservedAmount;
    Fixed6 minAmount;
    Fixed6 maxAmount;
}

library PurchasePermitWithAllocationFixed6Lib {
    function digest(PurchasePermitWithAllocationFixed6 memory permit) internal pure returns (bytes32) {
        return MessageHashUtils.toEthSignedMessageHash(abi.encode(permit));
    }

    function recoverSigner(PurchasePermitWithAllocationFixed6 memory permit, bytes calldata signature)
        internal
        pure
        returns (address)
    {
        return ECDSA.recover(digest(permit), signature);
    }
}
