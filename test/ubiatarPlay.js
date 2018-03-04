/**
 * Created by fabiopadoin on 25/01/2018.
 */

const nope = () => null

const Web3 = require('web3')
const web3 = new Web3()

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

const PreSaleVesting = truffleContract(require(__dirname + "/../build/contracts/PreSaleVesting.json"))
const UAC = truffleContract(require(__dirname + "/../build/contracts/UAC.json"))
const ICO = truffleContract(require(__dirname + "/../build/contracts/ICO.json"))
const UACUnsold = truffleContract(require(__dirname + "/../build/contracts/UACUnsold.json"))
const FoundersVesting = truffleContract(require(__dirname + "/../build/contracts/FoundersVesting.json"))
const UbiatarPlay = truffleContract(require(__dirname + "/../build/contracts/UbiatarPlay.json"))

PreSaleVesting.setProvider(web3.currentProvider)
UAC.setProvider(web3.currentProvider)
ICO.setProvider(web3.currentProvider)
UACUnsold.setProvider(web3.currentProvider)
FoundersVesting.setProvider(web3.currentProvider)
UbiatarPlay.setProvider(web3.currentProvider)


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

const mineBlock = () => {
  return web3.currentProvider.sendAsyncPromise({
    jsonrpc: "2.0",
    method: "evm_mine",
    params: [],
    id: 0
  })
}


