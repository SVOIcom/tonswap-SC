pragma ton-solidity >= 0.6.0;

pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

interface IERC20LiteToken {
    function mint(uint256 pubkey, uint256 amount) external;
    function burn(uint256 pubkey, uint256 amount) external;
    function transfer(uint256 pubkey, uint256 amount) external;
    function getBalance(uint256 pubkey, uint256 amount) 
}