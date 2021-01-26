pragma solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;

import "../interfaces/ITransferWalletCallback.sol";

contract TestContract is ITransferWalletCallback {
    address sender_;
    address receiver_;
    uint128 amount_;
    uint timestamp_;
    function internalTransferResult(TvmCell result) external 
    {
        tvm.accept();
        (sender_, receiver_, amount_, timestamp_) = decodeResultCell(result);
    }

    function decodeResultCell(TvmCell result) 
        internal 
        returns (address sender, address receiver, uint128 amount, uint timestamp)
    {
        TvmCell resultCell = result.toSlice();
        (sender, receiver, amount, timestamp) = resultCell.decode(address, address, uint128, uint);
   }

    function getResult()
        external
        view
        returns (address sender, address receiver, uint128 amount, uint timestamp)
    {
        tvm.accept();
        sender = sender_;
        receiver = receiver_;
        amount = amount_;
        timestamp = timestamp_;
    }
}