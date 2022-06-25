// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const HOST_ADDRESS = "0x3E14dC1b13c488a8d5D310918780c983bD5982E7";
const CFA_ADDRESS = "0x6EeE6060f715257b970700bc2656De21dEdF074C";
const IDA_ADDRESS = "0xB0aABBA4B2783A72C52956CDEF62d438ecA2d7a1";

const DAIX_ADDRESS = "0x1305F6B6Df9Dc47159D12Eb7aC2804d4A33173c2";
const USDCX_ADDRESS = "0xCAa7349CEA390F89641fe306D93591f87595dc1F";
const TELLOR_USDC_REQUEST_ID = Constants.TELLOR_USDC_REQUEST_ID;
const ETHX_ADDRESS = "0x27e1e4E6BC79D93032abef01025811B7E4727e85";
const TELLOR_ETH_REQUEST_ID = Constants.TELLOR_ETH_REQUEST_ID;
const WBTCX_ADDRESS = "0x4086eBf75233e8492F1BCDa41C7f2A8288c2fB92";
const TELLOR_WBTC_REQUEST_ID = Constants.TELLOR_WBTC_REQUEST_ID;
const REX_REFERRAL_ADDRESS = '0xA0eC9E1542485700110688b3e6FbebBDf23cd901';
const MATICX_ADDRESS = "0x3aD736904E9e65189c3000c7DD2c8AC8bB7cD4e3";
const TELLOR_MATIC_REQUEST_ID = 6;

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const SuperLevContract = await hre.ethers.getContractFactory("StableCashFlow");
  const superLev = await SuperLevContract.deploy(HOST_ADDRESS, CFA_ADDRESS, IDA_ADDRESS, );

  await superSwap.deployed();

  console.log("RexSuperSwap deployed to:", superSwap.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
