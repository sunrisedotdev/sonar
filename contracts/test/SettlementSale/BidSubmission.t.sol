// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./SettlementSaleBaseTest.sol";

contract SettlementSaleBidTestBase is SettlementSaleBaseTest {
    function setUp() public override {
        super.setUp();
        openCommitment();
    }

    struct State {
        uint256 saleTokenBalance;
        uint256 totalCommittedAmount;
        SettlementSale.Bid userBid;
        uint256 numEntities;
    }

    function getState(bytes16 entityID, IERC20 token) internal view returns (State memory) {
        return State({
            saleTokenBalance: token.balanceOf(address(sale)),
            totalCommittedAmount: sale.totalCommittedAmount(),
            userBid: sale.entityStateByID(entityID).currentBid,
            numEntities: sale.numEntities()
        });
    }

    function bidSuccess(address user, uint64 price, uint256 amount, IERC20 token) internal {
        bidSuccess(user, price, amount, false, token);
    }

    function bidSuccess(address user, uint64 price, uint256 amount, bool lockup, IERC20 token) internal {
        bidSuccess({
            user: user,
            price: price,
            amount: amount,
            lockup: lockup,
            token: token,
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: SALE_MIN_PRICE,
            maxPrice: SALE_MAX_PRICE
        });
    }

    function bidSuccess(
        address user,
        uint64 price,
        uint256 amount,
        bool lockup,
        IERC20 token,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 minPrice,
        uint64 maxPrice
    ) internal {
        PurchasePermitV3 memory purchasePermit = makePurchasePermit({
            saleSpecificEntityID: addressToEntityID(user),
            wallet: user,
            minAmount: minAmount,
            maxAmount: maxAmount,
            minPrice: minPrice,
            maxPrice: maxPrice
        });
        bidSuccess({
            user: user, price: price, amount: amount, lockup: lockup, token: token, purchasePermit: purchasePermit
        });
    }

    function bidSuccess(
        address user,
        uint64 price,
        uint256 amount,
        IERC20 token,
        PurchasePermitV3 memory purchasePermit
    ) internal {
        bidSuccess(user, price, amount, false, token, purchasePermit);
    }

    function bidSuccess(
        address user,
        uint64 price,
        uint256 amount,
        bool lockup,
        IERC20 token,
        PurchasePermitV3 memory purchasePermit
    ) internal {
        bytes16 entityID = purchasePermit.saleSpecificEntityID;
        State memory stateBefore = getState(entityID, token);

        uint256 amountDelta = amount - stateBefore.userBid.amount;

        deal(address(token), user, amountDelta);

        vm.prank(user);
        token.approve(address(sale), amountDelta);

        bool newWallet = !sale.isWalletInitialized(user);
        bool newEntity = !sale.isEntityInitialized(entityID);
        if (newEntity) {
            vm.expectEmit(true, true, true, true, address(sale));
            emit SettlementSale.EntityInitialized(entityID, user);
        }
        if (newWallet) {
            vm.expectEmit(true, true, true, true, address(sale));
            emit SettlementSale.WalletInitialized(entityID, user);
        }

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: lockup, price: price, amount: amount});

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.BidPlaced(entityID, user, bid);

        {
            bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

            vm.prank(user);
            sale.replaceBidWithApproval(token, bid, purchasePermit, purchasePermitSignature);
        }

        State memory stateAfter = getState(entityID, token);

        assertEq(stateAfter.saleTokenBalance, stateBefore.saleTokenBalance + amountDelta);
        assertEq(stateAfter.totalCommittedAmount, stateBefore.totalCommittedAmount + amountDelta);
        assertEq(stateAfter.userBid, bid);
        assertTrue(sale.isWalletInitialized(user));
        assertEq(stateAfter.numEntities, stateBefore.numEntities + (newEntity ? 1 : 0));
        assertEq(sale.entityStateByID(entityID).bidTimestamp, block.timestamp);
        assertEq(sale.walletStateByAddress(user).entityID, entityID, "entity ID should match");
    }

    function bidFail(address user, uint64 price, uint256 amount, IERC20 token, bytes memory err) internal {
        return
            bidFail({
                entityID: addressToEntityID(user), user: user, price: price, amount: amount, token: token, err: err
            });
    }

    function bidFail(
        bytes16 entityID,
        address user,
        uint64 price,
        uint256 amount,
        IERC20 token,
        bytes memory err
    ) internal {
        PurchasePermitV3 memory purchasePermit = makePurchasePermit({saleSpecificEntityID: entityID, wallet: user});
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        deal(address(token), user, amount);
        vm.prank(user);
        token.approve(address(sale), amount);

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: false, price: price, amount: amount});

        vm.expectRevert(err);
        vm.prank(user);
        sale.replaceBidWithApproval(token, bid, purchasePermit, purchasePermitSignature);
    }

    function bidFail(
        address user,
        uint64 price,
        uint256 amount,
        IERC20 token,
        PurchasePermitV3 memory purchasePermit,
        bytes memory err
    ) internal {
        bidFail({
            user: user,
            price: price,
            amount: amount,
            lockup: false,
            token: token,
            purchasePermit: purchasePermit,
            err: err
        });
    }

    function bidFail(
        address user,
        uint64 price,
        uint256 amount,
        bool lockup,
        IERC20 token,
        PurchasePermitV3 memory purchasePermit,
        bytes memory err
    ) internal {
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);
        bidFail({
            user: user,
            price: price,
            amount: amount,
            lockup: lockup,
            token: token,
            purchasePermit: purchasePermit,
            purchasePermitSignature: purchasePermitSignature,
            err: err
        });
    }

    function bidFail(
        address user,
        uint64 price,
        uint256 amount,
        IERC20 token,
        PurchasePermitV3 memory purchasePermit,
        bytes memory purchasePermitSignature,
        bytes memory err
    ) internal {
        bidFail({
            user: user,
            price: price,
            amount: amount,
            lockup: false,
            token: token,
            purchasePermit: purchasePermit,
            purchasePermitSignature: purchasePermitSignature,
            err: err
        });
    }

    function bidFail(
        address user,
        uint64 price,
        uint256 amount,
        bool lockup,
        IERC20 token,
        PurchasePermitV3 memory purchasePermit,
        bytes memory purchasePermitSignature,
        bytes memory err
    ) internal {
        deal(address(token), user, amount);
        vm.prank(user);
        token.approve(address(sale), amount);

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: lockup, price: price, amount: amount});

        vm.expectRevert(err);
        vm.prank(user);
        sale.replaceBidWithApproval(token, bid, purchasePermit, purchasePermitSignature);
    }
}

