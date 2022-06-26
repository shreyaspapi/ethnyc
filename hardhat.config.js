require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("@nomiclabs/hardhat-etherscan");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.4",
  networks: {
    polygon: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/f5tnV-9lglEWqMyfhppbBUJrMBnHHqRM",
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 8000000000,
      gas: 2100000
    },
    rinkeby: {
      url: "https://rinkeby.infura.io/v3/39982aafcd7240098e7ba54f05b7863c",
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 8000000000,
      gas: 2100000
    },
    optimism: {
      url: "https://opt-kovan.g.alchemy.com/v2/V0nDjZbG4sprN3vDBYn-s-Qlvb2TgPt5",
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 8000000000,
      gas: 2100000
    }

  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      polygon: "UGGPFIPIBGKQKH4JXKI33B1NRR25GICK9P",
    }
  },
};
