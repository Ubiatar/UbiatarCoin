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

### Unit Testing

Compile contracts first of all

```
$ npm run compile
```

and test them

```
$ npm run test
```

### Deploy

Deploy in order
```
1. UAC
2. UACUnsold
3. FoundersVesting
4. PreSaleVesting
5. UbiatarPlay
6. ReservationContract
7. ICO
```
Set addresses in contracts
```
1. set ICO contract address in UAC, PreSaleVesting, UbiatarPlay, FoundersVesting and ReservationContract
2. Set foundersTokenHolder in FoundersVesting
3. Set ubiatarColdWallet and RCContractAddress in ICO
4. Set ubiatarPlayTokenHolder in UbiatarPlay
5. Set uacTokenAddress in ReservationContract
6. In ReservationContract set the same usdTokenPrice and UsdPerEthRate as the ICO contract
   then call getIcoBlockNumberStart() to get the ico block number start, then set the rcBlockNumberStart
   
foundersTokenHolder, ubiatarColdWallet and ubiatarPlayTokenHolder are wallets
```
### Documentation

Please see the [UbiatarPlay ICO site](http://ubiatarplay.io) for the whitepaper and for ICO launch details. 
