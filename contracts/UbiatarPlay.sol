pragma solidity ^0.4.18;

import "./Owned.sol";
import "./SafeMath.sol";

contract UACAC {
    function transfer(address _to, uint256 _value) public returns(bool);
}

contract UbiatarPlay is Owned{

    using SafeMath for uint;

    bool public icoFinished = false;

    uint public startingTime = 0;

    address public icoContractAddress = 0x0;

    address public uacTokenAddress = 0x0;

    address public ubiatarPlayTokenHolder = 0x0;

    UACAC public uacToken;

    uint public currentBalance = 50500000 * 1 ether;

    uint public withdrawMonths3 = 2000000 * 1 ether;
    uint public withdrawMonths6 = 4000000 * 1 ether;
    uint public withdrawMonths9 = 6000000 * 1 ether;
    uint public withdrawMonths12 = 8000000 * 1 ether;
    uint public withdrawMonths18 = 10000000 * 1 ether;
    uint public withdrawMonths24 = 20500000 * 1 ether;

    modifier onlyIcoFinished()
    {
        require(icoFinished == true);
        _;
    }

    modifier byIcoContract()
    {
        require(msg.sender == icoContractAddress);
        _;
    }

    function UbiatarPlay(address _uacTokenAddress){
        uacToken = UACAC(_uacTokenAddress);
        uacTokenAddress = _uacTokenAddress;
    }

    function finishIco()
    byIcoContract
    {
        startingTime = uint(now);
        icoFinished = true;
    }

    function setIcoContractAddress(address _icoContractAddress)
    public
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
    }

    function setUacTokenAddress(address _uacTokenAddress)
    public
    onlyOwner
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UACAC(_uacTokenAddress);
    }

    function setubiatarPlayTokenHolder(address _ubiatarPlayTokenHolder)
    public
    onlyOwner
    {
        ubiatarPlayTokenHolder = _ubiatarPlayTokenHolder;
    }

    function withdraw()
    public
    onlyIcoFinished
    onlyOwner
    {
        uint amountToSend = 0;

        if(uint(now) > startingTime + 90 days)
        {
            amountToSend = withdrawMonths3;
            withdrawMonths3 = 0;
        }
        if(uint(now) > startingTime + 180 days)
        {
            amountToSend = amountToSend.add(withdrawMonths6);
            withdrawMonths6 = 0;
        }
        if(uint(now) > startingTime + 270 days)
        {
            amountToSend = amountToSend.add(withdrawMonths9);
            withdrawMonths9 = 0;
        }
        if(uint(now) > startingTime + 360 days)
        {
            amountToSend = amountToSend.add(withdrawMonths12);
            withdrawMonths12 = 0;
        }
        if(uint(now) > startingTime + 540 days)
        {
            amountToSend = amountToSend.add(withdrawMonths18);
            withdrawMonths18 = 0;
        }
        if(uint(now) > startingTime + 720 days)
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
