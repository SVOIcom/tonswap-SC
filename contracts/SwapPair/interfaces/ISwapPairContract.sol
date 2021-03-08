pragma solidity >= 0.6.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './ISwapPairInformation.sol';

interface ISwapPairContract is ISwapPairInformation {
    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) external;

    function swap(address swappableTokenRoot,  uint128 swappableTokenAmount) external  returns (SwapInfo _swapInfo);

    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) external view returns (SwapInfo _swapInfo);

    function provideLiquidity(uint128 maxFirstTokenAmount, uint128 maxSecondTokenAmount) external returns (uint128 providedFirstTokenAmount, uint128 providedSecondTokenAmount);

    function withdrawLiquidity(uint128 minFirstTokenAmount, uint128 minSecondTokenAmount) external returns (uint128 withdrawedFirstTokenAmount, uint128 withdrawedSecondTokenAmount);

    function getCreationTimestamp() external view returns (uint256 creationTimestamp);

    function getPairInfo() external view returns (SwapPairInfo info);

    function getUserBalance(uint pubkey) external view returns (UserBalanceInfo ubi);
}