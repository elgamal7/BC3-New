const hre = require("hardhat");
//console.log(hre)
//const ethers = require("hardhat");
//const { ethers } = require("hardhat");


async function main() {

  const GameBC3 = await hre.ethers.getContractFactory("GameBC3");
  //console.log("hintergame", GameBC3)
  const gameBC3 = await GameBC3.deploy();
  await gameBC3.deployed();
  console.log(`GameBC3 deployed at ${gameBC3.address}.`);


  const GameFactoryBC3 = await hre.ethers.getContractFactory("GameFactoryBC3");
  //console.log("hintergamefactory", Factory)
  const _template = `${gameBC3.address}`;
  const factory = await GameFactoryBC3.deploy(_template);
  //console.log("hinterfactorygame", factory)
  await factory.deployed();
  console.log(`Factory deployed at ${factory.address}.`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});