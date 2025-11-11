// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {PurchasePermit} from "sonar/permits/PurchasePermit.sol";
import {
    PurchasePermitWithAuctionData,
    PurchasePermitWithAuctionDataLib
} from "sonar/permits/PurchasePermitWithAuctionData.sol";

import {BaseTest, console} from "./BaseTest.sol";
import {ERC20Fake, ERC20Permit} from "./doubles/ERC20Fake.sol";

import {EnglishAuctionSale} from "sonar/EnglishAuctionSale.sol";
import {IAuctionBidDataReader} from "sonar/interfaces/IAuctionBidData.sol";
import {IOffchainSettlement} from "sonar/interfaces/IOffchainSettlement.sol";

bytes16 constant TEST_SALE_UUID = hex"1234567890abcdef1234567890abcdef";
bytes32 constant ERC20_PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

uint256 constant SALE_MIN_AMOUNT = 1000e6;
uint256 constant SALE_MAX_AMOUNT = 15000e6;

contract TestableEnglishAuctionSale is EnglishAuctionSale {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(Init memory init) EnglishAuctionSale(init) {}

    function containsCommitter(address committer) public view returns (bool) {
        return _committers.contains(committer);
    }

    function allCommitters() public view returns (address[] memory) {
        uint256 numCommitters = this.numCommitters();
        return this.committersIn(0, numCommitters);
    }

    function allCommitterStates() public view returns (CommitterState[] memory) {
        uint256 numCommitters = this.numCommitters();
        return this.committerStatesIn(0, numCommitters);
    }
}

contract EnglishAuctionSaleTest is BaseTest {
    TestableEnglishAuctionSale sale;
    ERC20Fake paymentToken;

    bytes16 internal immutable aliceID = addressToEntityID(alice);
    bytes16 internal immutable bobID = addressToEntityID(bob);
    bytes16 internal immutable charlieID = addressToEntityID(charlie);

    address internal immutable pauser = makeAddr("pauser");
    address internal immutable recoverer = makeAddr("recoverer");
    address internal immutable receiver = makeAddr("receiver");
    address internal immutable settler = makeAddr("settler");
    address internal immutable refunder = makeAddr("refunder");

    Account permitSigner = makeAccount("permitSigner");
    Account maliciousPermitSigner = makeAccount("maliciousPermitSigner");

    function setUp() public virtual {
        paymentToken = new ERC20Fake("FAKE", "FAKE");
        vm.label(address(paymentToken), "FAKE-paymentToken");

        EnglishAuctionSale.Init memory init = EnglishAuctionSale.Init({
            saleUUID: TEST_SALE_UUID,
            admin: admin,
            paymentToken: paymentToken,
            purchasePermitSigner: permitSigner.addr,
            proceedsReceiver: receiver,
            pauser: pauser,
            closeAuctionAtTimestamp: uint64(block.timestamp + 24 hours),
            maxAddressesPerEntity: 10,
            claimRefundEnabled: true
        });
        sale = new TestableEnglishAuctionSale(init);

        vm.startPrank(admin);
        sale.grantRole(sale.SALE_MANAGER_ROLE(), manager);
        sale.grantRole(sale.SETTLER_ROLE(), settler);
        sale.grantRole(sale.TOKEN_RECOVERER_ROLE(), recoverer);
        sale.grantRole(sale.REFUNDER_ROLE(), refunder);
        vm.stopPrank();
    }

    function signPurchasePermit(PurchasePermitWithAuctionData memory permit, uint256 pk)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 digest = PurchasePermitWithAuctionDataLib.digest(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function signPurchasePermit(PurchasePermitWithAuctionData memory permit) internal view returns (bytes memory) {
        return signPurchasePermit(permit, permitSigner.key);
    }

    function makePurchasePermit(
        bytes16 entityID,
        bytes16 saleUUID,
        address wallet,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 minPrice,
        uint64 maxPrice,
        uint64 expiresAt
    ) internal pure returns (PurchasePermitWithAuctionData memory) {
        return PurchasePermitWithAuctionData({
            permit: PurchasePermit({
                entityID: entityID,
                saleUUID: saleUUID,
                wallet: wallet,
                expiresAt: expiresAt,
                payload: hex""
            }),
            minAmount: minAmount,
            maxAmount: maxAmount,
            minPrice: minPrice,
            maxPrice: maxPrice
        });
    }

    function makePurchasePermit(bytes16 entityID, address wallet, uint64 maxPrice)
        internal
        view
        returns (PurchasePermitWithAuctionData memory)
    {
        return makePurchasePermit({
            entityID: entityID,
            saleUUID: TEST_SALE_UUID,
            wallet: wallet,
            expiresAt: uint64(block.timestamp + 1000),
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: 0,
            maxPrice: maxPrice
        });
    }

    function makePurchasePermit(bytes16 entityID, address wallet, uint64 minPrice, uint64 maxPrice)
        internal
        view
        returns (PurchasePermitWithAuctionData memory)
    {
        return makePurchasePermit({
            entityID: entityID,
            saleUUID: TEST_SALE_UUID,
            wallet: wallet,
            expiresAt: uint64(block.timestamp + 1000),
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: minPrice,
            maxPrice: maxPrice
        });
    }

    function doBid(address user, uint256 amount, uint64 price) internal {
        doBid(user, amount, price, 100);
    }

    function doBid(address user, uint256 amount, uint64 price, uint64 maxPrice) internal {
        bytes16 entityID = addressToEntityID(user);
        PurchasePermitWithAuctionData memory purchasePermit = makePurchasePermit(entityID, user, maxPrice);
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        uint256 amountDelta = amount - sale.committerStateByAddress(user).currentBid.amount;
        deal(address(paymentToken), user, amountDelta);

        vm.prank(user);
        paymentToken.approve(address(sale), amountDelta);

        EnglishAuctionSale.Bid memory bid = EnglishAuctionSale.Bid({price: price, amount: amount});
        vm.prank(user);
        sale.replaceBidWithApproval(bid, purchasePermit, purchasePermitSignature);
    }

    function doSetAllocation(address user, uint256 amount) internal {
        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({committer: user, acceptedAmount: amount});

        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: false});
    }

    function addressToEntityID(address addr) internal pure returns (bytes16) {
        return bytes16(keccak256(abi.encode(addr)));
    }

    function assertEq(EnglishAuctionSale.Bid memory a, EnglishAuctionSale.Bid memory b) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(EnglishAuctionSale.Bid memory a, EnglishAuctionSale.Bid memory b, string memory message)
        internal
        pure
    {
        assertEq(a.amount, b.amount, string.concat(message, " bid.amount"));
        assertEq(a.price, b.price, string.concat(message, " bid.price"));
    }

    function assertEq(EnglishAuctionSale.CommitterState memory a, EnglishAuctionSale.CommitterState memory b)
        internal
        pure
    {
        assertEq(a, b, "");
    }

    function assertEq(
        EnglishAuctionSale.CommitterState memory a,
        EnglishAuctionSale.CommitterState memory b,
        string memory message
    ) internal pure {
        assertEq(a.addr, b.addr, string.concat(message, " addr"));
        assertEq(a.entityID, b.entityID, string.concat(message, " entityID"));
        assertEq(a.acceptedAmount, b.acceptedAmount, string.concat(message, " acceptedAmount"));
        assertEq(a.refunded, b.refunded, string.concat(message, " refunded"));
        assertEq(a.cancelled, b.cancelled, string.concat(message, " cancelled"));
        assertEq(a.currentBid, b.currentBid, string.concat(message, " currentBid"));
    }

    function openAuction() public {
        vm.prank(manager);
        sale.openAuction();
    }

    function closeAuction() internal {
        uint256 closeTimestamp = sale.closeAuctionAtTimestamp();
        vm.warp(closeTimestamp);
    }

    function openCancellation() public {
        vm.prank(admin);
        sale.openCancellation();
    }

    function openSettlement() public {
        vm.prank(admin);
        sale.openSettlement();
    }

    function finalizeSettlement(uint256 expectedtotalAcceptedAmount) public {
        vm.prank(admin);
        sale.finalizeSettlement(expectedtotalAcceptedAmount);
    }

    function finalizeSettlement() public {
        finalizeSettlement(sale.totalAcceptedAmount());
    }
}

