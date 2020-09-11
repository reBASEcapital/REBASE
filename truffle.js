const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();
console.log(process.env.MNENOMIC);
module.exports = {
  networks: {
    ganacheUnitTest: {},
    ropsten: {
      provider: () => new HDWalletProvider(process.env.MNENOMIC, 'https://ropsten.infura.io/v3/' + process.env.INFURA_API_KEY),
      network_id: 3,
      gas: 3000000,
      gasPrice: 10000000000
    }
  },
  compilers: {
    solc: {
      version: '0.4.24',
      settings: {
        optimizer: {
          enabled: false
        }
      }
    }
  },
  mocha: {
    enableTimeouts: false
  }
};
