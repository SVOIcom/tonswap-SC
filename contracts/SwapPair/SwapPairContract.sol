pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../RIP-3/interfaces/IRootTokenContract.sol';
import '../RIP-3/interfaces/IWalletCreationCallback.sol';
import '../RIP-3/interfaces/ITokensReceivedCallback.sol';
import './interfaces/ISwapPairContract.sol';
import './interfaces/ISwapPairInformation.sol';
import './interfaces/IUpgradeSwapPairCode.sol';

contract SwapPairContract is ISwapPairContract, ISwapPairInformation, IUpgradeSwapPairCode, IWalletCreationCallback, ITokensReceivedCallback {
    address /*static*/ token1;
    address /*static*/ token2;

    address swapPairRootContract;

    uint /*static*/ swapPairID;
    uint swapPairDeployer;

    //Deployed token wallets addresses
    address token1Wallet;
    address token2Wallet;

    // Initial balance managing
    uint constant walletInitialBalanceAmount = 200 milli;
    uint constant walletDeployMessageValue   = 400 milli;

    //Liquidity Pools
    uint128 private lp1;
    uint128 private lp2;

    uint public kLast; // reserve1 * reserve2 after most recent swap

    //Users balances
    mapping(address => uint128) token1UserBalance;
    mapping(address => uint128) token2UserBalance;
    mapping(address => uint128) rewardUserBalance;

    mapping(address => uint128) token1LiquidityUserBalance;
    mapping(address => uint128) token2LiquidityUserBalance;


    //Error codes
    uint8 ERROR_CONTRACT_ALREADY_INITIALIZED = 100;     string ERROR_CONTRACT_ALREADY_INITIALIZED_MSG = "Error: contract is already initialized";
    uint8 ERROR_CONTRACT_NOT_INITIALIZED     = 101;     string ERROR_CONTRACT_NOT_INITIALIZED_MSG     = "Error: contract is not initialized"; 
    uint8 ERROR_CALLER_IS_NOT_TOKEN_ROOT     = 102;     string ERROR_CALLER_IS_NOT_TOKEN_ROOT_MSG     = "Error: msg.sender is not token root";
    uint8 ERROR_CALLER_IS_NOT_TOKEN_WALLET   = 103;     string ERROR_CALLER_IS_NOT_TOKEN_WALLET_MSG   = "Error: msg.sender is not token wallet";
    uint8 ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT = 104;     string ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT_MSG = "Error: msg.sender is not swap pair root contract";
    uint8 ERROR_NO_LIQUIDITY_PROVIDED        = 105;     string ERROR_NO_LIQUIDITY_PROVIDED_MSG        = "Error: no liquidity provided";

    uint8 ERROR_INVALID_TOKEN_ADDRESS        = 106;     string ERROR_INVALID_TOKEN_ADDRESS_MSG        = "Error: invalid token address";
    
    uint8 ERROR_INSUFFICIENT_USER_BALANCE    = 111;     string ERROR_INSUFFICIENT_USER_BALANCE_MSG    = "Error: insufficient user balance";
    uint8 ERROR_INSUFFICIENT_USER_LP_BALANCE = 112;     string ERROR_INSUFFICIENT_USER_LP_BALANCE_MSG = "Error: insufficient user liquidity pool balance";

    //Pair creation timestamp
    uint256 creationTimestamp;

    //Initialization status. 0 - new, 1 - one wallet created, 2 - fully initialized
    uint private initializedStatus = 0;



    constructor(address rootContract, uint spd) public {
        tvm.accept();
        creationTimestamp = now;
        swapPairRootContract = rootContract;
        swapPairDeployer = spd;

        //Deploy tokens wallets
        _deployWallets();

        lp1 = 0;
        lp2 = 0;
        kLast = 0;
    }

    /**
    * Deploy internal wallets. getWalletAddressCallback to get their addresses
    */
    function _deployWallets() private {
        IRootTokenContract(token1).deployEmptyWallet{
            value: walletDeployMessageValue
        }(
            walletInitialBalanceAmount milliton, 
            tvm.pubkey(),
            address(this), 
            address(this)
        );

        IRootTokenContract(token2).deployEmptyWallet{
            value: walletDeployMessageValue
        }(
            walletInitialBalanceAmount milliton, 
            tvm.pubkey(), 
            address(this), 
            address(this)
        );
    }

    /**
    * Get pair creation timestamp
    */
    function getCreationTimestamp() public view returns (uint256 creationTimestamp) {
        return creationTimestamp;
    }

    function _getRates() private {

    }


    //============Upgrade swap pair code part============

    function updateSwapPairCode(TvmCell newCode, uint32 newCodeVersion) override external onlySwapPairRoot {
        tvm.accept();

        tvm.setcode(code);
        tvm.setCurrentCode(code);
        _initializeAfterCodeUpdate(
            token1UserBalance,
            token2UserBalance,
            rewardUserBalance,
            token1LiquidityUserBalance,
            token2LiquidityUserBalance,
            token1Wallet,
            token2Wallet,
            swapPairRootContract,
            swapPairDeployer
        )
    }

    function _initializeAfterCodeUpdate(
        mapping(address => uint128) token1UB, // user balance for token1
        mapping(address => uint128) token2UB, // user balance for token2
        mapping(address => uint128) rewardUB, // rewards user balance
        mapping(address => uint128) token1LPUB, // user balance at LP for token1
        mapping(address => uint128) token2LPUB, // user balance at LP for token2 
        address token1W,  // token1 wallet address
        address token2W,  // token2 wallet address
        address spRootContract,  // address of swap pair root contract
        uint    spDeployer // pubkey of swap pair deployer
    ) inline private {

    }
 

    //============Modifiers============

    modifier initialized() {
        require(initializedStatus == 2, ERROR_CONTRACT_NOT_INITIALIZED, ERROR_CONTRACT_NOT_INITIALIZED_MSG);
        _;
    }

    modifier onlyTokenRoot() {
        require(
            msg.sender.value == token1.sender || msg.sender.value == token2.sender, 
            ERROR_CALLER_IS_NOT_TOKEN_ROOT, 
            ERROR_CALLER_IS_NOT_TOKEN_ROOT_MSG
        );
        _;
    }

    modifier onlyOwnWallet() {
        require(
            msg.sender.value == token1Wallet.sender || msg.sender.value == token2Wallet.sender, 
            ERROR_CALLER_IS_NOT_TOKEN_WALLET, 
            ERROR_CALLER_IS_NOT_TOKEN_WALLET_MSG
        );
        _;
    }

    modifier onlySwapPairRoot() {
        require(
            msg.sender.value == swapPairRootContract, 
            ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT,
            ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT_MSG
        );
        _;
    }

    modifier liquidityProvided() {
        require(
            lp1 > 0 && lp2 > 0 && kLast > 0,
            ERROR_NO_LIQUIDITY_PROVIDED,
            ERROR_NO_LIQUIDITY_PROVIDED_MSG
        );
        _;
    }
    
    // TODO Модификатор с модификатором??????
    modifier rightTokenAddress(address _token) initialized {
        require(
            _token == token1 || _token == token2,
            ERROR_INVALID_TOKEN_ADDRESS,
            ERROR_INVALID_TOKEN_ADDRESS_MSG
        );
        _;
    }

    modifier userEnoughBalance(address _token, uint128 amount) {
        mapping(address => uint128) m = _getWalletsMapping(_token);
        uint128 userBalance = m[msg.pubkey()];
        require(
            userBalance > 0 && userBalance > amount,
            ERROR_INSUFFICIENT_USER_BALANCE,
            ERROR_INSUFFICIENT_USER_BALANCE_MSG
        );
        _;
    }


    //============Callbacks============

    /*
    * Deployed wallet address callback
    */
    function getWalletAddressCallback(address walletAddress) public {
        //Check for initialization
        require(initializedStatus < 2, ERROR_CONTRACT_ALREADY_INITIALIZED);

        if (msg.sender.value == token1.value) {
            token1Wallet = walletAddress;
            initializedStatus++;
        }

        if (msg.sender.value == token2.value) {
            token2Wallet = walletAddress;
            initializedStatus++;
        }

        if (initializedStatus == 2) {
            _setWalletsCallbackAddress();
        }
    }

    /*
     * Set callback address for wallets
     */
    function _setWalletsCallbackAddress() public inline {
        ITONTokenWalletWithNotifiableTransfers(token1Wallet).setReceiveCallback{
            value: 200 milliton
        }(address(this));
        ITONTokenWalletWithNotifiableTransfers(token2Wallet).setReceiveCallback{
            value: 200 milliton
        }(address(this));
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

        if (msg.sender.value == token1Wallet.sender) {
            token1UserBalance[sender_address] += amount;
        }

        if (msg.sender.value == token2Wallet.sender) {
            token2UserBalance[sender_address] += amount;
        }

    }


    //============Functions============

        function getPairInfo() override external view returns (SwapPairInfo info) {
        return SwapPairInfo(
            swapPairRootContract,
            token1,
            token2,
            token1Wallet,
            token2Wallet,
            swapPairDeployer,
            creationTimestamp,
            address(this),
            swapPairID
        );
    }

    function getUserBalance() override external view returns (UserBalanceInfo ubi) {
        uint256 pubkey = msg.pubkey();
        return UserBalanceInfo(
            token1,
            token2,
            token1UserBalance[pubkey],
            token2UserBalance[pubkey]
        );
    }

    
    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) 
        override
        external 
        view 
        returns (uint256 rate)
    {

    }


    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) override external initialized {

    }


    function provideLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) override external initialized {

    }

    function withdrawLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) 
        override
        external 
        initialized 
        liquidityProvided 
    {

    }

    
    function swap(address swappableTokenRoot,  uint128 swappableTokenAmount) 
        override 
        external 
        initialized 
        liquidityProvided
        userEnoughBalance(swappableTokenRoot, swappableTokenAmount)
    {   
        // TODO doesn't done
        // Тот факт, что в одном месте мы юзаем названия типа `token1`, а в другом аддресса - это пиздец. 
        // Оно нам так надо? Мб создать маппинг на 2 места и положить в них структуры с нужной инфой?
        // Иначе надо под всё писать функции, которые будут искать нужноре тебе поле {token, lp, tokenWallet, tokenUserBalance, LPBalance}{1,2}
        // а это такое себе

    }


    //============HELPERS============
    
    function _getWalletsMapping(address _token) 
        private 
        rightTokenAddress(_token)
        returns (mapping(address => uint128)) 
    {
        if (_token == token1)
            return token1UserBalance;

        if (_token == token2)
            return token2UserBalance;
    }

    // function _get


    //============DEBUG============

    function _getLiquidityPoolTokens() override external view returns (_DebugLPInfo dlpi) {

    }

    function _getUserLiquidityPoolTokens() override external view returns (_DebugLPInfo dlpi) {

    }

    function _getExchangeRateSimulation(
        uint256 token1, 
        uint256 token2, 
        uint256 swapToken1, 
        uint256 swapToken2
    ) override external view returns (_DebugERInfo deri) {

    }
}