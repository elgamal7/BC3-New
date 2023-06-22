// interact.js

const API_KEY = process.env.API_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;

const { ethers } = require("hardhat")
const contract = require("../artifacts/contracts/GameFactoryBC3.sol/GameFactoryBC3.json");
//console.log(JSON.stringify(contract.abi))s;

// Provider
const InfuraProvider = new ethers.providers.InfuraProvider(network="sepolia", API_KEY);

// Signer
const signer = new ethers.Wallet(PRIVATE_KEY, InfuraProvider);

// Contract
const GameBCContract = new ethers.Contract(CONTRACT_ADDRESS, contract.abi, signer);

async function main() {
    // Create a new game
    const createGameTx = await GameBCContract.createGame();
    await createGameTx.wait();

    // Get the address of the latest created game
    const games = await GameBCContract.getGames();
    const latestGameAddress = games[games.length - 1];

    // Get the GameBC3 contract ABI
    const gameContractAbi = require("../artifacts/contracts/GameBC3.sol/GameBC3.json").abi;

    // Create a contract instance for the latest game
    const latestGameContract = new ethers.Contract(latestGameAddress, gameContractAbi, signer);

    // Call the message function or access the variable on the latestGameContract
    const message = await latestGameContract.message();
    console.log("The message is: " + message);

    const tx = await latestGameContract.update("thisisthenewmessage");
    await tx.wait();

    const newMessage = await latestGameContract.message();
    console.log("The new message is: " + newMessage);
}

  main();