contract EnglishAuctionSaleVandalTest is EnglishAuctionSaleTest {
    function testVandalCannotSetManualStage(address vandal) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.setManualStage(EnglishAuctionSale.Stage.Auction);
    }

    function testVandalCannotRecoverTokens(address vandal, IERC20 paymentToken, uint256 amount, address to) public {
        vm.assume(vandal != recoverer);
        vm.expectRevert(missingRoleError(vandal, sale.TOKEN_RECOVERER_ROLE()));
        vm.prank(vandal);
        sale.recoverTokens(paymentToken, amount, to);
    }

    function testVandalCannotSetReceiver(address vandal, address newReceiver) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.setProceedsReceiver(newReceiver);
    }

    function testVandalCannotWithdraw(address vandal) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.withdraw();
    }

    function testVandalCannotSetAllocations(address vandal, IOffchainSettlement.Allocation[] memory allocations)
        public
    {
        vm.assume(vandal != settler);
        vm.expectRevert(missingRoleError(vandal, sale.SETTLER_ROLE()));
        vm.prank(vandal);
        sale.setAllocations({allocations: allocations, allowOverwrite: false});
    }

    function testVandalCannotSetCloseAuctionAtTimestamp(address vandal, uint64 timestamp) public {
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.setCloseAuctionAtTimestamp(timestamp);
    }

    function testVandalCannotSetMaxAddressesPerEntity(address vandal, uint256 newMax) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.setMaxAddressesPerEntity(newMax);
    }

    function testVandalCannotOpenAuction(address vandal) public {
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.openAuction();
    }

    function testVandalCannotOpenCancellation(address vandal) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.openCancellation();
    }

    function testVandalCannotOpenSettlement(address vandal) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.openSettlement();
    }

    function testVandalCannotFinalizeSettlement(address vandal, uint256 totalAcceptedAmount) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.finalizeSettlement(totalAcceptedAmount);
    }

    function testVandalCannotPause(address vandal) public {
        vm.assume(vandal != pauser);
        vm.expectRevert(missingRoleError(vandal, sale.PAUSER_ROLE()));
        vm.prank(vandal);
        sale.pause();
    }

    function testVandalCannotSetPaused(address vandal, bool paused) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.setPaused(paused);
    }

    function testVandalCannotProcessRefunds(address vandal, address[] calldata committers) public {
        vm.assume(vandal != refunder);
        vm.expectRevert(missingRoleError(vandal, sale.REFUNDER_ROLE()));
        vm.prank(vandal);
        sale.processRefunds(committers, false);
    }

    function testVandalCannotSetClaimRefundEnabled(address vandal, bool enabled) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.setClaimRefundEnabled(enabled);
    }
}

contract EnglishAuctionSaleStageTest is EnglishAuctionSaleTest {
    function testManualStage(uint8 stage, uint256 warp) public {
        EnglishAuctionSale.Stage want =
            EnglishAuctionSale.Stage(bound(stage, uint8(0), uint8(EnglishAuctionSale.Stage.Done)));
        vm.assume(want != EnglishAuctionSale.Stage.Auction);
        vm.warp(warp);

        vm.prank(admin);
        sale.setManualStage(want);

        assertEq(uint8(sale.stage()), uint8(want));
    }

    function testCloseAtTimestamp(uint256 startTime) public {
        startTime = bound(startTime, 0, type(uint32).max);
        vm.warp(startTime);

        assertEq(uint8(sale.manualStage()), uint8(EnglishAuctionSale.Stage.PreOpen));
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.PreOpen));

        vm.warp(startTime + 5 hours);
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.PreOpen));

        vm.prank(manager);
        sale.setCloseAuctionAtTimestamp(uint64(startTime + 24 hours));

        // moving on to auction

        vm.prank(manager);
        sale.openAuction();
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Auction));

        // should automatically close after the close timestamp
        vm.warp(startTime + 24 hours - 1 seconds);
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Auction));

        vm.warp(startTime + 24 hours);
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Closed));

        // extending the sale close window
        vm.prank(manager);
        sale.setCloseAuctionAtTimestamp(uint64(block.timestamp + 1 hours));
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Auction));

        vm.warp(block.timestamp + 30 minutes);
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Auction));

        vm.warp(block.timestamp + 30 minutes);
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Closed));

        // disable automatic closing
        vm.prank(manager);
        sale.setCloseAuctionAtTimestamp(0);
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Auction));

        // manual overrides
        vm.startPrank(admin);
        sale.setManualStage(EnglishAuctionSale.Stage.PreOpen);
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.PreOpen));

        sale.setManualStage(EnglishAuctionSale.Stage.Auction);
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Auction));
    }
}

