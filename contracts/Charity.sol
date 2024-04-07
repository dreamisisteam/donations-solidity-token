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


contract CharityToken is Erc20 {
    address[] internal neediesRegistry; 

    mapping(address => uint256) internal _donateNeeds;
    mapping(address => uint256) internal _donateBalances;

    constructor(address _exchanger) Erc20("CharityToken", "CHR", _exchanger, 300) {}

    function donateNeed(address _needie) external view returns(uint256) {
        return _donateNeeds[_needie];
    }

    function donateBalance(address _needie) external view returns(uint256) {
        return _donateBalances[_needie];
    }

    function registerDonateNeeds(uint _needs) external {
        // регистрация адреса для фиксации необходимости в донатах
        require(_needs > 0, "Needs should be > 0!");

        address _needy = msg.sender;

        neediesRegistry.push(msg.sender);
        _donateNeeds[msg.sender] = _needs;

        emit NeedsRegister(_needy, _needs);
    }

    function donate(uint _value) external checkTokenSufficiency(msg.sender, _value) {
        // донат для одного рандомного нуждающегося
        require(neediesRegistry.length > 0, "No needies now!");

        address _from = msg.sender;

        uint _index = uint(block.number % neediesRegistry.length);
        address _to = neediesRegistry[_index];

        bool _status = _transfer(_from, _to, _value);

        if (_status) {
            _checkNeedyDonationsNeeds(_to, _value, _index);
        }
    }

    function donateAll(uint _value) external checkTokenSufficiency(msg.sender, _value) {
        // донат для всех нуждающихся
        require(neediesRegistry.length > 0, "No needies now!");
        require(_value >= neediesRegistry.length, "Needies number is more than donation sum!");

        address _from = msg.sender;
        uint _value_per_needy = _value / neediesRegistry.length;

        address[] memory newNeediesRegistry = new address[](neediesRegistry.length);

        // копирование массива
        for (uint i; i < neediesRegistry.length; i++) {
            newNeediesRegistry[i] = neediesRegistry[i];
        }

        uint _deletedCount = 0;

        // осуществление перевода
        for (uint i; i < newNeediesRegistry.length; i++) {
            address _to = newNeediesRegistry[i];
            bool _status = _transfer(_from, _to, _value_per_needy);

            if (_status) {  // при успешном переводе проверяем, утолили ли мы требования нуждающегося
                bool _isNeedy = _checkNeedyDonationsNeeds(_to, _value_per_needy, i - _deletedCount);

                if (!_isNeedy) {
                    _deletedCount++;  // формирование смещения индекса
                }
            }
        }
    }

    function _checkNeedyDonationsNeeds(address _needy, uint _value, uint _index) internal returns(bool) {
        // проверка необходимости получения донатов после поступления новой суммы
        _donateBalances[_needy] += _value;

        if (_donateBalances[_needy] >= _donateNeeds[_needy]) {
            delete _donateBalances[_needy];
            delete _donateNeeds[_needy];

            _removeNeedyFromRegistry(_index);

            emit NeedsAchieved(_needy);

            return false;
        }

        return true;
    }

    function _removeNeedyFromRegistry(uint _index) internal {
        require(_index < neediesRegistry.length, "Index out of registry!");

        for (uint i = _index; i < neediesRegistry.length - 1; i++) {
            neediesRegistry[i] = neediesRegistry[i + 1];
        }

        neediesRegistry.pop();
    }

    event NeedsRegister(address indexed _needy, uint _needs);
    event NeedsAchieved(address indexed _needy);
}


contract CharityExchanger {
    InterfaceErc20 public token;
    address payable public owner;

    event Buy(address indexed _buyer, uint _value);
    event Sell(address indexed _seller, uint _value);

    constructor() {
        token = new CharityToken(address(this));
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
