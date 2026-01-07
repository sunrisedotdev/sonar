// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IEntityAllocationDataReader} from "sonar/interfaces/IEntityAllocationDataReader.sol";
import {ITotalCommitmentsReader} from "sonar/interfaces/ITotalCommitmentsReader.sol";

import "./SettlementSaleBaseTest.sol";

contract SettlementSaleConstructorTest is BaseTest {
    ERC20FakeWithDecimals usdc;
    ERC20FakeWithDecimals usdt;

    Account permitSigner = makeAccount("permitSigner");
    address internal immutable pauser = makeAddr("pauser");
    address internal immutable receiver = makeAddr("receiver");
    address internal immutable settler = makeAddr("settler");
    address internal immutable refunder = makeAddr("refunder");

    address[] internal defaultExtraManagers;
    address[] internal defaultPausers;

    function setUp() public {
        usdc = new ERC20FakeWithDecimals("USD", "USD", 6);
        vm.label(address(usdc), "FAKE-usdc");

        usdt = new ERC20FakeWithDecimals("USDT", "USDT", 6);
        vm.label(address(usdt), "FAKE-usdt");

        defaultExtraManagers = new address[](1);
        defaultExtraManagers[0] = manager;

        defaultPausers = new address[](1);
        defaultPausers[0] = pauser;
    }

    function _defaultPaymentTokens() internal view returns (IERC20Metadata[] memory) {
        IERC20Metadata[] memory tokens = new IERC20Metadata[](2);
        tokens[0] = IERC20Metadata(address(usdc));
        tokens[1] = IERC20Metadata(address(usdt));
        return tokens;
    }

    function testConstructor_WithValidParams_DeploysSuccessfully() public {
        SettlementSale.Init memory init = SettlementSale.Init({
            saleUUID: TEST_SALE_UUID,
            admin: admin,
            extraManagers: defaultExtraManagers,
            purchasePermitSigner: permitSigner.addr,
            proceedsReceiver: receiver,
            extraPausers: defaultPausers,
            extraSettler: settler,
            extraRefunder: refunder,
            closeAuctionAtTimestamp: 0,
            claimRefundEnabled: true,
            paymentTokens: _defaultPaymentTokens(),
            expectedPaymentTokenDecimals: 6
        });
        TestableSettlementSale sale = new TestableSettlementSale(init);

        assertEq(sale.getRoleMemberCount(sale.SALE_MANAGER_ROLE()), 2);
        assertEq(sale.getRoleMember(sale.SALE_MANAGER_ROLE(), 0), admin);
        assertEq(sale.getRoleMember(sale.SALE_MANAGER_ROLE(), 1), manager);

        assertEq(sale.getRoleMemberCount(sale.PAUSER_ROLE()), 2);
        assertEq(sale.getRoleMember(sale.PAUSER_ROLE(), 0), admin);
        assertEq(sale.getRoleMember(sale.PAUSER_ROLE(), 1), pauser);

        assertEq(sale.getRoleMemberCount(sale.SETTLER_ROLE()), 2);
        assertEq(sale.getRoleMember(sale.SETTLER_ROLE(), 0), admin);
        assertEq(sale.getRoleMember(sale.SETTLER_ROLE(), 1), settler);

        assertEq(sale.getRoleMemberCount(sale.REFUNDER_ROLE()), 2);
        assertEq(sale.getRoleMember(sale.REFUNDER_ROLE(), 0), admin);
        assertEq(sale.getRoleMember(sale.REFUNDER_ROLE(), 1), refunder);

        assertEq(sale.getRoleMemberCount(sale.PURCHASE_PERMIT_SIGNER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.PURCHASE_PERMIT_SIGNER_ROLE(), 0), permitSigner.addr);

        assertEq(sale.getRoleMemberCount(sale.TOKEN_RECOVERER_ROLE()), 0);
    }

    function testConstructor_NoExtraRoles_DeploysSuccessfully() public {
        SettlementSale.Init memory init = SettlementSale.Init({
            saleUUID: TEST_SALE_UUID,
            admin: admin,
            extraManagers: new address[](0),
            purchasePermitSigner: permitSigner.addr,
            proceedsReceiver: receiver,
            extraPausers: new address[](0),
            extraSettler: address(0),
            extraRefunder: address(0),
            closeAuctionAtTimestamp: 0,
            claimRefundEnabled: true,
            paymentTokens: _defaultPaymentTokens(),
            expectedPaymentTokenDecimals: 6
        });
        TestableSettlementSale sale = new TestableSettlementSale(init);

        assertEq(sale.getRoleMemberCount(sale.SALE_MANAGER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.SALE_MANAGER_ROLE(), 0), admin);

        assertEq(sale.getRoleMemberCount(sale.PAUSER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.PAUSER_ROLE(), 0), admin);

        assertEq(sale.getRoleMemberCount(sale.SETTLER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.SETTLER_ROLE(), 0), admin);

        assertEq(sale.getRoleMemberCount(sale.REFUNDER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.REFUNDER_ROLE(), 0), admin);
    }

    function testConstructor_AdminAsExtraRoles_DeploysSuccessfully() public {
        address[] memory extraManagers = new address[](1);
        extraManagers[0] = admin;

        address[] memory extraPausers = new address[](1);
        extraPausers[0] = admin;

        SettlementSale.Init memory init = SettlementSale.Init({
            saleUUID: TEST_SALE_UUID,
            admin: admin,
            extraManagers: extraManagers,
            purchasePermitSigner: permitSigner.addr,
            proceedsReceiver: receiver,
            extraPausers: extraPausers,
            extraSettler: admin,
            extraRefunder: admin,
            closeAuctionAtTimestamp: 0,
            claimRefundEnabled: true,
            paymentTokens: _defaultPaymentTokens(),
            expectedPaymentTokenDecimals: 6
        });
        TestableSettlementSale sale = new TestableSettlementSale(init);

        assertEq(sale.getRoleMemberCount(sale.SALE_MANAGER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.SALE_MANAGER_ROLE(), 0), admin);

        assertEq(sale.getRoleMemberCount(sale.PAUSER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.PAUSER_ROLE(), 0), admin);

        assertEq(sale.getRoleMemberCount(sale.SETTLER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.SETTLER_ROLE(), 0), admin);

        assertEq(sale.getRoleMemberCount(sale.REFUNDER_ROLE()), 1);
        assertEq(sale.getRoleMember(sale.REFUNDER_ROLE(), 0), admin);
    }

    function testConstructor_InvalidDecimals_Reverts() public {
        ERC20FakeWithDecimals invalidToken = new ERC20FakeWithDecimals("INVALID", "INV", 18);

        IERC20Metadata[] memory invalidTokens = new IERC20Metadata[](2);
        invalidTokens[0] = IERC20Metadata(address(invalidToken));
        invalidTokens[1] = usdt;

        SettlementSale.Init memory init = SettlementSale.Init({
            saleUUID: TEST_SALE_UUID,
            admin: admin,
            extraManagers: defaultExtraManagers,
            purchasePermitSigner: permitSigner.addr,
            proceedsReceiver: receiver,
            extraPausers: defaultPausers,
            extraSettler: settler,
            extraRefunder: refunder,
            closeAuctionAtTimestamp: 0,
            claimRefundEnabled: true,
            paymentTokens: invalidTokens,
            expectedPaymentTokenDecimals: 6
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                SettlementSale.InvalidPaymentTokenDecimals.selector, IERC20Metadata(address(invalidToken))
            )
        );
        new TestableSettlementSale(init);
    }

    function testConstructor_DuplicateTokens_Reverts() public {
        IERC20Metadata[] memory duplicateTokens = new IERC20Metadata[](2);
        duplicateTokens[0] = IERC20Metadata(address(usdc));
        duplicateTokens[1] = IERC20Metadata(address(usdc));

        SettlementSale.Init memory init = SettlementSale.Init({
            saleUUID: TEST_SALE_UUID,
            admin: admin,
            extraManagers: defaultExtraManagers,
            purchasePermitSigner: permitSigner.addr,
            proceedsReceiver: receiver,
            extraPausers: defaultPausers,
            extraSettler: settler,
            extraRefunder: refunder,
            closeAuctionAtTimestamp: 0,
            claimRefundEnabled: true,
            paymentTokens: duplicateTokens,
            expectedPaymentTokenDecimals: 6
        });

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.DuplicatePaymentToken.selector, usdc));
        new TestableSettlementSale(init);
    }

    function testConstructor_NoPaymentTokens_Reverts() public {
        IERC20Metadata[] memory emptyTokens = new IERC20Metadata[](0);

        SettlementSale.Init memory init = SettlementSale.Init({
            saleUUID: TEST_SALE_UUID,
            admin: admin,
            extraManagers: defaultExtraManagers,
            purchasePermitSigner: permitSigner.addr,
            proceedsReceiver: receiver,
            extraPausers: defaultPausers,
            extraSettler: settler,
            extraRefunder: refunder,
            closeAuctionAtTimestamp: 0,
            claimRefundEnabled: true,
            paymentTokens: emptyTokens,
            expectedPaymentTokenDecimals: 6
        });

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.NoPaymentTokens.selector));
        new TestableSettlementSale(init);
    }
}

