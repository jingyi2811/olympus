// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../libraries/Balancer/interfaces/IWeightedPool.sol";
import "../../Balancer.sol";

contract BalancerTest is Test {
    Balancer balancer;

    function setUp() public {
        // Deploy the Balancer contract or set it up as needed
        balancer = new Balancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    }

    function testBalancerPoolBalance() public {
        bytes32 addr = 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014;

        // Balancer 80%, Weth 20%
        (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balancer.getPoolBalance(addr);

        assertEq(tokens.length, 2);
        assertEq(address(tokens[0]), 0xba100000625a3754423978a60c9317c58a424e3D); // BAL
        assertEq(address(tokens[1]), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // IWETH

        console.log(balances[0]);
        console.log(balances[1]);

        console.log(lastChangeBlock);

        IWeightedPool pool = IWeightedPool(address(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56));

        // Get pool ID
        uint[] memory x = pool.getNormalizedWeights();
        console.log(x.length);
        console.log(x[0]);
        console.log(x[1]);

        console.log(pool.getInvariant());
        console.log(pool.totalSupply());
        console.logBytes32(pool.getPoolId());
        console.log(pool.decimals());
    }

    function testBalancerStablePoolBalance() public {
        bytes32 addr = 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2;

        // Balancer 80%, Weth 20%
        (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balancer.getPoolBalance(addr);

        console.log(tokens.length); // 3
        console.log(address(tokens[0])); // WsETH
        console.log(address(tokens[1]));
        console.log(address(tokens[2]));

//        assertEq(address(tokens[0]), 0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0); // WsETH
//        assertEq(address(tokens[1]), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // IWETH

//        console.log(balances[0]);
//        console.log(balances[1]);
//
//        console.log(lastChangeBlock);
//
//        IWeightedPool pool = IWeightedPool(address(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56));
//
//        // Get pool ID
//        uint[] memory x = pool.getNormalizedWeights();
//        console.log(x.length);
//        console.log(x[0]);
//        console.log(x[1]);
//
//        console.log(pool.getInvariant());
//        console.log(pool.totalSupply());
//        console.logBytes32(pool.getPoolId());
//        console.log(pool.decimals());
    }
}