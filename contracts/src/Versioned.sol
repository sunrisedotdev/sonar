// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

/// @title Versioned
/// @notice A base contract for version control
/// @dev This contract MUST only contain immutable state, since we will also use it for upgradeable contracts.
contract Versioned {
    uint32 private immutable _major;
    uint32 private immutable _minor;
    uint32 private immutable _patch;

    constructor(uint32 major, uint32 minor, uint32 patch) {
        _major = major;
        _minor = minor;
        _patch = patch;
    }

    function version() external view returns (uint32, uint32, uint32) {
        return (_major, _minor, _patch);
    }
}
