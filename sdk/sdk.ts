import { ethers } from "ethers";
import { VerifyBridge } from "../typechain-types";
import { VerifyBridge__factory } from "../typechain-types";

export class VerifyBridgeSDK {
    private provider: ethers.JsonRpcProvider;
    private contract: VerifyBridge;
    private signer: ethers.Signer;

    constructor(providerURL: string, contractAddress: string, privateKey: string) {
        this.provider = new ethers.JsonRpcProvider(providerURL);
        this.signer = new ethers.Wallet(privateKey, this.provider);

        this.contract = VerifyBridge__factory.connect(contractAddress, this.signer);
    }

    public async getNextTaskId(): Promise<bigint> {
        try {
            const nextTaskId = await this.contract.nextTaskId(await this.signer.getAddress());
            return nextTaskId;
        } catch (error) {
            console.error("Error fetching next task ID:", error);
            throw error;
        }
    }

    public async request(rawData: string, lifecycle: number): Promise<ethers.ContractTransactionResponse> {
        try {
            const nextTaskId = await this.getNextTaskId();
            const rawDataHash = ethers.keccak256(ethers.toUtf8Bytes(rawData));
            const abiEncoder = ethers.AbiCoder.defaultAbiCoder();
            const inputData = ethers.keccak256(
                abiEncoder.encode(
                    ["uint256", "bytes32"],
                    [nextTaskId, rawDataHash]
                )
            );

            const tx = await this.contract.requestCompute(inputData, lifecycle);

            await tx.wait();
            console.log(`Task ${nextTaskId} has been successfully created.`);
            return tx;
        } catch (error) {
            console.error("Error during compute request:", error);
            throw error;
        }
    }
}