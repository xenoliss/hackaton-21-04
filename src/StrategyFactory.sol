// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {AMM} from "./AMM.sol";
import {IndexStrategy} from "./IndexStrategy.sol";

contract StrategyFactory {
    /// @notice The USDC address.
    address public immutable usdc;

    /// @notice The AMM address used to swap tokens and compute their market price.
    AMM public immutable amm;

    constructor(address usdc_, AMM amm_) {
        usdc = usdc_;
        amm = amm_;
    }

    /// @notice Deploy a new strategy.
    ///
    /// @param tokens The strategy token addresses.
    /// @param weights The strategy token weights.
    /// @param rebalanceInterval The strategy rebalancing interval.
    /// @param isOpen Whether the strategy is open to public or restricted to a whitelist.
    /// @param investors The investors whitelist allow to use this strategy.
    /// @param name The strategy name.
    /// @param symbol The strategy symbol.
    function deployNewStrategy(
        address[] memory tokens,
        uint16[] memory weights,
        uint256 rebalanceInterval,
        bool isOpen,
        address[] memory investors,
        string memory name,
        string memory symbol
    ) external returns (address) {
        IndexStrategy strategy = new IndexStrategy({
            tokens_: tokens,
            weights_: weights,
            rebalanceInterval_: rebalanceInterval,
            isOpen_: isOpen,
            investors_: investors,
            amm_: amm,
            usdc_: usdc,
            name_: name,
            symbol_: symbol
        });

        return address(strategy);
    }
}
