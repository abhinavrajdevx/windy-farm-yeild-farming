// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Wind is ERC20 {
    address public owner;
    constructor() ERC20("Wind", "WND") {
        owner= msg.sender;
    }

    function mint (uint256 _amount) public {
        require(msg.sender == owner, "You are not Owner");
        _mint(msg.sender, _amount);
    }

    function transferOwnership (address _owner) public{
        require(msg.sender == owner, "You are not Owner");
        owner= _owner;
    }
}