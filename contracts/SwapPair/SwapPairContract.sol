pragma ton-solidity ^ 0.36.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../RIP-3/interfaces/IRootTokenContract.sol';
import '../RIP-3/interfaces/IWalletCreationCallback.sol';
import '../RIP-3/interfaces/ITokensReceivedCallback.sol';
import '../RIP-3/interfaces/ITONTokenWalletWithNotifiableTransfers.sol';
import './interfaces/ISwapPairContract.sol';
import './interfaces/ISwapPairInformation.sol';
import './interfaces/IUpgradeSwapPairCode.sol';

contract SwapPairContract is ITokensReceivedCallback, ISwapPairInformation, IUpgradeSwapPairCode, IWalletCreationCallback, ISwapPairContract {
    address static token1;
    address static token2;
    uint    static swapPairID;

    uint32 swapPairCodeVersion = 1;
    uint swapPairDeployer;
    address swapPairRootContract;

    uint128 constant feeNominator = 997;
    uint128 constant feeDenominator = 1000;

    mapping(uint8 => address) tokens;
    mapping(address => uint8) tokensPositions;

    //Deployed token wallets addresses
    mapping(uint8 => address) tokensWallets;

    //Users balances
    mapping(uint8 => mapping(uint256 => uint128)) tokenUserBalances;
    mapping(uint8 => mapping(uint256 => uint128)) liquidityUserBalances;
    mapping(uint256 => uint128) rewardUserBalance;

    //Liquidity Pools
    mapping(uint8 => uint128) private lps;
    uint256 public kLast; // reserve1 * reserve2 after most recent swap


    //Pair creation timestamp
    uint256 creationTimestamp;

    //Initialization status. 0 - new, 1 - one wallet created, 2 - fully initialized
    uint private initializedStatus = 0;

    // Initial balance managing
    uint128 constant walletInitialBalanceAmount = 200 milli;
    uint128 constant walletDeployMessageValue   = 400 milli;

    // Tokens positions
    uint8 constant T1 = 0;
    uint8 constant T2 = 1;

    //Error codes    
    uint8 constant ERROR_CONTRACT_ALREADY_INITIALIZED  = 100; string constant ERROR_CONTRACT_ALREADY_INITIALIZED_MSG  = "Error: contract is already initialized";
    uint8 constant ERROR_CONTRACT_NOT_INITIALIZED      = 101; string constant ERROR_CONTRACT_NOT_INITIALIZED_MSG      = "Error: contract is not initialized";
    uint8 constant ERROR_CALLER_IS_NOT_TOKEN_ROOT      = 102; string constant ERROR_CALLER_IS_NOT_TOKEN_ROOT_MSG      = "Error: msg.sender is not token root";
    uint8 constant ERROR_CALLER_IS_NOT_TOKEN_WALLET    = 103; string constant ERROR_CALLER_IS_NOT_TOKEN_WALLET_MSG    = "Error: msg.sender is not token wallet";
    uint8 constant ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT  = 104; string constant ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT_MSG  = "Error: msg.sender is not swap pair root contract";
    uint8 constant ERROR_NO_LIQUIDITY_PROVIDED         = 105; string constant ERROR_NO_LIQUIDITY_PROVIDED_MSG         = "Error: no liquidity provided";
     
    uint8 constant ERROR_INVALID_TOKEN_ADDRESS         = 106; string constant ERROR_INVALID_TOKEN_ADDRESS_MSG         = "Error: invalid token address";
    uint8 constant ERROR_INVALID_TOKEN_AMOUNT          = 107; string constant ERROR_INVALID_TOKEN_AMOUNT_MSG          = "Error: invalid token amount";
    
    uint8 constant ERROR_INSUFFICIENT_USER_BALANCE     = 111; string constant ERROR_INSUFFICIENT_USER_BALANCE_MSG     = "Error: insufficient user balance";
    uint8 constant ERROR_INSUFFICIENT_USER_LP_BALANCE  = 112; string constant ERROR_INSUFFICIENT_USER_LP_BALANCE_MSG  = "Error: insufficient user liquidity pool balance";
    uint8 constant ERROR_UNKNOWN_USER_PUBKEY           = 113; string constant ERROR_UNKNOWN_USER_PUBKEY_MSG           = "Error: unknown user's pubkey";
    
    uint8 constant ERROR_LIQUIDITY_PROVIDING_RATE      = 115; string constant ERROR_LIQUIDITY_PROVIDING_RATE_MSG      = "Error: added liquidity disrupts the rate";
    uint8 constant ERROR_INSUFFICIENT_LIQUIDITY_AMOUNT = 116; string constant ERROR_INSUFFICIENT_LIQUIDITY_AMOUNT_MSG = "Error: zero liquidity tokens provided";



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
            walletInitialBalanceAmount,
            tvm.pubkey(),
            address(this),
            address(this)
        );

        IRootTokenContract(token2).deployEmptyWallet{
            value: walletDeployMessageValue
        }(
            walletInitialBalanceAmount,
            tvm.pubkey(),
            address(this),
            address(this)
        );
    }

    /**
    * Get pair creation timestamp
    */
    function getCreationTimestamp() override public view returns (uint256) {
        return creationTimestamp;
    }

    function _getRates(address swappableTokenRoot, uint128 swappableTokenAmount) private returns (uint256 rates) {
        //Some fancy math here
    }


    //============Upgrade swap pair code part============
    function updateSwapPairCode(TvmCell newCode, uint32 newCodeVersion) override external onlySwapPairRoot {
        tvm.accept();

        tvm.setcode(newCode);
        tvm.setCurrentCode(newCode);
        _initializeAfterCodeUpdate(
            tokens,
            tokensPositions,
            tokensWallets,
            tokenUserBalances,
            liquidityUserBalances,
            rewardUserBalance,
            swapPairRootContract,
            swapPairDeployer
        );
    }

    function _initializeAfterCodeUpdate(
        mapping(uint8 => address) tokens_,
        mapping(address => uint8) tokensPositions_,
        mapping(uint8 => address) tokensWallets_,
        mapping(uint8 => mapping(uint256 => uint128)) tokenUserBalances_,
        mapping(uint8 => mapping(uint256 => uint128)) liquidityUserBalances_,
        mapping(uint256 => uint128) rewardUserBalance_,  
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
        bool b1 = tokensWallets.exists(T1) && msg.sender == tokensWallets[T1];
        bool b2 = tokensWallets.exists(T2) && msg.sender == tokensWallets[T2];
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
            checkIsLiquidityProvided(),
            ERROR_NO_LIQUIDITY_PROVIDED,
            ERROR_NO_LIQUIDITY_PROVIDED_MSG
        );
        _;
    }

    
    modifier tokenExistsInPair(address _token) {
        require(
            tokensPositions.exists(_token),
            ERROR_INVALID_TOKEN_ADDRESS,
            ERROR_INVALID_TOKEN_ADDRESS_MSG
        );
        _;
    }

    modifier notEmptyAmount(uint128 _amount) {
        require (_amount > 0,  ERROR_INVALID_TOKEN_AMOUNT, ERROR_INVALID_TOKEN_AMOUNT_MSG);
        _;
    }

    modifier notZeroLiquidity(uint128 _amount1, uint128 _amount2) {
        require(
            _amount1 > 0 || _amount2 > 0,
            ERROR_INSUFFICIENT_LIQUIDITY_AMOUNT,
            ERROR_INSUFFICIENT_LIQUIDITY_AMOUNT_MSG
        );
        _;
    }

    modifier userEnoughTokenBalance(address _token, uint128 amount) {
        uint8 _p = _getTokenPosition(_token);        
        uint128 userBalance = tokenUserBalances[_p][msg.pubkey()];
        require(
            userBalance > 0 && userBalance >= amount,
            ERROR_INSUFFICIENT_USER_BALANCE,
            ERROR_INSUFFICIENT_USER_BALANCE_MSG
        );
        _;
    }

    modifier checkUserTokens(address token1_, uint128 token1Amount, address token2_, uint128 token2Amount) {
        bool b1 = tokenUserBalances[tokensPositions[token1_]][msg.pubkey()] >= token1Amount;
        bool b2 = tokenUserBalances[tokensPositions[token2_]][msg.pubkey()] >= token2Amount;
        require(
            b1 && b2,
            ERROR_INSUFFICIENT_USER_BALANCE,
            ERROR_INSUFFICIENT_USER_BALANCE_MSG
        );
        _;
    }


    //============Callbacks============

    /*
    * Deployed wallet address callback
    */
    function getWalletAddressCallback(address walletAddress) override public {
        //Check for initialization
        require(initializedStatus < 2, ERROR_CONTRACT_ALREADY_INITIALIZED);

        if (msg.sender == token1) {
            if( !tokensWallets.exists(T1) )
                initializedStatus++;
            tokensWallets[T1] = walletAddress;
        }

        if (msg.sender == token2) {
            if( !tokensWallets.exists(T2) )
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
    function _setWalletsCallbackAddress() 
        private 
        inline 
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
        TvmCell payload
    ) 
        override
        public
        onlyOwnWallet
    {   
        uint8 _p = tokensWallets[T1] == msg.sender ? T1 : T2; // `onlyWallets` eliminates other validational
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
            swapPairID,
            swapPairCodeVersion
        );
    }


    function getUserBalance() 
        override   
        external 
        view 
        initialized
        returns (UserBalanceInfo ubi) 
    {
        uint256 pubkey = msg.pubkey();
        return UserBalanceInfo(
            token1,
            token2,
            tokenUserBalances[T1][pubkey],
            tokenUserBalances[T2][pubkey]
        );
    }


    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount)
        override
        external
        returns (uint256 rate)
    {
        return _getRates(swappableTokenRoot, swappableTokenAmount);
    }


    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) override external initialized {

    }

    // TODO можно добавить минималку для стартовой инициализации. Чтобы обеспечить минимальный размер пулов на старте
    // либо изменить проверку `checkIsLiquidityProvided` таким образом, чтобы минималка была не 0, а нормальная
    // Лучший варик - какое-то минимальное значение lp1 * lp2.
    function provideLiquidity(uint128 maxFirstTokenAmount, uint128 maxSecondTokenAmount) 
        override 
        external 
        initialized 
        notZeroLiquidity(maxFirstTokenAmount, maxSecondTokenAmount)
        checkUserTokens(token1, maxFirstTokenAmount, token2, maxSecondTokenAmount)
        returns (uint128 providedFirstTokenAmount, uint128 providedSecondTokenAmount)
    {
        uint256 pubkey = msg.pubkey();
        uint128 provided1 = 0;
        uint128 provided2 = 0;

        if ( !checkIsLiquidityProvided() ) {
            provided1 = maxFirstTokenAmount;
            provided2 = maxSecondTokenAmount;
        }
        else {
            uint128 maxToProvide1 = maxSecondTokenAmount != 0 ? (maxSecondTokenAmount * lps[T1] / lps[T2]) : 0;
            uint128 maxToProvide2 = maxFirstTokenAmount  != 0 ? (maxFirstTokenAmount * lps[T2] / lps[T1])  : 0;
            if (maxToProvide1 <= maxFirstTokenAmount ) {
                provided1 = maxToProvide1;
                provided2 = maxSecondTokenAmount;
            } else {
                provided1 = maxFirstTokenAmount;
                provided2 = maxToProvide2;
            }
        }

        tokenUserBalances[T1][pubkey]-= provided1;
        tokenUserBalances[T2][pubkey]-= provided2;        

        liquidityUserBalances[T1][pubkey] += provided1;
        liquidityUserBalances[T2][pubkey] += provided2;

        lps[T1] += provided1;
        lps[T2] += provided2;
        kLast = uint256(lps[T1] * lps[T2]);

        // Return:
        providedFirstTokenAmount = provided1;
        providedSecondTokenAmount = provided2;
    }


    function withdrawLiquidity(uint128 minFirstTokenAmount, uint128 minSecondTokenAmount)
        override
        external
        initialized
        liquidityProvided
        returns (uint128 withdrawedFirstTokenAmount, uint128 withdrawedSecondTokenAmount)
    {
        uint256 pubkey = msg.pubkey();
        require(
            liquidityUserBalances[T1][pubkey] >= minFirstTokenAmount && 
            liquidityUserBalances[T2][pubkey] >= minSecondTokenAmount, 
            ERROR_INSUFFICIENT_USER_LP_BALANCE,
            ERROR_INSUFFICIENT_USER_LP_BALANCE_MSG
        );

        uint128 withdrawed1 = minSecondTokenAmount != 0 ? (lps[T1] * minSecondTokenAmount / lps[T2]) : 0;
        uint128 withdrawed2 = minFirstTokenAmount  != 0 ? (lps[T2] * minFirstTokenAmount / lps[T1])  : 0;

        if (withdrawed1 > 0 && withdrawed1 >= minFirstTokenAmount) {
            withdrawed2 = minSecondTokenAmount;
        }
        else if (withdrawed2 > 0 && withdrawed2 >= minSecondTokenAmount) {
            withdrawed1 = minFirstTokenAmount;
        }
        else {
            return (0, 0);
        }

        lps[T1] -= withdrawed1;
        lps[T2] -= withdrawed2;

        liquidityUserBalances[T1][pubkey] -= withdrawed1;
        liquidityUserBalances[T2][pubkey] -= withdrawed2;

        tokenUserBalances[T1][pubkey] += withdrawed1;
        tokenUserBalances[T2][pubkey] += withdrawed2; 
        
        // Return
        withdrawedFirstTokenAmount = withdrawed1;
        withdrawedSecondTokenAmount = withdrawed2;
    }


    function swap(address swappableTokenRoot, uint128 swappableTokenAmount)
        override
        external
        initialized
        liquidityProvided
        notEmptyAmount(swappableTokenAmount)
        userEnoughTokenBalance(swappableTokenRoot, swappableTokenAmount)
        returns (uint128 targetTokenAmount)     
    {
        uint256 pubK = msg.pubkey();
        uint8 fromK = _getTokenPosition(swappableTokenRoot); // if tokenRoot doesn't exist, throws exception
        uint8 toK = fromK == T1 ? T2 : T1;

        uint128 fee = swappableTokenAmount * feeNominator / feeDenominator;
        uint128 newFromPool = lps[fromK] + swappableTokenAmount;
        uint128 newToPool = uint128( kLast / (newFromPool - fee));

        uint128 profit = lps[toK] - newToPool;

        tokenUserBalances[fromK][pubK] -= swappableTokenAmount;
        tokenUserBalances[toK][pubK] += profit;

        lps[fromK] = newFromPool;
        lps[toK] = newToPool;
        kLast = newFromPool * newToPool;

        return profit;
    }


    function __kek(address swappableTokenRoot, uint128 swappableTokenAmount) 
        private 
        inline
        returns (uint8 fromK, uint8 toK, uint128 newFromPool, uint128 newToPool, uint128 profit)
    {
        
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

    function checkIsLiquidityProvided() private inline returns (bool) {
        return lps[T1] > 0 && lps[T2] > 0 && kLast > 0;
    }


    //============DEBUG============

    function _getLiquidityPoolTokens() override external view returns (_DebugLPInfo dlpi) {

    }

    function _getUserLiquidityPoolTokens() override external view returns (_DebugLPInfo dlpi) {

    }

    function _getExchangeRateSimulation(
        uint256 t1,
        uint256 t2,
        uint256 swapToken1,
        uint256 swapToken2
    ) override external view returns (_DebugERInfo deri) {

    }
}