// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";
import {ZonePaymentGateway} from "../../src/payments/ZonePaymentGateway.sol";
import {x402Settler} from "../../src/payments/x402Settler.sol";

contract x402SettlerTest is Test {
    HNYToken public hny;
    ProjectRegistry public registry;
    ContributionLedger public ledger;
    ZonePaymentGateway public gateway;
    x402Settler public settler;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public serverApi = address(0x88);

    uint256 public agentPrivateKey = 0xA11CE;
    address public agent;
    uint256 public projectId;

    function setUp() public {
        agent = vm.addr(agentPrivateKey);

        vm.startPrank(owner);
        hny = new HNYToken(owner);
        registry = new ProjectRegistry(owner);
        ledger = new ContributionLedger(owner);

        gateway = new ZonePaymentGateway(address(hny), address(registry), address(ledger), treasuryVault, owner);

        settler = new x402Settler(address(hny), address(gateway), owner);

        hny.setMinter(owner, true);
        ledger.setReporter(address(gateway), true);
        vm.stopPrank();

        // Register API project
        projectId = registry.registerProject(serverApi, "ipfs://ai-agent-api", 0);

        // Mint HNY to agent
        vm.prank(owner);
        hny.mint(agent, 1000e18);
    }

    function test_AgentAutonomousPayment() public {
        uint256 paymentAmount = 50e18; // 50 HNY
        bytes32 nonce = keccak256("call-id-001");
        uint256 deadline = block.timestamp + 1 hours;

        // 1. Agent signs EIP-712 payment authorization
        bytes32 structHash = keccak256(abi.encode(settler.TYPEHASH(), agent, projectId, paymentAmount, nonce, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", settler.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 2. Agent approves settler
        vm.prank(agent);
        hny.approve(address(settler), paymentAmount);

        // 3. Server or Relayer submits settlement
        vm.prank(serverApi);
        (uint256 netProject, uint256 cashback) = settler.settlePayment(
            x402Settler.PaymentAuthorization({
                agent: agent, projectId: projectId, amount: paymentAmount, nonce: nonce, deadline: deadline
            }),
            signature
        );

        // 98% to server = 49 HNY, 1% cashback = 0.5 HNY
        assertEq(netProject, 49e18);
        assertEq(cashback, 0.5e18);
        assertEq(hny.balanceOf(serverApi), 49e18);
        assertEq(hny.balanceOf(agent), 1000e18 - paymentAmount + cashback);
    }
}
