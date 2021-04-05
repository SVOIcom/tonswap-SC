pragma ton-solidity ^0.39.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface IUpgradeSwapPairCode {
    function checkIfSwapPairUpgradeRequired(uint32 newCodeVersion) external returns(bool);
    function updateSwapPairCode(TvmCell newCode, uint32 newCodeVersion) external;
}