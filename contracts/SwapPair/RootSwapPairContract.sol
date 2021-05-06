pragma ton-solidity ^0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import './interfaces/swapPair/ISwapPairInformation.sol';
import './interfaces/rootSwapPair/IRootSwapPairContract.sol';
import './interfaces/rootSwapPair/IRootSwapPairUpgradePairCode.sol';
import './interfaces/rootSwapPair/IServiceInformation.sol';
import './interfaces/swapPair/IUpgradeSwapPairCode.sol';
import './libraries/rootSwapPair/RootSwapPairContractErrors.sol';
import './libraries/rootSwapPair/RootSwapPairConstants.sol';
import './SwapPairContract.sol';
contract RootSwapPairContract is
    IRootSwapPairUpgradePairCode,
    IRootSwapPairContract 
{
    //============Static variables============

    // For debug purposes and for multiple instances of contract
    uint256 static _randomNonce;
    // Owner public key
    uint256 static ownerPubkey;

    //============Used variables============

    // Swap pair code and it's version
    TvmCell swapPairCode;
    uint32  swapPairCodeVersion;
    // Minimum required message value
    uint256 minMessageValue;
    // Minimum comission for contract
    // This will be distributed if swap pair contract requires 
    uint256 contractServicePayment;

    // Logic time of root contract creation
    uint256 creationTimestamp;

    // TIP-3 token root contract deployer
    address tip3Deployer;
    
    // Information about deployed swap pairs
    // Required because we want only unique swap pairs
    mapping (uint256 => SwapPairInfo) swapPairDB;
    mapping (address => uint256) addressToUniqueID;

    // Information about user balances
    mapping (uint256 => uint128) userTONBalances;

    //============Constructor===========

    constructor(
        TvmCell spCode,
        uint32 spCodeVersion,
        uint256 minMsgValue,
        uint256 contractSP,
        address tip3Deployer_
    ) public {
        tvm.accept();
        creationTimestamp = now;
        // Setting code
        swapPairCode = spCode;
        swapPairCodeVersion = spCodeVersion;
        // Setting payment options
        minMessageValue = minMsgValue > RootSwapPairConstants.sendToNewSwapPair ? 
            minMsgValue : 
            RootSwapPairConstants.sendToNewSwapPair*RootSwapPairConstants.increaseNumerator/RootSwapPairConstants.increaseDenominator;
        contractServicePayment = contractSP;
        tip3Deployer = tip3Deployer_;
    }

    //============External functions============

    /**
     */
    function setTIP3DeployerAddress(
        address tip3Deployer_
    ) 
        external 
        override 
        onlyOwner
    {
        tvm.accept();
        tip3Deployer = tip3Deployer_;
    } 

    /**
     * Deploy swap pair with specified address of token root contract
     * @param tokenRootContract1 Address of token root contract
     * @param tokenRootContract2 Address of token root contract
     */
    function deploySwapPair(
        address tokenRootContract1, 
        address tokenRootContract2
    )   
        external 
        override
        onlyPaid 
        returns (address cA) 
    {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        require(
            !swapPairDB.exists(uniqueID), 
            RootSwapPairContractErrors.ERROR_PAIR_ALREADY_EXISTS
        );
        tvm.accept();

        uint256 currentTimestamp = now; 

        address contractAddress = new SwapPairContract{
            value: RootSwapPairConstants.sendToNewSwapPair,
            varInit: {
                token1: tokenRootContract1,
                token2: tokenRootContract2,
                swapPairID: uniqueID
            },
            code: swapPairCode
        }(address(this), msg.pubkey(), tip3Deployer);

        // Storing info about deployed swap pair contracts 
        SwapPairInfo info = SwapPairInfo(
            address(this),              // root contract
            tokenRootContract1,         // token root
            tokenRootContract2,         // token root
            address.makeAddrStd(0, 0),  // lp token root
            address.makeAddrStd(0, 0),  // token wallet
            address.makeAddrStd(0, 0),  // token wallet
            address.makeAddrStd(0, 0),  // lp token wallet
            msg.pubkey(),               // swap pair deployer
            currentTimestamp,           // creation timestamp
            contractAddress,            // address of swap pair
            uniqueID,                   // unique id of swap pair
            swapPairCodeVersion         // code version of swap pair
        );

        swapPairDB.add(uniqueID, info);
        addressToUniqueID.add(contractAddress, uniqueID);

        emit DeploySwapPair(contractAddress, tokenRootContract1, tokenRootContract2);

        return contractAddress;
    }

    //============Receive payments============

    receive() external {
        require(msg.value > minMessageValue);
        TvmSlice ts = msg.data;
        uint pubkey = ts.decode(uint);
        userTONBalances[pubkey] += msg.value;
    }

    fallback() external {
    }

    //============Get functions============

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
        require(
            spi.hasValue(), 
            RootSwapPairContractErrors.ERROR_PAIR_DOES_NOT_EXIST
        );
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

    function getFutureSwapPairAddress(
        address tokenRootContract1,
        address tokenRootContract2
    ) external view override returns(address) {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        return _calculateSwapPairContractAddress(tokenRootContract1, tokenRootContract2, uniqueID); 
    }

    //============Callback functions============

    function swapPairInitializedCallback(SwapPairInfo spi) external pairWithAddressExists(msg.sender) {
        swapPairDB[addressToUniqueID[msg.sender]] = spi;
        emit SwapPairInitialized(msg.sender);
    }

    //============Swap pair upgrade functionality============

    /**
     * Set new swap pair code
     */
    function setSwapPairCode(
        TvmCell code, 
        uint32 codeVersion
    ) external override onlyOwner {
        require(
            codeVersion > swapPairCodeVersion, 
            RootSwapPairContractErrors.ERROR_CODE_IS_NOT_UPDATED_OR_IS_DOWNGRADED
        );
        tvm.accept();
        swapPairCode = code;
        swapPairCodeVersion = codeVersion;

        emit SetSwapPairCode(codeVersion);
    }

    function upgradeSwapPair(uint256 uniqueID)
        external
        override
        pairExists(uniqueID, true)
    {
        SwapPairInfo info = swapPairDB.at(uniqueID);
        require(
            info.swapPairCodeVersion < swapPairCodeVersion, 
            RootSwapPairContractErrors.ERROR_CODE_IS_NOT_UPDATED_OR_IS_DOWNGRADED
        );
        require(
            msg.value > RootSwapPairConstants.requiredForUpgrade,
            RootSwapPairContractErrors.ERROR_MESSAGE_VALUE_IS_TOO_LOW
        );
        IUpgradeSwapPairCode(info.swapPairAddress).updateSwapPairCode{value: msg.value*3/4}(swapPairCode, swapPairCodeVersion);
        info.swapPairCodeVersion = swapPairCodeVersion;
        swapPairDB.replace(uniqueID, info);

        emit UpgradeSwapPair(uniqueID, swapPairCodeVersion);
    }

    //============Private functions============

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

    //============Modifiers============

    modifier onlyOwner() {
        require(
            msg.pubkey() == ownerPubkey, 
            RootSwapPairContractErrors.ERROR_MESSAGE_SENDER_IS_NOT_OWNER
        );
        _;
    }

    modifier onlyPaid() {
        require(
            msg.value >= minMessageValue ||
            userTONBalances[msg.pubkey()] >= minMessageValue ||
            msg.pubkey() == ownerPubkey, 
            RootSwapPairContractErrors.ERROR_MESSAGE_VALUE_IS_TOO_LOW
        );
        _;
    }

    modifier pairWithTokensDoesNotExist(address t1, address t2) {
        uint256 uniqueID = t1.value^t2.value;
        optional(SwapPairInfo) pairInfo = swapPairDB.fetch(uniqueID);
        require(
            !pairInfo.hasValue(), 
            RootSwapPairContractErrors.ERROR_PAIR_ALREADY_EXISTS
        );
        _;
    }

    modifier pairExists(uint256 uniqueID, bool exists) {
        optional(SwapPairInfo) pairInfo = swapPairDB.fetch(uniqueID);
        require(
            pairInfo.hasValue() == exists, 
            RootSwapPairContractErrors.ERROR_PAIR_DOES_NOT_EXIST
        );
        _;
    }

    modifier onlyPairDeployer(uint256 uniqueID) {
        SwapPairInfo spi = swapPairDB.at(uniqueID);
        require(
            spi.deployerPubkey == msg.pubkey() || 
            ownerPubkey == msg.pubkey(), 
            RootSwapPairContractErrors.ERROR_MESSAGE_SENDER_IS_NOT_DEPLOYER
        );
        _;
    }

    modifier pairWithAddressExists(address pairAddress) {
        require(
            addressToUniqueID.exists(pairAddress),
            RootSwapPairContractErrors.ERROR_PAIR_WITH_ADDRESS_DOES_NOT_EXIST
        );
        _;
    }
}