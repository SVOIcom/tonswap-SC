pragma ton-solidity ^0.39.0;

library RootSwapPairContractErrors {
    uint8 constant ERROR_MESSAGE_SENDER_IS_NOT_DEPLOYER       = 100;
    uint8 constant ERROR_MESSAGE_SENDER_IS_NOT_OWNER          = 101; 
    uint8 constant ERROR_PAIR_DOES_NOT_EXIST                  = 102; 
    uint8 constant ERROR_PAIR_ALREADY_EXISTS                  = 103; 
    uint8 constant ERROR_MESSAGE_VALUE_IS_TOO_LOW             = 104; 
    uint8 constant ERROR_CODE_IS_NOT_UPDATED_OR_IS_DOWNGRADED = 105; 
    uint8 constant ERROR_PAIR_WITH_ADDRESS_DOES_NOT_EXIST     = 106;

    string constant ERROR_MESSAGE_SENDER_IS_NOT_DEPLOYER_MSG       = "Error: Message sender is not deployer";
    string constant ERROR_MESSAGE_SENDER_IS_NOT_OWNER_MSG          = "Error: Message sender is not owner";
    string constant ERROR_PAIR_DOES_NOT_EXIST_MSG                  = "Error: Swap pair does not exist";
    string constant ERROR_PAIR_ALREADY_EXISTS_MSG                  = "Error: Swap pair already exists";
    string constant ERROR_MESSAGE_VALUE_IS_TOO_LOW_MSG             = "Error: Message value is below required minimum";
    string constant ERROR_CODE_IS_NOT_UPDATED_OR_IS_DOWNGRADED_MSG = "Error: Pair code is not updated or is downgraded";
    string constant ERROR_PAIR_WITH_ADDRESS_DOES_NOT_EXIST_MSG     = "Error: Pair with specified address does not exist";
}