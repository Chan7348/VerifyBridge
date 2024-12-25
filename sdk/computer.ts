import { Address } from './../typechain-types/@openzeppelin/contracts/utils/Address';
import { BigNumberish, BytesLike, ethers } from "ethers";
import { VerifyBridge } from "../typechain-types";
import { VerifyBridge__factory } from "../typechain-types";

export class Computer {
    private provider: ethers.JsonRpcProvider;
    private contract: VerifyBridge;
    private signer: ethers.Signer;
    private interval: number;

    constructor(providerURL: string, contractAddress: string, privateKey: string, interval: number = 5000) {
        this.provider = new ethers.JsonRpcProvider(providerURL);
        this.signer = new ethers.Wallet(privateKey, this.provider);

        this.contract = VerifyBridge__factory.connect(contractAddress, this.signer);
        this.interval = interval;
    }

    public startMonitoring(): void {
        console.log("Starting monitor...");
        setInterval(async() => {
            try {
                await this.pollEvents();
            } catch (error) {
                console.error("Error during event polling", error);
            }
        }, this.interval);
    }

    private async pollEvents(): Promise<void> {
        console.log("Polling for new events...");
        const latestBlock = await this.provider.getBlockNumber();
        console.log("Latest block:", latestBlock);

        const filter = this.contract.filters.TaskCreated();
        // 检查最新的10个块
        const events = await this.contract.queryFilter(filter, latestBlock - 10, latestBlock);

        for (const event of events) {
            const { requester, taskId, inputData } = event.args;
            console.log(`TaskCreated Event Detected - Requester: ${requester}, TaskID: ${taskId}, InputData: ${inputData}`);

            // Execute task
            await this.executeTask(requester, taskId, inputData);
        }
    }

    private async executeTask(requester: ethers.AddressLike, taskId: BigNumberish, inputData: string): Promise<void> {
        console.log(`Executing task for TaskID: ${taskId}`);
        try {
            const result = this.compute();

            const tx = await this.contract.submitResult(requester, taskId, result);
            await tx.wait();
            console.log(`Task ${taskId} successfully submitted with result: ${result}`);
        } catch (error) {
            console.error(`Error executing task ${taskId}:`, error);
        }
    }

    private compute(): BytesLike {
        return ethers.keccak256("");
    }
}