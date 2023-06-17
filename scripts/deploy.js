const hre = require("hardhat");
//console.log(hre)
//const ethers = require("hardhat");
//const { ethers } = require("hardhat");


async function main() {

  const Factory = await hre.ethers.getContractFactory("GameFactoryBC3");
  //console.log("hintergamefactory", Factory)
  const GameBC3 = await hre.ethers.getContractFactory("GameBC3");
  //console.log("hintergame", GameBC3)
  const gameBC3 = await GameBC3.deploy();
  //console.log("hintergameBC3", gameBC3)
  const factory = await Factory.deploy();
  //console.log("hinterfactorygame", factory)
  console.log(
    `GameBC3 deployed at ${gameBC3.address}.`
  );
  console.log(
    `Factory deployed at ${factory.address}.`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});