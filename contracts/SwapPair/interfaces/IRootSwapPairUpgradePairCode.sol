pragma ton-solidity >= 0.6.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface IRootSwapPairUpgradePairCode {

    function setSwapPairCode(TvmCell code, uint32 codeVersion) external;

    function upgradeSwapPair(uint256 uniqueID) external;

    // Events
    event SetSwapPairCode(uint32 codeVersion);
    event UpgradeSwapPair(uint256 uniqueID, uint32 codeVersion);
}