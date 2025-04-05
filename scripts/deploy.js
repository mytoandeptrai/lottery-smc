const hre = require("hardhat");

async function main() {
   try {
      console.log("Deploying DLottery contract...");

      // Get the contract factory
      const DLottery = await hre.ethers.getContractFactory("DLottery");

      // Deploy the contract
      const lottery = await DLottery.deploy();

      // Wait for deployment to finish
      await lottery.waitForDeployment();

      const lotteryAddress = await lottery.getAddress();
      console.log("DLottery deployed to:", lotteryAddress);

      // Verify the contract on Etherscan (if on a public network)
      if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
         console.log("Waiting for block confirmations...");
         
         // In ethers v6, we need to wait for confirmations differently
         // Wait for 6 blocks to be mined
         await new Promise(resolve => setTimeout(resolve, 30000)); // Wait 30 seconds for blocks to be mined
         
         console.log("Verifying contract on Etherscan...");
         await hre.run("verify:verify", {
            address: lotteryAddress,
            constructorArguments: [],
         });
      }
   } catch (error) {
      console.error("Deployment failed:", error);
   }
}

main().catch((error) => {
   console.error(error);
   process.exitCode = 1;
});
