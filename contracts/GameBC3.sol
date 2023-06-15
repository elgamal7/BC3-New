// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
//import "hardhat/console.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
//import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract GAMEBC3 {

    using SafeMath for uint256;

    uint256 public constant maxNumberOfPlayers = 20; // Sets the maximum number of players at 20.
    uint256 public constant minNumberOfPlayers = 3; // Min. number of players 
    uint256 public constant entryFee = 0.1 * 10**18; // Entry fee in Wei
    uint256 public thirdPlayerJoinTime; // Saves the blockheight after a third play has joined the game
    uint256 public revealPhaseStartTime; // Start time of the reveal phase
    uint256 public NumberPlayersWithHash = 0; // Counter for all players who have revealed their numbers
    uint256 public joinGameCountdown = 150; // Two and a half minutes in seconds
    uint256 public revealTimeCountdown = 180; // Three minutes in seconds
    uint256 public numberJoinedPlayers;

    bool public gameStarted; // Variable indicating whether the game is running or not.
    bool public gameEnded;  // Variable indicating whether the game is finished or not.
    bool public revealPhase = false; 

    mapping(address => bool) public hasPaid; // Mapping of which address had paid the entryFee
    mapping(address => bytes32) public playerCommitments; // Stores the hash of the commitment (number + salt)
    mapping(address => uint256) public revealedNumbers; /**This mapping variable stores the numbers submitted by the player as key-value pairs, where the key is the player's address and the
    value is the number submitted by the player. This allows the submitted numbers of each player to be retrieved quickly**/
    mapping(address => bool) public playerHasRevealed; //mapping for revealed numbers

    address payable public contractOwner; // Owner of the contract
    address payable private winner; // The winner of the game
    address payable[] public playersWithHash;
    address payable[] public playersWhoHaveRevealed; // All Players that have revealed their numbers during the revealTime
    address payable[] closestPlayers;
    
    struct Fees {
            uint256 totalEntryFees;
            uint256 serviceFee;
            uint256 winnerReward;
        }
        
    Fees public gameFees;

    event GameStarted(uint256 timestamp);
    event GameEnded(uint256 timestamp, address WinnerAddress);
    event ServiceFeePaid(address contractOwner, uint256 fee);
    event RewardClaimed(address indexed claimerAddress, uint256 amount, uint256 timestamp);
    event PlayerJoined(address indexed playerAddress, uint256 timestamp);
    event PlayerCommitted(address indexed playerAddress, string commitment, uint256 timestamp);
    event RevealPhaseStarted(uint256 timestamp);
    event PlayerRevealed(address indexed playerAddress, uint256 number, uint256 timestamp);
    event EntryFeePaid(address indexed playerAddress, uint256 amount, uint256 timestamp);
    event PlayerRemoved(address indexed playerAddress, uint256 timestamp);
    event PlayerRefundClaimed(address indexed playerAddress, uint256 amount, uint256 timestamp);



    constructor() payable {
            contractOwner = payable(msg.sender);
            gameStarted = false;
            gameEnded = false;
    }

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only the contract owner can call this function");
        _;
    }

    //Join the game
    function joinGame() public payable {
        require(gameStarted == false, "This game is already finished!");
        require(!hasPaid[msg.sender], "You have already paid the entry fee");
        require(numberJoinedPlayers <= maxNumberOfPlayers, "Max number of players reached");
        require(msg.sender != contractOwner, "Contract Owner cannot participate");
        require(msg.value == entryFee, "Please pay the exact participation fee of 0.1 ether");

        hasPaid[msg.sender] = true;
        numberJoinedPlayers++;
        
        emit PlayerJoined(msg.sender, block.timestamp);
        emit EntryFeePaid(msg.sender, msg.value, block.timestamp);
    }

    //Commit the hash of your number + salt    
    function commitHash(string memory _hash) public payable {
        require(gameStarted == false, "You can't submit a number, this game is already finished!");
        require(revealPhase == false, "Reveal phase has started, cannot commit number now");
        require(playerCommitments[msg.sender] == bytes32(0), "You have already committed a number and salt"); //Checks whether the player has already submitted a number.
        require(msg.sender != contractOwner, "contract Owner cannot participate");
        require(hasPaid[msg.sender], "You must pay the entry fee");

        bytes32 commit = keccak256(abi.encodePacked(_hash));
        playerCommitments[msg.sender] = commit;

        playersWithHash.push(payable(msg.sender));
        
        emit PlayerCommitted(msg.sender, _hash, block.timestamp);

            
        if (playersWithHash.length == minNumberOfPlayers) {
            thirdPlayerJoinTime = block.timestamp;
        }

            // Checks if the minimum number of players have joined and enough blocks have passed
        if (playersWithHash.length >= minNumberOfPlayers && !gameStarted && block.timestamp >= thirdPlayerJoinTime + joinGameCountdown) {
            startRevealTime();
        }
    }


    //Starts the game reveal time 
     function startRevealTime() internal {
        require(gameStarted == false, "The game has already started!");
        require(playersWithHash.length <= maxNumberOfPlayers);
        require(block.timestamp >= thirdPlayerJoinTime + joinGameCountdown, "Wait five minutes after the third player has joined until the game starts.");

        revealPhase = true;  // Start the reveal phase
        revealPhaseStartTime = block.timestamp;
        emit RevealPhaseStarted(block.timestamp);
    } 


    function revealNumber(uint256 _number, string memory _salt) public {
        require(revealPhase == true, "The reveal phase has not started yet wait for four blocks to be mined.");
        require(block.timestamp <= revealPhaseStartTime + revealTimeCountdown, "The reveal phase has ended. You cannot reveal your number anymore.");
        require(!playerHasRevealed[msg.sender], "You have already revealed your number.");
        require(!playerHasRevealed[msg.sender], "You have already revealed your number.");
        require(keccak256(abi.encodePacked(_number, _salt)) == playerCommitments[msg.sender], "The revealed number and salt do not match the committed values.");
        require(_number >= 0 && _number <= 1000, "Number must be between 0 and 1000.");
        
        revealedNumbers[msg.sender] = _number; // Stores the number of the player
        playerHasRevealed[msg.sender] = true;    
        playersWhoHaveRevealed.push(payable(msg.sender));

        emit PlayerRevealed(msg.sender, _number, block.timestamp);

        revealPhase = false;
        gameStarted = true;
        determineWinner();
    }