contract EnglishAuctionSaleBidTest is EnglishAuctionSaleTest {
    struct State {
        uint256 saleTokenBalance;
        uint256 totalComittedAmount;
        EnglishAuctionSale.Bid userBid;
        uint256 numCommitters;
    }

    function getState(address user) internal view returns (State memory) {
        return State({
            saleTokenBalance: paymentToken.balanceOf(address(sale)),
            totalComittedAmount: sale.totalComittedAmount(),
            userBid: sale.committerStateByAddress(user).currentBid,
            numCommitters: sale.numCommitters()
        });
    }

    function bidSuccess(address user, uint64 price, uint256 amount, uint64 maxPrice) internal {
        bidSuccess(user, price, amount, 0, maxPrice);
    }

    function bidSuccess(address user, uint64 price, uint256 amount, uint64 minPrice, uint64 maxPrice) internal {
        State memory stateBefore = getState(user);

        bytes16 entityID = addressToEntityID(user);
        uint256 amountDelta = amount - stateBefore.userBid.amount;

        deal(address(paymentToken), user, amountDelta);

        vm.prank(user);
        paymentToken.approve(address(sale), amountDelta);

        bool newCommitter = !sale.containsCommitter(user);
        if (newCommitter) {
            vm.expectEmit(true, true, true, true, address(sale));
            emit EnglishAuctionSale.CommitterInitialized(entityID, user);
        }

        EnglishAuctionSale.Bid memory bid = EnglishAuctionSale.Bid({price: price, amount: amount});

        vm.expectEmit(true, true, true, true, address(sale));
        emit EnglishAuctionSale.BidPlaced(entityID, user, bid);

        {
            PurchasePermitWithAuctionData memory purchasePermit = makePurchasePermit(entityID, user, minPrice, maxPrice);
            bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

            vm.prank(user);
            sale.replaceBidWithApproval(bid, purchasePermit, purchasePermitSignature);
        }

        State memory stateAfter = getState(user);

        assertEq(stateAfter.saleTokenBalance, stateBefore.saleTokenBalance + amountDelta);
        assertEq(stateAfter.totalComittedAmount, stateBefore.totalComittedAmount + amountDelta);
        assertEq(stateAfter.userBid, bid);
        assertTrue(sale.containsCommitter(user));
        assertEq(stateAfter.numCommitters, stateBefore.numCommitters + (newCommitter ? 1 : 0));
        assertEq(sale.committerStateByAddress(user).bidTimestamp, block.timestamp);
        // TODO check entity ID
    }

    function bidFail(address user, uint64 price, uint256 amount, uint64 maxPrice, bytes memory err) internal {
        bytes16 entityID = addressToEntityID(user);
        PurchasePermitWithAuctionData memory purchasePermit = makePurchasePermit(entityID, user, maxPrice);
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        deal(address(paymentToken), user, amount);
        vm.prank(user);
        paymentToken.approve(address(sale), amount);

        EnglishAuctionSale.Bid memory bid = EnglishAuctionSale.Bid({price: price, amount: amount});

        vm.expectRevert(err);
        vm.prank(user);
        sale.replaceBidWithApproval(bid, purchasePermit, purchasePermitSignature);
    }

    function testSingleBid() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: 1000e6, maxPrice: 100});
    }

    function testMultipleBids() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: 1000e6, maxPrice: 100});
        bidSuccess({user: alice, price: 10, amount: 1000e6, maxPrice: 100});
        bidSuccess({user: alice, price: 11, amount: 1000e6, maxPrice: 100});
    }

    function testMultipleUsers() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: 1000e6, maxPrice: 100});
        bidSuccess({user: bob, price: 10, amount: 1000e6, maxPrice: 100});
        bidSuccess({user: alice, price: 11, amount: 2000e6, maxPrice: 200});
        bidSuccess({user: bob, price: 20, amount: 3000e6, maxPrice: 200});

        assertEq(sale.committerStateByAddress(alice).currentBid, EnglishAuctionSale.Bid({price: 11, amount: 2000e6}));
        assertEq(sale.committerStateByAddress(bob).currentBid, EnglishAuctionSale.Bid({price: 20, amount: 3000e6}));
        assertEq(paymentToken.balanceOf(address(sale)), 5000e6);
    }

    function testCannotExceedMaxAmount() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: 2000e6, maxPrice: 100});
        bidFail({
            user: alice,
            price: 10,
            amount: SALE_MAX_AMOUNT + 1,
            maxPrice: 100,
            err: abi.encodeWithSelector(
                EnglishAuctionSale.BidExceedsMaxAmount.selector, SALE_MAX_AMOUNT + 1, SALE_MAX_AMOUNT
            )
        });
        bidSuccess({user: alice, price: 10, amount: SALE_MAX_AMOUNT, maxPrice: 100});
        assertEq(paymentToken.balanceOf(address(sale)), SALE_MAX_AMOUNT);

        bidFail({
            user: bob,
            price: 10,
            amount: SALE_MAX_AMOUNT + 1,
            maxPrice: 100,
            err: abi.encodeWithSelector(
                EnglishAuctionSale.BidExceedsMaxAmount.selector, SALE_MAX_AMOUNT + 1, SALE_MAX_AMOUNT
            )
        });
        bidSuccess({user: bob, price: 10, amount: SALE_MAX_AMOUNT, maxPrice: 100});
        assertEq(paymentToken.balanceOf(address(sale)), 2 * SALE_MAX_AMOUNT);
    }

    function testCannotLowerAmount() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: 2000e6, maxPrice: 100});
        bidFail({
            user: alice,
            price: 10,
            amount: 1500e6,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.BidAmountCannotBeLowered.selector, 1500e6, 2000e6)
        });
    }

    function testCannotLowerPrice() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: 2000e6, maxPrice: 100});
        bidFail({
            user: alice,
            price: 9,
            amount: 2000e6,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.BidPriceCannotBeLowered.selector, 9, 10)
        });
    }

    function testCannotBidAfterClose() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: 1000e6, maxPrice: 100});

        closeAuction();
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Closed));

        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, EnglishAuctionSale.Stage.Closed)
        });
    }

    function testCannotBidBeforeOpen() public {
        bidFail({
            user: alice,
            price: 10,
            amount: 1000e6,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, EnglishAuctionSale.Stage.PreOpen)
        });
    }

    function testCannotBidZeroAmount() public {
        openAuction();
        bidFail({
            user: alice,
            price: 10,
            amount: 0,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.ZeroAmount.selector)
        });
    }

    function testCannotBidZeroPrice() public {
        openAuction();
        bidFail({
            user: alice,
            price: 0,
            amount: 1000e6,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.ZeroPrice.selector)
        });
    }

    function testCannotBidWhilePaused() public {
        openAuction();

        bidSuccess({user: alice, price: 10, amount: 1000e6, maxPrice: 100});

        vm.prank(pauser);
        sale.pause();

        bidFail({
            user: alice,
            price: 11,
            amount: 1000e6,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.SalePaused.selector)
        });

        vm.prank(admin);
        sale.setPaused(false);

        bidSuccess({user: alice, price: 11, amount: 1000e6, maxPrice: 100});
    }

    function testCannotBidAboveMaxPrice() public {
        openAuction();
        bidFail({
            user: alice,
            price: 101,
            amount: 1000e6,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.BidPriceExceedsMaxPrice.selector, 101, 100)
        });
    }

    function testStateReadMethods() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: 2000e6, maxPrice: 100});
        bidSuccess({user: bob, price: 15, amount: SALE_MAX_AMOUNT, maxPrice: 100});
        bidSuccess({user: alice, price: 11, amount: 3000e6, maxPrice: 100});
        bidSuccess({user: charlie, price: 12, amount: 4000e6, maxPrice: 100});

        assertEq(sale.numCommitters(), 3);
        assertEq(sale.committerAt(0), alice);
        assertEq(sale.committerAt(1), bob);
        assertEq(sale.committerAt(2), charlie);

        assertEq(sale.committerStateByAddress(alice).currentBid, EnglishAuctionSale.Bid({price: 11, amount: 3000e6}));
        assertEq(
            sale.committerStateByAddress(bob).currentBid, EnglishAuctionSale.Bid({price: 15, amount: SALE_MAX_AMOUNT})
        );
        assertEq(sale.committerStateByAddress(charlie).currentBid, EnglishAuctionSale.Bid({price: 12, amount: 4000e6}));
    }

    function testStateReadRangeMethods(uint256 from, uint256 to) public {
        to = bound(to, 0, 3);
        from = bound(from, 0, to);

        openAuction();
        bidSuccess({user: alice, price: 10, amount: 2000e6, maxPrice: 100});
        bidSuccess({user: bob, price: 15, amount: SALE_MAX_AMOUNT, maxPrice: 100});
        bidSuccess({user: alice, price: 11, amount: 3000e6, maxPrice: 100});
        bidSuccess({user: charlie, price: 12, amount: 4000e6, maxPrice: 100});

        address[] memory committers = sale.committersIn(from, to);
        for (uint256 i = 0; i < committers.length; i++) {
            assertEq(committers[i], sale.committerAt(from + i));
        }

        EnglishAuctionSale.CommitterState[] memory committerStatesByID = sale.committerStatesIn(from, to);
        for (uint256 i = 0; i < committerStatesByID.length; i++) {
            assertEq(committerStatesByID[i], sale.committerStateByAddress(committers[i]));
        }
    }

    function testCannotBidBelowMinAmount() public {
        openAuction();
        bidFail({
            user: alice,
            price: 10,
            amount: SALE_MIN_AMOUNT - 1,
            maxPrice: 100,
            err: abi.encodeWithSelector(EnglishAuctionSale.BidBelowMinAmount.selector, SALE_MIN_AMOUNT - 1, SALE_MIN_AMOUNT)
        });
    }

    function testCanBidAtMinAmount() public {
        openAuction();
        bidSuccess({user: alice, price: 10, amount: SALE_MIN_AMOUNT, maxPrice: 100});
    }

    function testCanBidAtMinPrice() public {
        openAuction();
        bidSuccess({user: alice, price: 5, amount: 1000e6, minPrice: 5, maxPrice: 100});

        assertEq(sale.committerStateByAddress(alice).currentBid.price, 5);
        assertEq(sale.committerStateByAddress(alice).currentBid.amount, 1000e6);
    }

    function testMaxAddressesPerEntityReached() public {
        // Set max addresses to 2 for testing
        vm.prank(admin);
        sale.setMaxAddressesPerEntity(2);

        openAuction();

        bytes16 entityID = addressToEntityID(alice);
        address alice2 = makeAddr("alice2");
        address alice3 = makeAddr("alice3");

        // First address should work
        doBid({user: alice, price: 10, amount: 1000e6});

        // Second address with same entityID should work
        PurchasePermitWithAuctionData memory purchasePermit2 = makePurchasePermit(entityID, alice2, 100);
        bytes memory purchasePermitSignature2 = signPurchasePermit(purchasePermit2);

        deal(address(paymentToken), alice2, 1000e6);
        vm.prank(alice2);
        paymentToken.approve(address(sale), 1000e6);

        EnglishAuctionSale.Bid memory bid2 = EnglishAuctionSale.Bid({price: 10, amount: 1000e6});
        vm.prank(alice2);
        sale.replaceBidWithApproval(bid2, purchasePermit2, purchasePermitSignature2);

        // Third address with same entityID should fail (max is 2)
        PurchasePermitWithAuctionData memory purchasePermit3 = makePurchasePermit(entityID, alice3, 100);
        bytes memory purchasePermitSignature3 = signPurchasePermit(purchasePermit3);

        deal(address(paymentToken), alice3, 1000e6);
        vm.prank(alice3);
        paymentToken.approve(address(sale), 1000e6);

        EnglishAuctionSale.Bid memory bid3 = EnglishAuctionSale.Bid({price: 10, amount: 1000e6});

        vm.expectRevert(
            abi.encodeWithSelector(EnglishAuctionSale.MaxAddressesPerEntityExceeded.selector, entityID, 2, 2)
        );
        vm.prank(alice3);
        sale.replaceBidWithApproval(bid3, purchasePermit3, purchasePermitSignature3);

        // Increase the limit
        vm.prank(admin);
        sale.setMaxAddressesPerEntity(3);

        // Now third address with same entityID should work
        vm.prank(alice3);
        sale.replaceBidWithApproval(bid3, purchasePermit3, purchasePermitSignature3);
    }
}

