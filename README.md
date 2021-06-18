# Introduction
![photo_2020-12-15_20-21-41](https://user-images.githubusercontent.com/18599919/111032509-ac9fbd80-841d-11eb-9639-843ef2d758b3.jpg)
Hello there! \
SVOI dev team greets you and would like to present the results of created Decentralized Exchange for the FreeTON Community contest: \
#23 FreeTon DEX Implementation Stage 2 Contest.

Goal of this work is to create Decentralized Exchange based on Liquidity Pool mechanism and develop instruments, such as 
debot and [site](https://tonswap.com) for interacting with developed smart contracts.
 
# Links
[![Channel on Telegram](https://img.shields.io/badge/-TON%20Swap%20TG%20chat-blue)](https://t.me/tonswap) 

Repository for smart contracts compilation and deployment - [https://github.com/SVOIcom/ton-testing-suite](https://github.com/SVOIcom/ton-testing-suite)

Used ton-solidity compiler - [solidity compiler v0.39.0](https://github.com/broxus/TON-Solidity-Compiler/tree/98892ddbd2817784857b54436d75b64a3fdf6eb1)

Used tvm-linker - [latest tvm linker](https://github.com/tonlabs/TVM-linker)

# tonswap-SC
This repository contains smart contracts that are used for ```Decentralized Exchange``` based on ```Liquidity Pairs```

# Smart contracts description

## Swap pair contracts
There are two main contracts related to swap pair - RootSwapPairContract and SwapPairContract. \
RootSwapPairContract is used to deploy swap pair contract, update it and store information about already deployed swap pairs to prevent dublication of swap pairs. \
SwapPairContract is used to implement liquidity pool swap mechanics and to provide access to it for users. 

Below is short description of iterfaces and smart contracts.

### Interfaces

These interfaces may be used to implement smart contracts that interact with swap pair or swap pair root contract

#### [IRootSwapPairContract.sol](contracts/SwapPair/IRootSwapPairContract.sol)

Contains main functionality of RootSwapPairContract - deployment of swap pair
#### [IRootSwapPairUpgradePairCode.sol](contracts/SwapPair/IRootSwapPairUpgradePairCode.sol)

Contains functions for swap pair contract upgrade

#### [IServiceInformation.sol](contracts/SwapPair/IServiceInformation.sol)

Contains structure with service information

#### [ISwapPairContract.sol](contracts/SwapPair/ISwapPairContract.sol)

Contains main functionality of SwapPairContract

#### [ISwapPairDebug.sol](contracts/SwapPair/ISwapPairDebug.sol)

Contains debug functions of SwapPairContract which could be implemented if debug version is required

#### [ISwapPairInformation.sol](contracts/SwapPair/ISwapPairInformation.sol)

Contains information structures used in SwapPairContract

#### [IUpgradeSwapPairCode.sol](contracts/SwapPair/IUpgradeSwapPairCode.sol)

Contains function to upgrade swap pair code

### Contracts

#### [RootSwapPairContract.sol](contracts/SwapPair/RootSwapPairContract.sol)

This is RootSwapPairContract. It is mainly used to deploy swap pairs.

#### [SwapPairContract.sol](contracts/SwapPair/SwapPairContract.sol)

Contract implementing liquidity pair mechanism

## Tokens
Used tokens are TIP-3 tokens initially developed by Broxus for bridges between Ethereum and TON. \
We decided that it will be great not to create a ton of new TIP-3 token types and used already existing and working solution.

### Interfaces

Interfaces can be found at [contracts/TIP-3/interfaces/](contracts/TIP-3/interfaces)

### Contracts

Contracts can be found at [contracts/TIP-3/](contracts/TIP-3/)

## [Additional contracts](contracts/additional)
Some additional contracts that can help you to deploy your own swap pair or tokens

# Contract compilation and deployment

There are compiled contracts at [release page](https://github.com/SVOIcom/tonswap-SC/tags). You can use them for quick start. \
If you want to compile smart contracts - please check repository [https://github.com/SVOIcom/ton-testing-suite](https://github.com/SVOIcom/ton-testing-suite) \
There you will find instructions and instruments for smart contract compilation and testing/deploying test swap pair and debot contracts.

## Pre-deployed smart contracts for tests

Deployed root swap pair contract: ```0:3dc2f941650dbb757e47363109841a943c04a4824a6652b8be7377b945603137```
Deployed test swap pair contract: ```0:12987e0102acf7ebfe916da94a1308540b9894b3b99f8d5c7043a39725c08bdf```


If you have any questions - feel free to ask our team in [Telegram](https://t.me/tonswap).
