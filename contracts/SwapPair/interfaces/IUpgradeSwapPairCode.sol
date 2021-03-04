pragma ton-solidity ^ 0.36.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface IUpgradeSwapPairCode {
    function updateSwapPairCode(TvmCell newCode, uint32 newCodeVersion) external;
}