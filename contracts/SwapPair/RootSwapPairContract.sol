pragma ton-solidity ^0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import './interfaces/ISwapPairInformation.sol';
import './interfaces/IRootSwapPairContract.sol';
import './interfaces/IRootSwapPairUpgradePairCode.sol';
import './interfaces/IServiceInformation.sol';
import './interfaces/IUpgradeSwapPairCode.sol';
import './libraries/RootSwapPairContractErrors.sol';
import './SwapPairContract.sol';

contract RootSwapPairContract is
    IRootSwapPairUpgradePairCode,
    IRootSwapPairContract 
{
    //============Static variables============

    // For debug purposes
    uint256 static _randomNonce;
    // Owner public key
    uint256 static ownerPubkey;

    //============Constants============

    // 1 ton required for swap pair
    // 2x1 ton required for swap pair wallets deployment
    // 2x1 + 2x0.2 required for initial stage of swap pair 
    // The rest stays at swap pair contract balance
    uint128 constant sendToNewSwapPair = 10 ton;

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

    // Information about user balances
    mapping (uint256 => uint128) userTONBalances;

    //============Constructor===========

    constructor(
        TvmCell spCode,
        uint32 spCodeVersion,
        uint256 minMsgValue,
        uint256 contractSP
    ) public {
        tvm.accept();
        creationTimestamp = now;
        // Setting code
        swapPairCode = spCode;
        swapPairCodeVersion = spCodeVersion;
        // Setting payment options
        minMessageValue = minMsgValue > sendToNewSwapPair ? minMsgValue : sendToNewSwapPair * 103/100;
        contractServicePayment = contractSP;
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
            RootSwapPairContractErrors.ERROR_PAIR_ALREADY_EXISTS, 
            RootSwapPairContractErrors.ERROR_PAIR_ALREADY_EXISTS_MSG
        );
        tvm.accept();

        uint256 currentTimestamp = now; 

        address contractAddress = new SwapPairContract{
            value: sendToNewSwapPair,
            varInit: {
                token1: tokenRootContract1,
                token2: tokenRootContract2,
                swapPairID: uniqueID
            },
            code: swapPairCode
        }(address(this), msg.pubkey());

        // Storing info about deployed swap pair contracts 
        SwapPairInfo info = SwapPairInfo(
            address(this),
            tokenRootContract1,
            tokenRootContract2,
            address.makeAddrStd(0, 0),
            address.makeAddrStd(0, 0),
            msg.pubkey(),
            currentTimestamp,
            contractAddress,
            uniqueID,
            swapPairCodeVersion
        );

        swapPairDB.add(uniqueID, info);

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
        require(msg.value > minMessageValue);
        TvmSlice ts = msg.data;
        uint pubkey = ts.decode(uint);
        userTONBalances[pubkey] += msg.value;
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
            RootSwapPairContractErrors.ERROR_PAIR_DOES_NOT_EXIST, 
            RootSwapPairContractErrors.ERROR_PAIR_DOES_NOT_EXIST_MSG
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
            RootSwapPairContractErrors.ERROR_CODE_IS_NOT_UPDATED_OR_IS_DOWNGRADED,
            RootSwapPairContractErrors.ERROR_CODE_IS_NOT_UPDATED_OR_IS_DOWNGRADED_MSG
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
        onlyPairDeployer(uniqueID) 
    {
        tvm.accept();
        SwapPairInfo info = swapPairDB.at(uniqueID);
        require(
            info.swapPairCodeVersion < swapPairCodeVersion, 
            RootSwapPairContractErrors.ERROR_CODE_IS_NOT_UPDATED_OR_IS_DOWNGRADED,
            RootSwapPairContractErrors.ERROR_CODE_IS_NOT_UPDATED_OR_IS_DOWNGRADED_MSG
        );
        IUpgradeSwapPairCode(info.swapPairAddress).updateSwapPairCode(swapPairCode, swapPairCodeVersion);
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
            RootSwapPairContractErrors.ERROR_MESSAGE_SENDER_IS_NOT_OWNER,
            RootSwapPairContractErrors.ERROR_MESSAGE_SENDER_IS_NOT_DEPLOYER_MSG
        );
        _;
    }

    modifier onlyPaid() {
        require(
            msg.value >= minMessageValue ||
            userTONBalances[msg.pubkey()] >= minMessageValue ||
            msg.pubkey() == ownerPubkey, 
            RootSwapPairContractErrors.ERROR_MESSAGE_VALUE_IS_TOO_LOW,
            RootSwapPairContractErrors.ERROR_MESSAGE_VALUE_IS_TOO_LOW_MSG
        );
        _;
    }

    modifier pairWithTokensDoesNotExist(address t1, address t2) {
        uint256 uniqueID = t1.value^t2.value;
        optional(SwapPairInfo) pairInfo = swapPairDB.fetch(uniqueID);
        require(
            !pairInfo.hasValue(), 
            RootSwapPairContractErrors.ERROR_PAIR_ALREADY_EXISTS,
            RootSwapPairContractErrors.ERROR_PAIR_ALREADY_EXISTS_MSG
        );
        _;
    }

    modifier pairExists(uint256 uniqueID, bool exists) {
        optional(SwapPairInfo) pairInfo = swapPairDB.fetch(uniqueID);
        require(
            pairInfo.hasValue() == exists, 
            RootSwapPairContractErrors.ERROR_PAIR_DOES_NOT_EXIST,
            RootSwapPairContractErrors.ERROR_PAIR_DOES_NOT_EXIST_MSG
        );
        _;
    }

    modifier onlyPairDeployer(uint256 uniqueID) {
        SwapPairInfo spi = swapPairDB.at(uniqueID);
        require(
            spi.deployerPubkey == msg.pubkey() || 
            ownerPubkey == msg.pubkey(), 
            RootSwapPairContractErrors.ERROR_MESSAGE_SENDER_IS_NOT_DEPLOYER,
            RootSwapPairContractErrors.ERROR_MESSAGE_SENDER_IS_NOT_DEPLOYER_MSG
        );
        _;
    }
}