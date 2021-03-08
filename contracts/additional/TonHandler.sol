pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

contract TONHandler {
    uint owner;
    constructor() public {
        tvm.accept();
        owner = msg.pubkey();
    }

    function sendTONTo(address dest, uint128 amount) external {
        tvm.accept();
        address(dest).transfer({value: amount});
    }
}