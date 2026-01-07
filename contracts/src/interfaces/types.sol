// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

/// @notice An amount a of a specific token
struct TokenAmount {
    /// The token address
    address token;
    /// The amount of the token
    uint256 amount;
}

/// @notice A token amount related to a specific wallet
struct WalletTokenAmount {
    /// The wallet address
    address wallet;
    /// The token address
    address token;
    /// The amount of the token
    uint256 amount;
}
