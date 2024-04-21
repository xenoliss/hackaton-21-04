// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {AggregatorV3Interface} from "chainlink/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

import {ERC20WithMinters} from "./ERC20WithMinters.sol";

contract AMM is Ownable {
    /// @notice The USDC address.
    address public immutable usdc;

    /// @notice The chainlink price feeds per token.
    mapping(address token => AggregatorV3Interface priceFeed) public priceFeeds;

    constructor(address usdc_) {
        usdc = usdc_;
        _initializeOwner(msg.sender);
    }

    /// @notice Set the price feed to use.
    ///
    /// @param token The token address.
    /// @param priceFeed The price feed address.
    function setPriceFeed(address token, address priceFeed) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(priceFeed);
    }

    /// @notice Swap tokens.
    ///
    /// @param tokenIn The token in address.
    /// @param tokenOut The token out address.
    /// @param receiver The receiver address.
    ///
    /// @return amountOut The token out amount.
    function swap(address tokenIn, address tokenOut, address receiver) external returns (uint256 amountOut) {
        uint256 amountIn = ERC20(tokenIn).balanceOf(address(this));

        amountOut = getAmountOut(tokenIn, tokenOut, amountIn);

        ERC20WithMinters(tokenIn).burn({from: address(this), amount: amountIn});
        ERC20WithMinters(tokenOut).mint({to: receiver, amount: amountOut});
    }

    /// @notice Returns the token amount out.
    ///
    /// @param tokenIn The token in address.
    /// @param tokenOut The token out address.
    /// @param amountIn The token in amount.
    ///
    /// @return amountOut The token out amount.
    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn)
        public
        view
        returns (uint256 amountOut)
    {
        uint256 priceIn = _getPrice(tokenIn);
        uint256 priceOut = _getPrice(tokenOut);

        uint256 precisionIn = 10 ** ERC20(tokenIn).decimals();
        uint256 precisionOut = 10 ** ERC20(tokenOut).decimals();

        amountOut = (amountIn * priceIn * precisionOut) / (priceOut * precisionIn);
    }

    /// @notice Fetch the token price from the Chainlink price feed.
    ///
    /// @param token The token address.
    function _getPrice(address token) private view returns (uint256) {
        if (token == usdc) {
            return 1e18;
        }

        (, int256 answer,,,) = priceFeeds[token].latestRoundData();
        return uint256(answer) * 1e10;
    }
}
