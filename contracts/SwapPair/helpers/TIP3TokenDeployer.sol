pragma ton-solc ^0.39.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../interfaces/helpers/ITIP3TokenDeployer.sol';
import '../RootSwapPairContract.sol';

contract TIP3TokenDeployer is ITIP3TokenDeployer {
    TvmCell rootContractCode;
    TvmCell walletContractCode;
    uint ownerPublicKey;

    constructor() public {
        tvm.accept();
        ownerPublicKey = msg.pubkey();
    }

    function deployTIP3Token(
        bytes name,
        bytes symbol,
        uint8 decimals,
        uint256 rootPublicKey,
        address rootOwnerAddress,
        uint128 deployGrams
    ) 
        external 
        responsible 
        view 
        returns (address tip3Address) 
    {
        tvm.rawReserve(msg.value, 2);

        address tip3TokenAddress = RootTokenContract{
            value: deployGrams,
            flag: 1,
            code: rootContractCode,
            pubkey: rootPublicKey,
            varInit: {
                _randomNonce: 0,
                name: name_,
                symbol: symbol_,
                decimals: decimals_,
                wallet_code: walletContractCode 
            }
        }();

        return {value: 0, flag: 128} tip3TokenAddress;
    }

    function setTIP3RootContractCode(TvmCell rootContractCode_) external onlyOwner {
        tvm.accept();
        rootContractCode = rootContractCode_;
    }

    function setTIP3WalletContractCode(TvmCell walletContractCode_) external onlyOwner {
        tvm.accept();
        walletContractCode = walletContractCode_;
    }

    function getServiceInfo() external responsible view returns (ServiceInfo) {
        return ServiceInfo(rootContractCode, walletContractCode);
    }

    modifier onlyOwner() {
        require(
            msg.pubkey() == ownerPublicKey
        );
        _;
    }
}