contract SettlementSaleVandalTest is SettlementSaleBaseTest {
    function testRecoverTokens_ByUnauthorizedUser_Reverts(address vandal, IERC20 usdc, uint256 amount, address to)
        public
    {
        vm.assume(vandal != recoverer);
        vm.expectRevert(missingRoleError(vandal, sale.TOKEN_RECOVERER_ROLE()));
        vm.prank(vandal);
        sale.recoverTokens(usdc, amount, to);
    }

    function testSetReceiver_ByUnauthorizedUser_Reverts(address vandal, address newReceiver) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.setProceedsReceiver(newReceiver);
    }

    function testSetReceiver_ToZeroAddress_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.ZeroAddress.selector));
        sale.setProceedsReceiver(address(0));
    }

    function testWithdraw_ByUnauthorizedUser_Reverts(address vandal) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.withdraw();
    }

    function testSetAllocations_ByUnauthorizedUser_Reverts(
        address vandal,
        IOffchainSettlement.Allocation[] memory allocations
    ) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != settler);
        vm.expectRevert(missingRoleError(vandal, sale.SETTLER_ROLE()));
        vm.prank(vandal);
        sale.setAllocations({allocations: allocations, allowOverwrite: false});
    }

    function testSetCloseAuctionAtTimestamp_ByUnauthorizedUser_Reverts(address vandal, uint64 timestamp) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.setCloseAuctionAtTimestamp(timestamp);
    }

    function testOpenAuction_ByUnauthorizedUser_Reverts(address vandal) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.openAuction();
    }

    function testOpenCancellation_ByUnauthorizedUser_Reverts(address vandal) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.openCancellation();
    }

    function testCloseAuction_ByUnauthorizedUser_Reverts(address vandal) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.closeAuction();
    }

    function testReopenAuction_ByUnauthorizedUser_Reverts(address vandal, uint64 timestamp) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.reopenAuction(timestamp);
    }

    function testOpenSettlement_ByUnauthorizedUser_Reverts(address vandal) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.openSettlement();
    }

    function testFinalizeSettlement_ByUnauthorizedUser_Reverts(address vandal, uint256 totalAcceptedAmount) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.SETTLEMENT_FINALIZER_ROLE()));
        vm.prank(vandal);
        sale.finalizeSettlement(totalAcceptedAmount);
    }

    function testPause_ByUnauthorizedUser_Reverts(address vandal) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != pauser);
        vm.expectRevert(missingRoleError(vandal, sale.PAUSER_ROLE()));
        vm.prank(vandal);
        sale.pause();
    }

    function testSetPaused_ByUnauthorizedUser_Reverts(address vandal, bool paused) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.setPaused(paused);
    }

    function testProcessRefunds_ByUnauthorizedUser_Reverts(address vandal, bytes16[] calldata entityIDs) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != refunder);
        vm.expectRevert(missingRoleError(vandal, sale.REFUNDER_ROLE()));
        vm.prank(vandal);
        sale.processRefunds(entityIDs, false);
    }

    function testSetClaimRefundEnabled_ByUnauthorizedUser_Reverts(address vandal, bool enabled) public {
        vm.assume(vandal != admin);
        vm.assume(vandal != manager);
        vm.expectRevert(missingRoleError(vandal, sale.SALE_MANAGER_ROLE()));
        vm.prank(vandal);
        sale.setClaimRefundEnabled(enabled);
    }

    function testUnsafeSetStage_ByUnauthorizedUser_Reverts(address vandal) public {
        vm.assume(vandal != admin);
        vm.expectRevert(missingRoleError(vandal, sale.DEFAULT_ADMIN_ROLE()));
        vm.prank(vandal);
        sale.unsafeSetStage(SettlementSale.Stage.Auction);
    }
}

contract SettlementSaleStageTest is SettlementSaleBaseTest {
    function testStage_CloseAtTimestamp_TransitionsAutomatically(uint256 startTime) public {
        startTime = bound(startTime, 0, type(uint32).max);
        vm.warp(startTime);

        assertEq(uint8(sale.manualStage()), uint8(SettlementSale.Stage.PreOpen));
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.PreOpen));

        vm.warp(startTime + 5 hours);
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.PreOpen));

        vm.prank(manager);
        sale.setCloseAuctionAtTimestamp(uint64(startTime + 24 hours));

        // moving on to auction

        vm.prank(manager);
        sale.openAuction();
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Auction));

        // should automatically close after the close timestamp
        vm.warp(startTime + 24 hours - 1 seconds);
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Auction));

        vm.warp(startTime + 24 hours);
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Closed));

        // extending the sale close window
        vm.prank(manager);
        sale.reopenAuction(uint64(block.timestamp + 1 hours));
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Auction));

        vm.warp(block.timestamp + 30 minutes);
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Auction));

        vm.warp(block.timestamp + 30 minutes);
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Closed));

        // disable automatic closing
        vm.prank(manager);
        sale.setCloseAuctionAtTimestamp(0);
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Auction));
    }

    function testOpenAuction_WhenNotPreOpen_Reverts() public {
        openAuction();
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Auction));

        // Try to open auction again while in Auction stage
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.Auction));
        vm.prank(manager);
        sale.openAuction();
    }

    function testCloseAuction_WhenNotAuction_Reverts() public {
        // Try to close while in PreOpen
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.PreOpen));
        vm.prank(manager);
        sale.closeAuction();
    }

    function testReopenAuction_WhenNotClosed_Reverts() public {
        // Try to reopen while in PreOpen
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.PreOpen));
        vm.prank(manager);
        sale.reopenAuction(uint64(block.timestamp + 1 hours));

        // Try to reopen while in Auction
        openAuction();
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.Auction));
        vm.prank(manager);
        sale.reopenAuction(uint64(block.timestamp + 1 hours));
    }

    function testReopenAuction_WithPastTimestamp_ImmediatelyCloses() public {
        openAuction();

        // Disable auto close first
        vm.prank(manager);
        sale.setCloseAuctionAtTimestamp(0);

        closeAuction();
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Closed));

        // Reopen with a past timestamp - auction immediately closes again
        vm.prank(manager);
        sale.reopenAuction(uint64(block.timestamp - 1));

        // manualStage is Auction, but stage() returns Closed because timestamp is in the past
        assertEq(uint8(sale.manualStage()), uint8(SettlementSale.Stage.Auction));
        assertEq(uint8(sale.stage()), uint8(SettlementSale.Stage.Closed));
    }

    function testOpenCancellation_WhenNotClosed_Reverts() public {
        // Try to open cancellation while in PreOpen
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.PreOpen));
        vm.prank(manager);
        sale.openCancellation();

        // Try to open cancellation while in Auction
        openAuction();
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.Auction));
        vm.prank(manager);
        sale.openCancellation();
    }

    function testOpenSettlement_WhenNotClosedOrCancellation_Reverts() public {
        // Try while in PreOpen
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.PreOpen));
        vm.prank(manager);
        sale.openSettlement();

        // Try while in Auction
        openAuction();
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.InvalidStage.selector, SettlementSale.Stage.Auction));
        vm.prank(manager);
        sale.openSettlement();
    }
}

