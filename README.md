# Introduction
![photo_2020-12-15_20-21-41](https://user-images.githubusercontent.com/18599919/111032509-ac9fbd80-841d-11eb-9639-843ef2d758b3.jpg)
Hello there! \
SVOI dev team greets you and would like to present the results of created Decentralized Exchange for the FreeTON Community contest: \
#16 FreeTon DEX Implementation Stage 1 Contest.

Goal of this work is to create Decentralized Exchange based on Liquidity Pool mechanism and develop instruments, such as 
debot and [site](https://tonswap.com) for interacting with developed smart contracts.
 
# Links
[![Channel on Telegram](https://img.shields.io/badge/-TON%20Swap%20TG%20chat-blue)](https://t.me/tonswap) 

Repository with useful instruments - [https://github.com/SVOIcom/ton-testing-suite](https://github.com/SVOIcom/ton-testing-suite)

Used ton-solidity compiler - [solidity compiler v0.36.0](https://github.com/tonlabs/TON-Solidity-Compiler/tree/5914224aa6c03def19d98c160ad8779d2efe1c50)

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

## Debot

### [debot.sol](contracts/debot/debot.sol)
Debot simplifies a lot of routine interactions with smart contracts. \
And this one is created to simplify your interaction with swap-pair contract. \
With debot you can:

1. Get user token balance - get token amounts available for providing liquidity or performing swap operation;
2. Get user LP token balance - get user's tokens that are currently in liquidity pool;
3. Ger user TON balance - get user's TON balance;
4. Get current LP functions execution cost;
5. Provide liquidity - add tokens to liquidity pool;
6. Withdraw liquidity - remove tokens from liquidity pool;
7. Get current exchange rate;
8. Swap tokens - swap user's tokens that are currently not in liquidity pool;
9. Withdraw tokens from swap pair - remove tokens from swap pair by requesting transfer of tokens to specified wallet;
10. Exit debot :)


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

There are already deployed contracts. Information about them can be found here: [deployed contracts]() \
This file contains information about TIP-3 tokens, TIP-3 token wallets, swap pairs and debot contracts, \
as well as keys for controlling those contracts.


If you have any questions - feel free to ask our team in [Telegram](https://t.me/tonswap) (or contact me in direct messages @pafaul).
