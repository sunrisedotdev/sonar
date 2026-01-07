// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {PurchasePermitV2, PurchasePermitV2Lib} from "./permits/PurchasePermitV2.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title ExampleSale
/// @notice Example sale contract with entity-based purchase tracking and limits.
/// @dev This contract demonstrates entity-level accounting where purchases from multiple
/// wallets belonging to the same entity are aggregated and validated against entity-level limits.
///
/// ## Key Concepts
///
/// - **Entity**: A Sonar entity (individual or organization) that can use multiple wallets
/// - **Address**: An Ethereum address used to submit transactions
/// - **Entity-Level Limits**: minAmount and maxAmount apply to total across all entity wallets
/// - **Address-Level Tracking**: Individual wallet contributions are preserved for transparency
///
/// ## Example Flow
///
/// ```
/// Entity E1 has maxAmount = 1000
/// - Address A purchases 600 → Entity total: 600
/// - Address B purchases 300 → Entity total: 900
/// - Address B tries to purchase 200 → REVERTS (would exceed 1000)
/// - Address C purchases 100 → Entity total: 1000 (at limit)
/// ```
/// @custom:security-contact security@echo.xyz
contract ExampleSale is AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The role allowed to sign purchase permits.
    /// @dev This is intended to be granted to a wallet operated by the Sonar backend.
    bytes32 public constant PURCHASE_PERMIT_SIGNER_ROLE = keccak256("PURCHASE_PERMIT_SIGNER_ROLE");

    /// @notice Maximum number of addresses allowed per entity
    /// @dev This prevents griefing attacks and ensures reasonable gas costs
    uint8 public constant MAX_ADDRESSES_PER_ENTITY = 20;

    error PurchasePermitSaleUUIDMismatch(bytes16 got, bytes16 want);
    error PurchasePermitExpired();
    error PurchasePermitSenderMismatch(address got, address want);
    error PurchasePermitUnauthorizedSigner(address signer);
    error AmountBelowMinimum(uint256 amount, uint256 minAmount);
    error AmountExceedsMaximum(uint256 amount, uint256 maxAmount);
    error ZeroAddress();
    error ZeroEntityID();
    error AddressTiedToAnotherEntity(address addr, bytes16 got, bytes16 existing);
    error TooManyAddressesForEntity(bytes16 entityID, uint256 max);

    event Purchased(address indexed addr, bytes16 indexed entityID, uint256 amount, uint256 totalAmount);
    event EntityReset(bytes16 indexed entityID);

    /// @notice The Sonar UUID of the sale.
    bytes16 public immutable saleUUID;

    /// @notice The amount purchased by each address
    /// @dev Preserved for transparency and per-address queries
    mapping(address => uint256) public amountByAddress;

    /// @notice The total amount purchased by each entity (primary accounting)
    /// @dev This is the aggregate of all address purchases for an entity
    mapping(bytes16 => uint256) public amountByEntity;

    /// @notice The entity ID associated with each address
    /// @dev Used to validate that addresses can only be tied to one entity
    mapping(address => bytes16) public entityIDByAddress;

    /// @notice The set of addresses that have purchased for each entity
    /// @dev Internal mapping for efficient enumeration
    mapping(bytes16 => EnumerableSet.AddressSet) internal _addressesByEntity;

    /// @notice Helper struct for returning address purchase breakdown
    struct AddressPurchase {
        address addr;
        uint256 amount;
    }

    struct Init {
        bytes16 saleUUID;
        address purchasePermitSigner;
    }

    constructor(Init memory init) {
        saleUUID = init.saleUUID;
        _grantRole(PURCHASE_PERMIT_SIGNER_ROLE, init.purchasePermitSigner);
    }

    /// @notice Allows users to purchase an amount of something.
    /// @dev Tracks purchases at both entity and wallet level. Validates limits at entity level.
    ///
    /// The purchase permit's minAmount and maxAmount apply to the entity's total across all wallets,
    /// not to individual wallet totals. This prevents entities from bypassing limits by using
    /// multiple wallets.
    ///
    /// @param amount The amount to purchase in this transaction
    /// @param purchasePermit The purchase permit authorizing this wallet to purchase for an entity
    /// @param purchasePermitSignature The signature of the purchase permit
    function purchase(
        uint256 amount,
        PurchasePermitV2 calldata purchasePermit,
        bytes calldata purchasePermitSignature
    ) external {
        // Validate the purchase permit issued by Sonar
        _validatePurchasePermit(purchasePermit, purchasePermitSignature);

        bytes16 entityID = purchasePermit.saleSpecificEntityID;

        // Track entity association (validates address is tied to this entity)
        _trackEntity(entityID, msg.sender);

        // Calculate new entity total (aggregated across all addresses)
        uint256 newEntityTotal = amountByEntity[entityID] + amount;

        // Validate against entity-level minimum
        // Note: This checks if the entity's total meets the minimum
        if (newEntityTotal < purchasePermit.minAmount) {
            revert AmountBelowMinimum(newEntityTotal, purchasePermit.minAmount);
        }

        // Validate against entity-level maximum
        // Note: This prevents the entity from exceeding the limit across all addresses
        if (newEntityTotal > purchasePermit.maxAmount) {
            revert AmountExceedsMaximum(newEntityTotal, purchasePermit.maxAmount);
        }

        // Update entity-level total (primary accounting)
        amountByEntity[entityID] = newEntityTotal;

        // Update address-level total (for transparency and breakdown queries)
        uint256 newAddressTotal = amountByAddress[msg.sender] + amount;
        amountByAddress[msg.sender] = newAddressTotal;

        // Note: If the purchaser was transferring tokens as part of the purchase, you would do that here.

        // Emit events
        emit Purchased(msg.sender, entityID, amount, newAddressTotal);
    }

    /// @notice Validates a purchase permit.
    /// @dev This ensures that the permit was issued for the right sale (preventing the use of permits issued for other sales),
    /// is not expired, and is signed by the purchase permit signer.
    function _validatePurchasePermit(PurchasePermitV2 memory permit, bytes calldata signature) internal view {
        if (permit.saleUUID != saleUUID) {
            revert PurchasePermitSaleUUIDMismatch(permit.saleUUID, saleUUID);
        }

        if (permit.expiresAt <= block.timestamp) {
            revert PurchasePermitExpired();
        }

        if (permit.wallet != msg.sender) {
            revert PurchasePermitSenderMismatch(msg.sender, permit.wallet);
        }

        address recoveredSigner = PurchasePermitV2Lib.recoverSigner(permit, signature);
        if (!hasRole(PURCHASE_PERMIT_SIGNER_ROLE, recoveredSigner)) {
            revert PurchasePermitUnauthorizedSigner(recoveredSigner);
        }
    }

    /// @notice Tracks entities that have purchased.
    /// @dev Ensures that any purchasing wallet can only be associated with a single entity.
    /// Also enforces a maximum number of wallets per entity to prevent griefing and ensure
    /// reasonable gas costs for entity-level operations.
    function _trackEntity(bytes16 entityID, address addr) internal {
        if (entityID == bytes16(0)) {
            revert ZeroEntityID();
        }

        if (addr == address(0)) {
            revert ZeroAddress();
        }

        bytes16 existingEntityID = entityIDByAddress[addr];

        // If the address already has an associated entity, verify it matches
        if (existingEntityID != bytes16(0)) {
            if (existingEntityID != entityID) {
                revert AddressTiedToAnotherEntity(addr, entityID, existingEntityID);
            }
            // Entity already tracked, nothing more to do
            return;
        }

        // Enforce maximum wallets per entity
        if (_addressesByEntity[entityID].length() >= MAX_ADDRESSES_PER_ENTITY) {
            revert TooManyAddressesForEntity(entityID, MAX_ADDRESSES_PER_ENTITY);
        }

        // Track new entity association
        entityIDByAddress[addr] = entityID;
        _addressesByEntity[entityID].add(addr);
    }

    /// @notice Resets the data for all addresses associated with an entity.
    /// @dev This is useful for testing. DO NOT INCLUDE IN PRODUCTION.
    /// @param entityID The entity ID whose addresses should be reset
    function reset(bytes16 entityID) external {
        if (entityID == bytes16(0)) {
            revert ZeroEntityID();
        }

        // Get all addresses for this entity
        address[] memory addresses = _addressesByEntity[entityID].values();

        // Reset each address
        for (uint256 i = 0; i < addresses.length; i++) {
            address addr = addresses[i];
            delete entityIDByAddress[addr];
            delete amountByAddress[addr];
        }

        // Clear the entity's address set
        for (uint256 i = 0; i < addresses.length; i++) {
            _addressesByEntity[entityID].remove(addresses[i]);
        }

        // Reset entity-level total
        delete amountByEntity[entityID];
        emit EntityReset(entityID);
    }

    // ============ View Functions ============

    /// @notice Returns all wallet addresses used by an entity
    /// @param entityID The entity to query
    /// @return An array of wallet addresses that have purchased for this entity
    function getEntityAddresses(bytes16 entityID) external view returns (address[] memory) {
        return _addressesByEntity[entityID].values();
    }

    /// @notice Returns the number of wallets used by an entity
    /// @param entityID The entity to query
    /// @return The count of unique addresses that have purchased for this entity
    function getEntityAddressCount(bytes16 entityID) external view returns (uint256) {
        return _addressesByEntity[entityID].length();
    }

    /// @notice Returns per-wallet purchase breakdown for an entity
    /// @param entityID The entity to query
    /// @return purchases Array of wallet addresses and their individual purchase amounts
    function getEntityPurchaseBreakdown(bytes16 entityID) external view returns (AddressPurchase[] memory purchases) {
        address[] memory addresses = _addressesByEntity[entityID].values();
        purchases = new AddressPurchase[](addresses.length);

        for (uint256 i = 0; i < addresses.length; i++) {
            purchases[i] = AddressPurchase({addr: addresses[i], amount: amountByAddress[addresses[i]]});
        }
    }

    /// @notice Returns the entity ID for a given address
    /// @param addr The address to query
    /// @return The entity ID associated with this address, or bytes16(0) if none
    function entityByAddress(address addr) external view returns (bytes16) {
        return entityIDByAddress[addr];
    }
}
