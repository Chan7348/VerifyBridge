import { Requester } from "../sdk/requester";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
    try {
        const rpc = process.env.ETHEREUM_SEPOLIA_RPC;
        const contractAddress = "";
        const privateKey = process.env.near1;

        const requester = new Requester(rpc!, contractAddress, privateKey!);

        const rawData = "This is a test compute task";
        const lifecycle = 30 * 24 * 3600; // 30天

        console.log("Publishing a new compute task...");
        const tx = await requester.request(rawData, lifecycle);

        console.log("Compute task successfully published!");
        console.log(`Transaction Hash: ${tx.hash}`);
    } catch (error) {
        console.error("Error publishing compute task:", error);
    }
}

main().catch((error) => {
    console.error("Unhandled error:", error);
    process.exit(1);
});