pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface ITransferWalletContract {
    /* 
        TvmCell contains information:
        msg.sender - message sender address
        contractAddress - message receiver address
        tokens - amount of tokens transferred
        blockTimestamp - block logic time of message processing

        To encode parameters:
        TvmBuilder resultBuilder;
        resultBuilder.store(
            msg.sender,
            address(this),
            tokens,
            now
        );
        TvmCell = resultBuilder.toCell();

        To get these paramters, do this:
        TvmSlice resultSlice = TvmCellResult.toSlice();
        (address sender, address receiver, uint128 amount, uint timestamp) = resultSlice.
                decode(address, address, uint128, uint);
     */
    function internalTransferResult(TvmCell result) external;
}