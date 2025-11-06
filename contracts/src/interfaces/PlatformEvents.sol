// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

/// @notice Emitted when a configuration has been updated.
/// @param setterSelector The selector of the function that updated the configuration.
/// @param setterSignature The signature of the function that updated the configuration.
/// @param value The abi-encoded data passed to the function that updated the configuration. Since this event will only be emitted by setters, this data corresponds to the updated values in the configuration.
event ConfigChanged(bytes4 indexed setterSelector, string setterSignature, bytes value);
