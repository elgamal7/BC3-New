// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;


import "./GameBC3.sol";

// Test comment
contract GameFactoryBC3 {
    address[] public games;

    function createGame() external payable returns (address) {
        GameBC3 newGame = new GameBC3();
        games.push(address(newGame));
        return address(newGame);
    }

    function getGames() external view returns (address[] memory) {
        return games;
    }
}
