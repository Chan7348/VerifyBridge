// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IVerifyBridge} from "contracts/interfaces/IVerifyBridge.sol";

struct Task {
    bytes32 inputData;
    bool accepted;
}

contract VerifyBridge is IVerifyBridge, Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant REQUESTER_ROLE = keccak256("REQUESTER_ROLE");
    bytes32 public constant COMPUTER_ROLE = keccak256("COMPUTER_ROLE");

    mapping(uint256 id => Task) public tasks;
    uint256 public nextTaskId;

    event TaskCreated(uint256 taskId, bytes32 inputData);
    event TaskAccepted(uint256 taskId);

    error TaskAlreadyAccepted(uint256 taskId);
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

    function requestCompute(bytes32 inputData) external onlyRole(REQUESTER_ROLE) nonReentrant() {
        tasks[nextTaskId] = Task({
            inputData: inputData,
            accepted: false
        });

        emit TaskCreated(nextTaskId, inputData);
        nextTaskId++;
    }

    function submitResult(uint256 taskId, bytes32 result) external onlyRole(COMPUTER_ROLE) nonReentrant() {
        require(taskId < nextTaskId, InvalidTaskId(taskId, nextTaskId));

        Task memory task = tasks[taskId];
        require(!task.accepted, TaskAlreadyAccepted(taskId));
        require(_isValid(taskId, result, task.inputData), InvalidProof(taskId, result));
        tasks[taskId].accepted = true;

        emit TaskAccepted(taskId);
    }

    function _isValid(uint256 taskId, bytes32 hashResult, bytes32 inputData) internal pure returns (bool) {
        return keccak256(abi.encode(taskId, hashResult)) == inputData;
    }
}

// keccak256(abi.encode(id, result)) = inputData