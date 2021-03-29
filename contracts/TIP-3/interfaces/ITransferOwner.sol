pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface ITransferOwner {
    function transferOwner(uint256 external_owner_pubkey_, address internal_owner_address_) external;
}
