// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {BaseTest, console} from "./BaseTest.sol";
import {ExampleSale, PurchasePermitV3, PurchasePermitV3Lib} from "../src/ExampleSale.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @notice Base test contract with shared setup and helper functions
contract ExampleSaleTestBase is BaseTest {
    ExampleSale sale;
    bytes16 constant TEST_SALE_UUID = hex"1234567890abcdef1234567890abcdef";
    Account signer = makeAccount("signer");

    bytes16 entityIDAlice = hex"a11ce000000000000000000000000000";
    bytes16 entityIDBob = hex"b0b00000000000000000000000000000";

    address walletA = makeAddr("walletA");
    address walletB = makeAddr("walletB");
    address walletC = makeAddr("walletC");

    function setUp() public virtual {
        ExampleSale.Init memory init = ExampleSale.Init({saleUUID: TEST_SALE_UUID, purchasePermitSigner: signer.addr});
        sale = new ExampleSale(init);
    }

    function _signPermit(PurchasePermitV3 memory permit, uint256 pk) internal pure returns (bytes memory) {
        bytes32 digest = PurchasePermitV3Lib.digest(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _makePermit(
        bytes16 saleSpecificEntityID,
        address wallet,
        uint64 expiresAt,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 opensAt,
        uint64 closesAt
    ) internal pure returns (PurchasePermitV3 memory) {
        return PurchasePermitV3({
            saleSpecificEntityID: saleSpecificEntityID,
            saleUUID: TEST_SALE_UUID,
            wallet: wallet,
            expiresAt: expiresAt,
            minAmount: minAmount,
            maxAmount: maxAmount,
            minPrice: 0,
            maxPrice: type(uint64).max,
            opensAt: opensAt,
            closesAt: closesAt,
            payload: ""
        });
    }

    // Convenience overload for existing tests (uses a wide-open time window)
    function _makePermit(
        bytes16 saleSpecificEntityID,
        address wallet,
        uint64 expiresAt,
        uint256 minAmount,
        uint256 maxAmount
    ) internal view returns (PurchasePermitV3 memory) {
        return _makePermit(
            saleSpecificEntityID,
            wallet,
            expiresAt,
            minAmount,
            maxAmount,
            uint64(block.timestamp),
            uint64(block.timestamp + 86400)
        );
    }
}

contract SingleWalletTest is ExampleSaleTestBase {
    function testSingleWalletPurchase() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, alice, uint64(block.timestamp + 1000), 0, 1000);
        bytes memory sig = _signPermit(permit, signer.key);

        vm.prank(alice);
        sale.purchase(100, permit, sig);

        assertEq(sale.amountByAddress(alice), 100, "Wallet amount incorrect");
        assertEq(sale.amountByEntity(entityIDAlice), 100, "Entity amount incorrect");
        assertEq(sale.entityIDByAddress(alice), entityIDAlice, "Entity ID not set");
        assertEq(sale.getEntityAddressCount(entityIDAlice), 1, "Wallet count incorrect");
    }

    function testSingleWalletMultiplePurchases() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, alice, uint64(block.timestamp + 1000), 0, 1000);
        bytes memory sig = _signPermit(permit, signer.key);

        vm.startPrank(alice);
        sale.purchase(400, permit, sig);
        assertEq(sale.amountByEntity(entityIDAlice), 400);

        sale.purchase(300, permit, sig);
        assertEq(sale.amountByEntity(entityIDAlice), 700);
        assertEq(sale.amountByAddress(alice), 700);
        vm.stopPrank();
    }

    function testSingleWalletMaxAmount() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, alice, uint64(block.timestamp + 1000), 0, 1000);
        bytes memory sig = _signPermit(permit, signer.key);

        vm.startPrank(alice);
        sale.purchase(1000, permit, sig);
        assertEq(sale.amountByEntity(entityIDAlice), 1000);

        vm.expectRevert(abi.encodeWithSelector(ExampleSale.AmountExceedsMaximum.selector, 1100, 1000));
        sale.purchase(100, permit, sig);
        vm.stopPrank();
    }
}