contract EnglishAuctionSaleCancellationTest is EnglishAuctionSaleTest {
    struct State {
        uint256 bidAmount;
        bool refunded;
        bool cancelled;
        uint256 userBalance;
        uint256 saleBalance;
    }

    function getState(address committer) internal view returns (State memory) {
        EnglishAuctionSale.CommitterState memory state = sale.committerStateByAddress(committer);
        return State({
            bidAmount: state.currentBid.amount,
            refunded: state.refunded,
            cancelled: state.cancelled,
            userBalance: paymentToken.balanceOf(committer),
            saleBalance: paymentToken.balanceOf(address(sale))
        });
    }

    function cancelBidSuccess(address user) internal {
        State memory stateBefore = getState(user);

        bytes16 entityID = addressToEntityID(user);
        vm.expectEmit(true, true, true, true, address(sale));
        emit EnglishAuctionSale.BidCancelled(entityID, user, stateBefore.bidAmount);

        vm.prank(user);
        sale.cancelBid();

        State memory stateAfter = getState(user);
        assertEq(stateAfter.userBalance, stateBefore.userBalance + stateBefore.bidAmount);
        assertEq(stateAfter.saleBalance, stateBefore.saleBalance - stateBefore.bidAmount);
        assertEq(stateAfter.refunded, true);
        assertEq(stateAfter.cancelled, true);
    }

    function cancelBidFail(address user, bytes memory err) internal {
        vm.expectRevert(err);
        vm.prank(user);
        sale.cancelBid();
    }

    function testSingle() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();

        cancelBidSuccess(alice);
    }

    function testSingleAtExactThreshold() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();

        cancelBidSuccess(alice);
    }

    function testCannotCancelTwice() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();

        cancelBidSuccess(alice);
        cancelBidFail(alice, abi.encodeWithSelector(EnglishAuctionSale.BidAlreadyCancelled.selector, alice));
    }

    function testCannotCancelAfterCancellationPhase() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        cancelBidFail(
            alice, abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, EnglishAuctionSale.Stage.Settlement)
        );
    }

    function testCanOnlyCancelDuringCancellationPhase(uint8 s) public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        EnglishAuctionSale.Stage stage = EnglishAuctionSale.Stage(bound(s, 0, uint8(EnglishAuctionSale.Stage.Done)));

        vm.prank(admin);
        sale.setManualStage(stage);

        if (stage == EnglishAuctionSale.Stage.Cancellation) {
            cancelBidSuccess(alice);
        } else {
            cancelBidFail(alice, abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, stage));
        }
    }

    function testEntityWithoutBidCannotCancel() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();

        cancelBidFail(bob, abi.encodeWithSelector(EnglishAuctionSale.CommitterNotInitialized.selector, bob));
    }

    function testCannotCancelWhilePaused() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();

        vm.prank(pauser);
        sale.pause();

        cancelBidFail(alice, abi.encodeWithSelector(EnglishAuctionSale.SalePaused.selector));

        vm.prank(admin);
        sale.setPaused(false);

        cancelBidSuccess(alice);
    }
}

