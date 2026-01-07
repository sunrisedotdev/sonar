// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {TokenAmount} from "./types.sol";

/// @title ITotalCommitmentsReader
/// @notice Interface for reading total committed amounts across all participants in a sale.
/// @dev This interface is not strictly necessary for core sale functionality, but provides
/// a convenient way to query total commitments for sanity checks in scripts and monitoring tools.
///
/// In multi-token sales (e.g., accepting both USDC and USDT), this returns the breakdown
/// of total committed amounts for each payment token separately.
interface ITotalCommitmentsReader {
    /// @notice Returns the total committed amount for each payment token across all participants.
    /// @dev The returned amounts are monotonically increasing during the auction stage.
    /// They do not decrease on refunds or cancellations.
    /// @return TokenAmounts An array of TokenAmount structs, one for each payment token, containing
    /// the token address and the total amount committed in that token.
    function totalCommittedAmountByToken() external view returns (TokenAmount[] memory);
}
