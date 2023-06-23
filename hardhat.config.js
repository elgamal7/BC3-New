/**type import('hardhat/config').HardhatUserConfig**/

require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");

const { API_URL, PRIVATE_KEY } = process.env;

module.exports = {
   solidity: "0.8.2",
   defaultNetwork: "sepolia",
   networks: {
      hardhat: {
      },
      sepolia: {
         url: API_URL,
         accounts: [`${PRIVATE_KEY}`]
      }
   },
   etherscan:{
      apiKey: process.env.ETHERSCAN_API_KEY},

}