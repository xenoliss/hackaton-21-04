// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "chainlink/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

import {ERC20WithMinters} from "src/ERC20WithMinters.sol";
import {IndexStrategy} from "src/IndexStrategy.sol";
import {StrategyFactory} from "src/StrategyFactory.sol";
import {AMM} from "src/AMM.sol";

contract IndexStrategyTest is Test {
    ERC20WithMinters usdc;
    ERC20WithMinters weth;
    ERC20WithMinters wbtc;
    ERC20WithMinters link;

    address ethPriceFeed = address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
    address btcPriceFeed = address(0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298);
    address linkPriceFeed = address(0xb113F5A928BCfF189C998ab20d753a47F9dE5A61);

    IndexStrategy strategy;

    function setUp() public {
        vm.createSelectFork("https://sepolia.base.org");

        usdc = ERC20WithMinters(0x47E27927fDeD5bF66dDA166925cCB53Ff76D09B0);
        weth = ERC20WithMinters(0xE187295A56FE6609a364B7ca9746a3aB633c7CEf);
        wbtc = ERC20WithMinters(0x4771Ec5AB9D6Fe38bA5c005b79730108499f44A8);
        link = ERC20WithMinters(0x418CF6f3A2D0ce24CB21a506A1Ea3d611935A5c8);

        strategy = IndexStrategy(0x6Bdb041b7bcFB7eA34fEE79e7Df46CcDAEC0413a);

        usdc.mint({to: address(this), amount: 1000 * 1e6});
        usdc.approve({spender: address(strategy), amount: 1000 * 1e6});
    }

    function testFullFlow() public {
        uint256 usdcBalance = usdc.balanceOf(address(this));
        console.log("Investor USDC balance before deposit", usdcBalance);

        console.log("----");

        strategy.deposit({usdcAmountIn: 1000 * 1e6});

        usdcBalance = usdc.balanceOf(address(this));
        console.log("Investor USDC balance after deposit", usdcBalance);

        usdcBalance = usdc.balanceOf(address(strategy));
        uint256 wethBalance = weth.balanceOf(address(strategy));
        uint256 wbtcBalance = wbtc.balanceOf(address(strategy));
        uint256 linkBalance = link.balanceOf(address(strategy));
        console.log("Strategy USDC balance after deposit", usdcBalance);
        console.log("Strategy WETH balance after deposit", wethBalance);
        console.log("Strategy WBTC balance after deposit", wbtcBalance);
        console.log("Strategy LINK balance after deposit", linkBalance);

        console.log("----");

        vm.warp(block.timestamp + 61);
        strategy.rebalance();

        usdcBalance = usdc.balanceOf(address(strategy));
        wethBalance = weth.balanceOf(address(strategy));
        wbtcBalance = wbtc.balanceOf(address(strategy));
        linkBalance = link.balanceOf(address(strategy));
        console.log("Strategy USDC balance after rebalance", usdcBalance);
        console.log("Strategy WETH balance after rebalance", wethBalance);
        console.log("Strategy WBTC balance after rebalance", wbtcBalance);
        console.log("Strategy LINK balance after rebalance", linkBalance);

        console.log("----");

        strategy.withdraw({sharesAmountIn: ERC20(strategy).balanceOf(address(this))});

        usdcBalance = usdc.balanceOf(address(this));
        console.log("Investor USDC balance after withdraw", usdcBalance);

        usdcBalance = usdc.balanceOf(address(strategy));
        wethBalance = weth.balanceOf(address(strategy));
        wbtcBalance = wbtc.balanceOf(address(strategy));
        linkBalance = link.balanceOf(address(strategy));
        console.log("Strategy USDC balance after withdraw", usdcBalance);
        console.log("Strategy WETH balance after withdraw", wethBalance);
        console.log("Strategy WBTC balance after withdraw", wbtcBalance);
        console.log("Strategy LINK balance after withdraw", linkBalance);
    }

    function testFullFlowWithMockedPrices() public {
        uint256 usdcBalance = usdc.balanceOf(address(this));
        console.log("Investor USDC balance before deposit", usdcBalance);

        console.log("----");

        strategy.deposit({usdcAmountIn: 1000 * 1e6});

        usdcBalance = usdc.balanceOf(address(this));
        console.log("Investor USDC balance after deposit", usdcBalance);

        usdcBalance = usdc.balanceOf(address(strategy));
        uint256 wethBalance = weth.balanceOf(address(strategy));
        uint256 wbtcBalance = wbtc.balanceOf(address(strategy));
        uint256 linkBalance = link.balanceOf(address(strategy));
        console.log("Strategy USDC balance after deposit", usdcBalance);
        console.log("Strategy WETH balance after deposit", wethBalance);
        console.log("Strategy WBTC balance after deposit", wbtcBalance);
        console.log("Strategy LINK balance after deposit", linkBalance);

        console.log("----");

        _mockPriceFeedPrice({priceFeed: ethPriceFeed, spot: 10000 * 1e6});
        _mockPriceFeedPrice({priceFeed: btcPriceFeed, spot: 70000 * 1e6});
        _mockPriceFeedPrice({priceFeed: linkPriceFeed, spot: 15 * 1e6});

        vm.warp(block.timestamp + 61);
        strategy.rebalance();

        usdcBalance = usdc.balanceOf(address(strategy));
        wethBalance = weth.balanceOf(address(strategy));
        wbtcBalance = wbtc.balanceOf(address(strategy));
        linkBalance = link.balanceOf(address(strategy));
        console.log("Strategy USDC balance after rebalance", usdcBalance);
        console.log("Strategy WETH balance after rebalance", wethBalance);
        console.log("Strategy WBTC balance after rebalance", wbtcBalance);
        console.log("Strategy LINK balance after rebalance", linkBalance);

        console.log("----");

        strategy.withdraw({sharesAmountIn: ERC20(strategy).balanceOf(address(this))});

        usdcBalance = usdc.balanceOf(address(this));
        console.log("Investor USDC balance after withdraw", usdcBalance);

        usdcBalance = usdc.balanceOf(address(strategy));
        wethBalance = weth.balanceOf(address(strategy));
        wbtcBalance = wbtc.balanceOf(address(strategy));
        linkBalance = link.balanceOf(address(strategy));
        console.log("Strategy USDC balance after withdraw", usdcBalance);
        console.log("Strategy WETH balance after withdraw", wethBalance);
        console.log("Strategy WBTC balance after withdraw", wbtcBalance);
        console.log("Strategy LINK balance after withdraw", linkBalance);
    }

    function _mockPriceFeedPrice(address priceFeed, uint256 spot) private {
        uint80 roundId;
        int256 answer = int256(spot * 1e2);
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;

        vm.mockCall(
            priceFeed,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );
    }
}
