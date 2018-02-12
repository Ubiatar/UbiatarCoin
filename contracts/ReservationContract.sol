pragma solidity ^0.4.18;

// Maps account addresses and balances from PreSale

import "./SafeMath.sol";
import "./Owned.sol";

contract ICO
{
    // @TODO: put interface
}

contract ReservationContract is Owned
{
    using SafeMath for uint;
    uint public advisorPercentage = 0;
    address public icoContractAddress = 0x0;
    address public uacContractAddress = 0x0;
    uint public icoBlockNumberStart = 0;
    uint public rcBlockNumberStart = 0;
    mapping(address => uint) investorsTokens;
    ICO public ico;

    function ReservationContract() {}

    modifier byIcoContract()
    {
        require(msg.sender == icoContractAddress);
        _;
    }

    modifier onlyInBlockNumberRange()
    {
        require(block.number >= rcBlockNumberStart);
        require(block.number < icoBlockNumberStart);
        _;
    }

    modifier onlyAfterIcoStarted()
    {
        require(block.number > icoBlockNumberStart);
        _;
    }

    function setIcoContractAddress(address _icoContractAddress)
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
        ico = ICO(_icoContractAddress);
    }

    function setUacContractAddress(address _uacContractAddress)
    onlyOwner
    {
        uacContractAddress = _uacContractAddress;
    }

    function getIcoBlockNumberStart()
    onlyOwner
    {
        icoBlockNumberStart = ico.getBlockNumberStart();
        rcBlockNumberStart = icoBlockNumberStart - uint(2 days / 17 seconds);
    }

    function()
    payable
    onlyInBlockNumberRange
    {
        require(msg.value >= 500 finney);
        uint tokens = ico.reserveTokensRC();
        investorsTokens[msg.sender].add(tokens);
    }

    function getReservedTokens(address investor)
    constant
    public
    returns (uint balance)
    {
        return investorsTokens(investor);
    }

    function withdrawTokens()
    public
    onlyAfterIcoStarted
    {
        uint tokenToBeIssued = investorsTokens[msg.sender];
        require(tokenToBeIssued > 0);
        investorsTokens[msg.sender] = 0;
        require(ico.reclaimTokensRC(msg.sender, tokenToBeIssued));
    }
}
