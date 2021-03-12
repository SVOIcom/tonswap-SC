pragma ton-solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

contract DevNetGiver {
    constructor() public {
        tvm.accept();
    }

    function sendGrams(address dest, uint64 amount) external pure {
        tvm.accept();
        address(dest).transfer({value: amount, bounce: false});
    }
}