// Pre-alpha
pragma solidity >= 0.6.0;
pragma expire;
pragma time;

import './ISwapPairInformation.sol';
import './IRootSwapPairContract.sol';
import './IRootSwapPairUpgradePairCode.sol';
import './IServiceInformation.sol';
import './SwapPairContract.sol';

contract RootSwapPairContract is ISwapPairInformation, 
                                 IServiceInformation,
                                 IRootSwapPairContract, 
                                 IRootSwapPairUpgradePairCode {

    TvmCell static swapPairCode;
    uint256 ownerPubkey;
    uint256 creationTimestamp;
    uint256 minMessageValue;
    SwapPairCodeVersion swapPairCodeVersion;
    mapping (uint256 => SwapPairContract) swapPairDB;

    constructor() public {
        tvm.accept();
        ownerPubkey = msg.pubkey();    
    }

    function deploySwapPair(
        address tokenRootContract1, 
        address tokenRootContract2
    ) external override returns (address) {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        // TODO: условия когда можно начинать выполнение контракта
        if (pairInfoStorage.exists(uniqueID)) 
            revert();
        else
        // TODO: управление балансом, чтобы контракт не умер в мучениях от недостатка тона в крови
            tvm.rawReserve(1 ton, 2);

        // Нужны параметры для деплоя контракта
        address contractAddress = new SwapPairContract{value: 0.5 ton}();
        if (contractAddress.value != 0) {
            SwapPairInfo info = SwapPairInfo(
                tokenRootContract1,
                tokenRootContract2,
                msg.pubkey(),
                now,
                contractAddress,
                uniqueID
            );
            swapPairDB.add(uniqueID, info);
        }

        return contractAddress;
    }

    function checkIfPairExists(
        address tokenRootContract1, 
        address tokenRootContract2
    ) external override returns(bool) {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        return swapPairDB.exists(uniqueID);
    }

    function getServiceInformation() external override returns (ServiceInfo) {
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

    function upgradeSwapPair(uint256 uniqueID) external onlyPairDeployer(uniqueID) {
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

    modifier onlyPairDeployer(uint256 uniqueID) {
        optional(SwapPairInfo) pairInfo = swapPairDB.fetch(uniqueID);
        require(pairInfo.hasValue(), error_pair_does_not_exist);
        SwapPairInfo spi = pairInfo.get();
        require(pairInfo.deployerPubkey == msg.pubkey(), error_message_sender_is_not_deployer);
        _;
    }
}