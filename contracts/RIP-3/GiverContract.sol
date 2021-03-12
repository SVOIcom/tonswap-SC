pragma ton-solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;

contract GiverContract {
    constructor() {}

    function sendGrams(address dest, uint64 amount)
        external
    {
        tvm.accept();
        dest.transfer(amount);
    }
}