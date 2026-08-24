// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title DynamicTributeModel
/// @notice Pure mathematical engine computing graduated tributes scaling with Reserve / TVL growth.
contract DynamicTributeModel {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant WAD = 1e18;

    uint256 public constant BASE_ENTRY_TRIBUTE_BPS = 50;  // 0.5% at bootstrap
    uint256 public constant MAX_ENTRY_TRIBUTE_BPS = 250;  // 2.5% cap at maturity

    uint256 public constant BASE_EXIT_TRIBUTE_BPS = 100;  // 1.0% at bootstrap
    uint256 public constant MAX_EXIT_TRIBUTE_BPS = 500;   // 5.0% cap at maturity

    uint256 public constant SCALE_THRESHOLD = 1_000_000 * WAD; // 1M reserve threshold for max tribute

    /*//////////////////////////////////////////////////////////////
                           DYNAMIC TRIBUTES
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes dynamic entry tribute based on current reserve balance
    function getEntryTributeBps(uint256 currentReserve) external pure returns (uint256) {
        if (currentReserve >= SCALE_THRESHOLD) return MAX_ENTRY_TRIBUTE_BPS;

        uint256 delta = ((MAX_ENTRY_TRIBUTE_BPS - BASE_ENTRY_TRIBUTE_BPS) * currentReserve) / SCALE_THRESHOLD;
        return BASE_ENTRY_TRIBUTE_BPS + delta;
    }

    /// @notice Computes dynamic exit tribute based on current reserve balance
    function getExitTributeBps(uint256 currentReserve) external pure returns (uint256) {
        if (currentReserve >= SCALE_THRESHOLD) return MAX_EXIT_TRIBUTE_BPS;

        uint256 delta = ((MAX_EXIT_TRIBUTE_BPS - BASE_EXIT_TRIBUTE_BPS) * currentReserve) / SCALE_THRESHOLD;
        return BASE_EXIT_TRIBUTE_BPS + delta;
    }
}
