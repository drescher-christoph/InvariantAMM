//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { InvariantFactory } from "./InvariantFactory.sol";
import { InvariantPair } from "./InvariantPair.sol";
import { InvariantLibrary } from "./InvariantLibrary.sol";

contract InvariantRouter {

    address public factory;
    address public lib;

    constructor(address _factory, address _library) {
        factory = _factory;
        lib = _library;
    }

    // DAI -> USDC -> WETH
    // path = [DAI, USDC, WETH]
    // amounts = [amountIn, amountOut1, amountOut2]
    function _swap(uint256[] memory amounts, address[] memory path, address to) internal {
        for (uint i = 0; i < path.length -1; i++) {
            address input = path[i];
            address output = path[i + 1];
            // making sure the logic: inuput = token0 and output = token1 is fulfilled
            (address token0,) = InvariantLibrary(lib).sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            // Defining pair contract address from factory
            address pair = InvariantFactory(factory).getPair(input, output);
            require(pair != address(0), "InvariantRouter: PAIR_NOT_FOUND_ERROR");

            // If this is not the last swap, the recipient is the next pair, otherwise it is the final recipient
            address recipient;
            if (i < path.length - 2) {
                recipient = pair;
            } else {
                recipient = to;
            }

            InvariantPair(pair).swap(amount0Out, amount1Out, recipient);
            
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to
    ) public {
        uint256[] memory amounts = InvariantLibrary(lib).getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "InvariantRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] memory path,
        address to
    ) public {
        uint256[] memory amounts = InvariantLibrary(lib).getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "InvariantRouter: EXCESSIVE_INPUT_AMOUNT");
        _swap(amounts, path, to);
    }
}