contract SettlementSaleRecoverTokensTest is SettlementSaleBaseTest {
    function testRecoverTokens_AsRecoverer_TransfersTokensToReceiver() public {
        deal(address(usdc), address(sale), 1000000);

        vm.startPrank(admin);
        sale.grantRole(sale.TOKEN_RECOVERER_ROLE(), recoverer);
        vm.stopPrank();

        vm.startPrank(recoverer);
        sale.recoverTokens(usdc, 1000000, receiver);
        vm.stopPrank();

        assertEq(usdc.balanceOf(receiver), 1000000);
    }
}

contract CommitmentDataReaderTest is SettlementSaleBaseTest {
    function testNumCommitments_Empty_ReturnsZero() public {
        assertEq(sale.numCommitments(), 0, "numCommitments should be 0 for empty auction");
    }

    function testNumCommitments_SingleBid_ReturnsOne() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        assertEq(sale.numCommitments(), 1, "numCommitments should be 1 after single bid");
    }

    function testNumCommitments_MultipleBidsFromSameEntity_ReturnsOne() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(alice, usdc, 2000e6, 20);
        doBid(alice, usdc, 3000e6, 30);
        assertEq(sale.numCommitments(), 1, "numCommitments should be 1 when same entity places multiple bids");
    }

    function testNumCommitments_MultipleEntities_ReturnsCorrectCount() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);
        doBid(charlie, usdt, 3000e6, 30);
        assertEq(sale.numCommitments(), 3, "numCommitments should be 3 for three entities");
    }

    function testReadCommitmentDataAt_SingleBid_ReturnsCorrectData() public {
        openAuction();
        vm.warp(1000);
        doBid(alice, usdc, 1000e6, 10);

        ICommitmentDataReader.CommitmentData memory commitmentData = sale.readCommitmentDataAt(0);

        assertEq(commitmentData.commitmentID, bytes32(aliceID), "commitmentID should be derived from entity ID");
        assertEq(commitmentData.saleSpecificEntityID, aliceID, "saleSpecificEntityID should be aliceID");
        assertEq(commitmentData.timestamp, uint64(1000), "timestamp should match block timestamp");
        assertEq(commitmentData.price, 10, "price should be 10");
        assertEq(sum(commitmentData.amounts), 1000e6, "amount should be 1000e6");
        assertEq(commitmentData.refunded, false, "refunded should be false");
        assertEq(commitmentData.lockup, false, "lockup should be false");
        assertEq(commitmentData.extraData, hex"", "extraData should be empty");
    }

    function testReadCommitmentDataAt_SingleBidWithLockup_ReturnsCorrectData() public {
        openAuction();
        vm.warp(1000);
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc, lockup: true});

        ICommitmentDataReader.CommitmentData memory commitmentData = sale.readCommitmentDataAt(0);

        assertEq(commitmentData.commitmentID, bytes32(aliceID), "commitmentID should be derived from entity ID");
        assertEq(commitmentData.saleSpecificEntityID, aliceID, "saleSpecificEntityID should be aliceID");
        assertEq(commitmentData.timestamp, uint64(1000), "timestamp should match block timestamp");
        assertEq(commitmentData.price, 10, "price should be 10");
        assertEq(sum(commitmentData.amounts), 1000e6, "amount should be 1000e6");
        assertEq(commitmentData.refunded, false, "refunded should be false");
        assertEq(commitmentData.lockup, true, "lockup should be true");
        assertEq(commitmentData.extraData, hex"", "extraData should be empty");
    }

    function testReadCommitmentDataAt_MultipleEntities_ReturnsCorrectData() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, usdc, 1000e6, 10);

        vm.warp(2000);
        doBid(bob, usdt, 2000e6, 20);

        vm.warp(3000);
        doBid(charlie, usdt, 3000e6, 30);

        ICommitmentDataReader.CommitmentData memory aliceCommitment = sale.readCommitmentDataAt(0);
        assertEq(aliceCommitment.saleSpecificEntityID, aliceID, "first should be alice");
        assertEq(aliceCommitment.price, 10, "alice price should be 10");
        assertEq(sum(aliceCommitment.amounts), 1000e6, "alice amount should be 1000e6");
        assertEq(aliceCommitment.timestamp, uint64(1000), "alice timestamp should be 1000");

        ICommitmentDataReader.CommitmentData memory bobCommitment = sale.readCommitmentDataAt(1);
        assertEq(bobCommitment.saleSpecificEntityID, bobID, "second should be bob");
        assertEq(bobCommitment.price, 20, "bob price should be 20");
        assertEq(sum(bobCommitment.amounts), 2000e6, "bob amount should be 2000e6");
        assertEq(bobCommitment.timestamp, uint64(2000), "bob timestamp should be 2000");

        ICommitmentDataReader.CommitmentData memory charlieCommitment = sale.readCommitmentDataAt(2);
        assertEq(charlieCommitment.saleSpecificEntityID, charlieID, "third should be charlie");
        assertEq(charlieCommitment.price, 30, "charlie price should be 30");
        assertEq(sum(charlieCommitment.amounts), 3000e6, "charlie amount should be 3000e6");
        assertEq(charlieCommitment.timestamp, uint64(3000), "charlie timestamp should be 3000");
    }

    function testReadCommitmentDataAt_AfterBidUpdate_ReflectsLatest() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, usdc, 1000e6, 10);

        vm.warp(2000);
        doBid(alice, usdc, 2000e6, 20);

        ICommitmentDataReader.CommitmentData memory commitmentData = sale.readCommitmentDataAt(0);
        assertEq(commitmentData.price, 20, "price should reflect latest bid");
        assertEq(sum(commitmentData.amounts), 2000e6, "amount should reflect latest bid");
        assertEq(commitmentData.timestamp, uint64(2000), "timestamp should reflect latest bid");
    }

    function testReadCommitmentDataIn_EmptyRange_ReturnsEmptyArray() public {
        ICommitmentDataReader.CommitmentData[] memory commitmentData = sale.readCommitmentDataIn(0, 0);
        assertEq(commitmentData.length, 0, "readCommitmentDataIn should return empty array for empty range");
    }

    function testReadCommitmentDataIn_SingleBid_ReturnsCorrectData() public {
        openAuction();
        vm.warp(1000);
        doBid(alice, usdc, 1000e6, 10);

        ICommitmentDataReader.CommitmentData[] memory commitmentData = sale.readCommitmentDataIn(0, 1);
        assertEq(commitmentData.length, 1, "readCommitmentDataIn should return 1 bid");
        assertEq(commitmentData[0].saleSpecificEntityID, aliceID, "entity should be alice");
        assertEq(commitmentData[0].price, 10, "price should be 10");
        assertEq(sum(commitmentData[0].amounts), 1000e6, "amount should be 1000e6");
    }

    function testReadCommitmentDataIn_MultipleBids_ReturnsCorrectData() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, usdc, 1000e6, 10);
        vm.warp(2000);
        doBid(bob, usdt, 2000e6, 20);
        vm.warp(3000);
        doBid(charlie, usdt, 3000e6, 30);

        ICommitmentDataReader.CommitmentData[] memory commitmentData = sale.readCommitmentDataIn(0, 3);
        assertEq(commitmentData.length, 3, "readCommitmentDataIn should return 3 bids");

        assertEq(commitmentData[0].saleSpecificEntityID, aliceID, "first bid should be alice");
        assertEq(commitmentData[1].saleSpecificEntityID, bobID, "second bid should be bob");
        assertEq(commitmentData[2].saleSpecificEntityID, charlieID, "third bid should be charlie");
    }

    function testReadCommitmentDataIn_Pagination_ReturnsCorrectPages() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, usdc, 1000e6, 10);
        vm.warp(2000);
        doBid(bob, usdt, 2000e6, 20);
        vm.warp(3000);
        doBid(charlie, usdt, 3000e6, 30);

        // Read first 2 bids
        ICommitmentDataReader.CommitmentData[] memory page1 = sale.readCommitmentDataIn(0, 2);
        assertEq(page1.length, 2, "first page should have 2 bids");
        assertEq(page1[0].saleSpecificEntityID, aliceID, "first page should start with alice");
        assertEq(page1[1].saleSpecificEntityID, bobID, "first page should end with bob");

        // Read last bid
        ICommitmentDataReader.CommitmentData[] memory page2 = sale.readCommitmentDataIn(2, 3);
        assertEq(page2.length, 1, "second page should have 1 bid");
        assertEq(page2[0].saleSpecificEntityID, charlieID, "second page should be charlie");
    }

    function testReadCommitmentDataIn_PartialRange_ReturnsCorrectSubset() public {
        openAuction();

        vm.warp(1000);
        doBid(alice, usdc, 1000e6, 10);
        vm.warp(2000);
        doBid(bob, usdt, 2000e6, 20);
        vm.warp(3000);
        doBid(charlie, usdt, 3000e6, 30);

        ICommitmentDataReader.CommitmentData[] memory commitmentData = sale.readCommitmentDataIn(1, 2);
        assertEq(commitmentData.length, 1, "should return 1 bid");
        assertEq(commitmentData[0].saleSpecificEntityID, bobID, "should be bob's bid");
    }

    function testReadCommitmentDataIn_AfterRefund_ReflectsRefundStatus() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);

        closeAuction();
        openSettlement();

        doSetAllocation(alice, usdc, 500e6);
        doSetAllocation(bob, usdt, 1000e6);

        finalizeSettlement();

        // Refund alice
        vm.prank(refunder);
        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = aliceID;
        sale.processRefunds(entityIDs, false);

        ICommitmentDataReader.CommitmentData[] memory commitmentData = sale.readCommitmentDataIn(0, 2);

        assertEq(commitmentData[0].saleSpecificEntityID, aliceID, "first should be alice");
        assertEq(commitmentData[0].refunded, true, "alice should be refunded");
        assertEq(commitmentData[1].saleSpecificEntityID, bobID, "second should be bob");
        assertEq(commitmentData[1].refunded, false, "bob should not be refunded yet");
    }

    function testCommitmentID_MultipleEntities_IsUnique() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);
        doBid(charlie, usdt, 3000e6, 30);

        ICommitmentDataReader.CommitmentData[] memory commitmentData = sale.readCommitmentDataIn(0, 3);

        // commitmentIDs should be unique
        assertTrue(
            commitmentData[0].commitmentID != commitmentData[1].commitmentID,
            "alice and bob commitmentIDs should differ"
        );
        assertTrue(
            commitmentData[0].commitmentID != commitmentData[2].commitmentID,
            "alice and charlie commitmentIDs should differ"
        );
        assertTrue(
            commitmentData[1].commitmentID != commitmentData[2].commitmentID,
            "bob and charlie commitmentIDs should differ"
        );

        // commitmentIDs should be derived from entity IDs
        assertEq(commitmentData[0].commitmentID, bytes32(aliceID), "alice commitmentID should match entity ID");
        assertEq(commitmentData[1].commitmentID, bytes32(bobID), "bob commitmentID should match entity ID");
        assertEq(commitmentData[2].commitmentID, bytes32(charlieID), "charlie commitmentID should match entity ID");
    }

    function testCommitmentID_AfterBidUpdate_RemainsConstant() public {
        openAuction();
        vm.warp(1000);
        doBid(alice, usdc, 1000e6, 10);

        ICommitmentDataReader.CommitmentData memory commitmentData1 = sale.readCommitmentDataAt(0);
        bytes32 originalCommitmentID = commitmentData1.commitmentID;

        vm.warp(2000);
        doBid(alice, usdc, 2000e6, 20);

        ICommitmentDataReader.CommitmentData memory commitmentData2 = sale.readCommitmentDataAt(0);
        assertEq(
            commitmentData2.commitmentID,
            originalCommitmentID,
            "commitmentID should remain constant when entity updates bid"
        );
        assertEq(commitmentData2.price, 20, "price should be updated");
        assertEq(sum(commitmentData2.amounts), 2000e6, "amount should be updated");
    }

    function testReadCommitmentDataIn_ConsistentWithNumCommitments_ReturnsAll() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);
        doBid(charlie, usdt, 3000e6, 30);

        uint256 numCommitments = sale.numCommitments();
        ICommitmentDataReader.CommitmentData[] memory commitmentData = sale.readCommitmentDataIn(0, numCommitments);

        assertEq(commitmentData.length, numCommitments, "readCommitmentDataIn should return numCommitments commitments");
    }
}

