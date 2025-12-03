// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

/// @title IAuctionBidDataReader
/// @notice Interface for reading current auction bid data from sale contracts
/// @dev This interface is implemented by auction contracts to enable the Sonar backend to efficiently retrieve
/// the current state of all active bids. Historical bids that have been replaced or superseded are not accessible
/// through this interface. Implementations may allow a single committer to have one bid (where new bids replace
/// old ones) or multiple concurrent bids (differentiated by bidID). This design allows the backend to query
/// current auction state without needing to parse individual transaction logs or maintain complex event-based
/// state reconstruction.
interface IAuctionBidDataReader {
    /// @notice Structured representation of a bid
    struct BidData {
        /// Unique identifier for this bid, used to differentiate multiple bids from the same committer
        bytes32 bidID;
        /// The wallet address that placed the bid.
        address committer;
        /// The Sonar entity identifier (either a legal entity or individual) associated with this committer.
        /// @dev Entities may be associated with multiple committer addresses.
        bytes16 saleSpecificEntityID;
        /// The block timestamp when the bid was placed
        uint64 timestamp;
        /// The bid price in the auction's price tick units
        uint64 price;
        /// The total commitment amount in the payment token's base units
        uint256 amount;
        /// Whether this bid has been refunded
        bool refunded;
        /// Reserved for future extensions; empty by default but allows for additional data without breaking the interface
        bytes extraData;
    }

    /// @notice Returns the total number of current bids in the auction
    /// @dev This count represents the number of active bids that have not been superseded or replaced, not the
    /// total number of bid transactions. Depending on the implementation, this may equal the number of unique
    /// committers (if each committer can only have one bid) or may be higher (if committers can have multiple
    /// concurrent bids). This method is used in conjunction with readBidDataIn to paginate through all current bids.
    function numBids() external view returns (uint256);

    /// @notice Reads the bid data for a single bid by index
    /// @dev Returns the current bid data at the specified index. The index must be less than numBids().
    /// @param index The 0-based index of the bid
    function readBidDataAt(uint256 index) external view returns (BidData memory);

    /// @notice Reads a range of current bid data entries
    /// @dev This method enables efficient pagination of all current auction bids for backend indexing.
    /// Only current active bids are returned; bids that have been superseded or replaced are not included.
    /// Each returned bid has a unique bidID that can be used to track it across queries. The Sonar backend
    /// typically calls this in chunks (a few thousand entries at a time) to avoid hitting RPC response size
    /// limits. The range is inclusive of `from` and exclusive of `to`.
    /// @param from The starting index (inclusive, 0-based)
    /// @param to The ending index (exclusive)
    function readBidDataIn(uint256 from, uint256 to) external view returns (BidData[] memory);
}
