//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";

contract InvariantPair {
    address public factory;
    address public token0;
    address public token1;

    uint256 public reserve0;
    uint256 public reserve1;

    bool private initialized;

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(
            msg.sender == factory,
            "InvariantPair: CALLER_NOT_FACTORY_ERROR"
        );
        require(!initialized, "InvariantPair: ALREADY_INITIALIZED_ERROR");
        token0 = _token0;
        token1 = _token1;
        initialized = true;
    }

    function getReserves()
        internal
        view
        returns (uint256 _reserve0, uint256 _reserve1)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function _transfer(
        address token,
        address recipient,
        uint256 amount
    ) internal {
        bool success = IERC20(token).transfer(recipient, amount);
        require(success, "Transfer failed");
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external {}

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
        require(
            amount0Out > 0 || amount1Out > 0,
            "InvariantPair: INSUFFICIENT_OUTPUT_AMOUNT_ERROR"
        );
        (uint256 reserve0, uint256 reserve1) = getReserves();
        require(
            amount0Out < reserve0 && amount1Out < reserve1,
            "InvariantPair: NOT_ENOUGH_LIQUIDITY_ERROR"
        );

        // Optimistically transfer wanted output
        if (amount0Out > 0) _transfer(token0, to, amount0Out);
        if (amount1Out > 0) _transfer(token1, to, amount1Out);

        uint256 _balance0 = IERC20(token0).balanceOf(address(this));
        uint256 _balance1 = IERC20(token1).balanceOf(address(this));

        // dx = (dy * x0) / (y0 - dy)
        // dx...expected input; dy...amountOut; x0...reserve of input token; y0...reserve of output token
        uint256 amount0InExpected = (amount0Out * reserve0) / (reserve1 - amount0Out);
        uint256 amount1InExpected = (amount1Out * reserve1) / (reserve0 - amount1Out);
        require(amount0InExpected > 0 || amount1InExpected > 0, "InvariantAMM: INSUFFICIENT_INPUT_ERROR");

        // now we have to check if amounIn is including the fees: balance * 1000 - input * 3 > reserve0 * reserve1 * 1000^2 
        uint256 balance0Adjusted = (_balance0 * 1000) - (amount0InExpected * 3);
        uint256 balance1Adjusted = (_balance1 * 1000) - (amount1InExpected * 3);
        require(balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * (1000**2), "InvariantAMM: K_INVARIANT_ERROR");

        _update(_balance0, _balance1);
        emit Swap(msg.sender, amount0InExpected, amount1InExpected, amount0Out, amount1Out, to);

    }

    function _update(uint256 balance0, uint256 balance1) internal {
        reserve0 = balance0;
        reserve1 = balance1;
    }
}
