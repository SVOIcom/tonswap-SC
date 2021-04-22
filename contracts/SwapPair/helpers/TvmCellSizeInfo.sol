pragma ton-solidity ^0.39.0;

import '../interfaces/swapPair/ISwapPairInformation.sol';
import '../libraries/swapPair/SwapPairConstants.sol';

contract TvmCellSizeInfo {
    constructor() public {
        tvm.accept();
    }

    function getSwapSizeInfo() public pure returns (uint16, uint8) {
        TvmBuilder tb; 
        tb.store(address.makeAddrStd(0,0));
        TvmSlice tc = tb.toSlice();
        return (tc.bits(), tc.refs());
    }

    function getWithdrawInfo() public pure returns (uint16, uint8, uint16, uint8) {
        TvmBuilder tb;
        tb.store(
            address.makeAddrStd(0,0),
            address.makeAddrStd(0,0)
        );
        TvmBuilder tb1;
        tb1.store(
            address.makeAddrStd(0,0),
            address.makeAddrStd(0,0)
        );

        tb.storeRef(tb1);
        TvmSlice tc = tb.toSlice();
        TvmSlice tc1 = tb1.toSlice();
        return (tc.bits(), tc.refs(), tc1.bits(), tc1.refs());
    }

    function getProvideInfo() public pure returns (uint16, uint8) {
        TvmBuilder tb; 
        tb.store(address.makeAddrStd(0,0));
        TvmSlice tc = tb.toSlice();
        return (tc.bits(), tc.refs());
    }
}