contract MultiWalletEntityTest is ExampleSaleTestBase {
    function testMultiWalletEntityPurchase() public {
        PurchasePermitV3 memory permitA = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);
        PurchasePermitV3 memory permitB = _makePermit(entityIDAlice, walletB, uint64(block.timestamp + 1000), 0, 1000);

        bytes memory sigA = _signPermit(permitA, signer.key);
        bytes memory sigB = _signPermit(permitB, signer.key);

        vm.prank(walletA);
        sale.purchase(600, permitA, sigA);

        assertEq(sale.amountByAddress(walletA), 600, "Wallet A amount incorrect");
        assertEq(sale.amountByEntity(entityIDAlice), 600, "Entity total after A incorrect");

        vm.prank(walletB);
        sale.purchase(300, permitB, sigB);

        assertEq(sale.amountByAddress(walletB), 300, "Wallet B amount incorrect");
        assertEq(sale.amountByEntity(entityIDAlice), 900, "Entity total after B incorrect");
        assertEq(sale.getEntityAddressCount(entityIDAlice), 2, "Wallet count should be 2");
    }

    function testEntityMaxAmountEnforcementAcrossWallets() public {
        PurchasePermitV3 memory permitA = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);
        PurchasePermitV3 memory permitB = _makePermit(entityIDAlice, walletB, uint64(block.timestamp + 1000), 0, 1000);

        bytes memory sigA = _signPermit(permitA, signer.key);
        bytes memory sigB = _signPermit(permitB, signer.key);

        vm.prank(walletA);
        sale.purchase(600, permitA, sigA);

        vm.prank(walletB);
        vm.expectRevert(abi.encodeWithSelector(ExampleSale.AmountExceedsMaximum.selector, 1100, 1000));
        sale.purchase(500, permitB, sigB);

        vm.prank(walletB);
        sale.purchase(400, permitB, sigB);
        assertEq(sale.amountByEntity(entityIDAlice), 1000, "Should be at limit");

        vm.prank(walletB);
        vm.expectRevert(abi.encodeWithSelector(ExampleSale.AmountExceedsMaximum.selector, 1001, 1000));
        sale.purchase(1, permitB, sigB);
    }

    function testEntityMinAmountEnforcement() public {
        PurchasePermitV3 memory permitA = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 500, 1000);
        bytes memory sigA = _signPermit(permitA, signer.key);

        vm.prank(walletA);
        vm.expectRevert(abi.encodeWithSelector(ExampleSale.AmountBelowMinimum.selector, 400, 500));
        sale.purchase(400, permitA, sigA);

        vm.prank(walletA);
        sale.purchase(500, permitA, sigA);
        assertEq(sale.amountByEntity(entityIDAlice), 500);

        vm.prank(walletA);
        sale.purchase(100, permitA, sigA);
        assertEq(sale.amountByEntity(entityIDAlice), 600);
    }

    function testThreeWalletsOneEntity() public {
        PurchasePermitV3 memory permitA = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);
        PurchasePermitV3 memory permitB = _makePermit(entityIDAlice, walletB, uint64(block.timestamp + 1000), 0, 1000);
        PurchasePermitV3 memory permitC = _makePermit(entityIDAlice, walletC, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        sale.purchase(400, permitA, _signPermit(permitA, signer.key));

        vm.prank(walletB);
        sale.purchase(300, permitB, _signPermit(permitB, signer.key));

        vm.prank(walletC);
        sale.purchase(200, permitC, _signPermit(permitC, signer.key));

        assertEq(sale.amountByEntity(entityIDAlice), 900, "Entity total incorrect");
        assertEq(sale.getEntityAddressCount(entityIDAlice), 3, "Should have 3 wallets");

        assertEq(sale.amountByAddress(walletA), 400);
        assertEq(sale.amountByAddress(walletB), 300);
        assertEq(sale.amountByAddress(walletC), 200);
    }
}

