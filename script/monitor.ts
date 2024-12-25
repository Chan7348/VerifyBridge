import { Computer } from "../sdk/computer";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
    try {
        const rpc = process.env.ETHEREUM_SEPOLIA_RPC;
        const contractAddress = "0x39E1C7168614A6b92f1711221Ac40F4362F344BA";
        const privateKey = process.env.near2;

        const computer = new Computer(rpc!, contractAddress, privateKey!);
        computer.startMonitoring();
    } catch (error) {
        console.error("Failed to start monitoring:", error);
    }
}

main().catch((error) => {
    console.error("Unexpected error:", error);
});