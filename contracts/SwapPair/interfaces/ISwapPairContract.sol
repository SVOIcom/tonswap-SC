pragma ton-solidity >= 0.6.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './ISwapPairInformation.sol';

interface ISwapPairContract is ISwapPairInformation {
    function swap(
        address swappableTokenRoot,  
        uint128 swappableTokenAmount
    ) external  returns (SwapInfo _swapInfo);

    function getExchangeRate(
        address swappableTokenRoot, 
        uint128 swappableTokenAmount
    ) external view returns (SwapInfo _swapInfo);
    
    function getCurrentExchangeRate() external view returns (uint128, uint128);

    function getCurrentExchangeRateExt() external view returns(uint128, uint128);

    function provideLiquidity(
        uint128 maxFirstTokenAmount, 
        uint128 maxSecondTokenAmount
    ) external returns (uint128 providedFirstTokenAmount, uint128 providedSecondTokenAmount);

    // function withdrawLiquidity(
    //     uint128 minFirstTokenAmount, 
    //     uint128 minSecondTokenAmount
    // ) external returns (uint128 withdrawedFirstTokenAmount, uint128 withdrawedSecondTokenAmount);
    function withdrawLiquidity(uint256 liquidityTokensAmount)  
        external returns (uint128 withdrawedFirstTokenAmount, uint128 withdrawedSecondTokenAmount);
    
    function withdrawTokens(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) external;

    function getCreationTimestamp() external view returns (uint256 creationTimestamp);

    function getLPComission() external view returns(uint128);

    function getPairInfo() external view returns (SwapPairInfo info);

    function getUserBalance(uint pubkey) external view returns (UserBalanceInfo ubi);

    function getUserTONBalance(uint pubkey) external view returns (uint balance);

    function getUserLiquidityPoolBalance(uint pubkey) external view returns (UserPoolInfo upi) ;

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
}