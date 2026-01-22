// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./SettlementSaleBaseTest.sol";

contract SettlementSaleWithdrawTest is SettlementSaleBaseTest {
    function setUp() public override {
        super.setUp();

        openCommitment();
        doBid({user: alice, amount: 5000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 5000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 10000e6, price: 10, token: usdt});
        doBid({user: charlie, amount: 10000e6, price: 10, token: usdt});

        closeCommitment();
        openCancellation();
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
    }

    function testWithdraw_WithRefunds_TransfersToAllParties() public {
        finalizeSettlement();

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.WalletRefunded(aliceID, alice, address(usdc), 3000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.EntityRefunded(aliceID, 3000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.WalletRefunded(charlieID, charlie, address(usdt), 10000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.EntityRefunded(charlieID, 10000e6);

        bytes16[] memory entityIDs = new bytes16[](2);
        entityIDs[0] = aliceID;
        entityIDs[1] = charlieID;

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        vm.prank(admin);
        sale.withdraw();

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.WalletRefunded(bobID, bob, address(usdt), 4000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.EntityRefunded(bobID, 4000e6);

        entityIDs = new bytes16[](1);
        entityIDs[0] = bobID;

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        assertTokenBalances({owner: alice, usdcAmount: 3000e6, usdtAmount: 0});
        assertTokenBalances({owner: bob, usdcAmount: 0, usdtAmount: 4000e6});
        assertTokenBalances({owner: charlie, usdcAmount: 0, usdtAmount: 10000e6});
        assertTokenBalances({owner: receiver, usdcAmount: 7000e6, usdtAmount: 1000e6});
        assertTokenBalances({owner: address(sale), usdcAmount: 0, usdtAmount: 0});
    }

    function testWithdraw_AfterReceiverChange_SendsToNewReceiver() public {
        finalizeSettlement();

        address newReceiver = makeAddr("newReceiver");
        vm.prank(admin);
        sale.setProceedsReceiver(newReceiver);
        assertEq(sale.proceedsReceiver(), newReceiver);

        vm.startPrank(admin);
        sale.withdraw();

        assertTokenBalances({owner: newReceiver, usdcAmount: 7000e6, usdtAmount: 1000e6});
        assertTokenBalances({owner: receiver, usdcAmount: 0, usdtAmount: 0});
    }

    function testWithdraw_Twice_DoesNothing() public {
        finalizeSettlement();

        vm.startPrank(admin);
        sale.withdraw();

        // Second call succeeds but does nothing since everything is already withdrawn
        sale.withdraw();

        // Verify the total withdrawn is still correct (7000 USDC + 1000 USDT = 8000 total)
        assertEq(sale.withdrawnAmount(), 8000e6);
        assertTokenBalances({owner: receiver, usdcAmount: 7000e6, usdtAmount: 1000e6});
    }

    function testWithdraw_WrongStage_Reverts() public {
        vm.expectRevert(encodeInvalidStage(SettlementSale.Stage.Settlement, SettlementSale.Stage.Done));
        vm.prank(admin);
        sale.withdraw();
    }

    function testwithdrawPartial_SingleToken() public {
        finalizeSettlement();

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.ProceedsWithdrawn(receiver, address(usdc), 3000e6);

        vm.prank(admin);
        sale.withdrawPartial(usdc, 3000e6);

        assertEq(sale.withdrawnAmount(), 3000e6);
        assertTokenBalances({owner: receiver, usdcAmount: 3000e6, usdtAmount: 0});
    }

    function testwithdrawPartial_MultiplewithdrawPartialals() public {
        finalizeSettlement();

        vm.startPrank(admin);

        // First partial withdrawal of USDC
        sale.withdrawPartial(usdc, 2000e6);
        assertEq(sale.withdrawnAmount(), 2000e6);
        assertTokenBalances({owner: receiver, usdcAmount: 2000e6, usdtAmount: 0});

        // Second partial withdrawal of USDC
        sale.withdrawPartial(usdc, 3000e6);
        assertEq(sale.withdrawnAmount(), 5000e6);
        assertTokenBalances({owner: receiver, usdcAmount: 5000e6, usdtAmount: 0});

        // Partial withdrawal of USDT
        sale.withdrawPartial(usdt, 500e6);
        assertEq(sale.withdrawnAmount(), 5500e6);
        assertTokenBalances({owner: receiver, usdcAmount: 5000e6, usdtAmount: 500e6});

        // Withdraw remaining via full withdraw
        sale.withdraw();
        assertEq(sale.withdrawnAmount(), 8000e6);
        assertTokenBalances({owner: receiver, usdcAmount: 7000e6, usdtAmount: 1000e6});
    }

    function testwithdrawPartial_ExceedsAvailable_Reverts() public {
        finalizeSettlement();

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(SettlementSale.WithdrawalExceedsAvailable.selector, address(usdc), 10000e6, 7000e6)
        );
        sale.withdrawPartial(usdc, 10000e6);
    }

    function testwithdrawPartial_InvalidToken_Reverts() public {
        finalizeSettlement();

        IERC20 fakeToken = IERC20(makeAddr("fakeToken"));

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidPaymentToken.selector, address(fakeToken)));
        sale.withdrawPartial(fakeToken, 1000e6);
    }

    function testwithdrawPartial_WrongStage_Reverts() public {
        vm.expectRevert(encodeInvalidStage(SettlementSale.Stage.Settlement, SettlementSale.Stage.Done));
        vm.prank(admin);
        sale.withdrawPartial(usdc, 1000e6);
    }

    function testwithdrawPartial_WrongRole_Reverts() public {
        finalizeSettlement();

        vm.prank(alice);
        vm.expectRevert();
        sale.withdrawPartial(usdc, 1000e6);
    }

    function testWithdrawnAmountByToken() public {
        finalizeSettlement();

        vm.startPrank(admin);
        sale.withdrawPartial(usdc, 3000e6);
        sale.withdrawPartial(usdt, 500e6);
        vm.stopPrank();

        TokenAmount[] memory withdrawn = sale.withdrawnAmountByToken();
        assertEq(withdrawn.length, 2);
        assertEq(withdrawn[0].token, address(usdc));
        assertEq(withdrawn[0].amount, 3000e6);
        assertEq(withdrawn[1].token, address(usdt));
        assertEq(withdrawn[1].amount, 500e6);
    }
}

