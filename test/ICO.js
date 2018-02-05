/**
 * Created by fabiopadoin on 25/01/2018.
 */

const nope = () => null

const Web3 = require('web3')
const web3 = new Web3()

var BigNumber = require('bignumber.js');

const TestRPC = require('ethereumjs-testrpc')
web3.setProvider(TestRPC.provider())

const Promise = require('bluebird')
Promise.promisifyAll(web3.eth, {suffix: "Promise"})
Promise.promisifyAll(web3.version, {suffix: "Promise"})
Promise.promisifyAll(web3.currentProvider, {suffix: "Promise"})


const assert = require('assert-plus')
const chai = require('chai').use(require('chai-as-promised'))
const should = chai.should()

const truffleContract = require("truffle-contract")

const SafeMath = truffleContract(require(__dirname + "/../build/contracts/SafeMath.json"))
const PreSaleVesting = truffleContract(require(__dirname + "/../build/contracts/PreSaleVesting.json"))
const UAC = truffleContract(require(__dirname + "/../build/contracts/UAC.json"))
const StdToken = truffleContract(require(__dirname + "/../build/contracts/StdToken.json"))
const Owned = truffleContract(require(__dirname + "/../build/contracts/Owned.json"))
const ICO = truffleContract(require(__dirname + "/../build/contracts/ICO.json"))
const UACUnsold = truffleContract(require(__dirname + "/../build/contracts/UACUnsold.json"))
const FoundersVesting = truffleContract(require(__dirname + "/../build/contracts/FoundersVesting.json"))
SafeMath.setProvider(web3.currentProvider)
StdToken.setProvider(web3.currentProvider)
PreSaleVesting.setProvider(web3.currentProvider)
UAC.setProvider(web3.currentProvider)
Owned.setProvider(web3.currentProvider)
ICO.setProvider(web3.currentProvider)
UACUnsold.setProvider(web3.currentProvider)
FoundersVesting.setProvider(web3.currentProvider)


const assertEvent = (contract, filter) => {
    return new Promise((resolve, reject) => {
        var event = contract[filter.event]()
        event.watch()
        event.get((error, logs) => {
            var log = _.filter(logs, filter)
            if (log && Array.isArray(log) && log.length > 0) {
                resolve(log)
            } else {
                throw Error("Failed to find filtered event for " + filter.event)
            }
        })
        event.stopWatching(() => null)
    })
}

const increaseTime = (days) => {
    var seconds = 3600 * 24 * days;
    return web3.currentProvider.sendAsyncPromise({
        jsonrpc: '2.0',
        method: 'evm_increaseTime',
        params: [seconds],
        id: new Date().getTime()
    })
        .then(() => web3.currentProvider.sendAsyncPromise({
            jsonrpc: "2.0",
            method: "evm_mine",
            params: [],
            id: 0
        }))
}


