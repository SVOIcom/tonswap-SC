// Pre-alpha
pragma solidity >= 0.6.0;

interface IRootSwapPairUpgradePairCode {
    struct SwapPairCodeVersion {
        uint8 contractCodeVersion;
    }
    
    function setSwapPairCode(TvmCell code, SwapPairCodeVersion codeVersion) external;
    function upgradeSwapPair(uint256 uniqueID) external view;
}