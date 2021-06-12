pragma ton-solidity ^0.39.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './ISwapPairInformation.sol';

interface ISwapPairContract is ISwapPairInformation {

    function getExchangeRate(
        address swappableTokenRoot, 
        uint128 swappableTokenAmount
    ) external responsible view returns (SwapInfo _swapInfo);
    
    function getCurrentExchangeRate() external responsible view returns (LiquidityPoolsInfo lpi);

    function getPairInfo() external responsible view returns (SwapPairInfo info);

    function getWithdrawingLiquidityInfo(uint256 liquidityTokensAmount)
        external view returns (uint128 withdrawedFirstTokenAmount, uint128 withdrawedSecondTokenAmount);

    function getProvidingLiquidityInfo(
        uint128 maxFirstTokenAmount,
        uint128 maxSecondTokenAmount
    ) external view returns (uint128 providedFirstTokenAmount, uint128 providedSecondTokenAmount);

    function getAnotherTokenProvidingAmount(
        address providingTokenRoot,
        uint128 providingTokenAmount
    ) external view returns(uint128 anotherTokenAmount);

    function createSwapPayload(address sendTokensTo) external pure returns (TvmCell);

    function createProvideLiquidityPayload(address tip3Address) external pure returns (TvmCell);

    function createProvideLiquidityOneTokenPayload(address tip3Address) external pure returns (TvmCell);

    function createWithdrawLiquidityPayload(
        address tokenRoot1,
        address tokenWallet1,
        address tokenRoot2,
        address tokenWallet2
    ) external pure returns (TvmCell);
    
    function createWithdrawLiquidityOneTokenPayload(
        address tokenRoot, 
        address userWallet
    ) external pure returns (TvmCell);

    //Events
    event Swap(       
        address providedTokenRoot,  
        address targetTokenRoot,
        uint128 tokensUsedForSwap,
        uint128 tokensReceived,
        uint128 fee
    );

    event ProvideLiquidity(
        uint256 liquidityTokensAmount,
        uint128 firstTokenAmount,
        uint128 secondTokenAmount
    );

    event WithdrawLiquidity(
        uint256 liquidityTokensAmount,
        uint128 firstTokenAmount,
        uint128 secondTokenAmount
    );
}