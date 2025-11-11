// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract BaseTest is Test {
    using EnumerableMap for EnumerableMap.Bytes32ToBytes32Map;

    bytes internal constant NoExpectedError = "";

    address internal immutable admin = makeAddr("admin");
    address internal immutable manager = makeAddr("manager");

    address internal immutable alice = makeAddr("alice");
    address internal immutable bob = makeAddr("bob");
    address internal immutable charlie = makeAddr("charlie");

    Account internal aliceAcc = makeAccount("alice");
    Account internal bobAcc = makeAccount("bob");
    Account internal charlieAcc = makeAccount("charlie");

    mapping(address => Account) internal addressToAccount;

    constructor() {
        vm.warp(2);
    }

    /// @dev override to register all created accounts
    function makeAccount(string memory name) internal override returns (Account memory) {
        Account memory acc = super.makeAccount(name);
        addressToAccount[acc.addr] = acc;
        return acc;
    }

    /// @dev override to register the corresponding accounts for all created addresses
    function makeAddr(string memory name) internal override returns (address) {
        return makeAccount(name).addr;
    }

    /**
     * @notice Returns the error thrown by OZ's `AccessControl` contract if an account is missing a particular role
     */
    function missingRoleError(address account, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, role);
    }

    function sign(uint256 pk, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return abi.encodePacked(r, s, v);
    }

    function sign(address signer, bytes32 hash) internal view returns (bytes memory) {
        return sign(addressToAccount[signer].key, hash);
    }

    function readCloneImplAddress(address clone) internal view returns (address) {
        address impl;
        assembly {
            // the implementation address is stored at an offset of 10 bytes in the clone's contract bytecode
            extcodecopy(clone, 0, 10, 20)
            impl := shr(96, mload(0))
        }
        return impl;
    }

    function readProxyAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    }

    EnumerableMap.Bytes32ToBytes32Map dealSlotsBefore;
    EnumerableMap.Bytes32ToBytes32Map dealSlotsAfter;

    function assertStorageUnchanged(Vm.AccountAccess[] memory accountAccesses, address account) internal {
        uint256 snap = vm.snapshot();

        // find first value of each accessed slot
        for (uint256 i = accountAccesses.length; i > 0; --i) {
            for (uint256 j = accountAccesses[i - 1].storageAccesses.length; j > 0; --j) {
                Vm.StorageAccess memory storageAccess = accountAccesses[i - 1].storageAccesses[j - 1];
                if (storageAccess.account != account) {
                    continue;
                }
                dealSlotsBefore.set(storageAccess.slot, storageAccess.previousValue);
            }
        }

        // find last value of each accessed slot
        for (uint256 i; i < accountAccesses.length; ++i) {
            for (uint256 j; j < accountAccesses[i].storageAccesses.length; ++j) {
                Vm.StorageAccess memory storageAccess = accountAccesses[i].storageAccesses[j];
                if (storageAccess.account != account) {
                    continue;
                }
                dealSlotsAfter.set(storageAccess.slot, storageAccess.newValue);
            }
        }

        // consistency check
        assertEq(dealSlotsBefore.length(), dealSlotsAfter.length());

        for (uint256 i; i < dealSlotsAfter.length(); ++i) {
            (bytes32 slot, bytes32 pre) = dealSlotsBefore.at(i);
            bytes32 post = dealSlotsAfter.get(slot);
            assertEq(post, pre, "storage changed");
        }

        // to reset `dealSlots{Before,After}`
        vm.revertTo(snap);
    }

    EnumerableMap.Bytes32ToBytes32Map slotsA;
    EnumerableMap.Bytes32ToBytes32Map slotsB;

    /// @dev Asserts that the state diff applied to accountA and accountB are the same given the recorded access logs for mutations on both accounts
    function assertSameStateDiff(
        address accountA,
        Vm.AccountAccess[] memory accessesA,
        address accountB,
        Vm.AccountAccess[] memory accessesB
    ) internal {
        uint256 snap = vm.snapshot();

        // find last value of each accessed slot in A
        for (uint256 i; i < accessesA.length; ++i) {
            for (uint256 j; j < accessesA[i].storageAccesses.length; ++j) {
                Vm.StorageAccess memory storageAccess = accessesA[i].storageAccesses[j];
                if (storageAccess.account != accountA || storageAccess.reverted || !storageAccess.isWrite) {
                    continue;
                }
                slotsA.set(storageAccess.slot, storageAccess.newValue);
            }
        }

        // find last value of each accessed slot in B
        for (uint256 i; i < accessesB.length; ++i) {
            for (uint256 j; j < accessesB[i].storageAccesses.length; ++j) {
                Vm.StorageAccess memory storageAccess = accessesB[i].storageAccesses[j];
                if (storageAccess.account != accountB || storageAccess.reverted || !storageAccess.isWrite) {
                    continue;
                }
                slotsB.set(storageAccess.slot, storageAccess.newValue);
            }
        }

        // consistency check
        for (uint256 i; i < slotsA.length(); ++i) {
            (bytes32 slot, bytes32 valA) = slotsA.at(i);
            (, bytes32 valB) = slotsB.tryGet(slot);
            assertEq(valA, valB, "storage changed");
        }

        for (uint256 i; i < slotsB.length(); ++i) {
            (bytes32 slot, bytes32 valB) = slotsB.at(i);
            (, bytes32 valA) = slotsA.tryGet(slot);
            assertEq(valA, valB, "storage changed");
        }

        // to reset `slotsA` and `slotsB`
        vm.revertTo(snap);
    }
}
