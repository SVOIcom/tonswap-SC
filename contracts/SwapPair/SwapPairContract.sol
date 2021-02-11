pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

contract SwapPairContract {
    address static token1;
    address static token2;
    uint static swapPairDeployer;
    uint static swapPairID;

    constructor() public {

    }  
}