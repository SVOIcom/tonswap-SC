// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import './interfaces/ISwapPairInformation.sol';
import './interfaces/IRootSwapPairContract.sol';
import './interfaces/IRootSwapPairUpgradePairCode.sol';
import './interfaces/IServiceInformation.sol';
import './SwapPairContract.sol';

contract RootSwapPairContract is
    IRootSwapPairUpgradePairCode,
    IRootSwapPairContract 
{
    uint256 static _randomNonce;

    // Code of swap pair info
    TvmCell static swapPairCode;
    SwapPairCodeVersion static swapPairCodeVersion;
    // Owner public key
    uint256 static ownerPubkey;
    // Minimum required message value
    uint256 static minMessageValue;
    uint256 static contractServicePayment;

    // Logic time of root contract creation
    uint256 creationTimestamp;
    
    // Information about deployed swap pairs
    // Required because we want only unique swap pairs
    mapping (uint256 => SwapPairInfo) swapPairDB;

    uint8 error_message_sender_is_not_deployer       = 100;
    uint8 error_message_sender_is_not_owner          = 101;
    uint8 error_pair_does_not_exist                  = 102;
    uint8 error_pair_already_exists                  = 103;
    uint8 error_message_value_is_too_low             = 104;
    uint8 error_code_is_not_updated_or_is_downgraded = 105;

    /**
     * Пока что - просто задание публичного ключа
     */
    constructor() public {
        tvm.accept();
        creationTimestamp = now;
    }

    //#########################################################//
    // External functions

    /**
     * Deploy swap pair with specified address of token root contract
     * @param tokenRootContract1 Address of token root contract
     * @param tokenRootContract2 Address of token root contract
     */
    function deploySwapPair(
        address tokenRootContract1, 
        address tokenRootContract2
    ) external override pairWithTokensDoesNotExist(tokenRootContract1, tokenRootContract2) returns (address) {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        
        // TODO: управление балансом, чтобы контракт не умер в мучениях от недостатка тона в крови
        // Допустим что новой паре необходимо изначально 2 тона, + 0.3 на выполнение
        //For testing purposes
        tvm.accept();
        // tvm.rawReserve(msg.value - (msg.value - minMessageValue - contractServicePayment), 2);
            
        // Time of contract deploy
        uint256 currentTimestamp = now; 

        // Нужны параметры для деплоя контракта
        address contractAddress = new SwapPairContract{
            value: 2 ton,
            varInit: {
                token1: tokenRootContract1,
                token2: tokenRootContract2,
                swapPairID: uniqueID
            },
            code: swapPairCode
        }(address(this), msg.pubkey());

        SwapPairInfo info = SwapPairInfo(
            tokenRootContract1,
            tokenRootContract2,
            msg.pubkey(),
            currentTimestamp,
            contractAddress,
            uniqueID
        );
        swapPairDB.add(uniqueID, info);

        return contractAddress;
    }

    function getXOR(
        address tokenRootContract1, 
        address tokenRootContract2
    ) external returns (uint256) {
        return tokenRootContract1.value^tokenRootContract2.value;
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

    /**
     * Check if pair exists
     * @param tokenRootContract1 Address of token root contract
     * @param tokenRootContract2 Address of token root contract
     */
    function getPairInfo(
        address tokenRootContract1, 
        address tokenRootContract2
    ) external view override returns(SwapPairInfo) {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        optional(SwapPairInfo) spi = swapPairDB.fetch(uniqueID);
        require(spi.hasValue(), error_pair_does_not_exist);
        return spi.get();
    }


    /**
     * Get service information about root contract
     */
    function getServiceInformation() external view override returns (ServiceInfo) {
        return ServiceInfo(
            ownerPubkey,
            address(this).balance,
            creationTimestamp,
            swapPairCodeVersion,
            swapPairCode
        );
    }

    /**
     * Set new swap pair code
     */
    function setSwapPairCode(
        TvmCell code, 
        SwapPairCodeVersion codeVersion
    ) external override onlyOwner {
        require(
            codeVersion.contractCodeVersion > swapPairCodeVersion.contractCodeVersion, 
            error_code_is_not_updated_or_is_downgraded
        );
        tvm.accept();
        swapPairCode = code;
        swapPairCodeVersion = codeVersion;
    }

    function upgradeSwapPair(uint256 uniqueID) external view override pairExists(uniqueID, true) onlyPairDeployer(uniqueID) {
        tvm.accept();
        // TODO: update magic
    }

    //#########################################################//
    // Private functions

    function _calculateSwapPairContractAddress(
        address tokenRootContract1,
        address tokenRootContract2,
        uint256 uniqueID
    ) private view inline returns(address) {
        TvmCell stateInit = tvm.buildStateInit({
            contr: SwapPairContract,
            varInit: {
                token1: tokenRootContract1,
                token2: tokenRootContract2,
                swapPairID: uniqueID
            },
            code: swapPairCode
        });

        return address(tvm.hash(stateInit));
    }

    //#########################################################//
    // Modifiers

    modifier onlyOwner() {
        require(msg.pubkey() == ownerPubkey, error_message_sender_is_not_owner);
        _;
    }

    modifier onlyPaid() {
        require(msg.value >= minMessageValue, error_message_value_is_too_low);
        _;
    }

    modifier pairWithTokensDoesNotExist(address t1, address t2) {
        uint256 uniqueID = t1.value^t2.value;
        optional(SwapPairInfo) pairInfo = swapPairDB.fetch(uniqueID);
        require(!pairInfo.hasValue(), error_pair_already_exists);
        _;
    }

    modifier pairExists(uint256 uniqueID, bool exists) {
        optional(SwapPairInfo) pairInfo = swapPairDB.fetch(uniqueID);
        require(pairInfo.hasValue() == exists, error_pair_does_not_exist);
        _;
    }

    modifier onlyPairDeployer(uint256 uniqueID) {
        SwapPairInfo spi = swapPairDB.at(uniqueID);
        require(spi.deployerPubkey == msg.pubkey(), error_message_sender_is_not_deployer);
        _;
    }
}