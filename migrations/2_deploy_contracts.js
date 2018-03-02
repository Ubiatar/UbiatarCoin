const Web3 = require('web3')
const web3 = new Web3()

var StdToken = artifacts.require("./StdToken.sol");
var SafeMath = artifacts.require("./SafeMath.sol");
var UAC = artifacts.require("./UAC.sol");
var PreSaleVesting = artifacts.require("./PreSaleVesting.sol");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    deployer.link(SafeMath,StdToken);
    deployer.deploy(StdToken);
    deployer.link(StdToken, UAC);
    deployer.link(SafeMath, UAC);
    deployer.deploy(UAC);
    deployer.link(SafeMath, PreSaleVesting);
    deployer.link(UAC, PreSaleVesting)
        .then(() =>  deployer.deploy(PreSaleVesting, UAC.address))
};
