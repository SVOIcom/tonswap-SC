pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

contract TONStorage {
    uint static _randomNonce;
    uint owner;
    uint stage = 0;
    constructor() public {
        tvm.accept();
        owner = msg.pubkey();
    }

    function sendTONTo(address dest, uint128 amount) external {
        tvm.accept();
        TvmBuilder bb;
        bb.store(tvm.pubkey());
        TvmCell b = bb.toCell();
        dest.transfer(amount, false, 0, b);
    }

    function getPk() external returns(uint) {
        return tvm.pubkey();
    }

    function getPkCell() external returns(TvmCell) {
        TvmBuilder builder;
        builder.store(format("{}", tvm.pubkey()));
        return builder.toCell();
    }

    function tf(TvmCell tc) external returns(string) {
        TvmSlice ts = tc.toSlice();
        return ts.decode(string);
    }

    function stoiTest(string a) external returns(uint, bool) {
        return stoi(a);
    }
}