pragma ton-solidity ^0.39.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/IRootTokenContract.sol';
import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/ITokensReceivedCallback.sol';
import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/ITONTokenWallet.sol';
import './interfaces/ISwapPairContract.sol';
import './interfaces/ISwapPairInformation.sol';
import './interfaces/IUpgradeSwapPairCode.sol';
import './interfaces/IERC20LiteToken.sol';

contract SwapPairContract is ITokensReceivedCallback, ISwapPairInformation, IUpgradeSwapPairCode, ISwapPairContract, IERC20LiteToken {
    address static token1;
    address static token2;
    uint    static swapPairID;

    uint32 swapPairCodeVersion = 1;
    uint256 swapPairDeployer;
    address swapPairRootContract;

    uint128 constant feeNominator = 997;
    uint128 constant feeDenominator = 1000;
    uint256 constant kMin = 0;

    uint256 liquidityTokensMinted = 0;
    mapping(uint256 => uint256) liquidityUserTokens;

    mapping(uint8 => address) tokens;
    mapping(address => uint8) tokenPositions;

    //Deployed token wallets addresses
    mapping(uint8 => address) tokenWallets;

    //Users balances
    mapping(uint256 => uint256) usersTONBalance;
    mapping(uint8 => mapping(uint256 => uint128)) tokenUserBalances;
    mapping(uint256 => uint128) rewardUserBalance;

    //Liquidity Pools
    mapping(uint8 => uint128) private lps;
    uint256 public kLast; // lps[T1] * lps[T2] after most recent swap


    //Pair creation timestamp
    uint256 creationTimestamp;

    //Initialization status. 0 - new, 1 - one wallet created, 2 - fully initialized
    uint private initializedStatus = 0;

    // Balance managing constants
    // Average function execution cost + 20-30% reserve
    uint128          erc20FunctionCallCost      = 2    milli;
    uint128          getterFunctionCallCost     = 10   milli;
    uint128          heavyFunctionCallCost      = 100  milli;
    // Required for interaction with wallets for smart-contracts
    uint128 constant sendToTIP3TokenWallets     = 110  milli;
    uint128 constant sendToRootToken            = 500  milli;
    // We don't want to risk, this is one-time procedure
    // Extra wallet's tons will be transferred with first token transfer operation
    // Yep, there are transfer losses, but they are pretty small
    uint128 constant walletInitialBalanceAmount = 1000 milli;
    uint128 constant walletDeployMessageValue   = 1500 milli;

    // Constants for mechanism of payment rebalance
    uint128 constant erc20Increase    = 1050;
    uint128 constant erc20Decrease    = 977;
    uint128 constant gettersIncrease  = 1105;
    uint128 constant gettersDecrease  = 991;
    uint128 constant functionIncrease = 1110;
    uint128 constant functionDecrease = 983;

    // Tokens positions
    uint8 constant T1 = 0;
    uint8 constant T2 = 1;

    //Error codes    
    uint8 constant ERROR_CONTRACT_ALREADY_INITIALIZED  = 100; string constant ERROR_CONTRACT_ALREADY_INITIALIZED_MSG  = "Error: contract is already initialized";
    uint8 constant ERROR_CONTRACT_NOT_INITIALIZED      = 101; string constant ERROR_CONTRACT_NOT_INITIALIZED_MSG      = "Error: contract is not initialized";
    uint8 constant ERROR_CALLER_IS_NOT_TOKEN_ROOT      = 102; string constant ERROR_CALLER_IS_NOT_TOKEN_ROOT_MSG      = "Error: msg.sender is not token root";
    uint8 constant ERROR_CALLER_IS_NOT_TOKEN_WALLET    = 103; string constant ERROR_CALLER_IS_NOT_TOKEN_WALLET_MSG    = "Error: msg.sender is not token wallet";
    uint8 constant ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT  = 104; string constant ERROR_CALLER_IS_NOT_SWAP_PAIR_ROOT_MSG  = "Error: msg.sender is not swap pair root contract";
    uint8 constant ERROR_CALLER_IS_NOT_OWNER           = 105; string constant ERROR_CALLER_IS_NOT_OWNER_MSG           = "Error: message sender is not not owner";
    uint8 constant ERROR_LOW_MESSAGE_VALUE             = 106; string constant ERROR_LOW_MESSAGE_VALUE_MSG             = "Error: msg.value is too low"; 
    uint8 constant ERROR_NO_MESSAGE_SIGNATURE          = 107; string constant ERROR_NO_MESSAGE_SIGNATURE_MSG          = "Error: message is not signed"; 

    uint8 constant ERROR_INVALID_TOKEN_ADDRESS         = 110; string constant ERROR_INVALID_TOKEN_ADDRESS_MSG         = "Error: invalid token address";
    uint8 constant ERROR_INVALID_TOKEN_AMOUNT          = 111; string constant ERROR_INVALID_TOKEN_AMOUNT_MSG          = "Error: invalid token amount";
    uint8 constant ERROR_INVALID_TARGET_WALLET         = 112; string constant ERROR_INVALID_TARGET_WALLET_MSG         = "Error: specified token wallet cannot be zero address";
    uint8 constant ERROR_TARGET_ADDRESS_IS_ZERO        = 113; string constant ERROR_TARGET_ADDRESS_IS_ZERO_MSG        = "Error: requested ton transfer to zero address";
    
    uint8 constant ERROR_INSUFFICIENT_USER_BALANCE     = 120; string constant ERROR_INSUFFICIENT_USER_BALANCE_MSG     = "Error: insufficient user balance";
    uint8 constant ERROR_INSUFFICIENT_USER_LP_BALANCE  = 121; string constant ERROR_INSUFFICIENT_USER_LP_BALANCE_MSG  = "Error: insufficient user liquidity pool balance";
    uint8 constant ERROR_UNKNOWN_USER_PUBKEY           = 122; string constant ERROR_UNKNOWN_USER_PUBKEY_MSG           = "Error: unknown user's pubkey";
    uint8 constant ERROR_LOW_USER_BALANCE              = 123; string constant ERROR_LOW_USER_BALANCE_MSG              = "Error: user TON balance is too low";
    
    uint8 constant ERROR_NO_LIQUIDITY_PROVIDED         = 130; string constant ERROR_NO_LIQUIDITY_PROVIDED_MSG         = "Error: no liquidity provided";
    uint8 constant ERROR_LIQUIDITY_PROVIDING_RATE      = 131; string constant ERROR_LIQUIDITY_PROVIDING_RATE_MSG      = "Error: added liquidity disrupts the rate";
    uint8 constant ERROR_INSUFFICIENT_LIQUIDITY_AMOUNT = 132; string constant ERROR_INSUFFICIENT_LIQUIDITY_AMOUNT_MSG = "Error: zero liquidity tokens provided or provided token amount is too low";

    uint8 constant ERROR_CODE_DOWNGRADE_REQUESTED      = 200; string constant ERROR_CODE_DOWNGRADE_REQUESTED_MSG      = "Error: code downgrade requested";
    uint8 constant ERROR_CODE_UPGRADE_REQUESTED        = 201; string constant ERROR_CODE_UPGRADE_REQUESTED_MSG        = "Error: code upgrade requested";
    

    constructor(address rootContract, uint spd) public {
        tvm.accept();
        creationTimestamp = now;
        swapPairRootContract = rootContract;
        swapPairDeployer = spd;

        tokens[T1] = token1;
        tokens[T2] = token2;
        tokenPositions[token1] = T1;
        tokenPositions[token2] = T2;

        lps[T1] = 0;
        lps[T2] = 0;
        kLast = 0;

        //Deploy tokens wallets
        _deployWallets();
    }

    /**
    * Deploy internal wallets. getWalletAddressCallback to get their addresses
    */
    function _deployWallets() private view {
        tvm.accept();
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

        _getWalletAddresses();
    }

    function _getWalletAddresses() private view {
        tvm.accept();
        IRootTokenContract(token1).getWalletAddress{value: sendToRootToken, callback: this.getWalletAddressCallback}(tvm.pubkey(), address(this));
        IRootTokenContract(token2).getWalletAddress{value: sendToRootToken, callback: this.getWalletAddressCallback}(tvm.pubkey(), address(this));
    }

    function _reinitialize() external onlyOwner {
        require(msg.value >= 2 ton, ERROR_LOW_MESSAGE_VALUE, ERROR_LOW_MESSAGE_VALUE_MSG);
        initializedStatus = 0;
        delete tokenWallets;
        _deployWallets();
    }

    //============TON balance functions============

    receive() external {
        require(msg.value > heavyFunctionCallCost);
        TvmSlice ts = msg.data;
        uint pubkey = ts.decode(uint);
        usersTONBalance[pubkey] += msg.value;
    }

    fallback() external {
        require(msg.value > heavyFunctionCallCost);
        TvmSlice ts = msg.data;
        uint pubkey = ts.decode(uint);
        usersTONBalance[pubkey] += msg.value;
    }

    function withdrawTONs(address tonDestination, uint128 amount) override external onlyPrePaid(amount) {
        uint pubkey = msg.pubkey();
        require(
            pubkey != 0, 
            ERROR_NO_MESSAGE_SIGNATURE,
            ERROR_NO_MESSAGE_SIGNATURE_MSG
        );
        require(
            tonDestination != address.makeAddrStd(0, 0),
            ERROR_TARGET_ADDRESS_IS_ZERO,
            ERROR_TARGET_ADDRESS_IS_ZERO_MSG
        );
        tvm.accept();
        address(tonDestination).transfer({value: amount * 95/100, bounce: true});
    } 

    //============Get functions============

    /**
    * Get pair creation timestamp
    */
    function getCreationTimestamp() override public view getterPayment returns (uint256) {
        return creationTimestamp;
    }

    function getLPComission() override external view getterPayment returns(uint128) {
        return heavyFunctionCallCost;
    }

    function getPairInfo() override external view getterPayment returns (SwapPairInfo info) {
        return SwapPairInfo(
            swapPairRootContract,
            token1,
            token2,
            tokenWallets[T1],
            tokenWallets[T2],
            swapPairDeployer,
            creationTimestamp,
            address(this),
            swapPairID,
            swapPairCodeVersion
        );
    }

    function getUserBalance(uint pubkey) 
        override   
        external
        view
        initialized
        getterPayment
        returns (UserBalanceInfo ubi) 
    {
        uint _pk = pubkey != 0 ? pubkey : msg.pubkey();
        return UserBalanceInfo(
            token1,
            token2,
            tokenUserBalances[T1][_pk],
            tokenUserBalances[T2][_pk]
        );
    }

    function getUserTONBalance(uint pubkey) 
        override
        external
        view
        initialized
        getterPayment
        returns (uint balance)
    {
        uint _pk = pubkey != 0 ? pubkey : msg.pubkey();
        return usersTONBalance[_pk];
    }

    function getUserLiquidityPoolBalance(uint pubkey) 
        override 
        external 
        view 
        getterPayment
        returns (UserPoolInfo upi) 
    {
        uint _pk = pubkey != 0 ? pubkey : msg.pubkey();
        return UserPoolInfo(
            token1,
            token2,
            liquidityUserTokens[_pk],
            liquidityTokensMinted,
            lps[T1],
            lps[T2]
        );
    }

    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) 
        override
        external
        view
        initialized
        getterPayment
        tokenExistsInPair(swappableTokenRoot)
        returns (SwapInfo)
    {
        if (swappableTokenAmount <= 0)
            return SwapInfo(0, 0, 0);

        _SwapInfoInternal si = _getSwapInfo(swappableTokenRoot, swappableTokenAmount);

        return SwapInfo(swappableTokenAmount, si.targetTokenAmount, si.fee);
    }

    function getCurrentExchangeRate()
        override
        external
        view
        getterPayment
        returns (uint128, uint128)
    {
        return (lps[T1], lps[T2]);
    }

    //============Functions for offchain execution============

    // NOTICE: Requires a lot of gas, will only work with runLocal
    function getProvidingLiquidityInfo(uint128 maxFirstTokenAmount, uint128 maxSecondTokenAmount)
        override
        external
        view
        initialized
        returns (uint128 providedFirstTokenAmount, uint128 providedSecondTokenAmount)
    {
        uint256 _m = 0;
        (providedFirstTokenAmount, providedSecondTokenAmount, _m) = _calculateProvidingLiquidityInfo(maxFirstTokenAmount, maxSecondTokenAmount);
    }

    // NOTICE: Requires a lot of gas, will only work with runLocal
    function getWithdrawingLiquidityInfo(uint256 liquidityTokensAmount)
        override
        external
        view
        initialized
        returns (uint128 withdrawedFirstTokenAmount, uint128 withdrawedSecondTokenAmount)
    {
        uint256 _b = 0;
        (withdrawedFirstTokenAmount, withdrawedSecondTokenAmount, _b) = _calculateWithdrawingLiquidityInfo(liquidityTokensAmount, msg.pubkey());
    }

    // NOTICE: Requires a lot of gas, will only work with runLocal
    function getAnotherTokenProvidingAmount(address providingTokenRoot, uint128 providingTokenAmount)
        override
        external
        view
        initialized
        returns(uint128 anotherTokenAmount)
    {   
        if (!_checkIsLiquidityProvided())
            return 0;
        uint8 fromK = _getTokenPosition(providingTokenRoot);
        uint8 toK = fromK == T1 ? T2 : T1;

        return providingTokenAmount != 0 ? math.muldivc(providingTokenAmount,  lps[toK], lps[fromK]) : 0;
    }

    //============LP Functions============

    function provideLiquidity(uint128 maxFirstTokenAmount, uint128 maxSecondTokenAmount)
        override
        external
        initialized
        onlyPrePaid(heavyFunctionCallCost)
        returns (uint128 providedFirstTokenAmount, uint128 providedSecondTokenAmount)
    {
        uint256 pubkey = msg.pubkey();
        uint128 _sb = address(this).balance;

        tvm.accept();

        if (!notZeroLiquidity(maxFirstTokenAmount, maxSecondTokenAmount)) {
            _initializeRebalance(pubkey, _sb);
            return (0,0);
        }
        checkUserTokens(token1, maxFirstTokenAmount, token2, maxSecondTokenAmount, pubkey);

        (uint128 provided1, uint128 provided2, uint256 minted) = _calculateProvidingLiquidityInfo(maxFirstTokenAmount, maxSecondTokenAmount);

        if (!notZeroLiquidity(provided1, provided2)) {
            _initializeRebalance(pubkey, _sb);
            return (0,0);
        }

        tokenUserBalances[T1][pubkey]-= provided1;
        tokenUserBalances[T2][pubkey]-= provided2;  

        mintLPTokens(pubkey, minted);

        lps[T1] += provided1;
        lps[T2] += provided2;
        kLast = uint256(lps[T1]) * uint256(lps[T2]);

        _initializeRebalance(pubkey, _sb);

        return (provided1, provided2);
    }


    function withdrawLiquidity(uint256 liquidityTokensAmount)
        override
        external
        initialized
        onlyPrePaid(heavyFunctionCallCost)
        returns (uint128 withdrawedFirstTokenAmount, uint128 withdrawedSecondTokenAmount)
    {
        uint128 _sb = address(this).balance;
        uint256 pubkey = msg.pubkey();
        tvm.accept();
        require(
            _checkIsLiquidityProvided(),
            ERROR_NO_LIQUIDITY_PROVIDED,
            ERROR_NO_LIQUIDITY_PROVIDED_MSG
        );

        _checkIsEnoughUserLiquidity(pubkey, liquidityTokensAmount);

        (uint128 withdrawed1, uint128 withdrawed2, uint256 burned) = _calculateWithdrawingLiquidityInfo(liquidityTokensAmount, pubkey);

        if (withdrawed1 <= 0 || withdrawed2 <= 0) {
            _initializeRebalance(pubkey, _sb);
            return (0, 0);
        }

        lps[T1] -= withdrawed1;
        lps[T2] -= withdrawed2;
        kLast = uint256(lps[T1]) * uint256(lps[T2]);

        burnLPTokens(pubkey, burned);

        tokenUserBalances[T1][pubkey] += withdrawed1;
        tokenUserBalances[T2][pubkey] += withdrawed2; 

        _initializeRebalance(pubkey, _sb);
        
        return (withdrawed1, withdrawed2);
    }


    function swap(address swappableTokenRoot, uint128 swappableTokenAmount) override external returns(SwapInfo) { 
        return _swap(swappableTokenRoot, swappableTokenAmount);
    }

    function _swap(address swappableTokenRoot, uint128 swappableTokenAmount)
        internal
        initialized
        onlyPrePaid(heavyFunctionCallCost)
        returns (SwapInfo)  
    {
        uint128 _sb = address(this).balance;
        uint256 pubkey = msg.pubkey();
        tvm.accept();
        require(
            tokenPositions.exists(swappableTokenRoot),
            ERROR_INVALID_TOKEN_ADDRESS,
            ERROR_INVALID_TOKEN_ADDRESS_MSG
        );
        require(
            _checkIsLiquidityProvided(),
            ERROR_NO_LIQUIDITY_PROVIDED,
            ERROR_NO_LIQUIDITY_PROVIDED_MSG
        );
        notEmptyAmount(swappableTokenAmount);
        userEnoughTokenBalance(swappableTokenRoot, swappableTokenAmount, pubkey);

        _SwapInfoInternal _si = _getSwapInfo(swappableTokenRoot, swappableTokenAmount);

        if (!notZeroLiquidity(swappableTokenAmount, _si.targetTokenAmount)) {
            _initializeRebalance(pubkey, _sb);
            return SwapInfo(0, 0, 0);
        }

        uint8 fromK = _si.fromKey;
        uint8 toK = _si.toKey;

        tokenUserBalances[fromK][pubkey] -= swappableTokenAmount;
        tokenUserBalances[toK][pubkey]   += _si.targetTokenAmount;

        lps[fromK] = _si.newFromPool;
        lps[toK] = _si.newToPool;
        kLast = uint256(_si.newFromPool) * uint256(_si.newToPool);

        _initializeRebalance(pubkey, _sb);

        return SwapInfo(swappableTokenAmount, _si.targetTokenAmount, _si.fee);
    }


    function withdrawTokens(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) 
        override
        external
        initialized
        onlyPrePaid(heavyFunctionCallCost)
    {
        uint128 _sb = address(this).balance;
        uint pubkey = msg.pubkey();
        uint8 _tn = tokenPositions[withdrawalTokenRoot];
        tvm.accept();
        require(
            tokenPositions.exists(withdrawalTokenRoot),
            ERROR_INVALID_TOKEN_ADDRESS,
            ERROR_INVALID_TOKEN_ADDRESS_MSG
        );
        require(
            tokenUserBalances[_tn][pubkey] >= amount && amount != 0,
            ERROR_INVALID_TOKEN_AMOUNT,
            ERROR_INVALID_TOKEN_AMOUNT_MSG
        );
        require(
            receiveTokenWallet.value != 0,
            ERROR_INVALID_TARGET_WALLET,
            ERROR_INVALID_TARGET_WALLET_MSG
        );
        TvmCell payload;
        ITONTokenWallet(tokenWallets[_tn]).transfer{
            value: sendToTIP3TokenWallets
        }(
            receiveTokenWallet,
            amount, 
            0,
            address(this),
            true,
            payload
        );
        tokenUserBalances[_tn][pubkey] -= amount;
        _initializeRebalance(pubkey, _sb);
    }

    //============ERC20Lite LP Token============

    function mintLPTokens(uint256 pubkey, uint256 amount) private inline {
        liquidityTokensMinted += amount;
        liquidityUserTokens[pubkey] += amount;
    }

    function burnLPTokens(uint256 pubkey, uint256 amount) private inline {
        liquidityTokensMinted -= amount;
        liquidityUserTokens[pubkey] -= amount;
    }

    function transfer(uint256 receiver, uint256 amount) override external onlyPrePaid(erc20FunctionCallCost) {
        uint sender = msg.pubkey();
        _initializeERC20Rebalance(sender, address(this).balance);
        _checkIsEnoughUserLiquidity(sender, amount);
        liquidityUserTokens[sender] -= amount;
        liquidityUserTokens[receiver] += amount;
    }

    function getBalance(uint256 pubkey) override external returns (uint256) {
        uint pk = pubkey == 0 ? msg.pubkey() : pubkey;
        return liquidityUserTokens[pk];
    }

    //============HELPERS============

    function _calculateProvidingLiquidityInfo(uint128 maxFirstTokenAmount, uint128 maxSecondTokenAmount)
        private
        view
        inline
        returns (uint128 provided1, uint128 provided2, uint256 _minted)
    {
        if ( !_checkIsLiquidityProvided() ) {
            provided1 = maxFirstTokenAmount;
            provided2 = maxSecondTokenAmount;
            _minted = uint256(provided1) * uint256(provided2);
        }
        else {
            uint128 maxToProvide1 = maxSecondTokenAmount != 0 ?  math.muldiv(maxSecondTokenAmount, lps[T1], lps[T2]) : 0;
            uint128 maxToProvide2 = maxFirstTokenAmount  != 0 ?  math.muldiv(maxFirstTokenAmount,  lps[T2], lps[T1]) : 0;
            if (maxToProvide1 <= maxFirstTokenAmount ) {
                provided1 = maxToProvide1;
                provided2 = maxSecondTokenAmount;
                _minted =  math.muldiv(uint256(provided2), liquidityTokensMinted, uint256(lps[T2]) );
            } else {
                provided1 = maxFirstTokenAmount;
                provided2 = maxToProvide2;
                _minted =  math.muldiv(uint256(provided1), liquidityTokensMinted, uint256(lps[T1]) );
            }
        }
    }

    function _calculateWithdrawingLiquidityInfo(uint256 liquidityTokensAmount, uint256 _pubkey)
        private
        view
        inline
        returns (uint128 withdrawed1, uint128 withdrawed2, uint256 _burned)
    {   
        if (liquidityTokensMinted <= 0 || liquidityTokensAmount <= 0)
            return (0, 0, 0);
        
        withdrawed1 = uint128(math.muldiv(uint256(lps[T1]), liquidityTokensAmount, liquidityTokensMinted));
        withdrawed2 = uint128(math.muldiv(uint256(lps[T2]), liquidityTokensAmount, liquidityTokensMinted));
        _burned = liquidityTokensAmount;
    }

    function _initializeRebalance(uint pubkey, uint128 startBalance) private inline {
        usersTONBalance[pubkey] -= heavyFunctionCallCost;
        SwapPairContract(this)._rebalance(startBalance);
    }

    function _rebalance(uint128 balance) external onlySelf {
        if (address(this).balance + heavyFunctionCallCost > balance)
            heavyFunctionCallCost = math.muldiv(heavyFunctionCallCost, functionDecrease, 1000);
        else
            heavyFunctionCallCost = math.muldiv(heavyFunctionCallCost, functionIncrease, 1000);
    }

    function _initializeGettersRebalance(uint pubkey, uint128 startBalance) private inline {
        usersTONBalance[pubkey] -= getterFunctionCallCost;
        SwapPairContract(this)._rebalanceGetters(startBalance);
    }

    function _rebalanceGetters(uint128 balance) external onlySelf {
        if (address(this).balance + getterFunctionCallCost > balance)
            getterFunctionCallCost = math.muldiv(getterFunctionCallCost, gettersDecrease, 1000);
        else
            getterFunctionCallCost = math.muldiv(getterFunctionCallCost, gettersIncrease, 1000);
    }

    function _initializeERC20Rebalance(uint pubkey, uint128 startBalance) private inline {
        usersTONBalance[pubkey] -= erc20FunctionCallCost;
        SwapPairContract(this)._rebalanceERC20(startBalance);
    }

    function _rebalanceERC20(uint128 balance) external onlySelf {
        if (address(this).balance + erc20FunctionCallCost > balance)
            erc20FunctionCallCost = math.muldiv(erc20FunctionCallCost, erc20Decrease, 1000);
        else
            erc20FunctionCallCost = math.muldiv(erc20FunctionCallCost, erc20Increase, 1000);
    }
    
    function _getSwapInfo(address swappableTokenRoot, uint128 swappableTokenAmount) 
        private 
        view
        inline
        tokenExistsInPair(swappableTokenRoot)
        returns (_SwapInfoInternal swapInfo)
    {
        uint8 fromK = _getTokenPosition(swappableTokenRoot);
        uint8 toK = fromK == T1 ? T2 : T1;

        uint128 fee = swappableTokenAmount - math.muldivc(swappableTokenAmount, feeNominator, feeDenominator);
        uint128 newFromPool = lps[fromK] + swappableTokenAmount;
        uint128 newToPool = uint128( math.divc(kLast, newFromPool - fee) );

        uint128 targetTokenAmount = lps[toK] - newToPool;

        _SwapInfoInternal result = _SwapInfoInternal(fromK, toK, newFromPool, newToPool, targetTokenAmount, fee);

        return result;
    }

    /*
     * Get token position -> 
     */
    function _getTokenPosition(address _token) 
        private
        view
        initialized
        tokenExistsInPair(_token)
        returns(uint8)
    {
        return tokenPositions.at(_token);
    }

    function _checkIsLiquidityProvided() private view inline returns (bool) {
        return lps[T1] > 0 && lps[T2] > 0 && kLast > kMin;
    }


    //============Callbacks============

    /*
    * Deployed wallet address callback
    */
    function getWalletAddressCallback(address walletAddress) external onlyTokenRoot {
        require(initializedStatus < 2, ERROR_CONTRACT_ALREADY_INITIALIZED);
        tvm.accept();
        if (msg.sender == token1) {
            if( !tokenWallets.exists(T1) )
                initializedStatus++;
            tokenWallets[T1] = walletAddress;
        }

        if (msg.sender == token2) {
            if( !tokenWallets.exists(T2) )
                initializedStatus++;
            tokenWallets[T2] = walletAddress;
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
        view 
    {
        tvm.accept();
        ITONTokenWallet(tokenWallets[T1]).setReceiveCallback{
            value: 200 milliton
        }(
            address(this),
            false
        );
        ITONTokenWallet(tokenWallets[T2]).setReceiveCallback{
            value: 200 milliton
        }(
            address(this),
            false
        );
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
        tvm.accept();
        uint8 _p = tokenWallets[T1] == msg.sender ? T1 : T2; // `onlyWallets` eliminates other validational
        if (tokenUserBalances[_p].exists(sender_public_key)) {
            tokenUserBalances[_p].replace(
                sender_public_key,
                tokenUserBalances[_p].at(sender_public_key) + amount
            );
        } else {
            tokenUserBalances[_p].add(sender_public_key, amount);
        }
    }

    
    //============Upgrade swap pair code part============

    function updateSwapPairCode(TvmCell newCode, uint32 newCodeVersion) override external onlySwapPairRoot {
        require(
            newCodeVersion > newCodeVersion, 
            ERROR_CODE_DOWNGRADE_REQUESTED,
            ERROR_CODE_DOWNGRADE_REQUESTED_MSG
        );
        tvm.accept();
        swapPairCodeVersion = newCodeVersion;

        tvm.setcode(newCode);
        tvm.setCurrentCode(newCode);
        _initializeAfterCodeUpdate();
    }

    function checkIfSwapPairUpgradeRequired(uint32 newCodeVersion) override external onlySwapPairRoot returns(bool) {
        return newCodeVersion > swapPairCodeVersion;
    }

    function _initializeAfterCodeUpdate() inline private {
        //code will be added when required
    }

    //============Modifiers============

    modifier initialized() {
        require(initializedStatus == 2, ERROR_CONTRACT_NOT_INITIALIZED, ERROR_CONTRACT_NOT_INITIALIZED_MSG);
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this));
        _;
    }

    modifier onlyOwner() {
        require(
            msg.pubkey() == swapPairDeployer,
            ERROR_CALLER_IS_NOT_OWNER,
            ERROR_CALLER_IS_NOT_OWNER_MSG
        );
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
        bool b1 = tokenWallets.exists(T1) && msg.sender == tokenWallets[T1];
        bool b2 = tokenWallets.exists(T2) && msg.sender == tokenWallets[T2];
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

    modifier onlyPrePaid(uint128 requiredSum) {
        require(
            usersTONBalance[msg.pubkey()] >= requiredSum,
            ERROR_LOW_USER_BALANCE,
            ERROR_LOW_USER_BALANCE_MSG
        );
        _;
    }

    modifier liquidityProvided() {
        require(
            _checkIsLiquidityProvided(),
            ERROR_NO_LIQUIDITY_PROVIDED,
            ERROR_NO_LIQUIDITY_PROVIDED_MSG
        );
        _;
    }

    
    modifier tokenExistsInPair(address _token) {
        require(
            tokenPositions.exists(_token),
            ERROR_INVALID_TOKEN_ADDRESS,
            ERROR_INVALID_TOKEN_ADDRESS_MSG
        );
        _;
    }

    modifier getterPayment() {
        if (msg.sender.value == 0 && usersTONBalance[msg.pubkey()] >= getterFunctionCallCost) {
            tvm.accept();
            _initializeGettersRebalance(msg.pubkey(), address(this).balance);
        }
        _;
    }

    //============Too big for modifier too small for function============

    function notEmptyAmount(uint128 _amount) private pure inline {
        require (_amount > 0,  ERROR_INVALID_TOKEN_AMOUNT, ERROR_INVALID_TOKEN_AMOUNT_MSG);
    }

    function notZeroLiquidity(uint128 _amount1, uint128 _amount2) private pure inline returns(bool) {
        return _amount1 > 0 && _amount2 > 0;
    }

    function userEnoughTokenBalance(address _token, uint128 amount, uint pubkey) private view inline {
        uint8 _p = _getTokenPosition(_token);        
        uint128 userBalance = tokenUserBalances[_p][pubkey];
        require(
            userBalance > 0 && userBalance >= amount,
            ERROR_INSUFFICIENT_USER_BALANCE,
            ERROR_INSUFFICIENT_USER_BALANCE_MSG
        );
    }

    function checkUserTokens(address token1_, uint128 token1Amount, address token2_, uint128 token2Amount, uint pubkey) private view inline {
        bool b1 = tokenUserBalances[tokenPositions[token1_]][pubkey] >= token1Amount;
        bool b2 = tokenUserBalances[tokenPositions[token2_]][pubkey] >= token2Amount;
        require(
            b1 && b2,
            ERROR_INSUFFICIENT_USER_BALANCE,
            ERROR_INSUFFICIENT_USER_BALANCE_MSG
        );
    }

    function _checkIsEnoughUserLiquidity(uint256 pubkey, uint256 burned) private view inline {
        require(
            liquidityUserTokens[pubkey] >= burned, 
            ERROR_INSUFFICIENT_USER_LP_BALANCE,
            ERROR_INSUFFICIENT_USER_LP_BALANCE_MSG
        );
    }
}