contract SettlementSalePurchasePermitValidationTest is SettlementSaleBidTestBase {
    function testBid_WithInvalidSaleUUID_Reverts() public {
        PurchasePermitV3 memory permit = makePurchasePermit({wallet: alice});

        bytes16 wrongUUID = bytes16(uint128(1234567890));
        permit.saleUUID = wrongUUID;

        bidFail({
            user: alice,
            token: usdc,
            price: 10,
            amount: 1000e6,
            purchasePermit: permit,
            err: abi.encodeWithSelector(SettlementSale.InvalidSaleUUID.selector, wrongUUID, TEST_SALE_UUID)
        });
    }

    function testBid_WithExpiredPermit_Reverts() public {
        PurchasePermitV3 memory permit = makePurchasePermit({wallet: alice});
        permit.expiresAt = uint64(block.timestamp - 1); // expired
        bidFail({
            user: alice,
            token: usdc,
            price: 10,
            amount: 1000e6,
            purchasePermit: permit,
            err: abi.encodeWithSelector(
                SettlementSale.PurchasePermitExpired.selector, permit.expiresAt, block.timestamp
            )
        });
    }

    function testBid_WithPermitForDifferentWallet_Reverts() public {
        PurchasePermitV3 memory permit = makePurchasePermit({wallet: alice});
        bidFail({
            user: bob,
            token: usdc,
            price: 10,
            amount: 1000e6,
            purchasePermit: permit,
            err: abi.encodeWithSelector(SettlementSale.InvalidSender.selector, bob, alice)
        });
    }

    function testBid_WithUnauthorizedSigner_Reverts() public {
        PurchasePermitV3 memory permit = makePurchasePermit({wallet: alice});

        // Sign with wrong private key (bob's instead of purchasePermitSigner's)
        bytes memory wrongSignature = signPurchasePermit(permit, addressToAccount[bob].key);

        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            purchasePermit: permit,
            purchasePermitSignature: wrongSignature,
            err: abi.encodeWithSelector(SettlementSale.UnauthorizedSigner.selector, bob)
        });
    }

    function testBid_WithZeroAddress_Reverts() public {
        PurchasePermitV3 memory permit = makePurchasePermit({saleSpecificEntityID: aliceID, wallet: address(0)});

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.ZeroAddress.selector));
        vm.prank(address(0));
        sale.replaceBidWithApproval(
            usdc, SettlementSale.Bid({lockup: false, price: 10, amount: 1000e6}), permit, signPurchasePermit(permit)
        );
    }

    function testBid_WithZeroEntityID_Reverts() public {
        PurchasePermitV3 memory permit = makePurchasePermit({saleSpecificEntityID: bytes16(0), wallet: alice});
        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(SettlementSale.ZeroEntityID.selector)
        });
    }

    // Time window tests

    function testBid_WithinTimeWindow_Succeeds() public {
        PurchasePermitV3 memory permit = makePurchasePermit({
            saleSpecificEntityID: aliceID,
            wallet: alice,
            opensAt: uint64(block.timestamp),
            closesAt: uint64(block.timestamp + 1 hours)
        });
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc, purchasePermit: permit});
    }

    function testBid_BeforeOpensAt_Reverts() public {
        uint64 opensAt = uint64(block.timestamp + 1 hours);
        uint64 closesAt = uint64(block.timestamp + 2 hours);

        PurchasePermitV3 memory permit =
            makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice, opensAt: opensAt, closesAt: closesAt});
        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(
                SettlementSale.BidOutsideAllowedWindow.selector, opensAt, closesAt, block.timestamp
            )
        });
    }

    function testBid_AtOpensAt_Succeeds() public {
        uint64 opensAt = uint64(block.timestamp + 1 hours);
        uint64 closesAt = uint64(block.timestamp + 2 hours);

        PurchasePermitV3 memory permit = makePurchasePermit({
            saleSpecificEntityID: aliceID,
            wallet: alice,
            expiresAt: uint64(block.timestamp + 3 hours),
            opensAt: opensAt,
            closesAt: closesAt
        });

        vm.warp(opensAt);
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc, purchasePermit: permit});
    }

    function testBid_JustBeforeClosesAt_Succeeds() public {
        uint64 closesAt = uint64(block.timestamp + 1 hours);

        PurchasePermitV3 memory permit = makePurchasePermit({
            saleSpecificEntityID: aliceID,
            wallet: alice,
            expiresAt: uint64(block.timestamp + 2 hours),
            opensAt: uint64(block.timestamp),
            closesAt: closesAt
        });

        vm.warp(closesAt - 1);
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc, purchasePermit: permit});
    }

    function testBid_AtClosesAt_Reverts() public {
        uint64 opensAt = uint64(block.timestamp);
        uint64 closesAt = uint64(block.timestamp + 1 hours);

        PurchasePermitV3 memory permit = makePurchasePermit({
            saleSpecificEntityID: aliceID,
            wallet: alice,
            expiresAt: uint64(block.timestamp + 2 hours),
            opensAt: opensAt,
            closesAt: closesAt
        });

        vm.warp(closesAt);
        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(
                SettlementSale.BidOutsideAllowedWindow.selector, opensAt, closesAt, block.timestamp
            )
        });
    }

    function testBid_AfterClosesAt_Reverts() public {
        uint64 opensAt = uint64(block.timestamp);
        uint64 closesAt = uint64(block.timestamp + 1 hours);

        PurchasePermitV3 memory permit = makePurchasePermit({
            saleSpecificEntityID: aliceID,
            wallet: alice,
            expiresAt: uint64(block.timestamp + 2 hours),
            opensAt: opensAt,
            closesAt: closesAt
        });

        vm.warp(closesAt + 1);
        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(
                SettlementSale.BidOutsideAllowedWindow.selector, opensAt, closesAt, block.timestamp
            )
        });
    }

    function testBid_ZeroOpensAt_ValidFromEpoch() public {
        PurchasePermitV3 memory permit = makePurchasePermit({
            saleSpecificEntityID: aliceID, wallet: alice, opensAt: 0, closesAt: uint64(block.timestamp + 1 hours)
        });
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc, purchasePermit: permit});
    }

    function testBid_ZeroClosesAt_AlwaysExpired() public {
        PurchasePermitV3 memory permit =
            makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice, opensAt: 0, closesAt: 0});
        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(SettlementSale.BidOutsideAllowedWindow.selector, 0, 0, block.timestamp)
        });
    }

    function testBid_OpensAtGreaterThanClosesAt_NeverValid() public {
        uint64 opensAt = uint64(block.timestamp + 2 hours);
        uint64 closesAt = uint64(block.timestamp + 1 hours);

        PurchasePermitV3 memory permit =
            makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice, opensAt: opensAt, closesAt: closesAt});
        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(
                SettlementSale.BidOutsideAllowedWindow.selector, opensAt, closesAt, block.timestamp
            )
        });
    }

    function testBid_ExpiresAtCheckedWithinWindow() public {
        uint64 expiresAt = uint64(block.timestamp + 30 minutes);

        PurchasePermitV3 memory permit = makePurchasePermit({
            saleSpecificEntityID: aliceID,
            wallet: alice,
            expiresAt: expiresAt,
            opensAt: uint64(block.timestamp),
            closesAt: uint64(block.timestamp + 2 hours)
        });

        vm.warp(expiresAt + 1);
        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(SettlementSale.PurchasePermitExpired.selector, expiresAt, block.timestamp)
        });
    }
}

