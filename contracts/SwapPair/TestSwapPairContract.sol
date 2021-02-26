// Pre-alpha
pragma solidity >= 0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './interfaces/ISwapPairContract.sol';

import './interfaces/ISwapPairInformation.sol';

contract TestSwapPairContract is ISwapPairContract {

    uint static _randomNonce;

    SwapPairInfo testPairInfo;

    UserBalanceInfo testBalanceInfo;

    function setSwapPairInfo(SwapPairInfo spi) external {
        tvm.accept();

        testPairInfo = spi;
    }


    function setUserBalanceInfo(UserBalanceInfo ubi) external {
        tvm.accept();

        testBalanceInfo = ubi;
    }

    function withdrawToken(address withdrawalTokenRoot, address receiveTokenWallet, uint128 amount) override external {
        tvm.accept();
    } 

    function swap(address swappableTokenRoot,  uint128 swappableTokenAmount) override external {
        tvm.accept();
    } //-- 

    function getExchangeRate(address swappableTokenRoot, uint128 swappableTokenAmount) override external view returns (uint256 rate) {
        tvm.accept();
        return 1;
    } //int twm accept

    function addLiquidity(uint128 firstTokenAmount, uint128 secondTokenAmount) override external {
        tvm.accept();
    } //twm accept

    function getCreationTimestamp() override external view returns (uint256 creationTimestamp) {
        tvm.accept();
        return 1;
    } //twm accept int
    
    function getPairInfo() override external view returns (SwapPairInfo info) {
        tvm.accept();
        return testPairInfo;

    } //+ set ret SwapPairInfo

    function getUserBalance() override external view returns (UserBalanceInfo ubi) {
        tvm.accept();
        return testBalanceInfo;

    } //+ set ret UserBalanceInfo
}