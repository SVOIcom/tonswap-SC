// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;


interface ISwapPairContract  {
    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) public;

    function swap(address swappableTokenRoot,  uint128 swappableTokenAmount) public;

    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) view returns (uint256 rate);

    function addLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) public;

    function getCreationTimestamp() public view returns (uint256 creationTimestamp);

    function tokensReceivedCallback(
        address token_wallet,
        address token_root,
        uint128 amount,
        uint256 sender_public_key,
        address sender_address,
        address sender_wallet,
        address original_gas_to,
        uint128 updated_balance,
        TvmCell payload
    ) public;
}