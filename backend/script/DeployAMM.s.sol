// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {InvariantPair} from "../src/InvariantPair.sol";
import {InvariantFactory} from "../src/InvariantFactory.sol";
import {InvariantLibrary} from "../src/InvariantLibrary.sol";
import {InvariantRouter } from "../src/InvariantRouter.sol";
import {ERC20Mock} from "../test/Mock/ERC20Mock.sol";
import {DeployTokenPair} from "./DeployTokenPair.s.sol";

contract DeployAMM is Script {
    DeployTokenPair tokenDeployer;

    function run()
        external
        returns (
            address pair,
            address factory,
            address routerAddr,
            address libraryAddr,
            address token1,
            address token2
        )
    {
        tokenDeployer = new DeployTokenPair();

        vm.startBroadcast();
        // 1. Deploy Factory
        factory = address(new InvariantFactory());
        console.log("Factory deployed to ", address(factory));

        // 2. Deploy Library
        libraryAddr = address(new InvariantLibrary());
        console.log("Library deployed to ", address(libraryAddr));

        routerAddr = address(new InvariantRouter(factory, libraryAddr));
        console.log("Router deployed to ", address(routerAddr));

        // 2. Deploy Tokens
        (ERC20Mock token1, ERC20Mock token2) = tokenDeployer.run();
        console.log("Mock Token1 deployed to ", address(token1));
        console.log("Mock Token2 deployed to ", address(token2));

        // 3. Deploy Pair
        pair = InvariantFactory(factory).createPair(
            address(token1),
            address(token2)
        );
        console.log("Pair deployed to ", pair);

        vm.stopBroadcast();

        return (pair, factory, routerAddr, libraryAddr, address(token1), address(token2));
    }
}
