# tonswap-SC
Smart contracts for TONSwap project

# Smart contracts
When writing a smart contract please add following line to contract: \
```uint static _randomNonce;``` \
This is required for testing, because it allows to deploy multiple similar 
contracts (it changes hashsum of initial parameters)