// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

/**
 * @title Fixed6
 * @notice A fixed 6-decimal precision amount system for handling multi-token operations with consistent precision
 *
 * @dev This contract implements a fixed 6-decimal precision amount system that standardizes different stablecoin
 * tokens (USDC, USDT, DAI, etc.) to a common 6 decimal place format. This design enables
 * consistent mathematical operations across tokens with different native decimal precisions.
 *
 * ## Why Use 6 Decimal Places?
 *
 * Different stablecoins have different decimal precisions:
 * - USDC: 6 decimals
 * - USDT: 6 decimals
 * - DAI: 18 decimals
 *
 * Using 6dp instead of 18dp prevents scenarios where partial refunds or distributions result in
 * amounts that cannot be expressed in lower precision tokens. For example, if we used 18dp
 * precision and needed to refund a calculated amount to a 6dp token, we might end up with
 * fractional amounts that cannot be represented in the target token. To avoid this scenario, we use
 * 6dp precision and enforce that tokens with more than 6 decimal places must only specify amounts that have
 * at most 6 decimal place precision.
 *
 * Input tokens are validated to have ≤6 decimal places to prevent precision loss during conversion.
 */
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev Custom type that wraps uint256 to represent amounts with 6 decimal places of precision.
 * This provides type safety and prevents accidental mixing of fixed-precision and raw token amounts.
 */
type Fixed6 is uint256;

/**
 * @dev Operator overloads for Fixed6 to enable natural mathematical syntax.
 * These operators work directly on the wrapped uint256 values while maintaining type safety.
 */
using {
    addFixed6 as +, subFixed6 as -, ltFixed6 as <, leqFixed6 as <=, gtFixed6 as >, eqFixed6 as ==
} for Fixed6 global;

function addFixed6(Fixed6 a, Fixed6 b) pure returns (Fixed6) {
    return Fixed6.wrap(Fixed6.unwrap(a) + Fixed6.unwrap(b));
}

function subFixed6(Fixed6 a, Fixed6 b) pure returns (Fixed6) {
    return Fixed6.wrap(Fixed6.unwrap(a) - Fixed6.unwrap(b));
}

function ltFixed6(Fixed6 a, Fixed6 b) pure returns (bool) {
    return Fixed6.unwrap(a) < Fixed6.unwrap(b);
}

function leqFixed6(Fixed6 a, Fixed6 b) pure returns (bool) {
    return Fixed6.unwrap(a) <= Fixed6.unwrap(b);
}

function gtFixed6(Fixed6 a, Fixed6 b) pure returns (bool) {
    return Fixed6.unwrap(a) > Fixed6.unwrap(b);
}

function eqFixed6(Fixed6 a, Fixed6 b) pure returns (bool) {
    return Fixed6.unwrap(a) == Fixed6.unwrap(b);
}

/**
 * @title Fixed6Lib
 * @notice Library providing utility functions for Fixed6 operations and conversions
 * @dev Contains the core logic for converting between token amounts and fixed-precision amounts,
 * as well as additional mathematical operations not covered by basic operators.
 */
library Fixed6Lib {
    /// @dev The fixed decimal precision used for all Fixed6 amounts
    uint8 constant FIXED6_DECIMALS = 6;

    /**
     * @notice Thrown when a token amount conversion would result in precision loss
     * @param tokenAmount The original token amount that failed conversion
     * @param tokenDecimals The decimal places of the source token
     * @param remainder The remainder of the token amount after conversion
     */
    error TokenAmountConversionLossOfPrecision(uint256 tokenAmount, uint8 tokenDecimals, uint256 remainder);

    /**
     * @notice Thrown when a token with invalid decimal precision is used.
     * @param tokenDecimals The decimal places of the source token
     */
    error InvalidTokenDecimals(uint8 tokenDecimals);

    /**
     * @notice Returns the minimum of two Fixed6 values
     * @param a First value to compare
     * @param b Second value to compare
     * @return The smaller of the two values
     */
    function min(Fixed6 a, Fixed6 b) internal pure returns (Fixed6) {
        return Fixed6.wrap(Math.min(Fixed6.unwrap(a), Fixed6.unwrap(b)));
    }

    /**
     * @notice Performs multiplication and division in a single operation to avoid intermediate overflow
     * @param a First operand
     * @param b Second operand
     * @param c Divisor
     * @return Result of (a * b) / c as Fixed6
     */
    function mulDiv(Fixed6 a, Fixed6 b, Fixed6 c) internal pure returns (Fixed6) {
        return Fixed6.wrap(Math.mulDiv(Fixed6.unwrap(a), Fixed6.unwrap(b), Fixed6.unwrap(c)));
    }

    /**
     * @notice Converts a raw token amount to a Fixed6 with precision validation
     * @dev This function enforces that the conversion is lossless, and reverts if it is not.
     * This implies that tokens with more than 6 decimal places must only specify amounts that have
     * at most 6 decimal place precision.
     *
     * @param amount The raw token amount to convert
     * @param decimals The number of decimal places the token uses
     * @return The fixed-precision amount with 6 decimal places of precision
     *
     * @custom:throws TokenAmountConversionLossOfPrecision if the conversion is not lossless
     * @custom:throws InvalidTokenDecimals if the token has less than 6 decimal places
     */
    function convertTokenAmountToFixed6(uint256 amount, uint8 decimals) internal pure returns (Fixed6) {
        // Lower precision, we could scale this up, but as we don't need to support any coins with < 6 decimal places,
        // we just revert to prevent mistakes using the library.
        if (decimals < FIXED6_DECIMALS) {
            revert InvalidTokenDecimals(decimals);
        }

        // Already the correct precision, just wrap.
        if (decimals == FIXED6_DECIMALS) {
            return Fixed6.wrap(amount);
        }

        uint256 factor = 10 ** (decimals - FIXED6_DECIMALS);
        if (amount % factor != 0) {
            revert TokenAmountConversionLossOfPrecision(amount, decimals, amount % factor);
        }
        return Fixed6.wrap(amount / factor);
    }

    /**
     * @notice Converts a Fixed6 back to a raw token amount
     * @dev This function converts from the 6-decimal fixed-precision format back to the token's
     * native decimal format.
     *
     * @param amount The fixed-precision amount to convert
     * @param tokenDecimals The number of decimal places the target token uses
     * @return The raw token amount in the token's native precision
     *
     * @custom:throws InvalidTokenDecimals if the token has less than 6 decimal places
     */
    function convertFixed6ToTokenAmount(Fixed6 amount, uint8 tokenDecimals) internal pure returns (uint256) {
        // Lower precision, we could scale this up, but as we don't need to support any coins with < 6 decimal places,
        // we just revert to prevent mistakes using the library.
        if (tokenDecimals < FIXED6_DECIMALS) {
            revert InvalidTokenDecimals(tokenDecimals);
        }

        // Already the correct precision, just wrap.
        if (tokenDecimals == FIXED6_DECIMALS) {
            return Fixed6.unwrap(amount);
        }

        return Fixed6.unwrap(amount) * 10 ** (tokenDecimals - FIXED6_DECIMALS);
    }
}