contract SettlementSaleBidTest is SettlementSaleBidTestBase {
    function testBid_SingleUser_Success() public {
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc});
    }

    function testBid_SameUser_CanIncreaseBidMultipleTimes() public {
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc});
        assertEq(sale.totalCommittedAmountByToken(), toTokenAmounts({usdcAmount: 1000e6, usdtAmount: 0}));

        bidSuccess({user: alice, price: 10, amount: 3000e6, token: usdc});
        assertEq(sale.totalCommittedAmountByToken(), toTokenAmounts({usdcAmount: 3000e6, usdtAmount: 0}));

        bidSuccess({user: alice, price: 11, amount: 3000e6, token: usdc});
        assertEq(sale.totalCommittedAmountByToken(), toTokenAmounts({usdcAmount: 3000e6, usdtAmount: 0}));
    }

    function testBid_MultipleUsersAndTokens_Success() public {
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc});
        bidSuccess({user: bob, price: 10, amount: 1000e6, token: usdt});

        assertTokenBalances({owner: address(sale), usdcAmount: 1000e6, usdtAmount: 1000e6});
        assertEq(sale.totalCommittedAmountByToken(), toTokenAmounts({usdcAmount: 1000e6, usdtAmount: 1000e6}));

        bidSuccess({user: alice, price: 11, amount: 2000e6, token: usdc});
        bidSuccess({user: bob, price: 20, amount: 3000e6, token: usdt});

        assertTokenBalances({owner: address(sale), usdcAmount: 2000e6, usdtAmount: 3000e6});
        assertEq(sale.totalCommittedAmountByToken(), toTokenAmounts({usdcAmount: 2000e6, usdtAmount: 3000e6}));

        assertEq(
            sale.entityStateByID(aliceID).currentBid, SettlementSale.Bid({lockup: false, price: 11, amount: 2000e6})
        );
        assertEq(sale.entityStateByID(bobID).currentBid, SettlementSale.Bid({lockup: false, price: 20, amount: 3000e6}));
    }

    function testBid_SwitchingTokens_Success() public {
        // Alice bids with USDC
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc});
        assertTokenBalances({owner: address(sale), usdcAmount: 1000e6, usdtAmount: 0});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);

        // Alice increases bid with USDT (switching tokens)
        bidSuccess({user: alice, price: 11, amount: 2000e6, token: usdt});

        assertTokenBalances({owner: address(sale), usdcAmount: 1000e6, usdtAmount: 1000e6});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 2000e6);
    }

    function testBid_AfterClose_Reverts() public {
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc});

        closeCommitment();
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Closed));

        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            err: encodeInvalidStage(SettlementSale.Stage.Closed, SettlementSale.Stage.Commitment)
        });
    }

    function testBid_BeforeOpen_Reverts() public {
        vm.prank(admin);
        sale.unsafeSetStage(SettlementSale.Stage.PreOpen);

        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            token: usdc,
            err: encodeInvalidStage(SettlementSale.Stage.PreOpen, SettlementSale.Stage.Commitment)
        });
    }

    function testBid_WhilePaused_Reverts() public {
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc});

        vm.prank(pauser);
        sale.pause();

        bidFail({
            user: alice,
            price: 11,
            amount: 1000e6,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.SalePaused.selector)
        });

        vm.prank(admin);
        sale.setPaused(false);

        bidSuccess({user: alice, price: 11, amount: 1000e6, token: usdc});
    }

    function testBid_WithInvalidPaymentToken_Reverts() public {
        // Create a fake token that is NOT a payment token
        ERC20FakeWithDecimals fakeToken = new ERC20FakeWithDecimals("FAKE", "FAKE", 6);
        vm.label(address(fakeToken), "FAKE-token");

        bidFail({
            user: alice,
            token: fakeToken,
            price: 10,
            amount: 1000e6,
            err: abi.encodeWithSelector(SettlementSale.InvalidPaymentToken.selector, address(fakeToken))
        });
    }

    function testBid_WithDifferentEntity_Reverts() public {
        bidSuccess({user: alice, price: 10, amount: 1000e6, token: usdc});

        PurchasePermitV3 memory permitForBob = makePurchasePermit({saleSpecificEntityID: bobID, wallet: alice});
        bidFail({
            user: alice,
            price: 10,
            amount: 2000e6,
            token: usdc,
            purchasePermit: permitForBob,
            err: abi.encodeWithSelector(SettlementSale.WalletTiedToAnotherEntity.selector, bobID, aliceID, alice)
        });
    }

    function testBid_WithDifferentEntityID_Reverts() public {
        // Alice bids with first wallet
        bidSuccess({user: alice, token: usdc, amount: 2000e6, price: 10});

        // Try to use alice's wallet with a different entity ID (bobID)
        bidFail({
            entityID: bobID,
            user: alice,
            price: 10,
            amount: 3000e6,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.WalletTiedToAnotherEntity.selector, bobID, aliceID, alice)
        });
    }
}

