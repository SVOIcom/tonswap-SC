pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface IBurnableByRootTokenWallet {
    function burnByRoot(
        uint128 tokens,
        address callback_address,
        TvmCell callback_payload
    ) external;
}