contract SettlementSaleViewFunctionsTest is SettlementSaleBaseTest {
    function testPaymentTokens_AfterDeploy_ReturnsCorrectTokens() public view {
        IERC20[] memory tokens = sale.paymentTokens();

        assertEq(tokens.length, 2);
        assertEq(address(tokens[0]), address(usdc));
        assertEq(address(tokens[1]), address(usdt));
    }

    function testEntityAt_OutOfBounds_Reverts() public {
        assertEq(sale.numEntities(), 0);

        vm.expectRevert();
        sale.entityAt(0);
    }

    function testEntityAt_OutOfBoundsAfterBids_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        assertEq(sale.numEntities(), 1);
        assertEq(sale.entityAt(0), aliceID);

        vm.expectRevert();
        sale.entityAt(1);
    }

    function testReadCommitmentDataAt_OutOfBounds_Reverts() public {
        assertEq(sale.numCommitments(), 0);

        vm.expectRevert();
        sale.readCommitmentDataAt(0);
    }

    function testReadCommitmentDataAt_OutOfBoundsAfterBids_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 2000e6, price: 15, token: usdt});

        assertEq(sale.numCommitments(), 2);

        // Valid indices
        sale.readCommitmentDataAt(0);
        sale.readCommitmentDataAt(1);

        // Out of bounds
        vm.expectRevert();
        sale.readCommitmentDataAt(2);
    }

    function testEntitiesIn_OutOfBounds_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        bytes16[] memory result = sale.entitiesIn(0, 1);
        assertEq(result.length, 1);

        vm.expectRevert();
        sale.entitiesIn(0, 2);
    }

    function testEntityStatesIn_OutOfBounds_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        SettlementSale.EntityStateView[] memory result = sale.entityStatesIn(0, 1);
        assertEq(result.length, 1);

        vm.expectRevert();
        sale.entityStatesIn(0, 2);
    }

    function testReadCommitmentDataIn_OutOfBounds_Reverts() public {
        openAuction();
        doBid({user: alice, amount: 1000e6, price: 10, token: usdc});

        ICommitmentDataReader.CommitmentData[] memory result = sale.readCommitmentDataIn(0, 1);
        assertEq(result.length, 1);

        vm.expectRevert();
        sale.readCommitmentDataIn(0, 2);
    }

    function testTotalCommittedAmountByToken_AfterBids_ReturnsCorrectAmounts() public {
        openAuction();

        // Test with no commitments
        TokenAmount[] memory amounts = sale.totalCommittedAmountByToken();
        assertEq(amounts[0].amount, 0);
        assertEq(amounts[1].amount, 0);

        // Add some bids
        doBid({user: alice, amount: 2000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 3000e6, price: 10, token: usdt});

        amounts = sale.totalCommittedAmountByToken();
        assertEq(amounts[0].amount, 2000e6, "USDC committed amount");
        assertEq(amounts[1].amount, 3000e6, "USDT committed amount");
    }

    function testTotalRefundedAmountByToken_AfterRefunds_ReturnsCorrectAmounts() public {
        openAuction();
        doBid({user: alice, amount: 5000e6, price: 10, token: usdc});
        doBid({user: bob, amount: 3000e6, price: 10, token: usdt});

        closeAuction();
        openSettlement();
        doSetAllocation(alice, usdc, 2000e6);
        doSetAllocation(bob, usdt, 1000e6);
        finalizeSettlement();

        // Test before refunds
        TokenAmount[] memory amounts = sale.totalRefundedAmountByToken();
        assertEq(amounts[0].amount, 0);
        assertEq(amounts[1].amount, 0);

        // Process refunds
        bytes16[] memory entityIDs = new bytes16[](2);
        entityIDs[0] = aliceID;
        entityIDs[1] = bobID;
        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        // Test after refunds
        amounts = sale.totalRefundedAmountByToken();
        assertEq(amounts[0].amount, 3000e6, "USDC refunded amount");
        assertEq(amounts[1].amount, 2000e6, "USDT refunded amount");
    }

    function testEntityState_AfterMultipleBids_ReturnsCorrectData() public {
        openAuction();

        doBid({user: alice, price: 10, amount: 2000e6, token: usdc});
        doBid({user: bob, price: 15, amount: SALE_MAX_AMOUNT, token: usdc});
        doBid({user: alice, price: 11, amount: 3000e6, token: usdt});
        doBid({user: charlie, price: 12, amount: 4000e6, token: usdt});

        assertEq(sale.numEntities(), 3);
        assertEq(sale.entityAt(0), aliceID);
        assertEq(sale.entityAt(1), bobID);
        assertEq(sale.entityAt(2), charlieID);

        // Check entity states
        SettlementSale.EntityStateView memory aliceState = sale.entityStateByID(aliceID);
        assertEq(aliceState.entityID, aliceID);
        assertEq(aliceState.currentBid.price, 11);
        assertEq(aliceState.currentBid.amount, 3000e6);
        assertEq(
            aliceState.walletStates[0].committedAmountByToken, toTokenAmounts({usdcAmount: 2000e6, usdtAmount: 1000e6})
        );

        SettlementSale.EntityStateView memory bobState = sale.entityStateByID(bobID);
        assertEq(bobState.entityID, bobID);
        assertEq(bobState.currentBid.price, 15);
        assertEq(bobState.currentBid.amount, SALE_MAX_AMOUNT);
        assertEq(
            bobState.walletStates[0].committedAmountByToken,
            toTokenAmounts({usdcAmount: SALE_MAX_AMOUNT, usdtAmount: 0})
        );

        SettlementSale.EntityStateView memory charlieState = sale.entityStateByID(charlieID);
        assertEq(charlieState.entityID, charlieID);
        assertEq(charlieState.currentBid.price, 12);
        assertEq(charlieState.currentBid.amount, 4000e6);
        assertEq(
            charlieState.walletStates[0].committedAmountByToken, toTokenAmounts({usdcAmount: 0, usdtAmount: 4000e6})
        );
    }

    function testEntityState_MultipleWalletsPerEntity_ReturnsAllWalletStates() public {
        openAuction();

        // Use alice's entityID with two different wallets
        address wallet1 = makeAddr("wallet1");
        address wallet2 = makeAddr("wallet2");

        // First wallet bids 2000 USDC at price 10
        doBid({entityID: aliceID, user: wallet1, token: usdc, amount: 2000e6, price: 10});

        // Second wallet increases the bid to 5000 total (3000 more) using USDT at price 12
        doBid({entityID: aliceID, user: wallet2, token: usdt, amount: 5000e6, price: 12});

        // Test settlement with multiple wallets
        closeAuction();
        openSettlement();

        // Allocate 1500 USDC from wallet1 and 2000 USDT from wallet2
        doSetAllocation({entityID: aliceID, wallet: wallet1, token: usdc, amount: 1500e6});
        doSetAllocation({entityID: aliceID, wallet: wallet2, token: usdt, amount: 2000e6});

        // Verify entity count - should be 1 entity with 2 wallets
        assertEq(sale.numEntities(), 1);

        // Get entity state
        SettlementSale.EntityStateView memory entityState = sale.entityStateByID(aliceID);
        assertEq(entityState.entityID, aliceID);
        assertEq(entityState.currentBid.price, 12, "bid price should be updated to latest");
        assertEq(entityState.currentBid.amount, 5000e6, "bid amount should be total across wallets");

        // Verify we have 2 wallet states
        assertEq(entityState.walletStates.length, 2, "should have 2 wallet states");

        // Check wallet1 state (first wallet added)
        SettlementSale.WalletStateView memory wallet1State = entityState.walletStates[0];
        assertEq(wallet1State.addr, wallet1);
        assertEq(wallet1State.entityID, aliceID);
        assertEq(wallet1State.committedAmountByToken, toTokenAmounts({usdcAmount: 2000e6, usdtAmount: 0}));
        assertEq(wallet1State.acceptedAmountByToken, toTokenAmounts({usdcAmount: 1500e6, usdtAmount: 0}));

        // Check wallet2 state (second wallet added)
        SettlementSale.WalletStateView memory wallet2State = entityState.walletStates[1];
        assertEq(wallet2State.addr, wallet2);
        assertEq(wallet2State.entityID, aliceID);
        assertEq(wallet2State.committedAmountByToken, toTokenAmounts({usdcAmount: 0, usdtAmount: 3000e6}));
        assertEq(wallet2State.acceptedAmountByToken, toTokenAmounts({usdcAmount: 0, usdtAmount: 2000e6}));
    }
}

