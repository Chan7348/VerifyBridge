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

    // 5s扫一次事件，记录所有TaskCreated事件和TaskAccepted事件
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

    public startProcessing() {
        console.log("start processing...");

        // 添加一个锁，避免并发处理
        let isProcessing = false;

        setInterval(async () => {
            if (isProcessing) {
                return;
            }
            isProcessing = true; // 上锁

            try {
                // 从队列中取出一个任务
                const id = Array.from(this.idQueue.values())[0];
                if (!id) {
                    isProcessing = false; // 解锁
                    return;
                }

                // 从任务状态映射中获取任务详情
                const task = this.taskStateMap.get(id);
                if (!task || task.state !== 1) {
                    console.log(`Task ${id} is not in a valid state for processing.`);
                    this.idQueue.delete(id); // 从队列中移除无效任务
                    isProcessing = false; // 解锁
                    return;
                }

                await this.sendTx(id, this.compute());
                console.log(`Task ${id} successfully sent to the chain.`);

                const accepted = await this.waitForTaskAccepted(id);
                if (!accepted) {
                    console.error(`Task ${id} has not been accepted.`);
                    this.idQueue.add(id); // 重新加入队列
                }
                console.log("--------------------------------");
            } catch (err) {
                console.error(`Error processing Task: ${err}`);
            } finally {
                isProcessing = false; // 解锁
            }
        }, this.interval);
    }

    public async sendTx(id: bigint, result: string): Promise<void> {
        const tx = await this.contract.submitResult(id, result);
        await tx.wait();
        console.log(`Tx confirmed: ${tx.hash}`);
    }

    public compute(): string {
        return ethers.keccak256(ethers.toUtf8Bytes("1"));
    }

    private async waitForTaskAccepted(id: bigint, timeout = 30000, interval = 2000): Promise<boolean> {
        const startTime = Date.now();

        return new Promise((resolve) => {
            const checkTaskAccepted = () => {
                const task = this.taskStateMap.get(id);
                if (task && task.state === 2) {
                    resolve(true);
                    return;
                }

                if (Date.now() - startTime > timeout) {
                    resolve(false);
                    return;
                }

                setTimeout(checkTaskAccepted, interval);
            }
            checkTaskAccepted();
        })
    }
}

