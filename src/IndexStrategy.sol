// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";

import {AMM} from "./AMM.sol";

contract IndexStrategy is ERC20 {
    /// @notice The strategy tokens.
    address[] public tokens;

    /// @notice The strategy token weights.
    uint16[] public weights;

    /// @notice The rebalancing interval in seconds.
    uint256 public immutable rebalanceInterval;

    /// @notice Whether the strategy is open to public or restricted to a whitelist.
    bool public immutable isOpen;

    /// @notice The investors whitelist allow to use this strategy.
    mapping(address investor => bool canInvest) public investors;

    /// @notice The USDC address.
    address public immutable usdc;

    /// @notice The AMM address used to swap tokens and compute their market price.
    AMM public immutable amm;

    /// @dev The strategy name.
    string private _name;

    /// @dev The strategy symbol.
    string private _symbol;

    /// @notice The last timestamp when the rebalance happened.
    uint256 public lastRebalanceTimestamp;

    constructor(
        address[] memory tokens_,
        uint16[] memory weights_,
        uint256 rebalanceInterval_,
        bool isOpen_,
        address[] memory investors_,
        address usdc_,
        AMM amm_,
        string memory name_,
        string memory symbol_
    ) {
        require(tokens.length == weights.length, "Array length missmatch");

        // Ensure weights sum up to 100%.
        _verifyWeigths(weights_);

        // Register tokens and weights.
        tokens = tokens_;
        weights = weights_;
        rebalanceInterval = rebalanceInterval_;
        lastRebalanceTimestamp = block.timestamp;

        // Either set the strategy publicly opened or else register the whiteliseted investors.
        if (isOpen_) {
            require(investors_.length == 0);
            isOpen = isOpen_;
        } else {
            require(investors_.length > 0);
            _initializeInvestors(investors_);
        }

        usdc = usdc_;
        amm = amm_;

        // Set the ERC20 name and symbol.
        _name = name_;
        _symbol = symbol_;
    }

    /// @notice Deposit USDC into the strategy.
    ///
    /// @dev Mint shares to the depositor:
    ///         - 1 to 1 ratio for 1st depositor
    ///         - pro rata of the current vault USDC value for later depositors
    ///
    /// @param usdcAmountIn The USDC amount to deposit.
    function deposit(uint256 usdcAmountIn) external {
        require(isOpen || investors[msg.sender], "Sender can not invest");

        // Transfer the USDC from the sender to the Strategy contract.
        ERC20(usdc).transferFrom({from: msg.sender, to: address(this), amount: usdcAmountIn});

        // Loop over all tokens and swap them according to their weight.
        // NOTE: Due to precision issue do not swap the very last token.
        uint256 swappedAmount;
        uint256 l = weights.length;
        for (uint256 i; i < l - 1; i++) {
            uint256 amountIn = (usdcAmountIn * weights[i]) / 100_00;
            swappedAmount += amountIn;

            ERC20(usdc).transfer({to: address(amm), amount: amountIn});
            amm.swap({tokenIn: usdc, tokenOut: tokens[i], receiver: address(this)});
        }

        // Handle the very last token swap using what's left in USDC as amount in.
        uint256 lastAmountIn = usdcAmountIn - swappedAmount;
        ERC20(usdc).transfer({to: address(amm), amount: lastAmountIn});
        amm.swap({tokenIn: usdc, tokenOut: tokens[l - 1], receiver: address(this)});

        // Mint shares.
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            _mint({to: msg.sender, amount: usdcAmountIn});
        } else {
            (, uint256 totalUsdcValue) = _usdcValues();
            uint256 percent = usdcAmountIn * 1e18 / totalUsdcValue;
            uint256 toMint = percent * totalSupply_ / 1e18;
            _mint({to: msg.sender, amount: toMint});
        }
    }

    /// @notice Withdraw funds from the strategy.
    ///
    /// @dev Shares are burned and the equivalent amount of funds is returned to the sender
    ///      in USDC after selling them on a DEX.
    ///
    /// @param sharesAmountIn The amount of shares to exit.
    function withdraw(uint256 sharesAmountIn) external {
        uint256 percent = sharesAmountIn * 1e18 / totalSupply();
        _burn({from: msg.sender, amount: sharesAmountIn});

        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amountIn = percent * ERC20(token).balanceOf(address(this)) / 1e18;

            ERC20(token).transfer({to: address(amm), amount: amountIn});
            amm.swap({tokenIn: token, tokenOut: usdc, receiver: msg.sender});
        }
    }

    /// @notice Rebalance the vault based on the targeted token weights.
    ///
    /// @dev Reverts if the rebalancing interval is too short.
    function rebalance() external {
        uint256 elapsedTime = block.timestamp - lastRebalanceTimestamp;
        require(elapsedTime >= rebalanceInterval, "Can't rebalance now");
        lastRebalanceTimestamp = block.timestamp;

        // TODO: Smarter algo to only buy/sell the difference.

        uint256 tokensCount = tokens.length;

        // Dump all tokens for USDC.
        for (uint256 i; i < tokensCount; i++) {
            address token = tokens[i];

            ERC20(token).transfer({to: address(amm), amount: ERC20(token).balanceOf(address(this))});
            amm.swap({tokenIn: token, tokenOut: usdc, receiver: address(this)});
        }

        uint256 usdcBalance = ERC20(usdc).balanceOf(address(this));
        uint256 swappedAmount;

        // Rebuy all tokens.
        for (uint256 i; i < tokensCount - 1; i++) {
            uint256 amountIn = (usdcBalance * weights[i]) / 100_00;
            swappedAmount += amountIn;

            ERC20(usdc).transfer({to: address(amm), amount: amountIn});
            amm.swap({tokenIn: usdc, tokenOut: tokens[i], receiver: address(this)});
        }

        // Handle the very last token swap using what's left in USDC as amount in.
        uint256 lastAmountIn = usdcBalance - swappedAmount;
        ERC20(usdc).transfer({to: address(amm), amount: lastAmountIn});
        amm.swap({tokenIn: usdc, tokenOut: tokens[tokensCount - 1], receiver: address(this)});
    }

    /// @inheritdoc ERC20
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @inheritdoc ERC20
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc ERC20
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /// @notice Ensure the token weights sum up to 100%.
    ///
    /// @dev Reverts if the sum is not 100%.
    ///
    /// @param weights_ The token weights.
    function _verifyWeigths(uint16[] memory weights_) private pure {
        uint16 acc;
        for (uint256 i; i < weights_.length; i++) {
            acc += weights_[i];
        }

        require(acc == 100_00);
    }

    /// @notice Register the whitelisted investors list.
    ///
    /// @param investors_ The investors whitelist allow to use this strategy.
    function _initializeInvestors(address[] memory investors_) private {
        for (uint256 i; i < investors_.length; i++) {
            investors[investors_[i]] = true;
        }
    }

    /// @notice Compute the vault usdc values.
    ///
    /// @return usdcValues The individual USDC value per token (in order).
    /// @return totalUsdcValue The total vault USDC value.
    function _usdcValues() private view returns (uint256[] memory usdcValues, uint256 totalUsdcValue) {
        usdcValues = new uint256[](tokens.length);

        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 usdcValue =
                amm.getAmountOut({tokenIn: token, tokenOut: usdc, amountIn: ERC20(token).balanceOf(address(this))});
            usdcValues[i] = usdcValue;
            totalUsdcValue += usdcValue;
        }
    }
}
