// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {InvariantFactory} from "../src/InvariantFactory.sol";
import {InvariantPair} from "../src/InvariantPair.sol";
import {InvariantLibrary} from "../src/InvariantLibrary.sol";
import {ERC20Mock} from "./Mock/ERC20Mock.sol";
import {DeployAMM} from "../script/DeployAMM.s.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// helper contract inherits the library to expose internal helpers without
// modifying the original contract. Tests can deploy this and call wrapper
// functions.
contract LibraryHelper is InvariantLibrary {
    function getAmountOutExt(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256) {
        return getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountInExt(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256) {
        return getAmountIn(amountOut, reserveIn, reserveOut);
    }
}

contract LibraryTest is Test {
    InvariantFactory factory;
    InvariantLibrary lib;
    LibraryHelper helper;
    InvariantPair pair;
    ERC20Mock token0;
    ERC20Mock token1;

    address user = makeAddr("USER1");
    address lp = makeAddr("LP");

    function setUp() public {
        DeployAMM deployer = new DeployAMM();
        (
            address pairAddr,
            address factoryAddr,
            ,
            address libraryAddr,
            address token1Addr,
            address token2Addr
        ) = deployer.run();
        factory = InvariantFactory(factoryAddr);
        pair = InvariantPair(pairAddr);
        lib = InvariantLibrary(libraryAddr);
        helper = new LibraryHelper();

        (address _token0, address _token1) = pair.getAssets();
        token0 = ERC20Mock(_token0);
        token1 = ERC20Mock(_token1);

        // Fund user with tokens
        token0.mint(user, 1000 ether);
        token1.mint(user, 1000 ether);

        token0.mint(lp, 10000 ether);
        token1.mint(lp, 10000 ether);
    }

    function testGetAmountOut() public {
        uint256 amountOut = helper.getAmountOutExt(
            100 ether,
            1000 ether,
            1000 ether
        );
        assertApproxEqAbs(amountOut, 90.66 ether, 0.01 ether);
    }

    function testGetAmountIn() public {
        uint256 amountIn = helper.getAmountInExt(
            90 ether,
            1000 ether,
            1000 ether
        );
        assertGt(amountIn, 99 ether);
    }

    function testGetAmountsOut() public {
        vm.startPrank(lp);
        token0.approve(address(pair), 1000 ether);
        token1.approve(address(pair), 1000 ether);
        pair.addLiquidity(1000 ether, 1000 ether);
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        uint256[] memory amountsOut = lib.getAmountsOut(
            address(factory),
            100 ether,
            path
        );
        assertApproxEqAbs(amountsOut[1], 90.66 ether, 0.01 ether);
    }

    function testGetAmountsIn() public {
        vm.startPrank(lp);
        token0.approve(address(pair), 1000 ether);
        token1.approve(address(pair), 1000 ether);
        pair.addLiquidity(1000 ether, 1000 ether);
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        uint256[] memory amountsIn = lib.getAmountsIn(
            address(factory),
            100 ether,
            path
        );
        assertApproxEqAbs(amountsIn[0], 111.445 ether, 0.01 ether);
    }

    function testGetAmountsOut_UnequalReserves_ExposesSwappedReserveBug()
        public
    {
        // Absichtlich ungleiche Reserves → bei vertauschten Reserves
        // kommt ein komplett anderes Ergebnis raus
        vm.startPrank(lp);
        token0.approve(address(pair), 500 ether);
        token1.approve(address(pair), 2000 ether);
        pair.addLiquidity(500 ether, 2000 ether);
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        // Erwartung: 100 token1 rein, token1-Reserve=500, token2-Reserve=2000
        // amountInWithFee = 100e18 * 997 = 99700e18
        // amountOut = (99700e18 * 2000e18) / (500e18 * 1000 + 99700e18) ≈ 332.49 ether
        //
        // Buggy Ergebnis (Reserves vertauscht): reserveIn=2000, reserveOut=500
        // amountOut = (99700e18 * 500e18) / (2000e18 * 1000 + 99700e18) ≈ 23.72 ether
        // → Fehler wäre ~308 ether Abweichung, klar sichtbar

        uint256[] memory amounts = lib.getAmountsOut(
            address(factory),
            100 ether,
            path
        );

        assertApproxEqAbs(amounts[1], 332.49 ether, 0.01 ether);
    }

    function testGetAmountsIn_UnequalReserves_ExposesSwappedReserveBug()
        public
    {
        vm.startPrank(lp);
        token0.approve(address(pair), 500 ether);
        token1.approve(address(pair), 2000 ether);
        pair.addLiquidity(500 ether, 2000 ether);
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        // Erwartung: 100 token2 raus, token1-Reserve=500, token2-Reserve=2000
        // amountIn = (100e18 * 500e18 * 1000) / ((2000e18 - 100e18) * 997) + 1 ≈ 26.40 ether
        //
        // Buggy Ergebnis (Reserves vertauscht): reserveIn=2000, reserveOut=500
        // amountIn = (100e18 * 2000e18 * 1000) / ((500e18 - 100e18) * 997) + 1 ≈ 501.5 ether
        // → Fehler wäre ~475 ether Abweichung, klar sichtbar

        uint256[] memory amounts = lib.getAmountsIn(
            address(factory),
            100 ether,
            path
        );

        assertApproxEqAbs(amounts[0], 26.40 ether, 0.01 ether);
    }
}
