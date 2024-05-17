// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "truffle/Assert.sol";
import "../contracts/Donation.sol";

contract TestErc20 {
    function testConstructor() public {
        Erc20 token = new Erc20("test", "TST", msg.sender, 100);
        
        Assert.equal(token.name(), "test", "Token must have name test");
        Assert.equal(token.symbol(), "TST", "Token must have symbol TST");
        Assert.equal(token.totalSupply(), 100, "Tokens total supply must be 100");
        Assert.equal(token.balanceOf(msg.sender), 100, "Token balance must be 100");
    }
}
