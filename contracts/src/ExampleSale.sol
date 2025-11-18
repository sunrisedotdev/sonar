// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {PurchasePermitV2, PurchasePermitV2Lib} from "./permits/PurchasePermitV2.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract ExampleSale is AccessControlEnumerable {
    /// @notice The role allowed to sign purchase permits.
    /// @dev This is intended to be granted to a wallet operated by the Sonar backend.
    bytes32 public constant PURCHASE_PERMIT_SIGNER_ROLE = keccak256("PURCHASE_PERMIT_SIGNER_ROLE");

    error PurchasePermitSaleUUIDMismatch(bytes16 got, bytes16 want);
    error PurchasePermitExpired();
    error PurchasePermitSenderMismatch(address got, address want);
    error PurchasePermitUnauthorizedSigner(address signer);
    error AmountBelowMinimum(uint256 amount, uint256 minAmount);
    error AmountExceedsMaximum(uint256 amount, uint256 maxAmount);
    error ZeroAddress();
    error ZeroEntityID();
    error AddressTiedToAnotherEntity(address addr, bytes16 got, bytes16 existing);

    event Purchased(address indexed wallet, bytes16 indexed entityID, uint256 amount, uint256 totalAmount);

    /// @notice The Sonar UUID of the sale.
    bytes16 public immutable saleUUID;

    /// @notice The amount purchased by wallet address
    mapping(address => uint256) public amountByAddress;

    /// @notice The ID of Sonar entities (individuals or organisations) associated to purchasing wallets.
    mapping(address => bytes16) public entityIDByAddress;

    struct Init {
        bytes16 saleUUID;
        address purchasePermitSigner;
    }

    constructor(Init memory init) {
        saleUUID = init.saleUUID;
        _grantRole(PURCHASE_PERMIT_SIGNER_ROLE, init.purchasePermitSigner);
    }

    /// @notice Allows users to purchase an amount of something.
    /// @dev In this example, we just increment an amount storage against the purchasing wallet and don't transfer any actual tokens.
    function purchase(uint256 amount, PurchasePermitV2 calldata purchasePermit, bytes calldata purchasePermitSignature)
        external
    {
        // ensure the validity of the purchase permit issued by Sonar
        _validatePurchasePermit(purchasePermit, purchasePermitSignature);

        uint256 newTotalAmount = amountByAddress[msg.sender] + amount;

        // Validate against minimum amount (check if new total meets minimum)
        if (newTotalAmount < purchasePermit.minAmount) {
            revert AmountBelowMinimum(newTotalAmount, purchasePermit.minAmount);
        }

        // Validate against maximum amount
        if (newTotalAmount > purchasePermit.maxAmount) {
            revert AmountExceedsMaximum(newTotalAmount, purchasePermit.maxAmount);
        }

        _trackEntity(purchasePermit.entityID, msg.sender);

        // Update the wallet's total amount purchased.
        // Note: This example tracks amounts only by the investing wallet.
        // One might also want to track/limit totals by entity ID.
        amountByAddress[msg.sender] = newTotalAmount;

        emit Purchased(msg.sender, purchasePermit.entityID, amount, newTotalAmount);

        // Note: If the purchaser was transferring tokens as part of the purchase, you would do that here.
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
    /// @dev Ensures that any purchasing wallet can only be associated to a single Sonar entity.
    function _trackEntity(bytes16 entityID, address addr) internal {
        if (entityID == bytes16(0)) {
            revert ZeroEntityID();
        }

        if (addr == address(0)) {
            revert ZeroAddress();
        }

        bytes16 existingEntityID = entityIDByAddress[addr];

        // If the wallet already has an associated sonar entity, we need to check if it's the same,
        // since wallets can only be used by a single entity.
        // While this is also enforced by the Sonar backend, it's still good to also check it on the contract.
        if (existingEntityID != bytes16(0)) {
            // Wallets can only be used by a single entity
            if (existingEntityID != entityID) {
                revert AddressTiedToAnotherEntity(addr, entityID, existingEntityID);
            }

            // entity is already tracked
            return;
        }

        // new entity so we track them
        entityIDByAddress[addr] = entityID;
    }

    /// @notice Resets the data for a purchasing wallet.
    function reset() external {
        delete entityIDByAddress[msg.sender];
        delete amountByAddress[msg.sender];
    }
}