contract EnglishAuctionSaleSettlementTest is EnglishAuctionSaleTest {
    struct State {
        uint256 userAllocated;
        uint256 totalAcceptedAmount;
    }

    function getState(address committer) internal view returns (State memory) {
        return State({
            totalAcceptedAmount: sale.totalAcceptedAmount(),
            userAllocated: sale.committerStateByAddress(committer).acceptedAmount
        });
    }

    function setAllocationSuccess(address committer, uint256 amount, bool allowOverwrite) internal {
        State memory stateBefore = getState(committer);
        bytes16 entityID = addressToEntityID(committer);

        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({committer: committer, acceptedAmount: amount});

        vm.expectEmit(true, true, true, true, address(sale));
        emit EnglishAuctionSale.AllocationSet(entityID, committer, amount);

        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: allowOverwrite});

        State memory stateAfter = getState(committer);
        assertEq(stateAfter.totalAcceptedAmount, stateBefore.totalAcceptedAmount + amount - stateBefore.userAllocated);
        assertEq(stateAfter.userAllocated, amount);
    }

    function setAllocationFail(address committer, uint256 amount, bool allowOverwrite, bytes memory err) internal {
        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({committer: committer, acceptedAmount: amount});

        vm.expectRevert(err);
        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: allowOverwrite});
    }

    function testSingle() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, 2000e6, false);

        assertEq(sale.totalAcceptedAmount(), 2000e6);
        assertEq(sale.committerStateByAddress(alice).acceptedAmount, 2000e6);
    }

    function testMultiple() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 3000e6});
        doBid({user: bob, price: 10, amount: 5000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, 3000e6, false);
        setAllocationSuccess(bob, 4000e6, false);

        assertEq(sale.totalAcceptedAmount(), 7000e6);
        assertEq(sale.committerStateByAddress(alice).acceptedAmount, 3000e6);
        assertEq(sale.committerStateByAddress(bob).acceptedAmount, 4000e6);
    }

    function testOverwrite() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 3000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, 2000e6, false);
        setAllocationSuccess(alice, 0, true);

        assertEq(sale.totalAcceptedAmount(), 0);
        assertEq(sale.committerStateByAddress(alice).acceptedAmount, 0);

        setAllocationSuccess(alice, 3000e6, true);
        assertEq(sale.totalAcceptedAmount(), 3000e6);
        assertEq(sale.committerStateByAddress(alice).acceptedAmount, 3000e6);
    }

    function testCannotSetAllocationExceedingCommitment() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 1000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationFail(
            alice,
            3000e6,
            false,
            abi.encodeWithSelector(EnglishAuctionSale.AllocationExceedsCommitment.selector, alice, 3000e6, 1000e6)
        );
    }

    function testCannotSetAllocationForNonExistingEntity() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 1000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationFail({
            committer: bob,
            amount: 3000e6,
            allowOverwrite: true,
            err: abi.encodeWithSelector(EnglishAuctionSale.CommitterNotInitialized.selector, bob)
        });
    }

    function testCannotOverwriteAllocationsUnlessOptedIn() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, 1000e6, false);
        setAllocationFail({
            committer: alice,
            amount: 0,
            allowOverwrite: false,
            err: abi.encodeWithSelector(EnglishAuctionSale.AllocationAlreadySet.selector, alice, 1000e6)
        });
        setAllocationSuccess(alice, 2000e6, true);
    }

    function testCannotSetAllocationsWrongStage() public {
        setAllocationFail({
            committer: bob,
            amount: 3000e6,
            allowOverwrite: false,
            err: abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, EnglishAuctionSale.Stage.PreOpen)
        });

        openAuction();
        doBid({user: alice, price: 10, amount: 1000e6});
        setAllocationFail({
            committer: bob,
            amount: 3000e6,
            allowOverwrite: false,
            err: abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, EnglishAuctionSale.Stage.Auction)
        });

        closeAuction();
        openCancellation();
        openSettlement();

        vm.startPrank(admin);
        sale.finalizeSettlement(sale.totalAcceptedAmount());
        vm.stopPrank();

        setAllocationFail({
            committer: bob,
            amount: 3000e6,
            allowOverwrite: false,
            err: abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, EnglishAuctionSale.Stage.Done)
        });
    }

    function testCannotFinalizeOnMismatchingtotalAcceptedAmount() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 1000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, 1000e6, false);

        vm.expectRevert(
            abi.encodeWithSelector(EnglishAuctionSale.UnexpectedTotalAcceptedAmount.selector, 2000e6, 1000e6)
        );
        vm.prank(admin);
        sale.finalizeSettlement(2000e6);

        vm.prank(admin);
        sale.finalizeSettlement(1000e6);
    }

    function testCannotSetAllocationAfterRefund() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        setAllocationSuccess(alice, 1000e6, false);
        finalizeSettlement();

        address[] memory committers = new address[](1);
        committers[0] = alice;

        vm.prank(refunder);
        sale.processRefunds(committers, false);

        vm.prank(admin);
        sale.setManualStage(EnglishAuctionSale.Stage.Settlement);

        setAllocationFail({
            committer: alice,
            amount: 2000e6,
            allowOverwrite: true,
            err: abi.encodeWithSelector(EnglishAuctionSale.AlreadyRefunded.selector, alice)
        });
    }

    function testCannotSetAllocationAfterCancellation() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 2000e6});

        closeAuction();
        openCancellation();

        vm.prank(alice);
        sale.cancelBid();

        openSettlement();
        setAllocationFail({
            committer: alice,
            amount: 2000e6,
            allowOverwrite: true,
            err: abi.encodeWithSelector(EnglishAuctionSale.AlreadyRefunded.selector, alice)
        });
    }

    function testOpenSettlementFromClosed() public {
        openAuction();
        doBid({user: alice, price: 10, amount: 1000e6});

        closeAuction();
        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Closed));

        // Can open settlement directly from Closed stage
        vm.prank(admin);
        sale.openSettlement();

        assertEq(uint8(sale.stage()), uint8(EnglishAuctionSale.Stage.Settlement));
    }
}

