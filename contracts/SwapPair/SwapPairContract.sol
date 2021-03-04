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
    address static token1;  // TODO Хз, можно ли делать статический маппинг, поэтому оставил так
    address static token2;
    uint    static swapPairID;


    uint swapPairDeployer;
    address swapPairRootContract;

    mapping(uint8 => address) tokens;
    mapping(address => uint8) tokensPositions;

    //Deployed token wallets addresses
    mapping(uint8 => address) tokensWallets

    //Users balances
    mapping( uint8 => mapping(address => uint128) ) tokenUserBalances;
    mapping(uint8 => mapping(address => uint128)) liquidityUserBalances
    mapping(address => uint128) rewardUserBalance;

    //Liquidity Pools
    mapping(uint8 => uint128) private lps;
    uint public kLast; // reserve1 * reserve2 after most recent swap


    //Pair creation timestamp
    uint256 creationTimestamp;

    //Initialization status. 0 - new, 1 - one wallet created, 2 - fully initialized
    uint private initializedStatus = 0;

    // Initial balance managing
    uint constant walletInitialBalanceAmount = 200 milli;
    uint constant walletDeployMessageValue   = 400 milli;

    // Tokens positions
    uint8 constant T1 = 0;
    uint8 constant T2 = 1;

    //Error codes
    uint8 constant ERROR_CONTRACT_ALREADY_INITIALIZED = 100;     string constant ERROR_CONTRACT_ALREADY_INITIALIZED_MSG = "Error: contract is already initialized";
    uint8 constant ERROR_CONTRACT_NOT_INITIALIZED     = 101;     string constant ERROR_CONTRACT_NOT_INITIALIZED_MSG     = "Error: contract is not initialized";
    uint8 constant ERROR_CALLER_IS_NOT_TOKEN_ROOT     = 102;     string constant ERROR_CALLER_IS_NOT_TOKEN_ROOT_MSG     = "Error: msg.sender is not token root";
    uint8 constant ERROR_CALLER_IS_NOT_TOKEN_WALLET   = 103;     string constant ERROR_CALLER_IS_NOT_TOKEN_WALLET_MSG   = "Error: msg.sender is not token wallet";
    uint8 constant ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT = 104;     string constant ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT_MSG = "Error: msg.sender is not swap pair root contract";
    uint8 constant ERROR_NO_LIQUIDITY_PROVIDED        = 105;     string constant ERROR_NO_LIQUIDITY_PROVIDED_MSG        = "Error: no liquidity provided";
 
    uint8 constant ERROR_INVALID_TOKEN_ADDRESS        = 106;     string constant ERROR_INVALID_TOKEN_ADDRESS_MSG        = "Error: invalid token address";

    uint8 constant ERROR_INSUFFICIENT_USER_BALANCE    = 111;     string constant ERROR_INSUFFICIENT_USER_BALANCE_MSG    = "Error: insufficient user balance";
    uint8 constant ERROR_INSUFFICIENT_USER_LP_BALANCE = 112;     string constant ERROR_INSUFFICIENT_USER_LP_BALANCE_MSG = "Error: insufficient user liquidity pool balance";
    uint8 constant ERROR_UNKNOWN_USER_PUBKEY          = 113;     string constant ERROR_UNKNOWN_USER_PUBKEY_MSG          = "Error: unknown user's pubkey"



    constructor(address rootContract, uint spd) public {
        tvm.accept();
        creationTimestamp = now;
        swapPairRootContract = rootContract;
        swapPairDeployer = spd;

        //Deploy tokens wallets
        _deployWallets();

        tokens[T1] = token1;
        tokens[T2] = token2;
        tokensPositions[token1] = T1;
        tokensPositions[token2] = T2;

        lps[T1] = 0;
        lps[T2] = 0;
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

    function _getRates(address swappableTokenRoot, uint128 swappableTokenAmount) private returns (uint256 rates) {
        //Some fancy math here
    }


    //============Upgrade swap pair code part============
    // TODO: Переделать на маппинги, просто не хочется что-то сломать
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
            msg.sender == token1 || msg.sender == token2,
            ERROR_CALLER_IS_NOT_TOKEN_ROOT,
            ERROR_CALLER_IS_NOT_TOKEN_ROOT_MSG
        );
        _;
    }

    modifier onlyOwnWallet() {
        bool b1 = tokensWallets.exist(T1) && msg.sender == tokensWallets[T1];
        bool b2 = tokensWallets.exist(T2) && msg.sender == tokensWallets[T2];
        require(
            b1 || b2,
            ERROR_CALLER_IS_NOT_TOKEN_WALLET,
            ERROR_CALLER_IS_NOT_TOKEN_WALLET_MSG
        );
        _;
    }

    modifier onlySwapPairRoot() {
        require(
            msg.sender == swapPairRootContract,
            ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT,
            ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT_MSG
        );
        _;
    }

    modifier liquidityProvided() {
        require(
            lps[T1] > 0 && lps[T2] > 0 && kLast > 0,
            ERROR_NO_LIQUIDITY_PROVIDED,
            ERROR_NO_LIQUIDITY_PROVIDED_MSG
        );
        _;
    }

    
    modifier tokenExistsInPair(address _token) {
        require(
            tokensPositions.exist(_token),
            ERROR_INVALID_TOKEN_ADDRESS,
            ERROR_INVALID_TOKEN_ADDRESS_MSG
        );
        _;
    }


    modifier userEnoughBalance(address _token, uint128 amount) {
        uint8 _p = _getTokenPosition(_token);
        optional(uint128) userBalanceOptional = tokenUserBalances[_p].fetch(msg.pubkey());

        // TODO: хз, стоит ли тут кидать эксепшн.  
        // Потому что если юзер не закидывал токены на баланс, то у него просто пустой баланс. 
        // И в сущности нет разницы, взаимодействовал ли он когда-нибудь с этим контрактом
        require(
            userBalanceOptional.hasValue(), 
            ERROR_UNKNOWN_USER_PUBKEY,
            ERROR_UNKNOWN_USER_PUBKEY_MSG
        );
        
        uint128 userBalance = userBalanceOptional.get();
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
    // TODO: если 2 раза инициализировать один и тот же кошелёк, новый адрес затрёт предыдущий. 
    // Более того в этот момент, счётчик станет равен 2. Эту хрень поправил, предыдущее оставил как фичу.
    function getWalletAddressCallback(address walletAddress) public {
        //Check for initialization
        require(initializedStatus < 2, ERROR_CONTRACT_ALREADY_INITIALIZED);

        if (msg.sender == token1) {
            if( !tokensWallets.exist(T1) )
                initializedStatus++;
            tokensWallets[T1] = walletAddress;
        }

        if (msg.sender == token2) {
            if( !tokensWallets.exist(T2) )
                initializedStatus++;
            tokensWallets[T2] = walletAddress;
        }

        if (initializedStatus == 2) {
            _setWalletsCallbackAddress();
        }
    }

    /*
     * Set callback address for wallets
     */
    // TODO: я туповат, тут модификатор `public` правильно стоит?
    function _setWalletsCallbackAddress() 
        public 
        inline 
        initialized // TODO: на всякий добавил, если что-то ломает, поправьте
    {
        ITONTokenWalletWithNotifiableTransfers(tokensWallets[T1]).setReceiveCallback{
            value: 200 milliton
        }(address(this));
        ITONTokenWalletWithNotifiableTransfers(tokensWallets[T2]).setReceiveCallback{
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
        TvmCell payload) 
    public 
    onlyOwnWallet 
    {   
        const _p = tokensWallets[T1] == msg.sender ? T1 : T2; // onlyWallets eliminates other validational
        if (tokenUserBalances[_p].exists(sender_public_key)) {
            tokenUserBalances[_p].replace(
                sender_public_key,
                tokenUserBalances[_p].at(sender_public_key) + amount
            );
        } else {
            tokenUserBalances[_p].add(sender_public_key, amount);
        }
    }


    //============Functions============
    function getPairInfo() override external view returns (SwapPairInfo info) {
        return SwapPairInfo(
            swapPairRootContract,
            token1,
            token2,
            tokensWallets[T1],
            tokensWallets[T2],
            swapPairDeployer,
            creationTimestamp,
            address(this),
            swapPairID
        );
    }

    // TODO Мб стоит добавить модификатор `initialized`
    function getUserBalance() override external view returns (UserBalanceInfo ubi) {
        uint256 pubkey = msg.pubkey();
        return UserBalanceInfo(
            token1,
            token2,
            tokenUserBalances[T1][pubkey],   // Хз, что будет тут, если не будет инициализирован контракт
            tokenUserBalances[T2][pubkey]
        );
    }


    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount)
        override
        external
        view
        returns (uint256 rate)
    {
        return _getRates(swappableTokenRoot, swappableTokenAmount);
    }


    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) override external initialized {

    }


    function provideLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) 
        override 
        external 
        initialized 
        userEnoughBalance(token1, firstTokenAmount)
        userEnoughBalance(token2, secondTokenAmount)
    {
        uint256 pubkey = msg.pubkey();

        //TODO проверки коэф

        require(
            tokenUserBalances[T1][pubkey] >= firstTokenAmount && tokenUserBalances[T2][pubkey] >= secondTokenAmount,
            ERROR_INSUFFICIENT_USER_BALANCE,
            ERROR_INSUFFICIENT_USER_BALANCE_MSG
        );

        tokenUserBalances[T1][pubkey]-= firstTokenAmount;
        tokenUserBalances[T2][pubkey]-= secondTokenAmount;

        liquidityUserBalances[T1][pubkey] += firstTokenAmount;
        liquidityUserBalances[T2][pubkey] += secondTokenAmount;

        lps[T1] += firstTokenAmount;
        lps[T2] += secondTokenAmount;
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
    
    function _getTokenPosition(address _token) 
        private
        initialized
        tokenExistsInPair(_token)
        returns(uint8)
    {
        return tokensPositions.at(_token);
    }


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