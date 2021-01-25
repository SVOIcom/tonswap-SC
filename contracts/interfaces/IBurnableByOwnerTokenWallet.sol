pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface IBurnableByOwnerTokenWallet {
    function burnByOwner(
        uint128 tokens,
        uint128 grams,
        address callback_address,
        TvmCell callback_payload
    ) external;
}
