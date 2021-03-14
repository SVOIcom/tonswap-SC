pragma ton-solidity >= 0.6.0;
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

    struct _DebugSwapInfo {
        _DebugERInfo deri;

        uint128 oldFromUserBalance;
        uint128 oldToUserBalance;

        uint128 newFromUserBalance;
        uint128 newToUserBalance;
    }

    function _getLiquidityPoolTokens() external view returns (_DebugLPInfo dlpi);
    
    function _getExchangeRateSimulation(address swappableTokenRoot, uint128 swappableTokenAmount, uint128 fromLP, uint128 toLP) external returns (_DebugERInfo deri);

    function _simulateSwap(address swappableTokenRoot, uint128 swappableTokenAmount, uint128 fromLP, uint128 toLP, uint128 fromBalance, uint128 toBalance) external  returns (_DebugSwapInfo dsi);
}