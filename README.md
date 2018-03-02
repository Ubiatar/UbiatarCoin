# UbiatarCoin ICO Smart Contracts


### UAC
The UAC token is a standard ERC20 token that can be used by multiple wallets and
trading platforms.
The token will be used as the only currency for interacting with the UbiatarPlay platform.

### ICO

This is the official project for UAC token and crowdsale smart contracts.


### Development

UAC smart contracts use truffle and open zeppelin frameworks.
In order to compile and deploy the contracts you need to install truffle first.

Read more about [Truffle](http://truffleframework.com/).

Read more about [OpenZeppelin](https://openzeppelin.org/).

### Install

```
$ npm install
```

### Deploy

Deploy in order
```
1. UAC
2. UACUnsold
3. FoundersVesting
4. PreSaleVesting
5. UbiatarPlay
6. ICO
```
Set addresses in contracts
```
1. set ICO contract address in UAC, PreSaleVesting, UbiatarPlay and FoundersVesting
2. Set foundersTokenHolder in FoundersVesting
3. Set ubiatarColdWallet in ICO
4. Set ubiatarPlayTokenHolder in UbiatarPlay
foundersTokenHolder, ubiatarColdWallet and ubiatarPlayTokenHolder are wallets
```
### Documentation

Please see the [UbiatarPlay ICO site](http://ubiatarplay.io) for the whitepaper and for ICO launch details. 
