// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface InterfaceErc20 {
    function name() external view returns(string memory);

    function symbol() external view returns(string memory);

    function decimals() external pure returns(uint);

    function totalSupply() external view returns(uint256);

    function balanceOf(address _owner) external view returns(uint256);

    function allowance(address _owner, address _spender) external view returns(uint256);

    function transfer(address _to, uint256 _value) external returns(bool);

    function transferFrom(address _from, address _to, uint256 _value) external returns(bool);

    function approve(address _spender, uint256 _value) external returns(bool);

    event Transfer(address indexed _from, address indexed _to, uint _amount);

    event Approve(address indexed _from, address indexed _to, uint _amount);
}


contract Erc20 is InterfaceErc20 {
    string internal _name;
    string internal _symbol;
    
    address internal owner;

    uint internal total;

    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowances;

    modifier checkTokenSufficiency(address _from, uint _amount) {
        require(balanceOf(_from) >= _amount, "Not enough tokens for this operation!");
        _;
    }

    modifier allowOnlyToOwner() {
        require(msg.sender == owner, "This operation is allowed only for owner!");
        _;
    }

    function name() external view returns(string memory) {
        return _name;
    }

    function symbol() external view returns(string memory) {
        return _symbol;
    }

    function decimals() external pure returns(uint) {
        return 18;
    }

    function totalSupply() external view returns(uint256) {
        
    }

    function balanceOf(address _owner) public view returns(uint256) {
    
    }

    function allowance(address _owner, address _spender) external view returns(uint256) {

    }

    function transfer(address _to, uint256 _value) external returns(bool) {

    }

    function transferFrom(address _from, address _to, uint256 _value) external returns(bool) {

    }

    function approve(address _spender, uint256 _value) external returns(bool) {

    }
}
