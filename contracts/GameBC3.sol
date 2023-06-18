// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

// Note SafeMath is generally not needed starting with Solidity 0.8, since the compiler now has built in overflow checking.
// Note Comments for Jan, built a test in the FrontEnd to check wether the Number submitted before it is turned into a hash value, that is is an integer.

contract GameBC3 {
    using Math for uint256;

    // Constant variables
    uint256 public constant maxNumberOfPlayers = 20;
    uint256 public constant minNumberOfPlayers = 3;
    uint256 public constant entryFee = 0.1 * 10 ** 18;

    // Game state variables
    uint256 public gameCountdownStartTime;
    uint256 public revealPhaseStartTime;
    uint256 public numberJoinedPlayers = 0;
    uint256 public numberPlayersWithHash = 0;
    uint256 public playersWithHash = 0;
    bool public gameStarted = false;
    bool public gameEnded = false;
    bool public revealPhase = false;

    // Player variables
    mapping(address => bool) public hasPaidEntryFee;
    mapping(address => bytes32) public playerCommitments;
    mapping(address => uint256) private revealedNumbers;
    mapping(address => bool) public playerHasRevealed;
    address payable[] public playersWhoHaveRevealed;
    address payable[] public closestPlayers;

    // Contract variables
    address payable public contractOwner;
    address payable private winner;
    Fees public gameFees; // Fees is a data type, which includes three uints (structure object) GameFees = Varibale of the Fees Type

    // Fees struct
    struct Fees {
        uint256 totalEntryFees;
        uint256 serviceFee;
        uint256 winnerReward;
    }

    // Events
    event GameStarted(uint256 timestamp);
    event GameEnded(uint256 timestamp, address WinnerAddress);
    event ServiceFeePaid(address contractOwner, uint256 fee);
    event RewardClaimed(uint256 amount, uint256 timestamp);
    event PlayerJoined(address indexed playerAddress, uint256 timestamp);
    event PlayerCommitted(address indexed playerAddress, bytes32 commitment, uint256 timestamp);
    event RevealPhaseStarted(uint256 timestamp);
    event PlayerRevealed(address indexed playerAddress, uint256 number, uint256 timestamp);
    event PlayerRemoved(address indexed playerAddress, uint256 timestamp);
    event PlayerRefundClaimed(address indexed playerAddress, uint256 amount, uint256 timestamp);

    constructor() {
        contractOwner = payable(msg.sender);
        gameStarted = false;
        gameEnded = false;
    }

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only the contract owner can call this function");
        _;
    }

    // modifier gameStarted {
    //     require(gameStarted == false, "This game has already started!");
    //     _;
    // }

    /// @notice Allows a player to join the game after paying the entry fee.
    function joinGame() public payable {
        require(revealPhase == false, "The reveal phase has already started!");
        require(!hasPaidEntryFee[msg.sender], "You have already paid the entry fee, you already joined the game!");
        require(numberJoinedPlayers <= maxNumberOfPlayers, "Max number of players reached");
        require(msg.value == entryFee, "Please pay the exact participation fee of 0.1 ether");

        hasPaidEntryFee[msg.sender] = true;
        numberJoinedPlayers++;

        emit PlayerJoined(msg.sender, block.timestamp);
    }

    /// @notice Allows a player to commit their hashed number and salt.
    /// @param _hash Hashed combination of the player's number and a secret salt.

    // hash is ein byte32 kein string -- > hash wird im FrontEnd erzeugt mit web3 utils soldity SHA-3 --> web3.utils.soliditySha3({ t: 'uint256', v: number }, { t: 'string', v: secret })
    function commitHash(bytes32 _hash) public {
        require(revealPhase == false, "Reveal phase has started, cannot commit number now");
        require(hasPaidEntryFee[msg.sender], "You must pay the entry fee");
        require(playerCommitments[msg.sender] == bytes32(0), "You have already committed a number and salt"); //Checks whether the player has already submitted a number.

        playerCommitments[msg.sender] = _hash;
        playersWithHash++;

        emit PlayerCommitted(msg.sender, _hash, block.timestamp);

        if (playersWithHash == minNumberOfPlayers) {
            gameCountdownStartTime = block.timestamp;
        }

        // Checks if the minimum number of players have joined and enough blocks have passed
        if (playersWithHash >= minNumberOfPlayers && block.timestamp >= gameCountdownStartTime + 90) {
            startRevealPhase();
        }
    }

    /// @dev Helper function - Starts the reveal phase of the game.
    function startRevealPhase() internal {
        revealPhase = true;
        revealPhaseStartTime = block.timestamp;
        emit RevealPhaseStarted(block.timestamp);
    }

    /// @notice Allows a player to reveal their number and salt, which should match the previously committed hash.
    /// @param _number The original number a player chose.
    /// @param _salt The original salt a player chose.
    function revealNumber(uint256 _number, string memory _salt) public {
        require(revealPhase == true, "The reveal phase has not started yet wait for four blocks to be mined.");
        require(block.timestamp <= gameCountdownStartTime + 180);
        require(!playerHasRevealed[msg.sender], "You have already revealed your number.");
        require(
            keccak256(abi.encodePacked(_number, _salt)) == playerCommitments[msg.sender],
            "The revealed number and salt do not match the committed values."
        );
        require(_number >= 0 && _number <= 1000, "Number must be between 0 and 1000.");

        // Aussicht für Doku// the last player pays the gas fees for determineWinner(). This is unfair and should actually be taken over by the contractOwner. But then the contractOwner can rewrite the Dapp blackmail the players.
        revealedNumbers[msg.sender] = _number; // Stores the number of the player
        playerHasRevealed[msg.sender] = true;
        playersWhoHaveRevealed.push(payable(msg.sender));

        emit PlayerRevealed(msg.sender, _number, block.timestamp);

        // Note serviceFee --> ContractDeployer has to be online and call the determineWinner function. If not, there always has to be a last player after the revealTime is over to call the determineWinner function through the revealNumber function. But that is uncertain and unfair because of the extra gas costs for that player.
    }

    /// @notice Determines and sets the winner of the game.
    function determineWinner() public onlyOwner {
        require(revealPhase == true, "The reveal phase has not started yet.");
        require(block.timestamp > gameCountdownStartTime + 180);
        require(gameEnded == false, "Game has ended.");
        require(playersWhoHaveRevealed.length >= minNumberOfPlayers); //Impliziert gegeben durch revealPhase == True.

        // Calculate the average of all player numbers
        uint256 totalSum = 0;
        for (uint256 i = 0; i < playersWhoHaveRevealed.length; i++) {
            totalSum += revealedNumbers[playersWhoHaveRevealed[i]];
        }

        // Calculate 2/3 of the average
        uint256 twoThirdAverage = (2 * totalSum) / (3 * playersWhoHaveRevealed.length); // In Soldity, a standard division results in a whole number rounded down to 0 (https://docs.openzeppelin.com/contracts/4.x/api/utils#SignedMath)

        //event twoThirdAverage
        delete closestPlayers; // This clears the storage array closestPlayers for reuse

        uint256 currentPlayerNumber;
        // Finds the player(s) with the number closest to 2/3 of the average
        uint256 closestDiff = type(uint256).max; // start with maximum possible uint
        for (uint256 i = 0; i < playersWhoHaveRevealed.length; i++) {
            if (playerHasRevealed[playersWhoHaveRevealed[i]] == true) {
                currentPlayerNumber = revealedNumbers[playersWhoHaveRevealed[i]];
                uint256 diff = SignedMath.abs(int256(twoThirdAverage) - int256(currentPlayerNumber));
                if (diff < closestDiff) {
                    delete closestPlayers; // removes all previous addresses
                    closestPlayers = new address payable[](1); // creates new array
                    closestPlayers[0] = playersWhoHaveRevealed[i];
                    closestDiff = diff;
                } else if (diff == closestDiff) {
                    closestPlayers.push(playersWhoHaveRevealed[i]); // add player to potential winners
                }
            }
        }
       
        // If multiple winners, select one randomly
        if (closestPlayers.length > 1) {
            uint256 randomWinnerIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.number))) %
                closestPlayers.length;
            winner = closestPlayers[randomWinnerIndex];
        } else {
            winner = closestPlayers[0];
        }

        gameFees.totalEntryFees = address(this).balance;
        gameFees.serviceFee = gameFees.totalEntryFees / 10; // 10% service fee
        gameFees.winnerReward = (gameFees.totalEntryFees * 9) / 10; // 90% of the total entryFees are the winnerReward
        gameEnded = true;
        emit GameEnded(block.timestamp, winner);
        claimReward();
    }

    /** If there are multiple players with the closest number, select a random winner among them. Here the hash function keccak256 
        is used to generate a pseudo-random number based on the current block timestamp and on the block bas fee. 
        These two values are first combined using the abi.encodePacked() function to generate a byte array, 
        which is passed as an argument to keccak256(). The result is then cast into a uint256 variable and counted using the 
        modulo operator % by count to generate the random index value. Since the hash value is a pseudo-random number 
        between 0 and 2^256 - 1. It is taken modulo the number of players with the closest number to the two-thirds average, 
        to get an index within that range.**/

    /// @notice Allows the winner or the contract owner to claim their respective rewards.
    function claimReward() private {
        require(gameEnded == true);
        require(gameFees.winnerReward > 0, "The winner reward has already been claimed");
        require(gameFees.serviceFee > 0, "The service fee has already been claimed by the contract owner");

        // Winner can withdraw the reward
        payable(winner).transfer(gameFees.winnerReward); // casts the winning address into a payable address
        emit RewardClaimed(gameFees.winnerReward, block.timestamp);

        // ContractOwner can withdraw the serviceFee
        payable(contractOwner).transfer(gameFees.serviceFee); // casts the contractOwner address into a payable address
        emit ServiceFeePaid(contractOwner, gameFees.serviceFee);
    }

    /// @notice Allows a player to leave the game before their number is revealed, refunding their entry fee.
    function leaveGame() public {
        require(hasPaidEntryFee[msg.sender], "You haven't joined the game yet");
        require(!playerHasRevealed[msg.sender], "You have revealed a number, you cannot claim a refund");

        // Reset the mappings for the player's address
        hasPaidEntryFee[msg.sender] = false;
        playerCommitments[msg.sender] = bytes32(0);
        revealedNumbers[msg.sender] = 0;
        playerHasRevealed[msg.sender] = false;

        // Refund their entry fee
        payable(msg.sender).transfer(entryFee);

        emit PlayerRefundClaimed(msg.sender, entryFee, block.timestamp);
    }
}