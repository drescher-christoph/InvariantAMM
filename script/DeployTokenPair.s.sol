// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import { ERC20Mock } from "../test/Mock/ERC20Mock.sol";

contract DeployTokenPair is Script {
    function run() external returns (ERC20Mock token1, ERC20Mock token2) {
        token1 = new ERC20Mock(
            "CrazyAxie",
            "CAX",
            msg.sender,
            1_000_000_000 ether
        );
        token2 = new ERC20Mock(
            "InvariantUSD",
            "IUSD",
            msg.sender,
            1_000_000_000 ether
        );
        
    }
}
