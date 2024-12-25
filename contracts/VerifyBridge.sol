// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IVerifyBridge} from "contracts/interfaces/IVerifyBridge.sol";

struct Task {
    uint id;
    bytes32 inputData;
    bytes32 hashResult;
    uint expiration;
}

contract VerifyBridge is IVerifyBridge, Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant REQUESTER_ROLE = keccak256("REQUESTER_ROLE");
    bytes32 public constant COMPUTER_ROLE = keccak256("COMPUTER_ROLE");

    mapping(uint => Task) public tasks;
    uint public nextTaskId;

    event TaskCreated(uint indexed taskId, bytes32 inputData);
    event TaskAccepted(uint indexed taskId, bytes32 inputData, bytes32 result);

    error TaskAlreadyCompleted(uint taskId);
    error InvalidProof(uint id, bytes32 commitedResult);
    error InvalidTaskId(uint id, uint nextTaskId);
    error TaskExpired(uint id);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address requester, address computer) initializer public {
        __AccessControl_init();
        _grantRole(REQUESTER_ROLE, requester);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPUTER_ROLE, computer);
        nextTaskId = 1;
    }

    function requestCompute(bytes32 inputData, uint lifecycle) external onlyRole(REQUESTER_ROLE) nonReentrant() {
        tasks[nextTaskId] = Task({
            id: nextTaskId,
            inputData: inputData,
            hashResult: bytes32(0),
            expiration: block.timestamp + lifecycle
        });

        emit TaskCreated(nextTaskId, inputData);
        nextTaskId++;
    }

    function submitResult(uint taskId, bytes32 result) external onlyRole(COMPUTER_ROLE) nonReentrant() {
        require(taskId < nextTaskId, InvalidTaskId(taskId, nextTaskId));

        Task memory task = tasks[taskId];
        require(task.expiration >= block.timestamp, TaskExpired(taskId));
        require(task.hashResult == bytes32(0), TaskAlreadyCompleted(taskId));
        require(_isValid(taskId, result, task.inputData), InvalidProof(taskId, result));
        tasks[taskId].hashResult = result;

        emit TaskAccepted(taskId, task.inputData, result);
    }


    function _isValid(uint taskId, bytes32 hashResult, bytes32 inputData) internal pure returns (bool) {
        return keccak256(abi.encode(taskId, hashResult)) == inputData;
    }
}


// keccak256(abi.encode(id + result)) = inputData