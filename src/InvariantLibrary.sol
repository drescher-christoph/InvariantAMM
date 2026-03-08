// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InvariantPair} from "./InvariantPair.sol";
import {InvariantFactory} from "./InvariantFactory.sol";

contract InvariantLibrary {
    constructor() {}

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "InvariantLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "InvariantLibrary: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) external view returns (uint256[] memory amounts) {
        require(path.length >= 2, "InvariantLibrary: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            address tokenIn = path[i];
            address tokenOut = path[i + 1];
            address pairAddr = InvariantFactory(factory).getPair(tokenIn, tokenOut);

            (address _token0, ) = InvariantPair(pairAddr).getAssets();
            (uint256 reserve0, uint256 reserve1) = InvariantPair(pairAddr)
                .getReserves();

            (uint256 reserveIn, uint256 reserveOut) = tokenIn == _token0
                ? (reserve0, reserve1)
                : (reserve1, reserve0);

            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "InvariantLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "InvariantLibrary_ INSUFFICIENT_LIQUIDTY"
        );
        uint256 numerator = (amountOut * reserveIn) * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1; // +1 because soldity rounds down
    }

    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) external view returns (uint256[] memory amounts) {
        require(path.length >= 2, "InvariantLibrary: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            address tokenIn = path[i - 1];
            address tokenOut = path[i];

            address pairAddr = InvariantFactory(factory).getPair(
                tokenIn,
                tokenOut
            );
            (address _token0, ) = InvariantPair(pairAddr).getAssets();
            (uint256 reserve0, uint256 reserve1) = InvariantPair(pairAddr)
                .getReserves();

            (uint256 reserveIn, uint256 reserveOut) = tokenIn == _token0
                ? (reserve0, reserve1)
                : (reserve1, reserve0);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    function sortTokens(
        address token0,
        address token1
    ) external pure returns (address sortedToken0, address sortedToken1) {
        require(
            token0 != token1,
            "InvariantLibrary: IDENTICAL_ADDRESSES_ERROR"
        );
        (sortedToken0, sortedToken1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);
        require(
            sortedToken0 != address(0),
            "InvariantLibrary: ZERO_ADDRESS_ERROR"
        );
    }
}
