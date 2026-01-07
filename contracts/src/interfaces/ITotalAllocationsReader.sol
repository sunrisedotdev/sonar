// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {TokenAmount} from "./types.sol";

/// @title ITotalAllocationsReader
/// @notice Interface for reading total accepted (allocated) token amounts across all participants in a sale.
/// @dev This interface is not strictly necessary for core sale functionality, but provides
/// a convenient way to query total allocations for sanity checks in scripts and monitoring tools.
///
/// In multi-token sales (e.g., accepting both USDC and USDT), this returns the breakdown
/// of total accepted amounts for each payment token separately.
interface ITotalAllocationsReader {
    /// @notice Returns the total accepted amount for each payment token across all participants.
    /// @dev The returned amounts represent allocations that have been accepted by the sale.
    /// These may differ from committed amounts if not all commitments are accepted.
    /// @return TokenAmounts An array of TokenAmount structs, one for each payment token, containing
    /// the token address and the total amount accepted in that token.
    function totalAcceptedAmountByToken() external view returns (TokenAmount[] memory);
}
