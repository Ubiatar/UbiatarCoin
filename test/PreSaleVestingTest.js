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
const PreSaleVestingTest = truffleContract(require(__dirname + "/../build/contracts/PreSaleVestingTest.json"))
const UAC = truffleContract(require(__dirname + "/../build/contracts/UAC.json"))
const StdToken = truffleContract(require(__dirname + "/../build/contracts/StdToken.json"))
SafeMath.setProvider(web3.currentProvider)
StdToken.setProvider(web3.currentProvider)
PreSaleVestingTest.setProvider(web3.currentProvider)
UAC.setProvider(web3.currentProvider)


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


describe("PreSaleVesting tests", () => {
    var accounts, networkId, safeMath, preSaleVesting, uac, stdToken, investor
    var owner, user

    before("get accounts", () => {
        return web3.eth.getAccountsPromise()
            .then(_accounts => accounts = _accounts)
            .then(() => web3.version.getNetworkPromise())
            .then(_networkId => {
                networkId = _networkId
                PreSaleVestingTest.setNetwork(networkId)
                owner = accounts[0]
                user = accounts[1]
                investor = "0x7fe01ff0aDaF111A94ad0d69eD27cDe23553AF44";
            })
    })

    before("deploy StdToken", () => {
        return StdToken.new({from: owner})
            .then(_stdToken => stdToken = _stdToken)
    })

    before("deploy UAC", () => {
        return UAC.new({from: owner})
            .then(_uac => uac = _uac)
            .then(() => UAC.link({StdToken: stdToken.address}))
    })

    before("deploy SafeMath", () => {
        return SafeMath.new({from: owner})
            .then(_safeMath => safeMath = _safeMath)
            .then(() => PreSaleVestingTest.link({SafeMath: safeMath.address}))
    })

    const preSaleVestingDeploy = (uacAddress) => {
        return PreSaleVestingTest.new(uacAddress, {from: owner})
            .then(_preSaleVesting => preSaleVesting = _preSaleVesting)
    }

    it("should deploy", () => {
        return preSaleVestingDeploy(uac.address)
    })

    it("should fail to deploy", () => {
        return preSaleVestingDeploy(0).should.be.rejected
    })

    it("should get 0 initial reclaimable tokens", () => {
        return preSaleVestingDeploy(uac.address)
            .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
            .then(tokens => assert.strictEqual(tokens.toString(10), '0', "should be 0"))
    })

    it("should get investor's initial balance", () => {
        return preSaleVestingDeploy(uac.address)
            .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
            .then(tokens => assert.strictEqual(tokens.toString(10), '266955000000000513888375', "should be 266955000000000513888375"))
    })

    it("should get investor's first threshold tokens ", () => {
        var actualBalance;
        return preSaleVestingDeploy(uac.address)
            .then(() => increaseTime(37))
            .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
            .then((balance) => actualBalance = balance.div(3))
            .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
            .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toString(10), "should be equal"))
    })

    it("should get investor's reclaimable tokens after 127 days", () => {
        var actualBalance;
        return preSaleVestingDeploy(uac.address)
            .then(() => increaseTime(127))
            .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
            .then((balance) => actualBalance = balance.div(3))
            .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
            .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toString(10), "should be equal"))
    })

    it("should get investor's reclaimable tokens after 128 days", () => {
        var actualBalance;
        return preSaleVestingDeploy(uac.address)
            .then(() => increaseTime(128))
            .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
            .then((balance) => {
                actualBalance = balance.div(3)
                actualBalance = (actualBalance.mul(2)).div(180)
                actualBalance = (balance.div(3)).add(actualBalance)
            })
            .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
            .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toFixed(0), "should be equal"))
    })

    it("should get investor's reclaimable tokens after 140 days", () => {
        var actualBalance;
        return preSaleVestingDeploy(uac.address)
            .then(() => increaseTime(140))
            .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
            .then((balance) => {
                actualBalance = balance.div(3)
                actualBalance = (actualBalance.mul(2)).div(180).mul(13)
                actualBalance = (balance.div(3)).add(actualBalance)
            })
            .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
            .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toFixed(0), "should be equal"))
    })

    it("should get investor's locked tokens at first threshold", () => {
        var actualBalance;
        return preSaleVestingDeploy(uac.address)
            .then(() => increaseTime(37))
            .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
            .then((balance) => {
                actualBalance = balance.div(3)
                actualBalance = actualBalance.mul(2)
            })
            .then(() => preSaleVesting.getLockedTokens(investor, {from: investor}))
            .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toFixed(0), "should be equal"))
    })

    it("should get all investor's tokens", () => {
        return preSaleVestingDeploy(uac.address)
            .then(() => increaseTime(307))
            .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
            .then((balance) => {
                return preSaleVesting.getReclaimableTokens(investor, {from: investor})
                    .then(tokens => assert.strictEqual(tokens.toString(10), balance.toFixed(0), "should be equal"))
            })
    })


})