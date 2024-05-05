pragma solidity ^0.8.0;

import {
    ERC2771Context
} from "@gelatonetwork/relay-context/contracts/vendor/ERC2771Context.sol";

// By inheriting from ERC2771Context, Context's internal functions are overridden automatically
contract UmiMarket is ERC2771Context{
    mapping(address => uint256) public assets;

    // / Here we have a mapping that maps a counter to an address
    mapping(address => uint256) public contextCounter;
    address[] public caller;

    event IncrementContextCounter(address _msgSender);

    // A modifier that only allows the trustedForwarder to call
    // the required target function: `incrementContext`
    modifier onlyTrustedForwarder() {
        caller.push(msg.sender);
        // require(
        //     isTrustedForwarder(msg.sender),
        //     "Only callable by Trusted Forwarder"
        // );
        _;
    }

    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {
    }

    // `incrementContext` is the target function to call
    // This function increments a counter variable which is 
    // mapped to every _msgSender(), the address of the user.
    // This way each user off-chain has their own counter 
    // variable on-chain.
    function incrementContext() external onlyTrustedForwarder {
        // Remember that with the context shift of relaying,
        // where we would use `msg.sender` before, 
        // this now refers to Gelato Relay's address, 
        // and to find the address of the user, 
        // which has been verified using a signature,
        // please use _msgSender()!
        
        // Incrementing the counter mapped to the _msgSender!
        contextCounter[_msgSender()]++;
        
        // Emitting an event for testing purposes
        emit IncrementContextCounter(_msgSender());
    }

    function buy() public {
        assets[_msgSender()]++;
    }

    function sell() public {
        assets[_msgSender()] --;
    }
}
