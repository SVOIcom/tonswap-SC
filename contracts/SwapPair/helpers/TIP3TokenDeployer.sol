pragma ton-solc ^0.39.0;
pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

import '../interfaces/helpers/ITIP3TokenDeployer.sol';

import '../../../ton-eth-bridge-token-contracts/free-ton/contracts/RootTokenContract.sol';

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
        override 
        returns (address) 
    {
        address tip3TokenAddress = new RootTokenContract{
            value: deployGrams,
            flag: 1,
            code: rootContractCode,
            pubkey: rootPublicKey,
            varInit: {
                _randomNonce: 0,
                name: name,
                symbol: symbol,
                decimals: decimals,
                wallet_code: walletContractCode 
            }
        }(rootPublicKey, rootOwnerAddress);

        return {value: 0, flag: 128} tip3TokenAddress;
    }

    function getFutureTIP3Address(
        bytes name,
        bytes symbol,
        uint8 decimals,
        uint256 rootPublicKey
    ) 
        public 
        override 
        responsible
        returns (address) 
    {
        tvm.accept();
        TvmCell stateInit = tvm.buildStateInit({
            contr: RootTokenContract,
            code: rootContractCode,
            pubkey: rootPublicKey,
            varInit: {
                _randomNonce: 0,
                name: name,
                symbol: symbol,
                decimals: decimals,
                wallet_code: walletContractCode 
            }
        });

        return address.makeAddrStd(0, tvm.hash(stateInit));
    }

    function setTIP3RootContractCode(TvmCell rootContractCode_) external override onlyOwner {
        tvm.accept();
        rootContractCode = rootContractCode_;
    }

    function setTIP3WalletContractCode(TvmCell walletContractCode_) external override onlyOwner {
        tvm.accept();
        walletContractCode = walletContractCode_;
    }

    function getServiceInfo() external responsible view override returns (ServiceInfo) {
        return ServiceInfo(rootContractCode, walletContractCode);
    }

    modifier onlyOwner() {
        require(
            msg.pubkey() == ownerPublicKey
        );
        _;
    }
}