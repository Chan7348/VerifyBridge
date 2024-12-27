# VerifyBridge
通过事件驱动设计的计算任务桥接合约，用于管理计算任务的创建和结果验证
### 智能合约Interfaces:

#### requestCompute(bytes32)
由requester调用，用于发布计算任务

#### submitResult(uint256, bytes32)
由computer调用，用于提交计算结果，并进行链上验证


#### impl addr: [0x36767b4e096429d4dbfbb99901d850c07fa94fea](https://sepolia.etherscan.io/address/0x36767b4e096429d4dbfbb99901d850c07fa94fea#code)
#### contract addr(Transparent Upgradeable Proxy): [0x9e3cDdcf8Ee5322D3674e027FD6504b9eD77a37B](https://sepolia.etherscan.io/address/0x9e3cDdcf8Ee5322D3674e027FD6504b9eD77a37B#code)


#### 监听智能合约事件来处理计算任务。
智能合约事件分两种：
1. Requester创建任务，event TaskCreated
2. computer提交答案且验证成功，event TaskAccepted


### TypeScript SDK:

#### class Requester:
##### 核心方法:
getNextTaskId(): 从合约中获取下一个可用的ID
request(rawData): 发布新的计算任务，sdk会将 rawData+TaskId Hash之后提交到合约, 这个rawData其实也是computer计算得到的结果。

#### class Computer:
##### 核心方法：
startMonitoring(): 启动监控线程，监听所有的TaskCreated+TaskAccepted事件
startProcessing(): 启动处理线程，每次循环从队列中取出任务并执行, 等待monitor进程检测到Accepted事件表示任务成功

##### 队列管理：
使用idQueue储存任务ID，确保任务按顺序处理
使用taskStateMap管理存储任务状态，实现线程间的通信

##### 并发控制：
startProcessing()使用锁机制，确保同时只有一个任务被处理

#### Scripts:
request_compute.ts，由Requester触发，发布新的计算任务
run_computer.ts，由Computer触发，启动监控和处理线程

### 使用方法：
1. 设置好和env中的私钥和RPC_URL
2. 部署合约，注意权限管理，在部署脚本中设置好Requester和Computer的EOA地址
`forge script -f $ETHEREUM_SEPOLIA_RPC --verify --broadcast --slow --chain 11155111 script/foundry/deploy.s.sol:Deploy`
3. 先启动computer，
`yarn ts-node script/run_computer.ts`
1. 触发request.
`yarn ts-node script/request_compute.ts`