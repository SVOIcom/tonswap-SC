// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface ISwapPairInformation {
    struct SwapPairInfo {
        address tokenRoot1;
        address tokenRoot2;
        uint256 deployerPubkey;
        uint256 deployTimestamp;
        address swapPairAddress; 
        uint256 uniqueId;
    }

    struct UserBalanceInfo {
        address tokenRoot1;
        address tokenRoot2;
        uint128 tokenBalance1;
        uint128 tokenBalance2;
    }
}