contract EnglishAuctionSaleWithdrawRefundsTest is EnglishAuctionSaleTest {
    function setUp() public override {
        super.setUp();

        openAuction();
        doBid({user: alice, price: 10, amount: 5000e6});
        doBid({user: bob, price: 10, amount: 10000e6});
        doBid({user: charlie, price: 10, amount: 10000e6});

        closeAuction();
        openCancellation();
        openSettlement();

        doSetAllocation(alice, 2000e6);
        doSetAllocation(bob, 4000e6);

        // alice    committed  5k -> allocated 2k
        // bob      committed 10k -> allocated 4k
        // charlie  committed 10k -> allocated 0

        // to make sure we can do simple balance assertions later
        assertEq(paymentToken.balanceOf(alice), 0);
        assertEq(paymentToken.balanceOf(bob), 0);
        assertEq(paymentToken.balanceOf(charlie), 0);
    }

    function testWithdrawAndRefund() public {
        finalizeSettlement();

        vm.expectEmit(true, true, true, true, address(sale));
        emit EnglishAuctionSale.Refunded(aliceID, alice, 3000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit EnglishAuctionSale.Refunded(charlieID, charlie, 10000e6);

        address[] memory committers = new address[](2);
        committers[0] = alice;
        committers[1] = charlie;

        vm.prank(refunder);
        sale.processRefunds(committers, false);

        vm.prank(admin);
        sale.withdraw();

        vm.expectEmit(true, true, true, true, address(sale));
        emit EnglishAuctionSale.Refunded(bobID, bob, 6000e6);

        committers = new address[](1);
        committers[0] = bob;

        vm.prank(refunder);
        sale.processRefunds(committers, false);

        assertEq(paymentToken.balanceOf(alice), 3000e6);
        assertEq(paymentToken.balanceOf(bob), 6000e6);
        assertEq(paymentToken.balanceOf(charlie), 10000e6);
        assertEq(paymentToken.balanceOf(receiver), 6000e6);
        assertEq(paymentToken.balanceOf(address(sale)), 0);
    }

    function testCannotWithdrawTwice() public {
        finalizeSettlement();

        vm.startPrank(admin);
        sale.withdraw();

        vm.expectRevert(abi.encodeWithSelector(EnglishAuctionSale.AlreadyWithdrawn.selector));
        sale.withdraw();
    }

    function testCannotProcessRefundsTwice() public {
        finalizeSettlement();

        address[] memory committers = new address[](2);
        committers[0] = alice;
        committers[1] = bob;

        vm.prank(refunder);
        sale.processRefunds(committers, false);

        committers = new address[](2);
        committers[0] = charlie;
        committers[1] = bob; // repeated

        vm.expectRevert(abi.encodeWithSelector(EnglishAuctionSale.AlreadyRefunded.selector, bob));
        vm.prank(refunder);
        sale.processRefunds(committers, false);
    }

    function testRefundTwiceWithSkipping() public {
        finalizeSettlement();

        address[] memory committers = new address[](2);
        committers[0] = alice;
        committers[1] = bob;

        vm.prank(refunder);
        sale.processRefunds(committers, false);

        assertEq(paymentToken.balanceOf(alice), 3000e6);
        assertEq(paymentToken.balanceOf(bob), 6000e6);
        assertEq(paymentToken.balanceOf(charlie), 0);
        assertEq(paymentToken.balanceOf(address(sale)), 16000e6);

        committers = new address[](2);
        committers[0] = charlie;
        committers[1] = bob; // repeated

        vm.expectEmit(true, true, true, true, address(sale));
        emit EnglishAuctionSale.Refunded(charlieID, charlie, 10000e6);

        vm.expectEmit(true, true, true, true, address(sale));
        emit EnglishAuctionSale.RefundedCommitterSkipped(bobID, bob);

        vm.prank(refunder);
        sale.processRefunds(committers, true); // this time we're skipping the already refunded entity

        assertEq(paymentToken.balanceOf(alice), 3000e6);
        assertEq(paymentToken.balanceOf(bob), 6000e6);
        assertEq(paymentToken.balanceOf(charlie), 10000e6);
        assertEq(paymentToken.balanceOf(address(sale)), 6000e6);
    }

    function testCannotProcessRefundsForUsersWithoutBids() public {
        finalizeSettlement();

        address[] memory committers = new address[](1);
        committers[0] = makeAddr("committer without bid");

        vm.expectRevert(abi.encodeWithSelector(EnglishAuctionSale.CommitterNotInitialized.selector, committers[0]));
        vm.prank(refunder);
        sale.processRefunds(committers, false);
    }

    function testCannotProcessRefundsWrongStage() public {
        address[] memory committers = new address[](1);
        committers[0] = alice;

        vm.expectRevert(
            abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, EnglishAuctionSale.Stage.Settlement)
        );
        vm.prank(refunder);
        sale.processRefunds(committers, false);
    }

    function testCannotWithdrawWrongStage() public {
        vm.expectRevert(
            abi.encodeWithSelector(EnglishAuctionSale.InvalidStage.selector, EnglishAuctionSale.Stage.Settlement)
        );
        vm.prank(admin);
        sale.withdraw();
    }

    function testReceiverChange() public {
        finalizeSettlement();

        address newReceiver = makeAddr("newReceiver");
        vm.prank(admin);
        sale.setProceedsReceiver(newReceiver);
        assertEq(sale.proceedsReceiver(), newReceiver);

        vm.startPrank(admin);
        sale.withdraw();

        assertEq(paymentToken.balanceOf(newReceiver), 6000e6);
        assertEq(paymentToken.balanceOf(receiver), 0);
    }

    function testClaimRefundWhenEnabled() public {
        finalizeSettlement();

        // Claim refund should work when enabled
        uint256 balanceBefore = paymentToken.balanceOf(alice);
        vm.prank(alice);
        sale.claimRefund();

        assertEq(paymentToken.balanceOf(alice), balanceBefore + 3000e6);
        assertTrue(sale.committerStateByAddress(alice).refunded);
    }

    function testCannotClaimRefundWhenDisabled() public {
        // Disable claim refund
        vm.prank(admin);
        sale.setClaimRefundEnabled(false);

        finalizeSettlement();

        // Claim refund should fail when disabled
        vm.expectRevert(abi.encodeWithSelector(EnglishAuctionSale.ClaimRefundDisabled.selector));
        vm.prank(alice);
        sale.claimRefund();

        // But refunder can still process refunds
        address[] memory committers = new address[](1);
        committers[0] = alice;

        vm.prank(refunder);
        sale.processRefunds(committers, false);

        assertTrue(sale.committerStateByAddress(alice).refunded);
        assertEq(paymentToken.balanceOf(alice), 3000e6);
    }

    function testClaimRefundCanBeReEnabled() public {
        // Disable claim refund
        vm.prank(admin);
        sale.setClaimRefundEnabled(false);

        finalizeSettlement();

        // Claim refund should fail when disabled
        vm.expectRevert(abi.encodeWithSelector(EnglishAuctionSale.ClaimRefundDisabled.selector));
        vm.prank(alice);
        sale.claimRefund();

        // Re-enable claim refund
        vm.prank(admin);
        sale.setClaimRefundEnabled(true);

        // Now claim refund should work
        uint256 balanceBefore = paymentToken.balanceOf(alice);
        vm.prank(alice);
        sale.claimRefund();

        assertEq(paymentToken.balanceOf(alice), balanceBefore + 3000e6);
    }

    function testCannotClaimRefundTwice() public {
        finalizeSettlement();

        // First claim should succeed
        uint256 balanceBefore = paymentToken.balanceOf(alice);
        vm.prank(alice);
        sale.claimRefund();

        assertEq(paymentToken.balanceOf(alice), balanceBefore + 3000e6);
        assertTrue(sale.committerStateByAddress(alice).refunded);

        // Second claim should fail
        vm.expectRevert(abi.encodeWithSelector(EnglishAuctionSale.AlreadyRefunded.selector, alice));
        vm.prank(alice);
        sale.claimRefund();

        // Balance should not change
        assertEq(paymentToken.balanceOf(alice), balanceBefore + 3000e6);
    }

    function testCannotProcessRefundAfterClaimed() public {
        finalizeSettlement();

        // User claims their own refund
        vm.prank(alice);
        sale.claimRefund();

        assertTrue(sale.committerStateByAddress(alice).refunded);

        // Refunder tries to process refund for already refunded user
        address[] memory committers = new address[](1);
        committers[0] = alice;

        vm.expectRevert(abi.encodeWithSelector(EnglishAuctionSale.AlreadyRefunded.selector, alice));
        vm.prank(refunder);
        sale.processRefunds(committers, false);
    }

    function testCannotClaimRefundAfterProcessed() public {
        finalizeSettlement();

        // Refunder processes refund
        address[] memory committers = new address[](1);
        committers[0] = alice;

        vm.prank(refunder);
        sale.processRefunds(committers, false);

        assertTrue(sale.committerStateByAddress(alice).refunded);
        assertEq(paymentToken.balanceOf(alice), 3000e6);

        // User tries to claim refund after it's already been processed
        vm.expectRevert(abi.encodeWithSelector(EnglishAuctionSale.AlreadyRefunded.selector, alice));
        vm.prank(alice);
        sale.claimRefund();

        // Balance should not change
        assertEq(paymentToken.balanceOf(alice), 3000e6);
    }
}

contract EnglishAuctionSaleRecoverTokensTest is EnglishAuctionSaleTest {
    function testRecoverTokens() public {
        deal(address(paymentToken), address(sale), 1000000);

        vm.startPrank(admin);
        sale.grantRole(sale.TOKEN_RECOVERER_ROLE(), recoverer);
        vm.stopPrank();

        vm.startPrank(recoverer);
        sale.recoverTokens(paymentToken, 1000000, receiver);
        vm.stopPrank();

        assertEq(paymentToken.balanceOf(receiver), 1000000);
    }
}

