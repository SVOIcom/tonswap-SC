pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

contract DevNetGiver {
    uint static _randomNonce;
    uint owner;
    constructor() public {
        tvm.accept();
        owner = msg.pubkey();
    }

    function sendGrams(address dest, uint64 amount) public onlyOwner {
        tvm.accept();
        address(dest).transfer({value: amount, bounce: false});
    }

    modifier onlyOwner() {
        require(msg.pubkey() == owner);
        _;
    }
}