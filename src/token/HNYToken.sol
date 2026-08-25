// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";

/// @title HNYToken ($HNY v2)
/// @notice Core currency, medium of exchange, and governance anchor of the Economic Zones Protocol.
/// @dev High-performance ERC20 implementation with Solady, EIP-2612 Permit, controlled minters, and burns.
contract HNYToken is ERC20, Ownable, Versioned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MinterStatusUpdated(address indexed minter, bool indexed status);
    event TokensBurned(address indexed from, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAuthorizedMinter();
    error ZeroAddress();
    error InvalidAmount();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of addresses authorized to mint $HNY (e.g., Bonding Curve, Migrator)
    mapping(address => bool) public isMinter;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param initialOwner Address of the contract owner (Core Governor / Timelock)
    constructor(address initialOwner) Versioned("HNYToken") {
        if (initialOwner == address(0)) revert ZeroAddress();
        _initializeOwner(initialOwner);
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA & CONFIG
    //////////////////////////////////////////////////////////////*/

    function name() public pure override returns (string memory) {
        return "Honey";
    }

    function symbol() public pure override returns (string memory) {
        return "HNY";
    }

    /*//////////////////////////////////////////////////////////////
                             MINT & BURN
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints new $HNY tokens to a recipient. Only callable by authorized minters.
    /// @param to Recipient address
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external {
        if (!isMinter[msg.sender]) revert NotAuthorizedMinter();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        _mint(to, amount);
    }

    /// @notice Burns tokens from caller's balance.
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /// @notice Burns tokens from an account using allowance.
    /// @param from Account to burn tokens from
    /// @param amount Amount of tokens to burn
    function burnFrom(address from, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants or revokes minter authorization.
    /// @param minter Target address
    /// @param status True to allow minting, false to revoke
    function setMinter(address minter, bool status) external onlyOwner {
        if (minter == address(0)) revert ZeroAddress();
        isMinter[minter] = status;
        emit MinterStatusUpdated(minter, status);
    }
}