contract EntityIsolationTest is ExampleSaleTestBase {
    function testMultipleEntitiesIndependent() public {
        PurchasePermitV3 memory permitAlice =
            _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);
        vm.prank(walletA);
        sale.purchase(600, permitAlice, _signPermit(permitAlice, signer.key));

        PurchasePermitV3 memory permitBob = _makePermit(entityIDBob, walletB, uint64(block.timestamp + 1000), 0, 500);
        vm.prank(walletB);
        sale.purchase(300, permitBob, _signPermit(permitBob, signer.key));

        assertEq(sale.amountByEntity(entityIDAlice), 600, "Alice entity incorrect");
        assertEq(sale.amountByEntity(entityIDBob), 300, "Bob entity incorrect");
        assertEq(sale.entityIDByAddress(walletA), entityIDAlice);
        assertEq(sale.entityIDByAddress(walletB), entityIDBob);
    }

    function testWalletCannotSwitchEntities() public {
        PurchasePermitV3 memory permitAlice =
            _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);
        vm.prank(walletA);
        sale.purchase(100, permitAlice, _signPermit(permitAlice, signer.key));

        PurchasePermitV3 memory permitBob = _makePermit(entityIDBob, walletA, uint64(block.timestamp + 1000), 0, 1000);
        vm.prank(walletA);
        vm.expectRevert(
            abi.encodeWithSelector(ExampleSale.AddressTiedToAnotherEntity.selector, walletA, entityIDBob, entityIDAlice)
        );
        sale.purchase(100, permitBob, _signPermit(permitBob, signer.key));
    }
}

contract WalletLimitsTest is ExampleSaleTestBase {
    function testMaxWalletsPerEntity() public {
        for (uint256 i = 0; i < 20; i++) {
            address wallet = makeAddr(string(abi.encodePacked("wallet", i)));
            PurchasePermitV3 memory permit =
                _makePermit(entityIDAlice, wallet, uint64(block.timestamp + 1000), 0, type(uint256).max);

            vm.prank(wallet);
            sale.purchase(1, permit, _signPermit(permit, signer.key));
        }

        assertEq(sale.getEntityAddressCount(entityIDAlice), 20, "Should have 20 wallets");
        assertEq(sale.amountByEntity(entityIDAlice), 20, "Total should be 20");

        address wallet21 = makeAddr("wallet21");
        PurchasePermitV3 memory permit21 =
            _makePermit(entityIDAlice, wallet21, uint64(block.timestamp + 1000), 0, type(uint256).max);

        vm.prank(wallet21);
        vm.expectRevert(abi.encodeWithSelector(ExampleSale.TooManyAddressesForEntity.selector, entityIDAlice, 20));
        sale.purchase(1, permit21, _signPermit(permit21, signer.key));
    }
}

contract ViewFunctionsTest is ExampleSaleTestBase {
    function testGetEntityWallets() public {
        PurchasePermitV3 memory permitA = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);
        PurchasePermitV3 memory permitB = _makePermit(entityIDAlice, walletB, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        sale.purchase(100, permitA, _signPermit(permitA, signer.key));

        vm.prank(walletB);
        sale.purchase(200, permitB, _signPermit(permitB, signer.key));

        address[] memory wallets = sale.getEntityAddresses(entityIDAlice);
        assertEq(wallets.length, 2, "Should have 2 wallets");

        bool hasA = wallets[0] == walletA || wallets[1] == walletA;
        bool hasB = wallets[0] == walletB || wallets[1] == walletB;
        assertTrue(hasA, "Should contain walletA");
        assertTrue(hasB, "Should contain walletB");
    }

    function testGetEntityPurchaseBreakdown() public {
        PurchasePermitV3 memory permitA = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);
        PurchasePermitV3 memory permitB = _makePermit(entityIDAlice, walletB, uint64(block.timestamp + 1000), 0, 1000);
        PurchasePermitV3 memory permitC = _makePermit(entityIDAlice, walletC, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        sale.purchase(400, permitA, _signPermit(permitA, signer.key));

        vm.prank(walletB);
        sale.purchase(300, permitB, _signPermit(permitB, signer.key));

        vm.prank(walletC);
        sale.purchase(200, permitC, _signPermit(permitC, signer.key));

        ExampleSale.AddressPurchase[] memory breakdown = sale.getEntityPurchaseBreakdown(entityIDAlice);
        assertEq(breakdown.length, 3, "Should have 3 wallets");

        uint256 total = 0;
        for (uint256 i = 0; i < breakdown.length; i++) {
            total += breakdown[i].amount;
        }
        assertEq(total, 900, "Breakdown total should match entity total");
    }

    function testGetWalletEntity() public {
        PurchasePermitV3 memory permitA = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        sale.purchase(100, permitA, _signPermit(permitA, signer.key));

        assertEq(sale.entityByAddress(walletA), entityIDAlice, "Should return Alice entity");
        assertEq(sale.entityByAddress(walletB), bytes16(0), "Should return zero for unused wallet");
    }
}

