// Pre-alpha
pragma solidity >= 0.6.0;

interface IRootSwapPairUpgradePairCode {
    function setSwapPairCode(TvmCell code, uint32 codeVersion) external;
    function upgradeSwapPair(uint256 uniqueID) external view;
}