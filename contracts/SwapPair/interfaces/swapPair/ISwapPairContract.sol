pragma ton-solidity ^0.39.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './ISwapPairInformation.sol';

interface ISwapPairContract is ISwapPairInformation {
    function swap(
        address swappableTokenRoot,  
        uint128 swappableTokenAmount
    ) external responsible returns (SwapInfo _swapInfo);

    function getExchangeRate(
        address swappableTokenRoot, 
        uint128 swappableTokenAmount
    ) external responsible view returns (SwapInfo _swapInfo);
    
    function getCurrentExchangeRate() external responsible view returns (uint128, uint128);
    
    function withdrawTokens(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) external;

    function getCreationTimestamp() external responsible view returns (uint256 creationTimestamp);

    function getLPComission() external responsible view returns(uint128);

    function getPairInfo() external view returns (SwapPairInfo info);

    function getUserBalance(uint pubkey) external responsible view returns (UserBalanceInfo ubi);

    function getUserTONBalance(uint pubkey) external responsible view returns (uint balance);

    function withdrawTONs(address tonDestination, uint128 amount) external;

    function getUserLiquidityPoolBalance(uint pubkey) external responsible view returns (UserPoolInfo upi);

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

    function constructWithdrawingLPCell(
        address tr1,
        address tw1,
        address tr2,
        address tw2
    ) external pure returns (TvmCell);


    //Events
    event Swap(
        uint256 msgSenderPubkey,         
        address swappableTokenRoot,  
        address targetTokenRoot,
        uint128 swappableTokenAmount,
        uint128 targetTokenAmount,
        uint128 fee
    );

    event ProvideLiquidity(
        uint256 msgSenderPubkey,
        uint256 liquidityTokensAmount,
        uint128 firstTokenAmount,
        uint128 secondTokenAmount
    );

    event WithdrawLiquidity(
        uint256 msgSenderPubkey,
        uint256 liquidityTokensAmount,
        uint128 firstTokenAmount,
        uint128 secondTokenAmount
    );
}