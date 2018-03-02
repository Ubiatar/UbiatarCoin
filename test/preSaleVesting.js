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
const PreSaleVestingTest = truffleContract(require(__dirname + "/../build/contracts/PreSaleVestingTest.json"))
const UAC = truffleContract(require(__dirname + "/../build/contracts/UAC.json"))
const ICO = truffleContract(require(__dirname + "/../build/contracts/ICO.json"))
const UACUnsold = truffleContract(require(__dirname + "/../build/contracts/UACUnsold.json"))
const FoundersVesting = truffleContract(require(__dirname + "/../build/contracts/FoundersVesting.json"))
const UbiatarPlay = truffleContract(require(__dirname + "/../build/contracts/UbiatarPlay.json"))

PreSaleVesting.setProvider(web3.currentProvider)
PreSaleVestingTest.setProvider(web3.currentProvider)
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


describe("PreSaleVesting getters tests", () => {
  var accounts, networkId, preSaleVesting, uac, uacUnsold, foundersVesting, ico, ubiatarPlay, advisorsWallet
  var owner, user, investor

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
        advisorsWallet = accounts[2]
        investor = "0x7fe01ff0aDaF111A94ad0d69eD27cDe23553AF44";
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

  it("should get 0 initial reclaimable tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), '0', "should be 0"))
  })

  it("should get investor's initial balance", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), '266955000000000513888375', "should be 266955000000000513888375"))
  })

  it("should get investor's first threshold tokens ", () => {
    var actualBalance;
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(7))
      .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
      .then((balance) => actualBalance = balance.div(3))
      .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toString(10), "should be equal"))
  })

  it("should get investor's reclaimable tokens after 127 days", () => {
    var actualBalance;
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(97))
      .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
      .then((balance) => actualBalance = balance.div(3))
      .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toString(10), "should be equal"))
  })

  it("should get investor's reclaimable tokens after 128 days", () => {
    var actualBalance;
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(98))
      .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
      .then((balance) => {
        actualBalance = balance.div(3)
        actualBalance = (actualBalance.mul(2)).div(180)
        actualBalance = (balance.div(3)).add(actualBalance)
      })
      .then(() => preSaleVesting.getReclaimableTokens(investor, {from: investor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toFixed(0), "should be equal"))
  })

  it("should get investor's reclaimable tokens after 110 days", () => {
    var actualBalance;
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(110))
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
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(7))
      .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
      .then((balance) => {
        actualBalance = balance.div(3)
        actualBalance = actualBalance.mul(2)
      })
      .then(() => preSaleVesting.getLockedTokens(investor, {from: investor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), actualBalance.toFixed(0), "should be equal"))
  })

  it("should get all investor's tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(307))
      .then(() => preSaleVesting.getInitialBalance(investor, {from: investor}))
      .then((balance) => {
        return preSaleVesting.getReclaimableTokens(investor, {from: investor})
          .then(tokens => assert.strictEqual(tokens.toString(10), balance.toFixed(0), "should be equal"))
      })
  })

  it("should have 17584778551358900100698693 tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => uac.balanceOf(preSaleVesting.address))
      .then(tokens => assert.strictEqual(tokens.toString(10), "17584778551358900100698693", "should be equal"))
  })
})

