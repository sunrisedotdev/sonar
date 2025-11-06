// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {PurchasePermit} from "./permits/PurchasePermit.sol";
import {PurchasePermitWithAllocation} from "./permits/PurchasePermitWithAllocation.sol";
import {PurchasePermitWithAllocationFixed6} from "./permits/PurchasePermitWithAllocationFixed6.sol";
import {PurchasePermitWithAuctionData} from "./permits/PurchasePermitWithAuctionData.sol";

/// @notice This is a helper contract solely intended to provide easy to access types in go.
interface TypesHelper {
    function purchasePermit(PurchasePermit memory permit) external pure;
    function purchasePermitWithAllocation(PurchasePermitWithAllocation memory permit) external pure;
    function purchasePermitWithAllocationFixed6(PurchasePermitWithAllocationFixed6 memory permit) external pure;
    function purchasePermitWithAuctionData(PurchasePermitWithAuctionData memory permit) external pure;
}
