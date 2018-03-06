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
const ReservationContract = truffleContract(require(__dirname + "/../build/contracts/ReservationContract.json"))


PreSaleVesting.setProvider(web3.currentProvider)
UAC.setProvider(web3.currentProvider)
ICO.setProvider(web3.currentProvider)
UACUnsold.setProvider(web3.currentProvider)
FoundersVesting.setProvider(web3.currentProvider)
UbiatarPlay.setProvider(web3.currentProvider)
ReservationContract.setProvider(web3.currentProvider)


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


describe("RC tests", () => {
  var accounts, networkId, preSaleVesting, uac, uacUnsold, foundersVesting, ico, ubiatarPlay, reservationContract
  var owner, user, buyer, advisorsWallet, ubiatarColdWallet, buyer2, ubiatarColdWallet2, ubiatarColdWallet3, newOwner, attacker

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
        ReservationContract.setNetwork(networkId)
        owner = accounts[0]
        user = accounts[1]
        buyer = accounts[2]
        advisorsWallet = accounts[3]
        ubiatarColdWallet = accounts[4]
        buyer2 = accounts[5]
        ubiatarColdWallet2 = accounts[6]
        ubiatarColdWallet3 = accounts[7]
        newOwner = accounts[8]
        attacker = accounts[9]
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

  beforeEach("deploy FoundersVesting", () => {
    return FoundersVesting.new(uac.address, {from: owner})
      .then(_foundersVesting => foundersVesting = _foundersVesting)
      // .then(console.log(foundersVesting))
  })

  beforeEach("deploy PreSaleVesting", () => {
    return PreSaleVesting.new(uac.address, {from: owner})
      .then(_preSaleVesting => preSaleVesting = _preSaleVesting)
      // .then(console.log(preSaleVesting))
  })

  beforeEach("deploy UbiatarPlay", () => {
    return UbiatarPlay.new(uac.address, {from: owner})
      .then(_ubiatarPlay => ubiatarPlay = _ubiatarPlay)
  })

  beforeEach("deploy ReservationContract", () => {
    return ReservationContract.new(uac.address, {from: owner})
      .then(_reservationContract => reservationContract = _reservationContract)
  })

  const ICODeploy = (uacAddress, uacUnsoldAddress, foundersVestingAddress, preSaleVestingAddress, ubiatarPlayAddress, advisorsWallet) => {
    return ICO.new(uacAddress, uacUnsoldAddress, foundersVestingAddress, preSaleVestingAddress, ubiatarPlayAddress, advisorsWallet, {from: owner})
      .then(_ico => ico = _ico)
      .then(() => uac.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => preSaleVesting.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => ubiatarPlay.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => foundersVesting.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => reservationContract.setIcoContractAddress(ico.address, {from: owner}))
  }

  it("should change RC's ownership", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => reservationContract.owner())
      .then(address => assert.strictEqual(address, owner, "should be owner"))
      .then(() => reservationContract.transferOwnership(newOwner, {from: owner}))
      .then(() => reservationContract.owner())
      .then(address => assert.strictEqual(address, newOwner, "should be newOwner"))
  })

  it("should be rejected to receive Ether before blocks", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: reservationContract.address,
        value: 10
      })).should.be.rejected
  })

  it("should be rejected to receive Ether before RC starting block", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
      .then(() => ico.getBlockNumberStart({from: owner}))
      .then(() => mineBlock())
      .then(() => reservationContract.getIcoBlockNumberStart({from: attacker})).should.be.rejected
      .then(() => reservationContract.getIcoBlockNumberStart({from: owner}))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: reservationContract.address,
        value: web3.toWei(10, "ether")
      })).should.be.rejected
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => reservationContract.setRCBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: reservationContract.address,
        value: web3.toWei(10, "ether")
      })).should.be.rejected
      .then(() => ico.setRcContractAddress(reservationContract.address, {from: owner}))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: reservationContract.address,
        value: web3.toWei(10, "ether")
      }))
  })

  it("should buy al 7500000 tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
      .then(() => ico.getBlockNumberStart({from: owner}))
      .then(() => mineBlock())
      .then(() => reservationContract.getIcoBlockNumberStart({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => reservationContract.setRCBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => ico.setRcContractAddress(reservationContract.address, {from: owner}))
      .then(() => ico.setUsdTokenPrice(220, {from: owner}))
      .then(() => ico.setUsdPerEthRate(2000000000, {from: owner}))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: reservationContract.address,
        value: web3.toWei(0.75, "ether")
      }))
      .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(7500000, "ether"), "should be 7500000 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(10), web3.toWei(7500000, "ether"), "should be 7500000 tokens"))
  })


})

