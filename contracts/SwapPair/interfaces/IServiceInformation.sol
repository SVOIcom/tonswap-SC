pragma solidity >= 0.6.0;

import './IRootSwapPairUpgradePairCode.sol';

interface IServiceInformation {
    struct ServiceInfo {
        uint256 ownerPubkey;
        uint256 contractBalance;
        uint256 creationTimestamp;
        SwapPairCodeVersion codeVersion;
        TvmCell swapPairCode;
    }
}