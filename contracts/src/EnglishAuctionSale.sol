// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {
    PurchasePermitWithAuctionData,
    PurchasePermitWithAuctionDataLib
} from "./permits/PurchasePermitWithAuctionData.sol";

import {IAuctionBidDataReader} from "./interfaces/IAuctionBidData.sol";
import {IOffchainSettlement} from "./interfaces/IOffchainSettlement.sol";

/// @title  EnglishAuctionSale
/// @notice Public sale contract for a token offering with an English-auction-style mechanism.
///
/// @dev
/// This contract raises funds in `paymentToken` through a competitive English auction.
/// The contract acts as an escrow that records bids, enforces limits, and handles refunds and withdrawals.
/// Auction mechanics (clearing price determination and token allocations) are computed offchain, with final results recorded onchain during settlement.
///
/// # Sale Stages
///
/// The sale progresses through the following stages:
///
/// 1. **PreOpen**: Initial state, no commitments allowed
/// 2. **Auction**: Users submit bids with price and amount
/// 3. **Closed**: Auction automatically closes at a specified timestamp
/// 4. **Cancellation**: Committers can cancel their bids and receive refunds
/// 5. **Settlement**: Final allocations computed offchain are recorded onchain
/// 6. **Done**: Refunds processed and proceeds withdrawn
///
/// ## Auction Phase
///
/// Users with valid purchase permits (issued by Sonar) can participate by submitting bids specifying price and amount.
/// Each new bid replaces the previous bid for the same committer.
/// Bids must satisfy monotonic constraints: amounts and prices can only increase.
///
/// Total commitment per committer cannot exceed the maximum amount specified in their purchase permit.
/// Bid prices must fall within the minimum and maximum price bounds specified in the purchase permit.
/// These price bounds are determined offchain and can change dynamically.
/// The auction automatically closes at a specified timestamp, though admins can manually override if needed.
///
/// ## Cancellation Phase
///
/// After the auction closes, preliminary allocations are computed offchain and communicated to committers.
/// During this phase, committers can cancel their bids at any time, which triggers an immediate refund of their committed amount.
///
/// ## Settlement Process
///
/// Final allocations are computed offchain based on the project's requirements.
/// The settler role records non-zero allocations onchain via the settlement function.
///
/// ## Refund and Withdrawal
///
/// Refunds equal the difference between a committer's total commitment and their accepted allocation amount.
/// Refunds can be triggered by committers themselves or by addresses with the refunder role.
/// The total accepted amount (proceeds) is withdrawn to the proceeds receiver.
///
/// # Token Distribution
///
/// The distribution of purchased tokens is handled separately by the project team and is outside the scope of this contract.
///
/// # Technical Notes
///
/// All prices are denominated in the auction's price tick units, as defined by the project.
/// Minimum/maximum bid prices and maximum bid amounts are specified offchain and passed to the contract via purchase permits.
///
/// The `entityID` refers to an entity in the Sonar system, which can be either a legal entity or an individual.
/// A committer is a wallet address used to commit funds to the sale.
/// An entity can have multiple committers, but each committer is associated with exactly one entity.
///
/// With the exception of the emergency recovery mechanism, tokens can only be:
/// - transferred to the contract as part of a bid
/// - fully returned to the committer, or
/// - partially returned to the committer, with the remainder withdrawable by the proceeds receiver
///
/// @custom:security-contact security@echo.xyz
contract EnglishAuctionSale is AccessControlEnumerable, IAuctionBidDataReader, IOffchainSettlement {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The role allowed to recover tokens from the contract.
    /// @dev This is not intended to be granted by default, but will be granted manually by the DEFAULT_ADMIN_ROLE if needed.
    bytes32 public constant TOKEN_RECOVERER_ROLE = keccak256("TOKEN_RECOVERER_ROLE");

    /// @notice The role allowed to sign purchase permits.
    bytes32 public constant PURCHASE_PERMIT_SIGNER_ROLE = keccak256("PURCHASE_PERMIT_SIGNER_ROLE");

    /// @notice The role allowed to set the manual stage and stage related parameters.
    bytes32 public constant SALE_MANAGER_ROLE = keccak256("SALE_MANAGER_ROLE");

    /// @notice The role allowed to set allocations for auction clearing.
    bytes32 public constant SETTLER_ROLE = keccak256("SETTLER_ROLE");

    /// @notice The role allowed to pause the sale.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The role allowed to refund entities.
    bytes32 public constant REFUNDER_ROLE = keccak256("REFUNDER_ROLE");

    error InvalidSaleUUID(bytes16 got, bytes16 want);
    error PurchasePermitExpired();
    error InvalidSender(address got, address want);
    error UnauthorizedSigner(address signer);
    error BidBelowMinAmount(uint256 newBidAmount, uint256 minAmount);
    error BidExceedsMaxAmount(uint256 newBidAmount, uint256 maxAmount);
    error EntityTiedToAnotherAddress(address got, address existing, bytes16 entityID);
    error AddressTiedToAnotherEntity(bytes16 got, bytes16 existing, address addr);
    error ZeroAmount();
    error InvalidStage(Stage);
    error ZeroAddress();
    error ZeroEntityID();
    error BidAmountCannotBeLowered(uint256 newAmount, uint256 previousAmount);
    error BidPriceCannotBeLowered(uint256 newPrice, uint256 previousPrice);
    error ZeroPrice();
    error AllocationAlreadySet(address committer, uint256 acceptedAmount);
    error AlreadyRefunded(address committer);
    error AlreadyWithdrawn();
    error AllocationExceedsCommitment(address committer, uint256 allocation, uint256 commitment);
    error SalePaused();
    error BidPriceExceedsMaxPrice(uint256 bidPrice, uint256 maxPrice);
    error BidPriceBelowMinPrice(uint256 bidPrice, uint256 minPrice);
    error UnexpectedTotalAcceptedAmount(uint256 expected, uint256 actual);
    error BidAlreadyCancelled(address committer);
    error CommitterWithoutBid(address committer);
    error CommitterNotInitialized(address);
    error MaxAddressesPerEntityExceeded(bytes16 entityID, uint256 current, uint256 max);
    error ClaimRefundDisabled();

    event CommitterInitialized(bytes16 indexed entityID, address indexed addr);
    event BidPlaced(bytes16 indexed entityID, address indexed addr, Bid bid);
    event BidCancelled(bytes16 indexed entityID, address indexed addr, uint256 amount);
    event AllocationSet(bytes16 indexed entityID, address indexed addr, uint256 acceptedAmount);
    event Refunded(bytes16 indexed entityID, address indexed addr, uint256 amount);
    event RefundedCommitterSkipped(bytes16 indexed entityID, address indexed committer);
    event ProceedsWithdrawn(address indexed receiver, uint256 amount);

    /// @notice The state of a committer in the sale.
    /// @dev This tracks the committer's address, the amount of `PAYMENT_TOKEN` they have committed, etc.
    struct CommitterState {
        /// The address of the committer.
        address addr;
        /// The Sonar entity ID associated with the committer.
        bytes16 entityID;
        /// The timestamp of the last bid placed by the committer.
        uint32 bidTimestamp;
        /// Whether the committer cancelled their bid during the cancellation stage. This is tracked mostly for audit purposes and is not used for any logic.
        bool cancelled;
        /// Whether the committer was refunded.
        bool refunded;
        /// The amount of `PAYMENT_TOKEN` that has been accepted from the committer to purchase tokens after clearing the sale.
        /// The accepted amount will be withdrawn as proceeds at the end of the sale.
        /// The difference, i.e. `currentBid.amount - acceptedAmount`, will be refunded to the committer.
        uint256 acceptedAmount;
        /// The active bid of the committer in the auction part of the sale.
        Bid currentBid;
    }

    /// @notice A bid in the auction.
    /// @param price The price the committer is willing to pay, normalized to the price tick of the English auction.
    /// @param amount The amount of `PAYMENT_TOKEN` that the committer is willing to spend.
    struct Bid {
        uint64 price;
        uint256 amount;
    }

    /// @notice The stages of the sale.
    enum Stage {
        PreOpen,
        Auction,
        Closed,
        Cancellation,
        Settlement,
        Done
    }

    /// @notice The Sonar UUID of the sale.
    bytes16 public immutable SALE_UUID;

    /// @notice The token used to fund the sale.
    IERC20 public immutable PAYMENT_TOKEN;

    /// @notice Whether the sale is paused.
    /// @dev This is intended to be used in emergency situations and will disable the main external functions of the contract.
    bool public paused;

    /// @notice The manually set stage of the sale.
    /// @dev This can differ from the actual stage of the sale (as returned by `stage()`) if this is set to `Auction`
    /// and `closeAuctionAtTimestamp` are set.
    Stage public manualStage;

    /// @notice The timestamp at which the auction will be closed automatically.
    /// @dev Automatic closing based on timestamp is disabled if set to 0
    uint64 public closeAuctionAtTimestamp;

    /// @notice The total amount of `PAYMENT_TOKEN` that has been committed to the auction part of the sale.
    /// @dev This is the sum of all `CommitterState.currentBid.amount`s across all committers, tracked when bids are placed.
    /// Note: It is monotonically increasing and will not decrease on refunds/cancellations. Those are tracked separately by `totalRefundedAmount`.
    uint256 public totalComittedAmount;

    /// @notice The total amount of `PAYMENT_TOKEN` that has been refunded to committers.
    /// @dev This is the sum of all `CommitterState.currentBid.amount - CommitterState.acceptedAmount`s across all refunded committers.
    uint256 public totalRefundedAmount;

    /// @notice The total amount of `PAYMENT_TOKEN` that has been allocated to receive tokens.
    /// @dev This is the amount that will be withdrawn to the proceedsReceiver at the end of the sale.
    /// @dev This is the sum of all `CommitterState.acceptedAmount`s across all committers.
    uint256 public totalAcceptedAmount;

    /// @notice The address that will receive the proceeds of the sale.
    address public proceedsReceiver;

    /// @notice Whether the proceeds have been withdrawn.
    /// @dev This is used to prevent the proceeds from being withdrawn multiple times.
    bool public withdrawn;

    /// @notice The maximum number of addresses that can be associated with a single entity ID.
    /// @dev This is used to limit the number of committer addresses per entity.
    uint256 public maxAddressesPerEntity;

    /// @notice Whether committers can claim their own refunds during the `Done` stage.
    /// @dev If disabled, only addresses with the REFUNDER_ROLE can process refunds.
    bool public claimRefundEnabled;

    /// @notice The set of all committers that have participated in the sale.
    EnumerableSet.AddressSet internal _committers;

    /// @notice The mapping of committer addresses to committer states.
    /// @dev This is used to track the state of each committer.
    mapping(address => CommitterState) internal _committerStateByAddress;

    /// @notice The mapping of entity IDs to committer addresses.
    /// @dev This is used to track the committer addresses for each entity.
    mapping(bytes16 => EnumerableSet.AddressSet) internal _addressesByEntityID;

    /// @notice The initialization parameters for the sale.
    struct Init {
        bytes16 saleUUID;
        address admin;
        IERC20 paymentToken;
        address purchasePermitSigner;
        address proceedsReceiver;
        address pauser;
        uint64 closeAuctionAtTimestamp;
        uint256 maxAddressesPerEntity;
        bool claimRefundEnabled;
    }

    constructor(Init memory init) {
        SALE_UUID = init.saleUUID;
        PAYMENT_TOKEN = init.paymentToken;
        proceedsReceiver = init.proceedsReceiver;
        closeAuctionAtTimestamp = init.closeAuctionAtTimestamp;
        maxAddressesPerEntity = init.maxAddressesPerEntity;
        claimRefundEnabled = init.claimRefundEnabled;

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(PURCHASE_PERMIT_SIGNER_ROLE, init.purchasePermitSigner);
        _grantRole(PAUSER_ROLE, init.pauser);
    }

    /// @notice Returns the current stage of the sale.
    /// @dev The stage is either computed automatically if `manualStage` is set to `Auction`,
    /// or just returns the `manualStage` otherwise. This allows the contract to automatically
    /// move between active sale stages, while still allowing the admin to manually override
    /// the stage if needed.
    function stage() public view returns (Stage) {
        if (manualStage != Stage.Auction) {
            return manualStage;
        }

        if (closeAuctionAtTimestamp > 0 && block.timestamp >= closeAuctionAtTimestamp) {
            return Stage.Closed;
        }

        return Stage.Auction;
    }

    /// @notice Moves the sale to the `Auction` stage, allowing any user to submit bids.
    function openAuction() external onlyRole(SALE_MANAGER_ROLE) onlyStage(Stage.PreOpen) {
        manualStage = Stage.Auction;
    }

    /// @notice Tracks entities that placed bids in the sale.
    /// @dev Ensures that each address can only be tied to a single entityID. An entity can use multiple addresses (up to `maxAddressesPerEntity`).
    function _trackEntity(bytes16 entityID, address addr) internal {
        if (entityID == bytes16(0)) {
            revert ZeroEntityID();
        }

        if (addr == address(0)) {
            revert ZeroAddress();
        }

        // Ensure that addresses can only be tied to a single entityID
        CommitterState storage state = _committerStateByAddress[addr];

        bytes16 existingEntityIDForAddress = state.entityID;
        if (existingEntityIDForAddress != bytes16(0)) {
            if (existingEntityIDForAddress != entityID) {
                revert AddressTiedToAnotherEntity(entityID, existingEntityIDForAddress, addr);
            }
            // already initialized, so we're done
            return;
        }

        EnumerableSet.AddressSet storage entityAddresses = _addressesByEntityID[entityID];
        if (!entityAddresses.contains(addr) && entityAddresses.length() >= maxAddressesPerEntity) {
            revert MaxAddressesPerEntityExceeded(entityID, entityAddresses.length(), maxAddressesPerEntity);
        }

        state.entityID = entityID;
        state.addr = addr;
        _committers.add(addr);
        entityAddresses.add(addr);
        emit CommitterInitialized(entityID, addr);
    }

    // TODO implement permits?

    /// @notice Allows any wallet to bid during the `Auction` stage using a valid purchase permit.
    /// @dev When a new bid is submitted, it fully replaces any previous bid for the same committer.
    /// Only the difference in bid amount (if positive) is transferred from the bidder to the sale contract.
    function replaceBidWithApproval(
        Bid calldata bid,
        PurchasePermitWithAuctionData calldata purchasePermit,
        bytes calldata purchasePermitSignature
    ) external onlyStage(Stage.Auction) onlyUnpaused {
        uint256 amountDelta = _processBid(bid, purchasePermit, purchasePermitSignature);
        if (amountDelta > 0) {
            PAYMENT_TOKEN.safeTransferFrom(msg.sender, address(this), amountDelta);
        }
    }

    /// @notice Processes a bid during the `Auction` stage, validating the purchase permit and updating the bid.
    /// @dev The minimum and maximum amount of `PAYMENT_TOKEN` and the minimum and maximum price are specified on the purchase permit (`minAmount`, `maxAmount`, `minPrice`, and `maxPrice`, respectively).
    function _processBid(
        Bid calldata newBid,
        PurchasePermitWithAuctionData calldata purchasePermit,
        bytes calldata purchasePermitSignature
    ) internal returns (uint256) {
        _validatePurchasePermit(purchasePermit, purchasePermitSignature);

        if (newBid.price == 0) {
            revert ZeroPrice();
        }

        if (newBid.amount == 0) {
            revert ZeroAmount();
        }

        if (newBid.price > purchasePermit.maxPrice) {
            revert BidPriceExceedsMaxPrice(newBid.price, purchasePermit.maxPrice);
        }

        if (newBid.price < purchasePermit.minPrice) {
            revert BidPriceBelowMinPrice(newBid.price, purchasePermit.minPrice);
        }

        CommitterState storage state = _committerStateByAddress[purchasePermit.permit.wallet];
        // additional safety check: to avoid any bookkeeping issues, we disallow new bids for entities that have already been refunded.
        // this can theoretically happen if the auction was reopened after already refunding some entities.
        if (state.refunded) {
            revert AlreadyRefunded(purchasePermit.permit.wallet);
        }

        Bid memory previousBid = state.currentBid;

        if (newBid.amount < previousBid.amount) {
            revert BidAmountCannotBeLowered(newBid.amount, previousBid.amount);
        }

        if (newBid.price < previousBid.price) {
            revert BidPriceCannotBeLowered(newBid.price, previousBid.price);
        }

        if (newBid.amount < purchasePermit.minAmount) {
            revert BidBelowMinAmount(newBid.amount, purchasePermit.minAmount);
        }

        if (newBid.amount > purchasePermit.maxAmount) {
            revert BidExceedsMaxAmount(newBid.amount, purchasePermit.maxAmount);
        }

        _trackEntity(purchasePermit.permit.entityID, msg.sender);

        uint256 amountDelta = newBid.amount - previousBid.amount;

        state.currentBid = newBid;
        state.bidTimestamp = uint32(block.timestamp);
        totalComittedAmount += amountDelta;
        emit BidPlaced(purchasePermit.permit.entityID, msg.sender, newBid);

        return amountDelta;
    }

    /// @notice Validates a purchase permit.
    /// @dev This ensures that the permit was issued for the right sale (preventing the reuse of the same permit across sales),
    /// is not expired, and is signed by the purchase permit signer.
    function _validatePurchasePermit(PurchasePermitWithAuctionData memory permit, bytes calldata signature)
        internal
        view
    {
        if (permit.permit.saleUUID != SALE_UUID) {
            revert InvalidSaleUUID(permit.permit.saleUUID, SALE_UUID);
        }

        if (permit.permit.expiresAt <= block.timestamp) {
            revert PurchasePermitExpired();
        }

        if (permit.permit.wallet != msg.sender) {
            revert InvalidSender(msg.sender, permit.permit.wallet);
        }

        address recoveredSigner = PurchasePermitWithAuctionDataLib.recoverSigner(permit, signature);
        if (!hasRole(PURCHASE_PERMIT_SIGNER_ROLE, recoveredSigner)) {
            revert UnauthorizedSigner(recoveredSigner);
        }
    }

    /// @notice Moves the sale to the `Cancellation` stage, allowing committers to cancel their bids and receive refunds.
    function openCancellation() external onlyRole(DEFAULT_ADMIN_ROLE) onlyStage(Stage.Closed) {
        manualStage = Stage.Cancellation;
    }

    /// @notice Cancels a bid during the `Cancellation` stage, allowing committers to cancel their bids.
    /// @dev This differs from a refund in the `Done` stage in that it can only be triggered by the committer themselves and additionally marks the bid as cancelled.
    function cancelBid() external onlyStage(Stage.Cancellation) onlyUnpaused {
        CommitterState storage state = _committerStateByAddress[msg.sender];
        if (state.entityID == bytes16(0)) {
            revert CommitterNotInitialized(msg.sender);
        }
        assert(state.addr == msg.sender);

        if (state.cancelled) {
            revert BidAlreadyCancelled(msg.sender);
        }

        state.cancelled = true;
        emit BidCancelled(state.entityID, msg.sender, state.currentBid.amount);

        _refund(msg.sender);
    }

    /// @notice Moves the sale to the `Settlement` stage, allowing the settler to set allocations.
    /// @dev Can be called during the `Closed` stage (skipping the cancellation phase) or the `Cancellation` stage.
    function openSettlement() external onlyRole(DEFAULT_ADMIN_ROLE) onlyStages(Stage.Closed, Stage.Cancellation) {
        manualStage = Stage.Settlement;
    }

    /// @notice Allows the settler to set allocations for committers that participated in the sale.
    /// @dev Allocations are computed offchain and recorded onchain via this function.
    function setAllocations(Allocation[] calldata allocations, bool allowOverwrite)
        external
        onlyRole(SETTLER_ROLE)
        onlyStage(Stage.Settlement)
    {
        for (uint256 i = 0; i < allocations.length; i++) {
            _setAllocation(allocations[i], allowOverwrite);
        }
    }

    /// @notice Sets an allocation for a committer, ensuring that the allocation is not greater than their commitment.
    function _setAllocation(Allocation calldata allocation, bool allowOverwrite) internal {
        CommitterState storage state = _committerStateByAddress[allocation.committer];
        if (state.entityID == bytes16(0)) {
            revert CommitterNotInitialized(allocation.committer);
        }
        assert(state.addr == allocation.committer);

        // we cannot grant more allocation than a user committed
        // this also ensures that we can only set allocations for entities that have participated in the sale
        uint256 totalCommitment = state.currentBid.amount;
        if (allocation.acceptedAmount > totalCommitment) {
            revert AllocationExceedsCommitment(allocation.committer, allocation.acceptedAmount, totalCommitment);
        }

        if (state.refunded) {
            revert AlreadyRefunded(allocation.committer);
        }

        uint256 prevAcceptedAmount = state.acceptedAmount;
        if (prevAcceptedAmount > 0) {
            if (!allowOverwrite) {
                revert AllocationAlreadySet(allocation.committer, state.acceptedAmount);
            }

            totalAcceptedAmount -= prevAcceptedAmount;
        }

        state.acceptedAmount = allocation.acceptedAmount;
        totalAcceptedAmount += allocation.acceptedAmount;

        emit AllocationSet(state.entityID, allocation.committer, allocation.acceptedAmount);
    }

    /// @notice Moves the sale to the `Done` stage, allowing committers to claim refunds and the admin to withdraw the proceeds.
    /// @dev This is intended to be called after the settler has set allocations for all committers.
    function finalizeSettlement(uint256 expectedTotalAcceptedAmount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyStage(Stage.Settlement)
    {
        if (totalAcceptedAmount != expectedTotalAcceptedAmount) {
            revert UnexpectedTotalAcceptedAmount(expectedTotalAcceptedAmount, totalAcceptedAmount);
        }

        manualStage = Stage.Done;
    }

    /// @notice Refunds committers their unallocated `PAYMENT_TOKEN`.
    /// @dev The refund amount equals their commitment minus their allocated, accepted amount.
    /// @dev This function can only be called by addresses with the REFUNDER_ROLE. Committers can use `claimRefund` instead (if enabled).
    /// @param committers The addresses of the committers to refund.
    /// @param skipAlreadyRefunded Whether to skip already refunded committers. If this is false and a committer is already refunded, the transaction will revert.
    function processRefunds(address[] calldata committers, bool skipAlreadyRefunded)
        external
        onlyRole(REFUNDER_ROLE)
        onlyStage(Stage.Done)
    {
        for (uint256 i = 0; i < committers.length; i++) {
            CommitterState storage state = _committerStateByAddress[committers[i]];
            if (skipAlreadyRefunded && state.refunded) {
                emit RefundedCommitterSkipped(state.entityID, committers[i]);
                continue;
            }

            _refund(committers[i]);
        }
    }

    /// @notice Allows committers to claim their refund during the `Done` stage.
    /// @dev This enables committers to self-service their refunds without requiring the refunder role.
    function claimRefund() external onlyStage(Stage.Done) onlyUnpaused {
        if (!claimRefundEnabled) {
            revert ClaimRefundDisabled();
        }
        _refund(msg.sender);
    }

    /// @notice Refunds a committer their unallocated `PAYMENT_TOKEN`.
    /// @dev The refund amount equals their commitment minus their accepted allocation amount.
    function _refund(address committer) internal {
        CommitterState storage state = _committerStateByAddress[committer];
        if (state.entityID == bytes16(0)) {
            revert CommitterNotInitialized(committer);
        }
        assert(state.addr == committer);

        if (state.currentBid.amount == 0) {
            revert CommitterWithoutBid(committer);
        }

        if (state.refunded) {
            revert AlreadyRefunded(committer);
        }

        uint256 refundAmount = state.currentBid.amount - state.acceptedAmount;
        state.refunded = true;
        emit Refunded(state.entityID, committer, refundAmount);

        if (refundAmount > 0) {
            totalRefundedAmount += refundAmount;
            PAYMENT_TOKEN.safeTransfer(state.addr, refundAmount);
        }
    }

    /// @notice Withdraws the proceeds of the sale to the proceeds receiver.
    /// @dev This is intended to be called after the sale is finalized.
    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) onlyStage(Stage.Done) {
        if (withdrawn) {
            revert AlreadyWithdrawn();
        }

        withdrawn = true;
        emit ProceedsWithdrawn(proceedsReceiver, totalAcceptedAmount);
        PAYMENT_TOKEN.safeTransfer(proceedsReceiver, totalAcceptedAmount);
    }

    /// @notice Sets the manual stage of the sale.
    /// @dev This is not intended to be used during regular operation (use `openAuction`, `openCancellation`, `openSettlement`, and `finalizeSettlement` instead),
    /// but only for emergency situations.
    function setManualStage(Stage s) external onlyRole(DEFAULT_ADMIN_ROLE) {
        manualStage = s;
    }

    /// @notice Sets the timestamp at which the auction will be closed automatically.
    /// @dev Setting this to 0 will disable the automatic closing of the auction at a specific timestamp.
    function setCloseAuctionAtTimestamp(uint64 timestamp) external onlyRole(SALE_MANAGER_ROLE) {
        closeAuctionAtTimestamp = timestamp;
    }

    /// @notice Sets the address that will receive the proceeds of the sale.
    function setProceedsReceiver(address newProceedsReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newProceedsReceiver == address(0)) {
            revert ZeroAddress();
        }

        proceedsReceiver = newProceedsReceiver;
    }

    /// @notice Sets the maximum number of addresses that can be associated with a single entity ID.
    function setMaxAddressesPerEntity(uint256 newMaxAddressesPerEntity) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxAddressesPerEntity = newMaxAddressesPerEntity;
    }

    /// @notice Sets whether committers can claim their own refunds during the `Done` stage.
    function setClaimRefundEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        claimRefundEnabled = enabled;
    }

    /// @notice Pauses the sale.
    /// @dev This is intended to be used in emergency situations.
    function pause() external onlyRole(PAUSER_ROLE) {
        paused = true;
    }

    /// @notice Sets whether the sale is paused.
    /// @dev This is intended to unpause the sale after a pause.
    function setPaused(bool isPaused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused = isPaused;
    }

    /// @notice Returns the number of committers that have participated in the sale.
    function numCommitters() public view returns (uint256) {
        return _committers.length();
    }

    /// @notice Returns the committer address at a given index.
    function committerAt(uint256 index) public view returns (address) {
        return _committers.at(index);
    }

    /// @notice Returns the committer addresses in the given index range.
    function committersIn(uint256 from, uint256 to) external view returns (address[] memory) {
        address[] memory ids = new address[](to - from);
        for (uint256 i = from; i < to; i++) {
            ids[i - from] = committerAt(i);
        }
        return ids;
    }

    /// @notice Returns the state of a committer.
    function committerStateByAddress(address committer) public view returns (CommitterState memory) {
        return _committerStateByAddress[committer];
    }

    /// @notice Returns the states of the given committers.
    function committerStatesByAddresses(address[] calldata committers)
        external
        view
        returns (CommitterState[] memory)
    {
        CommitterState[] memory states = new CommitterState[](committers.length);
        for (uint256 i = 0; i < committers.length; i++) {
            states[i] = committerStateByAddress(committers[i]);
        }
        return states;
    }

    /// @notice Returns the states of committers in the given index range.
    function committerStatesIn(uint256 from, uint256 to) external view returns (CommitterState[] memory) {
        CommitterState[] memory states = new CommitterState[](to - from);
        for (uint256 i = from; i < to; i++) {
            states[i - from] = committerStateByAddress(committerAt(i));
        }
        return states;
    }

    /// @notice Returns the number of committer addresses associated with an entity ID.
    function numAddressesByEntityID(bytes16 entityID) public view returns (uint256) {
        return _addressesByEntityID[entityID].length();
    }

    /// @notice Returns the committer address at a given index for an entity ID.
    function addressAtByEntityID(bytes16 entityID, uint256 index) public view returns (address) {
        return _addressesByEntityID[entityID].at(index);
    }

    /// @notice Returns all committer addresses associated with an entity ID.
    function addressesByEntityID(bytes16 entityID) public view returns (address[] memory) {
        return _addressesByEntityID[entityID].values();
    }

    /// @notice Returns the total number of bids (committers) in the auction
    /// @dev Implementation of IAuctionBidDataReader.numBids().
    /// Returns the size of the internal _committers set, which tracks all unique wallet addresses
    /// that have placed at least one bid in the auction. This count remains constant even after
    /// refunds are processed, as committers are never removed from the set.
    function numBids() external view returns (uint256) {
        return _committers.length();
    }

    /// @notice Reads the bid data for a specific committer by index
    /// @dev Helper method that converts a CommitterState into a BidData struct.
    /// This method is used by readBidDataIn to efficiently batch-read multiple bids.
    /// Since this implementation only allows one bid per committer, the bidID is derived from the committer address.
    /// @param index The 0-based index of the committer in the _committers set
    function readBidDataAt(uint256 index) public view returns (BidData memory) {
        CommitterState memory state = committerStateByAddress(committerAt(index));
        return BidData({
            bidID: bytes32(uint256(uint160(state.addr))),
            committer: state.addr,
            entityID: state.entityID,
            timestamp: state.bidTimestamp,
            price: state.currentBid.price,
            amount: state.currentBid.amount,
            refunded: state.refunded,
            extraData: hex""
        });
    }

    /// @notice Reads a range of bid data entries for backend indexing
    /// @dev Implementation of IAuctionBidDataReader.readBidDataIn().
    /// This method is the primary interface for the Sonar backend to retrieve all auction bids.
    /// It iterates through the specified range of committer indices and returns their bid data.
    /// The Sonar backend typically calls this method multiple times with different ranges to
    /// paginate through all bids, avoiding RPC response size limitations.
    /// @param from The starting index (inclusive, 0-based)
    /// @param to The ending index (exclusive)
    function readBidDataIn(uint256 from, uint256 to) public view returns (BidData[] memory) {
        BidData[] memory bidData = new BidData[](to - from);
        for (uint256 i = from; i < to; i++) {
            bidData[i - from] = readBidDataAt(i);
        }
        return bidData;
    }

    /// @notice Recovers any ERC20 tokens that are sent to the contract.
    /// @dev This can be used to recover any tokens that are sent to the contract by mistake.
    function recoverTokens(IERC20 token, uint256 amount, address to) external onlyRole(TOKEN_RECOVERER_ROLE) {
        token.safeTransfer(to, amount);
    }

    /// @notice Modifier to ensure the sale is in the desired stage.
    modifier onlyStage(Stage want) {
        _onlyStage(want);
        _;
    }

    function _onlyStage(Stage want) private view {
        Stage s = stage();
        if (s != want) {
            revert InvalidStage(s);
        }
    }

    /// @notice Modifier to ensure the sale is in one of the allowed stages.
    modifier onlyStages(Stage want1, Stage want2) {
        _onlyStages(want1, want2);
        _;
    }

    function _onlyStages(Stage want1, Stage want2) private view {
        Stage s = stage();
        if (s != want1 && s != want2) {
            revert InvalidStage(s);
        }
    }

    /// @notice Modifier to ensure the sale is not paused.
    modifier onlyUnpaused() {
        _onlyUnpaused();
        _;
    }

    function _onlyUnpaused() private view {
        if (paused) {
            revert SalePaused();
        }
    }
}
