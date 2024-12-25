// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "contracts/Oracle.sol";
import "contracts/TUProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
contract OracleTest is Test {
    address proxyOwner = makeAddr("proxyOwner");
    address accessControlAdmin = makeAddr("accessControlAdmin");
    address requester = makeAddr("requester");
    address computer = makeAddr("computer");
    Oracle oracle;

    error TaskAlreadyCompleted(uint taskId);
    error InvalidProof(uint id, bytes32 commitedResult);
    error InvalidTaskId(uint id, uint nextTaskId);
    error TaskExpired(uint id);

    function setUp() public {
        console.log("proxyOwner", proxyOwner);
        console.log("accessControlAdmin", accessControlAdmin);
        console.log("requester", requester);
        console.log("computer", computer);
        address logic = address(new Oracle());
        oracle = Oracle(
            address(
                new TUProxy(
                    logic,
                    proxyOwner,
                    abi.encodeCall(
                        Oracle.initialize, (accessControlAdmin, requester, computer)
                    )
                )
            )
        );
    }

    // 权限和变量检测
    function test_check() public view {
        require(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), accessControlAdmin));
        require(oracle.hasRole(oracle.REQUESTER_ROLE(), requester));
        require(oracle.hasRole(oracle.COMPUTER_ROLE(), computer));

        require(oracle.nextTaskId() == 1);
    }

    // 由requester提交一个计算请求
    function test_requestCompute() public {
        uint taskId =1;
        bytes32 result = keccak256(abi.encodePacked("answer1"));
        bytes32 inputData = keccak256(abi.encode(taskId, result));

        vm.expectEmit(address(oracle));
        emit Oracle.TaskCreated(1, inputData); // 设置预期event

        vm.startPrank(requester);
        oracle.requestCompute(inputData, 30 days); // 发起请求
        vm.stopPrank();

        require(oracle.nextTaskId() == 2);
    }

    // 在请求之后，由computer提交一个计算结果
    function test_submitResult() public {
        test_requestCompute();

        bytes32 answer = keccak256(abi.encodePacked("answer1"));
        (,bytes32 inputDataWanted,,) = oracle.tasks(1);
        console.logBytes32(inputDataWanted);

        vm.expectEmit(address(oracle));
        emit Oracle.TaskAccepted(1, inputDataWanted, answer); // 设置预期event

        vm.startPrank(computer);
        oracle.submitResult(1, answer); // 提交结果
        vm.stopPrank();

        (,,bytes32 resultAfterSubmit,) = oracle.tasks(1);
        require(resultAfterSubmit != bytes32(0));
    }



    // 下面是几种常见的submitResult运行时错误
    function test_submitResult_revert_expired() public {
        test_requestCompute();

        vm.warp(31 days);

        vm.expectPartialRevert(TaskExpired.selector);

        vm.startPrank(computer);
        oracle.submitResult(1, bytes32("1"));
        vm.stopPrank();
    }

    function test_submitResult_revert_taskAlreadyCompleted() public {
        test_submitResult();

        vm.expectPartialRevert(TaskAlreadyCompleted.selector);

        vm.startPrank(computer);
        oracle.submitResult(1, bytes32("1"));
        vm.stopPrank();
    }

    function test_submitResult_revert_InvalidProof() public {
        test_requestCompute();

        vm.expectPartialRevert(InvalidProof.selector);

        vm.startPrank(computer);
        oracle.submitResult(1, bytes32("1"));
        vm.stopPrank();
    }

    function test_submitResult_revert_InvalidTaskId() public {
        test_requestCompute();

        vm.expectPartialRevert(InvalidTaskId.selector);

        vm.startPrank(computer);
        oracle.submitResult(2, bytes32("1"));
        vm.stopPrank();
    }

    function test_submitResult_revert_InvalidTaskId2() public {
        test_requestCompute();

        vm.expectPartialRevert(InvalidTaskId.selector);

        vm.startPrank(computer);
        oracle.submitResult(3, bytes32("1"));
        vm.stopPrank();
    }

    // proxy升级
    function test_upgrade() public {
        // require(TransparentUpgradeableProxy(address(oracle))._proxydmin() == proxyAdmin, "not admin");
        address newLogic = address(new Oracle());

        vm.startPrank(proxyOwner);
        ProxyAdmin(_getAdminAddress(address(oracle))).upgradeAndCall(ITransparentUpgradeableProxy(address(oracle)), newLogic, bytes(""));
        vm.stopPrank();
    }

    // provided by Openzeppelin
    function _getAdminAddress(address proxy) internal view returns (address) {
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }

}