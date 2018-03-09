pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";

// UbiatarCoin Abstract Contract
contract UACAC {
    function transfer(address _to, uint256 _value) public returns(bool);
}

/*
    This contract holds 12000000 founders UAC. They will be locked for 1 year and then will be gradually unlocked in the
    next year.
*/
contract FoundersVesting is Ownable
{
    // SafeMath standard lib
    using SafeMath for uint;

    // Flag that indicates if ICO is finished
    bool public icoFinished = false;

    // ICO contract address
    address public icoContractAddress = 0x0;

    // UbiatarCoin contract address
    address public uacTokenAddress = 0x0;

    // Founders Token cold wallet
    address public foundersTokenHolder = 0x0;

    // Last withdraw epoch time
    uint public lastWithdrawTime;

    // UbiatarCoin contract reference
    UACAC public uacToken;

    // Current UAC Token balance in this contract
    uint public currentBalance = 12000000 * 1 ether;

    // It is the fraction that it could be withdrawn every day
    uint public balanceFraction;

    // FoundersVesting constructor
    function FoundersVesting(address _uacTokenAddress)
    public
    {
        require(_uacTokenAddress != 0x0);

        uacToken = UACAC(_uacTokenAddress);
        uacTokenAddress = _uacTokenAddress;
        // Amount of tokens to be sent in a single day
        balanceFraction = ((currentBalance.mul(1 ether)).div(360)).div(1 ether);
    }


    /// Modifiers

    // Only by ICO contract
    modifier byIcoContract()
    {
        require(msg.sender == icoContractAddress);
        _;
    }

    // Only when ICO is finished
    modifier onlyIcoFinished()
    {
        require(icoFinished == true);
        _;
    }

    /// Setters

    // ICO contract address setter
    function setIcoContractAddress(address _icoContractAddress)
    public
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
    }

    // UbiatarCoin contract address setter
    function setUacTokenAddress(address _uacTokenAddress)
    public
    onlyOwner
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UACAC(_uacTokenAddress);
    }

    // Founders wallet address setter
    function setFoundersTokenHolder(address _foundersTokenHolder)
    public
    onlyOwner
    {
        foundersTokenHolder = _foundersTokenHolder;
    }

    /// Functions

    // Function called by ICO contract when it is finished
    function finishIco()
    public
    byIcoContract
    {
        lastWithdrawTime=uint(now).add(360 days);
        icoFinished = true;
    }

    // It allows Founders to withdraw their tokens
    // It can withdraw a fraction of its total supply day by day until the end of 1 year
    function withdrawTokens()
    public
    onlyOwner
    onlyIcoFinished
    {
        // Checks if we have already set the foundersTokenHolder wallet address
        require(foundersTokenHolder != 0x0);
        uint amountToSend = 0;

        // Calculates the number of days passed from the last time tokens were withdrawn
        uint daysPassed = (uint(now).sub(lastWithdrawTime)).div(1 days);

        amountToSend = balanceFraction.mul(daysPassed);
        lastWithdrawTime = uint(now);

        require(amountToSend != 0);

        if (currentBalance < amountToSend) {
            amountToSend = currentBalance;
        }

        currentBalance = currentBalance.sub(amountToSend);

        uacToken.transfer(foundersTokenHolder, amountToSend);

        amountToSend = 0;
    }

    // It doesn't allow to send money directly to this contract
    function() payable public {
        revert();
    }
}
