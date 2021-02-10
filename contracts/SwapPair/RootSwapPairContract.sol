// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import './ISwapPairInformation.sol';
import './IRootSwapPairContract.sol';
import './IRootSwapPairUpgradePairCode.sol';
import './IServiceInformation.sol';
import './SwapPairContract.sol';

contract RootSwapPairContract is 
    ISwapPairInformation, 
    IServiceInformation,
    IRootSwapPairContract, 
    IRootSwapPairUpgradePairCode 
{
    // Code of swap pair info
    TvmCell static swapPairCode;
    SwapPairCodeVersion static swapPairCodeVersion;
    // Owner public key
    uint256 static ownerPubkey;
    // Minimum required message value
    uint256 static minMessageValue;
    uint256 static commission;

    // Logic time of root contract creation
    uint256 creationTimestamp;
    
    // Information about deployed swap pairs
    // Required because we want only unique swap pairs
    mapping (uint256 => SwapPairContract) swapPairDB;

    uint8 error_message_sender_is_not_deployer = 100;
    uint8 error_pair_does_not_exist            = 101;
    uint8 error_pair_already_exists            = 102;
    uint8 error_message_value_is_too_low       = 103;

    /**
     * Пока что - просто задание публичного ключа
     */
    constructor() public {
        tvm.accept();
        creationTimestamp = now;
    }

    /**
     * Deploy swap pair with specified address of token root contract
     * @param tokenRootContract1 Address of token root contract
     * @param tokenRootContract2 Address of token root contract
     */
    function deploySwapPair(
        address tokenRootContract1, 
        address tokenRootContract2
    ) external override onlyPaid returns (address) {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        
        // TODO: условия когда можно начинать выполнение контракта
        require( (!pairInfoStorage.exists(uniqueID)) || (uniqueID != 0), error_pair_already_exitst);
        
        // TODO: управление балансом, чтобы контракт не умер в мучениях от недостатка тона в крови
        // Допустим что новой паре необходимо изначально 2 тона, + 0.3 на выполнение
        require(msg.value > minMessageValue, error_message_value_is_too_low);
        tvm.rawReserve(msg.value - (msg.value - minMessageValue), 2);
            

        uint256 currentTimestamp = now;

        // Нужны параметры для деплоя контракта
        address contractAddress = new SwapPairContract{
            value: 2 ton,
            varInit: {
                token1: tokenRootContract1,
                token2: tokenRootCOntract2,
                swapPairDeployer: msg.sender,
                swapPairID: uniqueID,
                timestamp: currentTimestamp
            },
            bounce: true
        }();

        if (contractAddress.value != 0) {
            SwapPairInfo info = SwapPairInfo(
                tokenRootContract1,
                tokenRootContract2,
                msg.pubkey(),
                currentTimestamp,
                contractAddress,
                uniqueID
            );
            swapPairDB.add(uniqueID, info);
        }

        return contractAddress;
    }

    /**
     * Check if pair exists
     * @param tokenRootContract1 Address of token root contract
     * @param tokenRootContract2 Address of token root contract
     */
    function checkIfPairExists(
        address tokenRootContract1, 
        address tokenRootContract2
    ) external view override returns(bool) {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        return swapPairDB.exists(uniqueID);
    }

    function getServiceInformation() external view override returns (ServiceInfo) {
        return ServiceInfo(
            ownerPubkey,
            address(this).balance,
            creationTimestamp,
            swapPairCodeVersion,
            swapPairCode
        );
    }

    function setSwapPairCode(
        TvmCell code, 
        SwapPairCodeVersion codeVersion
    ) external override onlyOwner {
        tvm.accept();
        swapPairCode = code;
        swapPairCodeVersion = codeVersion;
    }

    function upgradeSwapPair(uint256 uniqueID) external onlyPairDeployer(uniqueID) pairExists(uniqueID) {
        // TODO: update magic
    }

    modifier onlyOwner() {
        require(msg.sender == ownerPubkey, 100);
        _;
    }

    modifier onlyPaid() {
        require(msg.value >= minMessageValue);
        _;
    }

    modifier pairExists(uint256 uniqueID) {
        optional(SwapPairInfo) pairInfo = swapPairDB.fetch(uniqueID));
        require(pairInfo.hasValue(), error_pair_does_not_exist);
        _;
    }

    modifier onlyPairDeployer(uint256 uniqueID) {
        SwapPairInfo spi = pairInfo.at(uniqueID);
        require(spi.deployerPubkey == msg.pubkey(), error_message_sender_is_not_deployer);
        _;
    }
}