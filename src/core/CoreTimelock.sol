// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title CoreTimelock
/// @notice 48h timelock enforcement for protocol upgrades and parameter changes.
contract CoreTimelock {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OperationScheduled(bytes32 indexed id, address indexed target, uint256 value, bytes data, uint256 eta);
    event OperationExecuted(bytes32 indexed id, address indexed target, uint256 value, bytes data);
    event OperationCanceled(bytes32 indexed id);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidDelay();
    error OperationAlreadyQueued();
    error OperationNotReady();
    error OperationExpired();
    error ExecutionFailed();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public admin;
    uint256 public minDelay = 2 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    mapping(bytes32 => uint256) public queuedOperations;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _admin, uint256 _minDelay) {
        if (_minDelay < 1 hours || _minDelay > 30 days) revert InvalidDelay();
        admin = _admin;
        minDelay = _minDelay;
    }

    /*//////////////////////////////////////////////////////////////
                           TIMELOCK ACTIONS
    //////////////////////////////////////////////////////////////*/

    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 salt)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(target, value, data, salt));
    }

    function schedule(address target, uint256 value, bytes calldata data, bytes32 salt) external returns (bytes32 id) {
        if (msg.sender != admin) revert Unauthorized();

        id = hashOperation(target, value, data, salt);
        if (queuedOperations[id] != 0) revert OperationAlreadyQueued();

        uint256 eta = block.timestamp + minDelay;
        queuedOperations[id] = eta;

        emit OperationScheduled(id, target, value, data, eta);
    }

    function execute(address target, uint256 value, bytes calldata data, bytes32 salt)
        external
        payable
        returns (bytes memory)
    {
        if (msg.sender != admin) revert Unauthorized();

        bytes32 id = hashOperation(target, value, data, salt);
        uint256 eta = queuedOperations[id];

        if (eta == 0 || block.timestamp < eta) revert OperationNotReady();
        if (block.timestamp > eta + GRACE_PERIOD) revert OperationExpired();

        delete queuedOperations[id];

        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (!success) revert ExecutionFailed();

        emit OperationExecuted(id, target, value, data);
        return returnData;
    }

    function cancel(bytes32 id) external {
        if (msg.sender != admin) revert Unauthorized();
        delete queuedOperations[id];
        emit OperationCanceled(id);
    }
}
