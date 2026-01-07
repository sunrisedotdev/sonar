// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./SettlementSaleBaseTest.sol";

contract SettlementSaleRefundsTest is SettlementSaleBaseTest {
    function setUp() public override {
        super.setUp();
        openAuction();
    }

    function _defaultSetup() internal {
        doBid({user: alice, amount: 5000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 5000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 10000e6, price: 10, token: usdt});
        doBid({user: charlie, amount: 10000e6, price: 10, token: usdt});

        closeAuction();
        openSettlement();

        // alice    committed 5k USDC           -> allocated 2k USDC
        doSetAllocation(alice, usdc, 2000e6);

        // bob      committed 5k USDC + 5k USDT -> allocated 5k USDC + 1k USDT
        doSetAllocation(bob, usdc, 5000e6);
        doSetAllocation(bob, usdt, 1000e6);

        // charlie  committed 10k USDT          -> allocated 0

        // to make sure we can do simple balance assertions later
        assertTokenBalances({owner: alice, usdcAmount: 0, usdtAmount: 0});
        assertEq(usdc.balanceOf(bob), 0);
        assertEq(usdc.balanceOf(charlie), 0);

        finalizeSettlement();
    }

    function testProcessRefunds_Twice_Reverts() public {
        _defaultSetup();

        bytes16[] memory entityIDs = new bytes16[](2);
        entityIDs[0] = aliceID;
        entityIDs[1] = bobID;

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        entityIDs = new bytes16[](2);
        entityIDs[0] = charlieID;
        entityIDs[1] = bobID; // repeated

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.AlreadyRefunded.selector, bobID));
        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);
    }

    function testProcessRefunds_TwiceWithSkipping_SkipsAlreadyRefunded() public {
        _defaultSetup();

        bytes16[] memory entityIDs = new bytes16[](2);
        entityIDs[0] = aliceID;
        entityIDs[1] = bobID;

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        assertTokenBalances({owner: alice, usdcAmount: 3000e6, usdtAmount: 0});
        assertTokenBalances({owner: bob, usdcAmount: 0, usdtAmount: 4000e6});
        assertTokenBalances({owner: charlie, usdcAmount: 0, usdtAmount: 0});
        assertTokenBalances({owner: address(sale), usdcAmount: 7000e6, usdtAmount: 11000e6});

        entityIDs = new bytes16[](2);
        entityIDs[0] = charlieID;
        entityIDs[1] = bobID; // repeated

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.WalletRefunded(charlieID, charlie, usdt, 10000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.EntityRefunded(charlieID, 10000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.RefundedEntitySkipped(bobID);

        vm.prank(refunder);
        sale.processRefunds(entityIDs, true); // this time we're skipping the already refunded entity

        assertTokenBalances({owner: alice, usdcAmount: 3000e6, usdtAmount: 0});
        assertTokenBalances({owner: bob, usdcAmount: 0, usdtAmount: 4000e6});
        assertTokenBalances({owner: charlie, usdcAmount: 0, usdtAmount: 10000e6});
        assertTokenBalances({owner: address(sale), usdcAmount: 7000e6, usdtAmount: 1000e6});
    }

    function testProcessRefunds_WrongStage_Reverts() public {
        closeAuction();
        openSettlement();

        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = aliceID;

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.Settlement));
        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);
    }

    function testClaimRefund_WhenEnabled_Success() public {
        _defaultSetup();

        // Claim refund should work when enabled
        uint256 balanceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        sale.claimRefund();

        assertEq(usdc.balanceOf(alice), balanceBefore + 3000e6);
        assertTrue(sale.entityStateByID(aliceID).refunded);
    }

    function testClaimRefund_WhenDisabled_Reverts() public {
        _defaultSetup();

        // Disable claim refund
        vm.prank(admin);
        sale.setClaimRefundEnabled(false);

        // Claim refund should fail when disabled
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.ClaimRefundDisabled.selector));
        vm.prank(alice);
        sale.claimRefund();

        // But refunder can still process refunds
        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = aliceID;

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        assertTrue(sale.entityStateByID(aliceID).refunded);
        assertEq(usdc.balanceOf(alice), 3000e6);
    }

    function testClaimRefund_AfterReEnabled_Success() public {
        _defaultSetup();

        // Disable claim refund
        vm.prank(admin);
        sale.setClaimRefundEnabled(false);

        // Claim refund should fail when disabled
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.ClaimRefundDisabled.selector));
        vm.prank(alice);
        sale.claimRefund();

        // Re-enable claim refund
        vm.prank(admin);
        sale.setClaimRefundEnabled(true);

        // Now claim refund should work
        uint256 balanceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        sale.claimRefund();

        assertEq(usdc.balanceOf(alice), balanceBefore + 3000e6);
    }

    function testClaimRefund_Twice_Reverts() public {
        _defaultSetup();

        // First claim should succeed
        uint256 balanceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        sale.claimRefund();

        assertEq(usdc.balanceOf(alice), balanceBefore + 3000e6);
        assertTrue(sale.entityStateByID(aliceID).refunded);

        // Second claim should fail
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.AlreadyRefunded.selector, aliceID));
        vm.prank(alice);
        sale.claimRefund();

        // Balance should not change
        assertEq(usdc.balanceOf(alice), balanceBefore + 3000e6);
    }

    function testProcessRefunds_AfterClaimed_Reverts() public {
        _defaultSetup();

        // User claims their own refund
        vm.prank(alice);
        sale.claimRefund();

        assertTrue(sale.entityStateByID(aliceID).refunded);

        // Refunder tries to process refund for already refunded user
        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = aliceID;

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.AlreadyRefunded.selector, aliceID));
        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);
    }

    function testClaimRefund_AfterProcessed_Reverts() public {
        _defaultSetup();

        // Refunder processes refund
        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = aliceID;

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        assertTrue(sale.entityStateByID(aliceID).refunded);
        assertEq(usdc.balanceOf(alice), 3000e6);

        // User tries to claim refund after it's already been processed
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.AlreadyRefunded.selector, aliceID));
        vm.prank(alice);
        sale.claimRefund();

        // Balance should not change
        assertEq(usdc.balanceOf(alice), 3000e6);
    }

    function testClaimRefund_WhenNotInitialized_Reverts() public {
        _defaultSetup();

        // Dave never placed a bid, so claiming refund should revert
        address dave = makeAddr("dave");

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.WalletNotInitialized.selector, dave));
        vm.prank(dave);
        sale.claimRefund();

        // The zero entity should NOT be marked as refunded
        assertFalse(sale.entityStateByID(bytes16(0)).refunded);
    }

    function testProcessRefunds_UninitializedEntity_Reverts() public {
        _defaultSetup();

        // Try to process refund for an entity that never bid
        bytes16 fakeEntityID = bytes16(keccak256("fake"));
        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = fakeEntityID;

        // Should revert with EntityNotInitialized
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.EntityNotInitialized.selector, fakeEntityID));
        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        // Entity should NOT be marked as refunded
        assertFalse(sale.entityStateByID(fakeEntityID).refunded);
    }

    function testProcessRefunds_UninitializedEntityWithSkip_StillReverts() public {
        _defaultSetup();

        // Try to process refund for an entity that never bid, even with skipAlreadyRefunded=true
        bytes16 fakeEntityID = bytes16(keccak256("fake"));
        bytes16[] memory entityIDs = new bytes16[](2);
        entityIDs[0] = aliceID;
        entityIDs[1] = fakeEntityID;

        // Should revert with EntityNotInitialized regardless of skipAlreadyRefunded flag
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.EntityNotInitialized.selector, fakeEntityID));
        vm.prank(refunder);
        sale.processRefunds(entityIDs, true);

        // Alice should NOT be refunded since the whole tx reverted
        assertFalse(sale.entityStateByID(aliceID).refunded);
    }

    function testClaimRefund_WhilePaused_Reverts() public {
        _defaultSetup();

        vm.prank(pauser);
        sale.pause();

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.SalePaused.selector));
        vm.prank(alice);
        sale.claimRefund();

        // Unpause and claim should work
        vm.prank(admin);
        sale.setPaused(false);

        vm.prank(alice);
        sale.claimRefund();
        assertTrue(sale.entityStateByID(aliceID).refunded);
    }

    function testProcessRefunds_EmptyArray_Succeeds() public {
        _defaultSetup();

        bytes16[] memory emptyEntityIDs = new bytes16[](0);

        // Should succeed with no-op
        vm.prank(refunder);
        sale.processRefunds(emptyEntityIDs, false);

        // Alice should not be refunded
        assertFalse(sale.entityStateByID(aliceID).refunded);
        assertEq(usdc.balanceOf(alice), 0);
    }

    function testRefund_MultipleWalletsPerEntity_RefundsAllWallets() public {
        address aliceWallet2 = makeAddr("aliceWallet2");

        // Alice bids 2000 USDC with her first wallet
        doBid({entityID: aliceID, user: alice, token: usdc, amount: 2000e6, price: 10});

        // Alice bids additional 3000 USDT with her second wallet (bringing her total commitment to 5000 USD)
        doBid({entityID: aliceID, user: aliceWallet2, token: usdt, amount: 5000e6, price: 10});

        closeAuction();
        openSettlement();

        // Set allocations per wallet/token
        doSetAllocation(aliceID, alice, usdc, 1000e6);
        doSetAllocation(aliceID, aliceWallet2, usdt, 2000e6);

        finalizeSettlement();

        // Process refunds - should refund both wallets
        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = aliceID;

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.WalletRefunded(aliceID, alice, usdc, 1000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.WalletRefunded(aliceID, aliceWallet2, usdt, 1000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.EntityRefunded(aliceID, 2000e6);

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        // Alice's first wallet should get 1000 USDC refund (2000 committed - 1000 accepted)
        assertEq(usdc.balanceOf(alice), 1000e6, "alice wallet1 USDC refund");
        // Alice's second wallet should get 1000 USDT refund (3000 committed - 2000 accepted)
        assertEq(usdt.balanceOf(aliceWallet2), 1000e6, "alice wallet2 USDT refund");
    }
}

