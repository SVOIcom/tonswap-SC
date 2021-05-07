pragma ton-solidity ^0.39.0;
import '../../interfaces/swapPair/ISwapPairInformation.sol';

library SwapPairConstants {
    // Balance management and cost information
    uint128 constant tip3SendDeployGrams = 0.5 ton;
    uint128 constant tip3DeployGrams = 0.2 ton;

    // We don't want to risk, this is one-time procedure
    // Extra wallet's tons will be transferred with first token transfer operation
    // Yep, there are transfer losses, but they are pretty small
    uint128 constant walletInitialBalanceAmount = 1000 milli;
    uint128 constant walletDeployMessageValue   = 1500 milli;

    uint128 constant sendToTIP3TokenWallets = 110 milli;
    uint128 constant sendToRootToken        = 500 milli;

    // fee constants
    uint128 constant feeNominator = 997;
    uint128 constant feeDenominator = 1000;

    // TIP-3 root contract parameters
    uint8 constant tip3LpDecimals = 0;
    uint8 constant contractFullyInitialized = 4;

    // Information about required payload size
    uint16 constant payloadWithdrawBits = 16;
    uint8  constant payloadWithdrawRefs = 0;

    // Minimal required K to start swap pair operation
    uint256 constant kMin = 0;

    // Id of operations
    uint8 constant SwapPairOperation = 0;
    uint8 constant ProvideLiquidity  = 1;
    uint8 constant ProvideLiquidityOneToken = 2;
    uint8 constant WithdrawLiquidity = 3;
    uint8 constant WithdrawLiquidityOneToken = 4;

    // Operation TvmCell size
    uint16 constant SwapOperationBits = 267;
    uint8  constant SwapOperationRefs = 0;
    uint16 constant WithdrawOperationBits = 534;
    uint8  constant WithdrawOperationRefs = 1;
    uint16 constant WithdrawOneOperationBits = 267;
    uint8  constant WithdrawOneOperationRefs = 0;
    uint16 constant ProvideLiquidityBits = 267;
    uint8  constant ProvideLiquidityRefs = 0;
    uint16 constant ProvideLiquidityOneBits = 267;
    uint8  constant ProvideLiquidityOneRefs = 0;

    string constant swapFallbackPhrase = "Provided token amount is not enough for swap. Results in 0 tokens received."; 
}