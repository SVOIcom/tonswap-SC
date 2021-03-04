pragma ton-solidity ^ 0.36.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './IRootSwapPairUpgradePairCode.sol';

interface IServiceInformation is IRootSwapPairUpgradePairCode {
    struct ServiceInfo {
        uint256 ownerPubkey;
        uint256 contractBalance;
        uint256 creationTimestamp;
        uint32 codeVersion;
        TvmCell swapPairCode;
    }
}