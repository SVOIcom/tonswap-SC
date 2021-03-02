pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

contract Giver {
    mapping (uint256 => bool) allowedPubkeys;

    constructor() public {
        tvm.accept();
        allowedPubkeys[msg.pubkey()] = true;
    }

    function addAllowedPubkey(uint256 pubkey) public allowedPubkey {
        tvm.accept();
        allowedPubkeys[pubkey] = true;
    }

    function removeAllowedPubkey(uint256 pubkey) public allowedPubkey {
        tvm.accept();
        allowedPubkeys[pubkey] = false;
    }

    function sendGrams(address dest, uint64 amount) public view allowedPubkey {
        require(address(this).balance > amount, 60);
        tvm.accept();
        dest.transfer(amount, false, 1);
    }
    
    modifier allowedPubkey() {
        require(allowedPubkeys[msg.pubkey()], 100);
        _;
    }
}