contract SettlementSaleSingleTokenTest is BaseTest {
    TestableSettlementSale sale;
    ERC20FakeWithDecimals usdc;

    Account permitSigner = makeAccount("permitSigner");
    address internal immutable pauser = makeAddr("pauser");
    address internal immutable receiver = makeAddr("receiver");
    address internal immutable settler = makeAddr("settler");
    address internal immutable refunder = makeAddr("refunder");

    bytes16 internal immutable aliceID = bytes16(keccak256(abi.encode(alice)));

    function setUp() public {
        usdc = new ERC20FakeWithDecimals("USDC", "USDC", 6);
        vm.label(address(usdc), "FAKE-usdc");

        IERC20Metadata[] memory paymentTokens = new IERC20Metadata[](1);
        paymentTokens[0] = usdc;

        address[] memory extraManagers = new address[](1);
        extraManagers[0] = manager;

        address[] memory extraPausers = new address[](1);
        extraPausers[0] = pauser;

        SettlementSale.Init memory init = SettlementSale.Init({
            saleUUID: TEST_SALE_UUID,
            admin: admin,
            extraManagers: extraManagers,
            purchasePermitSigner: permitSigner.addr,
            proceedsReceiver: receiver,
            extraPausers: extraPausers,
            extraSettler: settler,
            extraRefunder: refunder,
            closeAuctionAtTimestamp: uint64(block.timestamp + 24 hours),
            claimRefundEnabled: true,
            paymentTokens: paymentTokens,
            expectedPaymentTokenDecimals: 6
        });
        sale = new TestableSettlementSale(init);
    }

    function testPaymentTokens_SingleToken_ReturnsCorrectToken() public view {
        IERC20[] memory tokens = sale.paymentTokens();
        assertEq(tokens.length, 1);
        assertEq(address(tokens[0]), address(usdc));
    }

    function testBidAndSettlement_SingleToken_CompletesSuccessfully() public {
        vm.prank(manager);
        sale.openAuction();

        PurchasePermitV2 memory permit = PurchasePermitV2({
            saleSpecificEntityID: aliceID,
            saleUUID: TEST_SALE_UUID,
            wallet: alice,
            expiresAt: uint64(block.timestamp + 1000),
            minAmount: 1000e6,
            maxAmount: 15000e6,
            minPrice: 5,
            maxPrice: 100,
            payload: abi.encode(SettlementSale.PurchasePermitPayload({forcedLockup: false}))
        });
        bytes32 digest = PurchasePermitV2Lib.digest(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permitSigner.key, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        deal(address(usdc), alice, 2000e6);
        vm.prank(alice);
        usdc.approve(address(sale), 2000e6);

        SettlementSale.Bid memory bid = SettlementSale.Bid({lockup: false, price: 10, amount: 2000e6});

        vm.prank(alice);
        sale.replaceBidWithApproval(usdc, bid, permit, sig);

        TokenAmount[] memory committed = sale.totalCommittedAmountByToken();
        assertEq(committed.length, 1);
        assertEq(committed[0].amount, 2000e6);
        assertEq(sale.totalCommittedAmount(), 2000e6);

        vm.prank(manager);
        sale.closeAuction();

        vm.prank(manager);
        sale.openSettlement();

        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: aliceID,
            wallet: alice,
            token: address(usdc),
            acceptedAmount: 1500e6
        });

        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: false});

        vm.prank(admin);
        sale.finalizeSettlement(1500e6);

        bytes16[] memory entityIDs = new bytes16[](1);
        entityIDs[0] = aliceID;

        vm.prank(refunder);
        sale.processRefunds(entityIDs, false);

        assertEq(usdc.balanceOf(alice), 500e6, "alice should get 500 USDC refund");

        vm.prank(admin);
        sale.withdraw();

        assertEq(usdc.balanceOf(receiver), 1500e6, "receiver should get 1500 USDC");
    }

    function testTotalAmountFunctions_SingleToken_ReturnCorrectValues() public {
        vm.prank(manager);
        sale.openAuction();

        assertEq(sale.totalCommittedAmount(), 0);
        assertEq(sale.totalAcceptedAmount(), 0);
        assertEq(sale.totalRefundedAmount(), 0);

        TokenAmount[] memory committed = sale.totalCommittedAmountByToken();
        assertEq(committed.length, 1);
        assertEq(committed[0].amount, 0);

        TokenAmount[] memory accepted = sale.totalAcceptedAmountByToken();
        assertEq(accepted.length, 1);
        assertEq(accepted[0].amount, 0);

        TokenAmount[] memory refunded = sale.totalRefundedAmountByToken();
        assertEq(refunded.length, 1);
        assertEq(refunded[0].amount, 0);
    }
}