contract SettlementSaleBidAmountTest is SettlementSaleBidTestBase {
    function testBid_AtMinAmount_Success() public {
        bidSuccess({user: alice, price: 10, amount: SALE_MIN_AMOUNT, token: usdc});
    }

    function testBid_AtMaxAmount_Success() public {
        bidSuccess({user: alice, price: 10, amount: SALE_MAX_AMOUNT, token: usdc});
    }

    function testBid_BelowMinAmount_Reverts() public {
        uint256 belowMinAmount = SALE_MIN_AMOUNT - 1;
        bidFail({
            user: alice,
            price: 10,
            amount: belowMinAmount,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.BidBelowMinAmount.selector, belowMinAmount, SALE_MIN_AMOUNT)
        });
    }

    function testBid_AboveMaxAmount_Reverts() public {
        uint256 aboveMaxAmount = SALE_MAX_AMOUNT + 1;
        bidFail({
            user: alice,
            price: 10,
            amount: aboveMaxAmount,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.BidExceedsMaxAmount.selector, aboveMaxAmount, SALE_MAX_AMOUNT)
        });
    }

    function testBid_AboveMaxAmountInMultipleSteps_Reverts() public {
        bidSuccess({user: alice, price: 10, amount: 2000e6, token: usdc});
        bidFail({
            user: alice,
            price: 10,
            amount: SALE_MAX_AMOUNT + 1,
            token: usdc,
            err: abi.encodeWithSelector(
                SettlementSale.BidExceedsMaxAmount.selector, SALE_MAX_AMOUNT + 1, SALE_MAX_AMOUNT
            )
        });
        bidSuccess({user: alice, price: 10, amount: SALE_MAX_AMOUNT, token: usdc});
        assertEq(usdc.balanceOf(address(sale)), SALE_MAX_AMOUNT);

        bidFail({
            user: bob,
            price: 10,
            amount: SALE_MAX_AMOUNT + 1,
            token: usdc,
            err: abi.encodeWithSelector(
                SettlementSale.BidExceedsMaxAmount.selector, SALE_MAX_AMOUNT + 1, SALE_MAX_AMOUNT
            )
        });
        bidSuccess({user: bob, price: 10, amount: SALE_MAX_AMOUNT, token: usdc});
        assertEq(usdc.balanceOf(address(sale)), 2 * SALE_MAX_AMOUNT);
    }

    function testBid_LoweringAmount_Reverts() public {
        bidSuccess({user: alice, price: 10, amount: 2000e6, token: usdc});
        bidFail({
            user: alice,
            price: 10,
            amount: 1500e6,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.BidAmountCannotBeLowered.selector, 1500e6, 2000e6)
        });
    }

    function testBid_ZeroAmount_Reverts() public {
        bidFail({
            user: alice,
            price: 10,
            amount: 0,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.ZeroAmount.selector)
        });
    }
}