describe("PreSaleVesting withdraw function test", () => {
  var accounts, networkId, preSaleVestingTest, uac, uacUnsold, foundersVesting, ico, ubiatarPlay, advisorsWallet
  var owner, user, investor, fakeInvestor

  before("get accounts", () => {
    return web3.eth.getAccountsPromise()
      .then(_accounts => accounts = _accounts)
      .then(() => web3.version.getNetworkPromise())
      .then(_networkId => {
        networkId = _networkId
        ICO.setNetwork(networkId)
        PreSaleVestingTest.setNetwork(networkId)
        UAC.setNetwork(networkId)
        FoundersVesting.setNetwork(networkId)
        UACUnsold.setNetwork(networkId)
        UbiatarPlay.setNetwork(networkId)
        owner = accounts[0]
        user = accounts[1]
        fakeInvestor = accounts[2]
        investor = "0x7fe01ff0aDaF111A94ad0d69eD27cDe23553AF44";
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
    return PreSaleVestingTest.new(uac.address, {from: owner})
      .then(_preSaleVestingTest => preSaleVestingTest = _preSaleVestingTest)
  })

  beforeEach("deploy UbiatarPlay", () => {
    return UbiatarPlay.new(uac.address, {from: owner})
      .then(_ubiatarPlay => ubiatarPlay = _ubiatarPlay)
  })

  const ICODeploy = (uacAddress, uacUnsoldAddress, founderVestingAddress, preSaleVestingTestAddress, ubiatarPlayAddress, advisorsWallet) => {
    return ICO.new(uacAddress, uacUnsoldAddress, founderVestingAddress, preSaleVestingTestAddress, ubiatarPlayAddress, advisorsWallet, {from: owner})
      .then(_ico => ico = _ico)
      .then(() => uac.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => preSaleVestingTest.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => ubiatarPlay.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => foundersVesting.setIcoContractAddress(ico.address, {from: owner}))
  }

  it("should add a new investor", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVestingTest.address, ubiatarPlay.address, advisorsWallet)
      .then(() => preSaleVestingTest.addNewInvestor(investor, web3.toWei(1200000, "ether"), {from: owner}))
  })

  it("should add a new investor and get its balances before ico finish", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVestingTest.address, ubiatarPlay.address, advisorsWallet)
      .then(() => preSaleVestingTest.addNewInvestor(fakeInvestor, web3.toWei(1200000, "ether"), {from: owner}))
      .then(() => preSaleVestingTest.getInitialBalance(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(1200000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getReclaimableTokens(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), "0", "should be equal"))
      .then(() => preSaleVestingTest.getBalance(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(1200000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getLockedTokens(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(1200000, "ether"), "should be equal"))
  })

  it("should add a new investor and withdraw 400000 tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVestingTest.address, ubiatarPlay.address, advisorsWallet)
      .then(() => preSaleVestingTest.addNewInvestor(fakeInvestor, web3.toWei(1200000, "ether"), {from: owner}))
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(7))
      .then(() => preSaleVestingTest.withdrawTokens({from: fakeInvestor}))
      .then(() => uac.balanceOf(preSaleVestingTest.address))
      .then(tokens => assert.strictEqual(tokens.toString(10), "17184778551358900100698693", "should be equal"))
      .then(() => uac.balanceOf(fakeInvestor))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(400000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getInitialBalance(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(1200000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getReclaimableTokens(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), "0", "should be equal"))
      .then(() => preSaleVestingTest.getBalance(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(800000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getLockedTokens(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(800000, "ether"), "should be equal"))
  })

  it("should add a new investor and withdraw 400000 tokens, then wait 360 days and withdraw all remaining tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVestingTest.address, ubiatarPlay.address, advisorsWallet)
      .then(() => preSaleVestingTest.addNewInvestor(fakeInvestor, web3.toWei(1200000, "ether"), {from: owner}))
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => increaseTime(7))
      .then(() => preSaleVestingTest.withdrawTokens({from: fakeInvestor}))
      .then(() => uac.balanceOf(preSaleVestingTest.address))
      .then(tokens => assert.strictEqual(tokens.toString(10), "17184778551358900100698693", "should be equal"))
      .then(() => uac.balanceOf(fakeInvestor))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(400000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getInitialBalance(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(1200000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getReclaimableTokens(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), "0", "should be equal"))
      .then(() => preSaleVestingTest.getBalance(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(800000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getLockedTokens(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(800000, "ether"), "should be equal"))
      .then(() => increaseTime(360))
      .then(() => preSaleVestingTest.getBalance(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(800000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getReclaimableTokens(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(800000, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.getLockedTokens(fakeInvestor, {from: fakeInvestor}))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(0, "ether"), "should be equal"))
      .then(() => preSaleVestingTest.withdrawTokens({from: fakeInvestor}))
      .then(() => uac.balanceOf(fakeInvestor))
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(1200000, "ether"), "should be equal"))
  })
})
