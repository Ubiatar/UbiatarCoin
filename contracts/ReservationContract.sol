pragma solidity ^0.4.18;

// Maps account addresses and balances from PreSale

import "./SafeMath.sol";
import "./Owned.sol";

contract UAC
{

}

contract ICO
{

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
    UAC public uacToken;
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
        uacToken = UAC(_uacTokenAddress);
    }

    function getIcoBlockNumberStart()
    onlyOwner
    {
        // @TODO: implement getBlockNumberStart ICO function
        icoBlockNumberStart = ico.getBlockNumberStart();
        rcBlockNumberStart = icoBlockNumberStart - uint(2 days / 17 seconds);
    }

    function() payable
    onlyInBlockNumberRange
    {
        require(msg.value > 500 finney);
        // @TODO: call ICO to reserve tokens
        // @TODO: calculate tokens to give to investor
    }

    function getReservedTokens(address user)
    constant
    public
    returns (uint balance)
    {
        return investorsTokens(msg.sender);
    }

    function withdrawTokens()
    public
    {
        uint tempBalance = (investors[msg.sender].initialBalance.mul(1 ether)).div(3);
        amountToSend = 0;


        if ((uint(now) >= firstThreshold) && (investors[msg.sender].firstWithdraw == 0)) {
            investors[msg.sender].balance = investors[msg.sender].initialBalance;
            investors[msg.sender].lastWithdrawTime = secondThreshold;
            investors[msg.sender].firstWithdraw = 1;
            amountToSend = tempBalance;
        }

        tempBalance = tempBalance.mul(2);

        if (uint(now) >= secondThreshold) {
            uint daysPassed = (uint(now).sub(investors[msg.sender].lastWithdrawTime)).div(1 days);
            amountToSend = amountToSend.add((tempBalance.div(180)).mul(daysPassed));
            investors[msg.sender].lastWithdrawTime = uint(now);
        }

        require(amountToSend != 0);
        amountToSend = amountToSend.div(1 ether);

        if (investors[msg.sender].balance < amountToSend) {
            amountToSend = investors[msg.sender].balance;
        }

        investors[msg.sender].balance = investors[msg.sender].balance.sub(amountToSend);

        uacToken.transfer(msg.sender, amountToSend);

        amountToSend = 0;
    }
}
