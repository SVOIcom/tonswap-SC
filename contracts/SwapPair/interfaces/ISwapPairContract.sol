// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;

import './ISwapPairInformation.sol';

interface ISwapPairContract is ISwapPairInformation   {
    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) public;

    function swap(address swappableTokenRoot,  uint128 swappableTokenAmount) public;

    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) view returns (uint256 rate);

    function addLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) public;

    function getCreationTimestamp() public view returns (uint256 creationTimestamp);
    
    function getPairInfo() public returns (SwapPairInfo info);


}
