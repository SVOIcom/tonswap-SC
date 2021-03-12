pragma ton-solidity ^0.36.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./interfaces/Debot.sol";
import "./interfaces/Terminal.sol";
import "./interfaces/AddressInput.sol";
import "./interfaces/Sdk.sol";
import "./interfaces/Menu.sol";
import "../SwapPair/interfaces/ISwapPairInformation.sol";

import "../SwapPair/interfaces/ISwapPairInformation.sol";
import "../SwapPair/interfaces/ISwapPairContract.sol";

import "../RIP-3/interfaces/IRootTokenContract.sol";

struct TokensInfo {
    address rootAddress;
    uint128 balance;
    string symbol;
}

struct TokensBalance {
    uint128 token1;
    uint128 token2;
}

struct PairInfo {
    address token1;
    address token2;
}

contract SwapDebot is Debot, ISwapPairInformation {
    uint static _randomNonce;

    // Information about tokens
    TokensInfo token1; TokensInfo token2;

    // Variables to store user input
    uint128 tokenAmount; 
    address chosenToken;
    address swapPairAddress;    
    uint128 maxTokenAmount;

    TokensBalance lpAddWithdraw;
    
    // Available actions: swap tokens or withdraw tokens
    uint8 state;

    uint8 constant USER_TOKEN_BALANCE        = 0;
    uint8 constant USER_LP_TOKEN_BALANCE     = 1;
    uint8 constant PROVIDE_LIQUIDITY         = 2;
    uint8 constant REMOVE_LIQUIDITY          = 3;
    uint8 constant GET_EXCHANGE_RATE         = 4;
    uint8 constant SWAP                      = 5;
    uint8 constant WITHDRAW_TOKENS_FROM_PAIR = 6;

    constructor(string swapDebotAbi) public {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();
        init(DEBOT_ABI, swapDebotAbi, "", address(0));
    }

    function fetch() public override returns (Context[] contexts) {}

    function start() public override {
        Terminal.print(tvm.functionId(mainMenu), "Hello, this is debot for swap pairs from SVOI.dev! You can swap tokens and withdraw them from pair.");
    }

    function getVersion() public override returns(string name, uint24 semver) {name = "SwapDeBot"; semver = 1 << 7 + 1; }
    function quit() public override {}

    function mainMenu() public {
        Menu.select("Main menu", "", [
            MenuItem("Get user token balance",         "", tvm.functionId(actionChoice)),
            MenuItem("Get user LP token balance",      "", tvm.functionId(actionChoice)),
            MenuItem("Provide liquidity",              "", tvm.functionId(actionChoice)),
            MenuItem("Withdraw liquidity",             "", tvm.functionId(actionChoice)),
            MenuItem("Get current exchange rate",      "", tvm.functionId(actionChoice)),
            MenuItem("Swap tokens",                    "", tvm.functionId(actionChoice)),
            MenuItem("Withdraw tokens from swap pair", "", tvm.functionId(actionChoice)),
            MenuItem("Exit debot", "", 0)
        ]);
    }

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

    function checkIfPairExitst(uint acc_type) public {
        if (acc_type != 1) {
            Terminal.print(tvm.functionId(mainMenu), "Swap pair does not exist or is not active. Going back to main menu");
        } else {
            string phrase = (state == USER_TOKEN_BALANCE || state == USER_LP_TOKEN_BALANCE) ? "Fetching required info..." : "Looks like swap pair exists and is active. Getting info about available tokens...";
            Terminal.print(tvm.functionId(getUserTokens), phrase);
        }
    }

    // Requesting information about user's tokens from pair contract
    function getUserTokens() public {
        optional(uint256) pubkey = 0;
        if (state == USER_TOKEN_BALANCE || state == PROVIDE_LIQUIDITY || state == SWAP ||state == WITHDRAW_TOKENS_FROM_PAIR)
            ISwapPairContract(swapPairAddress).getUserBalance{
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: pubkey,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(setTokenInfo),
                onErrorId: 0
            }(0);
        else 
            ISwapPairContract(swapPairAddress).getUserLiquidityPoolBalance{
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: pubkey,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(setLPTokenInfo),
                onErrorId: 0
            }(0);
    }

    // set token information
    function setTokenInfo(UserBalanceInfo ubi) public {
        token1.rootAddress = ubi.tokenRoot1;
        token1.balance = ubi.tokenBalance1;
        token2.rootAddress = ubi.tokenRoot2;
        token2.balance = ubi.tokenBalance2;
        Terminal.print(0, "Your available tokens (not in liquidity pool):");
        Terminal.print(0, format("{} for {}", token1.balance, token1.rootAddress));
        Terminal.print(tvm.functionId(choseNextStep), format("{} for {}", token2.balance, token2.rootAddress));
    }

    function setLPTokenInfo(UserPoolInfo upi) public {
        token1.rootAddress = upi.tokenRoot1;
        token2.rootAddress = upi.tokenRoot2;
        token1.balance = math.muldiv(upi.lpToken1, upi.userLiquidityTokenBalance, upi.liquidityTokensMinted);
        token2.balance = math.muldiv(upi.lpToken2, upi.userLiquidityTokenBalance, upi.liquidityTokensMinted);
        Terminal.print(0, "Your tokens in liquidity pool:");
        Terminal.print(0, format("{} for {}", token1.balance, token1.rootAddress));
        Terminal.print(tvm.functionId(choseNextStep), format("{} for {}", token2.balance, token2.rootAddress));
    }

    

    // Choice of token to operate with
    function choseNextStep() public {
        if (state == USER_TOKEN_BALANCE || state == USER_LP_TOKEN_BALANCE) {
            Terminal.print(tvm.functionId(mainMenu), "Returning to main menu");
        } else if (state == SWAP || state == WITHDRAW_TOKENS_FROM_PAIR) {
            Menu.select("", "Select active token (for swap - token you want to swap): ", [
                MenuItem(format("{}", token1.rootAddress), "", tvm.functionId(getTokenAmount)),
                MenuItem(format("{}", token2.rootAddress), "", tvm.functionId(getTokenAmount))
            ]);
        } else if (state == PROVIDE_LIQUIDITY || state == REMOVE_LIQUIDITY) {
            string headT1 = "Input first token amount to ";
            string headT2 = "Input second token amount to ";
            string tail = state == PROVIDE_LIQUIDITY ?  "add to LP: " : "withdraw from LP: ";
            headT1.append(tail);
            headT2.append(tail);
            Terminal.inputUint(tvm.functionId(setToken1Amount), headT1);
            Terminal.inputUint(tvm.functionId(setToken2Amount), headT2);
            Terminal.print(tvm.functionId(validateLPTokenAmount), "Proceeding...");
        }
    }

    // function getInfoAboutUser() public {
    //     optional(uint256) pubkey = 0;
    //     if (state == USER_TOKEN_BALANCE) {
    //         ISwapPairContract(swapPairAddress).getUserBalance{
    //             abiVer: 2,
    //             extMsg: true,
    //             sign: true,
    //             pubkey: pubkey,
    //             time: uint64(now),
    //             expire: 0,
    //             callbackId: tvm.functionId(showUserBalance),
    //             onErrorId: 0
    //         }(0);
    //     } else if (state == USER_LP_TOKEN_BALANCE) {
    //         ISwapPairContract(swapPairAddress).getUserLiquidityPoolBalance{
    //             abiVer: 2,
    //             extMsg: true,
    //             sign: true,
    //             pubkey: pubkey,
    //             time: uint64(now),
    //             expire: 0,
    //             callbackId: tvm.functionId(showUserLPBalance),
    //             onErrorId: 0
    //         }(0);
    //     }
    // }

    function setToken1Amount(uint value) public {
        lpAddWithdraw.token1 = uint128(value);
    }

    function setToken2Amount(uint value) public {
        lpAddWithdraw.token2 = uint128(value);
    }


    function getTokenAmount(uint32 index) public {
        maxTokenAmount = (index == 0) ? token1.balance : token2.balance; 
        chosenToken = (index == 0) ? token1.rootAddress : token2.rootAddress;
        Terminal.inputUint(tvm.functionId(validateTokenAmount), "Input token amount: ");
    }

    function validateTokenAmount(uint value) public {
        if (value > maxTokenAmount) {
            Terminal.print(tvm.functionId(choseNextStep), "Sum is too high. Please, reenter your token choice and token amount.");
        } else {
            tokenAmount = uint128(value);
            if (state == SWAP)
                Terminal.print(tvm.functionId(submitSwap), "Proceeding to token swap submit stage");
            else if (state == WITHDRAW_TOKENS_FROM_PAIR)
                Terminal.print(tvm.functionId(enterWalletAddress), "Proceeding to token withdraw submit stage");
        }
    }

    function validateLPTokenAmount() public {
        if (lpAddWithdraw.token1 > token1.balance || lpAddWithdraw.token2 > token2.balance) {
            Terminal.print(tvm.functionId(choseNextStep), "Sum is too high. Please, reenter your token choice and token amount.");
        } else {
            uint32 fid = (state == PROVIDE_LIQUIDITY) ? tvm.functionId(submitLiquidityProvide) : tvm.functionId(submitLiquidityRemoval);
            string message = (state == PROVIDE_LIQUIDITY) ? "Proceeding to adding liquidity submit stage" : "Proceeding to liquidity removal submit stage";
            Terminal.print(fid, message);
        }
    }

    function submitSwap() public {
        optional(uint) pubkey = 0;
        ISwapPairContract(swapPairAddress).swap{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(showSwapResult),
            onErrorId: 0
        }(chosenToken, tokenAmount);
    }

    function showSwapResult(SwapInfo si) public {
        Terminal.print(tvm.functionId(mainMenu), format("Swapped: {} for {} with {} fee", si.swappableTokenAmount, si.targetTokenAmount, si.fee));
    }

    function submitLiquidityProvide() public {
        optional(uint) pubkey = 0;
        ISwapPairContract(swapPairAddress).provideLiquidity{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(showLPres),
            onErrorId: 0
        }(lpAddWithdraw.token1, lpAddWithdraw.token2);
    }

    function submitLiquidityRemoval() public {
        optional(uint) pubkey = 0;
        ISwapPairContract(swapPairAddress).withdrawLiquidity{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(showLPres),
            onErrorId: 0
        }(lpAddWithdraw.token1, lpAddWithdraw.token2);
    }

    function showLPres(uint128 ftA, uint128 stA) public {
        string head = state == PROVIDE_LIQUIDITY ? "Tokens added to LP:" : "Tokens removed from LP: ";
        Terminal.print(0, head);
        Terminal.print(tvm.functionId(mainMenu), format("{} for first token, {} for second token", ftA, stA));
    }

    function showLiquidityRemovalResult(uint128 ftA, uint128 stA) public {
        Terminal.print(tvm.functionId(mainMenu), format("Tokens removed from LP: {} for first token, {} for second token", ftA, stA));
    }

    function enterWalletAddress() public {
        Terminal.print(0, "Input token wallet address");
        AddressInput.select(tvm.functionId(processPair));
    }

    function submitTokenWithdraw(address value) public {
        optional(uint) pubkey = 0;
        ISwapPairContract(swapPairAddress).withdrawTokens{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(showTokenWithdrawResullt),
            onErrorId: 0
        }(chosenToken, value, tokenAmount);
    }

    // function showUserBalance(UserBalanceInfo ubi) public {
    //     token1.rootAddress = ubi.tokenRoot1;
    //     token1.balance = ubi.tokenBalance1;
    //     token2.rootAddress = ubi.tokenRoot2;
    //     token2.balance = ubi.tokenBalance2;
    //     string head = state == USER_TOKEN_BALANCE ? "Tokens not in liquidity pool: " : "Tokens in liquidity pool: ";

    //     Terminal.print(0, head);
    //     Terminal.print(0, format("{} for {}", token1.balance, token1.rootAddress));
    //     Terminal.print(tvm.functionId(mainMenu), format("{} for {}", token2.balance, token2.rootAddress));
    // }

    // function showUserLPBalance(UserBalanceInfo ubi) public {
    //     token1.rootAddress = ubi.tokenRoot1;
    //     token1.balance = ubi.tokenBalance1;
    //     token2.rootAddress = ubi.tokenRoot2;
    //     token2.balance = ubi.tokenBalance2;
    //     string head = state == USER_TOKEN_BALANCE ? "Tokens not in liquidity pool: " : "Tokens in liquidity pool: ";

    //     Terminal.print(0, head);
    //     Terminal.print(0, format("{} for {}", token1.balance, token1.rootAddress));
    //     Terminal.print(tvm.functionId(mainMenu), format("{} for {}", token2.balance, token2.rootAddress));
    // }

    function showTokenWithdrawResullt() public {
        Terminal.print(tvm.functionId(mainMenu), "Token withdraw successfull");
    }
}