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
        // 检查最新的100个块
        const events = await this.contract.queryFilter(filter, 7351272, latestBlock);
        console.log(`events number: ${events.length}`)
        for (const event of events) {
            const abicoder = new ethers.AbiCoder();
            const decoded = abicoder.decode(["address", "uint256", "bytes32"], event.data);
            const requester = decoded[0];
            const taskId = decoded[1];
            const inputData = decoded[2];
            console.log(`TaskCreated Event Detected - Requester: ${requester}, TaskID: ${taskId}, InputData: ${inputData}`);

            // Execute task
            await this.executeTask(requester, taskId, inputData);
        }
    }

    private async executeTask(requester: ethers.AddressLike, taskId: BigNumberish, inputData: string): Promise<void> {
        console.log(`Executing task for TaskID: ${taskId}`);
        try {
            const result = this.compute("1");
            console.log(`Task ${taskId} computed with result: ${result}`);
            const abicoder = new ethers.AbiCoder();
            const inputData = ethers.keccak256(abicoder.encode(["uint256", "bytes32"], [taskId, result]));
            console.log("inputData:", inputData);
            const tx = await this.contract.submitResult(requester, taskId, result);
            await tx.wait();
            console.log(`Task ${taskId} successfully submitted with result: ${result}`);
        } catch (error) {
            console.error(`Error executing task ${taskId}:`, error);
        }
    }

    private compute(rawData: string): BytesLike {
        // return ethers.encodeBytes32String("test1");
        return ethers.keccak256(ethers.toUtf8Bytes(rawData));
    }
}