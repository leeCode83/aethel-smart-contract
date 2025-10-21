// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {WUSDT} from "../src/aethel/WUSDT.sol";
import {AethelFactory} from "../src/aethel/AethelFactory.sol";
import {AethelMarketplace} from "../src/marketplace/AethelMarketplace.sol";

contract DeployAethelScript is Script {
    // Kontrak yang akan di-deploy
    WUSDT public wusdt;
    AethelFactory public factory;
    AethelMarketplace public marketplace;

    function run() public {
        // --- 1. SETUP ---
        console.log(
            "Starting Aethel Protocol deployment to Sepolia Testnet..."
        );
        console.log("");

        // Ambil private key dari environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY not set. Please set it in your .env file");
        }
        address deployer = vm.addr(deployerPrivateKey);
        address daoAddress = deployer; // Gunakan alamat deployer sebagai placeholder untuk DAO

        // --- 2. TAMPILKAN INFORMASI DEPLOYMENT ---
        console.log("Deployment Details:");
        console.log("  - Deployer address:", deployer);

        uint256 balance = deployer.balance;
        console.log("  - Deployer balance:", balance / 1e18, "ETH");

        if (balance < 0.05 ether) {
            console.log(
                "Warning: Low balance. Deployment might fail. Please ensure you have enough Sepolia ETH."
            );
        }

        console.log("  - Network: Sepolia Testnet");
        console.log("  - Chain ID: 11155111");
        console.log("");

        // --- 3. PROSES DEPLOYMENT ---
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying WUSDT contract...");
        wusdt = new WUSDT();
        console.log("WUSDT deployed at:", address(wusdt));
        console.log("---");

        console.log("Deploying AethelFactory contract...");
        factory = new AethelFactory(address(wusdt), daoAddress);
        console.log("AethelFactory deployed at:", address(factory));
        console.log("---");

        console.log("Deploying AethelMarketplace contract...");
        marketplace = new AethelMarketplace(address(wusdt), address(factory));
        console.log("AethelMarketplace deployed at:", address(marketplace));

        vm.stopBroadcast();

        // --- 4. TAMPILKAN HASIL AKHIR ---
        console.log("");
        console.log("Aethel Protocol Deployment Successful!");
        console.log("======================================");
        console.log("Deployed Contract Addresses:");
        console.log("  - WUSDT:", address(wusdt));
        console.log("  - AethelFactory:", address(factory));
        console.log("  - AethelMarketplace:", address(marketplace));
        console.log("  - Deployer/DAO Address:", deployer);
        console.log("======================================");
    }
}