contract SettlementSaleBidPriceTest is SettlementSaleBidTestBase {
    function testBid_AtMinPrice_Success() public {
        bidSuccess({user: alice, price: SALE_MIN_PRICE, amount: 1000e6, token: usdc});

        assertEq(sale.entityStateByID(aliceID).currentBid.price, SALE_MIN_PRICE);
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);
    }

    function testBid_AtMaxPrice_Success() public {
        bidSuccess({user: alice, price: SALE_MAX_PRICE, amount: 1000e6, token: usdc});

        assertEq(sale.entityStateByID(aliceID).currentBid.price, SALE_MAX_PRICE);
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);
    }

    function testBid_AboveMaxPrice_Reverts() public {
        uint64 aboveMaxPrice = SALE_MAX_PRICE + 1;
        bidFail({
            user: alice,
            price: aboveMaxPrice,
            amount: 1000e6,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.BidPriceExceedsMaxPrice.selector, aboveMaxPrice, SALE_MAX_PRICE)
        });
    }

    function testBid_BelowMinPrice_Reverts() public {
        uint64 belowMinPrice = SALE_MIN_PRICE - 1;
        bidFail({
            user: alice,
            price: belowMinPrice,
            amount: 1000e6,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.BidPriceBelowMinPrice.selector, belowMinPrice, SALE_MIN_PRICE)
        });
    }

    function testBid_LoweringPrice_Reverts() public {
        bidSuccess({user: alice, price: 10, amount: 2000e6, token: usdc});
        bidFail({
            user: alice,
            price: 9,
            amount: 2000e6,
            token: usdc,
            err: abi.encodeWithSelector(SettlementSale.BidPriceCannotBeLowered.selector, 9, 10)
        });
    }
}

contract SettlementSaleBidAfterRefundTest is SettlementSaleBidTestBase {
    function testBid_AfterBeingRefunded_Reverts() public {
        // Alice places a bid
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});

        closeCommitment();
        openCancellation();

        // Alice cancels (gets refunded)
        vm.prank(alice);
        sale.cancelBid();

        assertTrue(sale.entityStateByID(aliceID).refunded, "alice should be refunded");

        // Admin manually sets stage back to Commitment (simulating reopening after refunds)
        vm.prank(admin);
        sale.unsafeSetStage(SettlementSale.Stage.Commitment);

        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Commitment), "should be in commitment stage");

        // Try to bid again - should fail because alice was already refunded
        PurchasePermitV3 memory permit = makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice});
        bidFail({
            user: alice,
            token: usdc,
            price: 10,
            amount: 1000e6,
            purchasePermit: permit,
            err: abi.encodeWithSelector(SettlementSale.AlreadyRefunded.selector, aliceID)
        });
    }
}

