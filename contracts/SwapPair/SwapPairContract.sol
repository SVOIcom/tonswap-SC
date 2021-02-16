pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

contract SwapPairContract {
    address static token1;
    address static token2;
    address static swapPairRootContract;
    uint static swapPairID;
    uint static swapPairDeployer;

    constructor() public {

    }  
}