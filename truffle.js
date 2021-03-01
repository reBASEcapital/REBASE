const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();
module.exports = {
  networks: {
    ganacheUnitTest: {
      'ref': 'ganache-unit-test',
      'host': '127.0.0.1',
      'port': 8545,
      'network_id': '*',
      'gas': 7989556,
      'gasPrice': 9000000000
    },
    ropsten: {
      provider: () => new HDWalletProvider(process.env.MNENOMIC, 'https://ropsten.infura.io/v3/' + process.env.INFURA_API_KEY),
      network_id: 3,
      gas: 4000000,
      gasPrice: 20000000000
    },
    bsc: {
      provider: () => new HDWalletProvider(process.env.MNENOMIC, 'https://data-seed-prebsc-2-s1.binance.org:8545'),
      network_id: 97,
      gas: 4000000,
      gasPrice: 20000000000
    },
    bscprod: {
      provider: () => new HDWalletProvider(process.env.MNENOMIC, 'https://bsc-dataseed.binance.org'),
      network_id: 56,
      gas: 5000000,
      gasPrice: 25000000000
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
