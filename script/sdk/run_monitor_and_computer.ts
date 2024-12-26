import { Monitor } from "../../sdk/monitor";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
    try {
        const rpc = process.env.ETHEREUM_SEPOLIA_RPC!;
        const contractAddress = "0x9e3cDdcf8Ee5322D3674e027FD6504b9eD77a37B";
        const privateKey = process.env.near2!;

        const monitor = new Monitor(rpc, contractAddress, privateKey);

        monitor.startMonitoring();
        monitor.startProcessing();
    } catch (error) {
        console.error("Failed to start Monitor and Computer:", error);
    }
}

// Run the main function
main().catch((error) => {
    console.error("Unexpected error in main:", error);
});