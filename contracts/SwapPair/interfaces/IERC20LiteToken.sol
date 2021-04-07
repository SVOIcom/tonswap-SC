pragma ton-solidity ^0.39.0;

pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

interface IERC20LiteToken {
    function transfer(uint256 receiver, uint256 amount) external;
    function getBalance(uint256 pubkey) external returns(uint256);
}