// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {InvariantFactory} from "../src/InvariantFactory.sol";
import {InvariantPair} from "../src/InvariantPair.sol";
import {InvariantLibrary} from "../src/InvariantLibrary.sol";
import {ERC20Mock} from "./Mock/ERC20Mock.sol";
import {DeployAMM} from "../script/DeployAMM.s.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// helper for exposing internal library functions via inheritance
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

contract ReentrantToken is ERC20 {
    InvariantPair public pair;

    constructor(address _pair) ERC20("Reentrant", "RE") {
        pair = InvariantPair(_pair);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        // reenter the pair while it's in the middle of a call
        // amount arguments can be arbitrary; we just want the lock to trigger
        pair.addLiquidity(1 ether, 1 ether);
        _transfer(from, to, value);
        return true;
    }
}

contract PairTest is Test {
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
            address libraryAddr,
            ,
            address token1Addr,
            address token2Addr
        ) = deployer.run();
        factory = InvariantFactory(factoryAddr);
        token0 = ERC20Mock(token1Addr);
        token1 = ERC20Mock(token2Addr);
        pair = InvariantPair(pairAddr);
        lib = InvariantLibrary(libraryAddr);
        helper = new LibraryHelper();

        (address _token0, address _token1) = pair.getAssets();
        token0 = ERC20Mock(_token0);
        token1 = ERC20Mock(_token1);

        // Fund user with tokens
        token0.mint(user, 1000 ether);
        token1.mint(user, 1000 ether);

        token0.mint(lp, 1000 ether);
        token1.mint(lp, 1000 ether);
    }

    function testInitialize() public view {
        // Verify that the pair was initialized with the correct tokens
        (address asset0, address asset1) = pair.getAssets();
        assertEq(asset0, address(token0));
        assertEq(asset1, address(token1));
    }

    function testAddLiquidity() public {
        // user approves pair to take tokens
        vm.startPrank(lp);
        token0.approve(address(pair), 500 ether);
        token1.approve(address(pair), 300 ether);
        pair.addLiquidity(500 ether, 300 ether);
        vm.stopPrank();

        // reserves should reflect the deposited amounts
        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r0, 500 ether);
        assertEq(r1, 300 ether);

        // contract balance should also match
        assertEq(token0.balanceOf(address(pair)), 500 ether);
        assertEq(token1.balanceOf(address(pair)), 300 ether);
    }

    function testAddLiquidityOneSided() public {
        vm.startPrank(lp);
        token0.approve(address(pair), 200 ether);
        pair.addLiquidity(200 ether, 0);
        vm.stopPrank();

        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r0, 200 ether);
        assertEq(r1, 0);
    }

    function testSwapToken2ForToken1() public {
        // 1. Liquidity hinzufügen
        vm.startPrank(lp);
        token0.approve(address(pair), 1000 ether);
        token1.approve(address(pair), 1000 ether);
        pair.addLiquidity(1000 ether, 1000 ether);
        vm.stopPrank();

        // 2. Swap: token2 rein → token1 raus
        vm.startPrank(user);
        token1.mint(user, 200 ether);

        token1.transfer(address(pair), 200 ether); // Input-Token an Pair senden

        uint256 beforeBalance = token0.balanceOf(user);
        uint256 expectedOut = helper.getAmountOutExt(
            200 ether,
            1000 ether,
            1000 ether
        ); // ~166 ether

        pair.swap(expectedOut, 0, user); // token1 raus (amount0Out), token2 bleibt (amount1Out=0)
        vm.stopPrank();

        // 3. User hat token1 erhalten
        assertApproxEqAbs(
            token0.balanceOf(user),
            beforeBalance + expectedOut,
            1
        );

        // 4. Reserves: token2 gestiegen, token1 gesunken
        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r1, 1200 ether); // token2: 1000 + 200 rein
        assertApproxEqAbs(r0, 1000 ether - expectedOut, 1); // token1: 1000 - raus
    }

    function testSwapRevertsWhenNotEnoughLiquidity() public {
        vm.startPrank(user);
        token0.approve(address(pair), 500 ether);
        token1.approve(address(pair), 500 ether);
        pair.addLiquidity(500 ether, 500 ether);
        vm.expectRevert("InvariantPair: NOT_ENOUGH_LIQUIDITY_ERROR");
        pair.swap(600 ether, 0, user);
        vm.stopPrank();
    }

    function testSwapRevertsOnKInvariantViolation() public {
        // set up a small liquidity pool
        vm.startPrank(user);
        token0.approve(address(pair), 1000 ether);
        token1.approve(address(pair), 1000 ether);
        pair.addLiquidity(1000 ether, 1000 ether);
        // mint a tiny amount so we can attempt the transfer
        token1.mint(user, 1 ether);
        // provide too little token2 input
        token1.transfer(address(pair), 1 ether);
        vm.expectRevert("InvariantAMM: K_INVARIANT_ERROR");
        pair.swap(0, 100 ether, user);
        vm.stopPrank();
    }

    function testReentrancyGuardPreventsDoubleEntry() public {
        // deploy fresh pair and malicious tokens
        ReentrantToken rt0 = new ReentrantToken(address(0));
        ReentrantToken rt1 = new ReentrantToken(address(0));
        InvariantPair p = new InvariantPair();
        // set token addresses
        rt0 = new ReentrantToken(address(p));
        rt1 = new ReentrantToken(address(p));
        p.initialize(address(rt0), address(rt1));

        // mint funds to user
        rt0.mint(user, 1000 ether);
        rt1.mint(user, 1000 ether);

        vm.startPrank(user);
        rt0.approve(address(p), 100 ether);
        rt1.approve(address(p), 100 ether);
        // first call will attempt reentry during transferFrom
        vm.expectRevert("InvariantPair: LOCKED");
        p.addLiquidity(50 ether, 50 ether);
        vm.stopPrank();
    }
}
