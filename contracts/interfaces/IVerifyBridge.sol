// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Task} from "contracts/VerifyBridge.sol";

interface IVerifyBridge {
    function nextTaskId() external returns (uint256);
    function requestCompute(bytes32) external;
    function submitResult(uint256,bytes32) external;
}