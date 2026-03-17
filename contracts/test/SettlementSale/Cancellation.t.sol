// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./SettlementSaleBaseTest.t.sol";

contract SettlementSaleCancellationTest is SettlementSaleBaseTest {
    struct State {
        uint256 bidAmount;
        bool refunded;
        TokenAmount[] userBalance;
        TokenAmount[] saleBalance;
        TokenAmount[] committedAmountByToken;
    }

    function getState(bytes16 entityID, address wallet) internal view returns (State memory) {
        SettlementSale.EntityStateView memory entityState = sale.entityStateByID(entityID);
        SettlementSale.WalletStateView memory walletState = sale.walletStateByAddress(wallet);
        return State({
            bidAmount: entityState.currentBid.amount,
            refunded: entityState.refunded,
            userBalance: tokenBalances(wallet),
            saleBalance: tokenBalances(address(sale)),
            committedAmountByToken: walletState.committedAmountByToken
        });
    }

    function cancelBidSuccess(address user) internal {
        bytes16 entityID = addressToEntityID(user);
        State memory stateBefore = getState(entityID, user);

        vm.prank(user);
        sale.cancelBid();

        State memory stateAfter = getState(entityID, user);

        assertEq(stateAfter.refunded, true, "refunded should be true");

        assertEq(
            stateAfter.userBalance,
            add(stateBefore.userBalance, stateBefore.committedAmountByToken),
            "user balance after cancellation"
        );
        assertEq(
            stateAfter.saleBalance,
            sub(stateBefore.saleBalance, stateBefore.committedAmountByToken),
            "sale balance after cancellation"
        );
    }

    function cancelBidFail(address user, bytes memory err) internal {
        vm.expectRevert(err);
        vm.prank(user);
        sale.cancelBid();
    }

    function testCancelBid_SingleUser_RefundsFullCommitment() public {
        openCommitment();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        openCancellation();

        cancelBidSuccess(alice);
    }

    function testCancelBid_Twice_Reverts() public {
        openCommitment();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        openCancellation();

        cancelBidSuccess(alice);
        cancelBidFail(alice, abi.encodeWithSelector(SettlementSale.AlreadyRefunded.selector, aliceID));
    }

    function testCancelBid_AfterCancellationPhase_Reverts() public {
        openCommitment();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        openCancellation();
        openSettlement();

        cancelBidFail(alice, encodeInvalidStage(SettlementSale.Stage.Settlement, SettlementSale.Stage.Cancellation));
    }

    function testCancelBid_DuringWrongStage_RevertsOrSucceeds(uint8 s) public {
        openCommitment();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        SettlementSale.Stage stage = SettlementSale.Stage(bound(s, 0, uint8(SettlementSale.Stage.Done)));

        vm.prank(admin);
        sale.unsafeSetStage(stage);

        if (stage == SettlementSale.Stage.Cancellation) {
            cancelBidSuccess(alice);
        } else {
            cancelBidFail(alice, encodeInvalidStage(stage, SettlementSale.Stage.Cancellation));
        }
    }

    function testCancelBid_EntityWithoutBid_Reverts() public {
        openCommitment();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        openCancellation();

        cancelBidFail(bob, abi.encodeWithSelector(SettlementSale.WalletNotInitialized.selector, bob));
    }

    function testCancelBid_WhilePaused_Reverts() public {
        openCommitment();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        openCancellation();

        vm.prank(pauser);
        sale.pause();

        cancelBidFail(alice, abi.encodeWithSelector(SettlementSale.SalePaused.selector));

        vm.prank(admin);
        sale.setPaused(false);

        cancelBidSuccess(alice);
    }

    function testCancelBid_WithUSDT_Success() public {
        openCommitment();

        // Alice bids with USDT
        doBid({user: alice, amount: 2000e6, price: 10, token: usdt});

        openCancellation();

        cancelBidSuccess(alice);
    }

    function testCancelBid_MultipleUsersWithDifferentTokens_Success() public {
        openCommitment();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 3000e6, price: 10, token: usdt});

        openCancellation();

        cancelBidSuccess(alice);
        cancelBidSuccess(bob);

        assertEq(usdc.balanceOf(alice), 2000e6, "alice should get USDC back");
        assertEq(usdt.balanceOf(bob), 3000e6, "bob should get USDT back");
        assertTrue(sale.entityStateByID(aliceID).refunded);
        assertTrue(sale.entityStateByID(bobID).refunded);
    }

    function testCancelBid_FromSecondWallet_RefundsBothWallets() public {
        address aliceWallet2 = makeAddr("aliceWallet2");

        openCommitment();

        // Alice bids with first wallet using USDC
        doBid({entityID: aliceID, user: alice, amount: 2000e6, price: 10, token: usdc});

        // Alice bids with second wallet using USDT (same entity)
        doBid({entityID: aliceID, user: aliceWallet2, amount: 5000e6, price: 10, token: usdt});

        openCancellation();

        // Second wallet cancels the entire entity's bid
        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.CommitmentReduced(aliceID, alice, address(usdc), 2000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.CommitmentReduced(aliceID, aliceWallet2, address(usdt), 3000e6);

        vm.prank(aliceWallet2);
        sale.cancelBid();

        // Both wallets should receive their committed amounts back
        assertEq(usdc.balanceOf(alice), 2000e6, "alice wallet1 should get USDC back");
        assertEq(usdt.balanceOf(aliceWallet2), 3000e6, "alice wallet2 should get USDT back");
        assertTrue(sale.entityStateByID(aliceID).refunded);
    }

    function testCancelBid_WithLockup_StillRefunds() public {
        // Verify that lockup status doesn't affect cancellation - users can still cancel
        // and get full refunds even if they had lockup enabled on their bid
        openCommitment();
        doBid({user: alice, amount: 2000e6, price: 10, lockup: true, token: usdc});

        // Verify lockup is set
        assertTrue(sale.entityStateByID(aliceID).currentBid.lockup, "lockup should be enabled");

        openCancellation();

        // Cancel should still work and refund full amount
        cancelBidSuccess(alice);

        // Verify refund occurred
        assertEq(usdc.balanceOf(alice), 2000e6, "alice should get full USDC refund");
        assertTrue(sale.entityStateByID(aliceID).refunded, "should be refunded");
    }
}

