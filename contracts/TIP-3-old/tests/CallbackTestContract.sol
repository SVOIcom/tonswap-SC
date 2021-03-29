pragma ton-solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;

import "../interfaces/ITokensReceivedCallback.sol";

contract TestContract is ITokensReceivedCallback {
    uint256 static _randomNonce;

    uint256 sender_public_key_;
    address sender_address_;
    address receiver_address_;
    uint128 amount_;

    function tokensReceivedCallback(
        address token_wallet,
        address token_root,
        uint128 amount,
        uint256 sender_public_key,
        address sender_address,
        address sender_wallet,
        address original_gas_to,
        uint128 updated_balance,
        TvmCell payload
    ) external override {
        sender_public_key_ = sender_public_key;
        sender_address_ = sender_address;
        receiver_address_ = msg.sender;
        amount_ = amount;
    }

    function getResult()
        external
        view
        returns (address sender, address receiver, uint128 amount, uint256 sender_public_key)
    {
        tvm.accept();
        sender = sender_address_;
        receiver = receiver_address_;
        amount = amount_;
        sender_public_key = sender_public_key_;
    }
}