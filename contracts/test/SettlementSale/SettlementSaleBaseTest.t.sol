// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ICommitmentDataReader} from "sales/interfaces/ICommitmentDataReader.sol";
import {IEntityAllocationDataReader} from "sales/interfaces/IEntityAllocationDataReader.sol";
import {IOffchainSettlement} from "sales/interfaces/IOffchainSettlement.sol";
import {TokenAmount, WalletTokenAmount} from "sales/interfaces/types.sol";

import {PurchasePermitV3, PurchasePermitV3Lib} from "sales/permits/PurchasePermitV3.sol";

import {BaseTest, console} from "../BaseTest.sol";
import {ERC20FakeWithDecimals, ERC20Permit} from "../doubles/ERC20Fake.sol";
import {Vm} from "forge-std/Vm.sol";

import {SettlementSale} from "sales/SettlementSale.sol";

bytes16 constant TEST_SALE_UUID = hex"1234567890abcdef1234567890abcdef";
bytes32 constant ERC20_PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

uint256 constant SALE_MIN_AMOUNT = 1000e6;
uint256 constant SALE_MAX_AMOUNT = 15000e6;

uint64 constant SALE_MIN_PRICE = 5;
uint64 constant SALE_MAX_PRICE = 100;

contract TestableSettlementSale is SettlementSale {
    using EnumerableSet for EnumerableSet.AddressSet;

    function allEntities() public view returns (bytes16[] memory) {
        uint256 num = this.numEntities();
        return this.entitiesIn(0, num);
    }

    function allEntityStates() public view returns (EntityStateView[] memory) {
        uint256 num = this.numEntities();
        return this.entityStatesIn(0, num);
    }

    function isEntityInitialized(bytes16 entityID) public view returns (bool) {
        return _entityStateByID[entityID].wallets.length() > 0;
    }

    function isWalletInitialized(address addr) public view returns (bool) {
        return _entityIDByAddress[addr] != bytes16(0);
    }

    // Helper to get entity ID from address for tests
    function getEntityID(address addr) public view returns (bytes16) {
        return _entityIDByAddress[addr];
    }
}

/// @dev Helper to create a TestableSettlementSale using the clone pattern.
/// This is needed because the base SettlementSale constructor disables initializers.
function newTestableSettlementSale(SettlementSale.Init memory init) returns (TestableSettlementSale) {
    TestableSettlementSale clone = newUninitializedTestableSettlementSale();
    clone.initialize(init);
    return clone;
}

/// @dev Helper to create an uninitialized TestableSettlementSale clone.
/// Use this for testing initialization failures.
function newUninitializedTestableSettlementSale() returns (TestableSettlementSale) {
    TestableSettlementSale impl = new TestableSettlementSale();
    return TestableSettlementSale(Clones.clone(address(impl)));
}