describe("UbiatarPlay tests", () => {
  var accounts, networkId, preSaleVesting, uac, uacUnsold, foundersVesting, ico, ubiatarPlay, advisorsWallet
  var owner, user, ubiatarAccount

  before("get accounts", () => {
    return web3.eth.getAccountsPromise()
      .then(_accounts => accounts = _accounts)
      .then(() => web3.version.getNetworkPromise())
      .then(_networkId => {
        networkId = _networkId
        ICO.setNetwork(networkId)
        PreSaleVesting.setNetwork(networkId)
        UAC.setNetwork(networkId)
        FoundersVesting.setNetwork(networkId)
        UACUnsold.setNetwork(networkId)
        UbiatarPlay.setNetwork(networkId)
        owner = accounts[0]
        user = accounts[1]
        ubiatarAccount = accounts[2]
        advisorsWallet = accounts[3]
      })
  })

  beforeEach("deploy UAC", () => {
    return UAC.new({from: owner})
      .then(_uac => uac = _uac)
  })

  before("deploy UACUnsold", () => {
    return UACUnsold.new({from: owner})
      .then(_uacUnsold => uacUnsold = _uacUnsold)
  })

  beforeEach("deploy FounderVesting", () => {
    return FoundersVesting.new(uac.address, {from: owner})
      .then(_foundersVesting => foundersVesting = _foundersVesting)
  })

  beforeEach("deploy PreSaleVesting", () => {
    return PreSaleVesting.new(uac.address, {from: owner})
      .then(_preSaleVesting => preSaleVesting = _preSaleVesting)
  })

  beforeEach("deploy UbiatarPlay", () => {
    return UbiatarPlay.new(uac.address, {from: owner})
      .then(_ubiatarPlay => ubiatarPlay = _ubiatarPlay)
  })

  const ICODeploy = (uacAddress, uacUnsoldAddress, founderVestingAddress, preSaleVestingAddress, ubiatarPlayAddress, advisorsWallet) => {
    return ICO.new(uacAddress, uacUnsoldAddress, founderVestingAddress, preSaleVestingAddress, ubiatarPlayAddress, advisorsWallet, {from: owner})
      .then(_ico => ico = _ico)
      .then(() => uac.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => preSaleVesting.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => ubiatarPlay.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => foundersVesting.setIcoContractAddress(ico.address, {from: owner}))
  }

 /* it("should start the ICO", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert.strictEqual(isIcoRunning, true, "it should be started"))
  })*/

 it("should start with 50500000 tokens", () => {
   return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
     .then(() => ico.startICO({from: owner}))
     .then(() => ubiatarPlay.currentBalance())
     .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(50500000, "ether"), "should be 50500000 tokens"))
     .then(() => uac.balanceOf(ubiatarPlay.address))
     .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(50500000, "ether"), "should be 50500000 tokens"))
 })

 it("should withdraw tokens after 3 months", () => {
   return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
     .then(() => ico.startICO({from: owner}))
     .then(() => ico.setIcoFinishTime(0, {from: owner}))
     .then(() => ico.finishICO({from: owner}))
     .then(() => increaseTime(91))
     .then(() => ubiatarPlay.setubiatarPlayTokenHolder(ubiatarAccount, {from: owner}))
     .then(() => ubiatarPlay.withdraw({from: owner}))
     .then(() => ubiatarPlay.currentBalance())
     .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(48500000, "ether"), "should be 48500000 remaining tokens"))
     .then(() => ubiatarPlay.withdrawMonths3())
     .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 3 months"))
     .then(() => uac.balanceOf(ubiatarPlay.address))
     .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(48500000, "ether"), "should be 48500000 remaining tokens in UAC"))
     .then(() => uac.balanceOf(ubiatarAccount))
     .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(2000000, "ether"), "should have 2000000 tokens in UAC"))
 })

  it("should withdraw tokens after 9 months", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(271))
      .then(() => ubiatarPlay.setubiatarPlayTokenHolder(ubiatarAccount, {from: owner}))
      .then(() => ubiatarPlay.withdraw({from: owner}))
      .then(() => ubiatarPlay.currentBalance())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(38500000, "ether"), "should be 48500000 remaining tokens"))
      .then(() => ubiatarPlay.withdrawMonths3())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 3 months"))
      .then(() => ubiatarPlay.withdrawMonths6())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 6 months"))
      .then(() => ubiatarPlay.withdrawMonths9())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 9 months"))
      .then(() => uac.balanceOf(ubiatarPlay.address))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(38500000, "ether"), "should be 38500000 remaining tokens in UAC"))
      .then(() => uac.balanceOf(ubiatarAccount))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(12000000, "ether"), "should have 12000000 tokens in UAC"))
  })

  it("should withdraw all tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(721))
      .then(() => ubiatarPlay.setubiatarPlayTokenHolder(ubiatarAccount, {from: owner}))
      .then(() => ubiatarPlay.withdraw({from: owner}))
      .then(() => ubiatarPlay.currentBalance())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 remaining tokens"))
      .then(() => uac.balanceOf(ubiatarPlay.address))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 remaining tokens in UAC"))
      .then(() => uac.balanceOf(ubiatarAccount))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(50500000, "ether"), "should have 50500000 tokens in UAC"))
  })

  it("should withdraw tokens after 3 months ad again after 12", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(91))
      .then(() => ubiatarPlay.setubiatarPlayTokenHolder(ubiatarAccount, {from: owner}))
      .then(() => ubiatarPlay.withdraw({from: owner}))
      .then(() => ubiatarPlay.currentBalance())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(48500000, "ether"), "should be 48500000 remaining tokens"))
      .then(() => ubiatarPlay.withdrawMonths3())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 3 months"))
      .then(() => uac.balanceOf(ubiatarPlay.address))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(48500000, "ether"), "should be 48500000 remaining tokens in UAC"))
      .then(() => uac.balanceOf(ubiatarAccount))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(2000000, "ether"), "should have 2000000 tokens in UAC"))
      .then(() => increaseTime(271))
      .then(() => ubiatarPlay.withdraw({from: owner}))
      .then(() => ubiatarPlay.currentBalance())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(30500000, "ether"), "should be 30500000 remaining tokens"))
      .then(() => ubiatarPlay.withdrawMonths3())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 3 months"))
      .then(() => ubiatarPlay.withdrawMonths6())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 6 months"))
      .then(() => ubiatarPlay.withdrawMonths9())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 9 months"))
      .then(() => ubiatarPlay.withdrawMonths12())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 12 months"))
      .then(() => uac.balanceOf(ubiatarPlay.address))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(30500000, "ether"), "should be 30500000 remaining tokens in UAC"))
      .then(() => uac.balanceOf(ubiatarAccount))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(20000000, "ether"), "should have 20000000 tokens in UAC"))
  })

  it("should withdraw tokens after 3 months and try immediately after", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(91))
      .then(() => ubiatarPlay.setubiatarPlayTokenHolder(ubiatarAccount, {from: owner}))
      .then(() => ubiatarPlay.withdraw({from: owner}))
      .then(() => ubiatarPlay.currentBalance())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(48500000, "ether"), "should be 48500000 remaining tokens"))
      .then(() => ubiatarPlay.withdrawMonths3())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be 0 reclaimable tokens after 3 months"))
      .then(() => uac.balanceOf(ubiatarPlay.address))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(48500000, "ether"), "should be 48500000 remaining tokens in UAC"))
      .then(() => uac.balanceOf(ubiatarAccount))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(2000000, "ether"), "should have 2000000 tokens in UAC"))
      .then(() => ubiatarPlay.withdraw({from: owner})).should.be.rejected
  })
})

