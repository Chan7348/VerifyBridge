import { BigNumberish, ethers } from "ethers";
import { VerifyBridge } from "../typechain-types";
import { VerifyBridge__factory } from "../typechain-types";

interface TaskDetails {
    state: number; // 0: 未检测, 1: 未计算完成, 2: 已计算完成
    inputData: string; // 任务的 inputData
}

export class Computer {
    public provider: ethers.JsonRpcProvider;
    public contract: VerifyBridge;
    public interval: number;

    public idQueue: Set<bigint> = new Set<bigint>; // 只储存状态为1的任务ID
    public taskStateMap: Map<bigint, TaskDetails> = new Map<bigint, TaskDetails>(); // 储存任务状态

    public abicoder = new ethers.AbiCoder();

    constructor(providerURL: string, contractAddress: string, privateKey: string, interval: number = 10000) {
        this.provider = new ethers.JsonRpcProvider(providerURL);
        const signer = new ethers.Wallet(privateKey, this.provider);
        this.contract = VerifyBridge__factory.connect(contractAddress, signer);
        this.interval = interval;
    }

    public startMonitoring() {
        console.log("start monitoring...");

        this.contract.on(this.contract.getEvent("TaskCreated"), (taskId, inputData) => {
            console.log(`Captured TaskCreated event, id:${taskId}`);
            if (this.taskStateMap.has(taskId)) return;

            this.idQueue.add(taskId);
            this.taskStateMap.set(taskId, { state: 1, inputData: inputData });

            console.log(`Task ${taskId} added to queue.`);
        });

        this.contract.on(this.contract.getEvent("TaskAccepted"), (taskId) => {
            console.log(`Captured TaskAccepted event, id:${taskId}`);

            const task = this.taskStateMap.get(taskId);
            if (task && task.state === 1) {
                task.state = 2;
                this.idQueue.delete(taskId);
                console.log(`Task ${taskId} has been accepted and removed from the queue.`);
            }
        });
    }

    // loop流程：
    // 1. 尝试从队列中取出一个任务，如果一直没有任务，等待一段时间后再进入下一个loop重新尝试
    // 2. 获取任务详情，如果无效任务，删除并continue
    // 3. 执行计算, 发送交易
    // 4. 等待任务被 accept之后进入下一个loop
    public async startProcessing() {
        console.log("start processing...");

        while (true) { // 无限循环处理任务
            try {
                // 从队列中取出一个任务
                const id = Array.from(this.idQueue.values())[0];
                if (!id) {
                    console.log("No tasks in the queue. Waiting...");
                    await new Promise((resolve) => setTimeout(resolve, this.interval)); // 等待一段时间再检查, 节省资源
                    continue;
                }

                // 获取任务详情
                const task = this.taskStateMap.get(id);
                if (!task || task.state !== 1) {
                    console.log(`Task ${id} is not in a valid state for processing.`);
                    this.idQueue.delete(id); // 从队列中移除无效任务
                    continue;
                }

                console.log(`Processing Task: TaskID=${id}, InputData=${task.inputData}`);

                // 执行计算, 发送交易
                await this.sendTx(id, this.compute());
                console.log(`Task ${id} successfully sent to the chain.`);

                // 等待任务被 accept
                const accepted = await this.waitForTaskAccepted(id);
                if (!accepted) {
                    console.error(`Task ${id} has not been accepted.`);
                    this.idQueue.add(id); // 重新加入队列
                }

                console.log("--------------------------------");
            } catch (err) {
                console.error(`Error processing Task: ${err}`);
            }
        }
    }

    public async sendTx(id: bigint, result: string): Promise<void> {
        const tx = await this.contract.submitResult(id, result);
        await tx.wait();
        console.log(`Tx confirmed: ${tx.hash}`);
    }

    public compute(): string {
        return ethers.keccak256(ethers.toUtf8Bytes("1"));
    }

    // 检查本地Map中的任务状态，如果任务已被接受，返回true，否则阻塞
    private async waitForTaskAccepted(id: bigint, timeout = 30000, interval = 2000): Promise<boolean> {
        const startTime = Date.now();

        while (true) {
            // 检查任务状态
            const task = this.taskStateMap.get(id);
            if (task && task.state === 2) {
                console.log(`Task ${id} has been accepted.`);
                return true; // 任务已被接受，返回 true
            }

            // 检查是否超时
            if (Date.now() - startTime > timeout) {
                console.log(`Timeout reached while waiting for Task ${id} to be accepted.`);
                return false; // 超时，返回 false
            }

            // 等待一段时间再继续检查
            await new Promise((resolve) => setTimeout(resolve, interval));
        }
    }
}

