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
        if (amount0Out > 1) _transfer(token1, to, amount1Out);

        uint256 _balance0 = IERC20(token0).balanceOf(address(this));
        uint256 _balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In =
    }

    function _update(uint256 balance0, uint256 balance1) internal {}
}
