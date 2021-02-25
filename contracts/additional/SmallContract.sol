pragma solidity >= 0.6.0;

contract SmallContract {
    uint static _randomNonce;
    constructor() public {
        tvm.accept();
    }

    function getValue() external view returns (uint value) {
        tvm.accept();
        value = _randomNonce;
    }
}