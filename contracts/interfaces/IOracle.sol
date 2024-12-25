// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Task} from "contracts/Oracle.sol";

interface IOracle {
    function nextTaskId() external returns (uint);
    function requestCompute(bytes32,uint256) external;
    function submitResult(uint256,bytes32) external;
}