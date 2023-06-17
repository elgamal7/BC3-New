// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;


import "./GameBC3.sol";

// Test comment
contract MyGameFactory {
    address[] public games;

    function createGame(address payable _contractOwner) external payable returns (address) {
        address newGame = address(MyGame(_contractOwner));
        games.push(newGame);
        return newGame;
    }

    function getGames() external view returns (address[] memory) {
        return games;
    }
}
