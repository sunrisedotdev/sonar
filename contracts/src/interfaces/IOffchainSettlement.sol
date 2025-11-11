// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

/// @title Offchain Settlement Interface
/// @notice Interface for sales that defer final allocation computation to off-chain processing
/// @dev Implementing contracts should handle the full settlement lifecycle including allocation recording and finalization
interface IOffchainSettlement {
    /// @notice Represents the final allocation of payment for a participant
    /// @param committer The address of the participant in the sale
    /// @param acceptedAmount The amount of payment accepted from this participant.
    struct Allocation {
        address committer;
        uint256 acceptedAmount;
    }

    /// @notice Records allocations for participants after off-chain computation
    /// @dev Must be called by an authorized settler role
    /// @param allocations Array of allocations to record
    /// @param allowOverwrite Whether to allow overwriting existing allocations for the same addresses
    function setAllocations(Allocation[] calldata allocations, bool allowOverwrite) external;

    /// @notice Completes the settlement process
    /// @dev Should be called after all allocations have been recorded. The total accepted amount serves as a checkpoint.
    /// @param expectedTotalAcceptedAmount Expected sum of all accepted amounts, used for validation
    function finalizeSettlement(uint256 expectedTotalAcceptedAmount) external;
}
