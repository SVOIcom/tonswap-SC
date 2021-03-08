pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

interface ISwapPairDebug {
    
    //============DEBUG============

    struct _DebugLPInfo {
        address token1;
        address token2;
        uint256 token1LPAmount;
        uint256 token2LPAmount;
    }

    struct _DebugERInfo {
        uint256 oldK;
        uint256 newK;

        uint128 swappableTokenAmount;
        uint128 targetTokenAmount;
        uint128 fee;

        uint128 oldFromPool;
        uint128 oldToPool;

        uint128 newFromPool;
        uint128 newToPool;
    }

    function _getLiquidityPoolTokens() external view returns (_DebugLPInfo dlpi);

    function _getUserLiquidityPoolTokens() external view returns (_DebugLPInfo dlpi);

    // function _getExchangeRateSimulation(uint256 token1, uint256 token2, uint256 swapToken1, uint256 swapToken2) external view returns (_DebugERInfo deri);

    // Тк изначально на контракте нет ликвидности, добавил возможность руками выставить на этом тесте (через костыль, но всё же)
    function _getExchangeRateSimulation(address swappableTokenRoot, uint128 swappableTokenAmount, uint128 fromLP, uint128 toLP) external returns (_DebugERInfo deri);

}