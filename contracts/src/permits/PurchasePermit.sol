// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @notice A permit that allows a wallet to purchase a tokens in a sale.
struct PurchasePermit {
    bytes16 entityID;
    bytes16 saleUUID;
    address wallet;
    uint64 expiresAt;
    bytes payload; // Generic extra data field for future use.
}

library PurchasePermitLib {
    function digest(PurchasePermit memory permit) internal pure returns (bytes32) {
        return MessageHashUtils.toEthSignedMessageHash(abi.encode(permit));
    }

    function recoverSigner(PurchasePermit memory permit, bytes calldata signature) internal pure returns (address) {
        return ECDSA.recover(digest(permit), signature);
    }
}