contract EnglishAuctionSaleFuzzTest is EnglishAuctionSaleTest {
    uint64 constant MAX_PRICE = type(uint64).max;

    struct FuzzedAuctionBids {
        address wallet;
        EnglishAuctionSale.Bid bid;
    }

    mapping(address => EnglishAuctionSale.Bid) lastBid;

    address[] committersToRefundAfterSettlement;

    function test_Success_Fuzzed(FuzzedAuctionBids[] memory auctionBids, uint128 manuallySentUSDT) public {
        deal(address(paymentToken), address(sale), manuallySentUSDT);

        checkInvariants(manuallySentUSDT);
        openAuction();

        uint256 totalComittedAmountExpected = 0;
        for (uint256 i = 0; i < auctionBids.length; i++) {
            FuzzedAuctionBids memory bid = auctionBids[i];
            if (isDisallowedAddress(bid.wallet)) {
                continue;
            }

            EnglishAuctionSale.Bid memory previousBid = lastBid[bid.wallet];

            bid.bid.price = uint64(bound(bid.bid.price, 1, MAX_PRICE));
            bid.bid.amount =
                uint256(bound(bid.bid.amount, Math.max(SALE_MIN_AMOUNT, previousBid.amount), SALE_MAX_AMOUNT));

            if (bid.bid.price < previousBid.price) {
                bid.bid.price = previousBid.price;
            }

            uint256 amountDelta = bid.bid.amount - previousBid.amount;
            deal(address(paymentToken), bid.wallet, amountDelta);
            doBid({user: bid.wallet, price: bid.bid.price, amount: bid.bid.amount, maxPrice: MAX_PRICE});

            // update test counters
            totalComittedAmountExpected += amountDelta;
            lastBid[bid.wallet] = bid.bid;

            assertEq(
                sale.committerStateByAddress(bid.wallet).currentBid, lastBid[bid.wallet], "active bid should be updated"
            );
            assertEq(paymentToken.balanceOf(bid.wallet), 0, "balance of bidder after bid");
        }

        checkInvariants(manuallySentUSDT);

        assertEq(sale.totalComittedAmount(), totalComittedAmountExpected, "total auction commitments after bids");
        assertEq(sale.totalAcceptedAmount(), 0, "total allocated paymentToken after bids");

        // assume we have at least one commitment so the auction can be closed
        vm.assume(sale.totalComittedAmount() > 0);
        closeAuction();

        openCancellation();

        address[] memory committers = sale.allCommitters();
        for (uint256 i = 0; i < committers.length; i++) {
            address committer = committers[i];
            bytes32 rand = keccak256(abi.encode(i, committer, "cancel"));

            // do nothing for 80% of the entities
            if (uint256(rand) % 100 < 80) {
                continue;
            }

            vm.prank(committer);
            sale.cancelBid();
        }

        checkInvariants(manuallySentUSDT);
        openSettlement();

        uint256 totalAcceptedAmount = 0;
        for (uint256 i = 0; i < committers.length; i++) {
            address committer = committers[i];
            bytes32 rand = keccak256(abi.encode(i, committer));

            EnglishAuctionSale.CommitterState memory committerState = sale.committerStateByAddress(committer);
            if (committerState.refunded) {
                continue;
            }

            committersToRefundAfterSettlement.push(committer);

            uint256 acceptedAmount = uint256(bound(uint256(rand), 0, committerState.currentBid.amount));
            if (acceptedAmount == 0) {
                continue;
            }

            doSetAllocation(committerState.addr, acceptedAmount);
            totalAcceptedAmount += acceptedAmount;
        }

        assertEq(sale.totalAcceptedAmount(), totalAcceptedAmount, "total allocated paymentToken after allocations");
        checkInvariants(manuallySentUSDT);

        finalizeSettlement();

        // process refunds
        vm.prank(refunder);
        sale.processRefunds(committersToRefundAfterSettlement, false);

        // check that all entities are refunded
        EnglishAuctionSale.CommitterState[] memory committerStates = sale.allCommitterStates();
        for (uint256 i = 0; i < committerStates.length; i++) {
            EnglishAuctionSale.CommitterState memory committerState = committerStates[i];
            assertTrue(committerState.refunded, "entity should be refunded");
        }

        checkInvariants(manuallySentUSDT);

        // withdrawing funds
        // double checking that the initial receiver balance is 0 so the next check is valid
        assertEq(paymentToken.balanceOf(receiver), 0, "receiver balance should be 0 before withdraw");
        vm.prank(admin);
        sale.withdraw();
        assertEq(
            paymentToken.balanceOf(receiver),
            totalAcceptedAmount,
            "receiver balance is the total allocated paymentToken"
        );

        // the manually sent paymentToken should still be in the sale after everything is withdrawn
        assertEq(
            paymentToken.balanceOf(address(sale)),
            manuallySentUSDT,
            "the manually sent paymentToken is still in the sale after withdraw"
        );

        // recover any manually sent paymentTokens
        address recoverReceiver = makeAddr("recoverReceiver");
        vm.prank(recoverer);
        sale.recoverTokens(paymentToken, manuallySentUSDT, recoverReceiver);
        assertEq(
            paymentToken.balanceOf(recoverReceiver),
            manuallySentUSDT,
            "recoverReceiver balance should be 1M after paymentToken recovery"
        );

        assertEq(paymentToken.balanceOf(address(sale)), 0, "sale balance is 0 at the end");
    }

    function checkInvariants(uint256 manuallySentUSDT) internal view {
        address[] memory committers = sale.allCommitters();
        EnglishAuctionSale.CommitterState[] memory committerStates = sale.allCommitterStates();
        assertEq(committers.length, committerStates.length);

        // sum of auction commitments == total auction commitments
        uint256 sumAuctionCommitments = 0;
        for (uint256 i = 0; i < committerStates.length; i++) {
            sumAuctionCommitments += committerStates[i].currentBid.amount;
        }
        assertEq(sale.totalComittedAmount(), sumAuctionCommitments, "total auction commitments");

        uint256 sumRefundedAmounts = 0;
        for (uint256 i = 0; i < committerStates.length; i++) {
            if (!committerStates[i].refunded) {
                continue;
            }
            sumRefundedAmounts += committerStates[i].currentBid.amount - committerStates[i].acceptedAmount;
        }
        assertEq(sale.totalRefundedAmount(), sumRefundedAmounts, "total refunded amount");

        assertEq(
            paymentToken.balanceOf(address(sale)),
            sumAuctionCommitments - sumRefundedAmounts + manuallySentUSDT,
            "total paymentToken balance"
        );
    }

    function isDisallowedAddress(address addr) internal view returns (bool) {
        return addr == address(0) || addr == address(sale) || addr == receiver;
    }
}

