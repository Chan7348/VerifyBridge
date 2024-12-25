// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IVerifyBridge} from "contracts/interfaces/IVerifyBridge.sol";

struct Task {
    uint256 id;
    bytes32 inputData;
    bytes32 hashResult;
    uint256 expiration;
}

contract VerifyBridge is IVerifyBridge, Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant REQUESTER_ROLE = keccak256("REQUESTER_ROLE");
    bytes32 public constant COMPUTER_ROLE = keccak256("COMPUTER_ROLE");

    mapping(address => mapping(uint256 => Task)) public tasks;
    mapping(address => uint256) public nextTaskId;

    event TaskCreated(address requester, uint256 taskId, bytes32 inputData);
    event TaskAccepted(uint256 taskId, bytes32 inputData, bytes32 result);

    error TaskAlreadyCompleted(uint256 taskId);
    error InvalidProof(uint256 id, bytes32 commitedResult);
    error InvalidTaskId(uint256 id, uint256 nextTaskId);
    error TaskExpired(uint256 id);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address requester, address computer) initializer public {
        __AccessControl_init();
        _grantRole(REQUESTER_ROLE, requester);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPUTER_ROLE, computer);
    }

    function requestCompute(bytes32 inputData, uint256 lifecycle) external onlyRole(REQUESTER_ROLE) nonReentrant() {
        tasks[msg.sender][nextTaskId[msg.sender]] = Task({
            id: nextTaskId[msg.sender],
            inputData: inputData,
            hashResult: bytes32(0),
            expiration: block.timestamp + lifecycle
        });

        emit TaskCreated(msg.sender, nextTaskId[msg.sender], inputData);
        nextTaskId[msg.sender]++;
    }

    function submitResult(address requester, uint256 taskId, bytes32 result) external onlyRole(COMPUTER_ROLE) nonReentrant() {
        require(taskId < nextTaskId[requester], InvalidTaskId(taskId, nextTaskId[requester]));

        Task memory task = tasks[requester][taskId];
        require(task.expiration >= block.timestamp, TaskExpired(taskId));
        require(task.hashResult == bytes32(0), TaskAlreadyCompleted(taskId));
        require(_isValid(taskId, result, task.inputData), InvalidProof(taskId, result));
        tasks[requester][taskId].hashResult = result;

        emit TaskAccepted(taskId, task.inputData, result);
    }


    function _isValid(uint256 taskId, bytes32 hashResult, bytes32 inputData) internal pure returns (bool) {
        return keccak256(abi.encode(taskId, hashResult)) == inputData;
    }
}


// keccak256(abi.encode(id, result)) = inputData