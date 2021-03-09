pragma solidity >= 0.6.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../SwapPair/interfaces/IRootSwapPairContract.sol';

contract PairDeployer {
    uint static _randomNonce;
    uint owner;
    address pairAddress_;
    address pairRoot_;

    constructor() public {
        tvm.accept();
        owner = msg.pubkey();
    }

    function deployPair(address pairRoot, address root1, address root2, uint128 grams) public onlyOwner {
        tvm.accept();
        pairRoot_ = pairRoot;
        IRootSwapPairContract(pairRoot).deploySwapPair{value: grams, callback: receiveAddress}(root1, root2);
    }

    function receiveAddress(address pairAddress) public onlyPairRoot {
        pairAddress_ = pairAddress;
    }

    function getPairAddress() public returns(address) {
        return pairAddress_;
    }

    modifier onlyOwner() {
        require(msg.pubkey() == owner);
        _;
    }

    modifier onlyPairRoot() {
        require(msg.sender == pairRoot_);
        _;
    }
}