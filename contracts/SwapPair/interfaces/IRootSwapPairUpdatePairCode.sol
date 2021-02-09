pragma solidity >= 0.6.0;

interface IRootSwapPairUpdatePairCode {
    function getCode() external returns (TvmCell code);
    function setCode(TvmCell) external;
    function getCodeVersion() external returns (uint8 majorVersion, uint8 minorVersion);
    function upgradeSwapPair(address pairAddress) external;
}