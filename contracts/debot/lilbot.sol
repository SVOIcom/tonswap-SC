pragma solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/Terminal.sol";
import "./interfaces/Debot.sol";
import "./interfaces/AddressInput.sol";

interface SetCode { 

    function setA(uint b) external;

    function getA() external returns(uint);

    function setCode(TvmCell newcode) external;
}

contract LilBot is Debot {

    uint256 static _randomNonce;

    string name_;

    constructor(string debotAbi) public {
        tvm.accept();
        init(DEBOT_ABI, debotAbi, "", address(0));
    }

    function fetch() override public returns (Context[] contexts) { }

    function start() override public {
        Terminal.print(0, "Hello! I'm jst a lilbot, but I will grow big and useful!");
        Terminal.print(0, "Input test contract address:");
        AddressInput.select(tvm.functionId(callContract));
    }

    function quit() override public {

    }

    function getVersion() override public returns (string name, uint24 semver) {name = "lilbot"; semver = 1;}
    // function getErrorDescription(uint32 error) public pure override returns (string desc) {desc = "error";}

    function setText(string value) public {
        name_ = value;
        Terminal.print(0, "Your name: " + name_);
    }

    function callContract(address value) public {
        optional (uint256) pubkey;
        SetCode(value).getA{
            extMsg: true,
            pubkey: pubkey,
            abiVer: 2,
            callbackId: tvm.functionId(receiveA),
            onErrorId: tvm.functionId(onError)
        }();
    }

    function receiveA(uint a) public {
        Terminal.print(0, format("Value of A: {}", a));
    } 

    function onError(uint32 errorId) public {
        Terminal.print(0, "Ooops, error occured. Returning to menu.");
    }
}