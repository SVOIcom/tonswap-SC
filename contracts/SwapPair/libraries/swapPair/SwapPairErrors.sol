pragma ton-solidity ^0.39.0;

library SwapPairErrors {
    uint8 constant CONTRACT_ALREADY_INITIALIZED  = 100;   string constant CONTRACT_ALREADY_INITIALIZED_MSG  = "Error: contract is already initialized";
    uint8 constant CONTRACT_NOT_INITIALIZED      = 101;   string constant CONTRACT_NOT_INITIALIZED_MSG      = "Error: contract is not initialized";
    uint8 constant CALLER_IS_NOT_TOKEN_ROOT      = 102;   string constant CALLER_IS_NOT_TOKEN_ROOT_MSG      = "Error: msg.sender is not token root";
    uint8 constant CALLER_IS_NOT_TOKEN_WALLET    = 103;   string constant CALLER_IS_NOT_TOKEN_WALLET_MSG    = "Error: msg.sender is not token wallet";
    uint8 constant CALLER_IS_NOT_SWAP_PAIR_ROOT  = 104;   string constant CALLER_IS_NOT_SWAP_PAIR_ROOT_MSG  = "Error: msg.sender is not swap pair root contract";
    uint8 constant CALLER_IS_NOT_OWNER           = 105;   string constant CALLER_IS_NOT_OWNER_MSG           = "Error: msg.sender is not not owner";
    uint8 constant CALLER_IS_NOT_TIP3_DEPLOYER   = 106;   string constant CALLER_IS_NOT_TIP3_DEPLOYER_MSG   = "Error: msg.sender is not tip3 deployer";
    uint8 constant LOW_MESSAGE_VALUE             = 107;   string constant LOW_MESSAGE_VALUE_MSG             = "Error: msg.value is too low"; 
    uint8 constant NO_MESSAGE_SIGNATURE          = 108;   string constant NO_MESSAGE_SIGNATURE_MSG          = "Error: message is not signed"; 

    uint8 constant INVALID_TOKEN_ADDRESS         = 110;   string constant INVALID_TOKEN_ADDRESS_MSG         = "Error: invalid token address";
    uint8 constant INVALID_TOKEN_AMOUNT          = 111;   string constant INVALID_TOKEN_AMOUNT_MSG          = "Error: invalid token amount";
    uint8 constant INVALID_TARGET_WALLET         = 112;   string constant INVALID_TARGET_WALLET_MSG         = "Error: specified token wallet cannot be zero address";
    uint8 constant TARGET_ADDRESS_IS_ZERO        = 113;   string constant TARGET_ADDRESS_IS_ZERO_MSG        = "Error: requested ton transfer to zero address";
    
    uint8 constant INSUFFICIENT_USER_BALANCE     = 120;   string constant INSUFFICIENT_USER_BALANCE_MSG     = "Error: insufficient user balance";
    uint8 constant INSUFFICIENT_USER_LP_BALANCE  = 121;   string constant INSUFFICIENT_USER_LP_BALANCE_MSG  = "Error: insufficient user liquidity pool balance";
    uint8 constant UNKNOWN_USER_PUBKEY           = 122;   string constant UNKNOWN_USER_PUBKEY_MSG           = "Error: unknown user's pubkey";
    uint8 constant LOW_USER_BALANCE              = 123;   string constant LOW_USER_BALANCE_MSG              = "Error: user TON balance is too low";
    
    uint8 constant NO_LIQUIDITY_PROVIDED         = 130;   string constant NO_LIQUIDITY_PROVIDED_MSG         = "Error: no liquidity provided";
    uint8 constant LIQUIDITY_PROVIDING_RATE      = 131;   string constant LIQUIDITY_PROVIDING_RATE_MSG      = "Error: added liquidity disrupts the rate";
    uint8 constant INSUFFICIENT_LIQUIDITY_AMOUNT = 132;   string constant INSUFFICIENT_LIQUIDITY_AMOUNT_MSG = "Error: zero liquidity tokens provided or provided token amount is too low";

    uint8 constant CODE_DOWNGRADE_REQUESTED      = 200;   string constant CODE_DOWNGRADE_REQUESTED_MSG      = "Error: code downgrade requested";
    uint8 constant CODE_UPGRADE_REQUESTED        = 201;   string constant CODE_UPGRADE_REQUESTED_MSG        = "Error: code upgrade requested";
}