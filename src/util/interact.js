require('dotenv').config();
const infuraKey = process.env.REACT_APP_API_KEY;
const contractAddress = process.env.REACT_APP_CONTRACT_ADDRESS;
const contractABI = require('../contract-abi.json');
const Web3 = require('web3');

const web3 = new Web3(
    new Web3.providers.HttpProvider(
        "https://sepolia.infura.io/v3/71e40452b92247b5833518894c67fe09"
    )
)

export const GameFactoryBC3 = new web3.eth.Contract(
    contractABI,
    contractAddress
  );

export const loadCurrentMessage = async () => { 
    console.log("beladefunktion")
    const message = await GameFactoryBC3.methods.message().call();
    console.log("message call")
    return message;
};

export const connectWallet = async () => {
    if (window.ethereum) {
        try {
          const addressArray = await window.ethereum.request({
            method: "eth_requestAccounts",
          });
          const obj = {
            status: "👆🏽 Write a message in the text-field above.",
            address: addressArray[0],
          };
          return obj;
        } catch (err) {
          return {
            address: "",
            status: "😥 " + err.message,
          };
        }
      } else {
        return {
          address: "",
          status: ("You must install Metamask, a virtual Ethereum wallet, in your browser."),

        }; } 
  
};

export const getCurrentWalletConnected = async () => {
    if (window.ethereum) {
        try {
          const addressArray = await window.ethereum.request({
            method: "eth_accounts",
          });
          if (addressArray.length > 0) {
            return {
              address: addressArray[0],
              status: "👆🏽 Write a message in the text-field above.",
            };
          } else {
            return {
              address: "",
              status: "🦊 Connect to Metamask using the top right button.",
            };
          }
        } catch (err) {
          return {
            address: "",
            status: "😥 " + err.message,
          };
        }
      } else {
        return {
          address: "",
          status: ("You must install Metamask, a virtual Ethereum wallet, in your browser.")
        }; } };


export const updateMessage = async (address, message) => {
   //input error handling
   if (!window.ethereum || address === null) {
    return {
      status:
        "💡 Connect your Metamask wallet to update the message on the blockchain.",
    };
  }

  if (message.trim() === "") {
    return {
      status: "❌ Your message cannot be an empty string.",
    };
  }
  //set up transaction parameters
  const transactionParameters = {
    to: contractAddress, // Required except during contract publications.
    from: address, // must match user's active address.
    data: GameFactoryBC3.methods.update(message).encodeABI(),
  };

  //sign the transaction
  try {
    const txHash = await window.ethereum.request({
      method: "eth_sendTransaction",
      params: [transactionParameters],
    });
    return {
      status: (
        <span>
          ✅{" "}
          <a target="_blank" href={`https://ropsten.etherscan.io/tx/${txHash}`}>
            View the status of your transaction on Etherscan!
          </a>
          <br />
          ℹ️ Once the transaction is verified by the network, the message will
          be updated automatically.
        </span>
      ),
    };
  } catch (error) {
    return {
      status: "😥 " + error.message,
    };
  }
};
