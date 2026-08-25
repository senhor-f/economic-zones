// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {L2CommerceBatcher} from "../../src/crosschain/L2CommerceBatcher.sol";

contract L2CommerceBatcherTest is Test {
    MockERC20 public usdc;
    L2CommerceBatcher public batcher;

    address public owner = address(0xAA);
    address public sequencer = address(0x5E0);
    address public l1Receiver = address(0xCAFE);
    address public bridgeAdapter = address(0x8888);

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 18);
        vm.prank(owner);
        batcher = new L2CommerceBatcher(address(usdc), l1Receiver, owner);

        vm.prank(owner);
        batcher.setSequencer(sequencer, true);

        usdc.mint(address(batcher), 10_000e18); // Batcher holds 10k USDC collected taxes
    }

    function test_FinalizeEpochBatch_AndBridgeTributes() public {
        uint256 epoch = 1;
        bytes32 root = keccak256("batch_epoch_1");
        uint256 volume = 250_000e18;
        uint256 tax = 2_500e18;
        uint256 projects = 12;

        vm.prank(sequencer);
        batcher.finalizeEpochBatch(epoch, root, volume, tax, projects);

        assertEq(batcher.currentEpoch(), epoch);

        (
            uint256 bEpoch,
            bytes32 bRoot,
            uint256 bVolume,
            uint256 bTax,
            uint256 bProjects,
            uint256 closedAt
        ) = batcher.epochBatches(epoch);

        assertEq(bEpoch, epoch);
        assertEq(bRoot, root);
        assertEq(bVolume, volume);
        assertEq(bTax, tax);
        assertEq(bProjects, projects);
        assertTrue(closedAt > 0);

        // Owner bridges collected tax to L1
        vm.prank(owner);
        batcher.bridgeTributesToL1(tax, bridgeAdapter);

        assertEq(usdc.balanceOf(bridgeAdapter), tax);
    }
}
