// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;


import "./GameBC3.sol";

// Test comment
contract MyGameFactory {
    address[] public games;

    function createGame() external payable returns (address) {
        GAMEBC3 newGame = new GAMEBC3();
        games.push(address(newGame));
        return address(newGame);
    }

    function getGames() external view returns (address[] memory) {
        return games;
    }
}
