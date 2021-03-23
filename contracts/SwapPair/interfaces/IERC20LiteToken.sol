pragma ton-solidity >= 0.6.0;

pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

interface IERC20LiteToken {
    function transfer(uint256 sender, uint256 receiver, uint256 amount) external;
}