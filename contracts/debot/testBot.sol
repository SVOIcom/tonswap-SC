pragma solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/Debot.sol";
import "./interfaces/Terminal.sol";
import "./interfaces/AddressInput.sol";

interface TestValue {
    function getValue() external view returns(uint);
}

contract TestDeBot is Debot {
    uint static _randomNonce;
    constructor(string botAbi) public {
        tvm.accept();
        init(DEBOT_ABI, botAbi, "", address(0));
    }

    function fetch() override public returns (Context[] contexts) { }

    function start() override public {
        Terminal.print(0, "Hello! I'm jst a lilbot, but I will grow big and useful!");
        Terminal.print(0, "Input test contract address:");
        AddressInput.select(tvm.functionId(callContract));
    }

    function quit() override public {

    }

    function getVersion() override public returns (string name, uint24 semver) {
        name = "lilbot"; semver = 1;
    }

    function callContract(address value) public {
        optional(uint) pubkey;
        TvmCell message = tvm.buildExtMsg({
            abiVer: 2,
            callbackId: tvm.functionId(showValue),
            onErrorId: 0,
            time: uint64(now),
            dest: value,
            call: {
                TestValue.getValue
            }
        });
        tvm.sendrawmsg(message, 1);
        // TestValue(value).getValue{
        //     extMsg: true,
        //     time: uint64(now),
        //     sign: false,
        //     pubkey: pubkey,
        //     callbackId: tvm.functionId(showValue),
        //     abiVer: 2,
        //     errorId: tvm.functionId(showValue)
        // }();
    }
    
    function showValue(uint inputValue) public {
        Terminal.print(0, format("random nonce: {}", inputValue));
    }
}