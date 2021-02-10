// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;

import './ISwapPairInformation.sol';
improt './IServiceInformation.sol';

interface IRootSwapPairContract is ISwapPairInformation {
    // Deploy of swap pair
    function deploySwapPair(address tokenRootContract1, address tokenRootContract2) external returns (address);

    // Getting information about swap pairs
    function checkIfPairExists(address tokenRootContract1, address tokenRootContract2) external view returns (bool);

    // Getting service information
    // Expected to be run locally
    function getServiceInformation() external view returns (ServiceInfo);
}