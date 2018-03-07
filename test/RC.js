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
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
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

  it("should buy all 7500000 tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
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

describe("RC ICOEngine tests", () => {
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

  it("started - should not be started before starting block", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => reservationContract.started())
      .then(started => assert.strictEqual(started, false, "should note be started before starting block"))
  })

  it("started - should be started after starting block", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
      .then(() => mineBlock())
      .then(() => reservationContract.getIcoBlockNumberStart({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => reservationContract.setRCBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => reservationContract.started())
      .then(started => assert.strictEqual(started, true, "should be started after starting block"))
  })

  it("ended - should not be ended before starting block", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => reservationContract.ended())
      .then(started => assert.strictEqual(started, false, "should note be started before starting block"))
  })

  it("ended - should not be ended after starting block and before ending block", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
      .then(() => ico.getBlockNumberStart({from: owner}))
      .then(() => mineBlock())
      .then(() => reservationContract.getIcoBlockNumberStart({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => reservationContract.setRCBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => reservationContract.ended())
      .then(started => assert.strictEqual(started, false, "should be started after starting block"))
  })

  it("ended - should be ended if all tokens have been sold", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
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
      .then(() => reservationContract.ended())
      .then(started => assert.strictEqual(started, true, "should be ended if all tokens have been sold"))
  })

  it("startBlock - startBlock should be 0 before being initialized", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => reservationContract.startBlock())
      .then(number => assert.strictEqual(number.toString(10), "0", "should be 0 before being initialized"))
  })

  it("startBlock - startBlock should be set", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
      .then(() => mineBlock())
      .then(() => reservationContract.getIcoBlockNumberStart({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => reservationContract.setRCBlockNumberStart(number, {from: owner}))
      .then(() => reservationContract.startBlock())
      .then(rcBlockNumber => {
        return web3.eth.getBlockNumberPromise()
          .then(previousBlockNumber => assert.strictEqual(rcBlockNumber.toString(10), (previousBlockNumber - 1).toString(10), "should be equal"))
      })
  })

  it("endBlock - endBlock should be 0 before being initialized", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => reservationContract.endBlock())
      .then(number => assert.strictEqual(number.toString(10), "0", "should be 0 before being initialized"))
  })

  it("endBlock - endBlock should be set", () => {
    let currentNumber
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => {
        currentNumber = number
        return ico.setBlockNumberStart(number, {from: owner})
      })
      .then(() => reservationContract.getIcoBlockNumberStart({from: owner}))
      .then(() => reservationContract.icoBlockNumberStart())
      .then(number => assert.strictEqual(number.toString(10), currentNumber.toString(10), "should be equal"))
  })

  it("totalTokens - should return total tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => reservationContract.totalTokens())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(7500000, "ether"), "should be 7500000 total tokens"))
  })

  it("remainingTokens - should return remaining tokens at the start", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => reservationContract.remainingTokens())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(7500000, "ether"), "should be 7500000 remaining tokens"))
  })

  it("remainingTokens - should return 0 remaining tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
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
      .then(() => reservationContract.remainingTokens())
      .then(tokens => assert.strictEqual(tokens.toString(10), "0", "should be 0 remaining tokens"))
  })

  it("remainingTokens - should return remaining tokens after buying 605 tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => ico.setBlockNumberStart(number + 20, {from: owner}))
      .then(() => mineBlock())
      .then(() => reservationContract.getIcoBlockNumberStart({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then(number => reservationContract.setRCBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => ico.setRcContractAddress(reservationContract.address, {from: owner}))
      .then(() => ico.setUsdTokenPrice(220, {from: owner}))
      .then(() => reservationContract.setUsdTokenPrice(220, {from: owner}))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: reservationContract.address,
        value: web3.toWei(1, "ether")
      }))
      .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(550, "ether"), "should be 550 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(10), web3.toWei(550, "ether"), "should be 550 tokens"))
      .then(() => reservationContract.remainingTokens())
      .then(tokens => assert.strictEqual(tokens.toString(10), web3.toWei(7499450, "ether"), "should be 7499450 remaining tokens"))
  })

  it("price - should return current token price", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.setUsdTokenPrice(220, {from: owner}))
      .then(() => reservationContract.setUsdTokenPrice(220, {from: owner}))
      .then(() => reservationContract.price())
      .then(price => assert.strictEqual(price.toString(10), web3.toWei(550, "ether"), "should be 550 tokens per eth"))
  })
})
