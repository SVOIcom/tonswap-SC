pragma ton-solidity ^0.39.0;

import './Test128Flag.sol';

contract Proxy {
    constructor() public {
        tvm.accept();
    }

    function testFlag(address contractAddress, uint256 num) external {
        tvm.accept();
        Test128Flag(contractAddress).test128Flag{value: 1 ton, flag: 1}(num);
    }
}