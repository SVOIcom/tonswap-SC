// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './ISwapPairInformation.sol';

interface ISwapPairContract is ISwapPairInformation {
    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) external;

    function swap(address swappableTokenRoot,  uint128 swappableTokenAmount) external;

    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) external view returns (uint256 rate);

    function addLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) external;

    function removeLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) external;

    function getCreationTimestamp() external view returns (uint256 creationTimestamp);

    function getPairInfo() external view returns (SwapPairInfo info);

    function getUserBalance() external view returns (UserBalanceInfo ubi);

    //============DEBUG============

    struct _DebugLPInfo {
        address token1;
        address token2;
        uint256 token1LPAmount;
        uint256 token2LPAmount;
    }

    struct _DebugERInfo {
        uint256 numerator;
        uint256 denominator;
        uint256 exchangeResultToken1;
        uint256 exchangeResultToken2;
    }

    function _getLiquidityPoolTokens() external view returns (_DebugLPInfo dlpi);

    function _getUserLiquidityPoolTokens() external view returns (_DebugLPInfo dlpi);

    function _getExchangeRateSimulation(uint256 token1, uint256 token2, uint256 swapToken1, uint256 swapToken2) external view returns (_DebugERInfo deri);
}