/*
describe("RC ICOEngineInterface tests", () => {
  var accounts, networkId, preSaleVesting, uac, uacUnsold, foundersVesting, ico, ubiatarPlay
  var owner, user, buyer, advisorsWallet, ubiatarColdWallet

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
        buyer = accounts[2]
        advisorsWallet = accounts[3]
        ubiatarColdWallet = accounts[4]
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

  beforeEach("deploy FoundersVesting", () => {
    return FoundersVesting.new(uac.address, {from: owner})
      .then(_foundersVesting => foundersVesting = _foundersVesting)
    // .then(console.log(foundersVesting))
  })

  beforeEach("deploy PreSaleVesting", () => {
    return PreSaleVesting.new(uac.address, {from: owner})
      .then(_preSaleVesting => preSaleVesting = _preSaleVesting)
    // .then(console.log(preSaleVesting))
  })

  beforeEach("deploy UbiatarPlay", () => {
    return UbiatarPlay.new(uac.address, {from: owner})
      .then(_ubiatarPlay => ubiatarPlay = _ubiatarPlay)
  })

  const ICODeploy = (uacAddress, uacUnsoldAddress, foundersVestingAddress, preSaleVestingAddress, ubiatarPlayAddress, advisorsWallet) => {
    return ICO.new(uacAddress, uacUnsoldAddress, foundersVestingAddress, preSaleVestingAddress, ubiatarPlayAddress, advisorsWallet, {from: owner})
      .then(_ico => ico = _ico)
      .then(() => uac.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => preSaleVesting.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => ubiatarPlay.setIcoContractAddress(ico.address, {from: owner}))
      .then(() => foundersVesting.setIcoContractAddress(ico.address, {from: owner}))
  }

  it("should not be started in init state", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.started())
      .then(s => assert.strictEqual(s.toString(), "false", "should be false"))
  })

  it("should not be ended if the ico is not started", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.ended())
      .then(s => assert.strictEqual(s.toString(), "false", "should be false"))
  })

  it("should not be ended if the ico is running or paused", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.ended())
      .then(s => assert.strictEqual(s.toString(), "false", "should be false"))
      .then(() => ico.pauseICO({from: owner}))
      .then(() => ico.ended())
      .then(s => assert.strictEqual(s.toString(), "false", "should be false"))
  })

  it("should be ended if the ico is finished", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => ico.finishICO({from: owner}))
      .then(() => ico.ended())
      .then(s => assert.strictEqual(s.toString(), "true", "should be true"))
  })

  it("should return 15000000 total tokens for the ico", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.totalTokens())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(15000000, "ether"), "should 15000000 tokens"))
  })

  it("should return 15000000 total remaining tokens before the startt of the ico", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.remainingTokens())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(15000000, "ether"), "should 15000000 tokens"))
  })

  it("should buy 594 tokens and get remaining tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert(!isIcoRunning, "it should not be started yet"))
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert(isIcoRunning, "it should be started"))
      .then(() => web3.eth.getBlockNumberPromise())
      .then((number) => ico.setBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: web3.toWei(1, "ether")
      }))
      .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(), "594594594594594594594", "should be 594 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(), "594594594594594594594", "should be 594 tokens"))
      .then(() => ico.remainingTokens())
      .then(tokens => assert.strictEqual(tokens.toString(10), "14999405405405405405405406", "should 15000000 tokens"))
  })

  it("should get 594 tokens per eth", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.price())
      .then(tokens => assert.strictEqual(tokens.toString(10), "594594594594594594594", "should be 594 tokens"))
  })
})
*/
