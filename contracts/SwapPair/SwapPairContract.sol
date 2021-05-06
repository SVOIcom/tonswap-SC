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

// TODO: добавить комментарии чтобы было понятно что за параметры

contract SwapPairContract is ITokensReceivedCallback, ISwapPairInformation, IUpgradeSwapPairCode, ISwapPairContract {
    address static token1;
    address static token2;
    uint    static swapPairID;

    uint32  swapPairCodeVersion = 1;
    uint256 swapPairDeployer;
    address swapPairRootContract;
    address tip3Deployer;

    address lpTokenRootAddress;
    address lpTokenWalletAddress;

    uint128 constant feeNominator = 997;
    uint128 constant feeDenominator = 1000;

    uint256 liquidityTokensMinted = 0;

    mapping(uint8 => address) tokens;
    mapping(address => uint8) tokenPositions;

    //Deployed token wallets addresses
    mapping(uint8 => address) tokenWallets;

    //Liquidity providers info for security reasons
    mapping(uint256 => LPProvidingInfo) lpInputTokensInfo;

    //Liquidity Pools
    mapping(uint8 => uint128) private lps;
    uint256 public kLast; // lps[T1] * lps[T2] after most recent swap


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


    // Waiting for something except for numbers in libraries ...
    OperationSizeRequirements SwapOperationSize = OperationSizeRequirements(
        SwapPairConstants.SwapOperationBits, SwapPairConstants.SwapOperationRefs
    );
    OperationSizeRequirements WithdrawOperationSize = OperationSizeRequirements(
        SwapPairConstants.WithdrawOperationBits, SwapPairConstants.WithdrawOperationRefs
    );
    OperationSizeRequirements WithdrawOperationSizeOneToken = OperationSizeRequirements(
        SwapPairConstants.WithdrawOneOperationBits, SwapPairConstants.WithdrawOneOperationRefs
    );
    OperationSizeRequirements ProvideLiquidityOperationSize = OperationSizeRequirements(
        SwapPairConstants.ProvideLiquidityBits, SwapPairConstants.ProvideLiquidityRefs
    );
    OperationSizeRequirements ProvideLiquidityOperationSizeOneToken = OperationSizeRequirements(
        SwapPairConstants.ProvideLiquidityOneBits, SwapPairConstants.ProvideLiquidityOneRefs
    );

    string constant wrongPayloadFormatMessage = "Received payload is invalid or has wrong format. Use provided functions for payload creation.";
    string constant unknownOperationIdorWrongPayload = "Received payload contains unknow Operation ID or is malformed.";
    string constant sumIsTooLowForSwap = "Provided token amount is not enough for swap. Results in 0 tokens received.";
    string constant noLiquidityProvidedMessage = "No liquidity provided yet. Swaps are forbidden.";
    string constant sumIsTooLowForLPTokenWithdraw = "Provided LP token amount is not enough to withdraw liquidity. Results in 0 tokens received.";
    //============Contract initialization functions============

    constructor(address rootContract, uint spd, address tip3Deployer_) public {
        tvm.accept();
        creationTimestamp = now;
        swapPairRootContract = rootContract;
        swapPairDeployer = spd;
        tip3Deployer = tip3Deployer_;

        tokens[T1] = token1;
        tokens[T2] = token2;
        tokenPositions[token1] = T1;
        tokenPositions[token2] = T2;

        lps[T1] = 0;
        lps[T2] = 0;
        kLast = 0;

        //Deploy tokens wallets
        _deployWallet(token1);
        _deployWallet(token2);

        // Get information about tokens
        _getTIP3Details(token1);
        _getTIP3Details(token2);
    }

    /**
    * Deploy internal wallet. getWalletAddressCallback to get wallet address
    */
    function _deployWallet(address tokenRootAddress) private view {
        tvm.accept();
        IRootTokenContract(tokenRootAddress).deployEmptyWallet{
            value: SwapPairConstants.walletDeployMessageValue
        }(SwapPairConstants.walletInitialBalanceAmount, tvm.pubkey(), address(this), address(this));

        _getWalletAddress(tokenRootAddress);
    }

    function _getWalletAddress(address token) private view {
        tvm.accept();
        IRootTokenContract(token).getWalletAddress{
            value: SwapPairConstants.sendToRootToken, 
            callback: this.getWalletAddressCallback
        }(tvm.pubkey(), address(this));
    }

    /*
    * Deployed wallet address callback
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

        _setWalletsCallbackAddress(walletAddress);

        if (initializedStatus == SwapPairConstants.contractFullyInitialized) {
            _swapPairInitializedCall();
        }
    }

    function _getTIP3Details(address tokenRootAddress) 
        private
        pure
    {
        tvm.accept();
        IRootTokenContract(tokenRootAddress).getDetails{ value: SwapPairConstants.sendToRootToken, bounce: true, callback: this._receiveTIP3Details }();
    }

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

        if (tokenInfoCount == 2) {
            this._prepareDataForTIP3Deploy();
        }
    }

    function _prepareDataForTIP3Deploy()
        external
        view
    {
        tvm.accept();
        string res = string(T1Info.symbol);
        res.append(" <-> ");
        res.append(string(T2Info.symbol));
        this._deployTIP3LpToken(bytes(res), bytes(res));
    }

    function _deployTIP3LpToken(bytes name, bytes symbol)
        external
        view
    {
        tvm.accept();
        ITIP3TokenDeployer(tip3Deployer).deployTIP3Token{
            value: SwapPairConstants.tip3SendDeployGrams,
            bounce: true,
            callback: this._deployTIP3LpTokenCallback
        }(name, symbol, SwapPairConstants.tip3LpDecimals, 0, address(this), SwapPairConstants.tip3SendDeployGrams/2);
    }

    function _deployTIP3LpTokenCallback(address tip3RootContract) 
        external
        onlyTIP3Deployer
    {
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

    function getPairInfo() override external responsible view returns (SwapPairInfo info) {
        return _constructSwapPairInfo();
    }

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

        _SwapInfoInternal si = _getSwapInfo(swappableTokenRoot, swappableTokenAmount);

        return SwapInfo(swappableTokenAmount, si.targetTokenAmount, si.fee);
    }

    function getCurrentExchangeRate()
        override
        external
        responsible
        view
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
        (withdrawedFirstTokenAmount, withdrawedSecondTokenAmount, _b) = _calculateWithdrawingLiquidityInfo(liquidityTokensAmount);
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

    function _calculateProvidingLiquidityInfo(uint128 maxFirstTokenAmount, uint128 maxSecondTokenAmount)
        private
        view
        inline
        returns (uint128 provided1, uint128 provided2, uint256 _minted)
    {
        if ( !_checkIsLiquidityProvided() ) {
            provided1 = maxFirstTokenAmount;
            provided2 = maxSecondTokenAmount;
            _minted = uint256(provided1) * uint256(provided2); // TODO минтиинг
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

    function _calculateWithdrawingLiquidityInfo(uint256 liquidityTokensAmount)
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

    function _swap(address swappableTokenRoot, uint128 swappableTokenAmount)
        private
        returns (SwapInfo)  
    {
        _SwapInfoInternal _si = _getSwapInfo(swappableTokenRoot, swappableTokenAmount);

        if (!notZeroLiquidity(swappableTokenAmount, _si.targetTokenAmount)) {
            return SwapInfo(0, 0, 0);
        }

        uint8 fromK = _si.fromKey;
        uint8 toK = _si.toKey;

        lps[fromK] = _si.newFromPool;
        lps[toK] = _si.newToPool;
        kLast = uint256(_si.newFromPool) * uint256(_si.newToPool);

        return SwapInfo(swappableTokenAmount, _si.targetTokenAmount, _si.fee);
    }

    // TODO: Антон: реализовать функцию добавления ликвидности по одному токену
    function _provideLiquidityOneToken(address tokenRoot, uint128 tokenAmount, uint256 senderPubKey, address senderAddress, address lpWallet) 
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

        // return:
        (provided1, provided2, toMint) =_provideLiquidity(amount1, amount2, senderPubKey, senderAddress, lpWallet);
        inputTokenRemainder = isT1 ? (amount1 - provided1) : (amount2 - provided2);
    }


    // TODO: Антон: реализовать функцию вывода ликвидности по одному токену
    function _withdrawLiquidityOneToken() 
        private 
        pure
        liquidityProvided 
    {

    }   


    function _provideLiquidity(uint128 amount1, uint128 amount2, uint256 senderPubKey, address senderAddress, address lpWallet)
        private
        returns (uint128 provided1, uint128 provided2, uint256 toMint)
    {
        (provided1, provided2, toMint) = _calculateProvidingLiquidityInfo(amount1, amount2);
        lps[T1] += provided1;
        lps[T2] += provided2;
        kLast = uint256(lps[T1]) * uint256(lps[T2]);
        liquidityTokensMinted += toMint;

        if (lpWallet.value == 0) {
            IRootTokenContract(lpTokenRootAddress).deployWallet{
                value: msg.value/2,
                flag: 0
            }(uint128(toMint), msg.value/4, senderPubKey, senderAddress, senderAddress);
        } else {
            IRootTokenContract(lpTokenRootAddress).mint(uint128(toMint), lpWallet);
        }
        // return (provided1, provided2, toMint);
    }


    // возврат сдачи
    function _tryToReturnProvidingTokens(
        uint128 needToProvideAmount, uint128 actualAmount, address tokenWallet, address senderTokenWallet, address senderAddress, TvmBuilder payloadTB
    ) private {   
        uint128 a = needToProvideAmount - actualAmount;
        if (a > 0) {
            ITONTokenWallet(tokenWallet).transfer{
                value: msg.value/8,
                flag: 0
            }(senderTokenWallet, a, 0, senderAddress, false, payloadTB.toCell());
        }
    }


    //============HELPERS============

    function _createSwapPayload(SwapInfo si) private pure returns(TvmCell) {
        TvmBuilder tb;
        tb.store(si);
        return tb.toCell();
    }

    function _checkPayload(uint8 uid, uint8 reqUid, TvmSlice args, OperationSizeRequirements osr) private pure inline returns(bool) {
        return 
            uid == reqUid &&
            args.hasNBitsAndRefs(osr.bits, osr.refs);
    }
 
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

    function _constructSwapPairInfo()
        private
        view
        inline
        returns (SwapPairInfo)
    {
        SwapPairInfo spi = SwapPairInfo(
            swapPairRootContract,
            token1,
            token2,
            lpTokenRootAddress,
            tokenWallets[0],
            tokenWallets[1],
            lpTokenWalletAddress,
            swapPairDeployer,
            creationTimestamp,
            address(this),
            swapPairID,
            swapPairCodeVersion
        );
        return spi;
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
        tokenExistsInPair(_token)
        returns(uint8)
    {
        return tokenPositions[_token];
    }

    function _checkIsLiquidityProvided() private view inline returns (bool) {
        return lps[T1] > 0 && lps[T2] > 0 && kLast > SwapPairConstants.kMin;
    }


    function _calculateOneTokenProvidingAmount(address tokenRoot, uint128 tokenAmount)
        private
        view
        inline
        returns(uint128)
    {   
        uint8 fromK = _getTokenPosition(tokenRoot);
        uint128 f = uint256(lps[fromK]);
        uint128 k = feeNominator+feeDenominator;
        uint256 b = -1*f*k;
        uint256 v = f * _sqrt( k*k + math.muldiv(4*feeDenominator*feeNominator, tokenAmount, f));

        return uint128((b+v)/(feeNominator+feeNominator));
    }


    function _sqrt(uint256 x) private pure inline returns(uint256){
        uint256 z = (x+1) / 2;
        uint256 res = x;

        while(z < res) {
            res = z;
            z = ((x/z) + z) / 2;
        }
        return res;
    }

    //============Callbacks============

    /*
     * Set callback address for wallets
     */
    function _setWalletsCallbackAddress(address walletAddress) 
        private 
        pure 
    {
        tvm.accept();
        ITONTokenWallet(walletAddress).setReceiveCallback{
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
        TvmSlice tmp = payload.toSlice();
        (UnifiedOperation uo) = tmp.decode(UnifiedOperation);

        if (msg.sender != lpTokenWalletAddress) {
            if (uo.operationId == SwapPairConstants.SwapPairOperation) {
                SwapPairContract(this)._externalSwap{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, msg.sender, token_root, amount, sender_wallet, sender_address
                );
            } 
            else if (uo.operationId == SwapPairConstants.ProvideLiquidity) {
                SwapPairContract(this)._externalProvideLiquidity{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, msg.sender, sender_public_key, sender_address, amount, sender_wallet
                );
            } 
            else if (uo.operationId == SwapPairConstants.ProvideLiquidityOneToken) {
                SwapPairContract(this)._externalProvideLiquidityOneToken{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, msg.sender, sender_public_key, sender_address, amount, sender_wallet
                );
            } 
            else {
                TvmBuilder failTB;
                failTB.store(unknownOperationIdorWrongPayload);
                ITONTokenWallet(msg.sender).transfer{
                    flag: 64,
                    value: 0
                }(sender_wallet, amount, 0, sender_address, false, failTB.toCell());
            }
        } 
        else {
            if (uo.operationId == SwapPairConstants.WithdrawLiquidity) {
                SwapPairContract(this)._externalWithdrawLiquidity{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, amount, sender_address, sender_wallet, false
                );
            } else if (uo.operationId == SwapPairConstants.WithdrawLiquidityOneToken) {
                SwapPairContract(this)._externalWithdrawLiquidityOneToken{
                    flag: 64,
                    value: 0
                }();
            } else {
                TvmBuilder failTB;
                failTB.store(unknownOperationIdorWrongPayload);
                ITONTokenWallet(msg.sender).transfer{
                    flag: 64,
                    value: 0
                }(sender_wallet, amount, 0, sender_address, false, failTB.toCell());
            }
        }
    }

    function burnCallback(
        uint128 tokensBurnt,
        TvmCell payload,
        uint256 sender_public_key,
        address sender_address,
        address wallet_address,
        address send_gas_to
    ) external view onlyTokenRoot {
        TvmSlice tmp = payload.toSlice();
        (UnifiedOperation uo) = tmp.decode(UnifiedOperation);
        if (
            msg.sender != lpTokenWalletAddress
        ) {
            if (uo.operationId == SwapPairConstants.WithdrawLiquidity) {
                SwapPairContract(this)._externalWithdrawLiquidity{
                    flag: 64,
                    value: 0
                }(
                    uo.operationArgs, tokensBurnt, sender_address, wallet_address, true
                );
            }
        }
    }

    //============External LP functions============

    function _externalSwap(
        TvmCell args, address tokenReceiver, address token_root, uint128 amount, address sender_wallet, address sender_address
    ) 
        external 
        onlySelf 
    {
        TvmSlice tmpArgs = args.toSlice();
        (bool isPayloadOk, address transferTokensTo) = _checkAndDecompressSwapPayload(tmpArgs);
        
        if ( !isPayloadOk ){
            TvmBuilder failTB;
            failTB.store(wrongPayloadFormatMessage);
            ITONTokenWallet(tokenReceiver).transfer{
                value: 0, 
                flag: 64
            }(sender_wallet, amount, 0, sender_address, false, failTB.toCell());

            return;
        }
        if ( !_checkIsLiquidityProvided() ){
            TvmBuilder failTB;
            failTB.store(noLiquidityProvidedMessage);
            ITONTokenWallet(tokenReceiver).transfer{
                value: 0, 
                flag: 64
            }(sender_wallet, amount, 0, sender_address, false, failTB.toCell());

            return;
        }

        SwapInfo si = _swap(token_root, amount);
        if (si.targetTokenAmount != 0) {
            address tokenWallet = tokenReceiver == tokenWallets[T1] ? tokenWallets[T2] : tokenWallets[T1];  // TODO поправил, вроде был баг 
            ITONTokenWallet(tokenWallet).transfer{
                value: 0,
                flag: 64
            }(transferTokensTo, si.targetTokenAmount, 0, address.makeAddrStd(0, 0), true, _createSwapPayload(si));
        } else {
            ITONTokenWallet(tokenReceiver).transfer{
                value: 0,
                flag: 64
            }(sender_wallet, amount, 0, address.makeAddrStd(0, 0), true,  _createSwapFallbackPayload());
        }
    }


    function _externalProvideLiquidity(
        TvmCell args, 
        address tokenReceiver, 
        uint256 sender_public_key, 
        address sender_address, 
        uint128 amount, 
        address sender_wallet
    ) 
        external 
        onlySelf 
    {
        TvmSlice tmpArgs = args.toSlice();
        (bool isPayloadOk, address lpWallet) = _checkAndDecompressProvideLiquidityPayload(tmpArgs);

        if ( !isPayloadOk ) {
            TvmBuilder failTB;
            failTB.store(wrongPayloadFormatMessage);
            ITONTokenWallet(tokenReceiver).transfer{ 
                flag: 64, 
                value: 0 
            }(sender_wallet, amount, 0, sender_wallet, false, failTB.toCell());

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
            (uint128 rtp1, uint128 rtp2, uint256 toMint) = _provideLiquidity(lppi.a1, lppi.a2, sender_public_key, sender_address, lpWallet);

            TvmBuilder payloadTB;
            payloadTB.store(lppi.a1, rtp1, lppi.a2, rtp2);

            _tryToReturnProvidingTokens(lppi.a1, rtp1, tokenWallets[T1], lppi.w1, sender_address, payloadTB);
            _tryToReturnProvidingTokens(lppi.a2, rtp2, tokenWallets[T2], lppi.w2, sender_address, payloadTB);

            delete lpInputTokensInfo[uniqueID];
        } 
    }


    // TODO: Антон: формировние payload для ошибки при добавлении по одному токену
    // TODO: Антон: сделать добавление ликвидности по одному токену
    function _externalProvideLiquidityOneToken(        
        TvmCell args, 
        address tokenReceiver, 
        uint256 sender_public_key, 
        address sender_address, 
        uint128 amount, 
        address sender_wallet
    ) 
        external 
        onlySelf 
    {
        TvmSlice tmpArgs = args.toSlice();

        // TODO вынести в отдельную функцию
        if ( !_checkProvideLiquidityOneTokenPayload(tmpArgs) ) {
            TvmBuilder failTB;
            failTB.store(wrongPayloadFormatMessage);
            ITONTokenWallet(tokenReceiver).transfer{ 
                flag: 64, 
                value: 0 
            }(sender_wallet, amount, 0, sender_wallet, false, failTB.toCell());

            return;            
        }

        // TODO вынести в отдельную функцию
        if ( !_checkIsLiquidityProvided() ){
            TvmBuilder failTB;
            failTB.store(noLiquidityProvidedMessage);
            ITONTokenWallet(tokenReceiver).transfer{
                value: 0, 
                flag: 64
            }(sender_wallet, amount, 0, sender_address, false, failTB.toCell());

            return;
        }

        address lpWallet = tmpArgs.decode(address);

        (uint128 provided1, uint128 provided2, uint256 toMint, uint128 remainder) = _provideLiquidityOneToken(tokenReceiver, amount, sender_public_key, sender_address, lpWallet);

        if (provided2 == 0 || provided1 == 0)
            remainder = amount;

        TvmBuilder payloadTB;
        payloadTB.store(tokenReceiver, amount, remainder, provided1, provided2);

        _tryToReturnProvidingTokens(remainder, 0, tokenReceiver, sender_wallet, sender_address, payloadTB);
    }


    function _externalWithdrawLiquidity(
        TvmCell args, uint128 amount, address sender_address, address sender_wallet, bool tokensBurnt
    ) external view onlySelf {
        TvmSlice tmpArgs = args.toSlice();
        (bool isPayloadOk, LPWithdrawInfo lpwi) = _checkAndDecompressWithdrawLiquidityPayload(tmpArgs);
        if ( isPayloadOk ) {
            SwapPairContract(this)._withdrawTokensFromLP{flag: 64, value: 0}(amount, lpwi, sender_address, sender_wallet, tokensBurnt);
        } else {
            if ( tokensBurnt ) {
                IRootTokenContract(lpTokenRootAddress).mint{
                    flag: 64,
                    value: 0
                }(amount, sender_wallet);
            } else {
                TvmBuilder failTB;
                failTB.store(wrongPayloadFormatMessage);
                ITONTokenWallet(lpTokenWalletAddress).transfer{
                    flag: 64,
                    value: 0
                }(
                    sender_wallet, amount, 0, sender_wallet, false, failTB.toCell()
                );
            }
        }
    }
    
    // TODO: Антон: формировние payload для ошибки при выводе по одному токену
    // TODO: Антон: сделать вывод ликвидности по одному токену
    function _externalWithdrawLiquidityOneToken(
        TvmCell args, uint128 amount, address sender_address, address sender_wallet, bool tokensBurnt
    ) external onlySelf {
        TvmSlice tmpArgs = args.toSlice();

        if (_checkWithdrawLiquidityOneTokenPayload(tmpArgs)) {
            (address tokenRoot, address userWallet) = tmpArgs.decode(address, address);
            SwapPairContract(this)._withdrawOneTokenFromLP{
                flag: 64, value: 0
            } (amount, tokenRoot, userWallet, sender_wallet, tokensBurnt);
            return;
        }
        else {
            if (tokensBurnt) {
                IRootTokenContract(lpTokenRootAddress).mint{
                    flag: 64,
                    value: 0
                }(amount, sender_wallet);
            } else {
                TvmBuilder failTB;
                failTB.store(wrongPayloadFormatMessage);
                ITONTokenWallet(lpTokenWalletAddress).transfer{
                    flag: 64,
                    value: 0
                }(
                    sender_wallet, amount, 0, sender_wallet, false, failTB.toCell()
                );
            }
        }

    }

    //============Payload manipulation functions============

    function _checkAndDecompressSwapPayload(TvmSlice tmpArgs) private view returns (bool isPayloadOk, address transferTokensTo) {
        bool isSizeOk = tmpArgs.hasNBitsAndRefs(SwapOperationSize.bits, SwapOperationSize.refs);
        address content = _decompressSwapPayload(tmpArgs);
        bool isContentOk = content.value != 0;
        isPayloadOk = isSizeOk && isContentOk;
        transferTokensTo = content;
    }

    function _checkAndDecompressProvideLiquidityPayload(TvmSlice tmpArgs) private view returns (bool isPayloadOk, address lpTokenAddress) {
        bool isSizeOk = tmpArgs.hasNBitsAndRefs(ProvideLiquidityOperationSize.bits, ProvideLiquidityOperationSize.refs);
        address content = _decompressProvideLiquidityPayload(tmpArgs);
        bool isContentOk = content.value != 0;
        isPayloadOk = isSizeOk && isContentOk;
        lpTokenAddress = content;
    }

    function _checkAndDecompressWithdrawLiquidityPayload(TvmSlice tmpArgs) private view returns (bool isPayloadOk, LPWithdrawInfo lpwi) {
        bool isSizeOk = tmpArgs.hasNBitsAndRefs(WithdrawOperationSize.bits, WithdrawOperationSize.refs);
        LPWithdrawInfo content = _decompressWithdrawLiquidityPayload(tmpArgs);
        bool isContentOk = content.tr1.value != 0 && content.tr2.value != 0 && content.tw1.value != 0 && content.tw2.value != 0;
        isPayloadOk = isSizeOk && isContentOk;
        lpwi = content;
    }

    function _checkProvideLiquidityOneTokenPayload(TvmSlice tmpArgs) private view returns (bool) {
        // TODO: Антон: проверка на нулевые значения (см выше) + возвращение распакованного payload
        return tmpArgs.hasNBitsAndRefs(ProvideLiquidityOperationSizeOneToken.bits, ProvideLiquidityOperationSizeOneToken.refs);
    }

    function _checkWithdrawLiquidityOneTokenPayload(TvmSlice tmpArgs) private view returns (bool) {
        // TODO: Антон: проверка на нулевые значения (см выше) + возвращение распакованного payload
        return tmpArgs.hasNBitsAndRefs(WithdrawOperationSizeOneToken.bits, WithdrawOperationSizeOneToken.refs);
    }

    function _decompressSwapPayload(TvmSlice tmpArgs) private pure returns(address) {
        (address transferTokensTo) = tmpArgs.decode(address);
        return transferTokensTo;
    }

    function _decompressProvideLiquidityPayload(TvmSlice tmpArgs) private pure returns (address) {
        address lpWallet = tmpArgs.decode(address);
        return lpWallet;
    }

    function _decompressWithdrawLiquidityPayload(TvmSlice tmpArgs) private pure returns (LPWithdrawInfo) {
        LPWithdrawInfo lpwi;
        (lpwi.tr1, lpwi.tw1) = tmpArgs.decode(address, address);
        TvmSlice secondPart = tmpArgs.loadRefAsSlice();
        (lpwi.tr2, lpwi.tw2) = secondPart.decode(address, address);
        return lpwi;
    }

    // TODO: Антон: распаковка payload для provideLiquidityOneToken
    // TODO: Антон: распаковка payload для withdrawLiquidityOneToken

    function _createSwapFallbackPayload() private pure returns (TvmCell) {
        TvmBuilder tb;
        tb.store(sumIsTooLowForSwap);
        return tb.toCell();
    }

    function _createWithdrawResultPayload(address w1, uint128 t1a, address w2, uint128 t2a) private pure returns (TvmCell) {
        TvmBuilder payloadB;
        payloadB.store(w1, t1a, w2, t2a);
        return payloadB.toCell();
    }

    function createSwapPayload(address sendTokensTo) external pure returns (TvmCell) {
        TvmBuilder tb; TvmBuilder argsBuilder;
        argsBuilder.store(sendTokensTo);
        tb.store(UnifiedOperation(SwapPairConstants.SwapPairOperation, argsBuilder.toCell()));
        return tb.toCell();
    }

    function createProvideLiquidityPayload(address tip3Address) external pure returns (TvmCell) {
        TvmBuilder tb; TvmBuilder argsBuilder;
        argsBuilder.store(tip3Address);
        tb.store(UnifiedOperation(SwapPairConstants.ProvideLiquidity, argsBuilder.toCell()));
        return tb.toCell();
    }

    function createProvideLiquidityOneTokenPayload(address tip3Address) external pure returns (TvmCell) {
        TvmBuilder tb; TvmBuilder argsBuilder;
        argsBuilder.store(tip3Address);
        tb.store(UnifiedOperation(SwapPairConstants.ProvideLiquidityOneToken, argsBuilder.toCell()));
        return tb.toCell();
    }

    function createWithdrawLiquidityPayload(
        address tokenRoot1,
        address tokenWallet1,
        address tokenRoot2,
        address tokenWallet2
    ) external pure returns (TvmCell) {
        TvmBuilder tb; TvmBuilder payloadFirstHalf; TvmBuilder payloadSecondHalf;
        payloadFirstHalf.store(tokenRoot1, tokenWallet1); payloadSecondHalf.store(tokenRoot2, tokenWallet2);
        payloadFirstHalf.storeRef(payloadSecondHalf);
        tb.store(UnifiedOperation(SwapPairConstants.WithdrawLiquidity, payloadFirstHalf.toCell()));
        return tb.toCell();
    }

    function createWithdrawLiquidityOneTokenPayload(address tokenRoot, address userWallet) external pure returns (TvmCell) 
    {
        TvmBuilder tb; TvmBuilder argsBuilder;
        argsBuilder.store(tokenRoot, userWallet);
        tb.store(UnifiedOperation(SwapPairConstants.WithdrawLiquidityOneToken, argsBuilder.toCell()));
        return tb.toCell();
    }

    //============Withdraw LP tokens functionality============

    function _withdrawTokensFromLP(
        uint128 tokenAmount, 
        LPWithdrawInfo lpwi,
        address walletAddress,
        bool tokensBurnt
    ) external onlySelf {
        require(
            _checkIsLiquidityProvided(),
            SwapPairErrors.NO_LIQUIDITY_PROVIDED
        );

        (uint128 withdrawed1, uint128 withdrawed2, uint256 burned) = _calculateWithdrawingLiquidityInfo(tokenAmount);

        if (withdrawed1 != 0 && withdrawed2 != 0) {
            lps[T1] -= withdrawed1;
            lps[T2] -= withdrawed2;
            kLast = uint256(lps[T1]) * uint256(lps[T2]);

            if (!tokensBurnt) {
                _burnTransferredLPTokens(tokenAmount);
            }

            liquidityTokensMinted -= tokenAmount;

            emit WithdrawLiquidity(burned, withdrawed1, withdrawed2);
            SwapPairContract(this)._transferTokensToWallets{
                flag: 64,
                value: 0
            }(lpwi, withdrawed1, withdrawed2);
        } else {
            _fallbackWithdrawLP(walletAddress, tokenAmount, tokensBurnt);
        }
    }

    function _withdrawOneTokenFromLP  (
        uint128 tokenAmount, 
        address tokenRoot,
        address tokenWallet, 
        address lpWalletAddress,
        bool tokensBurnt
    ) external onlySelf {
        // TODO: общая часто с функцией _withdrawTokensFromLP, вынести в отдельный метод
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
        kLast = uint256(lps[T1]) * uint256(lps[T2]);

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
        
        SwapPairContract(this)._transferTokenToWallet{
            flag: 64,
            value: 0
        }(tokenRoot, tokenWallet, resultAmount);
    }

    function _transferTokensToWallets(
        LPWithdrawInfo lpwi, uint128 t1Amount, uint128 t2Amount
    ) external view onlySelf {
        bool t1ist1 = lpwi.tr1 == token1; // смотрим, не была ли перепутана последовательность адресов рут-контрактов
        address w1 = t1ist1 ? tokenWallets[0] : tokenWallets[1];
        address w2 = t1ist1 ? tokenWallets[1] : tokenWallets[0];
        uint128 t1a = t1ist1 ? t1Amount : t2Amount;
        uint128 t2a = t1ist1 ? t2Amount : t1Amount;
        // TODO: рефакторинг: вынести создание payload в отдельный метод
        TvmCell payload = _createWithdrawResultPayload(w1, t1a, w2, t2a);
        ITONTokenWallet(w1).transfer{value: msg.value/3}(lpwi.tw1, t1a, 0, address(this), true, payload);
        ITONTokenWallet(w2).transfer{flag: 64, value: 0}(lpwi.tw2, t2a, 0, address(this), true, payload);
    }

    function _transferTokenToWallet(address tokenRoot, address tokenWallet, uint128 amount)
        external view onlySelf
    {     
        address w = tokenRoot == token1 ? tokenWallets[T1] : tokenWallets[T2];

        // TODO: рефакторинг: вынести создание payload'a в отдельный метод
        TvmBuilder payloadB;
        payloadB.store(tokenWallet, amount);
        TvmCell payload = payloadB.toCell();

        ITONTokenWallet(w).transfer{flag: 64, value: 0}(tokenWallet, amount, 0, address(this), true, payload);
    }

    function _fallbackWithdrawLP(
        address walletAddress, uint128 tokensAmount, bool mintRequired
    ) private view inline {
        if (mintRequired) {
            IRootTokenContract(lpTokenRootAddress).mint{
                value: 0,
                flag: 64
            }(tokensAmount, walletAddress);
        } else {
            TvmBuilder payload;
            payload.store(sumIsTooLowForLPTokenWithdraw);
            ITONTokenWallet(lpTokenWalletAddress).transfer{
                value: 0,
                flag: 64
            }(walletAddress, tokensAmount, 0, address(this), true, payload.toCell());
        }
    }

    function _burnTransferredLPTokens(uint128 tokenAmount) private view inline {
        TvmCell payload;
        IBurnableByOwnerTokenWallet(lpTokenWalletAddress).burnByOwner{
            value: msg.value/4
        }(tokenAmount, 0, address(this), address(this), payload);
    }



    //============Upgrade swap pair code part============

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

    function checkIfSwapPairUpgradeRequired(uint32 newCodeVersion) override external onlySwapPairRoot returns(bool) {
        return newCodeVersion > swapPairCodeVersion;
    }

    function _initializeAfterCodeUpdate() inline private {
        //code will be added when required
    }



    //============Modifiers============

    modifier initialized() {
        require(initializedStatus == SwapPairConstants.contractFullyInitialized, SwapPairErrors.CONTRACT_NOT_INITIALIZED);
        _;
    }

    modifier onlyOwner() {
        require(
            msg.pubkey() == swapPairDeployer,
            SwapPairErrors.CALLER_IS_NOT_OWNER
        );
        _;
    }

    modifier onlyTokenRoot() {
        require(
            msg.sender == token1 || msg.sender == token2 || msg.sender == lpTokenRootAddress,
            SwapPairErrors.CALLER_IS_NOT_TOKEN_ROOT
        );
        _;
    }

    modifier onlyTIP3Deployer() {
        require(
            msg.sender == tip3Deployer,
            SwapPairErrors.CALLER_IS_NOT_TIP3_DEPLOYER
        );
        _;
    }

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

    modifier onlySelf() {
        require(msg.sender == address(this));
        _;
    }

    modifier onlySwapPairRoot() {
        require(
            msg.sender == swapPairRootContract,
            SwapPairErrors.CALLER_IS_NOT_SWAP_PAIR_ROOT
        );
        _;
    }

    modifier liquidityProvided() {
        require(
            _checkIsLiquidityProvided(),
            SwapPairErrors.NO_LIQUIDITY_PROVIDED
        );
        _;
    }

    
    modifier tokenExistsInPair(address _token) {
        require(
            tokenPositions.exists(_token),
            SwapPairErrors.INVALID_TOKEN_ADDRESS
        );
        _;
    }

    //============Too big for modifier too small for function============

    function notEmptyAmount(uint128 _amount) private pure inline {
        require (_amount > 0,  SwapPairErrors.INVALID_TOKEN_AMOUNT);
    }

    function notZeroLiquidity(uint128 _amount1, uint128 _amount2) private pure inline returns(bool) {
        return _amount1 > 0 && _amount2 > 0;
    }
}
