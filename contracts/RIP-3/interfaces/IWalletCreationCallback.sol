pragma ton-solidity >= 0.6.0;

pragma AbiHeader pubkey;
pragma AbiHeader expire;
pragma AbiHeader time;

interface IWalletCreationCallback {
    function getWalletAddressCallback(address walletAddress) external;
}