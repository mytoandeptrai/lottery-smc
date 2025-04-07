// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DLottery
 * @dev A decentralized lottery system
 */
contract DLottery {
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    // --- Lottery Core State ---
    uint256 private drawId;                      // Current lottery draw ID
    uint256 private nextDrawTimestamp;           // Timestamp for the next draw
    uint256 private currentPrize;                // Current prize pool amount
    bool private drawCompleted;                  // Whether the current draw is completed
    address private winner;                      // Address of the current draw winner
    
    // --- Lottery Configuration ---
    uint256 private constant MAX_PARTICIPANTS = 5;        // Maximum number of participants per draw
    uint256 private constant MAX_AVAILABLE_TICKETS = 10;  // Maximum tickets available per draw
    uint256 private ticketPrice = 0.001 ether;            // Price per ticket
    
    // --- Ticket Management ---
    uint256[] private availableTickets;                   // Available ticket numbers
    mapping(uint256 => address) private ticketToParticipant;  // Maps ticket numbers to participant addresses
    mapping(address => bool) private isParticipant;       // Track if address has participated
    uint256 private participantCount;                     // Number of participants in current draw
    
    // --- Contract Administration ---
    address private owner;                       // Contract owner address
    bool private paused;                         // Paused state
    
    // --- Security Management ---
    bool private locked;                         // Reentrancy guard
    bool private prizeWithdrawn;                 // Whether the prize has been withdrawn
    
    // --- Draw History Management ---
    struct DrawPerformResult {
        uint256 drawId;
        uint256 winningTicket;
        address winnerAddress;
        bool hasWinner;
    }
    
    mapping(uint256 => DrawPerformResult) private drawResults;  // Maps draw IDs to their results
    uint256[] private completedDrawIds;                         // Array of completed draw IDs
    
    // ============================================
    // EVENTS
    // ============================================
    event DrawCreated(uint256 indexed drawId, uint256 prize, uint256 drawTime);
    event ParticipantRegistered(uint256 indexed drawId, address participant, uint256 ticketNumber);
    event DrawResult(uint256 indexed drawId, uint256 winningTicket, address winner);
    event PrizeWithdrawn(uint256 indexed drawId, address winner, uint256 amount);
    event NewLotteryStarted(uint256 indexed drawId);
    event NoWinner(uint256 indexed drawId, uint256 winningTicket);
    
    // ============================================
    // MODIFIERS
    // ============================================
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    modifier nonReentrant() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    constructor() {
        owner = msg.sender;
        drawId = 1;
        drawCompleted = true;
        participantCount = 0;
        prizeWithdrawn = true;
    }
    
    // ============================================
    // EXTERNAL FUNCTIONS - CORE LOTTERY OPERATIONS
    // ============================================
    
    /**
     * @dev Starts a new lottery draw
     * @param timestamp The timestamp for the draw
     */
    function startNewDraw(uint256 timestamp) external payable {
        require(drawCompleted, "Previous lottery still in progress");
        // Only allow starting a new draw when there's no winner or the prize has been withdrawn
        require(winner == address(0) || prizeWithdrawn, "Previous winner has not claimed the prize yet");
        
        // Reset winner
        winner = address(0);
        
        if (currentPrize == 0) {
            currentPrize = msg.value;
        } else {
            currentPrize += msg.value;
        }

        nextDrawTimestamp = timestamp;
        drawCompleted = false;
        prizeWithdrawn = false;

        // Reset participant statuses
        for (uint256 i = 1; i <= MAX_AVAILABLE_TICKETS; i++) {
            address participant = ticketToParticipant[i];
            if (participant != address(0)) {
                isParticipant[participant] = false;
                ticketToParticipant[i] = address(0);
            }
        }

        // Reset available tickets
        delete availableTickets;
        for (uint256 i = 1; i <= MAX_AVAILABLE_TICKETS; i++) {
            availableTickets.push(i);
        }

        participantCount = 0;

        emit NewLotteryStarted(drawId);
    }

    /**
     * @dev Allows a user to buy a ticket for the current draw
     */
    function buyTicket() public payable whenNotPaused {
        require(!drawCompleted, "No active lottery");
        require(!isParticipant[msg.sender], "You already bought a ticket");
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(participantCount < MAX_PARTICIPANTS, "Max participants reached");
        require(availableTickets.length > 0, "No available tickets left");

        uint256 ticketNumber = _getRandomTicket();

        ticketToParticipant[ticketNumber] = msg.sender;
        isParticipant[msg.sender] = true;

        currentPrize += msg.value;

        participantCount++;

        _removeTicketFromAvailable(ticketNumber);

        emit ParticipantRegistered(drawId, msg.sender, ticketNumber);
    }

    /**
     * @dev Executes the lottery draw to determine a winner
     * @return The draw result
     */
    function performDraw() external onlyOwner nonReentrant returns (DrawPerformResult memory) {
        require(participantCount == MAX_PARTICIPANTS, "Not enough participants");
        require(!drawCompleted, "Lottery already completed");

        uint256 winningTicket = _getRandomTicketForDraw();
        address winnerAddress = ticketToParticipant[winningTicket];
        winner = winnerAddress;
        drawCompleted = true;
        
        DrawPerformResult memory result;
        
        if (winnerAddress != address(0)) {
            // Store the result
            result = DrawPerformResult({
                drawId: drawId,
                winningTicket: winningTicket,
                winnerAddress: winnerAddress,
                hasWinner: true
            });
            
            // Save the result in storage
            drawResults[drawId] = result;
            completedDrawIds.push(drawId);
            
            emit DrawResult(drawId, winningTicket, winnerAddress);
        } else {
            // Case where there's no winner
            result = DrawPerformResult({
                drawId: drawId,
                winningTicket: winningTicket,
                winnerAddress: address(0),
                hasWinner: false
            });
            
            // Save the result in storage
            drawResults[drawId] = result;
            completedDrawIds.push(drawId);
            
            emit NoWinner(drawId, winningTicket);
            
            // Prepare for the next round
            winner = address(0);
            prizeWithdrawn = true; // Allow starting a new draw
            drawId += 1;
        }
        
        return result;
    }

    /**
     * @dev Allows the winner to withdraw their prize
     */
    function withdrawPrize() external nonReentrant {
        require(drawCompleted, "Draw not completed");
        require(winner == msg.sender, "Not the winner");
        require(currentPrize > 0, "No prize to withdraw");
        require(!prizeWithdrawn, "Prize already withdrawn");

        uint256 prize = currentPrize;
        currentPrize = 0;
        prizeWithdrawn = true;

        // Increment drawId and reset state for a new draw
        drawId += 1;
        
        (bool sent, ) = payable(msg.sender).call{value: prize}("");
        require(sent, "Failed to send prize");

        emit PrizeWithdrawn(drawId - 1, msg.sender, prize);
    }
    
    // ============================================
    // EXTERNAL FUNCTIONS - ADMIN OPERATIONS
    // ============================================
    
    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        paused = true;
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        paused = false;
    }

    /**
     * @dev Sets a new ticket price
     * @param _ticketPrice The new ticket price
     */
    function setTicketPrice(uint256 _ticketPrice) external onlyOwner {
        require(drawCompleted, "Cannot change price during active lottery");
        ticketPrice = _ticketPrice;
    }
    
    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================
    
    /**
     * @dev Generates a random ticket number for the draw
     * @return A random ticket number between 1 and MAX_AVAILABLE_TICKETS
     */
    function _getRandomTicketForDraw() internal view returns (uint256) {
        return (_getRandomNumber() % MAX_AVAILABLE_TICKETS) + 1;
    }

    /**
     * @dev Removes a ticket from the available tickets array
     * @param ticketNumber The ticket number to remove
     */
    function _removeTicketFromAvailable(uint256 ticketNumber) internal {
        for (uint256 i = 0; i < availableTickets.length; i++) {
            if (availableTickets[i] == ticketNumber) {
                availableTickets[i] = availableTickets[availableTickets.length - 1];
                availableTickets.pop();
                break;
            }
        }
    }

    /**
     * @dev Selects a random ticket from available tickets
     * @return A random available ticket number
     */
    function _getRandomTicket() internal view returns (uint256) {
        require(availableTickets.length > 0, "No available tickets left");

        uint256 randomIndex = _getRandomNumber() % availableTickets.length;
        return availableTickets[randomIndex];
    }

    /**
     * @dev Generates a pseudo-random number
     * @return A pseudo-random uint256 value
     */
    function _getRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
    }
    
    // ============================================
    // EXTERNAL VIEW FUNCTIONS - GETTERS
    // ============================================
    
    /**
     * @dev Returns the result of a specific draw
     * @param _drawId The ID of the draw to query
     * @return The draw result
     */
    function getDrawResult(uint256 _drawId) external view returns (DrawPerformResult memory) {
        require(_drawId > 0 && _drawId <= drawId, "Invalid draw ID");
        require(drawResults[_drawId].drawId == _drawId, "Draw result not found");
        
        return drawResults[_drawId];
    }
    
    /**
     * @dev Returns the result of the latest completed draw
     * @return The latest draw result
     */
    function getLatestDrawResult() external view returns (DrawPerformResult memory) {
        require(completedDrawIds.length > 0, "No completed draws yet");
        
        uint256 latestCompletedDrawId = completedDrawIds[completedDrawIds.length - 1];
        return drawResults[latestCompletedDrawId];
    }
    
    /**
     * @dev Returns all completed draw IDs
     * @return Array of completed draw IDs
     */
    function getCompletedDrawIds() external view returns (uint256[] memory) {
        return completedDrawIds;
    }
    
    /**
     * @dev Returns whether the prize has been withdrawn
     * @return Prize withdrawal status
     */
    function isPrizeWithdrawn() external view returns (bool) {
        return prizeWithdrawn;
    }

    /**
     * @dev Returns a random ticket (for testing purposes)
     * @return A random ticket number
     */
    function getRandomTicket() external view returns (uint256) {
        return _getRandomTicket();
    }

    /**
     * @dev Returns the current number of participants
     * @return Number of participants
     */
    function getParticipantCount() external view returns (uint256) {
        return participantCount;
    }

    /**
     * @dev Returns the current winner address
     * @return Address of the winner
     */
    function getWinner() external view returns (address) {
        return winner;
    }

    /**
     * @dev Returns the current prize amount
     * @return Current prize in wei
     */
    function getCurrentPrize() external view returns (uint256) {
        return currentPrize;
    }

    /**
     * @dev Returns whether the current draw is completed
     * @return Draw completion status
     */
    function isDrawCompleted() external view returns (bool) {
        return drawCompleted;
    }

    /**
     * @dev Returns whether a user has registered for the current draw
     * @param user Address to check
     * @return Registration status
     */
    function isRegistered(address user) external view returns (bool) {
        return isParticipant[user];
    }

    /**
     * @dev Checks if the provided address is the contract owner
     * @param user Address to check
     * @return Whether the address is the owner
     */
    function isOwner(address user) external view returns (bool) {
        return user == owner;
    }

    /**
     * @dev Returns the ticket price
     * @return Ticket price in wei
     */
    function getTicketPrice() external view returns (uint256) {
        return ticketPrice;
    }

    /**
     * @dev Returns the ticket number for a given user
     * @param user Address of the user
     * @return Ticket number
     */
    function getUserTicket(address user) external view returns (uint256) {
        require(isParticipant[user], "User has not participated");

        for (uint256 i = 1; i <= MAX_AVAILABLE_TICKETS; i++) {
            if (ticketToParticipant[i] == user) {
                return i;
            }
        }
        revert("Ticket not found for the user");
    }

    /**
     * @dev Returns the current lottery state as a string
     * @return String representation of the lottery state
     */
    function getLotteryState() external view returns (string memory) {
        if (drawCompleted) {
            if (winner != address(0) && !prizeWithdrawn) {
                return "WAITING_FOR_PRIZE_CLAIM";
            } else if (prizeWithdrawn || winner == address(0)) {
                return "READY_FOR_NEW_DRAW";
            }
        } else {
            return "IN_PROGRESS";
        }
        
        return "UNKNOWN";
    }

    /**
     * @dev Returns all participants in the current draw
     * @return Array of participant addresses
     */
    function getParticipants() external view returns (address[] memory) {
        // Count actual participants
        uint256 count = 0;
        for (uint256 i = 1; i <= MAX_AVAILABLE_TICKETS; i++) {
            if (ticketToParticipant[i] != address(0)) {
                count++;
            }
        }

        if (count == 0) {
            return new address[](0);
        }

        address[] memory participants = new address[](count);
        uint256 index = 0;

        for (uint256 i = 1; i <= MAX_AVAILABLE_TICKETS; i++) {
            if (ticketToParticipant[i] != address(0)) {
                participants[index] = ticketToParticipant[i];
                index++;
            }
        }

        return participants;
    }
}