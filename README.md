# VerifyBridge
### Interfaces:

#### requestCompute(bytes32, uint256)
##### 由requester调用，用于发布计算任务

#### submitResult(uint256, bytes32)
##### 由computer调用，用于提交计算结果，并进行链上验证



#### deploy script:
#### forge script -f $ETHEREUM_SEPOLIA_RPC --verify --broadcast --slow --chain 11155111 script/foundry/deploy.s.sol:Deploy
#### signer: 0x783F89984F2ef3574fE16a66f034fd0622F716F5
#### proxyAdmin: 0x0f19474DEe1dBb7844d1278474f105958CF843BB
#### admin: 0x783F89984F2ef3574fE16a66f034fd0622F716F5
#### requester: 0x783F89984F2ef3574fE16a66f034fd0622F716F5
#### computer: 0x71e469198fb4b05567d39411e5E3ddDcB05E2EBf
#### near1: 0x783F89984F2ef3574fE16a66f034fd0622F716F5
#### near2: 0x71e469198fb4b05567d39411e5E3ddDcB05E2EBf
#### near3: 0x0f19474DEe1dBb7844d1278474f105958CF843BB
#### impl addr: 0x18B626AE4709BA59774A56A7e31B2ca87377503B
#### contract addr: 0xb0EC58791C55FAB42B362EBfd55aB91aCB150036


监听智能合约事件来处理计算任务。
智能合约事件分两种：
1. Task被创建，open
2. Task被close

链下储存数据结构：
1. suo