//service muss der dritte Spieler bisher zahlen --> ändern auf Contract Owner!


    function determineWinner() public returns (address, uint256) {
        require(gameStarted == true, "Game has not started yet.");
        require(gameEnded == false, "Game has ended.");
        require(NumberPlayersWithHash >= minNumberOfPlayers && NumberPlayersWithHash <= maxNumberOfPlayers, "Number of players who have revealed their numbers is not within the min and max limit.");

        // Calculate the average of all player numbers
        uint256 total = 0;
        for (uint256 i = 0; i < playersWhoHaveRevealed.length; i++) {
            total += revealedNumbers[playersWhoHaveRevealed[i]];
        }
        uint256 average = total / playersWhoHaveRevealed.length;

        // Calculate 2/3 of the average
        uint256 twoThirdAverage = (2 * average) / 3;


        delete closestPlayers; // This clears the storage array closestPlayers for reuse

        // Find the player(s) with the number closest to 2/3 of the average
        uint256 closestDiff = type(uint256).max; // start with maximum possible uint
        for (uint256 i = 0; i < playersWhoHaveRevealed.length; i++) {
            if (playerHasRevealed[playersWhoHaveRevealed[i]] == true) {
                uint256 diff = revealedNumbers[playersWhoHaveRevealed[i]] > twoThirdAverage ? revealedNumbers[playersWhoHaveRevealed[i]] - twoThirdAverage : twoThirdAverage - revealedNumbers[playersWhoHaveRevealed[i]];
                if (diff < closestDiff) {
                    delete closestPlayers; // remove all previous addresses
                    closestPlayers = new address payable[](1); // create new array
                    closestPlayers[0] = playersWhoHaveRevealed[i];
                    closestDiff = diff;
                } else if (diff == closestDiff) {
                    closestPlayers.push(playersWhoHaveRevealed[i]); // add player to potential winners
                }
            }
        }
            // If multiple winners, select one randomly
        if (closestPlayers.length > 1) {
            uint256 randomWinnerIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.basefee))) % closestPlayers.length;
            winner = closestPlayers[randomWinnerIndex];
        } else {
            winner = closestPlayers[0];
        }

        gameFees.totalEntryFees = address(this).balance;
        gameFees.serviceFee = gameFees.totalEntryFees / 10; // 10% service fee
        gameFees.winnerReward = (gameFees.totalEntryFees * 9) / 10; // 90% of the total entryFees are the winnerReward
        
    return (address(0), gameFees.winnerReward = 0); // no winner found 
    } 
        /** If there are multiple players with the closest number, select a random winner among them. Here the hash function keccak256 
        is used to generate a pseudo-random number based on the current block timestamp and on the block bas fee. 
        These two values are first combined using the abi.encodePacked() function to generate a byte array, 
        which is passed as an argument to keccak256(). The result is then cast into a uint256 variable and counted using the 
        modulo operator % by count to generate the random index value. Since the hash value is a pseudo-random number 
        between 0 and 2^256 - 1. It is taken modulo the number of players with the closest number to the two-thirds average, 
        to get an index within that range.**/


    function claimReward() public payable {
        
        require(gameEnded == true);
        require(msg.sender == winner || msg.sender == contractOwner, "Only winner or contract contractOwner can claim the reward");
            // Checking whether the rewards are still available
        require(gameFees.winnerReward > 0, "The winner reward has already been claimed");
        require(gameFees.serviceFee > 0, "The service fee has already been claimed by the contract owner");


            // Winner can withdraw the reward 
        if (msg.sender == winner) {
            payable(winner).transfer(gameFees.winnerReward);
            emit RewardClaimed(msg.sender, gameFees.winnerReward, block.timestamp);
        }
            // ContractOwner can withdraw the serviceFee 
        if (msg.sender == contractOwner) {
            payable(contractOwner).transfer(gameFees.serviceFee);
            emit ServiceFeePaid(contractOwner, gameFees.serviceFee);        
        } 
        gameFees.totalEntryFees = 0;
        gameFees.serviceFee = 0;
    }

    function leaveGame() public {
        require(hasPaid[msg.sender] == true);
        require(gameStarted == true, "You cannot get a refund before the game starts.");
        require(!playerHasRevealed[msg.sender], "You have revealed a number, you cannot claim a refund");

        // Refund their entry fee
        payable(msg.sender).transfer(entryFee);

        // Reset the mappings for the player's address
        hasPaid[msg.sender] = false;
        playerCommitments[msg.sender] = bytes32(0);
        revealedNumbers[msg.sender] = 0;
        playerHasRevealed[msg.sender] = false;

        emit PlayerRefundClaimed(msg.sender, entryFee, block.timestamp);
    }
}










   /* function bubbleSort(uint256[] memory arr) internal pure {
        uint256 n = arr.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
               if (arr[j] < arr[j + 1]) { 
                    uint256 temp = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = temp;
                }
            }
        }
    }

    function getRanking() public view returns (address[] memory, uint256[] memory, uint256[] memory) {
        require(gameEnded == true, "Das Spiel ist noch nicht beendet");

        address[] memory rankedPlayers = new address[](playersWhoHaveRevealed.length);
        uint256[] memory rankedNumbers = new uint256[](playersWhoHaveRevealed.length);
        uint256[] memory ranks = new uint256[](playersWhoHaveRevealed.length);

        for (uint256 i = 0; i < playersWhoHaveRevealed.length; i++) {
            rankedPlayers[i] = playersWhoHaveRevealed[i];
            rankedNumbers[i] = revealedNumbers[playersWhoHaveRevealed[i]];
            ranks[i] = 0;
        }

        uint256[] memory sortedPlayerNumbers = rankedNumbers; // Create a copy of the array
        bubbleSort(sortedPlayerNumbers); // use sorted copy

            // Assign ranks based on the sorted player numbers
        for (uint256 i = 0; i < playersWhoHaveRevealed.length; i++) {
            for (uint256 j = 0; j < playersWhoHaveRevealed.length; j++) {
                if (revealedNumbers[rankedPlayers[j]] == sortedPlayerNumbers[i]) {
                    ranks[j] = i + 1;
                    break;
                }
            }
        }

        return (rankedPlayers, sortedPlayerNumbers, ranks); // Return sorted numbers
    }
    */