pragma solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/Terminal.sol";

contract LilBot {

    string name;

    function start() public {
        Terminal.print("Hello! I'm jst a lilbot, but I will grow big and useful!");
        Terminal.input(tvm.functionId(setText), "Enter your name: ");
        Terminal.print("Your name: " + name);
    }

    function setText(string value) public {
        name = value;
    }
}