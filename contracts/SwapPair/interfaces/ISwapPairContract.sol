// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;

import './ISwapPairInformation.sol';

interface ISwapPairContract is ISwapPairInformation   {
    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) external;

    function swap(address swappableTokenRoot,  uint128 swappableTokenAmount) external;

    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) external view returns (uint256 rate);

    function addLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) external;

    function getCreationTimestamp() external view returns (uint256 creationTimestamp);
    
    function getPairInfo() external returns (SwapPairInfo info);


}
