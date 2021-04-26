pragma ton-solidity ^0.39.0;

library RootSwapPairConstants {
    //============Constants============

    // 1 ton required for swap pair
    // 2x1 ton required for swap pair wallets deployment
    // 2x1 + 2x0.2 required for initial stage of swap pair 
    // The rest stays at swap pair contract balance
    uint128 constant sendToNewSwapPair = 10 ton;
    uint128 constant increaseNumerator = 103;
    uint128 constant increaseDenominator = 100;
}