contract SettlementSaleViewFunctionsCoverageTest is SettlementSaleBaseTest {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    function testWalletStateByAddress_Uninitialized_Reverts() public {
        // Try to get wallet state for address that never placed a bid
        vm.expectRevert(abi.encodeWithSelector(SettlementSale.WalletNotInitialized.selector, alice));
        sale.walletStateByAddress(alice);
    }

    function testWalletStatesByAddresses_MultipleWallets_ReturnsCorrectData() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);

        address[] memory addrs = new address[](2);
        addrs[0] = alice;
        addrs[1] = bob;

        SettlementSale.WalletStateView[] memory states = sale.walletStatesByAddresses(addrs);

        assertEq(states.length, 2, "should return 2 states");

        assertEq(states[0].addr, alice, "first state should be alice");
        assertEq(states[0].entityID, aliceID, "alice entityID should match");
        assertEq(states[0].committedAmountByToken.length, 2, "alice should have 2 token amounts");

        assertEq(states[1].addr, bob, "second state should be bob");
        assertEq(states[1].entityID, bobID, "bob entityID should match");
        assertEq(states[1].committedAmountByToken.length, 2, "bob should have 2 token amounts");
    }

    function testWalletStatesByAddresses_AnyUninitialized_Reverts() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        // bob never placed a bid

        address[] memory addrs = new address[](2);
        addrs[0] = alice;
        addrs[1] = bob;

        vm.expectRevert(abi.encodeWithSelector(SettlementSale.WalletNotInitialized.selector, bob));
        sale.walletStatesByAddresses(addrs);
    }

    function testEntityStatesByIDs_MultipleEntities_ReturnsCorrectData() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);

        bytes16[] memory entityIDs = new bytes16[](2);
        entityIDs[0] = aliceID;
        entityIDs[1] = bobID;

        SettlementSale.EntityStateView[] memory states = sale.entityStatesByIDs(entityIDs);

        assertEq(states.length, 2, "should return 2 states");

        assertEq(states[0].entityID, aliceID, "first state entityID should be alice");
        assertEq(states[0].currentBid.amount, 1000e6, "alice bid amount should be 1000e6");
        assertEq(states[0].currentBid.price, 10, "alice bid price should be 10");
        assertFalse(states[0].cancelled, "alice should not be cancelled");
        assertFalse(states[0].refunded, "alice should not be refunded");

        assertEq(states[1].entityID, bobID, "second state entityID should be bob");
        assertEq(states[1].currentBid.amount, 2000e6, "bob bid amount should be 2000e6");
        assertEq(states[1].currentBid.price, 20, "bob bid price should be 20");
    }

    function testEntityStatesByIDs_EmptyArray_ReturnsEmpty() public {
        bytes16[] memory entityIDs = new bytes16[](0);
        SettlementSale.EntityStateView[] memory states = sale.entityStatesByIDs(entityIDs);
        assertEq(states.length, 0, "should return empty array");
    }

    function testSupportsInterface_ValidInterfaces_ReturnsTrue() public view {
        // Test ICommitmentDataReader interface
        assertTrue(
            sale.supportsInterface(type(ICommitmentDataReader).interfaceId), "should support ICommitmentDataReader"
        );

        // Test ITotalCommitmentsReader interface
        assertTrue(
            sale.supportsInterface(type(ITotalCommitmentsReader).interfaceId), "should support ITotalCommitmentsReader"
        );

        // Test IOffchainSettlement interface
        assertTrue(sale.supportsInterface(type(IOffchainSettlement).interfaceId), "should support IOffchainSettlement");

        // Test AccessControl interface (from parent)
        assertTrue(
            sale.supportsInterface(type(IAccessControl).interfaceId), "should support IAccessControl from parent"
        );

        // Test invalid interface returns false
        bytes4 invalidInterfaceId = 0xdeadbeef;
        assertFalse(sale.supportsInterface(invalidInterfaceId), "should not support invalid interface");
    }
}

