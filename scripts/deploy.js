import { ethers } from "hardhat";

async function main() {

  const Factory = await ethers.getContractFactory("GameFactoryBC3");
  const GameBC3 = await ethers.getContractFactory("GameBC3");

  const gameBC3 = await GameBC3.deploy();
  const factory = await Factory.deploy(GameBC3.address);

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