contract SettlementSalePermitBidTest is SettlementSaleBaseTest {
    function setUp() public override {
        super.setUp();
        openCommitment();
    }

    function doBidWithPermitSuccess(address user, uint256 amount, uint64 price, IERC20 token) internal {
        bytes16 entityID = addressToEntityID(user);
        PurchasePermitV3 memory purchasePermit = makePurchasePermit(entityID, user);
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        bytes memory erc20PermitSignature;
        uint256 deadline;
        {
            uint256 amountDelta = amount - sale.entityStateByID(entityID).currentBid.amount;
            deal(address(token), user, amountDelta);
            (erc20PermitSignature, deadline) = getERC20PermitSignature(token, user, amountDelta);
        }

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: false, price: price, amount: amount});

        if (!sale.isEntityInitialized(entityID)) {
            vm.expectEmit(true, true, true, true, address(sale));
            emit SettlementSale.EntityInitialized(entityID, user);
        }
        if (!sale.isWalletInitialized(user)) {
            vm.expectEmit(true, true, true, true, address(sale));
            emit SettlementSale.WalletInitialized(entityID, user);
        }

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.BidPlaced(entityID, user, bid);

        vm.prank(user);
        sale.replaceBidWithPermit(token, bid, purchasePermit, purchasePermitSignature, deadline, erc20PermitSignature);

        assertEq(sale.entityStateByID(entityID).currentBid, bid);
    }

    function testBidWithPermit_SingleUser_Success() public {
        doBidWithPermitSuccess({user: alice, amount: 1000e6, price: 10, token: usdc});

        assertTokenBalances({owner: address(sale), usdcAmount: 1000e6, usdtAmount: 0});
        assertEq(sale.totalCommittedAmount(), 1000e6);
    }

    function testBidWithPermit_MultipleIncreases_Success() public {
        // First bid
        doBidWithPermitSuccess({user: alice, amount: 1000e6, price: 10, token: usdc});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);
        assertTokenBalances({owner: address(sale), usdcAmount: 1000e6, usdtAmount: 0});

        // Second bid - only increment needs permit
        doBidWithPermitSuccess({user: alice, amount: 2000e6, price: 11, token: usdc});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 2000e6);
        assertTokenBalances({owner: address(sale), usdcAmount: 2000e6, usdtAmount: 0});

        // Third bid with different token
        doBidWithPermitSuccess({user: alice, amount: 3000e6, price: 12, token: usdt});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 3000e6);
        assertTokenBalances({owner: address(sale), usdcAmount: 2000e6, usdtAmount: 1000e6});
    }

    function testBidWithPermit_OnlyAuthorizesDelta_Success() public {
        // First bid with approval
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);

        // Second bid with permit - only permit the increment (500e6), not the full amount (1500e6)
        doBidWithPermitSuccess({user: alice, amount: 1500e6, price: 11, token: usdc});

        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1500e6);
        assertEq(usdc.balanceOf(address(sale)), 1500e6);
    }

    function testBidWithPermit_MixedWithApproval_Success() public {
        // First bid with approval
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);
        assertTokenBalances({owner: address(sale), usdcAmount: 1000e6, usdtAmount: 0});

        // Second bid with permit
        doBidWithPermitSuccess({user: alice, amount: 2000e6, price: 11, token: usdc});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 2000e6);
        assertTokenBalances({owner: address(sale), usdcAmount: 2000e6, usdtAmount: 0});

        // Third bid back to approval
        doBid({user: alice, amount: 3000e6, price: 12, token: usdc});
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 3000e6);
        assertTokenBalances({owner: address(sale), usdcAmount: 3000e6, usdtAmount: 0});
    }

    struct testPermitAndApprovalProduceSameStateParams {
        uint8 tokenIndex;
        string userName;
        uint256 bidAmount;
        uint64 bidPrice;
    }

    function testBidWithPermit_VsApproval_ProducesSameState(testPermitAndApprovalProduceSameStateParams memory fuzz)
        public
    {
        Account memory user = makeAccount(fuzz.userName);

        PurchasePermitV3 memory purchasePermit =
            makePurchasePermit({saleSpecificEntityID: addressToEntityID(user.addr), wallet: user.addr});
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        SettlementSale.Bid memory bid = SettlementSale.Bid({
            lockup: false,
            price: uint64(bound(fuzz.bidPrice, SALE_MIN_PRICE, SALE_MAX_PRICE)),
            amount: bound(fuzz.bidAmount, SALE_MIN_AMOUNT, SALE_MAX_AMOUNT)
        });

        IERC20 token = paymentTokens[fuzz.tokenIndex % paymentTokens.length];
        deal(address(token), user.addr, bid.amount);

        // take a snapshot of the state before the bids, we will revert to this snapshot after each bid
        uint256 snap = vm.snapshotState();

        // run the approval-based bid and record the state diff
        vm.startStateDiffRecording();
        Vm.AccountAccess[] memory accessApproval;
        {
            vm.startPrank(user.addr);
            token.approve(address(sale), bid.amount);
            sale.replaceBidWithApproval(token, bid, purchasePermit, purchasePermitSignature);
            vm.stopPrank();

            accessApproval = vm.stopAndReturnStateDiff();
        }

        // Reset the state so we're ready for the permit-based bid
        vm.revertToState(snap);

        // run the permit-based bid and record the state diff
        vm.startStateDiffRecording();
        Vm.AccountAccess[] memory accessPermit;
        {
            ERC20Permit permitToken = ERC20Permit(address(token));
            uint256 deadline = block.timestamp + 1000;
            bytes memory erc20PermitSignature =
                signERC20Permit(permitToken, user.addr, address(sale), bid.amount, deadline);

            vm.prank(user.addr);
            sale.replaceBidWithPermit(
                token, bid, purchasePermit, purchasePermitSignature, deadline, erc20PermitSignature
            );

            accessPermit = vm.stopAndReturnStateDiff();
        }

        // Assert that both methods produce the same state diff on the sale contract
        assertSameStateDiff(address(sale), accessApproval, address(sale), accessPermit);
    }

    function testBidWithPermit_AfterFrontrun_StillSucceeds() public {
        uint256 bidAmount = 1000e6;
        uint64 bidPrice = 10;

        deal(address(usdc), alice, bidAmount);

        PurchasePermitV3 memory purchasePermit = makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice});
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        // Get ERC20 permit signature
        (bytes memory erc20PermitSignature, uint256 deadline) = getERC20PermitSignature(usdc, alice, bidAmount);

        // Simulate frontrunning: someone else uses the permit first by pre-approving
        vm.prank(alice);
        usdc.approve(address(sale), bidAmount);

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: false, price: bidPrice, amount: bidAmount});

        // The bid should still succeed because the try-catch swallows the permit error
        // and safeTransferFrom works with the pre-approval
        vm.prank(alice);
        sale.replaceBidWithPermit(usdc, bid, purchasePermit, purchasePermitSignature, deadline, erc20PermitSignature);

        assertEq(sale.entityStateByID(aliceID).currentBid.amount, bidAmount);
        assertEq(usdc.balanceOf(address(sale)), bidAmount);
    }

    function testBidWithPermit_InvalidSignatureWithApproval_Success() public {
        uint256 bidAmount = 1000e6;
        uint64 bidPrice = 10;

        deal(address(usdc), alice, bidAmount);

        // Pre-approve the contract
        vm.prank(alice);
        usdc.approve(address(sale), bidAmount);

        PurchasePermitV3 memory purchasePermit = makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice});
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        // Use garbage ERC20 permit signature
        bytes memory invalidErc20Sig = new bytes(65);
        uint256 deadline = block.timestamp + 1000;

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: false, price: bidPrice, amount: bidAmount});

        // Should succeed because the try-catch swallows the permit error
        vm.prank(alice);
        sale.replaceBidWithPermit(usdc, bid, purchasePermit, purchasePermitSignature, deadline, invalidErc20Sig);

        assertEq(sale.entityStateByID(aliceID).currentBid.amount, bidAmount);
    }
}

