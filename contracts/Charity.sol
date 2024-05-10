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
        bool _status = _transfer(_from, _to, _value);
        return _status;
    }

    function transferFrom(address _from, address _to, uint256 _value) external checkTokenSufficiency(_from, _value) returns(bool) {
        require(allowances[_from][_to] >= _value, "No allowance provided for this transaction!");
        bool _status = _transfer(_from, _to, _value);
        if (_status) {
            allowances[_from][_to] -= _value;
        }
        return _status;
    }

    function _transfer(address _from, address _to, uint256 _value) internal returns(bool) {
        bool _status = _beforeTokenTransfer(_from, _to, _value);

        if (_status) {
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


contract DonationToken is Erc20 {
    address[] internal membersRegistry; 
    mapping(address => bool) internal membersStatus; 

    mapping(address => mapping(string => uint256)) internal _donateNeeds;
    mapping(address => uint256) internal _donateBalances;

    constructor(address _exchanger) Erc20("DonationToken", "DNTT", _exchanger, 300) {}

    modifier allowOnlyToMember() {
        // модификатор для ограничения доступа к функции для всех кроме участника объединения
        require(membersStatus[msg.sender], "This operation is allowed only for member!");
        _;
    }

    function donateNeed(address _needie, string memory _needName) external view returns(uint256) {
        return _donateNeeds[_needie][_needName];
    }

    function donateBalance(address _needie) external view returns(uint256) {
        return _donateBalances[_needie];
    }

    function registerDonateNeeds(string memory _needName, uint _needs) external allowOnlyToMember {
        // регистрация адреса для фиксации необходимости в донатах
        require(_needs > 0, "Needs should be > 0!");

        address _needy = msg.sender;
        _donateNeeds[_needy][_needName] = _needs;

        emit NeedsRegister(_needy, _needs);
    }

    function donate(uint _value) external checkTokenSufficiency(msg.sender, _value) returns(bool) {
        // донат для одного рандомного нуждающегося
        require(membersRegistry.length > 0, "No needies now!");

        address _from = msg.sender;

        uint _index = uint(block.number % membersRegistry.length);
        address _to = membersRegistry[_index];

        bool _status = _transfer(_from, _to, _value);
        return _status;
    }

    function donateAll(uint _value) external checkTokenSufficiency(msg.sender, _value) returns(bool) {
        // донат для всех нуждающихся
        require(membersRegistry.length > 0, "No needies now!");
        require(_value >= membersRegistry.length, "Needies number is more than donation sum!");

        address _from = msg.sender;
        uint _value_per_needy = _value / membersRegistry.length;
        bool _status_all = true;

        // осуществление перевода
        for (uint i; i < membersRegistry.length; i++) {
            address _to = membersRegistry[i];
            bool _status = _transfer(_from, _to, _value_per_needy);
            _status_all = _status_all && _status;
        }

        return _status_all;
    }

    function registerMember(address _newMember) external allowOnlyToOwner {
        // регистрация участника
        membersRegistry.push(_newMember);
        membersStatus[_newMember] = true;
    }

    function disableMember(address _member) external allowOnlyToOwner {
        // деактивация участника    
        for (uint _index = 0; _index < membersRegistry.length - 1; _index++) {
            if (membersRegistry[_index] == _member) {
                _removeMemberFromRegistry(_index);
            }
        }

        membersStatus[_member] = false;
    }

    function _removeMemberFromRegistry(uint _index) internal {
        require(_index > membersRegistry.length, "Index out of registry!");

        for (uint i = _index; i < membersRegistry.length - 1; i++) {
            membersRegistry[i] = membersRegistry[i + 1];
        }

        membersRegistry.pop();
    }

    event NeedsRegister(address indexed _needy, uint _needs);
    event MemberDisabled(address indexed _needy);
}


contract DonationExchanger {
    InterfaceErc20 public token;
    address payable public owner;

    event Buy(address indexed _buyer, uint _value);
    event Sell(address indexed _seller, uint _value);

    constructor() {
        token = new DonationToken(address(this));
        owner = payable(msg.sender);
    }

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

    receive() external payable checkTokenSufficiency(address(this), msg.value) {
        // продажа обменником токенов
        address _to = msg.sender;
        uint _value = msg.value;

        token.transfer(_to, _value);

        emit Buy(_to, _value);
    }
}
