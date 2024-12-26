// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import "contracts/VerifyBridge.sol";
import "contracts/TUProxy.sol";

contract Deploy is Script {

    address near1;
    address near2;
    address near3;

    address signer;
    address proxyAdmin;
    address admin;
    address requester;
    address computer;

    function setUp() public {
        near1 = vm.addr(vm.envUint("near1"));
        near2 = vm.addr(vm.envUint("near2"));
        near3 = vm.addr(vm.envUint("near3"));

        signer = near1;
        proxyAdmin = near3;
        admin = near1;
        requester = near1;
        computer = near2;
    }

    function run() public {
        vm.startBroadcast(vm.envUint("near1"));
        address impl = address(new VerifyBridge());
        address verifyBridge = address(
            new TUProxy(
                impl,
                proxyAdmin,
                abi.encodeCall(
                    VerifyBridge.initialize, (admin, requester, computer)
                )
            )
        );
        console.log("signer:", signer);
        console.log("proxyAdmin:", proxyAdmin);
        console.log("admin:", admin);
        console.log("requester:", requester);
        console.log("computer:", computer);
        console.log("near1:",near1);
        console.log("near2:",near2);
        console.log("near3:",near3);
        console.log("impl addr:", impl);
        console.log("contract addr:", verifyBridge);
        vm.stopBroadcast();
    }
}