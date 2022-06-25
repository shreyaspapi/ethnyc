// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

/*
const HOST_ADDRESS = "0x3E14dC1b13c488a8d5D310918780c983bD5982E7";
const CFA_ADDRESS = "0x6EeE6060f715257b970700bc2656De21dEdF074C";
const IDA_ADDRESS = "0xB0aABBA4B2783A72C52956CDEF62d438ecA2d7a1";

const USDCX_ADDRESS = "0xCAa7349CEA390F89641fe306D93591f87595dc1F";
const ETHX_ADDRESS = "0x27e1e4E6BC79D93032abef01025811B7E4727e85";
*/

const HOST_ADDRESS = "0xeD5B5b32110c3Ded02a07c8b8e97513FAfb883B6";
const CFA_ADDRESS = "0xF4C5310E51F6079F601a5fb7120bC72a70b96e2A";
const IDA_ADDRESS = "0x32E0ecb72C1dDD92B007405F8102c1556624264D";

const USDCX_ADDRESS = "0xCAa7349CEA390F89641fe306D93591f87595dc1F";
const ETHX_ADDRESS = "0x27e1e4E6BC79D93032abef01025811B7E4727e85";


async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const SuperLevContract = await hre.ethers.getContractFactory("StableCashFlow");
  const superLev = await SuperLevContract.deploy(HOST_ADDRESS, CFA_ADDRESS, IDA_ADDRESS, USDCX_ADDRESS, ETHX_ADDRESS);

  await superLev.deployed();

  console.log("Deployed to:", superLev.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
