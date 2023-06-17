/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/0012850e95e5451c960eaf0c7431d4bd",
      accounts: ["8efbdd0d6a5f9e924f1b2611a414a9150955c0f129fa683e7a01f11dae0a953a"]
    }
  },
  etherscan: {
    apiKey: "F6JINXQPJTPUPAY675E8RDNTFRQVBX7F1Z"
  }
};
