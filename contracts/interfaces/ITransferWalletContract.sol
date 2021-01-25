pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface ITransferWalletContract {
    function internalTransferResult(address to, uint128 tokens, uint128 grams, address callbackAddress) external;
}