contract SettlementSaleBaseTest is BaseTest {
    TestableSettlementSale sale;
    ERC20FakeWithDecimals usdc;
    ERC20FakeWithDecimals usdt;
    IERC20Metadata[] paymentTokens;

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
        usdc = new ERC20FakeWithDecimals("USD", "USD", 6);
        vm.label(address(usdc), "FAKE-usdc");

        usdt = new ERC20FakeWithDecimals("USDT", "USDT", 6);
        vm.label(address(usdt), "FAKE-usdt");

        paymentTokens = new IERC20Metadata[](2);
        paymentTokens[0] = usdc;
        paymentTokens[1] = usdt;

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
            claimRefundEnabled: true,
            maxWalletsPerEntity: 50,
            paymentTokens: paymentTokens,
            expectedPaymentTokenDecimals: 6
        });
        sale = newTestableSettlementSale(init);

        vm.startPrank(admin);
        sale.grantRole(sale.TOKEN_RECOVERER_ROLE(), recoverer);
        vm.stopPrank();
    }

    function signPurchasePermit(PurchasePermitV3 memory permit, uint256 pk) internal pure returns (bytes memory) {
        bytes32 digest = PurchasePermitV3Lib.digest(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function signPurchasePermit(PurchasePermitV3 memory permit) internal view returns (bytes memory) {
        return signPurchasePermit(permit, permitSigner.key);
    }

    /// @notice Creates a purchase permit with all parameters including time window.
    function makePurchasePermit(
        bytes16 saleSpecificEntityID,
        bytes16 saleUUID,
        address wallet,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 minPrice,
        uint64 maxPrice,
        bool forcedLockup,
        uint64 expiresAt,
        uint64 opensAt,
        uint64 closesAt
    ) internal pure returns (PurchasePermitV3 memory) {
        return PurchasePermitV3({
            saleSpecificEntityID: saleSpecificEntityID,
            saleUUID: saleUUID,
            wallet: wallet,
            expiresAt: expiresAt,
            minAmount: minAmount,
            maxAmount: maxAmount,
            minPrice: minPrice,
            maxPrice: maxPrice,
            opensAt: opensAt,
            closesAt: closesAt,
            payload: abi.encode(SettlementSale.PurchasePermitPayload({forcedLockup: forcedLockup}))
        });
    }

    /// @notice Creates a purchase permit with specific time window.
    function makePurchasePermit(
        bytes16 saleSpecificEntityID,
        address wallet,
        uint64 opensAt,
        uint64 closesAt
    ) internal view returns (PurchasePermitV3 memory) {
        return makePurchasePermit({
            saleSpecificEntityID: saleSpecificEntityID,
            wallet: wallet,
            expiresAt: uint64(block.timestamp + 1000),
            opensAt: opensAt,
            closesAt: closesAt
        });
    }

    /// @notice Creates a purchase permit with specific time window and custom expiry.
    function makePurchasePermit(
        bytes16 saleSpecificEntityID,
        address wallet,
        uint64 expiresAt,
        uint64 opensAt,
        uint64 closesAt
    ) internal pure returns (PurchasePermitV3 memory) {
        return makePurchasePermit({
            saleSpecificEntityID: saleSpecificEntityID,
            saleUUID: TEST_SALE_UUID,
            wallet: wallet,
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: SALE_MIN_PRICE,
            maxPrice: SALE_MAX_PRICE,
            forcedLockup: false,
            expiresAt: expiresAt,
            opensAt: opensAt,
            closesAt: closesAt
        });
    }

    /// @notice Creates a purchase permit with always-valid time window (opensAt=0, closesAt=max).
    function makePurchasePermit(
        bytes16 saleSpecificEntityID,
        address wallet
    ) internal view returns (PurchasePermitV3 memory) {
        return makePurchasePermit({
            saleSpecificEntityID: saleSpecificEntityID, wallet: wallet, opensAt: 0, closesAt: type(uint64).max
        });
    }

    /// @notice Creates a purchase permit with always-valid time window, deriving entityID from wallet.
    function makePurchasePermit(address wallet) internal view returns (PurchasePermitV3 memory) {
        return makePurchasePermit({saleSpecificEntityID: addressToEntityID(wallet), wallet: wallet});
    }

    /// @notice Creates a purchase permit with custom limits and always-valid time window.
    function makePurchasePermit(
        bytes16 saleSpecificEntityID,
        address wallet,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 minPrice,
        uint64 maxPrice
    ) internal view returns (PurchasePermitV3 memory) {
        return makePurchasePermit({
            saleSpecificEntityID: saleSpecificEntityID,
            saleUUID: TEST_SALE_UUID,
            wallet: wallet,
            minAmount: minAmount,
            maxAmount: maxAmount,
            minPrice: minPrice,
            maxPrice: maxPrice,
            forcedLockup: false,
            expiresAt: uint64(block.timestamp + 1000),
            opensAt: 0,
            closesAt: type(uint64).max
        });
    }

    /// @notice Creates a purchase permit with custom limits, lockup, expiry, and always-valid time window.
    function makePurchasePermit(
        bytes16 saleSpecificEntityID,
        bytes16 saleUUID,
        address wallet,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 minPrice,
        uint64 maxPrice,
        bool forcedLockup,
        uint64 expiresAt
    ) internal pure returns (PurchasePermitV3 memory) {
        return makePurchasePermit({
            saleSpecificEntityID: saleSpecificEntityID,
            saleUUID: saleUUID,
            wallet: wallet,
            minAmount: minAmount,
            maxAmount: maxAmount,
            minPrice: minPrice,
            maxPrice: maxPrice,
            forcedLockup: forcedLockup,
            expiresAt: expiresAt,
            opensAt: 0,
            closesAt: type(uint64).max
        });
    }

    function doBid(address user, IERC20 token, uint256 amount, uint64 price) internal {
        doBid({
            entityID: addressToEntityID(user), user: user, amount: amount, price: price, lockup: false, token: token
        });
    }

    function doBid(address user, IERC20 token, uint256 amount, uint64 price, bool lockup) internal {
        doBid({
            entityID: addressToEntityID(user),
            user: user,
            amount: amount,
            price: price,
            lockup: lockup,
            token: token,
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: SALE_MIN_PRICE,
            maxPrice: SALE_MAX_PRICE,
            forcedLockup: false
        });
    }

    function doBid(bytes16 entityID, address user, IERC20 token, uint256 amount, uint64 price) internal {
        doBid({
            entityID: entityID,
            user: user,
            amount: amount,
            price: price,
            lockup: false,
            token: token,
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: SALE_MIN_PRICE,
            maxPrice: SALE_MAX_PRICE,
            forcedLockup: false
        });
    }

    function doBid(bytes16 entityID, address user, IERC20 token, uint256 amount, uint64 price, bool lockup) internal {
        doBid({
            entityID: entityID,
            user: user,
            amount: amount,
            price: price,
            lockup: lockup,
            token: token,
            minAmount: SALE_MIN_AMOUNT,
            maxAmount: SALE_MAX_AMOUNT,
            minPrice: SALE_MIN_PRICE,
            maxPrice: SALE_MAX_PRICE,
            forcedLockup: false
        });
    }

    struct DoBidParams {
        bytes16 entityID;
        address user;
        uint256 amount;
        uint64 price;
        bool lockup;
        IERC20 token;
        uint256 minAmount;
        uint256 maxAmount;
        uint64 minPrice;
        uint64 maxPrice;
        bool forcedLockup;
    }

    function doBid(
        bytes16 entityID,
        address user,
        uint256 amount,
        uint64 price,
        bool lockup,
        IERC20 token,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 minPrice,
        uint64 maxPrice,
        bool forcedLockup
    ) internal {
        _doBidWithParams(
            DoBidParams({
                entityID: entityID,
                user: user,
                amount: amount,
                price: price,
                lockup: lockup,
                token: token,
                minAmount: minAmount,
                maxAmount: maxAmount,
                minPrice: minPrice,
                maxPrice: maxPrice,
                forcedLockup: forcedLockup
            })
        );
    }

    function _doBidWithParams(DoBidParams memory params) internal {
        PurchasePermitV3 memory purchasePermit = makePurchasePermit({
            saleSpecificEntityID: params.entityID,
            saleUUID: TEST_SALE_UUID,
            wallet: params.user,
            minAmount: params.minAmount,
            maxAmount: params.maxAmount,
            minPrice: params.minPrice,
            maxPrice: params.maxPrice,
            forcedLockup: params.forcedLockup,
            expiresAt: uint64(block.timestamp + 1000),
            opensAt: 0,
            closesAt: type(uint64).max
        });
        bytes memory purchasePermitSignature = signPurchasePermit(purchasePermit);

        uint256 previousBidAmount = 0;
        // Use the provided entityID (not addressToEntityID(user)) to correctly handle
        // multi-wallet entities where a different wallet places a bid for an existing entity
        if (sale.isEntityInitialized(params.entityID)) {
            previousBidAmount = sale.entityStateByID(params.entityID).currentBid.amount;
        }

        uint256 amountDelta = params.amount - previousBidAmount;
        deal(address(params.token), params.user, amountDelta);

        vm.prank(params.user);
        params.token.approve(address(sale), amountDelta);

        SettlementSale.Bid memory bid =
            SettlementSale.Bid({lockup: params.lockup, price: params.price, amount: params.amount});
        vm.prank(params.user);
        sale.replaceBidWithApproval(params.token, bid, purchasePermit, purchasePermitSignature);
    }

    /// @notice Signs an ERC20 permit signature using an Account's private key.
    function signERC20Permit(
        ERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal view returns (bytes memory) {
        uint256 nonce = token.nonces(owner);
        bytes32 structHash = keccak256(abi.encode(ERC20_PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 hash = MessageHashUtils.toTypedDataHash(token.DOMAIN_SEPARATOR(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(addressToAccount[owner].key, hash);
        return abi.encodePacked(r, s, v);
    }

    /// @notice Helper to get ERC20 permit signature for a bid increment.
    function getERC20PermitSignature(
        IERC20 token,
        address owner,
        uint256 amountDelta
    ) internal view returns (bytes memory, uint256) {
        ERC20Permit permitToken = ERC20Permit(address(token));
        uint256 deadline = block.timestamp + 1000;
        address spender = address(sale);
        bytes memory signature = signERC20Permit(permitToken, owner, spender, amountDelta, deadline);
        return (signature, deadline);
    }

    function doSetAllocation(address wallet, IERC20 token, uint256 amount) internal {
        doSetAllocation(wallet, token, amount, false);
    }

    function doSetAllocation(bytes16 entityID, address wallet, IERC20 token, uint256 amount) internal {
        doSetAllocation(entityID, wallet, token, amount, false);
    }

    function doSetAllocation(address wallet, IERC20 token, uint256 amount, bool allowOverwrite) internal {
        return doSetAllocation({
            entityID: addressToEntityID(wallet),
            wallet: wallet,
            token: token,
            amount: amount,
            allowOverwrite: allowOverwrite
        });
    }

    function doSetAllocation(
        bytes16 entityID,
        address wallet,
        IERC20 token,
        uint256 amount,
        bool allowOverwrite
    ) internal {
        IOffchainSettlement.Allocation[] memory allocations = new IOffchainSettlement.Allocation[](1);
        allocations[0] = IOffchainSettlement.Allocation({
            saleSpecificEntityID: entityID, wallet: wallet, token: address(token), acceptedAmount: amount
        });

        vm.prank(settler);
        sale.setAllocations({allocations: allocations, allowOverwrite: allowOverwrite});
    }

    function addressToEntityID(address addr) internal pure returns (bytes16) {
        return bytes16(keccak256(abi.encode(addr)));
    }

    function assertEq(SettlementSale.Bid memory a, SettlementSale.Bid memory b) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(SettlementSale.Bid memory a, SettlementSale.Bid memory b, string memory message) internal pure {
        assertEq(a.lockup, b.lockup, string.concat(message, ": lockup"));
        assertEq(a.amount, b.amount, string.concat(message, ": amount"));
        assertEq(a.price, b.price, string.concat(message, ": price"));
    }

    function assertEq(SettlementSale.WalletStateView memory a, SettlementSale.WalletStateView memory b) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(TokenAmount memory a, TokenAmount memory b, string memory message) internal pure {
        assertEq(address(a.token), address(b.token), string.concat(message, ": token"));
        assertEq(a.amount, b.amount, string.concat(message, ": amount"));
    }

    function assertEq(TokenAmount[] memory a, TokenAmount[] memory b) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(TokenAmount[] memory a, TokenAmount[] memory b, string memory message) internal pure {
        assertEq(a.length, b.length, string.concat(message, ": length mismatch"));
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i], string.concat(message, ": [", Strings.toString(i), "]"));
        }
    }

    function assertEq(WalletTokenAmount memory a, WalletTokenAmount memory b, string memory message) internal pure {
        assertEq(a.wallet, b.wallet, string.concat(message, ": wallet"));
        assertEq(a.token, b.token, string.concat(message, ": token"));
        assertEq(a.amount, b.amount, string.concat(message, ": amount"));
    }

    function assertEq(WalletTokenAmount[] memory a, WalletTokenAmount[] memory b) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(WalletTokenAmount[] memory a, WalletTokenAmount[] memory b, string memory message) internal pure {
        assertEq(a.length, b.length, string.concat(message, ": length mismatch"));
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i], string.concat(message, ": [", Strings.toString(i), "]"));
        }
    }

    function assertEq(
        IEntityAllocationDataReader.EntityAllocationData memory a,
        IEntityAllocationDataReader.EntityAllocationData memory b,
        string memory message
    ) internal pure {
        assertEq(a.saleSpecificEntityID, b.saleSpecificEntityID, string.concat(message, ": saleSpecificEntityID"));
        assertEq(a.acceptedAmounts, b.acceptedAmounts, string.concat(message, ": acceptedAmounts"));
    }

    function assertEq(
        IEntityAllocationDataReader.EntityAllocationData[] memory a,
        IEntityAllocationDataReader.EntityAllocationData[] memory b
    ) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(
        IEntityAllocationDataReader.EntityAllocationData[] memory a,
        IEntityAllocationDataReader.EntityAllocationData[] memory b,
        string memory message
    ) internal pure {
        assertEq(a.length, b.length, string.concat(message, ": length mismatch"));
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i], string.concat(message, ": [", Strings.toString(i), "]"));
        }
    }

    function assertEq(
        SettlementSale.WalletStateView memory a,
        SettlementSale.WalletStateView memory b,
        string memory message
    ) internal pure {
        assertEq(a.addr, b.addr, string.concat(message, ": addr"));
        assertEq(a.entityID, b.entityID, string.concat(message, ": entityID"));
        assertEq(a.acceptedAmountByToken, b.acceptedAmountByToken, string.concat(message, ": acceptedAmountByToken"));
        assertEq(a.committedAmountByToken, b.committedAmountByToken, string.concat(message, ": committedAmountByToken"));
    }

    function assertEq(
        ICommitmentDataReader.CommitmentData memory a,
        ICommitmentDataReader.CommitmentData memory b
    ) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(
        ICommitmentDataReader.CommitmentData memory a,
        ICommitmentDataReader.CommitmentData memory b,
        string memory message
    ) internal pure {
        assertEq(a.commitmentID, b.commitmentID, string.concat(message, ": commitmentID"));
        assertEq(a.saleSpecificEntityID, b.saleSpecificEntityID, string.concat(message, ": saleSpecificEntityID"));
        assertEq(a.timestamp, b.timestamp, string.concat(message, ": timestamp"));
        assertEq(a.price, b.price, string.concat(message, ": price"));
        assertEq(a.refunded, b.refunded, string.concat(message, ": refunded"));
        assertEq(
            keccak256(abi.encode(a.amounts)), keccak256(abi.encode(b.amounts)), string.concat(message, ": amounts")
        );
        assertEq(a.extraData, b.extraData, string.concat(message, ": extraData"));
    }

    function openCommitment() public {
        vm.prank(manager);
        sale.openCommitment();
    }

    function closeCommitment() internal {
        vm.prank(manager);
        sale.closeCommitment();
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

    function toTokenAmounts(uint256 usdcAmount, uint256 usdtAmount) internal view returns (TokenAmount[] memory) {
        TokenAmount[] memory amounts = new TokenAmount[](2);
        amounts[0] = TokenAmount({token: address(usdc), amount: usdcAmount});
        amounts[1] = TokenAmount({token: address(usdt), amount: usdtAmount});
        return amounts;
    }

    function sum(TokenAmount[] memory tokenAmounts) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < tokenAmounts.length; i++) {
            total += tokenAmounts[i].amount;
        }
        return total;
    }

    function sum(WalletTokenAmount[] memory walletTokenAmounts) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < walletTokenAmounts.length; i++) {
            total += walletTokenAmounts[i].amount;
        }
        return total;
    }

    function add(TokenAmount[] memory a, TokenAmount[] memory b) internal pure returns (TokenAmount[] memory) {
        require(a.length == b.length, "length mismatch");
        TokenAmount[] memory result = new TokenAmount[](a.length);
        for (uint256 i = 0; i < a.length; i++) {
            result[i] = TokenAmount({token: a[i].token, amount: a[i].amount + b[i].amount});
        }
        return result;
    }

    function sub(TokenAmount[] memory a, TokenAmount[] memory b) internal pure returns (TokenAmount[] memory) {
        require(a.length == b.length, "length mismatch");
        TokenAmount[] memory result = new TokenAmount[](a.length);
        for (uint256 i = 0; i < a.length; i++) {
            result[i] = TokenAmount({token: a[i].token, amount: a[i].amount - b[i].amount});
        }
        return result;
    }

    function assertTokenBalances(
        address owner,
        uint256 usdcAmount,
        uint256 usdtAmount,
        string memory message
    ) internal view {
        assertEq(usdc.balanceOf(owner), usdcAmount, string.concat(message, ": usdc balance of owner"));
        assertEq(usdt.balanceOf(owner), usdtAmount, string.concat(message, ": usdt balance of owner"));
    }

    function assertTokenBalances(address owner, uint256 usdcAmount, uint256 usdtAmount) internal view {
        assertEq(tokenBalances(owner), toTokenAmounts(usdcAmount, usdtAmount), "");
    }

    function tokenBalances(address owner) internal view returns (TokenAmount[] memory) {
        TokenAmount[] memory balances = new TokenAmount[](2);
        balances[0] = TokenAmount({token: address(usdc), amount: usdc.balanceOf(owner)});
        balances[1] = TokenAmount({token: address(usdt), amount: usdt.balanceOf(owner)});
        return balances;
    }

    /// @notice Helper to encode InvalidStage error with a single expected stage.
    function encodeInvalidStage(
        SettlementSale.Stage got,
        SettlementSale.Stage want
    ) internal pure returns (bytes memory) {
        SettlementSale.Stage[] memory wanted = new SettlementSale.Stage[](1);
        wanted[0] = want;
        return abi.encodeWithSelector(SettlementSale.InvalidStage.selector, got, wanted);
    }

    /// @notice Helper to encode InvalidStage error with two expected stages.
    function encodeInvalidStage(
        SettlementSale.Stage got,
        SettlementSale.Stage want1,
        SettlementSale.Stage want2
    ) internal pure returns (bytes memory) {
        SettlementSale.Stage[] memory wanted = new SettlementSale.Stage[](2);
        wanted[0] = want1;
        wanted[1] = want2;
        return abi.encodeWithSelector(SettlementSale.InvalidStage.selector, got, wanted);
    }
}
