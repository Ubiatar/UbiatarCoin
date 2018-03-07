pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";

/*
    Eidoo ICO Engine interface
    This interface enables Eidoo wallet to query our ICO and display all the informations needed in the app
*/
contract ICOEngineInterface{
    function started() public view returns(bool);
    function ended() public view returns(bool);
    function startTime() public view returns(uint);
    function endTime() public view returns(uint);
    function startBlock() public view returns(uint);
    function endBlock() public view returns(uint);
    function totalTokens() public view returns(uint);
    function remainingTokens() public view returns(uint);
    function price() public view returns(uint);
}

// ICO Abstract Contract
contract ICOAC
{
    function RC_TOKEN_LIMIT() public constant returns(uint);
    function getBlockNumberStart() constant public returns(uint);
    function getUacTokenBalance(address _of) constant public returns (uint);
    function buyTokensRC(address _buyer) payable public;
    function getTokensIcoSold() constant public returns (uint);
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
contract ReservationContract is Ownable, ICOEngineInterface
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
    // Standard token price in USD CENTS per token
    uint public usdTokenPrice = 2 * 100;
    // The USD/ETH
    // UPDATE CHANGE RATE WITH CURRENT RATE WHEN DEPLOYING
    // This value is given in USD CENTS
    uint public usdPerEth = 1100 * 100;

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

    function setUsdTokenPrice(uint tokenPrice)
    public
    onlyOwner
    {
        usdTokenPrice = tokenPrice;
    }

    function setUsdPerEthRate(uint _usdPerEthRate)
    public
    onlyOwner
    {
        usdPerEth = _usdPerEthRate;
    }

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

    function getUacTokensPerEth(uint bonusPercent)
    constant
    internal
    returns (uint)
    {
        uint tokenPrice = (usdTokenPrice.mul(100)).div(bonusPercent.add(100));
        uint uacPerEth = (usdPerEth.mul(1 ether)).div(tokenPrice);
        return uacPerEth;
    }

    /// ICOEngineInterface

    // false if the ico is not started, true if the ico is started and running, true if the ico is completed
    function started()
    public
    view
    returns(bool)
    {
        return (rcBlockNumberStart != 0 && block.number >= rcBlockNumberStart && block.number < icoBlockNumberStart);
    }

    // false if the ico is not started, false if the ico is started and running, true if the ico is completed
    function ended()
    public
    view
    returns(bool)
    {
        return (icoBlockNumberStart != 0 && (block.number >= icoBlockNumberStart || ico.getTokensIcoSold() == ico.RC_TOKEN_LIMIT()));
    }

    // time stamp of the starting time of the ico, must return 0 if it depends on the block number
    function startTime()
    public
    view
    returns(uint)
    {
        return 0;
    }

    // time stamp of the ending time of the ico, must return 0 if it depends on the block number
    function endTime()
    public
    view
    returns(uint)
    {
        return 0;
    }

    // Optional function, can be implemented in place of startTime
    // Returns the starting block number of the ico, must return 0 if it depends on the time stamp
    function startBlock()
    public
    view
    returns(uint)
    {
        return rcBlockNumberStart;
    }

    // Optional function, can be implemented in place of endTime
    // Returns theending block number of the ico, must retrun 0 if it depends on the time stamp
    function endBlock()
    public
    view
    returns(uint)
    {
        return icoBlockNumberStart;
    }

    // returns the total number of the tokens available for the sale, must not change when the ico is started
    function totalTokens()
    public
    view
    returns(uint)
    {
        return ico.RC_TOKEN_LIMIT();
    }

    // returns the number of the tokens available for the ico. At the moment that the ico starts it must be equal to totalTokens(),
    // then it will decrease. It is used to calculate the percentage of sold tokens as remainingTokens() / totalTokens()
    function remainingTokens()
    public
    view
    returns(uint)
    {
        return ico.RC_TOKEN_LIMIT().sub(ico.getTokensIcoSold());
    }

    // return the price as number of tokens released for each ether
    function price()
    public
    view
    returns(uint)
    {
        uint bonusPercent = 10;
        return getUacTokensPerEth(bonusPercent);
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
