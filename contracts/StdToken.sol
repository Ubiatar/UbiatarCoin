pragma solidity ^0.4.18;

import "./SafeMath.sol";

// ERC20 standard
contract StdToken {

    using SafeMath for uint;

    // Fields:
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint public totalSupply = 0;

    // Events:
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    modifier onlyPayloadSize(uint _size)
    {
        require(msg.data.length >= _size + 4);
        _;
    }

    // Functions:
    function transfer(address _to, uint256 _value)
    public
    onlyPayloadSize(2 * 32)
    returns(bool)
    {
        require(balances[msg.sender] >= _value);
        require(balances[_to] + _value > balances[_to]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value)
    public
    returns(bool)
    {
        require(balances[_from] >= _value);
        require(allowed[_from][msg.sender] >= _value);
        require(balances[_to] + _value > balances[_to]);

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner)
    public
    constant
    returns (uint256)
    {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value)
    public
    returns (bool)
    {
        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender)
    public
    constant
    returns (uint256)
    {
        return allowed[_owner][_spender];
    }
}