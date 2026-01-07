// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./SettlementSaleBaseTest.sol";

contract SettlementSaleSettlementTest is SettlementSaleBaseTest {
    struct State {
        uint256 userAllocatedForToken;
        uint256 totalAcceptedAmount;
    }

    function getState(address wallet, IERC20 token) internal view returns (State memory) {
        TokenAmount[] memory acceptedAmountByToken = sale.walletStateByAddress(wallet).acceptedAmountByToken;

        uint256 userAllocatedForToken = 0;
        for (uint256 i = 0; i < acceptedAmountByToken.length; i++) {
            if (acceptedAmountByToken[i].token == address(token)) {
                userAllocatedForToken = acceptedAmountByToken[i].amount;
                break;
            }
        }

        return State({totalAcceptedAmount: sale.totalAcceptedAmount(), userAllocatedForToken: userAllocatedForToken});
    }

    function setAllocationSuccess(address wallet, IERC20 token, uint256 amount, bool allowOverwrite) internal {
        bytes16 entityID = addressToEntityID(wallet);
        State memory stateBefore = getState(wallet, token);

        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: entityID, wallet: wallet, token: address(token), acceptedAmount: amount
        });

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.AllocationSet(entityID, wallet, token, amount);

        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: allowOverwrite});

        State memory stateAfter = getState(wallet, token);
        assertEq(
            stateAfter.totalAcceptedAmount, stateBefore.totalAcceptedAmount + amount - stateBefore.userAllocatedForToken
        );
        assertEq(stateAfter.userAllocatedForToken, amount);
    }

    function setAllocationFail(
        address wallet,
        IERC20 token,
        uint256 amount,
        bool allowOverwrite,
        bytes memory err
    ) internal {
        bytes16 entityID = addressToEntityID(wallet);
        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: entityID, wallet: wallet, token: address(token), acceptedAmount: amount
        });

        vm.expectRevert(err);
        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: allowOverwrite});
    }

    function testSetAllocation_SingleUser_FullCommitment() public {
        openAuction();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        closeAuction();
        openSettlement();

        setAllocationSuccess(alice, usdc, 2000e6, false);

        assertEq(sale.totalAcceptedAmount(), 2000e6);
        assertEq(
            sale.walletStateByAddress(alice).acceptedAmountByToken, toTokenAmounts({usdcAmount: 2000e6, usdtAmount: 0})
        );
    }

    function testSetAllocation_SingleUserMultipleTokens_Success() public {
        openAuction();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdt});
        doBid({user: alice, amount: 5000e6, price: 10, token: usdc});

        closeAuction();
        openSettlement();

        // Alice committed 3000 USDC and 2000 USDT (total 5000, bid amount is 5000)
        // Set explicit allocations per token
        setAllocationSuccess(alice, usdc, 3000e6, false);
        setAllocationSuccess(alice, usdt, 1000e6, false);

        assertEq(
            sale.walletStateByAddress(alice).acceptedAmountByToken,
            toTokenAmounts({usdcAmount: 3000e6, usdtAmount: 1000e6})
        );
        assertEq(sale.totalAcceptedAmount(), 4000e6);
    }

    function testSetAllocation_MultipleUsersDifferentTokens_Success() public {
        openAuction();
        doBid({user: alice, amount: 3000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 5000e6, price: 10, token: usdt});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, usdc, 3000e6, false);
        setAllocationSuccess(bob, usdt, 4000e6, false);

        assertEq(sale.totalAcceptedAmount(), 7000e6);
        assertEq(
            sale.walletStateByAddress(alice).acceptedAmountByToken, toTokenAmounts({usdcAmount: 3000e6, usdtAmount: 0})
        );
        assertEq(
            sale.walletStateByAddress(bob).acceptedAmountByToken, toTokenAmounts({usdcAmount: 0, usdtAmount: 4000e6})
        );
    }

    function testSetAllocation_CanOverwrite_WhenAllowOverwriteIsTrue() public {
        openAuction();
        doBid({user: alice, amount: 3000e6, price: 10, token: usdc});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, usdc, 2000e6, false);
        setAllocationSuccess(alice, usdc, 0, true);

        assertEq(sale.totalAcceptedAmount(), 0);
        assertEq(sale.walletStateByAddress(alice).acceptedAmountByToken, toTokenAmounts({usdcAmount: 0, usdtAmount: 0}));

        setAllocationSuccess(alice, usdc, 3000e6, true);
        assertEq(sale.totalAcceptedAmount(), 3000e6);
        assertEq(
            sale.walletStateByAddress(alice).acceptedAmountByToken, toTokenAmounts({usdcAmount: 3000e6, usdtAmount: 0})
        );
    }

    function testSetAllocation_ExceedingCommitment_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});
        doBid({user: alice, amount: 2000e6, price: 10, token: usdt});

        closeAuction();
        openCancellation();
        openSettlement();

        // Alice committed 1000 USDC and 1000 USDT. Try to allocate more USDC than committed.
        setAllocationFail(
            alice,
            usdc,
            2000e6,
            false,
            abi.encodeWithSelector(
                SettlementSale.AllocationExceedsCommitment.selector, aliceID, alice, usdc, 2000e6, 1000e6
            )
        );
    }

    function testSetAllocation_NonExistingEntity_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        closeAuction();
        openCancellation();
        openSettlement();

        // Bob hasn't placed any bid, so the entity is not initialized
        setAllocationFail({
            wallet: bob,
            token: usdc,
            amount: 3000e6,
            allowOverwrite: true,
            err: abi.encodeWithSelector(SettlementSale.EntityNotInitialized.selector, bobID)
        });
    }

    function testSetAllocation_OverwriteWithoutOptIn_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, usdc, 1000e6, false);
        setAllocationFail({
            wallet: alice,
            token: usdc,
            amount: 0,
            allowOverwrite: false,
            err: abi.encodeWithSelector(SettlementSale.AllocationAlreadySet.selector, aliceID, 1000e6)
        });
        setAllocationSuccess(alice, usdc, 2000e6, true);
    }

    function testSetAllocation_WrongStage_Reverts() public {
        setAllocationFail({
            wallet: bob,
            token: usdc,
            amount: 3000e6,
            allowOverwrite: false,
            err: abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.PreOpen)
        });

        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});
        setAllocationFail({
            wallet: bob,
            token: usdc,
            amount: 3000e6,
            allowOverwrite: false,
            err: abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.Auction)
        });

        closeAuction();
        openCancellation();
        openSettlement();

        vm.startPrank(admin);
        sale.finalizeSettlement(sale.totalAcceptedAmount());
        vm.stopPrank();

        setAllocationFail({
            wallet: bob,
            token: usdc,
            amount: 3000e6,
            allowOverwrite: false,
            err: abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.Done)
        });
    }

    function testFinalizeSettlement_MismatchingTotal_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, usdc, 1000e6, false);

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.UnexpectedTotalAcceptedAmount.selector, 2000e6, 1000e6));
        vm.prank(admin);
        sale.finalizeSettlement(2000e6);

        vm.prank(admin);
        sale.finalizeSettlement(1000e6);
    }

    function testSetAllocation_AfterRefund_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, usdc, 1000e6, false);
        finalizeSettlement();

        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = aliceID;

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        vm.prank(admin);
        sale.unsafeSetStage(SettlementSale.Stage.Settlement);

        setAllocationFail({
            wallet: alice,
            token: usdc,
            amount: 2000e6,
            allowOverwrite: true,
            err: abi.encodeWithSelector(SettlementSale.AlreadyRefunded.selector, aliceID)
        });
    }

    function testSetAllocation_AfterCancellation_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        closeAuction();
        openCancellation();

        vm.prank(alice);
        sale.cancelBid();

        openSettlement();
        setAllocationFail({
            wallet: alice,
            token: usdc,
            amount: 2000e6,
            allowOverwrite: true,
            err: abi.encodeWithSelector(SettlementSale.AlreadyRefunded.selector, aliceID)
        });
    }

    function testOpenSettlement_FromClosed_Success() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        closeAuction();
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Closed));

        // Can open settlement directly from Closed stage
        vm.prank(admin);
        sale.openSettlement();

        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Settlement));
    }

    function testSetAllocation_EmptyArray_Succeeds() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        closeAuction();
        openSettlement();

        IOffchainSettlement.Allocation[] memory emptyAllocations = new IOffchainSettlement.Allocation[](0);

        // Should succeed with no-op
        vm.prank(settler);
        sale.setAllocations({allocations: emptyAllocations, allowOverwrite: false});

        assertEq(sale.totalAcceptedAmount(), 0);
    }

    function testFinalizeSettlement_ZeroAccepted_Success() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 2000e6, price: 15, token: usdt});

        closeAuction();
        openSettlement();

        // Don't set any allocations, finalize with 0
        vm.prank(admin);
        sale.finalizeSettlement(0);

        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Done));
        assertEq(sale.totalAcceptedAmount(), 0);
    }

    function testFinalizeSettlement_AfterAllCancelled_Success() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 2000e6, price: 15, token: usdt});

        closeAuction();
        openCancellation();

        vm.prank(alice);
        sale.cancelBid();

        vm.prank(bob);
        sale.cancelBid();

        openSettlement();

        vm.prank(admin);
        sale.finalizeSettlement(0);

        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Done));

        // Withdraw should work but transfer 0
        vm.prank(admin);
        sale.withdraw();

        assertEq(usdc.balanceOf(receiver), 0);
        assertEq(usdt.balanceOf(receiver), 0);
    }

    function testSetAllocation_TokenNeverCommitted_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        closeAuction();
        openSettlement();

        // Try to set allocation for USDT (which alice never committed)
        setAllocationFail(
            alice,
            usdt,
            100e6,
            false,
            abi.encodeWithSelector(SettlementSale.AllocationExceedsCommitment.selector, aliceID, alice, usdt, 100e6, 0)
        );
    }

    function testSetAllocation_ZeroForTokenNeverCommitted_Success() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        closeAuction();
        openSettlement();

        // Setting 0 allocation for USDT should succeed (0 <= 0)
        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: aliceID, wallet: alice, token: address(usdt), acceptedAmount: 0
        });

        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: false});

        assertEq(sale.walletStateByAddress(alice).acceptedAmountByToken, toTokenAmounts({usdcAmount: 0, usdtAmount: 0}));
    }

    function testSetAllocation_WalletNotAssociatedWithEntity_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 2000e6, price: 10, token: usdc});

        closeAuction();
        openSettlement();

        // Try to set allocation for Alice's entity but with Bob's wallet
        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: aliceID, wallet: bob, token: address(usdc), acceptedAmount: 500e6
        });

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.WalletNotAssociatedWithEntity.selector, bob, aliceID));
        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: false});
    }

    function testSetAllocation_InvalidPaymentToken_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        closeAuction();
        openSettlement();

        // Create a fake token that's not a valid payment token
        IERC20 fakeToken = IERC20(makeAddr("fakeToken"));

        setAllocationFail({
            wallet: alice,
            token: fakeToken,
            amount: 500e6,
            allowOverwrite: false,
            err: abi.encodeWithSelector(SettlementSale.InvalidPaymentToken.selector, address(fakeToken))
        });
    }
}

