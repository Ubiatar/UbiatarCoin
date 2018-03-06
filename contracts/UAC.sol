pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";

/*
    UbiatarCoin token contract.
*/
contract UAC is StandardToken, Ownable
{
    // SafeMath standard lib
    using SafeMath for uint;
    // Fields:
    string public constant name = "Ubiatar Coin";
    string public constant symbol = "UAC";
    uint public constant decimals = 18;

    // ICO contract address
    address public icoContractAddress = 0x0;
    // Bool to lock UAC transfers before ICO end
    bool public lockTransfers = true;

    // total UAC token supply
    uint public constant TOTAL_TOKEN_SUPPLY = 100000000 * 1 ether;
    // total ICO token supply
    uint public constant TOTAL_ICO_SUPPLY = 15000000 * 1 ether;
    // total presale token supply
    uint public constant TOTAL_PRESALE_SUPPLY = 17584778551358900100698693;
    // total advisors supply
    uint public constant TOTAL_ADVISORS_SUPPLY = 4915221448641099899301307;
    // total ubiatarPlay supply
    uint public constant TOTAL_UBIATARPLAY_SUPPLY = 50500000 * 1 ether;
    // total founders supply
    uint public constant TOTAL_FOUNDERS_SUPPLY = 12000000 * 1 ether;

    /// Modifiers:

    // Enable use only by ICO contract
    modifier byIcoContract()
    {
        require(msg.sender == icoContractAddress);
        _;
    }

    /// Setters/Getters

    // This function sets the ICO contract address
    function setIcoContractAddress(address _icoContractAddress)
    public
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
    }

    /// Functions:

    // UAC Constructor
    function UAC()
    public
    {
        require(TOTAL_TOKEN_SUPPLY == 100000000 * 1 ether);
        require(TOTAL_ICO_SUPPLY.add(TOTAL_PRESALE_SUPPLY).add(TOTAL_ADVISORS_SUPPLY).add(TOTAL_UBIATARPLAY_SUPPLY).add(TOTAL_FOUNDERS_SUPPLY) == TOTAL_TOKEN_SUPPLY);
    }

    /// @dev Override
    function transfer(address _to, uint256 _value)
    public
    returns(bool)
    {
        require(!lockTransfers);
        return super.transfer(_to,_value);
    }

    /// @dev Override
    function transferFrom(address _from, address _to, uint256 _value)
    public
    returns(bool)
    {
        require(!lockTransfers);
        return super.transferFrom(_from,_to,_value);
    }

    // It creates new token and it can be called only by ICO contract
    function issueTokens(address _who, uint _tokens)
    public
    byIcoContract
    {
        require((totalSupply_ + _tokens) <= TOTAL_TOKEN_SUPPLY);

        balances[_who] = balances[_who].add(_tokens);
        totalSupply_ = totalSupply_.add(_tokens);

        Transfer(0x0, _who, _tokens);
    }

    // It burns tokens updating total supply
    function burnTokens(address _who, uint _tokens)
    public
    byIcoContract
    {
        balances[_who] = balances[_who].sub(_tokens);
        totalSupply_ = totalSupply_.sub(_tokens);
    }

    // It enables or disables token transfers
    function lockTransfer(bool _lock)
    public
    byIcoContract
    {
        lockTransfers = _lock;
    }

    // It disallows to send money directly to this contract
    function()
    public
    {
        revert();
    }
}
