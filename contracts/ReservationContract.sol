pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";

contract ICOAC
{
    function getBlockNumberStart() constant public returns(uint);
    function getUacTokenBalance(address _of) constant public returns (uint);
    function buyTokensRC(address _buyer) payable public;
}

contract UACAC
{
    function balanceOf(address _owner) public constant returns (uint256);
}


contract ReservationContract is Ownable
{
    using SafeMath for uint;
    //uint public advisorPercentage = 0;
    address public icoContractAddress = 0x0;
    address public uacTokenAddress = 0x0;
    uint public icoBlockNumberStart = 0;
    uint public rcBlockNumberStart = 0;
    ICOAC public ico;
    UACAC public uacToken;

    event LogReserve(address to, uint value);

    function ReservationContract()
    public {
    }

    modifier onlyInBlockNumberRange()
    {
        require(block.number >= rcBlockNumberStart);
        require(block.number < icoBlockNumberStart);
        _;
    }

    function setIcoContractAddress(address _icoContractAddress)
    public
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
        ico = ICOAC(_icoContractAddress);
    }

    function setUacTokenAddress(address _uacTokenAddress)
    public
    onlyOwner
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UACAC(_uacTokenAddress);
    }

    function setRCBlockNumberStart(uint _blockNumber)
    onlyOwner
    public
    {
        rcBlockNumberStart = _blockNumber;
    }


    function getIcoBlockNumberStart()
    public
    onlyOwner
    {
        icoBlockNumberStart = ico.getBlockNumberStart();
        // subtract roughly 3 days
        rcBlockNumberStart = icoBlockNumberStart - uint(3 days).div(uint(17 seconds));
    }

    function getReservedTokens(address investor)
    constant
    public
    returns (uint)
    {
        return uacToken.balanceOf(investor);
    }

    function()
    public
    payable
    onlyInBlockNumberRange
    {
        ico.buyTokensRC.value(msg.value)(msg.sender);
        LogReserve(msg.sender, msg.value);
    }
}
