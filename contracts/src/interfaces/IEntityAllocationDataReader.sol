// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {WalletTokenAmount} from "./types.sol";

/// @title IEntityAllocationDataReader
/// @notice Interface for reading entity allocation data from sale contracts after settlement
/// @dev This interface is implemented by sale contracts to enable the Sonar backend to efficiently retrieve
/// the final allocation state for all entities. Entity allocations represent the accepted amounts per wallet
/// after the settlement process has determined final allocations. This design allows the backend to query
/// settlement results without needing to parse individual transaction logs or maintain complex event-based
/// state reconstruction.
interface IEntityAllocationDataReader {
    /// @notice Structured representation of an entity's allocation data
    /// @dev This is used to represent the final accepted amounts for a specific entity after settlement.
    struct EntityAllocationData {
        /// The Sonar sale-specific entity identifier (either a legal entity or individual) associated with this allocation.
        /// @dev Entities may be associated with multiple funding wallet addresses.
        bytes16 saleSpecificEntityID;
        /// The accepted token amounts by wallet for this entity.
        /// MAY contain wallets and tokens with zero amounts accepted.
        WalletTokenAmount[] acceptedAmounts;
    }

    /// @notice Returns the total number of entity allocations in the sale.
    /// @dev This is intended to be used as bound to iterate through all entity allocations in the sale
    /// using `readEntityAllocationDataAt` or `readEntityAllocationDataIn`.
    /// Entities with zero accepted amounts MAY be included.
    function numEntityAllocations() external view returns (uint256);

    /// @notice Reads the allocation data for a single entity by index
    /// @dev Returns the entity allocation data at the specified index. The index must be less than numEntityAllocations().
    /// @param index The 0-based index of the entity allocation
    function readEntityAllocationDataAt(uint256 index) external view returns (EntityAllocationData memory);

    /// @notice Reads a range of entity allocation data entries
    /// @dev This method enables efficient pagination of all entity allocations for backend indexing.
    /// The Sonar backend typically calls this in chunks (a few thousand entries at a time) to avoid hitting
    /// RPC response size limits. The range is inclusive of `from` and exclusive of `to`.
    /// @param from The starting index (inclusive, 0-based)
    /// @param to The ending index (exclusive)
    function readEntityAllocationDataIn(uint256 from, uint256 to) external view returns (EntityAllocationData[] memory);
}
