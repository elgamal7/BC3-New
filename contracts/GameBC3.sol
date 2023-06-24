// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

// Note SafeMath is generally not needed starting with Solidity 0.8, since the compiler now has built in overflow checking.
/* Note Comments for Jan, built a test in the FrontEnd to check wether the Number submitted before it is turned into a hash value,
 that is is an integer. */

contract GameBC3 is ReentrancyGuard {
    using Math for uint256;

    // Constant variables
    uint256 public constant maxNumberOfPlayers = 20;
    uint256 public constant minNumberOfPlayers = 3;
    uint256 public constant entryFee = 0.1 * 10**18;
    

    // Game state variables
    uint256 public revealPhaseStartTime;
    uint256 public numberJoinedPlayers = 0;
    uint256 public countdown;
    bool public gameStarted = false;
    bool public gameEnded = false;
    bool public revealPhase = false;
    

    // Player variables
    mapping(address => bool) public hasPaidEntryFee;
    mapping(address => bytes32) public playerCommitments;
    mapping(address => uint256) private revealedNumbers;
    mapping(address => bool) public playerHasRevealed;
    mapping(address => uint256) public pendingWithdrawals;
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
    event RewardRecorded(address indexed winner, uint256 rewardAmount, uint256 timestamp);
    event ServiceFeeRecorded(address indexed contractOwner, uint256 feeAmount, uint256 timestamp);
    event Withdrawal(address indexed recipient, uint256 amount, uint256 timestamp);
    event PlayerCommitted(
        address indexed playerAddress,
        bytes32 commitment,
        uint256 timestamp
    );
    event RevealPhaseStarted(uint256 timestamp);
    event PlayerRevealed(
        address indexed playerAddress,
        uint256 number,
        uint256 timestamp
    );
    event PlayerRemoved(address indexed playerAddress, uint256 timestamp);
    event PlayerRefundClaimed(
        address indexed playerAddress,
        uint256 amount,
        uint256 timestamp
    );

    function initialize() public {
        contractOwner = payable(msg.sender);
        gameStarted = false;
        gameEnded = false;
        countdown = block.timestamp + 86400; // A day in seconds
    }

    // Adds a check wether the contractOwner is still active, maybe use PullPattern to
    modifier onlyOwner() {
        require(
            msg.sender == contractOwner,
            "Only the contract owner can call this function"
        );
        _;
    }

    /* Hash is ein byte32 kein string -- > hash wird im FrontEnd erzeugt mit web3 utils soldity SHA-3 --> 
        web3.utils.soliditySha3({ t: 'uint256', v: number }, { t: 'string', v: secret }) */
    /// @notice Allows a player to join the game after paying the entry fee.
    /// @notice Allows a player to commit their hashed number and salt.
    /// @param _hash Hashed combination of the player's number and a secret salt.
    function commitHash(bytes32 _hash) public payable {
        require(
            revealPhase == false,
            "Reveal phase has started, cannot commit number now"
        );
        require(
            !hasPaidEntryFee[msg.sender],
            "You have already paid the entry fee and commited a hash, you already joined the game!"
        );
        require(
            numberJoinedPlayers <= maxNumberOfPlayers,
            "Max number of players reached"
        );
        require(
            msg.value == entryFee,
            "Please pay the exact participation fee of 0.1 ether"
        );
        require(
            playerCommitments[msg.sender] == bytes32(0),
            "You have already committed a number and salt"
        ); //Checks whether the player has already submitted a hash.

        hasPaidEntryFee[msg.sender] = true;
        numberJoinedPlayers++;

        playerCommitments[msg.sender] = _hash;

        emit PlayerCommitted(msg.sender, _hash, block.timestamp);
    }

    /// @dev Helper function - Starts the reveal phase of the game.
    function startRevealPhase() public onlyOwner {
        require(numberJoinedPlayers >= minNumberOfPlayers);
        revealPhase = true;
        emit RevealPhaseStarted(block.timestamp);
    }

    /// @notice Allows a player to reveal their number and salt, which should match the previously committed hash.
    /// @param _number The original number a player chose.
    /// @param _salt The original salt a player chose.
    function revealNumber(uint256 _number, string memory _salt) public {
        require(
            revealPhase == true,
            "The reveal phase has not started yet wait for four blocks to be mined."
        );
        // require(block.timestamp <= countdown);
        require(
            !playerHasRevealed[msg.sender],
            "You have already revealed your number."
        );
        require(
            keccak256(abi.encodePacked(_number, _salt)) ==
                playerCommitments[msg.sender],
            "The revealed number and salt do not match the committed values."
        );
        require(
            _number >= 0 && _number <= 1000,
            "Number must be between 0 and 1000."
        );

        /* Solved -- Aussicht für Doku// the last player pays the gas fees for determineWinner(). 
        This is unfair and should actually be taken over by the contractOwner. But then the contractOwner
        can rewrite the Dapp blackmail the players.*/
        revealedNumbers[msg.sender] = _number; // Stores the number of the player
        playerHasRevealed[msg.sender] = true;
        playersWhoHaveRevealed.push(payable(msg.sender));

        emit PlayerRevealed(msg.sender, _number, block.timestamp);

        /* Note serviceFee --> ContractDeployer has to be online and call the determineWinner function. If not, there 
        always has to be a last player after the revealTime is over to call the determineWinner function through the revealNumber 
        function. But that is uncertain and unfair because of the extra gas costs for that player.*/
    }

    /// @notice Determines and sets the winner of the game.
    function determineWinner() public onlyOwner {
        require(revealPhase == true, "The reveal phase has not started yet.");
        require(gameEnded == false, "Game has ended.");
        require(playersWhoHaveRevealed.length >= minNumberOfPlayers); //Impliziert gegeben durch revealPhase == True.

        // Calculate the average of all player numbers
        uint256 totalSum = 0;
        for (uint256 i = 0; i < playersWhoHaveRevealed.length; i++) {
            totalSum += revealedNumbers[playersWhoHaveRevealed[i]];
        }

        // Calculate 2/3 of the average
        uint256 twoThirdAverage = (66 * totalSum) /
            (100 * playersWhoHaveRevealed.length); /* In Soldity, a standard division results in a whole number rounded down to 
            0 (https://docs.openzeppelin.com/contracts/4.x/api/utils#SignedMath)*/

        //event twoThirdAverage
        delete closestPlayers; // This clears the storage array closestPlayers for reuse

        uint256 currentPlayerNumber;
        // Finds the player(s) with the number closest to 2/3 of the average
        uint256 closestDiff = 1001; // start with maximum possible uint
        for (uint256 i = 0; i < playersWhoHaveRevealed.length; i++) {
            if (playerHasRevealed[playersWhoHaveRevealed[i]] == true) {
                currentPlayerNumber = revealedNumbers[
                    playersWhoHaveRevealed[i]
                ];
                uint256 diff = SignedMath.abs(
                    int256(twoThirdAverage) - int256(currentPlayerNumber)
                );
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
            uint256 randomWinnerIndex = uint256(
                keccak256(abi.encodePacked(block.timestamp, block.number))
            ) % closestPlayers.length;
            winner = closestPlayers[randomWinnerIndex];
        } else {
            winner = closestPlayers[0];
        }

        gameFees.totalEntryFees = address(this).balance;
        gameFees.serviceFee = gameFees.totalEntryFees / 10; // 10% service fee
        gameFees.winnerReward = (gameFees.totalEntryFees * 9) / 10; // 90% of the total entryFees are the winnerReward
        gameEnded = true;
        emit GameEnded(block.timestamp, winner);
        recordRewards();
    }

        /** If there are multiple players with the closest number, select a random winner among them. Here the hash function keccak256 
            is used to generate a pseudo-random number based on the current block timestamp and on the block number. 
            These two values are first combined using the abi.encodePacked() function to generate a byte array, 
            which is passed as an argument to keccak256(). The result is then cast into a uint256 variable and counted with the 
            Modulo operator % by the number of players with the closet number to get the random winner index value. Since the hash value is a pseudo-random number 
            between 0 and 2^256 - 1. It is taken modulo the number of players with the closest number to the two-thirds average, 
            to get an index within that range.**/


    /// @notice Records the rewards for the winner and the contract owner.
    function recordRewards() internal {
        require(gameEnded == true);
        require(
            gameFees.winnerReward > 0,
            "The winner reward has already been claimed"
        );
        require(
            gameFees.serviceFee > 0,
            "The service fee has already been claimed by the contract owner"
        );

        // Adds a condition to check if the game ended within the required time
        if(block.timestamp <= countdown) {
            // If the game ended in time, the rewards are recorded as before
            pendingWithdrawals[winner] = gameFees.winnerReward;
            emit RewardRecorded(winner, gameFees.winnerReward, block.timestamp);

            pendingWithdrawals[contractOwner] = gameFees.serviceFee;
            emit ServiceFeeRecorded(contractOwner, gameFees.serviceFee, block.timestamp);
        } else {
            // If the game did not end in time, players who revealed their numbers can claim back their entry fee
            for (uint i = 0; i < playersWhoHaveRevealed.length; i++) {
                address playerAddress = playersWhoHaveRevealed[i];
                pendingWithdrawals[playerAddress] = entryFee;
            }
        }
    }


    /// @notice Allows a recipient to withdraw their funds.
    function withdraw() public nonReentrant {
        uint amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds available for withdrawal");

        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdrawal(msg.sender, amount, block.timestamp);
    }


    /// @notice Allows a player to leave the game before their number is revealed, refunding their entry fee.
    function leaveGame() public nonReentrant {
        require(hasPaidEntryFee[msg.sender], "You haven't joined the game yet");
        require(
            !playerHasRevealed[msg.sender],
            "You have revealed a number, you cannot claim a refund"
        );
        require(
            block.timestamp >= countdown,
            "You have to wait a day from the ccontract creation block.timestamp on, to leave the game."
        );

        // Resets the mappings for the player's address
        hasPaidEntryFee[msg.sender] = false;
        playerCommitments[msg.sender] = bytes32(0);
        revealedNumbers[msg.sender] = 0;
        playerHasRevealed[msg.sender] = false;

        // Refunds their entry fee
        (bool refundSuccess, ) = payable(msg.sender).call{value: entryFee}("");
        require(refundSuccess, "Refund failed");

        emit PlayerRefundClaimed(msg.sender, entryFee, block.timestamp);
    }
}
