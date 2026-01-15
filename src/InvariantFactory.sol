//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InvariantPair} from "./InvariantPair.sol";

contract InvariantFactory {

    // asset0 => asset1 => pair
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event InvariantFactory__PairCreated(address indexed pair, address indexed asset0, address indexed asset1, uint256);

    constructor() {}

    function createPair(address assetA, address assetB) external returns (address pair) {
        require(assetA != assetB, "InvariantFactory: IDENTICAL_ADDRESSES_ERROR");
        (address asset0, address asset1) = assetA < assetB ? (assetB, assetA) : (assetA, assetB);
        require(asset0 != address(0), "InvariantFactory: ZERO_ADDRESS_ERROR");
        require(getPair[asset0][asset1] == address(0), "InvariantFactory: PAIR_ALREADY_EXISTS_ERROR");
        bytes memory bytecode = type(InvariantPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(asset0, asset1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        InvariantPair(pair).initialize(asset0, asset1);
        getPair[asset0][asset1] = pair;
        getPair[asset1][asset0] = pair; // populate reverse mapping
        allPairs.push(pair);
        // pair = address(new InvariantPair(asset0, assetB));
        // getPair[asset0][asset1] = pair;
        // getPair[asset1][asset0] = pair; // populate reverse mapping
        // allPairs.push(pair);

        emit InvariantFactory__PairCreated(pair, asset0, asset1, allPairs.length);

    }

    function allPairsLength() external view returns (uint256 length) {
        return allPairs.length;
    }

}