contract ResetFunctionalityTest is ExampleSaleTestBase {
    function testResetSingleWallet() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        sale.purchase(500, permit, _signPermit(permit, signer.key));

        assertEq(sale.amountByAddress(walletA), 500);
        assertEq(sale.amountByEntity(entityIDAlice), 500);

        sale.reset(entityIDAlice);

        assertEq(sale.amountByAddress(walletA), 0, "Wallet amount should be reset");
        assertEq(sale.amountByEntity(entityIDAlice), 0, "Entity amount should be reset");
        assertEq(sale.entityIDByAddress(walletA), bytes16(0), "Entity ID should be cleared");
        assertEq(sale.getEntityAddressCount(entityIDAlice), 0, "No wallets should remain");
    }

    function testResetMultiWalletEntity() public {
        PurchasePermitV3 memory permitA = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);
        PurchasePermitV3 memory permitB = _makePermit(entityIDAlice, walletB, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        sale.purchase(600, permitA, _signPermit(permitA, signer.key));

        vm.prank(walletB);
        sale.purchase(300, permitB, _signPermit(permitB, signer.key));

        assertEq(sale.amountByEntity(entityIDAlice), 900);

        sale.reset(entityIDAlice);

        assertEq(sale.amountByAddress(walletA), 0, "Wallet A should be reset");
        assertEq(sale.amountByAddress(walletB), 0, "Wallet B should be reset");
        assertEq(sale.amountByEntity(entityIDAlice), 0, "Entity total should be reset");
        assertEq(sale.getEntityAddressCount(entityIDAlice), 0, "No wallets should remain");
        assertEq(sale.entityIDByAddress(walletA), bytes16(0), "Wallet A entity ID should be cleared");
        assertEq(sale.entityIDByAddress(walletB), bytes16(0), "Wallet B entity ID should be cleared");
    }

    function testResetAllowsMorePurchases() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 100);

        vm.startPrank(walletA);
        sale.purchase(100, permit, _signPermit(permit, signer.key));

        vm.expectRevert(abi.encodeWithSelector(ExampleSale.AmountExceedsMaximum.selector, 101, 100));
        sale.purchase(1, permit, _signPermit(permit, signer.key));
        vm.stopPrank();

        sale.reset(entityIDAlice);

        vm.prank(walletA);
        sale.purchase(50, permit, _signPermit(permit, signer.key));
        assertEq(sale.amountByEntity(entityIDAlice), 50);
    }

    function testResetZeroEntityIDReverts() public {
        vm.expectRevert(ExampleSale.ZeroEntityID.selector);
        sale.reset(bytes16(0));
    }

    function testResetEntityWithNoWallets() public {
        // Reset an entity that has no wallets (should not revert, just do nothing)
        sale.reset(entityIDAlice);
        assertEq(sale.amountByEntity(entityIDAlice), 0);
        assertEq(sale.getEntityAddressCount(entityIDAlice), 0);
    }
}

