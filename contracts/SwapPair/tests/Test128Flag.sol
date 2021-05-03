pragma ton-solidity ^0.39.0;

contract Test128Flag {
    uint256 a;
    uint256 d;
    constructor() public {
        tvm.accept();
    }

    function test128Flag(uint256 b) external {
        this.c{flag:128, value: 0}(b);
        tvm.commit();
        a = b;
    }

    function c(uint256 b) external {
        tvm.accept();
        d = b;
    }

    function getA() external returns (uint256) {
        return a;
    }

    function getD() external returns (uint256) {
        return d;
    }
}