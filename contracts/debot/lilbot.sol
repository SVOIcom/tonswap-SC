pragma solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/Terminal.sol";

contract LilBot {

    string name;

    function start() public {
        Terminal.print(0, "Hello! I'm jst a lilbot, but I will grow big and useful!");
        Terminal.inputStr(tvm.functionId(setText), "Enter your name: ", false);
        Terminal.print(0, "Your name: " + name);
    }

    function setText(string value) public {
        name = value;
    }
}