pragma ton-solc ^0.39.0;
pragma AbiHeader expire;
pragma AbiHeader time;

interface ITIP3TokenDeployer {
    function deployTIP3Token(
        bytes name,
        bytes symbol,
        uint8 decimals,
        uint256 rootPublicKey,
        address rootOwnerAddress
    ) external responsible view returns (address tip3Address);

    function setTIP3RootContractCode(TvmCell rootContractCode_) external;

    function setTIP3WalletContractCode(TvmCell walletContractCode_) external;

    function getServiceInfo() external responsible view returns(ServiceInfo);

    struct ServiceInfo {
        TvmCell rootContractCode;
        TvmCell walletContractCode;
    }
}