describe("ICO tests", () => {
    var accounts, networkId, safeMath, preSaleVesting, uac, stdToken, owned, uacUnsold, foundersVesting, ico
    var owner, user, buyer

    before("get accounts", () => {
        return web3.eth.getAccountsPromise()
            .then(_accounts => accounts = _accounts)
            .then(() => web3.version.getNetworkPromise())
            .then(_networkId => {
                networkId = _networkId
                ICO.setNetwork(networkId)
                PreSaleVesting.setNetwork(networkId)
                UAC.setNetwork(networkId)
                StdToken.setNetwork(networkId)
                FoundersVesting.setNetwork(networkId)
                UACUnsold.setNetwork(networkId)
                owner = accounts[0]
                user = accounts[1]
                buyer = accounts[2]
            })
    })

    before("deploy Owned", () => {
        return Owned.new({from: owner})
            .then(_owned => owned = _owned)
            .then(() => ICO.link({Owned: owned.address}))
            .then(() => UAC.link({Owned: owned.address}))
            .then(() => UACUnsold.link({Owned: owned.address}))
            .then(() => FoundersVesting.link({Owned: owned.address}))
    })

    before("deploy SafeMath", () => {
        return SafeMath.new({from: owner})
            .then(_safeMath => safeMath = _safeMath)
            .then(() => PreSaleVesting.link({SafeMath: safeMath.address}))
            .then(() => ICO.link({SafeMath: safeMath.address}))
            .then(() => UAC.link({SafeMath: safeMath.address}))
            .then(() => StdToken.link({SafeMath: safeMath.address}))
            .then(() => FoundersVesting.link({SafeMath: safeMath.address}))
            .then(() => UACUnsold.link({SafeMath: safeMath.address}))
    })

    before("deploy StdToken", () => {
        return StdToken.new({from: owner})
            .then(_stdToken => stdToken = _stdToken)
            .then(() => UAC.link({StdToken: stdToken.address}))
    })

    before("deploy UAC", () => {
        return UAC.new({from: owner})
            .then(_uac => uac = _uac)
            .then(() => ICO.link({UAC: uac.address}))
            .then(() => UACUnsold.link({UAC: uac.address}))
            .then(() => FoundersVesting.link({UAC: uac.address}))
            .then(() => PreSaleVesting.link({UAC: uac.address}))
    })

    before("deploy UACUnsold", () => {
        return UACUnsold.new(owner, uac.address, {from: owner})
            .then(_uacUnsold => uacUnsold = _uacUnsold)
            .then(() => ICO.link({UACUnsold: uacUnsold.address}))
    })

    before("deploy FounderVesting", () => {
        return FoundersVesting.new(owner, uac.address, {from: owner})
            .then(_foundersVesting => foundersVesting = _foundersVesting)
    })

    before("deploy PreSaleVesting", () => {
        return PreSaleVesting.new(uac.address, {from: owner})
            .then(_preSaleVesting => preSaleVesting = _preSaleVesting)
    })

    before("deploy ICO", () => {
        return ICO.new(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, {from: owner})
            .then(_ico => ico = _ico)
    })

     const ICODeploy = (uacAddress, uacUnsoldAddress, founderVestingAddress, preSaleVestingAddress) => {
         return ICO.new(uacAddress, uacUnsoldAddress, founderVestingAddress, preSaleVestingAddress, {from: owner})
             .then(_ico => ico = _ico)
             .then(() => uac.setIcoContractAddress(ico.address, {from: owner}))
             .then(() => uacUnsold.setIcoContractAddress(ico.address, {from: owner}))
     }

    it("shouldn't start the ICO because Ico address isn't set in UAC contract", () => {
        return ico.startICO({from: owner}).should.be.rejected
    })

    it("shouldn't start the ICO", () => {
        return uac.setIcoContractAddress(ico.address, {from: owner})
            .then(() => uacUnsold.setIcoContractAddress(ico.address, {from: owner}))
            .then(() => ico.startICO({from: user})).should.be.rejected
    })

    it("should start the ICO", () => {
        return uac.setIcoContractAddress(ico.address, {from: owner})
            .then(() => uacUnsold.setIcoContractAddress(ico.address, {from: owner}))
            .then(() => ico.startICO({from: owner}))
    })

    it("should get the number of UAC token per eth", () => {
        return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address)
            .then(() => ico.getUacTokensPerEth())
            .then(uacTokensPerEth => assert.strictEqual(uacTokensPerEth.toString(10), web3.toWei(150000000000000000000, "ether"), "should be started") )
    })

    it("shouldn't be able to change the usdPerEth", () => {
        return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address)
            .then(() => ico.setUsdPerEthRate(600, {from: owner})).should.be.rejected
    })

    it("should change the usdPerEth and get the number of UAC token per eth", () => {
        return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address)
            .then(() => increaseTime(1))
            .then(() => ico.setUsdPerEthRate(600, {from: owner}))
            .then(() => ico.getUacTokensPerEth())
            .then(uacTokensPerEth => assert.strictEqual(uacTokensPerEth.toString(10), web3.toWei(300000000000000000000, "ether"), "should be started") )
    })

    it("should buy 150 tokens", () => {
        return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address)
            .then(() => ico.startICO({from: owner}))

    })





})