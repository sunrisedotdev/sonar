// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {WalletTokenAmount} from "./types.sol";

/// @title ICommitmentDataReader
/// @notice Interface for reading current commitment data from sale contracts
/// @dev This interface is implemented by sale contracts to enable the Sonar backend to efficiently retrieve
/// the current state of all active commitments. Historical commitments that have been replaced or superseded are not accessible
/// through this interface. Implementations may allow a single entity to have one commitment (where new commitments replace
/// old ones) or multiple concurrent commitments (differentiated by commitmentID). This design allows the backend to query
/// current sale state without needing to parse individual transaction logs or maintain complex event-based
/// state reconstruction.
interface ICommitmentDataReader {
    /// @notice Structured representation of a commitment
    /// @dev This is used to represent the current state of a commitment for a specific entity.
    struct CommitmentData {
        /// Unique identifier for this commitment, used to differentiate multiple commitments from the same entity.
        bytes32 commitmentID;
        /// The Sonar sale-specific entity identifier (either a legal entity or individual) associated with this commitment.
        /// @dev Entities may be associated with multiple funding wallet addresses.
        bytes16 saleSpecificEntityID;
        /// The block timestamp when the commitment was created.
        uint64 timestamp;
        /// The price associated with the commitment in an auction-like sale.
        /// Note: This field can be unset for non-auction sales.
        uint64 price;
        /// The lockup preference of the commitment.
        /// NOTE: This field can be unset for sales that do not support lockup.
        bool lockup;
        /// Whether this commitment has been refunded.
        bool refunded;
        /// The amount of tokens by wallet that have been committed by the entity.
        /// This MAY contain tokens with zero amounts committed.
        WalletTokenAmount[] amounts;
        /// Reserved for future extensions; empty by default but allows for additional data without breaking the interface
        bytes extraData;
    }

    /// @notice Returns the total number of current bids in the auction
    /// @dev This count represents the number of active bids that have not been superseded or replaced, not the
    /// total number of bid transactions. Depending on the implementation, this may equal the number of unique
    /// committers (if each committer can only have one bid) or may be higher (if committers can have multiple
    /// concurrent bids). This method is used in conjunction with readCommitmentDataIn to paginate through all current commitments.
    function numCommitments() external view returns (uint256);

    /// @notice Reads the commitment data for a single commitment by index
    /// @dev Returns the current commitment data at the specified index. The index must be less than numCommitments().
    /// @param index The 0-based index of the commitment
    function readCommitmentDataAt(uint256 index) external view returns (CommitmentData memory);

    /// @notice Reads a range of current commitment data entries
    /// @dev This method enables efficient pagination of all current commitments for backend indexing.
    /// Only current active commitments are returned; commitments that have been superseded or replaced are not included.
    /// Each returned commitment has a unique commitmentID that can be used to track it across queries. The Sonar backend
    /// typically calls this in chunks (a few thousand entries at a time) to avoid hitting RPC response size
    /// limits. The range is inclusive of `from` and exclusive of `to`.
    /// @param from The starting index (inclusive, 0-based)
    /// @param to The ending index (exclusive)
    function readCommitmentDataIn(uint256 from, uint256 to) external view returns (CommitmentData[] memory);
}
