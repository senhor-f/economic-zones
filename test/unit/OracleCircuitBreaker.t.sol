// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OracleCircuitBreaker, IAggregatorV3} from "../../src/rebalancing/OracleCircuitBreaker.sol";
import {DeluxeAssetRebalancer} from "../../src/rebalancing/DeluxeAssetRebalancer.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract MockAggregator is IAggregatorV3 {
    int256 public price;
    uint8 public override decimals = 8;
    uint256 public updatedAt;

    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 _updatedAt, uint80 answeredInRound)
    {
        return (1, price, block.timestamp, updatedAt, 1);
    }
}

contract OracleCircuitBreakerTest is Test {
    OracleCircuitBreaker public breaker;
    DeluxeAssetRebalancer public rebalancer;
    MockAggregator public feed;
    MockERC20 public token;
    MockERC20 public safeHaven;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);

    function setUp() public {
        vm.startPrank(owner);
        token = new MockERC20("Risk Stable", "rUSD", 18);
        safeHaven = new MockERC20("Safe USDC", "USDC", 18);
        feed = new MockAggregator();
        feed.setPrice(100_000_000); // 1.00 USD (8 decimals)

        rebalancer = new DeluxeAssetRebalancer(treasuryVault, owner);
        breaker = new OracleCircuitBreaker(address(rebalancer), owner);

        breaker.setAssetGuard(
            address(token),
            address(feed),
            0.985e18, // 0.985 USD trigger
            3600, // 1h max staleness
            address(safeHaven)
        );
        vm.stopPrank();
    }

    function test_NormalPrice_NoDepeg() public view {
        (bool depegged, uint256 priceWad) = breaker.isDepegged(address(token));
        assertFalse(depegged);
        assertEq(priceWad, 1e18);
    }

    function test_DepegDetected_TriggerCircuit() public {
        // Price drops to 0.97 USD (below 0.985 trigger)
        feed.setPrice(97_000_000);

        (bool depegged, uint256 priceWad) = breaker.isDepegged(address(token));
        assertTrue(depegged);
        assertEq(priceWad, 0.97e18);

        // Check upkeep
        (bool upkeepNeeded, bytes memory performData) = breaker.checkUpkeep();
        assertTrue(upkeepNeeded);

        // Execute upkeep
        breaker.performUpkeep(performData);
    }
}
