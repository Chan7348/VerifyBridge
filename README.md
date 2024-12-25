# VerifyBridge
### Interfaces:

#### requestCompute(bytes32, uint256)
##### 由requester调用，用于发布计算任务

#### submitResult(uint256, bytes32)
##### 由computer调用，用于提交计算结果，并进行链上验证



#### deploy script:
#### forge script -f $ETHEREUM_SEPOLIA_RPC --verify --broadcast --slow --chain 11155111 script/deploy.s.sol:Deploy
#### signer: 0x783F89984F2ef3574fE16a66f034fd0622F716F5
#### proxyAdmin: 0x0f19474DEe1dBb7844d1278474f105958CF843BB
#### admin: 0x783F89984F2ef3574fE16a66f034fd0622F716F5
#### requester: 0x783F89984F2ef3574fE16a66f034fd0622F716F5
#### computer: 0x71e469198fb4b05567d39411e5E3ddDcB05E2EBf
#### near1: 0x783F89984F2ef3574fE16a66f034fd0622F716F5
#### near2: 0x71e469198fb4b05567d39411e5E3ddDcB05E2EBf
#### near3: 0x0f19474DEe1dBb7844d1278474f105958CF843BB
#### impl addr: 0x9d140381EF177a758b0251A291A4Ad1383A29cFe
#### contract addr: 0x2E9C259DD173e98508ec4E1B4F65b3c4E707d33a