contract PermitValidationTest is ExampleSaleTestBase {
    function testExpiredPermitReverts() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, walletA, uint64(block.timestamp - 1), 0, 1000);

        vm.prank(walletA);
        vm.expectRevert(ExampleSale.PurchasePermitExpired.selector);
        sale.purchase(100, permit, _signPermit(permit, signer.key));
    }

    function testWrongSaleUUIDReverts() public {
        bytes16 wrongUUID = hex"deadbeefdeadbeefdeadbeefdeadbeef";
        PurchasePermitV3 memory permit = PurchasePermitV3({
            saleSpecificEntityID: entityIDAlice,
            saleUUID: wrongUUID,
            wallet: walletA,
            expiresAt: uint64(block.timestamp + 1000),
            minAmount: 0,
            maxAmount: 1000,
            minPrice: 0,
            maxPrice: type(uint64).max,
            opensAt: uint64(block.timestamp),
            closesAt: uint64(block.timestamp + 86400),
            payload: ""
        });

        vm.prank(walletA);
        vm.expectRevert(
            abi.encodeWithSelector(ExampleSale.PurchasePermitSaleUUIDMismatch.selector, wrongUUID, TEST_SALE_UUID)
        );
        sale.purchase(100, permit, _signPermit(permit, signer.key));
    }

    function testWrongWalletReverts() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletB);
        vm.expectRevert(abi.encodeWithSelector(ExampleSale.PurchasePermitSenderMismatch.selector, walletB, walletA));
        sale.purchase(100, permit, _signPermit(permit, signer.key));
    }

    function testUnauthorizedSignerReverts() public {
        Account memory wrongSigner = makeAccount("wrongSigner");
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        vm.expectRevert(abi.encodeWithSelector(ExampleSale.PurchasePermitUnauthorizedSigner.selector, wrongSigner.addr));
        sale.purchase(100, permit, _signPermit(permit, wrongSigner.key));
    }

    function testZeroEntityIDReverts() public {
        PurchasePermitV3 memory permit = _makePermit(bytes16(0), walletA, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        vm.expectRevert(ExampleSale.ZeroEntityID.selector);
        sale.purchase(100, permit, _signPermit(permit, signer.key));
    }
}

contract EventsTest is ExampleSaleTestBase {
    function testPurchasedEventEmitted() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        vm.expectEmit(true, true, false, true);
        emit ExampleSale.Purchased(walletA, entityIDAlice, 100, 100);
        sale.purchase(100, permit, _signPermit(permit, signer.key));
    }

    function testEntityResetEventEmitted() public {
        PurchasePermitV3 memory permit = _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000);

        vm.prank(walletA);
        sale.purchase(100, permit, _signPermit(permit, signer.key));

        vm.expectEmit(true, false, false, false);
        emit ExampleSale.EntityReset(entityIDAlice);
        sale.reset(entityIDAlice);
    }
}

contract TimeWindowTest is ExampleSaleTestBase {
    function testPurchaseBeforeOpensAtReverts() public {
        uint64 futureOpen = uint64(block.timestamp + 1000);
        PurchasePermitV3 memory permit =
            _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 2000), 0, 1000, futureOpen, futureOpen + 3600);

        vm.prank(walletA);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExampleSale.PurchaseOutsideAllowedWindow.selector, futureOpen, futureOpen + 3600, block.timestamp
            )
        );
        sale.purchase(100, permit, _signPermit(permit, signer.key));
    }

    function testPurchaseAfterClosesAtReverts() public {
        // Warp to a safe timestamp to avoid underflow
        vm.warp(10000);

        uint64 pastClose = uint64(block.timestamp - 1);
        uint64 pastOpen = uint64(block.timestamp - 1000);
        PurchasePermitV3 memory permit =
            _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000, pastOpen, pastClose);

        vm.prank(walletA);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExampleSale.PurchaseOutsideAllowedWindow.selector, pastOpen, pastClose, block.timestamp
            )
        );
        sale.purchase(100, permit, _signPermit(permit, signer.key));
    }

    function testPurchaseAtExactOpensAtSucceeds() public {
        uint64 opensAt = uint64(block.timestamp);
        PurchasePermitV3 memory permit =
            _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000, opensAt, opensAt + 3600);

        vm.prank(walletA);
        sale.purchase(100, permit, _signPermit(permit, signer.key));
        assertEq(sale.amountByEntity(entityIDAlice), 100);
    }

    function testPurchaseAtExactClosesAtReverts() public {
        // Warp to a safe timestamp to avoid underflow
        vm.warp(10000);

        uint64 opensAt = uint64(block.timestamp - 100);
        uint64 closesAt = uint64(block.timestamp); // Exclusive boundary
        PurchasePermitV3 memory permit =
            _makePermit(entityIDAlice, walletA, uint64(block.timestamp + 1000), 0, 1000, opensAt, closesAt);

        vm.prank(walletA);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExampleSale.PurchaseOutsideAllowedWindow.selector, opensAt, closesAt, block.timestamp
            )
        );
        sale.purchase(100, permit, _signPermit(permit, signer.key));
    }
}
