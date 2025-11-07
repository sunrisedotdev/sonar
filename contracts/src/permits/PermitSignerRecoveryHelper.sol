// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {PurchasePermit, PurchasePermitLib} from "./PurchasePermit.sol";
import {PurchasePermitWithAllocation, PurchasePermitWithAllocationLib} from "./PurchasePermitWithAllocation.sol";
import {
    PurchasePermitWithAllocationFixed6,
    PurchasePermitWithAllocationFixed6Lib
} from "./PurchasePermitWithAllocationFixed6.sol";

/// @notice A helper contract to test the signature generation on the backend
contract PermitSignerRecoveryHelper {
    function recoverSignerPurchasePermit(PurchasePermit memory permit, bytes calldata signature)
        external
        pure
        returns (address)
    {
        return PurchasePermitLib.recoverSigner(permit, signature);
    }

    function recoverSignerPurchasePermitWithAllocation(
        PurchasePermitWithAllocation memory permit,
        bytes calldata signature
    ) external pure returns (address) {
        return PurchasePermitWithAllocationLib.recoverSigner(permit, signature);
    }

    function recoverSignerPurchasePermitWithAllocationFixed6(
        PurchasePermitWithAllocationFixed6 memory permit,
        bytes calldata signature
    ) external pure returns (address) {
        return PurchasePermitWithAllocationFixed6Lib.recoverSigner(permit, signature);
    }
}
