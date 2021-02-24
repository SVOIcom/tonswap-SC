pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../RIP-3/interfaces/IRootTokenContract.sol';
import '../RIP-3/interfaces/IWalletCreationCallback.sol';
import '../RIP-3/interfaces/ITokensReceivedCallback.sol';

contract SwapPairContract is IWalletCreationCallback, ITokensReceivedCallback  {
    address /*static*/ token1;
    address /*static*/ token2;

    address /*static*/ swapPairRootContract;
    uint /*static*/ swapPairID;
    uint /*static*/ swapPairDeployer;

    //Deployed token wallets addresses
    address token1Wallet;
    address token2Wallet;

    //Users balances
    mapping(address => uint128) token1UserBalance;
    mapping(address => uint128) token2UserBalance;
    mapping(address => uint128) rewardUserBalance;

    //Error codes
    uint8 ERROR_CONTRACT_ALREADY_INITIALIZED            = 100;
    uint8 ERROR_CONTRACT_NOT_INITIALIZED                = 101;
    uint8 ERROR_CALLER_IS_NOT_TOKEN_ROOT                = 102;
    uint8 ERROR_CALLER_IS_NOT_TOKEN_WALLET              = 103;

    //Pair creation timestamp
    uint256 creationTimestamp;

    //Initialization status. 0 - new, 1 - one wallet created, 2 - fully initialized
    uint private initializedStatus = 0;



    constructor() public {
        tvm.accept();
        creationTimestamp = now;

        //Deploy tokens wallets
        _deployWallets();
    }

    /**
    * Deploy internal wallets. getWalletAddressCallback
    */
    function _deployWallets() private {
        IRootTokenContract(token1).deployEmptyWallet{}(200000000, tvm.pubkey(), address(this), address(this));
        IRootTokenContract(token2).deployEmptyWallet{}(200000000, tvm.pubkey(), address(this), address(this));
    }

    /**
    * Get pair creation timestamp
    */
    function getCreationTimestamp() public view returns (uint256 creationTimestamp) {
        return creationTimestamp;
    }

    function _getRates() private{

    }

    function _swap() private {

    }

    //============Modifiers============
    modifier initialized() {
        require(initializedStatus == 2, ERROR_CONTRACT_NOT_INITIALIZED);
        _;
    }

    modifier onlyTokenRoot() {
        require(msg.sender.value == token1.sender || msg.sender.value == token2.sender, ERROR_CALLER_IS_NOT_TOKEN_ROOT);
        _;
    }

    modifier onlyOwnWallet() {
        require(msg.sender.value == token1Wallet.sender || msg.sender.value == token2Wallet.sender, ERROR_CALLER_IS_NOT_TOKEN_WALLET);
        _;
    }

    //============Callbacks============

    /*
    * Deployed wallet address callback
    */
    function getWalletAddressCallback(address walletAddress) public{
        //Check for initialization
        require(initializedStatus < 2, ERROR_CONTRACT_ALREADY_INITIALIZED);

        if(msg.sender.value == token1.value){
            token1Wallet = walletAddress;
            initializedStatus++;
        }

        if(msg.sender.value == token2.value){
            token2Wallet = walletAddress;
            initializedStatus++;
        }
    }

    /*
    * Tokens received from user
    */
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
    ) public onlyOwnWallet {

        

    }

}