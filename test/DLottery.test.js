const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DLottery", function () {
    let DLottery;
    let lottery;
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let addr4;
    let addr5;
    let addr6;
    let addrs;

    const TICKET_PRICE = ethers.parseEther("0.001");
    const MAX_PARTICIPANTS = 5;
    const MAX_TICKETS = 10;

    beforeEach(async function () {
        // Deploy a new contract before each test
        [owner, addr1, addr2, addr3, addr4, addr5, addr6, ...addrs] = await ethers.getSigners();
        DLottery = await ethers.getContractFactory("DLottery");
        lottery = await DLottery.deploy();
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await lottery.isOwner(owner.address)).to.be.true;
        });

        it("Should initialize with correct values", async function () {
            expect(await lottery.getTicketPrice()).to.equal(TICKET_PRICE);
            expect(await lottery.getParticipantCount()).to.equal(0);
            expect(await lottery.isDrawCompleted()).to.be.true;
            expect(await lottery.getCurrentPrize()).to.equal(0);
            expect(await lottery.isPrizeWithdrawn()).to.be.true;
        });

        it("Should have correct initial state", async function () {
            expect(await lottery.getLotteryState()).to.equal("READY_FOR_NEW_DRAW");
        });
    });

    describe("Lottery Operations", function () {
        beforeEach(async function () {
            // Start a new draw before each test
            const futureTimestamp = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
            await lottery.startNewDraw(futureTimestamp);
        });

        describe("Buying Tickets", function () {
            it("Should allow buying a ticket with correct price", async function () {
                await lottery.connect(addr1).buyTicket({ value: TICKET_PRICE });
                await lottery.getUserTicket(addr1.address);
                
                await expect(lottery.connect(addr1).buyTicket({ value: TICKET_PRICE }))
                    .to.be.revertedWith("You already bought a ticket");

                expect(await lottery.getParticipantCount()).to.equal(1);
                expect(await lottery.isRegistered(addr1.address)).to.be.true;
            });

            it("Should reject ticket purchase with incorrect price", async function () {
                const wrongPrice = ethers.parseEther("0.002");
                await expect(
                    lottery.connect(addr1).buyTicket({ value: wrongPrice })
                ).to.be.revertedWith("Incorrect ticket price");
            });

            it("Should prevent double registration", async function () {
                await lottery.connect(addr1).buyTicket({ value: TICKET_PRICE });
                await expect(
                    lottery.connect(addr1).buyTicket({ value: TICKET_PRICE })
                ).to.be.revertedWith("You already bought a ticket");
            });

            it("Should limit participants to MAX_PARTICIPANTS", async function () {
                // Buy tickets for MAX_PARTICIPANTS
                for (let i = 0; i < MAX_PARTICIPANTS; i++) {
                    const addr = [addr1, addr2, addr3, addr4, addr5][i];
                    await lottery.connect(addr).buyTicket({ value: TICKET_PRICE });
                }

                // Try to buy one more ticket
                await expect(
                    lottery.connect(addr6).buyTicket({ value: TICKET_PRICE })
                ).to.be.revertedWith("Max participants reached");
            });

            it("Should accumulate prize pool correctly", async function () {
                await lottery.connect(addr1).buyTicket({ value: TICKET_PRICE });
                expect(await lottery.getCurrentPrize()).to.equal(TICKET_PRICE);

                await lottery.connect(addr2).buyTicket({ value: TICKET_PRICE });
                expect(await lottery.getCurrentPrize()).to.equal(TICKET_PRICE * 2n);
            });
        });

        describe("Performing Draw", function () {
            beforeEach(async function () {
                // Buy tickets for all participants
                for (let i = 0; i < MAX_PARTICIPANTS; i++) {
                    const addr = [addr1, addr2, addr3, addr4, addr5][i];
                    await lottery.connect(addr).buyTicket({ value: TICKET_PRICE });
                }
            });

            it("Should only allow owner to perform draw", async function () {
                await expect(
                    lottery.connect(addr1).performDraw()
                ).to.be.revertedWith("Not owner");
            });

            it("Should emit correct events on draw", async function () {
                const tx = await lottery.performDraw();
                const receipt = await tx.wait();

                // Check if either DrawResult or NoWinner event was emitted
                const drawResultEvent = receipt.logs.find(
                    log => log.fragment && log.fragment.name === "DrawResult"
                );
                const noWinnerEvent = receipt.logs.find(
                    log => log.fragment && log.fragment.name === "NoWinner"
                );

                expect(drawResultEvent || noWinnerEvent).to.not.be.undefined;
            });

            it("Should mark draw as completed after draw", async function () {
                await lottery.performDraw();
                expect(await lottery.isDrawCompleted()).to.be.true;
            });

            it("Should store draw result correctly", async function () {
                const tx = await lottery.performDraw();
                const receipt = await tx.wait();
                const completedDrawIds = await lottery.getCompletedDrawIds();
                
                const storedResult = await lottery.getDrawResult(completedDrawIds[0]);
                expect(storedResult.drawId).to.equal(completedDrawIds[0]);
                
                // Get the winner from the event
                const drawResultEvent = receipt.logs.find(
                    log => log.fragment && log.fragment.name === "DrawResult"
                );
                
                if (drawResultEvent) {
                    const winner = drawResultEvent.args.winner;
                    expect(storedResult.winnerAddress).to.equal(winner);
                    expect(storedResult.hasWinner).to.be.true;
                } else {
                    expect(storedResult.winnerAddress).to.equal(ethers.ZeroAddress);
                    expect(storedResult.hasWinner).to.be.false;
                }
            });

            it("Should track completed draw IDs", async function () {
                await lottery.performDraw();
                const completedDrawIds = await lottery.getCompletedDrawIds();
                expect(completedDrawIds.length).to.be.greaterThan(0);
            });

            it("Should return latest draw result", async function () {
                await lottery.performDraw();
                const latestResult = await lottery.getLatestDrawResult();
                const completedDrawIds = await lottery.getCompletedDrawIds();
                const lastDrawId = completedDrawIds[completedDrawIds.length - 1];
                
                expect(latestResult.drawId).to.equal(lastDrawId);
            });
        });

        describe("Prize Withdrawal", function () {
            beforeEach(async function () {
                // Complete a draw with a winner
                for (let i = 0; i < MAX_PARTICIPANTS; i++) {
                    const addr = [addr1, addr2, addr3, addr4, addr5][i];
                    await lottery.connect(addr).buyTicket({ value: TICKET_PRICE });
                }
                await lottery.performDraw();
            });

            it("Should only allow winner to withdraw prize", async function () {
                const winner = await lottery.getWinner();
                if (winner !== ethers.ZeroAddress) {
                    await expect(
                        lottery.connect(addr1).withdrawPrize()
                    ).to.be.revertedWith("Not the winner");
                } else {
                    this.skip();
                }
            });
        });
    });

    describe("Admin Operations", function () {
        it("Should allow owner to pause contract", async function () {
            await lottery.pause();
            const futureTimestamp = Math.floor(Date.now() / 1000) + 3600;
            await lottery.startNewDraw(futureTimestamp);
            
            await expect(
                lottery.connect(addr1).buyTicket({ value: TICKET_PRICE })
            ).to.be.revertedWith("Contract is paused");
        });

        it("Should allow owner to unpause contract", async function () {
            await lottery.pause();
            await lottery.unpause();
            
            const futureTimestamp = Math.floor(Date.now() / 1000) + 3600;
            await lottery.startNewDraw(futureTimestamp);
            
            await expect(
                lottery.connect(addr1).buyTicket({ value: TICKET_PRICE })
            ).to.not.be.reverted;
        });

        it("Should allow owner to change ticket price", async function () {
            const newPrice = ethers.parseEther("0.002");
            await lottery.setTicketPrice(newPrice);
            expect(await lottery.getTicketPrice()).to.equal(newPrice);
        });

        it("Should prevent changing ticket price during active draw", async function () {
            const futureTimestamp = Math.floor(Date.now() / 1000) + 3600;
            await lottery.startNewDraw(futureTimestamp);
            
            const newPrice = ethers.parseEther("0.002");
            await expect(
                lottery.setTicketPrice(newPrice)
            ).to.be.revertedWith("Cannot change price during active lottery");
        });
    });

    describe("Edge Cases", function () {
        it("Should handle no winner scenario correctly", async function () {
            const futureTimestamp = Math.floor(Date.now() / 1000) + 3600;
            await lottery.startNewDraw(futureTimestamp);
            
            for (let i = 0; i < MAX_PARTICIPANTS; i++) {
                const addr = [addr1, addr2, addr3, addr4, addr5][i];
                await lottery.connect(addr).buyTicket({ value: TICKET_PRICE });
            }
            
            await lottery.performDraw();
            const winner = await lottery.getWinner();
            
            if (winner === ethers.ZeroAddress) {
                expect(await lottery.isPrizeWithdrawn()).to.be.true;
                expect(await lottery.getLotteryState()).to.equal("READY_FOR_NEW_DRAW");
            }
        });
    });
}); 