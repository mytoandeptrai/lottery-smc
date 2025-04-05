const hre = require("hardhat");

async function main() {
  // Get the contract address from command line arguments
  const contractAddress = process.argv[2];
  if (!contractAddress) {
    console.error("Please provide the contract address as an argument");
    process.exit(1);
  }

  console.log(`Interacting with DLottery at address: ${contractAddress}`);

  // Get the contract
  const DLottery = await hre.ethers.getContractFactory("DLottery");
  const lottery = DLottery.attach(contractAddress);

  // Get signers
  const [owner, addr1, addr2, addr3, addr4, addr5] = await hre.ethers.getSigners();

  // Get contract state
  const ticketPrice = await lottery.getTicketPrice();
  const participantCount = await lottery.getParticipantCount();
  const isDrawCompleted = await lottery.isDrawCompleted();
  const currentPrize = await lottery.getCurrentPrize();
  const lotteryState = await lottery.getLotteryState();

  console.log("\nContract State:");
  console.log(`Ticket Price: ${hre.ethers.formatEther(ticketPrice)} ETH`);
  console.log(`Participant Count: ${participantCount}`);
  console.log(`Draw Completed: ${isDrawCompleted}`);
  console.log(`Current Prize: ${hre.ethers.formatEther(currentPrize)} ETH`);
  console.log(`Lottery State: ${lotteryState}`);

  // Check if there's an active draw
  if (!isDrawCompleted) {
    console.log("\nThere is an active draw. You can buy tickets.");
    
    // Example: Buy a ticket
    try {
      const tx = await lottery.connect(addr1).buyTicket({ value: ticketPrice });
      await tx.wait();
      console.log(`Ticket purchased by ${addr1.address}`);
    } catch (error) {
      console.error("Error buying ticket:", error.message);
    }
  } else {
    console.log("\nThere is no active draw. You can start a new one.");
    
    // Example: Start a new draw
    try {
      const futureTimestamp = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      const tx = await lottery.startNewDraw(futureTimestamp);
      await tx.wait();
      console.log(`New draw started with end time: ${new Date(futureTimestamp * 1000).toLocaleString()}`);
    } catch (error) {
      console.error("Error starting new draw:", error.message);
    }
  }

  // Check if there's a winner
  const winner = await lottery.getWinner();
  if (winner !== hre.ethers.ZeroAddress) {
    console.log(`\nWinner: ${winner}`);
    
    // Check if prize has been withdrawn
    const isPrizeWithdrawn = await lottery.isPrizeWithdrawn();
    if (!isPrizeWithdrawn) {
      console.log("Prize has not been withdrawn yet.");
      
      // Example: Withdraw prize (only works if you're the winner)
      try {
        const tx = await lottery.connect(winner).withdrawPrize();
        await tx.wait();
        console.log(`Prize withdrawn by ${winner}`);
      } catch (error) {
        console.error("Error withdrawing prize:", error.message);
      }
    } else {
      console.log("Prize has already been withdrawn.");
    }
  } else {
    console.log("\nNo winner selected yet or no participants.");
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 