// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "contracts/VerifyBridge.sol";
import "contracts/TUProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
contract VerifyBridgeTest is Test {
    address proxyOwner = makeAddr("proxyOwner");
    address accessControlAdmin = makeAddr("accessControlAdmin");
    address requester = makeAddr("requester");
    address computer = makeAddr("computer");
    VerifyBridge verifyBridge;

    error TaskAlreadyCompleted(uint taskId);
    error InvalidProof(uint id, bytes32 commitedResult);
    error InvalidTaskId(uint id, uint nextTaskId);
    error TaskExpired(uint id);

    function setUp() public {
        console.log("proxyOwner", proxyOwner);
        console.log("accessControlAdmin", accessControlAdmin);
        console.log("requester", requester);
        console.log("computer", computer);
        address logic = address(new VerifyBridge());
        verifyBridge = VerifyBridge(
            address(
                new TUProxy(
                    logic,
                    proxyOwner,
                    abi.encodeCall(
                        VerifyBridge.initialize, (accessControlAdmin, requester, computer)
                    )
                )
            )
        );
    }

    // 权限和变量检测
    function test_check() public view {
        require(verifyBridge.hasRole(verifyBridge.DEFAULT_ADMIN_ROLE(), accessControlAdmin));
        require(verifyBridge.hasRole(verifyBridge.REQUESTER_ROLE(), requester));
        require(verifyBridge.hasRole(verifyBridge.COMPUTER_ROLE(), computer));

        require(verifyBridge.nextTaskId() == 1);
    }

    // 由requester提交一个计算请求
    function test_requestCompute() public {
        uint taskId =1;
        bytes32 result = keccak256(abi.encodePacked("answer1"));
        bytes32 inputData = keccak256(abi.encode(taskId, result));

        vm.expectEmit(address(verifyBridge));
        emit VerifyBridge.TaskCreated(1, inputData); // 设置预期event

        vm.startPrank(requester);
        verifyBridge.requestCompute(inputData, 30 days); // 发起请求
        vm.stopPrank();

        require(verifyBridge.nextTaskId() == 2);
    }

    // 在请求之后，由computer提交一个计算结果
    function test_submitResult() public {
        test_requestCompute();

        bytes32 answer = keccak256(abi.encodePacked("answer1"));
        (,bytes32 inputDataWanted,,) = verifyBridge.tasks(1);
        console.logBytes32(inputDataWanted);

        vm.expectEmit(address(verifyBridge));
        emit VerifyBridge.TaskAccepted(1, inputDataWanted, answer); // 设置预期event

        vm.startPrank(computer);
        verifyBridge.submitResult(1, answer); // 提交结果
        vm.stopPrank();

        (,,bytes32 resultAfterSubmit,) = verifyBridge.tasks(1);
        require(resultAfterSubmit != bytes32(0));
    }



    // 下面是几种常见的submitResult运行时错误
    function test_submitResult_revert_expired() public {
        test_requestCompute();

        vm.warp(31 days);

        vm.expectPartialRevert(TaskExpired.selector);

        vm.startPrank(computer);
        verifyBridge.submitResult(1, bytes32("1"));
        vm.stopPrank();
    }

    function test_submitResult_revert_taskAlreadyCompleted() public {
        test_submitResult();

        vm.expectPartialRevert(TaskAlreadyCompleted.selector);

        vm.startPrank(computer);
        verifyBridge.submitResult(1, bytes32("1"));
        vm.stopPrank();
    }

    function test_submitResult_revert_InvalidProof() public {
        test_requestCompute();

        vm.expectPartialRevert(InvalidProof.selector);

        vm.startPrank(computer);
        verifyBridge.submitResult(1, bytes32("1"));
        vm.stopPrank();
    }

    function test_submitResult_revert_InvalidTaskId() public {
        test_requestCompute();

        vm.expectPartialRevert(InvalidTaskId.selector);

        vm.startPrank(computer);
        verifyBridge.submitResult(2, bytes32("1"));
        vm.stopPrank();
    }

    function test_submitResult_revert_InvalidTaskId2() public {
        test_requestCompute();

        vm.expectPartialRevert(InvalidTaskId.selector);

        vm.startPrank(computer);
        verifyBridge.submitResult(3, bytes32("1"));
        vm.stopPrank();
    }

    // proxy升级
    function test_upgrade() public {
        // require(TransparentUpgradeableProxy(address(VerifyBridge))._proxydmin() == proxyAdmin, "not admin");
        address newLogic = address(new VerifyBridge());

        vm.startPrank(proxyOwner);
        ProxyAdmin(_getAdminAddress(address(verifyBridge))).upgradeAndCall(ITransparentUpgradeableProxy(address(verifyBridge)), newLogic, bytes(""));
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