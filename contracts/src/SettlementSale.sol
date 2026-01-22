// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PurchasePermitV3, PurchasePermitV3Lib} from "./permits/PurchasePermitV3.sol";

import {ICommitmentDataReader} from "./interfaces/ICommitmentDataReader.sol";
import {IOffchainSettlement} from "./interfaces/IOffchainSettlement.sol";
import {ITotalCommitmentsReader} from "./interfaces/ITotalCommitmentsReader.sol";
import {IEntityAllocationDataReader} from "./interfaces/IEntityAllocationDataReader.sol";
import {ITotalAllocationsReader} from "./interfaces/ITotalAllocationsReader.sol";
import {TokenAmount, WalletTokenAmount} from "./interfaces/types.sol";

/// @title  SettlementSale
/// @notice Public sale contract for a token offering with various clearing mechanisms.
///
/// @dev
/// This contract raises funds in multiple payment tokens.
/// Supports various pricing mechanisms including fixed price, English auction, etc.
/// The contract acts as an escrow that records commitments, enforces limits, and handles refunds and withdrawals.
/// Clearing mechanics (price determination and token allocations) are computed offchain, with final results recorded onchain during settlement.
///
/// # Sale Stages
///
/// The sale progresses through the following stages:
///
/// 1. **PreOpen**: Initial state, no commitments allowed
/// 2. **Commitment**: Users submit bids with price and amount
/// 3. **Closed**: Commitment stage closes at a specified timestamp
/// 4. **Cancellation**: Participants can cancel their bids and receive refunds
/// 5. **Settlement**: Final allocations computed offchain are recorded onchain
/// 6. **Done**: Refunds processed and proceeds withdrawn
///
/// ## PreOpen Stage
///
/// The sale begins in the PreOpen stage, where no bids or commitments are accepted.
/// This is the initial setup stage before the commitment stage begins, allowing the sale manager to configure parameters and prepare for the commitment stage.
///
/// Transitions to: Commitment
///
/// ## Commitment Stage
///
/// Entities with valid purchase permits (issued by Sonar) can participate by submitting bids specifying price, amount, and lockup preferences.
/// Each new bid replaces the previous bid for the same entity.
/// Bids must satisfy monotonic constraints: amounts and prices can only increase or stay the same, and lockup preferences can be enabled but cannot be disabled once set.
/// Forced lockup can be required for specific entities as specified in the purchase permit.
///
/// Total commitment per entity cannot exceed the maximum amount specified in their purchase permit.
/// Bid prices must fall within the minimum and maximum price bounds specified in the purchase permit.
/// These price bounds are determined offchain and can change dynamically.
/// The commitment stage closes at a specified timestamp, though admins can manually override if needed.
///
/// Transitions to: Closed
///
/// ## Closed Stage
///
/// No new commitments can be submitted in this stage. The sale manager can reopen the commitment stage, proceed directly to settlement, or proceed to the cancellation or settlement stage.
/// Note: Once the sale moves from Closed to Cancellation or Settlement, the commitment stage cannot be reopened.
///
/// Transitions to: Commitment, Cancellation, Settlement
///
/// ## Cancellation Stage
///
/// After the commitment stage closes, preliminary allocations are computed offchain and communicated to participants.
/// During this stage, participants can cancel their bids at any time, which triggers an immediate refund of their committed amount.
///
/// Transitions to: Settlement
///
/// ## Settlement Stage
///
/// Final allocations are computed offchain based on the project's requirements.
/// The settler role records non-zero allocations onchain via the settlement function.
///
/// Transitions to: Done
///
/// ## Done Stage (Refund and Withdrawal)
///
/// After settlement is finalized, the sale enters the Done stage where refunds can be processed and proceeds can be withdrawn.
/// Refunds equal the difference between an entity's total commitment and their accepted allocation amount, calculated separately for each payment token.
/// Refunds can be triggered by participants themselves (if enabled) or by addresses with the refunder role.
/// The total accepted amount (proceeds) is withdrawn to the proceeds receiver.
///
/// # Token Distribution
///
/// The distribution of purchased tokens is handled separately by the project team and is outside the scope of this contract.
///
/// # Technical Notes
///
/// All prices are denominated in the sale's price tick units, as defined by the project.
/// Minimum/maximum bid prices and maximum bid amounts are specified offchain and passed to the contract via purchase permits.
///
/// The `entityID` refers to an entity in the Sonar system, which can be either a legal entity or an individual.
/// A wallet is an address used to commit funds to the sale.
/// An entity can have multiple wallets, but each wallet is associated with exactly one entity.
///
/// With the exception of the emergency recovery mechanism, tokens can only be:
/// - transferred to the contract as part of a bid
/// - fully returned to the wallet, or
/// - partially returned to the wallet, with the remainder withdrawable to the proceeds receiver
///
/// # Multi-Token Support
///
/// This contract accepts multiple payment tokens (e.g. USDC and USDT) and tracks commitments, allocations, and refunds separately for each token.
/// All amounts in bids and allocations represent the total value across all tokens, and the contract uses amounts interchangeably.
/// CRITICAL ASSUMPTION: All payment tokens MUST maintain 1:1 value parity throughout the sale lifecycle (e.g. USD stablecoins).
/// If a token depegs or loses parity, the sale SHOULD be paused immediately using the `pause()` function for further assessment.
///
/// When processing bids, the contract accepts a single payment token per transaction, tracking the breakdown by token internally.
/// During refunds and withdrawals, each token is transferred separately based on the accepted amounts recorded per-token amounts during settlement.
///
/// # Token Compatibility Warning
///
/// This contract is NOT compatible with rebasing tokens (e.g., stETH, aTokens) or fee-on-transfer tokens.
/// The contract's accounting model assumes that token balances remain constant between transfers and that
/// the full transfer amount is received. Using incompatible tokens will result in incorrect accounting
/// and potential loss of funds.
///
/// @custom:security-contact security@echo.xyz
contract SettlementSale is
    AccessControlEnumerable,
    ICommitmentDataReader,
    ITotalCommitmentsReader,
    IOffchainSettlement,
    IEntityAllocationDataReader,
    ITotalAllocationsReader
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The role allowed to recover tokens from the contract.
    /// @dev This is not intended to be granted by default, but will be granted manually by the DEFAULT_ADMIN_ROLE if needed.
    bytes32 public constant TOKEN_RECOVERER_ROLE = keccak256("TOKEN_RECOVERER_ROLE");

    /// @notice The role allowed to sign purchase permits.
    bytes32 public constant PURCHASE_PERMIT_SIGNER_ROLE = keccak256("PURCHASE_PERMIT_SIGNER_ROLE");

    /// @notice The role allowed to manage the operational aspects of the sale.
    bytes32 public constant SALE_MANAGER_ROLE = keccak256("SALE_MANAGER_ROLE");

    /// @notice The role allowed to set allocations for sale clearing.
    bytes32 public constant SETTLER_ROLE = keccak256("SETTLER_ROLE");

    /// @notice The role allowed to finalize the settlement.
    bytes32 public constant SETTLEMENT_FINALIZER_ROLE = keccak256("SETTLEMENT_FINALIZER_ROLE");

    /// @notice The role allowed to pause the sale.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The role allowed to refund entities.
    bytes32 public constant REFUNDER_ROLE = keccak256("REFUNDER_ROLE");

    // Initialization errors
    error InvalidPaymentTokenDecimals(address token, uint256 got, uint256 want);
    error DuplicatePaymentToken(address token);
    error NoPaymentTokens();

    // Purchase permit validation errors
    error InvalidSaleUUID(bytes16 got, bytes16 want);
    error PurchasePermitExpired(uint256 expiresAt, uint256 currentTime);
    error BidOutsideAllowedWindow(uint64 opensAt, uint64 closesAt, uint256 currentTime);
    error InvalidSender(address got, address want);
    error UnauthorizedSigner(address signer);

    // Commitment submission errors
    error BidBelowMinAmount(uint256 amount, uint256 min);
    error BidExceedsMaxAmount(uint256 amount, uint256 max);
    error WalletTiedToAnotherEntity(bytes16 got, bytes16 want, address wallet);
    error MaxWalletsPerEntityExceeded(bytes16 entityID, uint256 count, uint256 max);
    error ZeroAmount();
    error BidAmountCannotBeLowered(uint256 got, uint256 want);
    error BidPriceCannotBeLowered(uint256 got, uint256 want);
    error BidPriceExceedsMaxPrice(uint256 price, uint256 max);
    error BidPriceBelowMinPrice(uint256 price, uint256 min);
    error BidMustHaveLockup();
    error BidLockupCannotBeUndone();
    error InvalidPaymentToken(address token);

    // Settlement errors
    error AllocationAlreadySet(bytes16 entityID, uint256 acceptedAmount);
    error AllocationExceedsCommitment(
        bytes16 entityID, address wallet, address token, uint256 allocation, uint256 commitment
    );
    error WalletNotAssociatedWithEntity(address wallet, bytes16 entityID);
    error UnexpectedTotalAcceptedAmount(uint256 got, uint256 want);

    // Refund errors
    error AlreadyRefunded(bytes16 entityID);
    error BidAlreadyCancelled(bytes16 entityID);
    error ClaimRefundDisabled();

    // Withdrawal errors
    error WithdrawalExceedsAvailable(address token, uint256 requested, uint256 available);

    // Generic errors
    error InvalidStage(Stage got, Stage[] want);
    error ZeroAddress();
    error ZeroEntityID();
    error ZeroMaxWalletsPerEntity();
    error SalePaused();
    error EntityNotInitialized(bytes16 entityID);
    error WalletNotInitialized(address wallet);

    event StageChanged(Stage indexed previousStage, Stage indexed newStage);
    event EntityInitialized(bytes16 indexed entityID, address indexed wallet);
    event WalletInitialized(bytes16 indexed entityID, address indexed wallet);
    event BidPlaced(bytes16 indexed entityID, address indexed wallet, Bid bid);
    event BidCancelled(bytes16 indexed entityID, address indexed wallet, uint256 amount);
    event AllocationSet(
        bytes16 indexed entityID, address indexed wallet, address indexed token, uint256 acceptedAmount
    );
    event EntityRefunded(bytes16 indexed entityID, uint256 amount);
    event WalletRefunded(bytes16 indexed entityID, address indexed wallet, address indexed token, uint256 amount);
    event RefundedEntitySkipped(bytes16 indexed entityID);
    event ProceedsWithdrawn(address indexed receiver, address indexed token, uint256 amount);
    event ProceedsReceiverChanged(address indexed previousReceiver, address indexed newReceiver);
    event ClaimRefundEnabledChanged(bool enabled);
    event MaxWalletsPerEntityChanged(uint8 previousMax, uint8 newMax);
    event PausedStateChanged(bool paused);
    event TokensRecovered(address indexed token, uint256 amount, address indexed to);

    /// @notice The state of a wallet in the sale.
    /// @dev This tracks the wallet's committed and accepted amounts for each payment token.
    struct WalletState {
        /// The amount of each payment token that has been committed to the commitment stage of the sale, tracked separately by token.
        mapping(IERC20 => uint256) committedAmountByToken;
        /// The amount of each payment token that has been accepted from the wallet to purchase tokens after clearing the sale.
        /// The accepted amounts will be withdrawn as proceeds at the end of the sale.
        /// The difference per token, i.e. `committedAmountByToken[token] - acceptedAmountByToken[token]`, will be refunded to the wallet.
        mapping(IERC20 => uint256) acceptedAmountByToken;
    }

    /// @notice The state of an entity in the sale.
    /// @dev This tracks the entity's wallets, amounts of each payment token they have committed, their bid parameters, etc.
    struct EntityState {
        /// The timestamp of the last bid placed by the entity.
        uint32 bidTimestamp;
        /// Whether the entity cancelled their bid during the cancellation stage. This is tracked mostly for audit purposes and is not used for any logic.
        bool cancelled;
        /// Whether the entity was refunded.
        bool refunded;
        /// The active bid of the entity in the commitment stage of the sale, including price, total amount, and lockup preference.
        Bid currentBid;
        /// The set of wallets that the entity has used to commit funds to the sale.
        EnumerableSet.AddressSet wallets;
        /// The state of each wallet that the entity has used to commit funds to the sale.
        mapping(address => WalletState) walletStates;
    }

    /// @notice A bid in the commitment stage.
    /// @param price The price the entity is willing to pay, normalized to the price tick of the sale.
    /// @param amount The total amount across all payment tokens that the entity is willing to spend.
    /// @param lockup Whether the entity opts to lock up the purchased tokens. Once enabled, this cannot be disabled in subsequent bids.
    struct Bid {
        bool lockup;
        uint64 price;
        uint256 amount;
    }

    /// @notice The additional payload on the purchase permit issued by Sonar.
    /// @param forcedLockup Whether the purchased tokens for a specific entity must be locked up.
    struct PurchasePermitPayload {
        bool forcedLockup;
    }

    /// @notice The stages of the sale.
    /// @dev See the header comment for allowed stage transitions.
    enum Stage {
        PreOpen,
        Commitment,
        Closed,
        Cancellation,
        Settlement,
        Done
    }

    /// @notice The Sonar UUID of the sale.
    bytes16 public immutable SALE_UUID;

    /// @notice The payment tokens used to fund the sale.
    /// @dev Only set on construction and cannot be modified after.
    IERC20[] internal _paymentTokens;

    /// @notice Returns the payment tokens used to fund the sale.
    function paymentTokens() external view returns (IERC20[] memory) {
        return _paymentTokens;
    }

    /// @notice Whether the token is a valid payment token.
    /// @dev This is used to validate that the token is a valid payment token.
    /// @dev Only set on construction and cannot be modified after.
    mapping(IERC20 => bool) private _isValidPaymentToken;

    /// @notice Whether the sale is paused.
    /// @dev This is intended to be used in emergency situations and will disable the main external functions of the contract.
    bool public paused;

    /// @notice The maximum number of wallets that can be associated with a single entity.
    /// @dev This is used to prevent unbounded gas costs in _refund(). Must be > 0.
    uint8 public maxWalletsPerEntity;

    /// @notice The current stage of the sale.
    Stage public stage;

    /// @notice The amount of each payment token that has been committed to the sale, across all entities, tracked separately by token.
    /// @dev This is the sum of all `_entityStateByID[entityID].walletStates[wallet].committedAmountByToken[token]` over all entities and wallets.
    /// Note: It is monotonically increasing during the commitment stage and will not decrease on refunds/cancellations. Those are tracked separately by `totalRefundedAmountByToken`.
    mapping(IERC20 => uint256) internal _totalCommittedAmountByToken;

    /// @notice Returns the total committed amount for each payment token across all entities.
    /// @dev It is monotonically increasing and will not decrease on refunds/cancellations. Those are tracked separately by `totalRefundedAmount()`.
    function totalCommittedAmountByToken() external view returns (TokenAmount[] memory) {
        return _toTokenAmounts(_totalCommittedAmountByToken);
    }

    /// @notice Returns the total committed amount across all payment tokens.
    /// @dev This is computed by summing totalCommittedAmountByToken over all payment tokens.
    /// Note: It is monotonically increasing and will not decrease on refunds/cancellations. Those are tracked separately by `totalRefundedAmount()`.
    function totalCommittedAmount() external view returns (uint256) {
        return _sumByToken(_totalCommittedAmountByToken);
    }

    /// @notice The amount of refunds processed, across all entities, tracked separately by token.
    /// @dev For each token, this is the sum of all `WalletState.committedAmountByToken[token] - WalletState.acceptedAmountByToken[token]` over all refunded entities.
    /// @dev This is mainly used for audit purposes and is not used for any logic.
    mapping(IERC20 => uint256) internal _totalRefundedAmountByToken;

    /// @notice Returns the total refunded amount for each payment token across all entities.
    /// @dev This is computed by summing totalRefundedAmountByToken over all payment tokens.
    function totalRefundedAmountByToken() external view returns (TokenAmount[] memory) {
        return _toTokenAmounts(_totalRefundedAmountByToken);
    }

    /// @notice Returns the total refunded amount across all payment tokens.
    /// @dev This is computed by summing totalRefundedAmountByToken for all payment tokens.
    function totalRefundedAmount() external view returns (uint256) {
        return _sumByToken(_totalRefundedAmountByToken);
    }

    /// @notice The amount of each payment token that has been allocated to receive tokens, across all entities, tracked separately by token.
    /// @dev This is the amount that will be withdrawn to the proceedsReceiver at the end of the sale.
    /// @dev For each token, this is the sum of all `WalletState.acceptedAmountByToken[token]` over all entities and wallets.
    mapping(IERC20 => uint256) internal _totalAcceptedAmountByToken;

    /// @notice Returns the total accepted amount for each payment token across all entities.
    /// @dev This is computed by summing totalAcceptedAmountByToken over all payment tokens.
    function totalAcceptedAmountByToken() external view returns (TokenAmount[] memory) {
        return _toTokenAmounts(_totalAcceptedAmountByToken);
    }

    /// @notice Returns the total accepted amount across all payment tokens.
    /// @dev This is computed by summing totalAcceptedAmountByToken for all payment tokens.
    function totalAcceptedAmount() public view returns (uint256) {
        return _sumByToken(_totalAcceptedAmountByToken);
    }

    /// @notice The address that will receive the proceeds of the sale.
    address public proceedsReceiver;

    /// @notice The amount of each payment token that has been withdrawn as proceeds, tracked separately by token.
    /// @dev This is used to track partial withdrawals and prevent double withdrawals.
    mapping(IERC20 => uint256) internal _withdrawnAmountByToken;

    /// @notice Returns the withdrawn amount for each payment token.
    function withdrawnAmountByToken() external view returns (TokenAmount[] memory) {
        return _toTokenAmounts(_withdrawnAmountByToken);
    }

    /// @notice Returns the total withdrawn amount across all payment tokens.
    function withdrawnAmount() public view returns (uint256) {
        return _sumByToken(_withdrawnAmountByToken);
    }

    /// @notice Whether wallets can claim their own refunds during the `Done` stage.
    /// @dev If disabled, only addresses with the REFUNDER_ROLE can process refunds.
    bool public claimRefundEnabled;

    /// @notice The list of all entity IDs that have participated in the sale.
    bytes16[] internal _entityIDs;

    /// @notice The mapping of entity IDs to entity states.
    /// @dev This is used to track the state of each entity.
    mapping(bytes16 => EntityState) internal _entityStateByID;

    /// @notice The mapping of wallet addresses to entity IDs.
    /// @dev This is used to look up which entity a wallet address belongs to and to check whether the tracking for a wallet was initialized.
    mapping(address => bytes16) internal _entityIDByAddress;

    /// @notice The initialization parameters for the sale.
    struct Init {
        bytes16 saleUUID;
        address admin;
        address[] extraManagers;
        address[] extraPausers;
        address extraSettler;
        address extraRefunder;
        address purchasePermitSigner;
        address proceedsReceiver;
        bool claimRefundEnabled;
        uint8 maxWalletsPerEntity;
        IERC20Metadata[] paymentTokens;
        uint256 expectedPaymentTokenDecimals;
    }

    constructor(Init memory init) {
        if (init.admin == address(0)) {
            revert ZeroAddress();
        }
        if (init.purchasePermitSigner == address(0)) {
            revert ZeroAddress();
        }
        if (init.proceedsReceiver == address(0)) {
            revert ZeroAddress();
        }
        if (init.maxWalletsPerEntity == 0) {
            revert ZeroMaxWalletsPerEntity();
        }

        SALE_UUID = init.saleUUID;
        proceedsReceiver = init.proceedsReceiver;
        claimRefundEnabled = init.claimRefundEnabled;
        maxWalletsPerEntity = init.maxWalletsPerEntity;

        if (init.paymentTokens.length == 0) {
            revert NoPaymentTokens();
        }

        for (uint256 i = 0; i < init.paymentTokens.length; i++) {
            // additional sanity check to ensure that all payment tokens have the same number of decimals,
            // so we can use amounts interchangeably (assuming they all have the same value, e.g. all are USD stablecoins)
            if (init.paymentTokens[i].decimals() != init.expectedPaymentTokenDecimals) {
                revert InvalidPaymentTokenDecimals(
                    address(init.paymentTokens[i]), init.paymentTokens[i].decimals(), init.expectedPaymentTokenDecimals
                );
            }

            if (_isValidPaymentToken[init.paymentTokens[i]]) {
                revert DuplicatePaymentToken(address(init.paymentTokens[i]));
            }

            _paymentTokens.push(init.paymentTokens[i]);
            _isValidPaymentToken[init.paymentTokens[i]] = true;
        }

        // the admin should have all operational roles by default
        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(SALE_MANAGER_ROLE, init.admin);
        _grantRole(SETTLER_ROLE, init.admin);
        _grantRole(SETTLEMENT_FINALIZER_ROLE, init.admin);
        _grantRole(PAUSER_ROLE, init.admin);
        _grantRole(REFUNDER_ROLE, init.admin);

        _grantRole(PURCHASE_PERMIT_SIGNER_ROLE, init.purchasePermitSigner);

        // grant extra roles
        if (init.extraSettler != address(0)) {
            _grantRole(SETTLER_ROLE, init.extraSettler);
        }

        if (init.extraRefunder != address(0)) {
            _grantRole(REFUNDER_ROLE, init.extraRefunder);
        }

        for (uint256 i = 0; i < init.extraManagers.length; i++) {
            _grantRole(SALE_MANAGER_ROLE, init.extraManagers[i]);
        }

        for (uint256 i = 0; i < init.extraPausers.length; i++) {
            _grantRole(PAUSER_ROLE, init.extraPausers[i]);
        }
    }

    /// @notice Moves the sale to the `Commitment` stage, allowing participants to submit bids.
    /// @dev Can be called from `PreOpen` (first open) or `Closed` (reopen after closing).
    function openCommitment() external onlyRole(SALE_MANAGER_ROLE) onlyStages(Stage.PreOpen, Stage.Closed) {
        _setStage(Stage.Commitment);
    }

    /// @notice Moves the sale to the `Closed` stage, preventing any new bids from being submitted.
    function closeCommitment() external onlyRole(SALE_MANAGER_ROLE) onlyStage(Stage.Commitment) {
        _setStage(Stage.Closed);
    }

    /// @notice Tracks entities that placed bids in the sale.
    /// @dev Ensures that each address can only be tied to a single entityID. An entity can use multiple addresses (up to `maxWalletsPerEntity`).
    function _trackEntity(bytes16 entityID, address addr) internal {
        if (entityID == bytes16(0)) {
            revert ZeroEntityID();
        }

        if (addr == address(0)) {
            revert ZeroAddress();
        }

        // Ensure that addresses can only be tied to a single entityID
        bytes16 existingEntityIDForAddress = _entityIDByAddress[addr];
        if (existingEntityIDForAddress != bytes16(0)) {
            if (existingEntityIDForAddress != entityID) {
                revert WalletTiedToAnotherEntity(entityID, existingEntityIDForAddress, addr);
            }
            // wallet address already tracked, so we're done
            return;
        }

        // initialize wallet address
        _entityIDByAddress[addr] = entityID;

        EntityState storage state = _entityStateByID[entityID];

        // track new entity
        bool isNewEntity = state.wallets.length() == 0;
        if (isNewEntity) {
            _entityIDs.push(entityID);
            emit EntityInitialized(entityID, addr);
        }

        // add wallet to entity's wallet set
        state.wallets.add(addr);

        // check max wallets per entity limit
        uint8 maxWallets = maxWalletsPerEntity;
        if (state.wallets.length() > maxWallets) {
            revert MaxWalletsPerEntityExceeded(entityID, state.wallets.length(), maxWallets);
        }

        emit WalletInitialized(entityID, addr);
    }

    /// @notice Allows any wallet to bid during the `Commitment` stage using a valid purchase permit and ERC20 permit signature.
    /// @dev When a new bid is submitted, it fully replaces any previous bid for the same entity.
    /// Only the difference in bid amount (if positive) is transferred from the bidder to the sale contract in the specified payment token.
    ///
    /// This function uses ERC20 permit to combine token approval and transfer into a single transaction.
    /// The permit signature only needs to authorize the difference between the new and old bid amount, not the full bid amount.
    /// For example, if a user previously bid 100 USDC and now wants to bid 150 USDC, they only need to permit 50 USDC.
    ///
    /// @param token The payment token to use for this bid increment.
    /// @param bid The bid to replace.
    /// @param purchasePermit The purchase permit to use for this bid.
    /// @param purchasePermitSignature The signature of the purchase permit.
    /// @param erc20PermitDeadline The deadline for the ERC20 permit signature.
    /// @param erc20PermitSignature The ERC20 permit signature (r, s, v components concatenated).
    function replaceBidWithPermit(
        IERC20 token,
        Bid calldata bid,
        PurchasePermitV3 calldata purchasePermit,
        bytes calldata purchasePermitSignature,
        uint256 erc20PermitDeadline,
        bytes calldata erc20PermitSignature
    ) external onlyStage(Stage.Commitment) onlyUnpaused {
        uint256 amountDelta = _processBid(token, bid, purchasePermit, purchasePermitSignature);
        if (amountDelta > 0) {
            // Permit signatures can be grabbed from the mempool, allowing attackers to execute them before the actual bid is placed,
            // which will cause the call to `ptoken.permit` to revert.
            // The sale contract should be able to handle this gracefully and not revert when the bid transaction is eventually included.
            // To do this, we wrap the call to `ptoken.permit` in a try-catch block and ignore the revert. This will also ignore any other errors,
            // which is fine because this method effectively just becomes equivalent to `replaceBidWithApproval`.
            IERC20Permit ptoken = IERC20Permit(address(token));
            try ptoken.permit({
                owner: msg.sender,
                spender: address(this),
                value: amountDelta,
                deadline: erc20PermitDeadline,
                r: bytes32(erc20PermitSignature[0:32]),
                s: bytes32(erc20PermitSignature[32:64]),
                v: uint8(bytes1(erc20PermitSignature[64]))
            }) {}
                catch {}

            token.safeTransferFrom(msg.sender, address(this), amountDelta);
        }
    }

    /// @notice Allows any wallet to bid during the `Commitment` stage using a valid purchase permit.
    /// @dev When a new bid is submitted, it fully replaces any previous bid for the same entity.
    /// Only the difference in bid amount (if positive) is transferred from the bidder to the sale contract in the specified payment token.
    ///
    /// This function requires the user to have already approved the contract to spend tokens via a separate
    /// `approve` transaction. This requires two transactions: first `approve`, then this function.
    /// The approval only needs to cover the difference between the new and old bid amount, not the full bid amount.
    /// For example, if a user previously bid 100 USDT and now wants to bid 150 USDT, they only need to approve 50 USDT.
    ///
    /// Use `replaceBidWithPermit` instead if the payment token supports ERC20 permit, as it
    /// combines approval and transfer into a single transaction.
    ///
    /// @param token The payment token to use for this bid increment.
    /// @param bid The bid to replace.
    /// @param purchasePermit The purchase permit to use for this bid.
    /// @param purchasePermitSignature The signature of the purchase permit.
    function replaceBidWithApproval(
        IERC20 token,
        Bid calldata bid,
        PurchasePermitV3 calldata purchasePermit,
        bytes calldata purchasePermitSignature
    ) external onlyStage(Stage.Commitment) onlyUnpaused {
        uint256 amountDelta = _processBid(token, bid, purchasePermit, purchasePermitSignature);
        if (amountDelta > 0) {
            token.safeTransferFrom(msg.sender, address(this), amountDelta);
        }
    }

    /// @notice Processes a bid during the `Commitment` stage, validating the purchase permit, any constraints specified on the permit, and updating the bid.
    /// @dev The minimum and maximum total bid amount and the minimum and maximum price are specified on the purchase permit (`minAmount`, `maxAmount`, `minPrice`, and `maxPrice`, respectively).
    function _processBid(
        IERC20 token,
        Bid calldata newBid,
        PurchasePermitV3 calldata purchasePermit,
        bytes calldata purchasePermitSignature
    ) internal returns (uint256) {
        _validatePurchasePermit(purchasePermit, purchasePermitSignature);

        if (!_isValidPaymentToken[token]) {
            revert InvalidPaymentToken(address(token));
        }

        if (block.timestamp < purchasePermit.opensAt || block.timestamp >= purchasePermit.closesAt) {
            revert BidOutsideAllowedWindow(purchasePermit.opensAt, purchasePermit.closesAt, block.timestamp);
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

        if (newBid.amount < purchasePermit.minAmount) {
            revert BidBelowMinAmount(newBid.amount, purchasePermit.minAmount);
        }

        if (newBid.amount > purchasePermit.maxAmount) {
            revert BidExceedsMaxAmount(newBid.amount, purchasePermit.maxAmount);
        }

        PurchasePermitPayload memory payload = abi.decode(purchasePermit.payload, (PurchasePermitPayload));
        if (payload.forcedLockup && !newBid.lockup) {
            revert BidMustHaveLockup();
        }

        EntityState storage state = _entityStateByID[purchasePermit.saleSpecificEntityID];
        // additional safety check: to avoid any bookkeeping issues, we disallow new bids for entities that have already been refunded.
        // this can theoretically happen if the commitment stage was reopened after already refunding some entities.
        if (state.refunded) {
            revert AlreadyRefunded(purchasePermit.saleSpecificEntityID);
        }

        Bid memory previousBid = state.currentBid;

        if (newBid.amount < previousBid.amount) {
            revert BidAmountCannotBeLowered(newBid.amount, previousBid.amount);
        }

        if (newBid.price < previousBid.price) {
            revert BidPriceCannotBeLowered(newBid.price, previousBid.price);
        }

        if (previousBid.lockup && !newBid.lockup) {
            revert BidLockupCannotBeUndone();
        }

        uint256 amountDelta = newBid.amount - previousBid.amount;

        // track the entity and wallet
        address wallet = purchasePermit.wallet;
        _trackEntity(purchasePermit.saleSpecificEntityID, wallet);

        // update entity and wallet state
        state.currentBid = newBid;
        state.bidTimestamp = uint32(block.timestamp);
        state.walletStates[wallet].committedAmountByToken[token] += amountDelta;

        // updating global state
        _totalCommittedAmountByToken[token] += amountDelta;

        emit BidPlaced(purchasePermit.saleSpecificEntityID, msg.sender, newBid);

        return amountDelta;
    }

    /// @notice Validates a purchase permit.
    /// @dev This ensures that the permit was issued for the right sale (preventing the reuse of the same permit across sales),
    /// is not expired, and is signed by the purchase permit signer.
    function _validatePurchasePermit(PurchasePermitV3 memory permit, bytes calldata signature) internal view {
        if (permit.saleUUID != SALE_UUID) {
            revert InvalidSaleUUID(permit.saleUUID, SALE_UUID);
        }

        if (permit.expiresAt <= block.timestamp) {
            revert PurchasePermitExpired(permit.expiresAt, block.timestamp);
        }

        if (permit.wallet != msg.sender) {
            revert InvalidSender(msg.sender, permit.wallet);
        }

        address recoveredSigner = PurchasePermitV3Lib.recoverSigner(permit, signature);
        if (!hasRole(PURCHASE_PERMIT_SIGNER_ROLE, recoveredSigner)) {
            revert UnauthorizedSigner(recoveredSigner);
        }
    }

    /// @notice Moves the sale to the `Cancellation` stage, allowing participants to cancel their bids and receive refunds.
    function openCancellation() external onlyRole(SALE_MANAGER_ROLE) onlyStage(Stage.Closed) {
        _setStage(Stage.Cancellation);
    }

    /// @notice Cancels a bid during the `Cancellation` stage, allowing participants to cancel their bids and receive refunds.
    /// @dev This differs from a refund in the `Done` stage in that it can only be triggered by the wallet itself and additionally marks the bid as cancelled.
    function cancelBid() external onlyStage(Stage.Cancellation) onlyUnpaused {
        bytes16 entityID = _entityIDByAddress[msg.sender];
        if (entityID == bytes16(0)) {
            revert WalletNotInitialized(msg.sender);
        }

        EntityState storage state = _entityStateByID[entityID];
        if (state.cancelled) {
            revert BidAlreadyCancelled(entityID);
        }

        state.cancelled = true;
        emit BidCancelled(entityID, msg.sender, state.currentBid.amount);

        _refund(entityID);
    }

    /// @notice Moves the sale to the `Settlement` stage, allowing the settler to set allocations.
    /// @dev Can be called during the `Closed` stage (skipping the cancellation stage) or the `Cancellation` stage.
    function openSettlement() external onlyRole(SALE_MANAGER_ROLE) onlyStages(Stage.Closed, Stage.Cancellation) {
        _setStage(Stage.Settlement);
    }

    /// @notice Allows the settler to set allocations for each entity that participated in the sale.
    /// @dev Allocations are computed offchain and recorded onchain via this function.
    /// The settler provides a list of (entityID, walletAddress, tokenAddress, acceptedAmount) tuples, that specify how many tokens are accepted from any given wallet.
    /// Unset allocations are implicitly assumed to be 0.
    /// If a non-zero amount was already set for `entityID, walletAddress, tokenAddress`, the contract will revert unless `allowOverwrite` is true.
    function setAllocations(
        Allocation[] calldata allocations,
        bool allowOverwrite
    ) external onlyRole(SETTLER_ROLE) onlyStage(Stage.Settlement) {
        for (uint256 i = 0; i < allocations.length; i++) {
            _setAllocation(allocations[i], allowOverwrite);
        }
    }

    /// @notice Sets an allocation for an entity's wallet, ensuring that the allocation is not greater than their commitment.
    function _setAllocation(Allocation calldata allocation, bool allowOverwrite) internal {
        EntityState storage entityState = _entityStateByID[allocation.saleSpecificEntityID];
        if (entityState.wallets.length() == 0) {
            revert EntityNotInitialized(allocation.saleSpecificEntityID);
        }
        if (entityState.refunded) {
            revert AlreadyRefunded(allocation.saleSpecificEntityID);
        }

        // ensure that the wallet is associated with the entity
        // this is intended as an additional safety check to ensure that the caller specified the correct entityID <-> wallet association.
        if (!entityState.wallets.contains(allocation.wallet)) {
            revert WalletNotAssociatedWithEntity(allocation.wallet, allocation.saleSpecificEntityID);
        }

        IERC20 token = IERC20(allocation.token);
        if (!_isValidPaymentToken[token]) {
            revert InvalidPaymentToken(address(token));
        }

        WalletState storage walletState = entityState.walletStates[allocation.wallet];

        // we cannot grant more allocation than a user committed
        // this implicitly also ensures that we can only set allocations for entities and wallets that have participated in the sale
        if (walletState.committedAmountByToken[token] < allocation.acceptedAmount) {
            revert AllocationExceedsCommitment(
                allocation.saleSpecificEntityID,
                allocation.wallet,
                address(token),
                allocation.acceptedAmount,
                walletState.committedAmountByToken[token]
            );
        }

        // reset the global state if had any previous allocations that we want to overwrite
        uint256 prevAcceptedAmountForToken = walletState.acceptedAmountByToken[token];
        if (prevAcceptedAmountForToken > 0) {
            if (!allowOverwrite) {
                revert AllocationAlreadySet(
                    allocation.saleSpecificEntityID, _sumByToken(walletState.acceptedAmountByToken)
                );
            }

            // reset global counter
            _totalAcceptedAmountByToken[token] -= prevAcceptedAmountForToken;
        }

        // update global counter
        _totalAcceptedAmountByToken[token] += allocation.acceptedAmount;

        // set wallet state
        walletState.acceptedAmountByToken[token] = allocation.acceptedAmount;

        emit AllocationSet(
            allocation.saleSpecificEntityID, allocation.wallet, address(token), allocation.acceptedAmount
        );
    }

    /// @notice Moves the sale to the `Done` stage, allowing participants to claim refunds and the admin to withdraw the proceeds.
    /// @dev This is intended to be called after the settler has set allocations for all entities.
    function finalizeSettlement(uint256 expectedTotalAcceptedAmount)
        external
        onlyRole(SETTLEMENT_FINALIZER_ROLE)
        onlyStage(Stage.Settlement)
    {
        if (totalAcceptedAmount() != expectedTotalAcceptedAmount) {
            revert UnexpectedTotalAcceptedAmount(totalAcceptedAmount(), expectedTotalAcceptedAmount);
        }

        _setStage(Stage.Done);
    }

    /// @notice Refunds entities their unallocated payment tokens.
    /// @dev The refund amount per token equals their commitment minus their allocated, accepted amount for that token.
    /// @dev This function can only be called by addresses with the REFUNDER_ROLE. Wallets can use `claimRefund` instead (if enabled).
    /// @param entityIDs The entity IDs to refund.
    /// @param skipAlreadyRefunded Whether to skip already refunded entities. If this is false and an entity is already refunded, the transaction will revert.
    function processRefunds(
        bytes16[] calldata entityIDs,
        bool skipAlreadyRefunded
    ) external onlyRole(REFUNDER_ROLE) onlyStage(Stage.Done) {
        for (uint256 i = 0; i < entityIDs.length; i++) {
            EntityState storage state = _entityStateByID[entityIDs[i]];
            if (skipAlreadyRefunded && state.refunded) {
                emit RefundedEntitySkipped(entityIDs[i]);
                continue;
            }

            _refund(entityIDs[i]);
        }
    }

    /// @notice Allows entities to claim their refund during the `Done` stage.
    /// This can be initiated by any wallet associated with an entity and will process the refunds for all wallets associated to it.
    /// @dev This enables wallets to self-service their refunds without requiring the refunder role.
    function claimRefund() external onlyStage(Stage.Done) onlyUnpaused {
        if (!claimRefundEnabled) {
            revert ClaimRefundDisabled();
        }

        bytes16 entityID = _entityIDByAddress[msg.sender];
        if (entityID == bytes16(0)) {
            revert WalletNotInitialized(msg.sender);
        }

        _refund(entityID);
    }

    /// @notice Refunds an entity their unallocated payment tokens.
    /// @dev This will process the refunds for all wallets associated with the entity.
    /// @dev The refund amount per token equals the wallets commitment minus the accepted allocation amount for that token.
    function _refund(bytes16 entityID) internal {
        EntityState storage state = _entityStateByID[entityID];
        if (state.wallets.length() == 0) {
            revert EntityNotInitialized(entityID);
        }
        if (state.refunded) {
            revert AlreadyRefunded(entityID);
        }
        state.refunded = true;

        address[] memory wallets = state.wallets.values();
        uint256 numTokens = _paymentTokens.length;

        uint256 entityTotalRefundAmount = 0;
        for (uint256 i = 0; i < wallets.length; i++) {
            WalletState storage walletState = state.walletStates[wallets[i]];
            for (uint256 j = 0; j < numTokens; j++) {
                IERC20 token = _paymentTokens[j];
                uint256 refundAmount =
                    walletState.committedAmountByToken[token] - walletState.acceptedAmountByToken[token];

                // nothing to refund
                if (refundAmount == 0) {
                    continue;
                }

                // increment global counters
                entityTotalRefundAmount += refundAmount;
                _totalRefundedAmountByToken[token] += refundAmount;
                emit WalletRefunded(entityID, wallets[i], address(token), refundAmount);

                // Note: We transfer tokens within the same loop that updates state, to avoid having to recompute
                // or store the amounts to be refunded.
                // This deviates from the usual Checks-Effects-Interactions (CEI) pattern but is safe within the
                // context of this contract because `_totalRefundedAmountByToken` is only used for tracking purposes
                // and doesn't affect any control flow or calculations.
                token.safeTransfer(wallets[i], refundAmount);
            }
        }

        emit EntityRefunded(entityID, entityTotalRefundAmount);
    }

    /// @notice Withdraws a partial amount of proceeds for a specific token to the proceeds receiver.
    /// @dev This allows the admin to withdraw proceeds incrementally rather than all at once, e.g. to do a test withdrawal.
    /// @param token The payment token to withdraw.
    /// @param amount The amount to withdraw.
    function withdrawPartial(IERC20 token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) onlyStage(Stage.Done) {
        _withdrawPartial(token, amount);
    }

    /// @notice Withdraws all remaining proceeds for all payment tokens to the proceeds receiver.
    /// @dev This is intended to be called after the sale is finalized.
    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) onlyStage(Stage.Done) {
        for (uint256 i = 0; i < _paymentTokens.length; i++) {
            IERC20 token = _paymentTokens[i];
            uint256 available = _totalAcceptedAmountByToken[token] - _withdrawnAmountByToken[token];
            if (available > 0) {
                _withdrawPartial(token, available);
            }
        }
    }

    /// @notice Internal function to withdraw a partial amount of proceeds for a specific token.
    /// @param token The payment token to withdraw.
    /// @param amount The amount to withdraw.
    function _withdrawPartial(IERC20 token, uint256 amount) internal {
        if (!_isValidPaymentToken[token]) {
            revert InvalidPaymentToken(address(token));
        }

        uint256 available = _totalAcceptedAmountByToken[token] - _withdrawnAmountByToken[token];
        if (amount > available) {
            revert WithdrawalExceedsAvailable(address(token), amount, available);
        }

        _withdrawnAmountByToken[token] += amount;
        emit ProceedsWithdrawn(proceedsReceiver, address(token), amount);

        token.safeTransfer(proceedsReceiver, amount);
    }

    /// @notice Sets the address that will receive the proceeds of the sale.
    function setProceedsReceiver(address newProceedsReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newProceedsReceiver == address(0)) {
            revert ZeroAddress();
        }

        address previousReceiver = proceedsReceiver;
        proceedsReceiver = newProceedsReceiver;
        emit ProceedsReceiverChanged(previousReceiver, newProceedsReceiver);
    }

    /// @notice Sets whether wallets can claim their own refunds during the `Done` stage.
    function setClaimRefundEnabled(bool enabled) external onlyRole(SALE_MANAGER_ROLE) {
        claimRefundEnabled = enabled;
        emit ClaimRefundEnabledChanged(enabled);
    }

    /// @notice Sets the maximum number of wallets that can be associated with a single entity.
    /// @param max The new maximum. Must be > 0.
    function setMaxWalletsPerEntity(uint8 max) external onlyRole(SALE_MANAGER_ROLE) {
        if (max == 0) {
            revert ZeroMaxWalletsPerEntity();
        }
        uint8 previousMax = maxWalletsPerEntity;
        maxWalletsPerEntity = max;
        emit MaxWalletsPerEntityChanged(previousMax, max);
    }

    /// @notice Pauses the sale.
    /// @dev This is intended to be used in emergency situations.
    function pause() external onlyRole(PAUSER_ROLE) {
        paused = true;
        emit PausedStateChanged(true);
    }

    /// @notice Sets whether the sale is paused.
    /// @dev This is intended to unpause the sale after a pause.
    function setPaused(bool isPaused) external onlyRole(SALE_MANAGER_ROLE) {
        paused = isPaused;
        emit PausedStateChanged(isPaused);
    }

    /// @notice Internal function to set the stage of the sale.
    /// @dev Emits a StageChanged event and updates the stage.
    function _setStage(Stage newStage) internal {
        emit StageChanged(stage, newStage);
        stage = newStage;
    }

    /// @notice Sets the stage of the sale.
    /// @dev This is only intended to be used in exceptional circumstances.
    /// Use with caution and consult with the Sonar team before using this function.
    function unsafeSetStage(Stage newStage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setStage(newStage);
    }

    /// @notice Returns the number of entities that have participated in the sale.
    function numEntities() public view returns (uint256) {
        return _entityIDs.length;
    }

    /// @notice Returns the entity ID at a given index.
    function entityAt(uint256 index) public view returns (bytes16) {
        return _entityIDs[index];
    }

    /// @notice Returns the entity IDs in the given index range.
    function entitiesIn(uint256 from, uint256 to) external view returns (bytes16[] memory) {
        bytes16[] memory ids = new bytes16[](to - from);
        for (uint256 i = from; i < to; i++) {
            ids[i - from] = entityAt(i);
        }
        return ids;
    }

    struct WalletStateView {
        address addr;
        bytes16 entityID;
        TokenAmount[] acceptedAmountByToken;
        TokenAmount[] committedAmountByToken;
    }

    function walletStateByAddress(address addr) public view returns (WalletStateView memory) {
        bytes16 entityID = _entityIDByAddress[addr];
        if (entityID == bytes16(0)) {
            revert WalletNotInitialized(addr);
        }

        EntityState storage state = _entityStateByID[entityID];
        return WalletStateView({
            addr: addr,
            entityID: entityID,
            committedAmountByToken: _toTokenAmounts(state.walletStates[addr].committedAmountByToken),
            acceptedAmountByToken: _toTokenAmounts(state.walletStates[addr].acceptedAmountByToken)
        });
    }

    function walletStatesByAddresses(address[] memory addrs) public view returns (WalletStateView[] memory) {
        WalletStateView[] memory states = new WalletStateView[](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            states[i] = walletStateByAddress(addrs[i]);
        }
        return states;
    }

    struct EntityStateView {
        bytes16 entityID;
        uint32 bidTimestamp;
        bool cancelled;
        bool refunded;
        Bid currentBid;
        WalletStateView[] walletStates;
    }

    /// @notice Returns the state of an entity.
    function entityStateByID(bytes16 entityID) public view returns (EntityStateView memory) {
        EntityState storage state = _entityStateByID[entityID];
        address[] memory wallets = state.wallets.values();

        return EntityStateView({
            entityID: entityID,
            bidTimestamp: state.bidTimestamp,
            cancelled: state.cancelled,
            refunded: state.refunded,
            currentBid: state.currentBid,
            walletStates: walletStatesByAddresses(wallets)
        });
    }

    /// @notice Returns the states of the given entities.
    function entityStatesByIDs(bytes16[] calldata entityIDs) external view returns (EntityStateView[] memory) {
        EntityStateView[] memory states = new EntityStateView[](entityIDs.length);
        for (uint256 i = 0; i < entityIDs.length; i++) {
            states[i] = entityStateByID(entityIDs[i]);
        }
        return states;
    }

    /// @notice Returns the states of entities in the given index range.
    function entityStatesIn(uint256 from, uint256 to) external view returns (EntityStateView[] memory) {
        EntityStateView[] memory states = new EntityStateView[](to - from);
        for (uint256 i = from; i < to; i++) {
            states[i - from] = entityStateByID(entityAt(i));
        }
        return states;
    }

    /// @notice Returns the total number of entities that have participated in the sale.
    /// @dev Implementation of ICommitmentDataReader.numCommitments().
    /// Returns the size of the internal _entityIDs array, which tracks all unique entities
    /// that have placed at least one bid in the sale. This count remains constant even after
    /// refunds are processed, as entities are never removed from the array.
    function numCommitments() external view returns (uint256) {
        return _entityIDs.length;
    }

    /// @notice Reads the commitment data for a specific entity by index.
    /// @dev Helper method that converts an EntityState into a CommitmentData struct.
    function readCommitmentDataAt(uint256 index) public view returns (CommitmentData memory) {
        bytes16 entityID = _entityIDs[index];
        EntityState storage state = _entityStateByID[entityID];

        address[] memory wallets = state.wallets.values();
        uint256 numTokens = _paymentTokens.length;

        // Build committed amounts array
        // Each wallet can have committed amounts in each payment token
        uint256 numWalletTokenPairs = wallets.length * numTokens;
        WalletTokenAmount[] memory committedAmounts = new WalletTokenAmount[](numWalletTokenPairs);

        uint256 idx = 0;
        for (uint256 i = 0; i < wallets.length; i++) {
            WalletState storage walletState = state.walletStates[wallets[i]];
            for (uint256 j = 0; j < numTokens; j++) {
                IERC20 token = _paymentTokens[j];
                committedAmounts[idx] = WalletTokenAmount({
                    wallet: wallets[i], token: address(token), amount: walletState.committedAmountByToken[token]
                });
                idx++;
            }
        }

        return CommitmentData({
            commitmentID: bytes32(entityID),
            saleSpecificEntityID: entityID,
            timestamp: state.bidTimestamp,
            price: state.currentBid.price,
            lockup: state.currentBid.lockup,
            refunded: state.refunded,
            amounts: committedAmounts,
            extraData: hex""
        });
    }

    /// @notice Reads a range of commitment data entries for backend indexing.
    /// @dev Implementation of ICommitmentDataReader.readCommitmentDataIn().
    /// This method is the primary interface for the Sonar backend to retrieve all commitment data.
    /// It iterates through the specified range of entity indices and returns their commitment data.
    /// The Sonar backend typically calls this method multiple times with different ranges to
    /// paginate through all commitments, avoiding RPC response size limitations.
    /// @param from The starting index (inclusive, 0-based)
    /// @param to The ending index (exclusive)
    function readCommitmentDataIn(uint256 from, uint256 to) public view returns (CommitmentData[] memory) {
        CommitmentData[] memory commitmentData = new CommitmentData[](to - from);
        for (uint256 i = from; i < to; i++) {
            commitmentData[i - from] = readCommitmentDataAt(i);
        }
        return commitmentData;
    }

    /// @notice Returns the total number of entity allocations in the sale.
    /// @dev Implementation of IEntityAllocationDataReader.numEntityAllocations().
    /// This is intended to be used as bound to iterate through all entity allocations in the sale
    /// using `readEntityAllocationDataAt` or `readEntityAllocationDataIn`.
    function numEntityAllocations() external view returns (uint256) {
        return _entityIDs.length;
    }

    /// @notice Reads the allocation data for a specific entity by index.
    /// @dev Implementation of IEntityAllocationDataReader.readEntityAllocationDataAt().
    /// Returns the accepted amounts by wallet and token for the entity at the given index.
    /// Includes all wallet-token pairs, even those with zero accepted amounts.
    /// @param index The 0-based index of the entity in the internal _entityIDs array
    function readEntityAllocationDataAt(uint256 index) public view returns (EntityAllocationData memory) {
        bytes16 entityID = _entityIDs[index];

        EntityState storage state = _entityStateByID[entityID];
        address[] memory wallets = state.wallets.values();

        uint256 numWalletTokenPairs = wallets.length * _paymentTokens.length;
        WalletTokenAmount[] memory amounts = new WalletTokenAmount[](numWalletTokenPairs);
        uint256 idx = 0;
        for (uint256 i = 0; i < wallets.length; i++) {
            for (uint256 j = 0; j < _paymentTokens.length; j++) {
                amounts[idx] = WalletTokenAmount({
                    wallet: wallets[i],
                    token: address(_paymentTokens[j]),
                    amount: state.walletStates[wallets[i]].acceptedAmountByToken[_paymentTokens[j]]
                });
                idx++;
            }
        }

        return EntityAllocationData({saleSpecificEntityID: entityID, acceptedAmounts: amounts});
    }

    /// @notice Reads a range of entity allocation data entries for backend indexing.
    /// @dev Implementation of IEntityAllocationDataReader.readEntityAllocationDataIn().
    /// This method enables efficient pagination of all entity allocations.
    /// The Sonar backend typically calls this method multiple times with different ranges to
    /// paginate through all allocations, avoiding RPC response size limitations.
    /// @param from The starting index (inclusive, 0-based)
    /// @param to The ending index (exclusive)
    function readEntityAllocationDataIn(uint256 from, uint256 to) public view returns (EntityAllocationData[] memory) {
        EntityAllocationData[] memory entityAllocationData = new EntityAllocationData[](to - from);
        for (uint256 i = from; i < to; i++) {
            entityAllocationData[i - from] = readEntityAllocationDataAt(i);
        }
        return entityAllocationData;
    }

    /// @notice Recovers any ERC20 tokens that are sent to the contract.
    /// @dev This can be used to recover any tokens that are sent to the contract by mistake.
    function recoverTokens(IERC20 token, uint256 amount, address to) external onlyRole(TOKEN_RECOVERER_ROLE) {
        emit TokensRecovered(address(token), amount, to);
        token.safeTransfer(to, amount);
    }

    /// @notice Checks if the contract supports an interface.
    function supportsInterface(bytes4 interfaceId) public view override(AccessControlEnumerable) returns (bool) {
        return interfaceId == type(ICommitmentDataReader).interfaceId
            || interfaceId == type(ITotalCommitmentsReader).interfaceId
            || interfaceId == type(IEntityAllocationDataReader).interfaceId
            || interfaceId == type(ITotalAllocationsReader).interfaceId
            || interfaceId == type(IOffchainSettlement).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Modifier to ensure the sale is in the desired stage.
    modifier onlyStage(Stage want) {
        _onlyStage(want);
        _;
    }

    function _onlyStage(Stage want) private view {
        Stage s = stage;
        if (s != want) {
            Stage[] memory wanted = new Stage[](1);
            wanted[0] = want;
            revert InvalidStage(s, wanted);
        }
    }

    /// @notice Modifier to ensure the sale is in one of the allowed stages.
    modifier onlyStages(Stage want1, Stage want2) {
        _onlyStages(want1, want2);
        _;
    }

    function _onlyStages(Stage want1, Stage want2) private view {
        Stage s = stage;
        if (s != want1 && s != want2) {
            Stage[] memory wanted = new Stage[](2);
            wanted[0] = want1;
            wanted[1] = want2;
            revert InvalidStage(s, wanted);
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

    /// @notice Iterates over all payment tokens and sums the amounts for a given mapping.
    function _sumByToken(mapping(IERC20 => uint256) storage amounts) private view returns (uint256) {
        uint256 total = 0;
        uint256 numTokens = _paymentTokens.length;
        for (uint256 i = 0; i < numTokens; i++) {
            total += amounts[_paymentTokens[i]];
        }
        return total;
    }

    /// @notice Iterates over all payment tokens and converts an amounts mapping to an array of TokenAmounts.
    function _toTokenAmounts(mapping(IERC20 => uint256) storage amounts) private view returns (TokenAmount[] memory) {
        uint256 numTokens = _paymentTokens.length;
        TokenAmount[] memory arr = new TokenAmount[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            arr[i] = TokenAmount({token: address(_paymentTokens[i]), amount: amounts[_paymentTokens[i]]});
        }
        return arr;
    }
}
