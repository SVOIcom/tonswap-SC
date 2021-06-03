pragma ton-solidity ^0.39.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import '../swapPair/ISwapPairInformation.sol';
import './IServiceInformation.sol';

interface IRootSwapPairContract is ISwapPairInformation, IServiceInformation {
    
    function deploySwapPair(address tokenRootContract1, address tokenRootContract2) external returns (address);
    
    function checkIfPairExists(address tokenRootContract1, address tokenRootContract2) external view returns (bool);

    function getServiceInformation() external view returns (ServiceInfo);

    function getAllSwapPairsID() external view returns (uint256[] ids);

    function getPairInfoByID(uint256 uniqueID) external view returns(SwapPairInfo swapPairInfo);

    function getPairInfo(address tokenRootContract1, address tokenRootContract2) external view returns(SwapPairInfo);

    function setTIP3DeployerAddress(address tip3Deployer_) external;

    function getFutureSwapPairAddress(address tokenRootContract1, address tokenRootContract2) external view returns(address);

    event DeploySwapPair(address swapPairAddress, address tokenRootContract1, address tokenRootContract2);

    event SwapPairInitialized(address swapPairAddress);
}