/**
 * Created by antoniogiordano on 26/10/2017.
 */

const nope = () => null

const Web3 = require('web3')
const web3 = new Web3()

const TestRPC = require('ethereumjs-testrpc')
web3.setProvider(TestRPC.provider())

const Promise = require('bluebird')
Promise.promisifyAll(web3.eth, {suffix: "Promise"})
Promise.promisifyAll(web3.version, {suffix: "Promise"})

const assert = require('assert-plus')
const chai = require('chai').use(require('chai-as-promised'))
const should = chai.should()

const truffleContract = require("truffle-contract")

const SafeMath = truffleContract(require(__dirname + "/../build/contracts/SafeMath.json"))
const Owned = truffleContract(require(__dirname + "/../build/contracts/Owned.json"))
SafeMath.setProvider(web3.currentProvider)
Owned.setProvider(web3.currentProvider)

describe("Owned changing owner", () => {
    var accounts, networkId, owned, safeMath
    var owner, newOwner, attacker

    before("get accounts", () => {
        return web3.eth.getAccountsPromise()
            .then(_accounts => accounts = _accounts)
            .then(() => web3.version.getNetworkPromise())
            .then(_networkId => {
                networkId = _networkId
                Owned.setNetwork(networkId)
                owner = accounts[0]
                newOwner = accounts[1]
                attacker = accounts[2]
            })
    })

    before("deploy owned", () => {
        return Owned.new({from: accounts[0]})
            .then(_owned => owned = _owned)
    })

    before("deploy safemath", () => {
        return SafeMath.new({from: accounts[0]})
            .then(_safeMath => safeMath = _safeMath)
            .then(() => Owned.link({SafeMath: safeMath.address}))
    })

    it("should set newOwner as a new candidate", () => {
        return owned.candidateOwner()
            .then(() => owned.setCandidate(newOwner, {from: owner}))
            .then(() => owned.candidateOwner())
            .then(candidateOwner => assert.strictEqual(
                candidateOwner.toString(),
                newOwner,
                "should set candidateOwner to newOwner"))
    })

    it("shouldn't set newOwner as a new candidate", function () {
        return owned.candidateOwner()
            .then(() => owned.setCandidate(newOwner, {from: newOwner}).should.be.rejected)
    })

    it("should set newOwner as the new owner and back to original owner", () => {
        return owned.owner()
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should be owner"))
            .then(() => owned.setCandidate(newOwner, {from: owner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should be owner"))
            .then(() => owned.getOwnership({from: newOwner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                newOwner,
                "should set owner to newOwner"))
            .then(() => owned.setCandidate(newOwner, {from: owner}).should.be.rejected)
            .then(() => owned.setCandidate(owner, {from: newOwner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                newOwner,
                "should be newOwner"))
            .then(() => owned.getOwnership({from: owner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should set owner to original owner"))
    })

    it("should not getOWnership from other accounts", () => {
        return owned.owner()
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should be owner"))
            .then(() => owned.setCandidate(newOwner, {from: owner}))
            .then(() => owned.getOwnership({from: attacker}).should.be.rejected)
            .then(() => owned.setCandidate(attacker, {from: attacker}).should.be.rejected)
            .then(() => owned.setCandidate(newOwner, {from: newOwner}).should.be.rejected)
            .then(() => owned.getOwnership({from: newOwner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should set owner to newOwner"))
    })
})

describe("Owned contract attack", () => {
    var accounts, networkId, owned, safeMath
    var owner, newOwner, attacker

    before("get accounts", () => {
        return web3.eth.getAccountsPromise()
            .then(_accounts => accounts = _accounts)
            .then(() => web3.version.getNetworkPromise())
            .then(_networkId => {
                networkId = _networkId
                Owned.setNetwork(networkId)
                owner = accounts[0]
                newOwner = accounts[1]
                attacker = accounts[2]
            })
    })

    before("deploy owned", () => {
        return Owned.new({from: accounts[0]})
            .then(_owned => owned = _owned)
    })

    before("deploy safemath", () => {
        return SafeMath.new({from: accounts[0]})
            .then(_safeMath => safeMath = _safeMath)
            .then(() => Owned.link({SafeMath: safeMath.address}))
    })

    it("should set newOwner as a new candidate", () => {
        return owned.candidateOwner()
            .then(() => owned.setCandidate(newOwner, {from: owner}))
            .then(() => owned.candidateOwner())
            .then(candidateOwner => assert.strictEqual(
                candidateOwner.toString(),
                newOwner,
                "should set candidateOwner to newOwner"))
    })

    it("shouldn't set newOwner as a new candidate", () => {
        return owned.candidateOwner()
            .then(() => owned.setCandidate(newOwner, {from: newOwner}).should.be.rejected)
    })

    it("should set newOwner as the new owner and back to original owner", () => {
        return owned.owner()
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should be owner"))
            .then(() => owned.setCandidate(newOwner, {from: owner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should be owner"))
            .then(() => owned.getOwnership({from: newOwner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                newOwner,
                "should set owner to newOwner"))
            .then(() => owned.setCandidate(newOwner, {from: owner}).should.be.rejected)
            .then(() => owned.setCandidate(owner, {from: newOwner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                newOwner,
                "should be newOwner"))
            .then(() => owned.getOwnership({from: owner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should set owner to original owner"))
    })

    it("should not getOWnership from other accounts", () => {
        return owned.owner()
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should be owner"))
            .then(() => owned.setCandidate(newOwner, {from: owner}))
            .then(() => owned.getOwnership({from: attacker}).should.be.rejected)
            .then(() => owned.setCandidate(attacker, {from: attacker}).should.be.rejected)
            .then(() => owned.setCandidate(newOwner, {from: newOwner}).should.be.rejected)
            .then(() => owned.getOwnership({from: newOwner}))
            .then(() => owned.owner())
            .then(owner => assert.strictEqual(
                owner.toString(),
                owner,
                "should set owner to newOwner"))
    })
})