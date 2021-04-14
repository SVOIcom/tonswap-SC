pragma ton-solidity ^0.39.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface ISwapPairInformation {
    struct SwapPairInfo {
        address rootContract;
        address tokenRoot1;
        address tokenRoot2;
        address lpTokenRoot;
        address tokenWallet1;
        address tokenWallet2;
        address lpTokenWallet;
        uint256 deployerPubkey;
        uint256 deployTimestamp;
        address swapPairAddress; 
        uint256 uniqueId;
        uint32  swapPairCodeVersion;
    }

    struct UserBalanceInfo {
        address tokenRoot1;
        address tokenRoot2;
        uint128 tokenBalance1;
        uint128 tokenBalance2;
    }

    struct UserPoolInfo {
        address tokenRoot1;
        address tokenRoot2;
        uint256 liquidityTokensMinted;
        uint128 lpToken1;
        uint128 lpToken2;
    }

    struct SwapInfo {
        uint128 swappableTokenAmount;
        uint128 targetTokenAmount;
        uint128 fee;
    }

    struct _SwapInfoInternal {
        uint8 fromKey;
        uint8 toKey;
        uint128 newFromPool;
        uint128 newToPool;
        uint128 targetTokenAmount;
        uint128 fee;
    }

    struct LPWithdrawInfo {
        address tr1;
        address tw1;
        address tr2;
        address tw2;
    }

    struct LPWithdrawResult {
        address tokenWallet1;
        uint128 tokenWallet1Amount;
        address tokenWallet2;
        uint128 tokenWallet2Amount;
    }

    // TODO: добавить/доделать структуру для унифицированных операций
    struct UnifiedOperation {
        uint8 operationId;
        TvmCell operationArgs;
    }

    struct OperationSizeRequirements {
        uint16 bits;
        uint8 refs;
    }
}