pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";

// ICO Abstract Contract
contract ICOAC
{
    function getBlockNumberStart() constant public returns(uint);
    function getUacTokenBalance(address _of) constant public returns (uint);
    function buyTokensRC(address _buyer) payable public;
}

// UbiatarCoin Abstract Contract
contract UACAC
{
    function balanceOf(address _owner) public constant returns (uint256);
}

/*
    Reservation contract
    It will deliver an amount of token with a discount price a few hours before ICO begin
*/
contract ReservationContract is Ownable
{
    // SafeMath standard lib
    using SafeMath for uint;

    // ICO contract address
    address public icoContractAddress = 0x0;
    // UbiatarCoin contract address
    address public uacTokenAddress = 0x0;
    // ICO block number start
    uint public icoBlockNumberStart = 0;
    // Reservation contract block number start
    uint public rcBlockNumberStart = 0;
    // ICO contract reference
    ICOAC public ico;
    // UbiatarCoint contract reference
    UACAC public uacToken;

    event LogReserve(address to, uint value);

    // Reservation contract constructor
    function ReservationContract()
    public
    {}

    /// modifiers

    // only during  Reservation contract campaign
    modifier onlyInBlockNumberRange()
    {
        require(block.number >= rcBlockNumberStart);
        require(block.number < icoBlockNumberStart);
        _;
    }

    /// setters

    // set ICO contract address
    function setIcoContractAddress(address _icoContractAddress)
    public
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
        ico = ICOAC(_icoContractAddress);
    }

    // set UbiatarCoint ERC20 token contract address
    function setUacTokenAddress(address _uacTokenAddress)
    public
    onlyOwner
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UACAC(_uacTokenAddress);
    }

    // set Reservation contract campaign block number start
    function setRCBlockNumberStart(uint _blockNumber)
    onlyOwner
    public
    {
        rcBlockNumberStart = _blockNumber;
    }

    /// functions

    // It gets ICO starting block number
    function getIcoBlockNumberStart()
    public
    onlyOwner
    {
        icoBlockNumberStart = ico.getBlockNumberStart();
    }

    // It retrieves user reserved tokens
    function getReservedTokens(address investor)
    constant
    public
    returns (uint)
    {
        return uacToken.balanceOf(investor);
    }

    // Payback function to partecipate to Reservation contract campaign
    function()
    public
    payable
    onlyInBlockNumberRange
    {
        ico.buyTokensRC.value(msg.value)(msg.sender);
        LogReserve(msg.sender, msg.value);
    }
}
