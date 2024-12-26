import { BigNumberish, ethers } from "ethers";
import { VerifyBridge } from "../typechain-types";
import { VerifyBridge__factory } from "../typechain-types";

interface TaskDetails {
    state: number; // 0: 未检测, 1: 未计算完成, 2: 已计算完成
    inputData: string; // 任务的 inputData
}

// 50s扫一次事件，记录所有TaskCreated事件和TaskAccepted事件。
// 如果有新的任务，则将任务加入队列

export class Monitor {
    public provider: ethers.JsonRpcProvider;
    public contract: VerifyBridge;
    public interval: number;

    public idQueue: Set<bigint> = new Set<bigint>; // 只储存状态为1的任务ID
    public taskStateMap: Map<bigint, TaskDetails> = new Map<bigint, TaskDetails>(); // 储存任务状态

    public abicoder = new ethers.AbiCoder();

    constructor(providerURL: string, contractAddress: string, privateKey: string, interval: number = 5000) {
        this.provider = new ethers.JsonRpcProvider(providerURL);
        const signer = new ethers.Wallet(privateKey, this.provider);
        this.contract = VerifyBridge__factory.connect(contractAddress, signer);
        this.interval = interval;
    }

    // 5s扫一次事件，记录所有TaskCreated事件和TaskAccepted事件
    public startMonitoring() {
        console.log("start monitoring...");

        this.contract.on(this.contract.getEvent("TaskCreated"), (taskId, inputData) => {
            console.log(`Captured TaskCreated event, id:${taskId}, inputData: ${inputData}`);
            if (this.taskStateMap.has(taskId)) return;

            this.idQueue.add(taskId);
            this.taskStateMap.set(taskId, { state: 1, inputData: inputData });

            console.log(`Task ${taskId} added to queue with InputData=${inputData}`);
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

        setInterval(async () => {
            const id = Array.from(this.idQueue.values())[0];
            if (!id) {
                return;
            } else {
                this.idQueue.delete(id);
            }

            const task = this.taskStateMap.get(id);
            if (!task || task.state !== 1) return; // 任务状态不为1，不处理

            console.log(`Processing Task: TaskID=${id}, InputData=${task.inputData}`);

            try {
                const result = this.compute();
                console.log(`Task ${id} has been computed, result: ${result}`);

                await this.sendTx(id, result);
                console.log(`Task ${id} has been sent to the chain.`);
            } catch (err) {
                console.error(`Error processing Task ${id}:`, err);
                this.idQueue.delete(id);
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
}

