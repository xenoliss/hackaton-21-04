// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {ERC20WithMinters} from "src/ERC20WithMinters.sol";
import {StrategyFactory} from "src/StrategyFactory.sol";
import {AMM} from "src/AMM.sol";

contract DeploymentScript is Script {
    function run() public {
        // 1. Deploy the mocked tokens.
        ERC20WithMinters usdc = _deployToken({name: "USDC", symbol: "USDC", decimals: 6});
        ERC20WithMinters weth = _deployToken({name: "WETH", symbol: "WETH", decimals: 18});
        ERC20WithMinters wbtc = _deployToken({name: "WBTC", symbol: "WBTC", decimals: 8});

        console.log("Mocked USDC deployed at", address(usdc));
        console.log("Mocked WETH deployed at", address(weth));
        console.log("Mocked WBTC deployed at", address(wbtc));

        // 2. Deploy the mocked AMM.
        address[] memory underlyings = new address[](2);
        underlyings[0] = address(weth);
        underlyings[1] = address(wbtc);

        // See here for price feed addresses: https://docs.chain.link/data-feeds/price-feeds/addresses?network=base&page=1#base-sepolia-testnet
        address[] memory priceFeeds = new address[](2);
        priceFeeds[0] = address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
        priceFeeds[1] = address(0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298);

        AMM amm = _deployAMM({tokens: underlyings, priceFeeds: priceFeeds});
        console.log("Mocked AMM deployed at", address(amm));

        // 3. Register the AMM as an allowed minter of the tokens.
        usdc.setCanMint({minter: address(amm), value: true});
        weth.setCanMint({minter: address(amm), value: true});
        wbtc.setCanMint({minter: address(amm), value: true});

        // 4. Deploy the strategy factory.
        StrategyFactory factory = _deployStrategyFactory({usdc: address(usdc), amm: amm});
        console.log("Strategy factory deployed at", address(factory));

        // 5. Deploy a strategy.
        uint16[] memory weights = new uint16[](2);
        weights[0] = 50_00;
        weights[1] = 50_00;
        address[] memory investors;
        address strategy = factory.deployNewStrategy({
            tokens: underlyings,
            weights: weights,
            rebalanceInterval: 1 days,
            isOpen: true,
            investors: investors,
            name: "50/50 WETH WBTC",
            symbol: "50/50 WETH WBTC"
        });

        console.log("Strategy deployed at", address(strategy));
    }

    function _deployAMM(address[] memory tokens, address[] memory priceFeeds) private returns (AMM) {
        AMM amm = new AMM();

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
