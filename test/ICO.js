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

const SafeMath = truffleContract(require(__dirname + "/../build/contracts/SafeMath.json"))
const PreSaleVesting = truffleContract(require(__dirname + "/../build/contracts/PreSaleVesting.json"))
const UAC = truffleContract(require(__dirname + "/../build/contracts/UAC.json"))
const StdToken = truffleContract(require(__dirname + "/../build/contracts/StdToken.json"))
const Owned = truffleContract(require(__dirname + "/../build/contracts/Owned.json"))
const ICO = truffleContract(require(__dirname + "/../build/contracts/ICO.json"))
const UACUnsold = truffleContract(require(__dirname + "/../build/contracts/UACUnsold.json"))
const FoundersVesting = truffleContract(require(__dirname + "/../build/contracts/FoundersVesting.json"))
const UbiatarPlay = truffleContract(require(__dirname + "/../build/contracts/UbiatarPlay.json"))

SafeMath.setProvider(web3.currentProvider)
StdToken.setProvider(web3.currentProvider)
PreSaleVesting.setProvider(web3.currentProvider)
UAC.setProvider(web3.currentProvider)
Owned.setProvider(web3.currentProvider)
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


describe("ICO tests", () => {
  var accounts, networkId, safeMath, preSaleVesting, uac, stdToken, owned, uacUnsold, foundersVesting, ico, ubiatarPlay
  var owner, user, buyer, advisorsWallet

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
        UbiatarPlay.setNetwork(networkId)
        owner = accounts[0]
        user = accounts[1]
        buyer = accounts[2]
        advisorsWallet = accounts[3]
      })
  })

  before("deploy Owned", () => {
    return Owned.new({from: owner})
      .then(_owned => owned = _owned)
      .then(() => ICO.link({Owned: owned.address}))
      .then(() => UAC.link({Owned: owned.address}))
      .then(() => UACUnsold.link({Owned: owned.address}))
      .then(() => FoundersVesting.link({Owned: owned.address}))
      .then(() => PreSaleVesting.link({Owned: owned.address}))
      .then(() => UbiatarPlay.link({Owned: owned.address}))
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
      .then(() => UbiatarPlay.link({SafeMath: safeMath.address}))
  })

  before("deploy StdToken", () => {
    return StdToken.new({from: owner})
      .then(_stdToken => stdToken = _stdToken)
      .then(() => UAC.link({StdToken: stdToken.address}))
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

  it("should start the ICO", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert.strictEqual(isIcoRunning, true, "it should be started"))
  })

  /* it("should get the number of UAC token per eth", () => {
       return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address)
           .then(() => ico.getUacTokensPerEth())
           .then(uacTokensPerEth => assert.strictEqual(uacTokensPerEth.toString(10), web3.toWei(550, "ether"), "should be started"))
   }) */

  it("should change the usdPerEth and check it", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.setUsdPerEthRate(60000, {from: owner}))
      .then(() => ico.usdPerEth())
      .then(uacTokensPerEth => assert.strictEqual(uacTokensPerEth.toString(10), "60000", "should be started"))
  })

  it("should start ico, pause it and then start it again", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert.strictEqual(isIcoRunning, false, "it should not be started yet"))
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert.strictEqual(isIcoRunning, true, "it should be started"))
      .then(() => ico.pauseICO({from: owner}))
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert.strictEqual(isIcoRunning, false, "it should be stopped"))
      .then(() => ico.resumeICO({from: owner}))
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert.strictEqual(isIcoRunning, true, "it should be started again"))
  })

  it("should not update token value", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.usdTokenPrice())
      .then(usdTokenPrice => assert.strictEqual(usdTokenPrice.toString(), "200", "should be 2 usd"))
      .then(() => ico.setUsdTokenPrice(1, {from: user})).should.be.rejected
      .then(() => ico.usdTokenPrice())
      .then(usdTokenPrice => assert.strictEqual(usdTokenPrice.toString(), "200", "should be 2 usd"))
  })

  it("Should not get tokens before ICO is started", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert(!isIcoRunning, "it should not be started yet"))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: 10
      })).should.be.rejected
  })

  it("Should not get tokens before ICO is started", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert(!isIcoRunning, "it should not be started yet"))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: 10
      })).should.be.rejected
  })

  it("Should not get tokens after ICO started but before starting block", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert(!isIcoRunning, "it should not be started yet"))
      .then(() => ico.startICO({from: owner}))
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert(isIcoRunning, "it should be started"))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: 10
      })).should.be.rejected
  })

  it("Should not get tokens after starting block but before starting ICO", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.isIcoRunning())
      .then(isIcoRunning => assert(!isIcoRunning, "it should not be started yet"))
      .then(() => setBlockAndMine())
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: 10
      })).should.be.rejected
  })

  it("should not buy tokens after ICO's finish time", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then((number) => ico.setBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => ico.setIcoFinishTime(0, {from: owner}))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: 10
      })).should.be.rejected

  })

  it("should buy 550 tokens with the fallback function", () => {
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
      .then(t => assert.strictEqual(t.toString(), web3.toWei(550, "ether"), "should be 550 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(), web3.toWei(550, "ether"), "should be 550 tokens"))
  })

  it("should buy tokens, pause the ico, resume the ico and buy tokens again", () => {
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
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(550, "ether"), "should be 550 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(10), web3.toWei(550, "ether"), "should be 550 tokens"))
      .then(() => ico.pauseICO({from: owner}))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: web3.toWei(1, "ether")
      })).should.be.rejected
      .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(550, "ether"), "should be 550 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(10), web3.toWei(550, "ether"), "should be 550 tokens"))
      .then(() => ico.resumeICO({from: owner}))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: web3.toWei(1, "ether")
      }))
      .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(1100, "ether"), "should be 1100 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(10), web3.toWei(1100, "ether"), "should be 1100 tokens"))
  })

  it("should reject a transaction of less than 100 finney", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then((number) => ico.setBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: web3.toWei(90, "finney")
      })).should.be.rejected
      .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(0, "ether"), "should be 0 tokens"))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: web3.toWei(100, "finney")
      }))
      .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(55, "ether"), "should be 0.55 tokens"))
  })

  it("should buy all tokens", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then((number) => ico.setBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => ico.setUsdPerEthRate(1500000, {from: owner}))
      .then(() => ico.usdPerEth())
      .then(u => assert.strictEqual(u.toString(10), "1500000", "should be 1500000"))
      .then(() => ico.setUsdTokenPrice(1, {from: owner}))
      .then(() => ico.usdTokenPrice())
      .then(u => assert.strictEqual(u.toString(10), "1", "should be 1"))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: web3.toWei(10, "ether")
      }))
     /* .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(15000000, "ether"), "should be 15000000 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(10), web3.toWei(15000000, "ether"), "should be 15000000 tokens"))*/
  })

  it("should buy all 15000000 tokens with overflow and payback of 2 ether", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then((number) => ico.setBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => ico.setUsdPerEthRate(1500000, {from: owner}))
      .then(() => ico.setUsdTokenPrice(1, {from: owner}))
      .then(() => web3.eth.sendTransactionPromise({
        from: buyer,
        to: ico.address,
        value: web3.toWei(12, "ether")
      }))
      .then(() => ico.icoTokensSold())
      .then(t => assert.strictEqual(t.toString(10), web3.toWei(15000000, "ether"), "should be 15000000 tokens"))
      .then(() => uac.balanceOf(buyer))
      .then(b => assert.strictEqual(b.toString(10), web3.toWei(15000000, "ether"), "should be 15000000 tokens"))
      .then(() => ico.refundAmount())
      .then(amount => assert.strictEqual(amount.toString(10), web3.toWei(2, "ether"), "should be 2 ether"))
      .then(() => ico.toBeRefund())
      .then(address => assert.strictEqual(address.toString(10), buyer, "should be buyer"))
      .then(() => ico.refund({from: owner}))
      .then(() => ico.refundAmount())
      .then(amount => assert.strictEqual(amount.toString(10), web3.toWei(0, "ether"), "should be 0 ether"))
      .then(() => ico.toBeRefund())
      .then(address => assert.strictEqual(address.toString(10), "0x0000000000000000000000000000000000000000", "should be null"))
  })

  it("should not be able to call the buyTokens() function", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, preSaleVesting.address, ubiatarPlay.address, advisorsWallet)
      .then(() => ico.startICO({from: owner}))
      .then(() => web3.eth.getBlockNumberPromise())
      .then((number) => ico.setBlockNumberStart(number, {from: owner}))
      .then(() => mineBlock())
      .then(() => ico.buyTokens(buyer, 10, {from: buyer})).should.be.rejected
  })

  it("should receive invalid PreSaleVestingAddress and then set the right one", () => {
    return ICODeploy(uac.address, uacUnsold.address, foundersVesting.address, "0x0", advisorsWallet)
      .then(() => ico.preSaleVestingAddress())
      .then(address => assert.strictEqual(address.toString(), "0x0000000000000000000000000000000000000000", "should be null"))
      .then(() => ico.setPreSaleVestingAddress(preSaleVesting.address, {from: owner}))
      .then(() => ico.preSaleVestingAddress())
      .then(address => assert.strictEqual(address.toString(), preSaleVesting.address, "should be preSaleVesting address"))
  })


})

