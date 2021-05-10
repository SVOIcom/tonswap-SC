pragma ton-solidity ^0.39.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface ISwapPairInformation {
    // General swap pair information
    struct SwapPairInfo {
        address rootContract;           // address of swap pair deployer address
        address tokenRoot1;             // address of first TIP-3 token root
        address tokenRoot2;             // address of second TIP-3 token root
        address lpTokenRoot;            // address of deployed LP token root
        address tokenWallet1;           // address of first TIP-3 token wallet
        address tokenWallet2;           // address of second TIP-3 token wallet
        address lpTokenWallet;          // address of deployed LP token wallet
        uint256 deployTimestamp;        // when the contract was deployed
        address swapPairAddress;        // address of swap pair
        uint256 uniqueId;               // unique id of swap pair
        uint32  swapPairCodeVersion;    // code version of swap pair. can be upgraded using root contract
    }

    // Information about swap operation result
    struct SwapInfo {
        uint128 swappableTokenAmount; // token amount that will be swapped
        uint128 targetTokenAmount;    // root token contract of token to swap 
        uint128 fee;                  // fee for swap operation
    }

    // Internal information about swap operation
    struct _SwapInfoInternal {
        uint8 fromKey;              // Id of token that will be used for swap
        uint8 toKey;                // Id of token that will be swapped to
        uint128 newFromPool;        // new pool volume
        uint128 newToPool;          // new pool volume
        uint128 targetTokenAmount;  // amount of tokens acquired after swap
        uint128 fee;                // fee of operation
    }

    // Information for token withdraw
    struct LPWithdrawInfo {
        address tr1;    // root of first token wallet
        address tw1;    // first token wallet
        address tr2;    // root of seconde token wallet
        address tw2;    // second token wallet
    }

    // Information for liquidity providing, stored inside contract
    struct LPProvidingInfo {
        address walletOwner;    // address of token wallet owner
        uint256 walletPubkey;   // pubkey of token wallet owner
        address w1;             // address of first token wallet
        uint128 a1;             // amount of tokens provided
        address w2;             // address of second token wallet
        uint128 a2;             // amount of tokens provided
    }

    // Struct used for internal routing
    struct UnifiedOperation {
        uint8 operationId;      // Id of operation
        TvmCell operationArgs;  // Arguments for operation stored in TvmCell
    }
}