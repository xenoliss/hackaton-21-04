// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract ERC20WithMinters is ERC20, Ownable {
    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;

        _initializeOwner(msg.sender);
    }

    /// @notice Mint new tokens.
    ///
    /// @param to The recipient address.
    /// @param amount The amount to mint.
    function mint(address to, uint256 amount) external {
        _mint({to: to, amount: amount});
    }

    /// @notice Burn tokens.
    ///
    /// @param from The from address.
    /// @param amount The amount to burn.
    function burn(address from, uint256 amount) external {
        _burn({from: from, amount: amount});
    }

    /// @notice Returns the name of the token.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the decimals places of the token.
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
