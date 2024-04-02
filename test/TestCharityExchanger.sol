// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Charity.sol";

contract TestCharityExchanger {
    function testInitialBalanceOfExchanger() public {
        CharityExchanger exchanger = new CharityExchanger();
        InterfaceErc20 token = InterfaceErc20(exchanger.token());
        
        Assert.equal(token.balanceOf(address(exchanger)), 300, "Exchanger should have 300 tokens by deploy");
    }
}
