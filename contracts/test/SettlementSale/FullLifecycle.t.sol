// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./SettlementSaleBaseTest.sol";

contract SettlementSaleFullLifecycleFuzzTest is SettlementSaleBaseTest {
    struct FuzzedAuctionBids {
        address wallet;
        uint256 tokenIdx;
        SettlementSale.Bid bid;
    }

    mapping(address => SettlementSale.Bid) lastBid;

    bytes16[] entitiesToBeRefunded;

    function test_Success_Fuzzed(FuzzedAuctionBids[] memory auctionBids, uint128 manuallySentUSDC) public {
        deal(address(usdc), address(sale), manuallySentUSDC);

        // we're sending USDC manually to the contract to demonstrate that it doesn't throw off the internal book keeping.
        checkInvariants(manuallySentUSDC);
        openAuction();

        // Sending the bids according to the fuzzed input.
        // New bids are clamped to the previous bid's price and amount to ensure that the new bid is valid
        uint256 totalCommittedAmountExpected = 0;
        for (uint256 i = 0; i < auctionBids.length; i++) {
            FuzzedAuctionBids memory bid = auctionBids[i];
            if (isDisallowedAddress(bid.wallet)) {
                continue;
            }

            SettlementSale.Bid memory previousBid = lastBid[bid.wallet];

            bid.bid.price = uint64(bound(bid.bid.price, Math.max(SALE_MIN_PRICE, previousBid.price), SALE_MAX_PRICE));
            bid.bid.amount =
                uint256(bound(bid.bid.amount, Math.max(SALE_MIN_AMOUNT, previousBid.amount), SALE_MAX_AMOUNT));
            // Lockup can only be enabled, never disabled once set
            if (previousBid.lockup) {
                bid.bid.lockup = true;
            }

            bid.tokenIdx = uint256(bound(bid.tokenIdx, 0, paymentTokens.length - 1));
            IERC20 token = paymentTokens[bid.tokenIdx];

            uint256 amountDelta = bid.bid.amount - previousBid.amount;
            deal(address(token), bid.wallet, amountDelta);
            doBid({user: bid.wallet, token: token, price: bid.bid.price, amount: bid.bid.amount, lockup: bid.bid.lockup});

            // update test counters
            totalCommittedAmountExpected += amountDelta;
            lastBid[bid.wallet] = bid.bid;

            bytes16 entityID = addressToEntityID(bid.wallet);
            assertEq(sale.entityStateByID(entityID).currentBid, lastBid[bid.wallet], "active bid should be updated");
            assertEq(usdc.balanceOf(bid.wallet), 0, "balance of bidder after bid");
        }

        checkInvariants(manuallySentUSDC);

        assertEq(sale.totalCommittedAmount(), totalCommittedAmountExpected, "total auction commitments after bids");
        assertEq(sale.totalAcceptedAmount(), 0, "total allocated usdc after bids");

        // assume we have at least one commitment so the auction can be closed
        vm.assume(sale.totalCommittedAmount() > 0);
        closeAuction();

        // open the cancellation stage, so some users can cancel their bids
        openCancellation();
        bytes16[] memory entities = sale.allEntities();
        for (uint256 i = 0; i < entities.length; i++) {
            bytes16 entityID = entities[i];
            SettlementSale.EntityStateView memory entityState = sale.entityStateByID(entityID);
            // Get first wallet for this entity (in this test, each entity has one wallet)
            address wallet = entityState.walletStates[0].addr;
            bytes32 rand = keccak256(abi.encode(i, wallet, "cancel"));

            // do nothing for 80% of the wallets
            if (uint256(rand) % 100 < 80) {
                continue;
            }

            // 20% of wallets will cancel their bid
            vm.prank(wallet);
            sale.cancelBid();
        }

        checkInvariants(manuallySentUSDC);

        // open the settlement stage and post allocations for the contract
        openSettlement();
        uint256 totalAcceptedAmount = 0;
        for (uint256 i = 0; i < entities.length; i++) {
            bytes16 entityID = entities[i];
            SettlementSale.EntityStateView memory entityState = sale.entityStateByID(entityID);
            address wallet = entityState.walletStates[0].addr;
            bytes32 rand = keccak256(abi.encode(i, wallet, "allocation"));

            // skip if the entity has already been refunded in the cancellation stage
            if (entityState.refunded) {
                continue;
            }

            // Get the committed amounts per token for this wallet
            TokenAmount[] memory committedByToken = entityState.walletStates[0].committedAmountByToken;

            // Calculate how much to allocate from each token based on the random accepted amount
            uint256 totalCommitted = committedByToken[0].amount + committedByToken[1].amount;
            uint256 acceptedAmount = uint256(bound(uint256(rand), 0, totalCommitted));
            if (acceptedAmount == 0) {
                continue;
            }

            // Distribute allocation across tokens, first allocate from USDC, then from USDT
            uint256 remainingToAllocate = acceptedAmount;
            for (uint256 j = 0; j < committedByToken.length; j++) {
                IERC20 token = IERC20(committedByToken[j].token);
                uint256 committedForToken = committedByToken[j].amount;

                if (committedForToken == 0) {
                    continue;
                }

                uint256 allocationForToken = Math.min(remainingToAllocate, committedForToken);
                if (allocationForToken > 0) {
                    doSetAllocation(wallet, token, allocationForToken);
                    remainingToAllocate -= allocationForToken;
                }

                if (remainingToAllocate == 0) {
                    break;
                }
            }

            totalAcceptedAmount += acceptedAmount;
        }

        assertEq(sale.totalAcceptedAmount(), totalAcceptedAmount, "total allocated usdc after allocations");
        checkInvariants(manuallySentUSDC);

        finalizeSettlement();

        // process refunds
        // we want half of the entities to claim their own refund, while the other half will be refunded by the refunder
        for (uint256 i = 0; i < entities.length; i++) {
            bytes16 entityID = entities[i];
            SettlementSale.EntityStateView memory entityState = sale.entityStateByID(entityID);
            address wallet = entityState.walletStates[0].addr;
            bytes32 rand = keccak256(abi.encode(i, wallet, "refund"));

            // skip if the entity has already been refunded in the cancellation stage
            if (entityState.refunded) {
                continue;
            }

            if (uint256(rand) % 100 < 50) {
                // claim refund
                vm.prank(wallet);
                sale.claimRefund();
                continue;
            }

            entitiesToBeRefunded.push(entityID);
        }

        vm.prank(refunder);
        sale.processRefunds(entitiesToBeRefunded, false);

        // check that all entities are refunded
        SettlementSale.EntityStateView[] memory entityStates = sale.allEntityStates();
        for (uint256 i = 0; i < entityStates.length; i++) {
            SettlementSale.EntityStateView memory entityState = entityStates[i];
            assertTrue(entityState.refunded, "entity should be refunded");
        }

        checkInvariants(manuallySentUSDC);

        // withdrawing funds
        // double checking that the initial receiver balance is 0 so the next check is valid
        assertTokenBalances({
            owner: receiver,
            usdcAmount: 0,
            usdtAmount: 0,
            message: "receiver balance should be 0 before withdraw"
        });

        vm.prank(admin);
        sale.withdraw();

        assertEq(
            usdc.balanceOf(receiver) + usdt.balanceOf(receiver),
            totalAcceptedAmount,
            "receiver balance should be the total allocated usdc after withdraw"
        );

        // the manually sent usdc should still be in the sale after everything is withdrawn
        assertTokenBalances({
            owner: address(sale),
            usdcAmount: manuallySentUSDC,
            usdtAmount: 0,
            message: "the manually sent usdc is still in the sale after withdrawal"
        });

        // recover any manually sent usdcs
        address recoverReceiver = makeAddr("recoverReceiver");
        vm.prank(recoverer);
        sale.recoverTokens(usdc, manuallySentUSDC, recoverReceiver);
        assertEq(
            usdc.balanceOf(recoverReceiver),
            manuallySentUSDC,
            "recoverReceiver balance should be 1M after usdc recovery"
        );

        assertEq(usdc.balanceOf(address(sale)), 0, "sale balance is 0 at the end");
    }

    function checkInvariants(uint256 manuallySentUSDC) internal view {
        bytes16[] memory entities = sale.allEntities();
        SettlementSale.EntityStateView[] memory entityStates = sale.allEntityStates();
        assertEq(entities.length, entityStates.length);

        // sum of auction commitments == total auction commitments
        uint256 sumAuctionCommitments = 0;
        for (uint256 i = 0; i < entityStates.length; i++) {
            sumAuctionCommitments += entityStates[i].currentBid.amount;
        }
        assertEq(sale.totalCommittedAmount(), sumAuctionCommitments, "total auction commitments");

        uint256 sumRefundedAmounts = 0;
        for (uint256 i = 0; i < entityStates.length; i++) {
            if (!entityStates[i].refunded) {
                continue;
            }
            sumRefundedAmounts +=
                entityStates[i].currentBid.amount - sum(entityStates[i].walletStates[0].acceptedAmountByToken);
        }
        assertEq(sale.totalRefundedAmount(), sumRefundedAmounts, "total refunded amount");

        assertEq(
            usdc.balanceOf(address(sale)) + usdt.balanceOf(address(sale)),
            sumAuctionCommitments - sumRefundedAmounts + manuallySentUSDC,
            "total balance of the sale"
        );
    }

    function isDisallowedAddress(address addr) internal view returns (bool) {
        return addr == address(0) || addr == address(sale) || addr == receiver;
    }
}
