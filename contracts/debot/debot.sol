pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "./interfaces/Debot.sol";
import "./interfaces/Terminal.sol";
import "./interfaces/AddressInput.sol";
import "./interfaces/Sdk.sol";
import "./interfaces/Menu.sol";
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
    // For user usage
    uint static _randomNonce;
    
    address swapPairAddress;
    TokenInfo token1; TokenInfo token2;
    address token1; address token2;
    string token1Symbol = "A"; string token2Symbol = "B";
    uint128 token1Balance = 100; uint128 token2Balance = 200;
    uint128 maxTokenAmount;
    uint8 state;

    uint8 SWAP = 0;
    uint8 GET_TOKENS = 1;

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

    function getVersion() public override returns(string name, uint24 semver) {name = "SwapDeBot"; semver = 1; }
    function quit() public override {}

    function actionChoice(uint32 index) public { 
        state = uint8(index);
        Terminal.print(0, "Please input swap pair address");
        AddressInput.select(tvm.functionId(processPair));
    }

    function processPair(address value) public {  
        swapPairAddress = value;
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
        optional(uint256) pubkey;
        TvmCell cell = tvm.buildExtMsg({
            abiVer: 2,
            callbackId: tvm.functionId(setTokenInfo),
            onErrorId: 0,
            time: uint64(now),
            expire:  uint64(now) + 100,
            pubkey: pubkey,
            dest: value,
            call: {
                ISwapPairContract.getUserTokens
            },
        });
        // ISwapPairContract(swapPairAddress).getPairInfo{
        //     extMsg: true,
        //     time: uint64(now),
        //     sign: false,
        //     pubkey: pubkey,
        //     callbackId: tvm.functionId(setTokenInfo)
        // }();
        // ISwapPairContract(swapPairAddress).getUserTokens{
        //     extMsg: true,
        //     time: uint64(now),
        //     sign: false,
        //     pubkey: pubkey,
        //     callbackId: tvm.functionId(setUserTokenBalance)
        // }();
    }

    function getTokenInfo() public {

    }

    function chooseToken() public {
        Menu.select("", "Select active token (for swap - token you want to swap): ", [
            MenuItem(token1.symbol, "", tvm.functionId(getTokenAmount)),
            MenuItem(token2.symbol, "", tvm.functionId(getTokenAmount))
        ]);
    }

    function getTokenAmount(uint32 index) public {
        maxTokenAmount = (index == 0) ? token1.balance : token2.balance; 
        Terminal.inputUint(tvm.functionId(validateTokenAmount), "Input token amount: ");
    }

    function validateTokenAmount(uint value) public {
        if (value > maxTokenAmount) {
            Terminal.print(tvm.functionId(chooseToken), "Sum is too high. Please, reenter your token choice and token amount.");
        } else {
            uint32 fid = (state == SWAP) ? tvm.functionId(submitSwap) : tvm.functionId(submitTokenWithdraw);
            string message = (state == SWAP) ? "Proceeding to token swap submit stage" : "Proceeding to token removal submit stage";
            Terminal.print(fid, message);
        }
    }

    function submitSwap() public {
        TvmCell cell = tvm.buildExtMsg({
            abiVer: 2,
            callbackId: tvm.functionId(setTokenInfo),
            onErrorId: 0,
            time: uint64(now),
            expire:  uint64(now) + 100,
            pubkey: pubkey,
            dest: swapPairAddress,
            call: {
                ISwapPairContract.Swap,

            },
        });
        Terminal.print(0, "Swap completed");
    }

    function submitTokenWithdraw() public {
        Terminal.print(0, "Token withdraw completed");
    }

    function setUserTokenBalance(TokensBalance tokensBalance) public {

    }

    function getInfoAboutTokens(IRootTokenContractDetails rootInfo) {
        if (msg.sender == token1.root) {
            token1.symbol = rootInfo.symbol;
        } else {
            token2.symbol = rootInfo.symbol;
        }
    }

    function setTokenInfo(PairInfo pairInfo) public {
        token1.rootAddress = pairInfo.token1;
        token2.rootAddress = pairInfo.token2;
        sendRootMsg(token1.rootAddress);
        sendRootMsg(token2.rootAddress);
        
        //Terminal.print(tvm.functionId(chooseToken), format("Your balance: {} for {}; {} for {}", token1.balance, token1.symbol, token2.balance, token2.symbol));
    }

    function sendRootMsg(address root) private inline view {
        TvmCell cell = tvm.buildExtMsg({
            abiVer: 2,
            callbackId: tvm.functionId(getInfoAboutTokens),
            onErrorId: 0,
            time: uint64(now),
            expire:  uint64(now) + 100,
            pubkey: pubkey,
            dest: swapPairAddress,
            call: {
                IRootTokenContract.getDetails,
            },
        });
        tvm.sendrawmsg(cell, 1);
    }
}
