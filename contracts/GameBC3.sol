// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
//import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract GAMEBC3 {

    using SafeMath for uint256;

    uint256 public constant maxNumberOfPlayers = 20; // Sets the maximum number of players at 20.
    uint256 public constant minNumberOfPlayers = 3; // Min. number of players 
    uint256 public constant entryFee = 0.1 * 10**18; // Entry fee in Wei
    uint256 public thirdPlayerBlock; // Saves the blockheight after a third play has joined the game
    uint256 public revealPhaseStartTime; // Start time of the reveal phase
    uint256 public numPlayersWithNumber = 0; // Counter for all players who have revealed their numbers

    bool public gameStarted; // Variable indicating whether the game is running or not.
    bool public gameEnded;  // Variable indicating whether the game is finished or not.
    bool public revealPhase = false; 

    mapping(address => bool) public hasPaid; // mapping of which address had paid the entryFee
    mapping(address => bytes32) public playerCommitments; //Stores the hash of the commitment (number + salt)
    mapping(address => uint256) public playerSubmittedNumbers; /**This mapping variable stores the numbers submitted by the player as key-value pairs, where the key is the player's address and the
    value is the number submitted by the player. This allows the submitted numbers of each player to be retrieved quickly**/
    mapping(address => bool) public playerHasRevealed; //mapping for revealed numbers

    address payable public contractOwner; // Owner of the contract
    address payable private winner; // The winner of the game
    address payable[] public players;
    address payable[] public revealedPlayers; // All Players that have revealed their numbers during the revealTime
    
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

        //Update fees
   function updateFees() public {
        gameFees.totalEntryFees = address(this).balance;
        gameFees.serviceFee = gameFees.totalEntryFees / 10; // 10% service fee
        gameFees.winnerReward = (gameFees.totalEntryFees * 9) / 10; // 90% of the total entryFees are the winnerReward
    }


        //Join the game
    function play() public payable {
        require(gameStarted == false, "This game is already finished!");
        require(!hasPaid[msg.sender], "You have already paid the entry fee");
        require(numPlayersWithNumber < maxNumberOfPlayers, "Max number of players reached");
        require(msg.sender != contractOwner, "Contract Owner cannot participate");
        require(msg.value == entryFee, "Please pay the exact participation fee of 0.1 ether");

        hasPaid[msg.sender] = true;
        
        updateFees();
        emit PlayerJoined(msg.sender, block.timestamp);
        emit EntryFeePaid(msg.sender, msg.value, block.timestamp);
    }
        

        //Get players
    function getPlayers() external view returns (address payable[] memory) {
        return players;
    }
    
    
    function commitHash(string memory _hash) public payable {
        require(gameStarted == false, "You can't submit a number, this game is already finished!");
        require(revealPhase == false, "Reveal phase has started, cannot commit number now");
        require(playerCommitments[msg.sender] == bytes32(0), "You have already committed a number and salt"); //Checks whether the player has already submitted a number.
        require(msg.sender != contractOwner, "contract Owner cannot participate");
        require(hasPaid[msg.sender], "You must pay the entry fee");

        bytes32 commit = keccak256(abi.encodePacked(_hash));
        playerCommitments[msg.sender] = commit;

    

        players.push(payable(msg.sender));
        numPlayersWithNumber++; // Incrementing after adding the player

        emit PlayerCommitted(msg.sender, _hash, block.timestamp);

            
        if (numPlayersWithNumber == minNumberOfPlayers) {
            thirdPlayerBlock = block.number;
        }

            // Checks if the minimum number of players have joined and enough blocks have passed
        if (numPlayersWithNumber >= minNumberOfPlayers && !gameStarted && block.number >= thirdPlayerBlock + 15) {
            startRevealTime();
        }
    }


        // game Reveal Time 
     function startRevealTime() internal {
        require(gameStarted == false, "The game has already started!");
        require(numPlayersWithNumber <= maxNumberOfPlayers);
        require(block.number >= thirdPlayerBlock + 20, "Wait 20 blocks after the third player joined.");

        revealPhase = true;  // Start the reveal phase
        revealPhaseStartTime = block.timestamp;

        emit RevealPhaseStarted(block.timestamp);
    } 


    function revealNumber(uint256 _number, string memory _salt) public {
        require(revealPhase == true, "The reveal phase has not started yet wait for four blocks to be mined");
        require(block.number >= revealPhaseStartTime + 30, "The reveal phase has ended. You cannot reveal your number anymore.");
        require(!playerHasRevealed[msg.sender], "You have already revealed your number");
        require(!playerHasRevealed[msg.sender], "You have already revealed your number");
        require(keccak256(abi.encodePacked(_number, _salt)) == playerCommitments[msg.sender], "The revealed number and salt do not match the committed values.");
        require(_number >= 0 && _number <= 1000, "Number must be between 0 and 1000");
        
        playerSubmittedNumbers[msg.sender] = _number; // Stores the number of the player
        playerHasRevealed[msg.sender] = true;    
        revealedPlayers.push(payable(msg.sender));

        emit PlayerRevealed(msg.sender, _number, block.timestamp);

        for (uint i = 0; i < players.length; i++) {
                if(!playerHasRevealed[players[i]]) {
                    return;  // If any player has not revealed their number, return immediately
                }
        }

        revealPhase = false;
        gameStarted = true;
        determineWinner();
    }



        //Calculates the winner
    function determineWinner() internal returns (address WinnerAddress, uint256 winnerReward, uint256 twoThirdsAverage) {
        require(revealedPlayers.length >= minNumberOfPlayers);
        require(revealedPlayers.length <= 20, "Max number of players reached");
        require(gameStarted == true, "The game has not yet started!");
        require(gameEnded == false);
        
    
            // Calculate the average of all player numbers
        uint256 sum = 0;
        for (uint256 i = 0; i < revealedPlayers.length; i++) {
            sum += playerSubmittedNumbers[revealedPlayers[i]];
        }

        uint256 average = sum / revealedPlayers.length;

            //Calculate the closest number to 2/3 of the average
        twoThirdsAverage = (average * 2) / 3;
        uint256 closestDistance = 2**256-1;
        uint256 closestNumber;

            //Calculates the winner
        for (uint256 i = 0; i < revealedPlayers.length; i++) {
            uint256 distance = playerSubmittedNumbers[revealedPlayers[i]] > twoThirdsAverage ? playerSubmittedNumbers[revealedPlayers[i]] - twoThirdsAverage : twoThirdsAverage - playerSubmittedNumbers[revealedPlayers[i]];
            if (distance < closestDistance) {
                closestDistance = distance;
                closestNumber = playerSubmittedNumbers[revealedPlayers[i]];
                WinnerAddress = revealedPlayers[i]; 

            }
        }
        
            //Counts the number of players with the closest number
        uint256 count = 0;
        for (uint256 i = 0; i < revealedPlayers.length; i++) {
            if (playerSubmittedNumbers[revealedPlayers[i]] == closestNumber) {
                count++;
            }
        }

            //If there is only one player with the closest number, return their address
        if (count == 1) {
            for (uint256 i = 0; i < revealedPlayers.length; i++) {
                if (playerSubmittedNumbers[revealedPlayers[i]] == closestNumber) {
                    gameEnded = true;
                    winner = revealedPlayers[i];
                    WinnerAddress = revealedPlayers[i];
                    winnerReward = gameFees.winnerReward;
                    emit GameEnded(block.timestamp, WinnerAddress);
                    return (WinnerAddress, winnerReward, twoThirdsAverage);
                   
                }
            }
    
        } else {   //If there are more than one player with the closest number, the winner is chosen at random
            uint256 winnerIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.basefee))) % count;
            uint256 j = 0;
            for (uint256 i = 0; i < revealedPlayers.length; i++) {
                if (playerSubmittedNumbers[revealedPlayers[i]] == closestNumber) {
                    if (j == winnerIndex) {
                        gameEnded = true;
                        winner = revealedPlayers[i];
                        WinnerAddress = revealedPlayers[i];
                        winnerReward = gameFees.winnerReward;
                        emit GameEnded(block.timestamp, WinnerAddress);
                        return (WinnerAddress, winnerReward, twoThirdsAverage);
                    }
                    j++;
                }
            }
        } 
        /** If there are multiple players with the closest number, select a random winner among them. Here the hash function keccak256 
        is used to generate a pseudo-random number based on the current block timestamp and on the block bas fee. 
        These two values are first combined using the abi.encodePacked() function to generate a byte array, 
        which is passed as an argument to keccak256(). The result is then cast into a uint256 variable and counted using the 
        modulo operator % by count to generate the random index value. Since the hash value is a pseudo-random number 
        between 0 and 2^256 - 1. It is taken modulo the number of players with the closest number to the two-thirds average, 
        to get an index within that range.**/
    
    return (address(0), winnerReward = 0, 0); // no winner found 
    } 


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

    function bubbleSort(uint256[] memory arr) internal pure {
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

        address[] memory rankedPlayers = new address[](revealedPlayers.length);
        uint256[] memory rankedNumbers = new uint256[](revealedPlayers.length);
        uint256[] memory ranks = new uint256[](revealedPlayers.length);

        for (uint256 i = 0; i < revealedPlayers.length; i++) {
            rankedPlayers[i] = revealedPlayers[i];
            rankedNumbers[i] = playerSubmittedNumbers[revealedPlayers[i]];
            ranks[i] = 0;
        }

        uint256[] memory sortedPlayerNumbers = rankedNumbers; // Create a copy of the array
        bubbleSort(sortedPlayerNumbers); // use sorted copy

            // Assign ranks based on the sorted player numbers
        for (uint256 i = 0; i < revealedPlayers.length; i++) {
            for (uint256 j = 0; j < revealedPlayers.length; j++) {
                if (playerSubmittedNumbers[rankedPlayers[j]] == sortedPlayerNumbers[i]) {
                    ranks[j] = i + 1;
                    break;
                }
            }
        }

        return (rankedPlayers, sortedPlayerNumbers, ranks); // sortierte Zahlen zurückgeben
    }

    function refund() external  {
        require(hasPaid[msg.sender] == true);
        require(gameStarted == true, "You cannot get a refund before the game starts.");
        require(playerSubmittedNumbers[msg.sender] >= 0 || playerSubmittedNumbers[msg.sender] < 1000, "You have submitted a valid number, you cannot claim a refund");
        removePlayer(); 
        payable(msg.sender).transfer(entryFee); // refund their entry fee
        hasPaid[msg.sender] = false;

        emit PlayerRefundClaimed(msg.sender, entryFee, block.timestamp);
    }


    function removePlayer() public {
        for (uint i = 0; i < players.length; i++) {
            if (players[i] == msg.sender) {
                // Delete the player from the array
                delete players[i];
                // Move the last element to the deleted position
                if (i != players.length - 1) { // Ensures it's not the last element
                    players[i] = players[players.length - 1];
                }
                // Removes the last element 
                players.pop();

                // Removes the player from revealedPlayers array, if exists
                for (uint j = 0; j < revealedPlayers.length; j++) {
                    if (revealedPlayers[j] == msg.sender) {
                        delete revealedPlayers[j];
                        if (j != revealedPlayers.length - 1) { // Ensures it's not the last element
                            revealedPlayers[j] = revealedPlayers[revealedPlayers.length - 1];
                        }
                        // Removes the last element
                        revealedPlayers.pop();
                        break;
                    }
                }
                emit PlayerRemoved(msg.sender, block.timestamp);
                break;
            }
        }
    }
}