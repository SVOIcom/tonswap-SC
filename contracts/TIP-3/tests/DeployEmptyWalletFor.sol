pragma solidity >= 0.6.0;

pragma AbiHeader expire;

import "../interfaces/IRootTokenContract.sol";

contract DeployEmptyWalletFor {

    uint256 static _randomNonce;
    address static root;

    uint256 latest_pubkey;
    address latest_addr;

    constructor() public {
        tvm.accept();
    }

    //key or addr
    function deployEmptyWalletFor(uint256 pubkey, address addr) external {
        tvm.accept();
        latest_pubkey = pubkey;
        latest_addr = addr;
        IRootTokenContract(root).deployEmptyWallet{
            value: 0.8 ton,
            callback: this.getAddress
        }(
            0.4 ton,
            pubkey,
            address.makeAddrStd(0, 0),
            address.makeAddrStd(0, 0)
        );
    }

    function getAddress(address a) external {
        tvm.accept();
    }

    function getLatestPublicKey() external view returns(uint256) {
        return latest_pubkey;
    }

    function getLatestAddr() external view returns(address) {
        return latest_addr;
    }

    function getRoot() external view returns(address) {
        return root;
    }

}
