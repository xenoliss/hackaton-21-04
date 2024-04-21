// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {ERC20WithMinters} from "src/ERC20WithMinters.sol";
import {StrategyFactory} from "src/StrategyFactory.sol";
import {AMM} from "src/AMM.sol";

contract DeploymentScript is Script {
    function run() public {
        vm.startBroadcast();

        // 1. Deploy the mocked tokens.
        ERC20WithMinters usdc = _deployToken({name: "USDC", symbol: "USDC", decimals: 6});
        ERC20WithMinters weth = _deployToken({name: "WETH", symbol: "WETH", decimals: 18});
        ERC20WithMinters wbtc = _deployToken({name: "WBTC", symbol: "WBTC", decimals: 8});
        ERC20WithMinters link = _deployToken({name: "LINK", symbol: "LINK", decimals: 18});

        console.log("Mocked USDC deployed at", address(usdc));
        console.log("Mocked WETH deployed at", address(weth));
        console.log("Mocked WBTC deployed at", address(wbtc));
        console.log("Mocked LINK deployed at", address(link));

        // 2. Deploy the mocked AMM.
        address[] memory underlyings = new address[](3);
        underlyings[0] = address(weth);
        underlyings[1] = address(wbtc);
        underlyings[2] = address(link);

        // See here for price feed addresses: https://docs.chain.link/data-feeds/price-feeds/addresses?network=base&page=1#base-sepolia-testnet
        address[] memory priceFeeds = new address[](3);
        priceFeeds[0] = address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
        priceFeeds[1] = address(0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298);
        priceFeeds[2] = address(0xb113F5A928BCfF189C998ab20d753a47F9dE5A61);

        AMM amm = _deployAMM({usdc: address(usdc), tokens: underlyings, priceFeeds: priceFeeds});
        console.log("Mocked AMM deployed at", address(amm));

        // 3. Deploy the strategy factory.
        StrategyFactory factory = _deployStrategyFactory({usdc: address(usdc), amm: amm});
        console.log("Strategy factory deployed at", address(factory));

        // 4. Deploy a strategy.
        uint16[] memory weights = new uint16[](3);
        weights[0] = 50_00;
        weights[1] = 25_00;
        weights[2] = 25_00;
        address[] memory investors;
        address strategy = factory.deployNewStrategy({
            tokens: underlyings,
            weights: weights,
            rebalanceInterval: 60,
            isOpen: true,
            investors: investors,
            name: "50/25/25 WETH/WBTC/LINK",
            symbol: "50/25/25 WETH/WBTC/LINK"
        });

        console.log("Strategy deployed at", address(strategy));

        vm.stopBroadcast();
    }

    function _deployAMM(address usdc, address[] memory tokens, address[] memory priceFeeds) private returns (AMM) {
        AMM amm = new AMM(usdc);

        for (uint256 i; i < tokens.length; i++) {
            amm.setPriceFeed({token: tokens[i], priceFeed: priceFeeds[i]});
        }

        return amm;
    }

    function _deployStrategyFactory(address usdc, AMM amm) private returns (StrategyFactory) {
        StrategyFactory factory = new StrategyFactory({usdc_: usdc, amm_: amm});
        return factory;
    }

    function _deployToken(string memory name, string memory symbol, uint8 decimals)
        private
        returns (ERC20WithMinters)
    {
        ERC20WithMinters token = new ERC20WithMinters({name_: name, symbol_: symbol, decimals_: decimals});
        return token;
    }
}
