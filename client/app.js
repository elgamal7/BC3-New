
// Erstellen Sie eine neue Web3-Instanz
const Web3 = require('web3');
const web3 = new Web3(
    new Web3.providers.WebsocketProvider(`wss://sepolia.infura.io/ws/v3/${infurakey}`)
);
const infurakey= "0012850e95e5451c960eaf0c7431d4bd"


// Setzen Sie die Adressen und ABIs Ihrer Smart Contracts
const gameFactoryAddress = 'Ihre GameFactory Adresse hier einfügen';
const gameFactoryABI = 'Ihr GameFactory ABI hier einfügen';
const gameABI = require("./GameBC3_ABI.json");

// Erstellen Sie neue Contract-Instanzen
let gameFactory = new web3.eth.Contract(gameFactoryABI, gameFactoryAddress);
let game;

// Initialisieren Sie die Metamask-Konten
let accounts;
const initializeAccounts = async () => {
    accounts = await web3.eth.getAccounts();
};
initializeAccounts();

// EventListener für den "Join Game"-Button
document.getElementById("joinGame").addEventListener("click", async () => {
    await gameFactory.methods.joinGame().send({ from: accounts[0], value: web3.utils.toWei("0.1", "ether") });
});

// EventListener für den "Commit Hash"-Button
document.getElementById("commitHash").addEventListener("click", async () => {
    const hash = document.getElementById("hashInput").value;
    await gameFactory.methods.commitHash(hash).send({ from: accounts[0] });
});

// EventListener für den "Reveal Number"-Button
document.getElementById("revealNumber").addEventListener("click", async () => {
    const number = document.getElementById("numberInput").value;
    const salt = document.getElementById("saltInput").value;
    await game.methods.revealNumber(number, salt).send({ from: accounts[0] });
});

// EventListener für den "Claim Reward"-Button
document.getElementById("claimReward").addEventListener("click", async () => {
    await game.methods.claimReward().send({ from: accounts[0] });
});

// EventListener für den "Leave Game"-Button
document.getElementById("leaveGame").addEventListener("click", async () => {
    await game.methods.leaveGame().send({ from: accounts[0] });
});
