// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Fake is ERC20Permit {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract ERC20FakeWithDecimals is ERC20Fake {
    uint8 internal immutable _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20Fake(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
