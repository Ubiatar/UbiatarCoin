pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";

// UbiatarCoin Abstract Contract
contract UACAC {
    function transfer(address _to, uint256 _value) public returns(bool);
}

/*
    UbiatarPlay contract wallet
    50.5% of UAC will be withdrawn here
    Token will be withdraws in slices after 3-6-9-12-18-24 months
*/
contract UbiatarPlay is Ownable{

    // SafeMath standard lib
    using SafeMath for uint;

    // Flag that indicates if ICO is finished
    bool public icoFinished = false;

    // Starting time is set when finishICO is fired by ICO contract
    uint public startingTime = 0;

    // ICO contract address
    address public icoContractAddress = 0x0;

    // UbiatrCoin Token contract address
    address public uacTokenAddress = 0x0;

    // UbiatarPlay coldwallet
    address public ubiatarPlayTokenHolder = 0x0;

    // UbiatarCoin contract reference
    UACAC public uacToken;

    // UbiatarPlay account UAC balance
    uint public currentBalance = 50500000 * 1 ether;

    // Token withdrawnable per months
    uint public withdrawMonths3 = 2000000 * 1 ether;
    uint public withdrawMonths6 = 4000000 * 1 ether;
    uint public withdrawMonths9 = 6000000 * 1 ether;
    uint public withdrawMonths12 = 8000000 * 1 ether;
    uint public withdrawMonths18 = 10000000 * 1 ether;
    uint public withdrawMonths24 = 20500000 * 1 ether;

    /// Modifiers

    // Only when ICO is finished
    modifier onlyIcoFinished()
    {
        require(icoFinished == true);
        _;
    }

    // Only by ICO contract
    modifier byIcoContract()
    {
        require(msg.sender == icoContractAddress);
        _;
    }

    // Contract constructor
    function UbiatarPlay(address _uacTokenAddress)
    public
    {
        uacToken = UACAC(_uacTokenAddress);
        uacTokenAddress = _uacTokenAddress;
    }

    // Function called by ICO contract when it is finished
    function finishIco()
    public
    byIcoContract
    {
        startingTime = uint(now);
        icoFinished = true;
    }

    // ICO contract address setter
    function setIcoContractAddress(address _icoContractAddress)
    public
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
    }

    // UbiatarCoin Token contract address setter
    function setUacTokenAddress(address _uacTokenAddress)
    public
    onlyOwner
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UACAC(_uacTokenAddress);
    }

    // UbiatarPlay account contract address setter
    function setubiatarPlayTokenHolder(address _ubiatarPlayTokenHolder)
    public
    onlyOwner
    {
        ubiatarPlayTokenHolder = _ubiatarPlayTokenHolder;
    }

    // UbiatarPlay UAC Token withdraw function based on timestamp
    function withdraw()
    public
    onlyIcoFinished
    onlyOwner
    {
        uint amountToSend = 0;

        if(uint(now) > startingTime.add(90 days))
        {
            amountToSend = withdrawMonths3;
            withdrawMonths3 = 0;
        }
        if(uint(now) > startingTime.add(180 days))
        {
            amountToSend = amountToSend.add(withdrawMonths6);
            withdrawMonths6 = 0;
        }
        if(uint(now) > startingTime.add(270 days))
        {
            amountToSend = amountToSend.add(withdrawMonths9);
            withdrawMonths9 = 0;
        }
        if(uint(now) > startingTime.add(360 days))
        {
            amountToSend = amountToSend.add(withdrawMonths12);
            withdrawMonths12 = 0;
        }
        if(uint(now) > startingTime.add(540 days))
        {
            amountToSend = amountToSend.add(withdrawMonths18);
            withdrawMonths18 = 0;
        }
        if(uint(now) > startingTime.add(720 days))
        {
            amountToSend = amountToSend.add(withdrawMonths24);
            withdrawMonths24 = 0;
            if(amountToSend < currentBalance)
            {
                amountToSend = currentBalance;
            }
        }

        currentBalance = currentBalance.sub(amountToSend);

        require(amountToSend != 0);

        uacToken.transfer(ubiatarPlayTokenHolder, amountToSend);
    }
}
