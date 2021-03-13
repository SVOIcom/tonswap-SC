pragma ton-solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

contract TestAutoBalance {
    uint initialPay = 100 milli;
    uint static _randomNonce;

    constructor() public {
        tvm.accept();
    }

    function heavyFunction() external {
        uint128 balance = address(this).balance;
        tvm.accept();
        string asdf  = format("{}{}{}", address(this),address(this),address(this));
        TestAutoBalance(this).rebalance(balance);
    }

    function rebalance(uint128 b) external {
        require(msg.sender == address(this));
        if (b < address(this).balance+initialPay) 
            initialPay = initialPay * 997 / 1000;
        else
            initialPay = initialPay * 1008 / 1000;
    }

    function getBalance() external returns(uint) {
        return initialPay;
    }
}