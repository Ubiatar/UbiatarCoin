var HDWalletProvider = require("truffle-hdwallet-provider");

var infura_apikey = "";
var mnemonic = "";

module.exports = {
    networks: {
        ganache: {
            host: "localhost",
            port: 8545,
            network_id: "42",
            gas: 300000000,
        },
        development: {
            host: "localhost",
            port: 8545,
            network_id: "*",
            gas: 300000000,
        },
        ropsten: {
            provider: new HDWalletProvider(mnemonic, "https://ropsten.infura.io/" + infura_apikey),
            network_id: 3,
        }
    }
};