contract EntityAllocationDataReaderTest is SettlementSaleBaseTest {
    function testNumEntityAllocations_Empty_ReturnsZero() public view {
        assertEq(sale.numEntityAllocations(), 0, "numEntityAllocations should be 0 for empty auction");
    }

    function testNumEntityAllocations_AfterBids_ReturnsEntityCount() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);
        doBid(charlie, usdt, 3000e6, 30);
        assertEq(sale.numEntityAllocations(), 3, "numEntityAllocations should be 3 for three entities");
    }

    function testNumEntityAllocations_MultipleBidsFromSameEntity_ReturnsOne() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(alice, usdc, 2000e6, 20);
        doBid(alice, usdc, 3000e6, 30);
        assertEq(
            sale.numEntityAllocations(), 1, "numEntityAllocations should be 1 when same entity places multiple bids"
        );
    }

    function testReadEntityAllocationDataAt_BeforeSettlement_ReturnsZeroAmounts() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);

        IEntityAllocationDataReader.EntityAllocationData[] memory got = sale.readEntityAllocationDataIn(0, 1);

        IEntityAllocationDataReader.EntityAllocationData[] memory want =
            new IEntityAllocationDataReader.EntityAllocationData[](1);
        want[0].saleSpecificEntityID = aliceID;
        want[0].acceptedAmounts = new WalletTokenAmount[](2);
        want[0].acceptedAmounts[0] = WalletTokenAmount({wallet: alice, token: address(usdc), amount: 0});
        want[0].acceptedAmounts[1] = WalletTokenAmount({wallet: alice, token: address(usdt), amount: 0});

        assertEq(got, want);
    }

    function testReadEntityAllocationDataAt_AfterSettlement_ReturnsCorrectAmounts() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);

        closeAuction();
        openSettlement();
        doSetAllocation(alice, usdc, 500e6);

        IEntityAllocationDataReader.EntityAllocationData[] memory got = sale.readEntityAllocationDataIn(0, 1);

        IEntityAllocationDataReader.EntityAllocationData[] memory want =
            new IEntityAllocationDataReader.EntityAllocationData[](1);
        want[0].saleSpecificEntityID = aliceID;
        want[0].acceptedAmounts = new WalletTokenAmount[](2);
        want[0].acceptedAmounts[0] = WalletTokenAmount({wallet: alice, token: address(usdc), amount: 500e6});
        want[0].acceptedAmounts[1] = WalletTokenAmount({wallet: alice, token: address(usdt), amount: 0});

        assertEq(got, want);
    }

    function testReadEntityAllocationDataIn_MultipleEntities_ReturnsCorrectData() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);
        doBid(charlie, usdc, 3000e6, 30);

        closeAuction();
        openSettlement();
        doSetAllocation(alice, usdc, 500e6);
        doSetAllocation(bob, usdt, 1000e6);
        doSetAllocation(charlie, usdc, 1500e6);

        IEntityAllocationDataReader.EntityAllocationData[] memory got = sale.readEntityAllocationDataIn(0, 3);

        IEntityAllocationDataReader.EntityAllocationData[] memory want =
            new IEntityAllocationDataReader.EntityAllocationData[](3);

        // Alice
        want[0].saleSpecificEntityID = aliceID;
        want[0].acceptedAmounts = new WalletTokenAmount[](2);
        want[0].acceptedAmounts[0] = WalletTokenAmount({wallet: alice, token: address(usdc), amount: 500e6});
        want[0].acceptedAmounts[1] = WalletTokenAmount({wallet: alice, token: address(usdt), amount: 0});

        // Bob
        want[1].saleSpecificEntityID = bobID;
        want[1].acceptedAmounts = new WalletTokenAmount[](2);
        want[1].acceptedAmounts[0] = WalletTokenAmount({wallet: bob, token: address(usdc), amount: 0});
        want[1].acceptedAmounts[1] = WalletTokenAmount({wallet: bob, token: address(usdt), amount: 1000e6});

        // Charlie
        want[2].saleSpecificEntityID = charlieID;
        want[2].acceptedAmounts = new WalletTokenAmount[](2);
        want[2].acceptedAmounts[0] = WalletTokenAmount({wallet: charlie, token: address(usdc), amount: 1500e6});
        want[2].acceptedAmounts[1] = WalletTokenAmount({wallet: charlie, token: address(usdt), amount: 0});

        assertEq(got, want);
    }

    function testReadEntityAllocationDataAt_MultipleTokens_ReturnsAllTokenAmounts() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(alice, usdt, 2000e6, 10); // Same entity, different token

        closeAuction();
        openSettlement();
        doSetAllocation(alice, usdc, 500e6);
        doSetAllocation(alice, usdt, 800e6);

        IEntityAllocationDataReader.EntityAllocationData[] memory got = sale.readEntityAllocationDataIn(0, 1);

        IEntityAllocationDataReader.EntityAllocationData[] memory want =
            new IEntityAllocationDataReader.EntityAllocationData[](1);
        want[0].saleSpecificEntityID = aliceID;
        want[0].acceptedAmounts = new WalletTokenAmount[](2);
        want[0].acceptedAmounts[0] = WalletTokenAmount({wallet: alice, token: address(usdc), amount: 500e6});
        want[0].acceptedAmounts[1] = WalletTokenAmount({wallet: alice, token: address(usdt), amount: 800e6});

        assertEq(got, want);
    }

    function testReadEntityAllocationDataAt_OutOfBounds_Reverts() public {
        vm.expectRevert();
        sale.readEntityAllocationDataAt(0);
    }

    function testReadEntityAllocationDataAt_OutOfBoundsAfterBids_Reverts() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);

        vm.expectRevert();
        sale.readEntityAllocationDataAt(1);
    }

    function testReadEntityAllocationDataIn_EmptyRange_ReturnsEmptyArray() public view {
        IEntityAllocationDataReader.EntityAllocationData[] memory got = sale.readEntityAllocationDataIn(0, 0);
        IEntityAllocationDataReader.EntityAllocationData[] memory want =
            new IEntityAllocationDataReader.EntityAllocationData[](0);
        assertEq(got, want);
    }

    function testReadEntityAllocationDataIn_Pagination_ReturnsCorrectPages() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);
        doBid(charlie, usdc, 3000e6, 30);

        closeAuction();
        openSettlement();
        doSetAllocation(alice, usdc, 500e6);
        doSetAllocation(bob, usdt, 1000e6);
        doSetAllocation(charlie, usdc, 1500e6);

        // Read first 2 entities
        IEntityAllocationDataReader.EntityAllocationData[] memory page1Got = sale.readEntityAllocationDataIn(0, 2);

        IEntityAllocationDataReader.EntityAllocationData[] memory page1Want =
            new IEntityAllocationDataReader.EntityAllocationData[](2);
        page1Want[0].saleSpecificEntityID = aliceID;
        page1Want[0].acceptedAmounts = new WalletTokenAmount[](2);
        page1Want[0].acceptedAmounts[0] = WalletTokenAmount({wallet: alice, token: address(usdc), amount: 500e6});
        page1Want[0].acceptedAmounts[1] = WalletTokenAmount({wallet: alice, token: address(usdt), amount: 0});
        page1Want[1].saleSpecificEntityID = bobID;
        page1Want[1].acceptedAmounts = new WalletTokenAmount[](2);
        page1Want[1].acceptedAmounts[0] = WalletTokenAmount({wallet: bob, token: address(usdc), amount: 0});
        page1Want[1].acceptedAmounts[1] = WalletTokenAmount({wallet: bob, token: address(usdt), amount: 1000e6});

        assertEq(page1Got, page1Want, "page1");

        // Read last entity
        IEntityAllocationDataReader.EntityAllocationData[] memory page2Got = sale.readEntityAllocationDataIn(2, 3);

        IEntityAllocationDataReader.EntityAllocationData[] memory page2Want =
            new IEntityAllocationDataReader.EntityAllocationData[](1);
        page2Want[0].saleSpecificEntityID = charlieID;
        page2Want[0].acceptedAmounts = new WalletTokenAmount[](2);
        page2Want[0].acceptedAmounts[0] = WalletTokenAmount({wallet: charlie, token: address(usdc), amount: 1500e6});
        page2Want[0].acceptedAmounts[1] = WalletTokenAmount({wallet: charlie, token: address(usdt), amount: 0});

        assertEq(page2Got, page2Want, "page2");
    }

    function testReadEntityAllocationDataIn_PartialRange_ReturnsCorrectSubset() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);
        doBid(charlie, usdc, 3000e6, 30);

        closeAuction();
        openSettlement();
        doSetAllocation(alice, usdc, 500e6);
        doSetAllocation(bob, usdt, 1000e6);
        doSetAllocation(charlie, usdc, 1500e6);

        IEntityAllocationDataReader.EntityAllocationData[] memory got = sale.readEntityAllocationDataIn(1, 2);

        IEntityAllocationDataReader.EntityAllocationData[] memory want =
            new IEntityAllocationDataReader.EntityAllocationData[](1);
        want[0].saleSpecificEntityID = bobID;
        want[0].acceptedAmounts = new WalletTokenAmount[](2);
        want[0].acceptedAmounts[0] = WalletTokenAmount({wallet: bob, token: address(usdc), amount: 0});
        want[0].acceptedAmounts[1] = WalletTokenAmount({wallet: bob, token: address(usdt), amount: 1000e6});

        assertEq(got, want);
    }

    function testReadEntityAllocationDataIn_OutOfBounds_Reverts() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);

        vm.expectRevert();
        sale.readEntityAllocationDataIn(0, 2);
    }

    function testReadEntityAllocationDataIn_ConsistentWithNumEntityAllocations() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);
        doBid(bob, usdt, 2000e6, 20);
        doBid(charlie, usdc, 3000e6, 30);

        uint256 numAllocations = sale.numEntityAllocations();
        IEntityAllocationDataReader.EntityAllocationData[] memory data =
            sale.readEntityAllocationDataIn(0, numAllocations);

        assertEq(data.length, numAllocations, "readEntityAllocationDataIn should return numEntityAllocations entities");
    }

    function testReadEntityAllocationDataIn_AfterAllocationOverwrite_ReflectsLatest() public {
        openAuction();
        doBid(alice, usdc, 1000e6, 10);

        closeAuction();
        openSettlement();

        // Set initial allocation
        doSetAllocation(alice, usdc, 500e6);

        IEntityAllocationDataReader.EntityAllocationData[] memory got1 = sale.readEntityAllocationDataIn(0, 1);

        IEntityAllocationDataReader.EntityAllocationData[] memory want1 =
            new IEntityAllocationDataReader.EntityAllocationData[](1);
        want1[0].saleSpecificEntityID = aliceID;
        want1[0].acceptedAmounts = new WalletTokenAmount[](2);
        want1[0].acceptedAmounts[0] = WalletTokenAmount({wallet: alice, token: address(usdc), amount: 500e6});
        want1[0].acceptedAmounts[1] = WalletTokenAmount({wallet: alice, token: address(usdt), amount: 0});

        assertEq(got1, want1, "initial");

        // Overwrite allocation
        doSetAllocation(alice, usdc, 800e6, true);

        IEntityAllocationDataReader.EntityAllocationData[] memory got2 = sale.readEntityAllocationDataIn(0, 1);

        IEntityAllocationDataReader.EntityAllocationData[] memory want2 =
            new IEntityAllocationDataReader.EntityAllocationData[](1);
        want2[0].saleSpecificEntityID = aliceID;
        want2[0].acceptedAmounts = new WalletTokenAmount[](2);
        want2[0].acceptedAmounts[0] = WalletTokenAmount({wallet: alice, token: address(usdc), amount: 800e6});
        want2[0].acceptedAmounts[1] = WalletTokenAmount({wallet: alice, token: address(usdt), amount: 0});

        assertEq(got2, want2, "updated");
    }

    function testReadEntityAllocationDataAt_MultipleWallets_ReturnsAllWalletTokenPairs() public {
        // Create a scenario where one entity has multiple wallets
        address alice2 = makeAddr("alice2");
        bytes16 aliceEntityID = aliceID;

        openAuction();

        // Alice bids from first wallet
        doBid(alice, usdc, 1000e6, 10);

        // Alice bids from second wallet (same entity)
        doBid(aliceEntityID, alice2, usdt, 2000e6, 10);

        closeAuction();
        openSettlement();

        // Set allocations for both wallets
        doSetAllocation(aliceEntityID, alice, usdc, 500e6);
        doSetAllocation(aliceEntityID, alice2, usdt, 800e6);

        IEntityAllocationDataReader.EntityAllocationData[] memory got = sale.readEntityAllocationDataIn(0, 1);

        // 4 entries: 2 wallets * 2 tokens
        IEntityAllocationDataReader.EntityAllocationData[] memory want =
            new IEntityAllocationDataReader.EntityAllocationData[](1);
        want[0].saleSpecificEntityID = aliceEntityID;
        want[0].acceptedAmounts = new WalletTokenAmount[](4);
        want[0].acceptedAmounts[0] = WalletTokenAmount({wallet: alice, token: address(usdc), amount: 500e6});
        want[0].acceptedAmounts[1] = WalletTokenAmount({wallet: alice, token: address(usdt), amount: 0});
        want[0].acceptedAmounts[2] = WalletTokenAmount({wallet: alice2, token: address(usdc), amount: 0});
        want[0].acceptedAmounts[3] = WalletTokenAmount({wallet: alice2, token: address(usdt), amount: 800e6});

        assertEq(got, want);
    }
}
