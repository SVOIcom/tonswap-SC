pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

contract Giver {
    mapping (uint256 => bool) allowedPubkeys;

    constructor() public {
        tvm.accept();
        allowedPubkeys.add(msg.pubkey(), true);
    }

    function addAllowedPubkey(uint256 pubkey) public pubkeyInAllowed {
        tvm.accept();
        if (allowedPubkeys.exists(pubkey)) {
            allowedPubkeys.replace(pubkey, true);
        } else {
            allowedPubkeys.add(pubkey, true);
        }
    }

    function removeAllowedPubkey(uint256 pubkey) public pubkeyInAllowed {
        tvm.accept();
        if (allowedPubkeys.exists(pubkey)) {
            allowedPubkeys.replace(pubkey, false);
        } else {
            allowedPubkeys.add(pubkey, false);
        }
    }

    function sendGrams(address dest, uint64 amount) public view pubkeyInAllowed {
        // require(address(this).balance > amount, 101);
        tvm.accept();
        dest.transfer({value: amount, bounce: false});
    }
    
    modifier pubkeyInAllowed() {
        require(allowedPubkeys.at(msg.pubkey()) == true, 100);
        _;
    }
}
