pragma ton-solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import './interfaces/ISwapPairInformation.sol';
import './interfaces/IRootSwapPairContract.sol';
import './interfaces/IRootSwapPairUpgradePairCode.sol';
import './interfaces/IServiceInformation.sol';
import './interfaces/IUpgradeSwapPairCode.sol';
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
    // 2x0.4 ton required for swap pair wallets deployment
    // 0.2 required for initial stage of swap pair 
    uint128 constant sendToNewSwapPair = 10000 milli;

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
    
    // Information about deployed swap pairs
    // Required because we want only unique swap pairs
    mapping (uint256 => SwapPairInfo) swapPairDB;

    // Information about user balances
    mapping (uint256 => uint128) userTONBalances;

    //============Errors============

    uint8 error_message_sender_is_not_deployer       = 100; string constant error_message_sender_is_not_deployer_msg       = "Message sender is not deployer";
    uint8 error_message_sender_is_not_owner          = 101; string constant error_message_sender_is_not_owner_msg          = "Message sender is not owner";
    uint8 error_pair_does_not_exist                  = 102; string constant error_pair_does_not_exist_msg                  = "Swap pair does not exist";
    uint8 error_pair_already_exists                  = 103; string constant error_pair_already_exists_msg                  = "Swap pair already exists";
    uint8 error_message_value_is_too_low             = 104; string constant error_message_value_is_too_low_msg             = "Message value is below required minimum";
    uint8 error_code_is_not_updated_or_is_downgraded = 105; string constant error_code_is_not_updated_or_is_downgraded_msg = "Pair code is not updated or is downgraded";

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
        minMessageValue = minMsgValue;
        contractServicePayment = contractSP;
    }

    //============External functions============

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
    returns (address cA) {
        uint256 uniqueID = tokenRootContract1.value^tokenRootContract2.value;
        require(!swapPairDB.exists(uniqueID), error_pair_already_exists, error_pair_already_exists_msg);
        // require(msg.value > contractServicePayment + sendToNewSwapPair, error_message_value_is_too_low, error_message_value_is_too_low_msg);
        // Uncomment to use debug balance manager variant (just disable it :) )
        tvm.accept();
        // The rest will be used to execute current function and keep swap pairs
        // alive if they request tons
        // tvm.rawReserve(msg.value - contractServicePayment - sendToNewSwapPair, 2);

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
        require(spi.hasValue(), error_pair_does_not_exist, error_pair_does_not_exist_msg);
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
            error_code_is_not_updated_or_is_downgraded,
            error_code_is_not_updated_or_is_downgraded_msg
        );
        tvm.accept();
        swapPairCode = code;
        swapPairCodeVersion = codeVersion;
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
            error_code_is_not_updated_or_is_downgraded,
            error_code_is_not_updated_or_is_downgraded_msg
        );
        IUpgradeSwapPairCode(info.swapPairAddress).updateSwapPairCode(swapPairCode, swapPairCodeVersion);
        info.swapPairCodeVersion = swapPairCodeVersion;
        swapPairDB.replace(uniqueID, info);
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
        require(msg.pubkey() == ownerPubkey, error_message_sender_is_not_owner);
        _;
    }

    modifier onlyPaid() {
        require(
            msg.value >= minMessageValue ||
            userTONBalances[msg.pubkey()] >= minMessageValue, 
            error_message_value_is_too_low
        );
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

    //============Debug============

    function getXOR(
        address tokenRootContract1, 
        address tokenRootContract2
    ) external returns (uint256) {
        return tokenRootContract1.value^tokenRootContract2.value;
    }
}