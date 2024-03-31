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

    event Transfer(address indexed _from, address indexed _to, uint _value);

    event Approve(address indexed _sender, address indexed _spender, uint _value);
}


contract Erc20 is InterfaceErc20 {
    string internal _name;
    string internal _symbol;
    
    address internal owner;

    uint internal total;

    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowances;

    constructor(
        string memory name_,
        string memory symbol_,
        address exchanger_,
        uint initialTotal
    ) {
        owner = msg.sender;

        _name = name_;
        _symbol = symbol_;

        mint(exchanger_, initialTotal);
    }

    modifier checkTokenSufficiency(address _from, uint _value) {
        // модификатор для проверки достаточности количества токенов для совершения операции
        require(_value > 0 && balanceOf(_from) >= _value, "Incorrect value for transaction!");
        _;
    }

    modifier allowOnlyToOwner() {
        // модификатор для ограничения доступа к функции для всех кроме владельца
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
        return 18;  // 1 wei
    }

    function totalSupply() external view returns(uint256) {
        return total;
    }

    function balanceOf(address _owner) public view returns(uint256) {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender) external view returns(uint256) {
        return allowances[_owner][_spender];
    }

    function _beforeTokenTransfer(address _from, address _to, uint _value) internal virtual returns(bool) {
        // служебная функция для определения возможности осуществления перевода
        return true;
    }

    function _beforeTokenApprove(address _sender, address _spender, uint _value) internal virtual returns(bool) {
        // служебная функция для определения возможности разрешения передачи токенов
        return true;
    }

    function transfer(address _to, uint256 _value) external checkTokenSufficiency(msg.sender, _value) returns(bool) {
        address _from = msg.sender;

        bool _status = _beforeTokenTransfer(_from, _to, _value);

        if (_status) {
            balances[_from] -= _value;
            balances[_to] += _value;

            emit Transfer(_from, _to, _value);
        }

        return _status;
    }

    function transferFrom(address _from, address _to, uint256 _value) external checkTokenSufficiency(_from, _value) returns(bool) {
        bool _status = _beforeTokenTransfer(_from, _to, _value);

        if (_status) {
            require(allowances[_from][_to] >= 0, "No allowance provided for this transaction!");

            balances[_from] -= _value;
            balances[_to] += _value;

            emit Transfer(_from, _to, _value);
        }

        return _status;
    }

    function approve(address _spender, uint256 _value) external returns(bool) {
        address _sender = msg.sender;

        bool _status = _beforeTokenApprove(_sender, _spender, _value);

        if (_status) {
            allowances[_sender][_spender] = _value;
            emit Approve(_sender, _spender, _value);
        }
        
        return _status;
    }

    function mint(address _exchanger, uint _value) public allowOnlyToOwner {
        // ввод в оборот определенного количества валюты
        _beforeTokenTransfer(address(0), _exchanger, _value);

        balances[_exchanger] += _value;
        total += _value;

        emit Transfer(address(0), _exchanger, _value);
    }
}


contract CharityToken is Erc20 {
    constructor(address _exchanger) Erc20("CharityToken", "CHR", _exchanger, 300) {}

    // TODO: _beforeTokenTransfer логика
    // TODO: _beforeTokenApprove логика
}


contract CharityExchanger {
    InterfaceErc20 public token;
    address payable public owner;

    event Donate(address indexed _donater, uint _value);
    event Buy(address indexed _buyer, uint _value);
    event Sell(address indexed _seller, uint _value);

    modifier checkTokenSufficiency(address _from, uint _value) {
        // модификатор для проверки достаточности количества токенов для совершения операции
        require(_value > 0 && token.balanceOf(_from) >= _value, "Incorrect value for transaction!");
        _;
    }

    function sell(uint _value) public checkTokenSufficiency(msg.sender, _value) {
        // продажа токенов обменнику
        address _from = msg.sender;
        address _to = address(this);
        
        uint _allowance = token.allowance(_from, address(this));
        require(_allowance >= _value, "No allowance!");

        token.transferFrom(_from, _to, _value);
        payable(_from).transfer(_value);

        emit Sell(_from, _value);
    }

    function donate(uint _value) public checkTokenSufficiency(msg.sender, _value) {
        // TODO: донат для рандомного человека
    }

    receive() external payable checkTokenSufficiency(address(this), msg.value) {
        // продажа обменником токенов
        address _to = msg.sender;
        uint _value = msg.value;

        token.transfer(_to, _value);

        emit Buy(_to, _value);
    }
}
