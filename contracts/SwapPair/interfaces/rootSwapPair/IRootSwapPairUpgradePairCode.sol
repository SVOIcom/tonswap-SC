pragma ton-solidity ^0.39.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface IRootSwapPairUpgradePairCode {

    function setSwapPairCode(TvmCell code, uint32 codeVersion) external;

    function upgradeSwapPair(address tokenRootContract1, address tokenRootContract2) external;

    // Events
    event SetSwapPairCode(uint32 codeVersion);
    event UpgradeSwapPair(uint256 uniqueID, uint32 codeVersion);
}