contract SettlementSalePriceOnlyIncreaseTest is SettlementSaleBaseTest {
    function setUp() public override {
        super.setUp();
        openCommitment();
    }

    function testBid_OnlyPriceIncrease_Success() public {
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        assertEq(sale.entityStateByID(aliceID).currentBid.price, 10);
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);
        assertEq(usdc.balanceOf(address(sale)), 1000e6);

        // Second bid: same amount, higher price (amountDelta = 0)
        PurchasePermitV3 memory permit = makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice});
        bytes memory sig = signPurchasePermit(permit);

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: false, price: 15, amount: 1000e6});

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.BidPlaced(aliceID, alice, bid);

        vm.prank(alice);
        sale.replaceBidWithApproval(usdc, bid, permit, sig);

        assertEq(sale.entityStateByID(aliceID).currentBid.price, 15);
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);
        assertEq(usdc.balanceOf(address(sale)), 1000e6, "no additional tokens transferred");
    }

    function testBid_OnlyPriceIncreaseWithPermit_Success() public {
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        PurchasePermitV3 memory purchasePermit = makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice});
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        // ERC20 permit for 0 amount delta
        (bytes memory erc20PermitSignature, uint256 deadline) = getERC20PermitSignature(usdc, alice, 0);

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: false, price: 20, amount: 1000e6});

        vm.prank(alice);
        sale.replaceBidWithPermit(usdc, bid, purchasePermit, purchasePermitSignature, deadline, erc20PermitSignature);

        assertEq(sale.entityStateByID(aliceID).currentBid.price, 20);
        assertEq(sale.entityStateByID(aliceID).currentBid.amount, 1000e6);
    }
}

