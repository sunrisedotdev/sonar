// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./SettlementSaleBaseTest.sol";

contract SettlementSaleEdgeCasesTest is SettlementSaleBaseTest {
    function testSetAllocation_AfterReopenAuction_UpdatesCorrectly() public {
        openAuction();

        // Disable auto close
        vm.prank(manager);
        sale.setCloseAuctionAtTimestamp(uint64(0));

        // Alice commits {500 USDC, 10000 USDT} = 10500 total
        // Bid 500 USDC
        doBid({user: alice, token: usdc, amount: 1000e6, price: 10});

        // Bid 2000 USDT (total commitment now 3000)
        doBid({user: alice, token: usdt, amount: 3000e6, price: 10});

        // Verify state after first bids
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 3000e6, "total commitment should be 3000");

        // Close auction and open settlement
        closeAuction();
        openSettlement();

        // Set allocation: U1 gets allocation of 2500
        // Explicitly allocate {1000 USDC, 1500 USDT}
        IOffchainSettlement.Allocation[] memory allocations1 = new IOffchainSettlement.Allocation[](2);
        allocations1[0] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: aliceID, wallet: alice, token: address(usdc), acceptedAmount: 1000e6
        });
        allocations1[1] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: aliceID, wallet: alice, token: address(usdt), acceptedAmount: 1500e6
        });

        vm.prank(settler);
        sale.setAllocations({allocations: allocations1, allowOverwrite: false});

        // Verify allocation was set correctly
        assertEq(
            sale.walletStateByAddress(alice).acceptedAmountByToken,
            toTokenAmounts({usdcAmount: 1000e6, usdtAmount: 1500e6})
        );
        assertEq(sale.totalAcceptedAmountByToken(), toTokenAmounts({usdcAmount: 1000e6, usdtAmount: 1500e6}));

        // Re-open auction manually
        vm.prank(admin);
        sale.unsafeSetStage(SettlementSale.Stage.Auction);
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Auction), "auction should be open");

        // User commits 4000 more USDC (total USDC now 5000, total commitment 7000)
        doBid({user: alice, token: usdc, amount: 7000e6, price: 10});

        // Verify state after additional bid
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 7000e6, "total commitment should be 7000");

        // Reopen settlement
        vm.prank(admin);
        sale.unsafeSetStage(SettlementSale.Stage.Settlement);

        // Update allocation: U1 allocation updated to 5000 total
        // Explicitly set {5000 USDC, 0 USDT}
        // Net change: USDC should go from 1000 to 5000 (+4000), USDT should go from 1500 to 0 (-1500)

        IOffchainSettlement.Allocation[] memory allocations2 = new IOffchainSettlement.Allocation[](2);
        allocations2[0] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: aliceID, wallet: alice, token: address(usdc), acceptedAmount: 5000e6
        });
        allocations2[1] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: aliceID, wallet: alice, token: address(usdt), acceptedAmount: 0
        });

        vm.prank(settler);
        sale.setAllocations({allocations: allocations2, allowOverwrite: true});

        // Check final state
        assertEq(
            sale.walletStateByAddress(alice).acceptedAmountByToken, toTokenAmounts({usdcAmount: 5000e6, usdtAmount: 0})
        );
        assertEq(sale.totalAcceptedAmountByToken(), toTokenAmounts({usdcAmount: 5000e6, usdtAmount: 0}));
    }
}
