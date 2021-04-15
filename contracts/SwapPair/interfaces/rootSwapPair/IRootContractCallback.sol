pragma ton-solc ^0.39.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../swapPair/ISwapPairInformation.sol';

interface IRootContractCallback is ISwapPairInformation {
    function swapPairInitializedCallback(SwapPairInfo spi) external;
}