contract SettlementSaleWalletEventTest is SettlementSaleBaseTest {
    function setUp() public override {
        super.setUp();
        openCommitment();
    }

    function testBid_SubsequentBids_NoWalletInitializedEvent() public {
        // First bid - should emit both EntityInitialized and WalletInitialized
        PurchasePermitV3 memory permit = makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice});
        bytes memory sig = signPurchasePermit(permit);

        deal(address(usdc), alice, 1000e6);
        vm.prank(alice);
        usdc.approve(address(sale), 1000e6);

        SettlementSale.Bid memory bid1 = SettlementSale.Bid({lockup: false, price: 10, amount: 1000e6});

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.EntityInitialized(aliceID, alice);

        vm.expectEmit(true, true, true, true, address(sale));
        emit SettlementSale.WalletInitialized(aliceID, alice);

        vm.prank(alice);
        sale.replaceBidWithApproval(usdc, bid1, permit, sig);

        // Second bid from same wallet - should NOT emit EntityInitialized or WalletInitialized
        deal(address(usdc), alice, 1000e6);
        vm.prank(alice);
        usdc.approve(address(sale), 1000e6);

        SettlementSale.Bid memory bid2 = SettlementSale.Bid({lockup: false, price: 15, amount: 2000e6});

        vm.recordLogs();

        vm.prank(alice);
        sale.replaceBidWithApproval(usdc, bid2, permit, sig);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 entityInitializedTopic = keccak256("EntityInitialized(bytes16,address)");
        bytes32 walletInitializedTopic = keccak256("WalletInitialized(bytes16,address)");

        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(
                logs[i].topics[0] != entityInitializedTopic, "EntityInitialized should not be emitted on subsequent bid"
            );
            assertTrue(
                logs[i].topics[0] != walletInitializedTopic, "WalletInitialized should not be emitted on subsequent bid"
            );
        }
    }
}

contract SettlementSaleBidLockupTest is SettlementSaleBidTestBase {
    function testBid_WithLockupEnabled_Success() public {
        bidSuccess({user: alice, price: 10, amount: 1000e6, lockup: true, token: usdc});

        SettlementSale.EntityStateView memory state = sale.entityStateByID(aliceID);
        assertTrue(state.currentBid.lockup, "lockup should be true");
        assertEq(state.currentBid.amount, 1000e6);
        assertEq(state.currentBid.price, 10);
    }

    function testBid_WithLockupDisabled_Success() public {
        bidSuccess({user: alice, price: 10, amount: 1000e6, lockup: false, token: usdc});

        SettlementSale.EntityStateView memory state = sale.entityStateByID(aliceID);
        assertFalse(state.currentBid.lockup, "lockup should be false");
        assertEq(state.currentBid.amount, 1000e6);
        assertEq(state.currentBid.price, 10);
    }

    function testBid_UpgradingToLockup_Success() public {
        // First bid without lockup
        bidSuccess({user: alice, price: 10, amount: 1000e6, lockup: false, token: usdc});
        assertFalse(sale.entityStateByID(aliceID).currentBid.lockup);

        // Update to lockup bid - lockup can be upgraded
        bidSuccess({user: alice, price: 11, amount: 2000e6, lockup: true, token: usdc});
        assertTrue(sale.entityStateByID(aliceID).currentBid.lockup);
    }

    function testBid_UndoingLockup_Reverts() public {
        // First bid with lockup
        bidSuccess({user: alice, price: 10, amount: 1000e6, lockup: true, token: usdc});
        assertTrue(sale.entityStateByID(aliceID).currentBid.lockup, "lockup should be true");

        // Try to update to non-lockup bid - should revert
        PurchasePermitV3 memory permit = makePurchasePermit({saleSpecificEntityID: aliceID, wallet: alice});
        bidFail({
            user: alice,
            price: 11,
            amount: 2000e6,
            lockup: false,
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(SettlementSale.BidLockupCannotBeUndone.selector)
        });
    }

    function testBid_WithForcedLockupButWithoutLockup_Reverts() public {
        PurchasePermitV3 memory permit = makePurchasePermit({
            saleSpecificEntityID: aliceID,
            saleUUID: TEST_SALE_UUID,
            wallet: alice,
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: SALE_MIN_PRICE,
            maxPrice: SALE_MAX_PRICE,
            forcedLockup: true, // force lockup
            expiresAt: uint64(block.timestamp + 1000)
        });

        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            lockup: false, // try to bid without lockup
            token: usdc,
            purchasePermit: permit,
            err: abi.encodeWithSelector(SettlementSale.BidMustHaveLockup.selector)
        });
    }

    function testBid_WithForcedLockupAndLockup_Success() public {
        doBid({
            entityID: aliceID,
            user: alice,
            amount: 1000e6,
            price: 10,
            lockup: true,
            token: usdc,
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: SALE_MIN_PRICE,
            maxPrice: SALE_MAX_PRICE,
            forcedLockup: true
        });

        assertTrue(sale.entityStateByID(aliceID).currentBid.lockup);
    }
}
