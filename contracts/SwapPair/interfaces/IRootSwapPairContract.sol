// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;

import './ISwapPairInformation.sol';
import './IServiceInformation.sol';

interface IRootSwapPairContract is ISwapPairInformation, IServiceInformation {
    // Deploy of swap pair
    function deploySwapPair(address tokenRootContract1, address tokenRootContract2) external returns (address);

    // Getting information about swap pairs
    function checkIfPairExists(address tokenRootContract1, address tokenRootContract2) external view returns (bool);

    // Getting service information
    // Expected to be run locally
    function getServiceInformation() external view returns (ServiceInfo);

    // Getting information about swap pair
    function getPairInfo(address tokenRootContract1, address tokenRootContract2) external view returns(SwapPairInfo);
}