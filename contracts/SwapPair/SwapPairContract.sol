pragma ton-solidity ^0.39.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/IRootTokenContract.sol';
import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/ITokensReceivedCallback.sol';
import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/ITONTokenWallet.sol';
import "../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/IBurnTokensCallback.sol";
import "../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/IBurnableByOwnerTokenWallet.sol";
import './interfaces/swapPair/ISwapPairContract.sol';
import './interfaces/swapPair/ISwapPairInformation.sol';
import './interfaces/swapPair/IUpgradeSwapPairCode.sol';
import './interfaces/rootSwapPair/IRootContractCallback.sol';

import './interfaces/helpers/ITIP3TokenDeployer.sol';

import './libraries/swapPair/SwapPairErrors.sol';
import './libraries/swapPair/SwapPairConstants.sol';

// TODO: рефакторинг: добавить комментарии чтобы было понятно что за параметры

contract SwapPairContract is ITokensReceivedCallback, ISwapPairInformation, IUpgradeSwapPairCode, ISwapPairContract {
    address static token1;
    address static token2;
    uint    static swapPairID;

    uint32  swapPairCodeVersion;
    address swapPairRootContract;
    address tip3Deployer;

    address lpTokenRootAddress;
    address lpTokenWalletAddress;
    bytes   LPTokenName;

    uint128 constant feeNominator = 997;
    uint128 constant feeDenominator = 1000;

    uint256 liquidityTokensMinted = 0;

    mapping(address => uint8) tokenPositions;

    //Deployed token wallets addresses
    mapping(uint8 => address) tokenWallets;

    //Liquidity providers info for security reasons
    mapping(uint256 => LPProvidingInfo) lpInputTokensInfo;

    //Liquidity Pools
    mapping(uint8 => uint128) private lps;


    //Pair creation timestamp
    uint256 creationTimestamp;

    //Initialization status. 
    // 0 - new                             <- not initialized
    // 1 - one wallet created              <- not initialized
    // 2 - both wallets for TIP-3 created  <- not initialized
    // 3 - deployed LP token contract      <- not initialized
    // 4 - deployed LP token wallet        <- initialized
    uint private initializedStatus = 0;

    // Tokens positions
    uint8 constant T1 = 0;
    uint8 constant T2 = 1; 

    // Token info
    uint8 tokenInfoCount;
    IRootTokenContract.IRootTokenContractDetails T1Info;
    IRootTokenContract.IRootTokenContractDetails T2Info;

    uint8 constant wrongPayloadFormatMessage = 0;        //Received payload is invalid or has wrong format.";
    uint8 constant unknownOperationIdorWrongPayload = 1; //Received payload contains unknow Operation ID or is malformed.";
    uint8 constant sumIsTooLowForSwap = 2;               //Provided token amount is not enough for swap.";
    uint8 constant noLiquidityProvidedMessage = 3;       //No liquidity provided yet. Swaps are forbidden.";
    uint8 constant sumIsTooLowForLPTokenWithdraw = 4;    //Provided LP token amount is not enough to withdraw liquidity.";

    //============Contract initialization functions============

    constructor(address rootContract, address tip3Deployer_, uint32 swapPairCodeVersion_) public {
        tvm.accept();
        creationTimestamp = now;
        swapPairRootContract = rootContract;
        tip3Deployer = tip3Deployer_;
        swapPairCodeVersion = swapPairCodeVersion_;

        tokenPositions[token1] = T1;
        tokenPositions[token2] = T2;

        lps[T1] = 0;
        lps[T2] = 0;

        //Deploy tokens wallets
        _deployWallet(token1);
        _deployWallet(token2);

        // Get information about tokens
        _getTIP3Details(token1);
        _getTIP3Details(token2);
    }

    /**
     * Deploy wallet for swap pair.
     * @dev You cannot get address from this function so _getWalletAddress is used to get address of wallet
     * @param tokenRootAddress address of tip-3 root contract
     */
    function _deployWallet(address tokenRootAddress) private view {
        tvm.accept();
        IRootTokenContract(tokenRootAddress).deployEmptyWallet{
            value: SwapPairConstants.walletDeployMessageValue
        }(SwapPairConstants.walletInitialBalanceAmount, tvm.pubkey(), address(this), address(this));
        _getWalletAddress(tokenRootAddress);
    }

    /**
     * Get address of future wallet address deployed using _deployWallet
     * @dev getWalletAddressCallback is used to get wallet address
     * @param token address of tip-3 root contract
     */
    function _getWalletAddress(address token) private view {
        tvm.accept();
        IRootTokenContract(token).getWalletAddress{
            value: SwapPairConstants.sendToRootToken, 
            callback: this.getWalletAddressCallback
        }(tvm.pubkey(), address(this));
    }

    /**
     * Deployed wallet address callback
     * @dev can be called only by token root contracts
     * @param walletAddress address of deployed token wallet
     */
    function getWalletAddressCallback(address walletAddress) external onlyTokenRoot {
        require(initializedStatus < SwapPairConstants.contractFullyInitialized, SwapPairErrors.CONTRACT_ALREADY_INITIALIZED);
        tvm.accept();
        if (msg.sender == token1) {
            tokenWallets[T1] = walletAddress;
            initializedStatus++;
        }

        if (msg.sender == token2) {
            tokenWallets[T2] = walletAddress;
            initializedStatus++;
        }

        if (msg.sender == lpTokenRootAddress) {
            lpTokenWalletAddress = walletAddress;
            initializedStatus++;
        }

        /* 
            For all deployed wallets we set callback address equal to swap pair address
        */
        _setWalletsCallbackAddress(walletAddress);

        /*
            If all wallets were deployed and LP token root is deployed - swap pair is ready
            We call swap pair root callback to update stored information
        */
        if (initializedStatus == SwapPairConstants.contractFullyInitialized) {
            _swapPairInitializedCall();
        }
    }

    /**
     * Set callback address for wallets
     * @param walletAddress Address of TIP-3 wallet
     */
    function _setWalletsCallbackAddress(address walletAddress) private pure {
        tvm.accept();
        ITONTokenWallet(walletAddress).setReceiveCallback{
            value: 200 milliton
        }(
            address(this),
            false
        );
    }

    /**
     * Get tip-3 details from root tip-3 contract
     * @dev function _receiveTIP3Details is used for callback
     * @param tokenRootAddress address of tip-3 root contract
     */
    function _getTIP3Details(address tokenRootAddress) private pure {
        tvm.accept();
        IRootTokenContract(tokenRootAddress).getDetails{ value: SwapPairConstants.sendToRootToken, bounce: true, callback: this._receiveTIP3Details }();
    }

    /**
     * Receive requested TIP-3 details from root contract
     * @dev this function can be called only by know TIP-3 token root contracts (token1, token2, LP token)
     * @param rtcd Details about TIP-3
     */
    function _receiveTIP3Details(IRootTokenContract.IRootTokenContractDetails rtcd) 
        external
        onlyTokenRoot
    {
        tvm.accept();
        if (msg.sender == token1) {
            T1Info = rtcd;
            tokenInfoCount++;
        } else {
            T2Info = rtcd;
            tokenInfoCount++;
        }

        /*
            After we receive information about both tokens we can proceed to LP token creation
            This is mainly done for nice name of future LP token such as "T1 <-> T2"
        */
        if (tokenInfoCount == 2) {
            this._prepareDataForTIP3Deploy();
        }
    }

    /**
     * Build name of future TIP-3 LP token
     * @dev This function can be called only by contract itself
     */
    function _prepareDataForTIP3Deploy() external view onlySelf {
        tvm.accept();
        string res = string(T1Info.symbol);
        res.append("<->");
        res.append(string(T2Info.symbol));
        res.append(" LP");
        this._deployTIP3LpToken(bytes(res), bytes(res));
    }

    /**
     * Deploy TIP-3 LP token with created params
     * @dev This function can be called only by contract itself
     * @param name Name of future TIP-3 token, equal to symbol
     * @param symbol Symbol of future TIP-3 token
     */
    function _deployTIP3LpToken(bytes name, bytes symbol) external onlySelf {
        tvm.accept();
        LPTokenName = symbol;
        /*
            Another contract is required to deploy TIP-3 token
        */
        ITIP3TokenDeployer(tip3Deployer).deployTIP3Token{
            value: SwapPairConstants.tip3SendDeployGrams,
            bounce: true,
            callback: this._deployTIP3LpTokenCallback
        }(name, symbol, SwapPairConstants.tip3LpDecimals, 0, address(this), SwapPairConstants.tip3SendDeployGrams/2);
    }

    /**
     * Receive address of LP token root contract. Callback for _deployTIP3Lptoken
     * @dev This function can be called only by TIP-3 deployer contract
     * @param tip3RootContract Address of deployed LP token root contract
     */
    function _deployTIP3LpTokenCallback(address tip3RootContract) external onlyTIP3Deployer {
        tvm.accept();
        lpTokenRootAddress = tip3RootContract;
        initializedStatus++;
        _deployWallet(tip3RootContract);
    }

    //============TON balance function============

    receive() external {
        // Thanks!
    }

    //============Get functions============

    /**
     * Get general information about swap pair
     */
    function getPairInfo() override external responsible view returns (SwapPairInfo info) {
        return _constructSwapPairInfo();
    }

    /**
     * Get result of swap if swap would be performed right now
     * @param swappableTokenRoot Root of tip-3 token used for swap
     * @param swappableTokenAmount Amount of token for swap
     */
    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) 
        override
        external
        responsible
        view
        initialized
        tokenExistsInPair(swappableTokenRoot)
        returns (SwapInfo)
    {
        if (swappableTokenAmount <= 0)
            return SwapInfo(0, 0, 0);

        _SwapInfoInternal si = _calculateSwapInfo(swappableTokenRoot, swappableTokenAmount);

        return SwapInfo(swappableTokenAmount, si.targetTokenAmount, si.fee);
    }

    /**
     * Get current pool states
     */
    function getCurrentExchangeRate()
        override
        external
        responsible
        view
        returns (LiquidityPoolsInfo lpi)
    {
        return LiquidityPoolsInfo(address(this), lps[T1], lps[T2], liquidityTokensMinted);
    }

    //============Functions for offchain execution============

    /**
     * Get information for liquidity providing - how much of first and second tokens will be added to 
     * liquidity pools 
     * @dev Requires a lot of gas, recommended to run with runLocal
     * @notice This is just imitation of LP mechanism for offchain execution
     * @param maxFirstTokenAmount  amount of first token provided to LP
     * @param maxSecondTokenAmount amount of second token provided to LP
     */
    function getProvidingLiquidityInfo(uint128 maxFirstTokenAmount, uint128 maxSecondTokenAmount)
        override
        external
        view
        initialized
        returns (uint128 providedFirstTokenAmount, uint128 providedSecondTokenAmount)
    {
        (providedFirstTokenAmount, providedSecondTokenAmount,) = _calculateProvidingLiquidityInfo(maxFirstTokenAmount, maxSecondTokenAmount);
    }

    /**
     * Get information how much tokens you will receive if you burn given amount of LP tokens
     * @dev Requires a lot of gas, recommended to run with runLocal
     * @notice This is just imitation of LP mechanism for offchain execution
     * @param liquidityTokensAmount Amount of liquidity tokens to be burnt
     */
    function getWithdrawingLiquidityInfo(uint256 liquidityTokensAmount)
        override
        external
        view
        initialized
        returns (uint128 withdrawedFirstTokenAmount, uint128 withdrawedSecondTokenAmount)
    {
        (withdrawedFirstTokenAmount, withdrawedSecondTokenAmount,) = _calculateWithdrawingLiquidityInfo(liquidityTokensAmount);
    }

    /**
     * Calculate amount of another token you need to provide to LP
     * @dev Requires a lot of gas, recommended to run with runLocal
     * @notice This is just imitation of LP mechanism for offchain execution
     * @param providingTokenRoot Address of provided tip-3 token
     * @param providingTokenAmount Amount of provided tip-3 tokens
     */
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

    /**
     * Calculate LP providing information -> amount of first and second token provided and amount of LP token to mint
     * @notice This function doesn't change LP volumes. It only calculates
     * @param maxFirstTokenAmount Amount of first token user provided
     * @param maxSecondTokenAmount Amount of second token user provided
     */
    function _calculateProvidingLiquidityInfo(uint128 maxFirstTokenAmount, uint128 maxSecondTokenAmount)
        private
        view
        returns (uint128 provided1, uint128 provided2, uint256 _minted)
    {
        // TODO: Антон: подумать что можно сделать с тем, что мы минтим uint256

        /*
            If no liquidity provided than you set the initial exchange rate
        */
        if ( !_checkIsLiquidityProvided() ) {
            provided1 = maxFirstTokenAmount;
            provided2 = maxSecondTokenAmount;
            _minted = uint256(provided1) * uint256(provided2);
        } else {
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

    /**
     * Calculate amount of tokens received if given amount of LP tokens is burnt
     * @notice This function doesn't change LP volumes. It only calculates
     * @param liquidityTokensAmount Amount of LP tokens burnt
     */
    function _calculateWithdrawingLiquidityInfo(uint256 liquidityTokensAmount)
        private
        view
        returns (uint128 withdrawed1, uint128 withdrawed2, uint256 _burned)
    {   
        if (liquidityTokensMinted <= 0 || liquidityTokensAmount <= 0)
            return (0, 0, 0);
        
        withdrawed1 = uint128(math.muldiv(uint256(lps[T1]), liquidityTokensAmount, liquidityTokensMinted));
        withdrawed2 = uint128(math.muldiv(uint256(lps[T2]), liquidityTokensAmount, liquidityTokensMinted));
        _burned = liquidityTokensAmount;
    }

    /**
     * Calculate LP providing information of only one token was provided
     * @notice This function doesn't change LP volumes. It only calculates
     * @param tokenRoot Root contract address of provided token 
     * @param tokenAmount Amount of provided token
     */
    function _calculateOneTokenProvidingAmount(address tokenRoot, uint128 tokenAmount)
        private
        view
        returns(uint128)
    {   
        uint8 fromK = _getTokenPosition(tokenRoot);
        uint256 f = uint256(lps[fromK]);
        uint128 k = feeNominator+feeDenominator;
        uint256 b = f*k;
        uint256 v = f * _sqrt( k*k + math.muldiv(4*feeDenominator*feeNominator, tokenAmount, f));

        return uint128((v-b)/(feeNominator+feeNominator));  
    }

    /**
     * Calculate swap results
     * @notice This function doesn't change LP volumes. It only calculates swap results
     * @param swappableTokenRoot Root contract address of token used for swap
     * @param swappableTokenAmount Amount of token used for swap
     */
    function _calculateSwapInfo(address swappableTokenRoot, uint128 swappableTokenAmount) 
        private 
        view
        tokenExistsInPair(swappableTokenRoot)
        returns (_SwapInfoInternal swapInfo)
    {
        uint8 fromK = _getTokenPosition(swappableTokenRoot);
        uint8 toK = fromK == T1 ? T2 : T1;

        uint128 fee = swappableTokenAmount - math.muldivc(swappableTokenAmount, feeNominator, feeDenominator);
        uint128 newFromPool = lps[fromK] + swappableTokenAmount;
        uint128 newToPool = uint128( math.divc(uint256(lps[T1]) * uint256(lps[T2]), newFromPool - fee) );

        uint128 targetTokenAmount = lps[toK] - newToPool;

        _SwapInfoInternal result = _SwapInfoInternal(fromK, toK, newFromPool, newToPool, targetTokenAmount, fee);

        return result;
    }

    /**
     * Wrapper for _calculateSwapInfo that changes the state of the contract
     * @notice This function changes LP volumes 
     * @param swappableTokenRoot Root contract address of token used for swap
     * @param swappableTokenAmount Amount of tokens used for swap
     */
    function _swap(address swappableTokenRoot, uint128 swappableTokenAmount)
        private
        returns (SwapInfo)  
    {
        _SwapInfoInternal _si = _calculateSwapInfo(swappableTokenRoot, swappableTokenAmount);

        if (!notZeroLiquidity(swappableTokenAmount, _si.targetTokenAmount)) {
            return SwapInfo(0, 0, 0);
        }

        lps[_si.fromKey] = _si.newFromPool;
        lps[_si.toKey] = _si.newToPool;

        return SwapInfo(swappableTokenAmount, _si.targetTokenAmount, _si.fee);
    }

    // TODO: Антон: проверка провайдинга ликвидности по одному токену
    /**
     * Internal function used for providing liquidity using one token
     * @notice To provide liquidity using one token it's required to swap part of provided token amount
     * @param tokenRoot Root contract address of token used for liquidity providing
     * @param tokenAmount Amount of tokens used for liquidity providing
     * @param senderPubkey Public key of user that provides liquidity
     * @param senderAddress Address of TON wallet of user
     * @param lpWallet Address of user's LP wallet
     */
    function _provideLiquidityOneToken(address tokenRoot, uint128 tokenAmount, uint256 senderPubkey, address senderAddress, address lpWallet) 
        private 
        tokenExistsInPair(tokenRoot)
        returns (uint128 provided1, uint128 provided2, uint256 toMint, uint128 inputTokenRemainder)
    {
        uint128 amount = _calculateOneTokenProvidingAmount(tokenRoot, tokenAmount);

        if (amount <= 0) 
            return (0, 0, 0, 0);

        SwapInfo si = _swap(tokenRoot, amount);

        uint128 amount1 = 0;
        uint128 amount2 = 0;

        bool isT1 = (tokenRoot == token1);
        if ( isT1 ) {
            amount1 = tokenAmount - si.swappableTokenAmount;
            amount2 = si.targetTokenAmount;
        } else {
            amount1 = si.targetTokenAmount;
            amount2 = tokenAmount - si.swappableTokenAmount;
        }

        (provided1, provided2, toMint) = _provideLiquidity(amount1, amount2, senderPubkey, senderAddress, lpWallet);
        inputTokenRemainder = isT1 ? (amount1 - provided1) : (amount2 - provided2);
    }

    /**
     * Internal function for liquidity providing using both tokens
     * @notice This function changes LP volumes
     * @param amount1 Amount of first token provided by user
     * @param amount2 Amount of second token provided by user
     * @param senderPubkey Public key of user that provides liquidity
     * @param senderAddress Address of TON wallet of user 
     * @param lpWallet Address of user's LP wallet
     */
    function _provideLiquidity(uint128 amount1, uint128 amount2, uint256 senderPubkey, address senderAddress, address lpWallet)
        private
        returns (uint128 provided1, uint128 provided2, uint256 toMint)
    {
        (provided1, provided2, toMint) = _calculateProvidingLiquidityInfo(amount1, amount2);
        lps[T1] += provided1;
        lps[T2] += provided2;
        liquidityTokensMinted += toMint;

        /*
            If user doesn't have wallet for LP tokens - we create one for user
        */
        if (lpWallet.value == 0) {
            IRootTokenContract(lpTokenRootAddress).deployWallet{
                value: msg.value/2,
                flag: 0
            }(uint128(toMint), msg.value/4, senderPubkey, senderAddress, senderAddress);
        } else {
            IRootTokenContract(lpTokenRootAddress).mint(uint128(toMint), lpWallet);
        }
    }

    /**
     * Function to return tokens not used for lqiuidity providing
     * @param providedByUser Amount of tokens transferred by user
     * @param providedAmount Amount of tokens provided to LP
     * @param tokenWallet Address of swap pair wallet that received tokens 
     * @param senderTokenWallet Address of user's token wallet
     * @param original_gas_to Where to return remaining gas
     * @param payloadTB Payload attached to message
     */
    function _tryToReturnProvidingTokens(
        uint128 providedByUser, uint128 providedAmount, address tokenWallet, address senderTokenWallet, address original_gas_to, TvmBuilder payloadTB
    ) private pure {   
        uint128 amount = providedByUser - providedAmount;
        if (amount > 0) {
            _sendTokens(tokenWallet, senderTokenWallet, amount, original_gas_to, false, payloadTB.toCell());
        }
    }

    //============Withdraw LP tokens functionality============

    /**
     * Function to withdraw tokens from liquidity pool
     * @notice To interact with swap pair you need to send TIP-3 tokens with specific payload and TONs
     * @dev This function can be called only by contract itself
     * @param tokenAmount Amount of LP tokens burnt/transferred
     * @param lpwi Information used for token withdrawal. Contains root addresses and user's wallets
     * @param walletAddress Address of user's LP wallet
     * @param tokensBurnt If tokens were burnt or just transferred
     * @param send_gas_to Where to send remaining gas
     */
    function _withdrawTokensFromLP(
        uint128 tokenAmount, 
        LPWithdrawInfo lpwi,
        address walletAddress,
        bool tokensBurnt,
        address send_gas_to
    ) external onlySelf {
        require(
            _checkIsLiquidityProvided(),
            SwapPairErrors.NO_LIQUIDITY_PROVIDED
        );

        (uint128 withdrawed1, uint128 withdrawed2, uint256 burned) = _calculateWithdrawingLiquidityInfo(tokenAmount);

        if (withdrawed1 != 0 && withdrawed2 != 0) {
            lps[T1] -= withdrawed1;
            lps[T2] -= withdrawed2;

            if (!tokensBurnt) {
                _burnTransferredLPTokens(tokenAmount);
            }

            liquidityTokensMinted -= tokenAmount;

            emit WithdrawLiquidity(burned, withdrawed1, withdrawed2);
            SwapPairContract(this)._transferTokensToWallets{
                flag: 64,
                value: 0
            }(lpwi, withdrawed1, withdrawed2, send_gas_to);
        } else {
            _fallbackWithdrawLP(walletAddress, tokenAmount, tokensBurnt);
        }
    }

    /**
     * Function to withdraw tokens from liquidity pool in one token
     * @notice To interact with swap pair you need to send TIP-3 tokens with specific payload and TONs
     * @dev This function can be called only by contract itself
     * @param tokenAmount Amount of LP tokens burnt/transferred
     * @param tokenRoot Address of desired TIP-3 token
     * @param tokenWallet Address of tip-3 wallet to transfer tokens to
     * @param lpWalletAddress Address of user's LP token wallet
     * @param tokensBurnt If tokens were burnt or just transferred
     * @param send_gas_to Where to send remaining gas
     */
    function _withdrawOneTokenFromLP  (
        uint128 tokenAmount, 
        address tokenRoot,
        address tokenWallet, 
        address lpWalletAddress,
        bool tokensBurnt,
        address send_gas_to
    ) external onlySelf {
        // TODO: рефакторинг: общая часть с функцией _withdrawTokensFromLP, возможно стоит вынести в отдельный метод
        require(
            _checkIsLiquidityProvided(),
            SwapPairErrors.NO_LIQUIDITY_PROVIDED
        );

        (uint128 withdrawed1, uint128 withdrawed2, uint256 burned) = _calculateWithdrawingLiquidityInfo(tokenAmount);

        if (withdrawed1 == 0 || withdrawed2 == 0) {
            _fallbackWithdrawLP(lpWalletAddress, tokenAmount, tokensBurnt);
            return;
        }

        lps[T1] -= withdrawed1;
        lps[T2] -= withdrawed2;

        if (!tokensBurnt) {
            _burnTransferredLPTokens(tokenAmount);
        }

        liquidityTokensMinted -= tokenAmount;

        emit WithdrawLiquidity(burned, withdrawed1, withdrawed2);


        bool isT1 = tokenRoot == token1;
        address swapableToken = isT1 ? token2 : token1;
        uint128 swapableAmount = isT1 ? withdrawed2 : withdrawed1;
        SwapInfo si = _swap(swapableToken, swapableAmount);
        uint128 resultAmount = si.targetTokenAmount + (isT1 ? withdrawed1 : withdrawed2);
        
        address w = tokenRoot == token1 ? tokenWallets[T1] : tokenWallets[T2];
        TvmCell payload;
        _sendTokens(w, tokenWallet, resultAmount, send_gas_to, true, payload);
    }

    /**
     * Function to transfer multiple tokens to wallets
     * @dev This function can be called only by contract itself
     * @param lpwi Struct with information for token withdraw
     * @param t1Amount Amount of first token to transfer
     * @param t2Amount Amount of second token to transfer
     * @param send_gas_to Where to send remaining gas
     */
    function _transferTokensToWallets(
        LPWithdrawInfo lpwi, uint128 t1Amount, uint128 t2Amount, address send_gas_to
    ) external view onlySelf {
        // TODO: рефакторинг: изменить названия
        // TODO: рефакторинг: переделать функцию
        bool t1ist1 = lpwi.tr1 == token1; // смотрим, не была ли перепутана последовательность адресов рут-контрактов
        address w1 = t1ist1 ? tokenWallets[0] : tokenWallets[1];
        address w2 = t1ist1 ? tokenWallets[1] : tokenWallets[0];
        uint128 t1a = t1ist1 ? t1Amount : t2Amount;
        uint128 t2a = t1ist1 ? t2Amount : t1Amount;

        TvmCell payload = _createWithdrawResultPayload(w1, t1a, w2, t2a);
        ITONTokenWallet(w1).transfer{value: msg.value/3}(lpwi.tw1, t1a, 0, send_gas_to, true, payload);
        _sendTokens(w2, lpwi.tw2, t2a, send_gas_to, true, payload);
    }

    /**
     * Fallback function if something went wrong during liquidity withdrawal
     * @param walletAddress Address of user's LP token wallet
     * @param tokensAmount Amount of LP tokens that were transferred/burnt
     * @param mintRequired Were tokens burnt or just transferred
     */
    function _fallbackWithdrawLP(
        address walletAddress, uint128 tokensAmount, bool mintRequired
    ) private view  {
        if (mintRequired) {
            IRootTokenContract(lpTokenRootAddress).mint{
                value: 0,
                flag: 64
            }(tokensAmount, walletAddress);
        } else {
            TvmBuilder payload;
            payload.store(sumIsTooLowForLPTokenWithdraw);
            _sendTokens(lpTokenWalletAddress, walletAddress, tokensAmount, address(this), true, payload.toCell());
        }
    }

    /**
     * Burn transferred LP tokens
     * @param tokenAmount Amount of LP tokens to burn
     */
    function _burnTransferredLPTokens(uint128 tokenAmount) private view  {
        TvmCell payload;
        IBurnableByOwnerTokenWallet(lpTokenWalletAddress).burnByOwner{
            value: msg.value/4
        }(tokenAmount, 0, address(this), address(this), payload);
    }

    //============Callbacks============

    /**
     * Function that is called when TIP-3 wallet receives tokens
     * @dev This function can only be called by swap pair's TIP-3 wallets
     * @notice This function is just a router for parsing initial payload and guessing which function to call
     * @param token_wallet Address of wallet that received tokens 
     * @param token_root Root contract address of wallet
     * @param amount Amount of tokens transferred
     * @param sender_public_key Sender's public key
     * @param sender_address Sender's TON wallet address
     * @param sender_wallet Sender's token wallet address
     * @param original_gas_to Original gas_back address
     * @param updated_balance Balance of wallet after transfer
     * @param payload Payload attached to message 
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
    ) override public onlyOwnWallet {
        TvmSlice tmp = payload.toSlice();
        (UnifiedOperation uo) = tmp.decode(UnifiedOperation);
        TvmBuilder failTB;
        failTB.store(unknownOperationIdorWrongPayload);

        // TODO: рефакторинг: разрулить if/else во что-то более нормальное
        if (msg.sender != lpTokenWalletAddress) {
            if (uo.operationId == SwapPairConstants.SwapPairOperation) {
                SwapPairContract(this)._externalSwap{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, msg.sender, token_root, amount, sender_wallet, original_gas_to
                );
            } 
            else if (uo.operationId == SwapPairConstants.ProvideLiquidity) {
                SwapPairContract(this)._externalProvideLiquidity{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, msg.sender, sender_public_key, amount, sender_wallet, sender_address, original_gas_to
                );
            } 
            else if (uo.operationId == SwapPairConstants.ProvideLiquidityOneToken) {
                SwapPairContract(this)._externalProvideLiquidityOneToken{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, token_root, msg.sender, sender_public_key, amount, sender_wallet, sender_address, original_gas_to
                );
            } 
            else {
                _sendTokens(msg.sender, sender_wallet, amount, original_gas_to, true, failTB.toCell());
            }
        } 
        else {
            if (uo.operationId == SwapPairConstants.WithdrawLiquidity) {
                SwapPairContract(this)._externalWithdrawLiquidity{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, amount, sender_wallet, original_gas_to, false
                );
            } else if (uo.operationId == SwapPairConstants.WithdrawLiquidityOneToken) {
                SwapPairContract(this)._externalWithdrawLiquidityOneToken{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, amount, sender_wallet, original_gas_to, false
                );
            } else {
                _sendTokens(msg.sender, sender_wallet, amount, original_gas_to, true, failTB.toCell());
            }
        }
    }

    /**
     * Function that is called when LP tokens are burnt
     * @dev This function can only be called by LP token root contract
     * @notice This function is just a router for parsing initial payload and guessing which function to call
     * @param tokensBurnt Amount of burnt tokens
     * @param payload Payload attached to burnt tokens
     * @param sender_public_key Public key of user that burnt tokens
     * @param sender_address Address of user's TON wallet
     * @param wallet_address Address of user's LP token wallet
     * @param send_gas_to Original gas_back address
     */
    function burnCallback(
        uint128 tokensBurnt,
        TvmCell payload,
        uint256 sender_public_key,
        address sender_address,
        address wallet_address,
        address send_gas_to
    ) external view onlyLpTokenRoot {
        TvmSlice tmp = payload.toSlice();
        (UnifiedOperation uo) = tmp.decode(UnifiedOperation);

        if (wallet_address == lpTokenWalletAddress) {
            return;
        }

        if (uo.operationId == SwapPairConstants.WithdrawLiquidity) {
            SwapPairContract(this)._externalWithdrawLiquidity{
                flag: 64,
                value: 0
            }(
                uo.operationArgs, tokensBurnt, wallet_address, send_gas_to, true
            );
        }
        else if (uo.operationId == SwapPairConstants.WithdrawLiquidityOneToken) {
                SwapPairContract(this)._externalWithdrawLiquidity{
                flag: 64,
                value: 0
            }(
                uo.operationArgs, tokensBurnt, wallet_address, send_gas_to, true
            );
        }
    }

    //============External LP functions============

    /**
     * Function for token swap. This is top-level wrapper.
     * @dev This function can be called only by contract itself
     * @param args Decoded payload from received message
     * @param tokenReceiver TIP-3 wallet that received tokens
     * @param token_root Root contract address of transferred token
     * @param amount Amount of transferred tokens
     * @param sender_wallet Address of user's TIP-3 wallet
     * @param original_gas_to Where to send remaining gas
     */
    function _externalSwap(
        TvmCell args, address tokenReceiver, address token_root, uint128 amount, address sender_wallet, address original_gas_to
    ) 
        external 
        onlySelf 
    {
        TvmSlice tmpArgs = args.toSlice();
        (bool isPayloadOk, address transferTokensTo) = _checkAndDecompressSwapPayload(tmpArgs);
        TvmBuilder failTB;
        
        if ( !isPayloadOk ){
            failTB.store(wrongPayloadFormatMessage);
            _sendTokens(tokenReceiver, sender_wallet, amount, original_gas_to, true, failTB.toCell());

            return;
        }

        if ( !_checkIsLiquidityProvided() ){
            failTB.store(noLiquidityProvidedMessage);
            _sendTokens(tokenReceiver, sender_wallet, amount, original_gas_to, true, failTB.toCell());

            return;
        }

        SwapInfo si = _swap(token_root, amount);
        if (si.targetTokenAmount != 0) {
            emit Swap(token_root, _getOppositeToken(token_root), si.swappableTokenAmount, si.targetTokenAmount, si.fee);

            address tokenWallet = tokenReceiver == tokenWallets[T1] ? tokenWallets[T2] : tokenWallets[T1];
            _sendTokens(tokenWallet, transferTokensTo, si.targetTokenAmount, original_gas_to, true, _createSwapPayload(si));
        } else {
            _sendTokens(tokenReceiver, sender_wallet, amount, original_gas_to, true, _createSwapFallbackPayload());
        }
    }

    /**
     * Function for liquidity providing. This is top-level wrapper.
     * @dev This function can be called only by contract itself
     * @param args Decoded payload from received message
     * @param tokenReceiver TIP-3 wallet that received tokens
     * @param amount Amount of transferred tokens
     * @param sender_wallet Address of user's TIP-3 wallet
     * @param sender_address Address of user's TON wallet
     * @param original_gas_to Where to send remaining gas
     */
    function _externalProvideLiquidity(
        TvmCell args, 
        address tokenReceiver, 
        uint256 sender_public_key, 
        uint128 amount, 
        address sender_wallet, 
        address sender_address,
        address original_gas_to
    ) 
        external 
        onlySelf 
    {
        TvmSlice tmpArgs = args.toSlice();
        (bool isPayloadOk, address lpWallet) = _checkAndDecompressProvideLiquidityPayload(tmpArgs);
        TvmBuilder failTB;

        if ( !isPayloadOk ) {
            failTB.store(wrongPayloadFormatMessage);
            _sendTokens(tokenReceiver, sender_wallet, amount, original_gas_to, false, failTB.toCell());

            return;            
        }

        // TODO: рефакторинг: разнести в разные функции создание записи о пользователе
        TvmBuilder tb;
        tb.store(sender_public_key, sender_address);
        uint256 uniqueID = tvm.hash(tb.toCell());

        if (!lpInputTokensInfo.exists(uniqueID)) {
            LPProvidingInfo _l = LPProvidingInfo(
                sender_address,
                sender_public_key,
                address.makeAddrStd(0, 0),
                0,
                address.makeAddrStd(0, 0),
                0                           
            );
            lpInputTokensInfo.add(uniqueID, _l);
        }

        // TODO: рефокторинг: изменение хранящихся данных
        LPProvidingInfo lppi = lpInputTokensInfo[uniqueID];

        if (tokenReceiver == tokenWallets[0]) {
            lppi.a1 += amount;
            lppi.w1 = sender_wallet;
        }

        if (tokenReceiver == tokenWallets[1]) {
            lppi.a2 += amount;
            lppi.w2 = sender_wallet;
        }

        if (lppi.a1 == 0 || lppi.a2 == 0) {
            lpInputTokensInfo[uniqueID] = lppi;
            address(sender_wallet).transfer({value: 0, flag: 64});
        }
        else {
            (uint128 rtp1, uint128 rtp2, ) = _provideLiquidity(lppi.a1, lppi.a2, sender_public_key, sender_address, lpWallet);
            emit ProvideLiquidity(liquidityTokensMinted, rtp1, rtp2);

            TvmBuilder payloadTB;
            payloadTB.store(lppi.a1, rtp1, lppi.a2, rtp2);

            _tryToReturnProvidingTokens(lppi.a1, rtp1, tokenWallets[T1], lppi.w1, original_gas_to, payloadTB);
            _tryToReturnProvidingTokens(lppi.a2, rtp2, tokenWallets[T2], lppi.w2, original_gas_to, payloadTB);

            delete lpInputTokensInfo[uniqueID];
        } 
    }

    // TODO: Антон: проверка провайдинга ликвидности по одному токену
    /**
     * Function for liquidity providing using one token. This is top-level wrapper.
     * @dev This function can be called only by contract itself
     * @param args Decoded payload from received message
     * @param tokenRoot Address of TIP-3 root contract
     * @param tokenReceiver TIP-3 wallet that received tokens
     * @param amount Amount of transferred tokens
     * @param sender_wallet Address of user's TIP-3 wallet
     * @param sender_address Address of user's TON wallet
     * @param original_gas_to Where to send remaining gas
     */
    function _externalProvideLiquidityOneToken(        
        TvmCell args, 
        address tokenRoot,
        address tokenReceiver, 
        uint256 sender_public_key, 
        uint128 amount, 
        address sender_wallet, 
        address sender_address,
        address original_gas_to
    ) 
        external 
        onlySelf 
    {
        TvmSlice tmpArgs = args.toSlice();
        (bool isPayloadOk, address lpWallet) = _checkAndDecompressProvideLiquidityOneTokenPayload(tmpArgs);
        TvmBuilder failTB;

        if ( !isPayloadOk ){
            failTB.store(wrongPayloadFormatMessage);
            _sendTokens(tokenReceiver, sender_wallet, amount, original_gas_to, false, failTB.toCell());
            return;
        }
        if ( !_checkIsLiquidityProvided() ){
            failTB.store(noLiquidityProvidedMessage);
            _sendTokens(tokenReceiver, sender_wallet, amount, original_gas_to, false, failTB.toCell());

            return;
        }

        (uint128 provided1, uint128 provided2, , uint128 remainder) = _provideLiquidityOneToken(tokenRoot, amount, sender_public_key, sender_address, lpWallet);

        if (provided2 == 0 || provided1 == 0)
            remainder = amount;
        else
            emit ProvideLiquidity(liquidityTokensMinted, provided1, provided2);

        TvmBuilder payloadTB;
        payloadTB.store(tokenReceiver, amount, remainder, provided1, provided2);

        _tryToReturnProvidingTokens(remainder, 0, tokenReceiver, sender_wallet, original_gas_to, payloadTB);
    }

    /**
     * Function for liquidity withdrawing. This is top-level wrapper.
     * @dev This function can be called only by contract itself
     * @param args Decoded payload from received message
     * @param amount Amount of transferred tokens
     * @param sender_wallet Address of user's TIP-3 wallet
     * @param original_gas_to Where to send remaining gas
     * @param tokensBurnt Were tokens burnt or jsut transferred
     */
    function _externalWithdrawLiquidity(
        TvmCell args, 
        uint128 amount, 
        address sender_wallet, 
        address original_gas_to, 
        bool tokensBurnt
    ) external view onlySelf {
        TvmSlice tmpArgs = args.toSlice();
        (bool isPayloadOk, LPWithdrawInfo lpwi) = _checkAndDecompressWithdrawLiquidityPayload(tmpArgs);

        if ( !isPayloadOk ) {
            if ( tokensBurnt ) {
                IRootTokenContract(lpTokenRootAddress).mint{
                    flag: 64,
                    value: 0
                }(amount, sender_wallet);
            } else {
                TvmBuilder failTB;
                failTB.store(wrongPayloadFormatMessage);
                _sendTokens(lpTokenWalletAddress, sender_wallet, amount, original_gas_to, false, failTB.toCell());
            }
            return;
        }

        SwapPairContract(this)._withdrawTokensFromLP{flag: 64, value: 0}(amount, lpwi, sender_wallet, tokensBurnt, original_gas_to);
    }

    /**
     * Function for liquidity withdrawing. This is top-level wrapper.
     * @dev This function can be called only by contract itself
     * @param args Decoded payload from received message
     * @param amount Amount of transferred tokens
     * @param sender_wallet Address of user's TIP-3 wallet
     * @param original_gas_to Where to send remaining gas
     * @param tokensBurnt Were tokens burnt or jsut transferred
     */
    function _externalWithdrawLiquidityOneToken(
        TvmCell args, 
        uint128 amount, 
        address sender_wallet, 
        address original_gas_to, 
        bool tokensBurnt
    ) external view onlySelf {
        TvmSlice tmpArgs = args.toSlice();

        (bool isPayloadOk, address tokenRoot, address userWallet) = _checkAndDecompressWithdrawLiquidityOneTokenPayload(tmpArgs);

        if ( !isPayloadOk ) {
            if (tokensBurnt) {
                IRootTokenContract(lpTokenRootAddress).mint{
                    flag: 64,
                    value: 0
                }(amount, sender_wallet);
            } else {
                TvmBuilder failTB;
                failTB.store(wrongPayloadFormatMessage);
                _sendTokens(lpTokenWalletAddress, sender_wallet, amount, original_gas_to, false, failTB.toCell());
            }
            return;
        }

        SwapPairContract(this)._withdrawOneTokenFromLP{
            flag: 64, value: 0
        } (amount, tokenRoot, userWallet, sender_wallet, tokensBurnt, original_gas_to);
        return;

    }

    //============Payload manipulation functions============

    /**
     * Check and decompress payload for swap operation
     * @param tmpArgs Received arguments
     */
    function _checkAndDecompressSwapPayload(TvmSlice tmpArgs) private pure returns (bool isPayloadOk, address transferTokensTo) {
        bool isSizeOk = tmpArgs.hasNBitsAndRefs(SwapPairConstants.SwapOperationBits, SwapPairConstants.SwapOperationRefs);
        transferTokensTo = _decompressSwapPayload(tmpArgs);
        bool isContentOk = transferTokensTo.value != 0;
        isPayloadOk = isSizeOk && isContentOk;
    }

    /**
     * Check and decompress payload for liquidity providing operation
     * @param tmpArgs Received arguments
     */
    function _checkAndDecompressProvideLiquidityPayload(TvmSlice tmpArgs) private pure returns (bool isPayloadOk, address lpTokenAddress) {
        bool isSizeOk = tmpArgs.hasNBitsAndRefs(SwapPairConstants.ProvideLiquidityBits, SwapPairConstants.ProvideLiquidityRefs);
        lpTokenAddress = _decompressProvideLiquidityPayload(tmpArgs);
        bool isContentOk = lpTokenAddress.value != 0 || lpTokenAddress.value == 0;
        isPayloadOk = isSizeOk && isContentOk;
    }

    /**
     * Check and decompress payload for liquidity withdrawing operation
     * @param tmpArgs Received arguments
     */
    function _checkAndDecompressWithdrawLiquidityPayload(TvmSlice tmpArgs) private pure returns (bool isPayloadOk, LPWithdrawInfo lpwi) {
        bool isSizeOk = tmpArgs.hasNBitsAndRefs(SwapPairConstants.WithdrawOperationBits, SwapPairConstants.WithdrawOperationRefs);
        lpwi = _decompressWithdrawLiquidityPayload(tmpArgs);
        bool isContentOk = lpwi.tr1.value != 0 && lpwi.tr2.value != 0 && lpwi.tw1.value != 0 && lpwi.tw2.value != 0;
        isPayloadOk = isSizeOk && isContentOk;
    }

    /**
     * Check and decompress payload for liquidity providing using one token operation
     * @param tmpArgs Received arguments
     */
    function _checkAndDecompressProvideLiquidityOneTokenPayload(TvmSlice tmpArgs) private pure returns  (bool isPayloadOk, address lpTokenAddress) {
        bool isSizeOk = tmpArgs.hasNBitsAndRefs(SwapPairConstants.ProvideLiquidityOneBits, SwapPairConstants.ProvideLiquidityOneRefs);
        lpTokenAddress = _decompressProvideLiquidityOneTokenPayload(tmpArgs);
        bool isContentOk = lpTokenAddress.value != 0 || lpTokenAddress.value == 0;
        isPayloadOk = isSizeOk && isContentOk;
    }

    /**
     * Check and decompress payload for liquidity withdrawing using one token operation
     * @param tmpArgs Received arguments
     */
    function _checkAndDecompressWithdrawLiquidityOneTokenPayload(TvmSlice tmpArgs) private pure returns (bool isPayloadOk, address tokenRoot, address userWallet) {
        bool isSizeOk = tmpArgs.hasNBitsAndRefs(SwapPairConstants.WithdrawOneOperationBits, SwapPairConstants.WithdrawOneOperationRefs);
        (tokenRoot, userWallet) = _decompresskWithdrawLiquidityOneTokenPayload(tmpArgs);
        bool isContentOk = (tokenRoot.value != 0) && (userWallet.value != 0);
        isPayloadOk = isSizeOk && isContentOk;
    }

    /**
     * Decompress payload for swap operation
     * @param tmpArgs Received arguments
     */
    function _decompressSwapPayload(TvmSlice tmpArgs) private pure returns(address) {
        (address transferTokensTo) = tmpArgs.decode(address);
        return transferTokensTo;
    }

    /**
     * Decompress payload for liquidity providing operation
     * @param tmpArgs Received arguments
     */
    function _decompressProvideLiquidityPayload(TvmSlice tmpArgs) private pure returns (address) {
        address lpWallet = tmpArgs.decode(address);
        return lpWallet;
    }

    /**
     * Decompress payload for liquidity withdrawing operation
     * @param tmpArgs Received arguments
     */
    function _decompressWithdrawLiquidityPayload(TvmSlice tmpArgs) private pure returns (LPWithdrawInfo) {
        LPWithdrawInfo lpwi;
        (lpwi.tr1, lpwi.tw1) = tmpArgs.decode(address, address);
        TvmSlice secondPart = tmpArgs.loadRefAsSlice();
        (lpwi.tr2, lpwi.tw2) = secondPart.decode(address, address);
        return lpwi;
    }

    /**
     * Decompress payload for liquidity providing using one token operation
     * @param tmpArgs Received arguments
     */
    function _decompressProvideLiquidityOneTokenPayload(TvmSlice tmpArgs) private pure returns (address) {
        address lpWallet = tmpArgs.decode(address);
        return lpWallet;
    }

    /**
     * Decompress payload for liquidity withdrawing using one token operation
     * @param tmpArgs Received arguments
     */
    function _decompresskWithdrawLiquidityOneTokenPayload(TvmSlice tmpArgs) private pure returns (address tokenRoot, address userWallet) {
        (tokenRoot, userWallet) = tmpArgs.decode(address, address);
    }

    /**
     * Create fail payload for swap operation 
     */
    function _createSwapFallbackPayload() private pure returns (TvmCell) {
        TvmBuilder tb;
        tb.store(sumIsTooLowForSwap);
        return tb.toCell();
    }

    /**
     * Create payload with results of withdraw operation
     * @param w1 Address of token wallet 1
     * @param t1a Amount of tokens transferred to w1
     * @param w2 Address of token wallet 2
     * @param t2a Amount of tokens transferred to w2
     */
    function _createWithdrawResultPayload(address w1, uint128 t1a, address w2, uint128 t2a) private pure returns (TvmCell) {
        TvmBuilder payloadB;
        payloadB.store(w1, t1a, w2, t2a);
        return payloadB.toCell();
    }

    /**
     * Create payload for swap operation
     */
    function createSwapPayload(address sendTokensTo) external override pure returns (TvmCell) {
        TvmBuilder tb; TvmBuilder argsBuilder;
        argsBuilder.store(sendTokensTo);
        tb.store(UnifiedOperation(SwapPairConstants.SwapPairOperation, argsBuilder.toCell()));
        return tb.toCell();
    }

    /**
     * Create payload for liquidity providing operation
     * @param tip3Address Address of user's LP token wallet
     */
    function createProvideLiquidityPayload(address tip3Address) external override pure returns (TvmCell) {
        TvmBuilder tb; TvmBuilder argsBuilder;
        argsBuilder.store(tip3Address);
        tb.store(UnifiedOperation(SwapPairConstants.ProvideLiquidity, argsBuilder.toCell()));
        return tb.toCell();
    }

    /**
     * Create payload for liquidity providing using one token operation
     * @param tip3Address Address of user's LP token wallet
     */
    function createProvideLiquidityOneTokenPayload(address tip3Address) external override pure returns (TvmCell) {
        TvmBuilder tb; TvmBuilder argsBuilder;
        argsBuilder.store(tip3Address);
        tb.store(UnifiedOperation(SwapPairConstants.ProvideLiquidityOneToken, argsBuilder.toCell()));
        return tb.toCell();
    }

    /**
     * Create payload for liquidity withdrawing operation
     * @param tokenRoot1 Root contract TIP-3 address of first user's wallet
     * @param tokenWallet1 Address of first user's TIP-3 wallet
     * @param tokenRoot1 Root contract TIP-3 address of second user's wallet
     * @param tokenWallet1 Address of second user's TIP-3 wallet
     */
    function createWithdrawLiquidityPayload(
        address tokenRoot1,
        address tokenWallet1,
        address tokenRoot2,
        address tokenWallet2
    ) external override pure returns (TvmCell) {
        TvmBuilder tb; TvmBuilder payloadFirstHalf; TvmBuilder payloadSecondHalf;
        payloadFirstHalf.store(tokenRoot1, tokenWallet1); payloadSecondHalf.store(tokenRoot2, tokenWallet2);
        payloadFirstHalf.storeRef(payloadSecondHalf);
        tb.store(UnifiedOperation(SwapPairConstants.WithdrawLiquidity, payloadFirstHalf.toCell()));
        return tb.toCell();
    }

    /**
     * Create payload for liquidity withdrawing using one token operation
     * @param tokenRoot Root contract TIP-3 address of user's wallet
     * @param userWallet Address of user's TIP-3 wallet
     */
    function createWithdrawLiquidityOneTokenPayload(address tokenRoot, address userWallet) external override pure returns (TvmCell) 
    {
        TvmBuilder tb; TvmBuilder argsBuilder;
        argsBuilder.store(tokenRoot, userWallet);
        tb.store(UnifiedOperation(SwapPairConstants.WithdrawLiquidityOneToken, argsBuilder.toCell()));
        return tb.toCell();
    }

    //============Upgrade swap pair code part============

    /**
     * Function to update swap pair code
     * @dev This function can only be called by swap pair root contract
     * @param newCode New swap pair's code
     * @param newCodeVersion New swap pair's code version
     */
    function updateSwapPairCode(TvmCell newCode, uint32 newCodeVersion) override external onlySwapPairRoot {
        require(
            newCodeVersion > newCodeVersion, 
            SwapPairErrors.CODE_DOWNGRADE_REQUESTED
        );
        tvm.accept();
        swapPairCodeVersion = newCodeVersion;

        tvm.setcode(newCode);
        tvm.setCurrentCode(newCode);
        _initializeAfterCodeUpdate();
    }

    /**
     * Function to check if update is required
     * @param newCodeVersion New swap pair's code version
     */
    function checkIfSwapPairUpgradeRequired(uint32 newCodeVersion) override external returns(bool) {
        return newCodeVersion > swapPairCodeVersion;
    }

    /**
     * Function for reinitialization after code update
     */
    function _initializeAfterCodeUpdate() private {
        //code will be added when required
    }

    //============HELPERS============

    /**
     * Send tokens to specified TIP-3 wallet
     * @param walletToUse Swap pair's wallet to use
     * @param destinationAddress Address to transfer tokens to
     * @param amount Amount of tokens to transfer
     * @param gasBackAddress Address to return gas to
     * @param notify If transfer should notify receiver
     * @param payload Payload to attach to message
     */
    function _sendTokens(
        address walletToUse, address destinationAddress, uint128 amount, address gasBackAddress, bool notify, TvmCell payload
    ) private pure {
        ITONTokenWallet(walletToUse).transfer{
                value: 0, 
                flag: 64
        }(destinationAddress, amount, 0, gasBackAddress, notify, payload);
    }

    /**
     * Create swap payload in case of successfull swap operation
     * @param si Result of swap pair operation
     */
    function _createSwapPayload(SwapInfo si) private pure returns(TvmCell) {
        TvmBuilder tb;
        tb.store(si);
        return tb.toCell();
    }
 
    /**
     * Call root contract to notify about initialization
     */
    function _swapPairInitializedCall() 
        private
        view
    {
        tvm.accept();
        SwapPairInfo spi = _constructSwapPairInfo();
        IRootContractCallback(swapPairRootContract).swapPairInitializedCallback{
            value: 0.1 ton,
            bounce: true
        }(spi);
    }

    /**
     * Construct swap pair info struct
     */
    function _constructSwapPairInfo()
        private
        view
        
        returns (SwapPairInfo)
    {
        SwapPairInfo spi = SwapPairInfo(
            swapPairRootContract,
            token1, token2, lpTokenRootAddress,
            tokenWallets[0], tokenWallets[1], lpTokenWalletAddress,
            creationTimestamp,
            address(this),
            swapPairID, swapPairCodeVersion,
            LPTokenName
        );
        return spi;
    }

    /**
     * Get token position
     * @param _token Address of token root
     */
    function _getTokenPosition(address _token) 
        private
        view
        tokenExistsInPair(_token)
        returns(uint8)
    {
        return tokenPositions[_token];
    }

    /**
     * Get opposite TIP-3 token root address
     * @param _token Address of token root
     */
    function _getOppositeToken(address _token)
        private
        view
        returns(address)
    {
        return _token == token1? token2 : token1;
    }

    /**
     * Check if liquidity is already provided
     */
    function _checkIsLiquidityProvided() private view returns (bool) {
        return lps[T1] > 0 && lps[T2] > 0;
    }

    /**
     * Calculate sqrt of given number
     * @param x Number to calculate sqrt of
     */
    function _sqrt(uint256 x) private pure returns(uint256){
        uint256 z = (x+1) / 2;
        uint256 res = x;

        while(z < res) {
            res = z;
            z = ((x/z) + z) / 2;
        }
        return res;
    }

    //============Modifiers============

    /**
     * Check if swap pair is initialized
     */
    modifier initialized() {
        require(initializedStatus == SwapPairConstants.contractFullyInitialized, SwapPairErrors.CONTRACT_NOT_INITIALIZED);
        _;
    }

    /**
     * Check if msg.sender is known TIP-3 root
     */
    modifier onlyTokenRoot() {
        require(
            msg.sender == token1 || msg.sender == token2 || msg.sender == lpTokenRootAddress,
            SwapPairErrors.CALLER_IS_NOT_TOKEN_ROOT
        );
        _;
    }

    /**
     * Check if msg.sender is LP token root
     */
    modifier onlyLpTokenRoot() {
        require(
            msg.sender == lpTokenRootAddress,
            SwapPairErrors.CALLER_IS_NOT_LP_TOKEN_ROOT
        );
        _;
    }

    /**
     * Check if msg.sender is TIP-3 deployer contract
     */
    modifier onlyTIP3Deployer() {
        require(
            msg.sender == tip3Deployer,
            SwapPairErrors.CALLER_IS_NOT_TIP3_DEPLOYER
        );
        _;
    }

    /**
     * Check if msg.sender is swap pair's TIP-3 wallet 
     */
    modifier onlyOwnWallet() {
        bool b1 = tokenWallets.exists(T1) && msg.sender == tokenWallets[T1];
        bool b2 = tokenWallets.exists(T2) && msg.sender == tokenWallets[T2];
        bool b3 = msg.sender == lpTokenWalletAddress;
        require(
            b1 || b2 || b3,
            SwapPairErrors.CALLER_IS_NOT_TOKEN_WALLET
        );
        _;
    }

    /**
     * Check if msg.sender is swap pair itself
     */
    modifier onlySelf() {
        require(msg.sender == address(this));
        _;
    }

    /**
     * Check if msg.sender is swap pair root contract
     */
    modifier onlySwapPairRoot() {
        require(
            msg.sender == swapPairRootContract,
            SwapPairErrors.CALLER_IS_NOT_SWAP_PAIR_ROOT
        );
        _;
    }
    
    /**
     * Check if given TIP-3 token root address is known to pair
     * @param _token TIP-3 token root address 
     */
    modifier tokenExistsInPair(address _token) {
        require(
            tokenPositions.exists(_token),
            SwapPairErrors.INVALID_TOKEN_ADDRESS
        );
        _;
    }

    //============Too big for modifier too small for function============

    /**
     * Check if two nubmers are not zeros
     * @param _amount1 first number
     * @param _amount2 second number
     */
    function notZeroLiquidity(uint128 _amount1, uint128 _amount2) private pure returns(bool) {
        return _amount1 > 0 && _amount2 > 0;
    }
}