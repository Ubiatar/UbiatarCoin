var HDWalletProvider = require("truffle-hdwallet-provider");

var infura_apikey = "" ;
var mnemonic = "";

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 4000000,
      gasPrice:  20000000000
    },
    ganache: {
      host: "localhost",
      port: 8545,
      network_id: 42,
      gas: 6500000,
      gasPrice:  20000000000
    },
    ropsten: {
      provider: new HDWalletProvider(mnemonic, "https://ropsten.infura.io/" + infura_apikey),
      network_id: 3,
      gas: 4000000,
      gasPrice:  20000000000
    }
  }
};