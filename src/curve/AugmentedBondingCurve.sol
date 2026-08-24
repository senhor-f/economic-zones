// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {HNYToken} from "../token/HNYToken.sol";

/// @title AugmentedBondingCurve
/// @notice Continuous liquidity, graduated tributes, and mathematical floor protection for $HNY.
/// @dev Implements an asymmetric augmented bonding curve with an unbreachable floor price backed by reserves.
contract AugmentedBondingCurve is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Minted(
        address indexed buyer, address indexed recipient, uint256 reserveIn, uint256 tributeTaken, uint256 hnyMinted
    );
    event Burned(
        address indexed seller, address indexed recipient, uint256 hnyBurned, uint256 tributeTaken, uint256 reserveOut
    );
    event FloorRedeemed(address indexed redeemer, address indexed recipient, uint256 hnyBurned, uint256 reserveOut);
    event TributesUpdated(uint256 entryTributeBps, uint256 exitTributeBps);
    event TreasuryVaultUpdated(address indexed newTreasuryVault);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error SlippageExceeded();
    error InvalidTribute();
    error InsufficientReserve();
    error InsufficientSupply();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The native $HNY token
    HNYToken public immutable hnyToken;

    /// @notice Primary reserve asset (e.g. USDC, sUSDS, WETH)
    address public immutable reserveToken;

    /// @notice Dedicated Treasury Vault that holds reserve backing
    address public treasuryVault;

    /// @notice Base price scalar (in WAD)
    uint256 public immutable basePrice;

    /// @notice Slope coefficient for the linear curve component (in WAD / 1e18)
    uint256 public immutable slope;

    /// @notice Entry tribute in basis points (starts low e.g. 50 = 0.5%)
    uint256 public entryTributeBps;

    /// @notice Exit tribute in basis points (starts low e.g. 100 = 1.0%)
    uint256 public exitTributeBps;

    /// @notice Total reserve assets tracked in the bonding curve pool
    uint256 public reserveBalance;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _hnyToken Address of HNYToken
    /// @param _reserveToken Address of ERC20 reserve asset
    /// @param _treasuryVault Destination for tributes and secondary floor custody
    /// @param _owner Protocol owner / governance
    /// @param _basePrice Initial base price in 18 decimals (e.g. 1e18 = 1 reserve unit per HNY)
    /// @param _slope Price curve slope (e.g. 1e12 for gentle bonding progression)
    /// @param _initialEntryTributeBps Initial entry tribute (e.g. 50 = 0.5%)
    /// @param _initialExitTributeBps Initial exit tribute (e.g. 100 = 1.0%)
    constructor(
        address _hnyToken,
        address _reserveToken,
        address _treasuryVault,
        address _owner,
        uint256 _basePrice,
        uint256 _slope,
        uint256 _initialEntryTributeBps,
        uint256 _initialExitTributeBps
    ) {
        if (
            _hnyToken == address(0) || _reserveToken == address(0) || _treasuryVault == address(0)
                || _owner == address(0)
        ) revert ZeroAddress();

        if (_initialEntryTributeBps > 1000 || _initialExitTributeBps > 2000) {
            revert InvalidTribute();
        }

        hnyToken = HNYToken(_hnyToken);
        reserveToken = _reserveToken;
        treasuryVault = _treasuryVault;
        basePrice = _basePrice;
        slope = _slope;
        entryTributeBps = _initialEntryTributeBps;
        exitTributeBps = _initialExitTributeBps;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           PRICE & FLOOR VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns current spot price of $HNY on the bonding curve (Yul optimized)
    function getSpotPrice() public view returns (uint256 spot) {
        uint256 supply = hnyToken.totalSupply();
        uint256 base = basePrice;
        uint256 sl = slope;
        assembly {
            // spot = base + (supply * slope) / 1e18
            spot := add(base, div(mul(supply, sl), 1000000000000000000))
        }
    }

    /// @notice Computes the mathematical floor price = reserveBalance / totalSupply (Yul optimized)
    function getFloorPrice() public view returns (uint256 floor) {
        uint256 supply = hnyToken.totalSupply();
        uint256 reserve = reserveBalance;
        uint256 base = basePrice;
        assembly {
            switch or(iszero(supply), iszero(reserve))
            case 1 {
                floor := base
            }
            default {
                floor := div(mul(reserve, 1000000000000000000), supply)
            }
        }
    }

    /// @notice Previews the amount of $HNY received for a given reserve deposit (Yul optimized)
    function previewBuy(uint256 reserveIn) public view returns (uint256 hnyOut, uint256 tribute) {
        if (reserveIn == 0) return (0, 0);
        uint256 tributeBps = entryTributeBps;
        uint256 netReserve;
        assembly {
            tribute := div(mul(reserveIn, tributeBps), 10000)
            netReserve := sub(reserveIn, tribute)
        }

        uint256 currentSpot = getSpotPrice();
        uint256 sl = slope;

        if (sl == 0) {
            assembly {
                hnyOut := div(mul(netReserve, 1000000000000000000), currentSpot)
            }
        } else {
            uint256 a = sl / 2;
            uint256 b = currentSpot;
            uint256 c = netReserve * 1e18;

            uint256 discriminant = (b * b) + (4 * a * c / 1e18);
            uint256 sqrtD = FixedPointMathLib.sqrt(discriminant);
            assembly {
                hnyOut := div(mul(sub(sqrtD, b), 1000000000000000000), mul(2, a))
            }
        }
    }

    /// @notice Previews the reserve amount returned for selling a given amount of $HNY
    function previewSell(uint256 hnyIn) public view returns (uint256 reserveOut, uint256 tribute) {
        if (hnyIn == 0) return (0, 0);
        uint256 currentSupply = hnyToken.totalSupply();
        if (hnyIn > currentSupply) revert InsufficientSupply();

        // 1. Calculate curve integral value
        uint256 spotAtTarget = basePrice + ((currentSupply - hnyIn) * slope) / WAD;
        uint256 avgPrice = (getSpotPrice() + spotAtTarget) / 2;
        uint256 curveReserve = (hnyIn * avgPrice) / WAD;

        // 2. Calculate Floor value guarantee
        uint256 floorValue = (hnyIn * getFloorPrice()) / WAD;

        // Curve return is max of curve integral and floor
        uint256 grossReserve = curveReserve > floorValue ? curveReserve : floorValue;
        if (grossReserve > reserveBalance) {
            grossReserve = reserveBalance;
        }

        tribute = (grossReserve * exitTributeBps) / BPS_DENOMINATOR;
        reserveOut = grossReserve - tribute;
    }

    /*//////////////////////////////////////////////////////////////
                           EXECUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Buys $HNY by depositing reserve token
    /// @param reserveIn Amount of reserve tokens to spend
    /// @param minHnyOut Minimum acceptable $HNY tokens minted (slippage protection)
    /// @param recipient Address receiving newly minted $HNY
    function buy(uint256 reserveIn, uint256 minHnyOut, address recipient)
        external
        nonReentrant
        returns (uint256 hnyOut)
    {
        if (reserveIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        (uint256 tokensToMint, uint256 tribute) = previewBuy(reserveIn);
        if (tokensToMint < minHnyOut) revert SlippageExceeded();

        // 1. Transfer reserve in
        reserveToken.safeTransferFrom(msg.sender, address(this), reserveIn);

        // 2. Transfer entry tribute to Treasury Vault
        if (tribute > 0) {
            reserveToken.safeTransfer(treasuryVault, tribute);
        }

        // 3. Track net reserve in curve backing
        reserveBalance += (reserveIn - tribute);

        // 4. Mint $HNY to recipient
        hnyToken.mint(recipient, tokensToMint);

        emit Minted(msg.sender, recipient, reserveIn, tribute, tokensToMint);
        return tokensToMint;
    }

    /// @notice Sells $HNY back to the bonding curve for reserve token
    /// @param hnyIn Amount of $HNY to burn
    /// @param minReserveOut Minimum acceptable reserve token to receive
    /// @param recipient Address receiving reserve tokens
    function sell(uint256 hnyIn, uint256 minReserveOut, address recipient)
        external
        nonReentrant
        returns (uint256 reserveOut)
    {
        if (hnyIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        (uint256 grossReserve, uint256 tribute) = previewSell(hnyIn);
        uint256 netReserve = grossReserve - tribute;
        if (netReserve < minReserveOut) revert SlippageExceeded();
        if (grossReserve > reserveBalance) revert InsufficientReserve();

        // 1. Burn user's $HNY
        hnyToken.burnFrom(msg.sender, hnyIn);

        // 2. Deduct from curve reserve
        reserveBalance -= grossReserve;

        // 3. Send exit tribute to Treasury Vault
        if (tribute > 0) {
            reserveToken.safeTransfer(treasuryVault, tribute);
        }

        // 4. Send net reserve to recipient
        reserveToken.safeTransfer(recipient, netReserve);

        emit Burned(msg.sender, recipient, hnyIn, tribute, netReserve);
        return netReserve;
    }

    /// @notice Direct unbreachable floor redemption: burns $HNY for exact proportional share of reserve balance
    /// @param hnyIn Amount of $HNY to burn
    /// @param minReserveOut Minimum reserve expected
    /// @param recipient Address receiving reserve token
    function redeemAtFloor(uint256 hnyIn, uint256 minReserveOut, address recipient)
        external
        nonReentrant
        returns (uint256 reserveOut)
    {
        if (hnyIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 supply = hnyToken.totalSupply();
        if (supply == 0 || reserveBalance == 0) revert InsufficientReserve();

        // Exact floor proportion: (hnyIn * reserveBalance) / supply
        reserveOut = (hnyIn * reserveBalance) / supply;
        if (reserveOut < minReserveOut) revert SlippageExceeded();

        // 1. Burn $HNY
        hnyToken.burnFrom(msg.sender, hnyIn);

        // 2. Reduce reserve
        reserveBalance -= reserveOut;

        // 3. Transfer reserve without tribute (pure floor right)
        reserveToken.safeTransfer(recipient, reserveOut);

        emit FloorRedeemed(msg.sender, recipient, hnyIn, reserveOut);
        return reserveOut;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    /// @notice Adjusts tributes dynamically (bounded by safety caps)
    function setTributes(uint256 _entryTributeBps, uint256 _exitTributeBps) external onlyOwner {
        if (_entryTributeBps > 1000 || _exitTributeBps > 2000) revert InvalidTribute();
        entryTributeBps = _entryTributeBps;
        exitTributeBps = _exitTributeBps;
        emit TributesUpdated(_entryTributeBps, _exitTributeBps);
    }

    /// @notice Updates Treasury Vault recipient
    function setTreasuryVault(address _treasuryVault) external onlyOwner {
        if (_treasuryVault == address(0)) revert ZeroAddress();
        treasuryVault = _treasuryVault;
        emit TreasuryVaultUpdated(_treasuryVault);
    }
}