contract BidDataReaderTest is EnglishAuctionSaleTest {
    using EnumerableSet for EnumerableSet.AddressSet;

    function assertEq(IAuctionBidDataReader.BidData memory a, IAuctionBidDataReader.BidData memory b) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(
        IAuctionBidDataReader.BidData memory a,
        IAuctionBidDataReader.BidData memory b,
        string memory message
    ) internal pure {
        assertEq(a.bidID, b.bidID, string.concat(message, " bidID"));
        assertEq(a.committer, b.committer, string.concat(message, " committer"));
        assertEq(a.entityID, b.entityID, string.concat(message, " entityID"));
        assertEq(a.timestamp, b.timestamp, string.concat(message, " timestamp"));
        assertEq(a.price, b.price, string.concat(message, " price"));
        assertEq(a.amount, b.amount, string.concat(message, " amount"));
        assertEq(a.refunded, b.refunded, string.concat(message, " refunded"));
        assertEq(a.extraData, b.extraData, string.concat(message, " extraData"));
    }

    function testNumBidsEmpty() public {
        assertEq(sale.numBids(), 0, "numBids should be 0 for empty auction");
    }

    function testNumBidsSingleBid() public {
        openAuction();
        doBid(alice, 1000e6, 10);
        assertEq(sale.numBids(), 1, "numBids should be 1 after single bid");
    }

    function testNumBidsMultipleBidsFromSameCommitter() public {
        openAuction();
        doBid(alice, 1000e6, 10);
        doBid(alice, 2000e6, 20);
        doBid(alice, 3000e6, 30);
        assertEq(sale.numBids(), 1, "numBids should be 1 when same committer places multiple bids");
    }

    function testNumBidsMultipleCommitters() public {
        openAuction();
        doBid(alice, 1000e6, 10);
        doBid(bob, 2000e6, 20);
        doBid(charlie, 3000e6, 30);
        assertEq(sale.numBids(), 3, "numBids should be 3 for three committers");
    }

    function testReadBidDataAtSingleBid() public {
        openAuction();
        vm.warp(1000);
        doBid(alice, 1000e6, 10);

        IAuctionBidDataReader.BidData memory bidData = sale.readBidDataAt(0);

        assertEq(bidData.bidID, bytes32(uint256(uint160(alice))), "bidID should be derived from committer address");
        assertEq(bidData.committer, alice, "committer should be alice");
        assertEq(bidData.entityID, aliceID, "entityID should be aliceID");
        assertEq(bidData.timestamp, uint64(1000), "timestamp should match block timestamp");
        assertEq(bidData.price, 10, "price should be 10");
        assertEq(bidData.amount, 1000e6, "amount should be 1000e6");
        assertEq(bidData.refunded, false, "refunded should be false");
        assertEq(bidData.extraData, hex"", "extraData should be empty");
    }

    function testReadBidDataAtMultipleCommitters() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, 1000e6, 10);

        vm.warp(2000);
        doBid(bob, 2000e6, 20);

        vm.warp(3000);
        doBid(charlie, 3000e6, 30);

        IAuctionBidDataReader.BidData memory aliceBidData = sale.readBidDataAt(0);
        assertEq(aliceBidData.committer, alice, "first bid should be alice");
        assertEq(aliceBidData.price, 10, "alice price should be 10");
        assertEq(aliceBidData.amount, 1000e6, "alice amount should be 1000e6");
        assertEq(aliceBidData.timestamp, uint64(1000), "alice timestamp should be 1000");

        IAuctionBidDataReader.BidData memory bobBidData = sale.readBidDataAt(1);
        assertEq(bobBidData.committer, bob, "second bid should be bob");
        assertEq(bobBidData.price, 20, "bob price should be 20");
        assertEq(bobBidData.amount, 2000e6, "bob amount should be 2000e6");
        assertEq(bobBidData.timestamp, uint64(2000), "bob timestamp should be 2000");

        IAuctionBidDataReader.BidData memory charlieBidData = sale.readBidDataAt(2);
        assertEq(charlieBidData.committer, charlie, "third bid should be charlie");
        assertEq(charlieBidData.price, 30, "charlie price should be 30");
        assertEq(charlieBidData.amount, 3000e6, "charlie amount should be 3000e6");
        assertEq(charlieBidData.timestamp, uint64(3000), "charlie timestamp should be 3000");
    }

    function testReadBidDataAtReflectsLatestBid() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, 1000e6, 10);

        vm.warp(2000);
        doBid(alice, 2000e6, 20);

        IAuctionBidDataReader.BidData memory bidData = sale.readBidDataAt(0);
        assertEq(bidData.price, 20, "price should reflect latest bid");
        assertEq(bidData.amount, 2000e6, "amount should reflect latest bid");
        assertEq(bidData.timestamp, uint64(2000), "timestamp should reflect latest bid");
    }

    function testReadBidDataInEmpty() public {
        IAuctionBidDataReader.BidData[] memory bidData = sale.readBidDataIn(0, 0);
        assertEq(bidData.length, 0, "readBidDataIn should return empty array for empty range");
    }

    function testReadBidDataInSingleBid() public {
        openAuction();
        vm.warp(1000);
        doBid(alice, 1000e6, 10);

        IAuctionBidDataReader.BidData[] memory bidData = sale.readBidDataIn(0, 1);
        assertEq(bidData.length, 1, "readBidDataIn should return 1 bid");
        assertEq(bidData[0].committer, alice, "committer should be alice");
        assertEq(bidData[0].price, 10, "price should be 10");
        assertEq(bidData[0].amount, 1000e6, "amount should be 1000e6");
    }

    function testReadBidDataInMultipleBids() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, 1000e6, 10);
        vm.warp(2000);
        doBid(bob, 2000e6, 20);
        vm.warp(3000);
        doBid(charlie, 3000e6, 30);

        IAuctionBidDataReader.BidData[] memory bidData = sale.readBidDataIn(0, 3);
        assertEq(bidData.length, 3, "readBidDataIn should return 3 bids");

        assertEq(bidData[0].committer, alice, "first bid should be alice");
        assertEq(bidData[1].committer, bob, "second bid should be bob");
        assertEq(bidData[2].committer, charlie, "third bid should be charlie");
    }

    function testReadBidDataInPagination() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, 1000e6, 10);
        vm.warp(2000);
        doBid(bob, 2000e6, 20);
        vm.warp(3000);
        doBid(charlie, 3000e6, 30);

        // Read first 2 bids
        IAuctionBidDataReader.BidData[] memory page1 = sale.readBidDataIn(0, 2);
        assertEq(page1.length, 2, "first page should have 2 bids");
        assertEq(page1[0].committer, alice, "first page should start with alice");
        assertEq(page1[1].committer, bob, "first page should end with bob");

        // Read last bid
        IAuctionBidDataReader.BidData[] memory page2 = sale.readBidDataIn(2, 3);
        assertEq(page2.length, 1, "second page should have 1 bid");
        assertEq(page2[0].committer, charlie, "second page should be charlie");
    }

    function testReadBidDataInPartialRange() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, 1000e6, 10);
        vm.warp(2000);
        doBid(bob, 2000e6, 20);
        vm.warp(3000);
        doBid(charlie, 3000e6, 30);

        IAuctionBidDataReader.BidData[] memory bidData = sale.readBidDataIn(1, 2);
        assertEq(bidData.length, 1, "should return 1 bid");
        assertEq(bidData[0].committer, bob, "should be bob's bid");
    }

    function testReadBidDataInReflectsRefundStatus() public {
        openAuction();
        doBid(alice, 1000e6, 10);
        doBid(bob, 2000e6, 20);

        closeAuction();
        openSettlement();

        doSetAllocation(alice, 500e6);
        doSetAllocation(bob, 1000e6);

        finalizeSettlement();

        // Refund alice
        vm.prank(refunder);
        address[] memory committers = new address[](1);
        committers[0] = alice;
        sale.processRefunds(committers, false);

        IAuctionBidDataReader.BidData[] memory bidData = sale.readBidDataIn(0, 2);

        assertEq(bidData[0].committer, alice, "first should be alice");
        assertEq(bidData[0].refunded, true, "alice should be refunded");
        assertEq(bidData[1].committer, bob, "second should be bob");
        assertEq(bidData[1].refunded, false, "bob should not be refunded yet");
    }

    function testBidIDIsUnique() public {
        openAuction();
        doBid(alice, 1000e6, 10);
        doBid(bob, 2000e6, 20);
        doBid(charlie, 3000e6, 30);

        IAuctionBidDataReader.BidData[] memory bidData = sale.readBidDataIn(0, 3);

        // bidIDs should be unique
        assertTrue(bidData[0].bidID != bidData[1].bidID, "alice and bob bidIDs should differ");
        assertTrue(bidData[0].bidID != bidData[2].bidID, "alice and charlie bidIDs should differ");
        assertTrue(bidData[1].bidID != bidData[2].bidID, "bob and charlie bidIDs should differ");

        // bidIDs should be derived from committer addresses
        assertEq(bidData[0].bidID, bytes32(uint256(uint160(alice))), "alice bidID should match address");
        assertEq(bidData[1].bidID, bytes32(uint256(uint160(bob))), "bob bidID should match address");
        assertEq(bidData[2].bidID, bytes32(uint256(uint160(charlie))), "charlie bidID should match address");
    }

    function testBidIDRemainsConstantOnUpdate() public {
        openAuction();
        vm.warp(1000);
        doBid(alice, 1000e6, 10);

        IAuctionBidDataReader.BidData memory bidData1 = sale.readBidDataAt(0);
        bytes32 originalBidID = bidData1.bidID;

        vm.warp(2000);
        doBid(alice, 2000e6, 20);

        IAuctionBidDataReader.BidData memory bidData2 = sale.readBidDataAt(0);
        assertEq(bidData2.bidID, originalBidID, "bidID should remain constant when committer updates bid");
        assertEq(bidData2.price, 20, "price should be updated");
        assertEq(bidData2.amount, 2000e6, "amount should be updated");
    }

    function testReadBidDataConsistencyWithNumBids() public {
        openAuction();
        doBid(alice, 1000e6, 10);
        doBid(bob, 2000e6, 20);
        doBid(charlie, 3000e6, 30);

        uint256 numBids = sale.numBids();
        IAuctionBidDataReader.BidData[] memory bidData = sale.readBidDataIn(0, numBids);

        assertEq(bidData.length, numBids, "readBidDataIn should return numBids bids");
    }
}
