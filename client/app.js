// Replace with your GameFactory contract address and ABI
import Web3 from "web3";
import gamefactoryConfiguration from "../build/contracts/MyGameFactory.json";
import gameConfiguration from "../build/contracts/MyGame.json";



// initialisiere Web3 Provider
const web3 = new Web3(Web3.givenProvider || "http://localhost:7545");

let metamaskAccount;
let gameFactory;

// initialisiere Web Elemente
const gamefactoryText = document.getElementById("gamefactoryAddress");
const accountText = document.getElementById("account");

// initialisiere Web3 Schnittstellen
const initializeWeb3 = async () => {

  // initialisiere MetaMask Account
  const accounts = await web3.eth.requestAccounts();
  metamaskAccount = accounts[0];
  accountText.innerText = 'MetaMask Account: ' + metamaskAccount;

  // initialisiere GameFactory + Game Contract
  const gameFactoryAddress = gamefactoryConfiguration.networks[5777].address;
  const gameFactoryABI = gamefactoryConfiguration.abi;
  gameFactory = new web3.eth.Contract(gameFactoryABI, gameFactoryAddress);
  gameAbi = gameConfiguration.abi;
  gamefactoryText.innerHTML = 'GameFactory Address: ' + gameFactoryAddress;
}
initializeWeb3();





function show(elementId) {
  document.getElementById(elementId).style.display = "block";
}

function hide(elementId) {
  document.getElementById(elementId).style.display = "none";
}

document.getElementById("createForm").addEventListener("submit", async (event) => {
  event.preventDefault(); // Prevent the default form submit behavior
});

document.getElementById("createGame").addEventListener("click", async () => {
  const newGame = await gameFactory.methods.createGame(web3.utils.toWei("0.01", "ether"), 10).send({ from: accounts[0] });
  const gameAddress = newGame.events.GameCreated.returnValues.game;

  document.getElementById("gameAddressDisplay").textContent = gameAddress;

  hide("createGame");
  show("game");
});

document.getElementById("submitNumber").addEventListener("click", async () => {
  const gameAddress = document.getElementById("gameAddressDisplay").textContent;
  const number = document.getElementById("number").value;
  const secret = document.getElementById("secret").value;
  const commit = web3.utils.soliditySha3(number, secret);

  const accounts = await web3.eth.getAccounts();
  await new web3.eth.Contract(gameABI, gameAddress).methods.enterGame(commit).send({ from: accounts[0], value: web3.utils.toWei("0.01", "ether") });
});

document.getElementById("revealWinner").addEventListener("click", async () => {
  const gameAddress = document.getElementById("gameAddressDisplay").textContent;
  const number = document.getElementById("number").value;
  const secret = document.getElementById("secret").value;

  const accounts = await web3.eth.getAccounts();
  await new web3.eth.Contract(gameABI, gameAddress).methods.revealNumber(number, secret).send({ from: accounts[0] });

  const winner = await new web3.eth.Contract(gameABI, gameAddress).methods.getWinner().call();
  document.getElementById("winner").textContent = winner;

  show("winningMessage");
  show("goBack");
});
document.getElementById("goBack").addEventListener("click", () => {
  hide("game");
  hide("winningMessage");
  hide("goBack");
  show("create-game");
});