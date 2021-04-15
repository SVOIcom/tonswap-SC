pragma ton-solidity ^0.39.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/IRootTokenContract.sol';
import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/ITokensReceivedCallback.sol';
import '../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/ITONTokenWallet.sol';
import "../../ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/IBurnTokensCallback.sol";
import './interfaces/swapPair/ISwapPairContract.sol';
import './interfaces/swapPair/ISwapPairInformation.sol';
import './interfaces/swapPair/IUpgradeSwapPairCode.sol';
import './interfaces/rootSwapPair/IRootContractCallback.sol';

import './interfaces/helpers/ITIP3TokenDeployer.sol';

import './libraries/swapPair/SwapPairErrors.sol';
import './libraries/swapPair/SwapPairConstants.sol';

// TODO: перевести взаимодействие через payload на унифицированную базу с использованием унифицированной структуры

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

    //Users balances
    mapping(uint256 => uint256) usersTONBalance;
    mapping(uint8 => mapping(uint256 => uint128)) tokenUserBalances;
    mapping(uint256 => uint128) rewardUserBalance;

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

    // Required for interaction with wallets for smart-contracts
    uint128 constant sendToTIP3TokenWallets     = 110  milli;
    uint128 constant sendToRootToken            = 500  milli;

    // Tokens positions
    uint8 constant T1 = 0;
    uint8 constant T2 = 1; 

    // Token info
    uint8 tokenInfoCount;
    IRootTokenContract.IRootTokenContractDetails T1Info;
    IRootTokenContract.IRootTokenContractDetails T2Info;


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
    //============Contract initialization functions============

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
        }(
            SwapPairConstants.walletInitialBalanceAmount,
            tvm.pubkey(),
            address(this),
            address(this)
        );

        _getWalletAddress(tokenRootAddress);
    }

    function _getWalletAddress(address token) private view {
        tvm.accept();
        IRootTokenContract(token).getWalletAddress{value: sendToRootToken, callback: this.getWalletAddressCallback}(tvm.pubkey(), address(this));
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
        view
    {
        IRootTokenContract(tokenRootAddress).getDetails{ value: 0.1 ton, bounce: true, callback: this._receiveTIP3Details }();
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
            _prepareDataForTIP3Deploy();
        }
    }

    // TODO: доделать получение данных для деплоя нового тип-3
    function _prepareDataForTIP3Deploy()
        private
        view
    {
        _deployTIP3LpToken("TTLP", "TTLP", 9);
    }

    function _deployTIP3LpToken(
        bytes name,
        bytes symbol
    )
        private
        view
    {
        tvm.accept();
        ITIP3TokenDeployer(tip3Deployer).deployTIP3Token{
            value: SwapPairConstants.tip3SendDeployGrams,
            bounce: true,
            callback: this._deployTIP3LpTokenCallback
        }(
            name,
            symbol,
            SwapPairConstants.tip3LpDecimals,
            0,
            address(this),
            SwapPairConstants.tip3DeployGrams
        );
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

    //============TON balance functions============

    receive() external {

    }

    fallback() external {

    }

    //============Get functions============

    /**
    * Get pair creation timestamp
    */
    function getCreationTimestamp() override public responsible view returns (uint256) {
        return creationTimestamp;
    }

    function getPairInfo() override external responsible view returns (SwapPairInfo info) {
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

    function _swap(address swappableTokenRoot, uint128 swappableTokenAmount, bool isDebug)
        internal
        initialized
        returns (SwapInfo)  
    {
        require(
            tokenPositions.exists(swappableTokenRoot),
            SwapPairErrors.INVALID_TOKEN_ADDRESS,
            SwapPairErrors.INVALID_TOKEN_ADDRESS_MSG
        );
        // TODO: перенести проверку предоставлена ли ликвидность
        require(
            _checkIsLiquidityProvided(),
            SwapPairErrors.NO_LIQUIDITY_PROVIDED,
            SwapPairErrors.NO_LIQUIDITY_PROVIDED_MSG
        );

        _SwapInfoInternal _si = _getSwapInfo(swappableTokenRoot, swappableTokenAmount);

        // TODO: Переделать проверку
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


    //============HELPERS============

    function _createSwapPayload(SwapInfo si) private returns(TvmCell) {
        TvmBuilder tb;
        tb.store(si);
        return tb.toCell();
    }

    function _checkPayload(uint8 uid, uint8 reqUid, TvmSlice args, OperationSizeRequirements osr) private inline returns(bool) {
        return 
            uid == reqUid &&
            args.hasNBitsAndRefs(osr.bits, osr.refs);
    }
 
    function _swapPairInitializedCall() 
        private
        view
    {
        tvm.accept();
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
        IRootContractCallback(swapPairRootContract).swapPairInitializedCallback{
            value: 0.1 ton,
            bounce: true
        }(spi);
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
        return lps[T1] > 0 && lps[T2] > 0 && kLast > SwapPairConstants.kMin;
    }

    //============Callbacks============

    /*
     * Set callback address for wallets
     */
    function _setWalletsCallbackAddress(address walletAddress) 
        private 
        view 
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
        if (msg.sender != lpTokenWalletAddress) {
            uint8 _p = tokenWallets[T1] == msg.sender ? T1 : T2; // `onlyWallets` eliminates other validational
            if (tokenUserBalances[_p].exists(sender_public_key)) {
                tokenUserBalances[_p].replace(
                    sender_public_key,
                    tokenUserBalances[_p].at(sender_public_key) + amount
                );
            } else {
                tokenUserBalances[_p].add(sender_public_key, amount);
            }
        } else {
            TvmSlice tmp = payload.toSlice();
            (UnifiedOperation uo) = tmp.decode(UnifiedOperation);
            TvmSlice tmpArgs = uo.operationArgs.toSlice();

            if (
                msg.sender != lpTokenWalletAddress &&
                _checkPayload(uo.operationId, SwapPairConstants.SwapPairOperation, tmpArgs, SwapOperationSize)
            ) {
                (address transferTokensTo) = tmpArgs.decode(address);
                SwapInfo si = _swap(token_root, amount, false);
                if (si.targetTokenAmount != 0)
                    ITONTokenWallet(tokenWallets[tokenPositions[token_root]]).transfer{
                        value: 0,
                        flag: 128
                    }(
                        transferTokensTo,
                        si.targetTokenAmount,
                        0,
                        address.makeAddrStd(0, 0),
                        true,
                        _createSwapPayload(si)
                    );
                else
                    ITONTokenWallet(msg.sender).transfer{
                        value: 0,
                        flag: 128
                    }(
                        token_wallet,
                        amount,
                        0,
                        address.makeAddrStd(0, 0),
                        true,
                        // TODO: сделать формировагние payload для ошибки
                    );
            }

            if (
                msg.sender != lpTokenWalletAddress &&
                _checkPayload(uo.operationId, SwapPairConstants.ProvideLiquidity, tmpArgs, ProvideLiquidityOperationSize)
            ) {
                TvmBuilder tb;
                tb.store(sender_public_key, sender_address);
                uint256 uniqueID = tvm.hash(tb.toCell());
                if (!lpInputTokensInfo.exists(uniqueID))
                    lpInputTokensInfo.add(uniqueID, LPProvidingInfo(
                        sender_address,
                        sender_public_key,
                        address.makeAddrStd(0, 0),
                        0,
                        address.makeAddrStd(0, 0),
                        0))

                LPProvidingInfo lppi = lpInputTokensInfo[uniqueID];

                if (msg.sender == tokenWallets[0]) {
                    lppi.a1 += amount;
                    lppi.w1 = sender_wallet;
                }

                if (msg.sender == tokenWallets[1]) {
                    lppi.a2 += amount;
                    lppi.w2 = sender_wallet;
                }

                if (lppi.a1 != 0 && lppi.a2 != 0) {
                    (uint128 rtp1, uint128 rtp2, uint256 _minted) = _calculateProvidingLiquidityInfo(lppi.a1, lppi.a2);
                    lps[0] += rtp1;
                    lps[1] += rtp2;
                    kLast = uint256(lps[T1]) * uint256(lps[T2]);
                    // TODO: сделать перевод TIP-3 LP токена пользователю, вопрос - как
                } else {
                    lpInputTokensInfo[uniqueID] = lppi;
                    address(sender_wallet).transfer({value: 0, flag: 128});
                }
            }

            if (
                msg.sender != lpTokenWalletAddress &&
                _checkPayload(uo.operationId, SwapPairConstants.ProvideLiquidityOneToken, tmpArgs, ProvideLiquidityOperationSizeOneToken)
            ) {
                _provideLiquidityOneToken();
            }

            if (
                msg.sender == lpTokenWalletAddress &&
                _checkPayload(uo.operationId, SwapPairConstants.WithdrawLiquidity, tmpArgs, WithdrawOperationSize)
            ) {
                _tryToWithdrawLP(amount, payload, msg.sender, sender_address, true);
                _burnTransferredLPTokens(tokens);
            }

            if (
                msg.sender != lpTokenWalletAddress &&
                _checkPayload(uo.operationId, SwapPairConstants.WithdrawLiquidityOneToken, tmpArgs, WithdrawOperationSizeOneToken)
            ) {
                _withdrawLiquidityOneToken();
            }

            TvmCell failPayload;
            ITONTokenWallet(msg.sender).transfer{
                value: 0, 
                flag: 128
            }(
                msg.sender,
                amount,
                sender_address,
                false,
                failPayload
            );
        }
    }

    function burnCallback(
        uint128 tokens,
        TvmCell payload,
        uint256 sender_public_key,
        address sender_address,
        address wallet_address,
        address send_gas_to
    ) external onlyTokenRoot {
        if (wallet_address != lpTokenWalletAddress) {
            _tryToWithdrawLP(tokens, payload, msg.sender, sender_address, true);
        }
    }

    //============Withdraw LP tokens functionality============
    // TODO: для уведомления пользователя о выполненной операции можно использовать transfer + payload

    function _tryToWithdrawLP(
        uint128 tokenAmount, 
        TvmCell payload, 
        address tokenSender, 
        address walletOwner,
        bool tokensBurnt
    ) private inline {
        if (
            !payload.empty() &&
            payload.hasNBits(SwapPairConstants.payloadWithdrawBits) &&
            payload.hasNRefs(SwapPairConstants.payloadWithdrawRefs)
        ) {
            TvmSlice tmp = payload.toSlice();
            UnifiedOperation lpWithdrawInfo = tmp.decode(UnifiedOperation);
            if (lpWithdrawInfo.operationId == SwapPairConstants.WithdrawLiquidity) {
                TvmSlice args = lpWithdrawInfo.operationArgs.toSlice();
                _withdrawTokensFromLP(tokens, args.decode(LPWithdrawResult), walletOwner, tokensBurnt);
            } else
                _fallbackWithdrawLP(tokenSender, tokens, tokensBurnt);
        } else {
            _fallbackWithdrawLP(tokenSender, tokens, tokensBurnt);
        }
    }

    function _withdrawTokensFromLP(
        uint128 tokenAmount, 
        LPWithdrawInfo lpwi,
        address walletOwner,
        bool tokensBurnt
    ) private inline {
        require(
            _checkIsLiquidityProvided(),
            SwapPairErrors.NO_LIQUIDITY_PROVIDED,
            SwapPairErrors.NO_LIQUIDITY_PROVIDED_MSG
        );

        (uint128 withdrawed1, uint128 withdrawed2, uint256 burned) = _calculateWithdrawingLiquidityInfo(tokensBurnt);

        lps[T1] -= withdrawed1;
        lps[T2] -= withdrawed2;
        kLast = uint256(lps[T1]) * uint256(lps[T2]);

        _transferTokensToWallets(lpwi, withdrawed1, withdrawed2);

        emit WithdrawLiquidity(burned, withdrawed1, withdrawed2);
    }

    function _transferTokensToWallets(LPWithdrawInfo lpwi, uint128 t1Amount, uint128 t2Amount) private inline {
        bool t1ist1 = lpwi.tr1 == token1; // смотрим, не была ли перепутана последовательность адресов рут-контрактов
        address w1 = t1ist1? tokenWallets[0] : tokenWallets[1];
        address w2 = t1ist1? tokenWallets[1] : tokenWallets[0];
        uint128 t1a = t1ist1? t1Amount : t2Amount;
        uint128 t2a = t1ist1? t2Amount : t1Amount;
        TvmBuilder payloadB;
        payloadB.store(w1, t1a, w2, t2a);
        TvmCell payload = payloadB.toCell();
        ITONTokenWallet(w1).transfer(
            lpwi.tw1,
            t1a,
            0,
            address(this),
            true,
            payload
        );
        ITONTokenWallet(w2).transfer(
            lpwi.tw2,
            t2a,
            0,
            address(this),
            true,
            payload
        );
    }

    function _fallbackWithdrawLP(address walletAddress, uint128 tokensAmount, bool mintRequired) private inline {
        if (mintRequired) {
            IRootTokenContract(lpTokenRootAddress).mint{
                value: 0,
                flag: 128
            }(walletAddress, tokensAmount);
        } else {
            TvmCell payload;
            ITONTokenWallet(lpTokenWalletAddress).transfer{
                value: 0,
                flag: 128
            }(
                walletAddress,
                tokensAmount,
                0,
                address(this),
                true,
                payload
            );
        }
    }

    function _burnTransferredLPTokens(uint128 tokenAmount) private inline {
        TvmCell payload;
        ITONTokenWallet(lpTokenWalletAddress).burnByOwner{
            value: 0,
            flag: 128
        }(
            tokenAmount,
            address(this),
            address(this),
            payload
        );
    }

    //============Upgrade swap pair code part============

    function updateSwapPairCode(TvmCell newCode, uint32 newCodeVersion) override external onlySwapPairRoot {
        require(
            newCodeVersion > newCodeVersion, 
            SwapPairErrors.CODE_DOWNGRADE_REQUESTED,
            SwapPairErrors.CODE_DOWNGRADE_REQUESTED_MSG
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
        require(initializedStatus == 2, SwapPairErrors.CONTRACT_NOT_INITIALIZED, SwapPairErrors.CONTRACT_NOT_INITIALIZED_MSG);
        _;
    }

    modifier onlyOwner() {
        require(
            msg.pubkey() == swapPairDeployer,
            SwapPairErrors.CALLER_IS_NOT_OWNER,
            SwapPairErrors.CALLER_IS_NOT_OWNER_MSG
        );
        _;
    }

    modifier onlyTokenRoot() {
        require(
            msg.sender == token1 || msg.sender == token2 || msg.sender == lpTokenRootAddress,
            SwapPairErrors.CALLER_IS_NOT_TOKEN_ROOT,
            SwapPairErrors.CALLER_IS_NOT_TOKEN_ROOT_MSG
        );
        _;
    }

    modifier onlyTIP3Deployer() {
        require(
            msg.sender == tip3Deployer,
            SwapPairErrors.CALLER_IS_NOT_TIP3_DEPLOYER,
            SwapPairErrors.sCALLER_IS_NOT_TIP3_DEPLOYER_MSG
        );
        _;
    }

    modifier onlyOwnWallet() {
        bool b1 = tokenWallets.exists(T1) && msg.sender == tokenWallets[T1];
        bool b2 = tokenWallets.exists(T2) && msg.sender == tokenWallets[T2];
        bool b3 = msg.sender == lpTokenWalletAddress;
        require(
            b1 || b2 || b3,
            SwapPairErrors.CALLER_IS_NOT_TOKEN_WALLET,
            SwapPairErrors.CALLER_IS_NOT_TOKEN_WALLET_MSG
        );
        _;
    }

    modifier onlySwapPairRoot() {
        require(
            msg.sender == swapPairRootContract,
            SwapPairErrors.CALLER_IS_NOT_SWAP_PAIR_ROOT,
            SwapPairErrors.CALLER_IS_NOT_SWAP_PAIR_ROOT_MSG
        );
        _;
    }

    modifier liquidityProvided() {
        require(
            _checkIsLiquidityProvided(),
            SwapPairErrors.NO_LIQUIDITY_PROVIDED,
            SwapPairErrors.NO_LIQUIDITY_PROVIDED_MSG
        );
        _;
    }

    
    modifier tokenExistsInPair(address _token) {
        require(
            tokenPositions.exists(_token),
            SwapPairErrors.INVALID_TOKEN_ADDRESS,
            SwapPairErrors.INVALID_TOKEN_ADDRESS_MSG
        );
        _;
    }

    //============Too big for modifier too small for function============

    function notEmptyAmount(uint128 _amount) private pure inline {
        require (_amount > 0,  SwapPairErrors.INVALID_TOKEN_AMOUNT, SwapPairErrors.INVALID_TOKEN_AMOUNT_MSG);
    }

    function notZeroLiquidity(uint128 _amount1, uint128 _amount2) private pure inline returns(bool) {
        return _amount1 > 0 && _amount2 > 0;
    }

    // TODO: убрать данный модификатор и удалить
    function userEnoughTokenBalance(
        address _token, 
        uint128 amount, 
        uint pubkey
    ) private view inline {
        uint8 _p = _getTokenPosition(_token);        
        uint128 userBalance = tokenUserBalances[_p][pubkey];
        require(
            userBalance > 0 && userBalance >= amount,
            SwapPairErrors.INSUFFICIENT_USER_BALANCE,
            SwapPairErrors.INSUFFICIENT_USER_BALANCE_MSG
        );
    }

    // TODO: убрать данный модификатор и удалить
    function checkUserTokens(
        address token1_, 
        uint128 token1Amount, 
        address token2_, 
        uint128 token2Amount, 
        uint pubkey
    ) private view inline {
        bool b1 = tokenUserBalances[tokenPositions[token1_]][pubkey] >= token1Amount;
        bool b2 = tokenUserBalances[tokenPositions[token2_]][pubkey] >= token2Amount;
        require(
            b1 && b2,
            SwapPairErrors.INSUFFICIENT_USER_BALANCE,
            SwapPairErrors.INSUFFICIENT_USER_BALANCE_MSG
        );
    }
}