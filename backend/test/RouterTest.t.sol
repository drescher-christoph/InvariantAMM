// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {InvariantRouter} from "../src/InvariantRouter.sol";
import {InvariantFactory} from "../src/InvariantFactory.sol";
import {InvariantLibrary} from "../src/InvariantLibrary.sol";
import {ERC20Mock} from "./Mock/ERC20Mock.sol";
import {DeployAMM} from "../script/DeployAMM.s.sol";
import {InvariantPair} from "../src/InvariantPair.sol";

contract RouterTest is Test {
    InvariantFactory factory;
    InvariantLibrary lib;
    InvariantRouter router;
    InvariantPair pair;
    ERC20Mock token1;
    ERC20Mock token2;

    address user = makeAddr("USER1");
    address lp = makeAddr("LP");

    modifier liquidityProvided() {
        vm.startPrank(lp);
        token1.approve(address(pair), 1000 ether);
        token2.approve(address(pair), 1000 ether);
        pair.addLiquidity(1000 ether, 1000 ether);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        DeployAMM deployer = new DeployAMM();
        (
            address pairAddr,
            address factoryAddr,
            address routerAddr,
            address libraryAddr,
            address token1Addr,
            address token2Addr
        ) = deployer.run();
        factory = InvariantFactory(factoryAddr);
        token1 = ERC20Mock(token1Addr);
        token2 = ERC20Mock(token2Addr);
        pair = InvariantPair(pairAddr);
        lib = InvariantLibrary(libraryAddr);
        router = InvariantRouter(routerAddr);

        // Fund user with tokens
        token1.mint(user, 1000 ether);

        token1.mint(lp, 1000 ether);
        token2.mint(lp, 1000 ether);
    }

    function testSwapExactTokensForTokens() public liquidityProvided {
        vm.startPrank(user);
        token1.approve(address(router), 100 ether);
        console.log("User approved router to spend 100 token1");

        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);

        router.swapExactTokensForTokens(100 ether, 90 ether, path, user);

        uint256 userBalanceToken2 = token2.balanceOf(user);

        assertGt(userBalanceToken2, 90 ether);
        assertApproxEqAbs(userBalanceToken2, 90.66 ether, 0.01 ether);
    }

    function testSwapTokensForExactTokens() public liquidityProvided {
        vm.startPrank(user);

        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);

        // 1. Benötigten Input ZUERST berechnen
        uint256[] memory amounts = lib.getAmountsIn(
            address(factory),
            100 ether,
            path
        );
        uint256 requiredAmountIn = amounts[0]; // ≈ 111.45 ether

        // 2. Approval basierend auf tatsächlich benötigtem Betrag
        token1.approve(address(router), requiredAmountIn);

        uint256 token1Before = token1.balanceOf(user);

        // 3. Swap mit realistischem amountInMax (z.B. 5% Slippage-Toleranz)
        router.swapTokensForExactTokens(
            100 ether, // exakt 100 token2 raus
            (requiredAmountIn * 105) / 100, // max 5% mehr als berechnet
            path,
            user
        );

        uint256 token1After = token1.balanceOf(user);

        // 4. Assertions
        // Exakt 100 token2 erhalten
        assertApproxEqAbs(token2.balanceOf(user), 100 ether, 0.01 ether);
        // Nicht mehr als amountInMax ausgegeben
        assertLe(token1Before - token1After, (requiredAmountIn * 105) / 100);
        // Tatsächlicher Input nahe an berechnetem Wert
        assertApproxEqAbs(
            token1Before - token1After,
            requiredAmountIn,
            0.01 ether
        );

        vm.stopPrank();
    }
}
