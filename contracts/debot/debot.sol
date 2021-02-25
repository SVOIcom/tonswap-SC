pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "./interfaces/Debot.sol";
import "./interfaces/Terminal.sol";
import "./interfaces/AddressInput.sol";
import "./interfaces/Sdk.sol";
import "./interfaces/Menu.sol";

import "./interfaces/UserBalanceInfo.sol";

import "../SwapPair/interfaces/ISwapPairContract.sol";
import "../RIP-3/interfaces/IRootTokenContract.sol";

interface ISwapPairContract {
    function getUserTokens(uint256 publicKey) external returns (TokensBalance);
    function getPairInfo() external returns (PairInfo);
}

struct TokensInfo {
    address rootAddress;
    uint balance;
    string symbol;
}

struct TokensBalance {
    uint token1;
    uint token2;
}

struct PairInfo {
    address token1;
    address token2;
}

contract SwapDebot is Debot {
    uint static _randomNonce;

    // Information about tokens
    TokenInfo token1; TokenInfo token2;

    // Variables to store user input
    uint tokenAmount; 
    address chosenToken;
    address swapPairAddress;    
    uint128 maxTokenAmount;
    
    // Available actions: swap tokens or withdraw tokens
    uint8 state;
    uint8 SWAP = 0;
    uint8 WITHDRAW_TOKENS = 1;

    constructor(string swapDebotAbi) public {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();
        init(DEBOT_ABI, swapDebotAbi, "", address(0));
    }

    function fetch() public override returns (Context[] contexts) {}

    function start() public override {
        Menu.select("Main menu", "Hello, this is debot for swap pairs from SVOI.dev! You can swap tokens and withdraw them from pair.", [
            MenuItem("Swap tokens", "", tvm.functionId(actionChoice)),
            MenuItem("Withdraw tokens", "", tvm.functionId(actionChoice)),
            MenuItem("Exit debot", "", 0)
        ]);
    }

    // Current version is 0.0.1
    function getVersion() public override returns(string name, uint24 semver) {
        name = "SwapDeBot"; 
        semver = 1; 
    }

    function quit() public override {}

    // Input of pair address
    function actionChoice(uint32 index) public { 
        state = uint8(index);
        Terminal.print(0, "Please input swap pair address");
        AddressInput.select(tvm.functionId(processPair));
    }
    
    // Requesting pair contract status 
    function processPair(address value) public {  
        swapPairAddress = value;
        Sdk.getAccountType(tvm.functionId(checkIfPairExitst), value);
    }

    // Checking pair status. Must be active to proceed
    function checkIfPairExitst(uint acc_type) public {
        if (acc_type != 1) {
            Terminal.print(tvm.functionId(start), "Wallet does not exist or is not active. Going back to main menu");
        } else {
            Terminal.print(tvm.functionId(getUserTokens), "Looks like wallet exists and is active. Getting info about available tokens...");
        }
    }

    // Requesting information about user's tokens from pair contract
    function getUserTokens() public {
        optional(uint256) pubkey;
        TvmCell cell = tvm.buildExtMsg({
            time: uint64(now),
            expire:  0,
            pubkey: pubkey,
            sign: true,
            abiVer: 2,
            dest: value,
            call: {
                ISwapPairContract.getUserTokens
            },
            callbackId: tvm.functionId(setTokenInfo),
            onErrorId: 0,
        });
    }

    // set token information
    function setTokenInfo(UserTokenInfo tokenInfo) public {
        token1.rootAddress = tokenInfo.root1;
        token1.balance = tokenInfo.balance1;
        token2.rootAddress = tokenInfo.root2;
        token2.balance = tokenInfo.balance2;
        Terminal.print(tvm.functionId(chooseToken), format("Your balance: {} for {}; {} for {}", token1.balance, token1.rootAddress, token2.balance, token2.rootAddress));
    }

    // Choice of token to operate with
    function chooseToken() public {
        Menu.select("", "Select active token (for swap - token you want to swap): ", [
            MenuItem(token1.rootAddress, "", tvm.functionId(getTokenAmount)),
            MenuItem(token2.rootAddress, "", tvm.functionId(getTokenAmount))
        ]);
    }


    function getTokenAmount(uint32 index) public {
        maxTokenAmount = (index == 0) ? token1.balance : token2.balance; 
        chosenToken = (index == 0) ? token1.rootAddress : token2.rootAddress;
        Terminal.inputUint(tvm.functionId(validateTokenAmount), "Input token amount: ");
    }

    function validateTokenAmount(uint value) public {
        if (value > maxTokenAmount) {
            Terminal.print(tvm.functionId(chooseToken), "Sum is too high. Please, reenter your token choice and token amount.");
        } else {
            tokenAmount = value;
            uint32 fid = (state == SWAP) ? tvm.functionId(submitSwap) : tvm.functionId(submitTokenWithdraw);
            string message = (state == SWAP) ? "Proceeding to token swap submit stage" : "Proceeding to token removal submit stage";
            Terminal.print(fid, message);
        }
    }

    function submitSwap() public {
        TvmCell cell = tvm.buildExtMsg({
            time: uint64(now),
            expire:  0,
            pubkey: pubkey,
            sign: true,
            abiVer: 2,
            dest: swapPairAddress,
            call: {
                ISwapPairContract.Swap,
                chosenToken,
                tokenAmount
            },
            callbackId: tvm.functionId(showSwapOrderId),
            onErrorId: 0,
        });
        tvm.sendrawmsg(cell, 1);
    }

    function showSwapOrderId(uint orderId) {
        Terminal.print(tvm.functionId(start), format("Swap order published. Order Id: {}", orderId));
    }

    function submitTokenWithdraw() public {
        TvmCell cell = tvm.buildExtMsg({
            time: uint64(now),
            expire:  0,
            pubkey: pubkey,
            sign: true,
            abiVer: 2,
            dest: swapPairAddress,
            call: {
                ISwapPairContract.withdrawTokenб
                chosenToken,
                tokenAmount
            },
            callbackId: tvm.functionId(showTokenWithdrawResullt),
            onErrorId: 0,
        });
        tvm.sendrawmsg(cell, 1);
    }

    function showTokenWithdrawResullt() public {
        Terminal.print(0, "Token withdraw completed");
    }

    // function setUserTokenBalance(TokensBalance tokensBalance) public {

    // }

    // function getInfoAboutTokens(IRootTokenContractDetails rootInfo) {
    //     if (msg.sender == token1.rootAddress) {
    //         token1.symbol = rootInfo.symbol;
    //     } else {
    //         token2.symbol = rootInfo.symbol;
    //     }
    // }

    // function sendRootMsg(address root) private inline view {
    //     TvmCell cell = tvm.buildExtMsg({
    //         abiVer: 2,
    //         callbackId: tvm.functionId(getInfoAboutTokens),
    //         onErrorId: 0,
    //         time: uint64(now),
    //         expire:  uint64(now) + 100,
    //         pubkey: pubkey,
    //         dest: swapPairAddress,
    //         call: {
    //             IRootTokenContract.getDetails,
    //         },
    //     });
    //     tvm.sendrawmsg(cell, 1);
    // }
}
