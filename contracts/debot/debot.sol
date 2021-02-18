pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import "./interfaces/AddressInput.sol";
import "./interfaces/Debot.sol";
import "./interfaces/Menu.sol";
import "./interfaces/Sdk.sol";
import "./interfaces/Terminal.sol";

interface ISwapPairContract {
    function getUserTokens(uint256 publicKey) public returns (TokensBalance);
}

contract SwapDebot is Debot, Menu, Sdk, Terminal, AddressInput {
    // For user usage
    address swapPairAddress;
    address token1; address token2;
    string token1Symbol; string token2Symbol;
    uint128 token1Balance; uint128 token2Balance;
    uint8 state;

    uint8 SWAP = 1;
    uint8 GET_TOKENS = 2;

    constructor(string swapDebotAbi) {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();
        init(DEBOT_ABI, swapDebotAbi, "", address(0));
    }

    function fetch() public override returns (Context[] contexts) {}

    function start() public override {
        Menu.select("Main menu", "Hello, this is debot for swap pairs from SVOI.dev! You can swap tokens and get them from pair.", [
            MenuItem("Swap tokens", "", tvm.functionId(swapTokens)),
            MenuItem("Get tokens back", "", tvm.functionId(getTokensFromPair)),
            MenuItem("Exit debot", "", 0)
        ]);
    }

    function swapTokens(uint32 index) public { 
        action = SWAP;
        Terminal.input(0, "Please input swap pair address");
        AddressInput.select(tvm.functionId(processPair));
    }

    function processPair(address value) {  
        Sdk.getAccountType(tvm.functionId(checkIfWalletExists), value);
    }

    function checkIfWalletExists(uint acc_type) public {
        if (acc_type != 1) {
            Terminal.print(tvm.functionId(start), "Wallet does not exist or is not active. Going back to main menu");
        } else {
            Terminal.print(tvm.functionId(getUserTokens), "Looks like wallet exists and is active. Getting info about available tokens...");
        }
    }

    function getUserTokens() public {

    }

    function getTokenInfo() public {

    }

    function chooseToken() public {

    }

    function getTokenAmount() public {

    }

    function validateTokenAmount() public {

    }

    function submitSwap() public {

    }

    function submitTokenRemoval() public {

    }

    function getTokensFromPair(uint32 index) public {
        action = GET_TOKENS;
        Terminal.input(0, "Please input swap pair address");
        AddressInput.select(tvm.functionId(processPair));
    }
}
