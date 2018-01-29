pragma solidity ^0.4.18;

// Maps account addresses and balances from PreSale

import "./SafeMath.sol";
import "./UAC.sol";


contract PreSaleVesting
{

    using SafeMath for uint;

    uint public amountToSend = 0;
    uint public firstThreshold;
    uint public secondThreshold;

    struct Investor
    {
        uint initialBalance;
        uint balance;
        uint lastWithdrawTime;
        uint firstWithdraw;
    }

    mapping(address => Investor) investors;


    UAC public uacToken;

    function PreSaleVesting(address _uacTokenAddress)
    {
        require(_uacTokenAddress != 0x0);
        investors[address(0x7fe01ff0aDaF111A94ad0d69eD27cDe23553AF44)].initialBalance = 266955000000000513888375;
        investors[address(0x7fe01ff0aDaF111A94ad0d69eD27cDe23553AF44)].balance = 266955000000000513888375;
        investors[address(0x7fe01ff0aDaF111A94ad0d69eD27cDe23553AF44)].lastWithdrawTime = uint(now).add(127 days);
        investors[address(0x7fe01ff0aDaF111A94ad0d69eD27cDe23553AF44)].firstWithdraw = 1;
        investors[address(0x48c04d07Ed26C38198A2411982D046d3CF952c5D)].initialBalance = 12025000000000023148125;
        investors[address(0x48c04d07Ed26C38198A2411982D046d3CF952c5D)].balance = 12025000000000023148125;
        investors[address(0x48c04d07Ed26C38198A2411982D046d3CF952c5D)].lastWithdrawTime = uint(now).add(127 days);
        investors[address(0x48c04d07Ed26C38198A2411982D046d3CF952c5D)].firstWithdraw = 1;
        // Set all addresses with initialBalance from PreSale lastWithdrawTime = uint64(now), firstWithdraw = 1

        uacToken = UAC(_uacTokenAddress);
        firstThreshold = uint(now).add(37 days);
        secondThreshold = uint(now).add(127 days);
    }

    function withdrawTokens()
    public
    {
        uint tempBalance = (investors[msg.sender].initialBalance.mul(1 ether)).div(3);


        if ((uint(now) >= firstThreshold) && (investors[msg.sender].firstWithdraw == 1)) {
            investors[msg.sender].firstWithdraw = 0;
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

    function getInitialBalance(address user)
    constant
    public
    returns (uint initialBalance)
    {
        initialBalance = investors[user].initialBalance;
        return initialBalance;
    }

    function getReclaimableTokens(address user)
    constant
    public
    returns (uint reclaimableTokens)
    {
        uint tempBalance = (investors[user].initialBalance.mul(1 ether)).div(3);


        if ((uint(now) >= firstThreshold) && (investors[user].firstWithdraw == 1)) {
            reclaimableTokens = tempBalance;
        }

        tempBalance = tempBalance.mul(2);

        if (uint(now) >= secondThreshold) {
            uint daysPassed = (uint(now).sub(investors[user].lastWithdrawTime)).div(1 days);
            reclaimableTokens = reclaimableTokens.add((tempBalance.div(180)).mul(daysPassed));
        }

        reclaimableTokens = reclaimableTokens.div(1 ether);

        if (investors[user].balance < reclaimableTokens) {
            reclaimableTokens = investors[user].balance;
        }

        return reclaimableTokens;
    }

    function getBalance(address user)
    constant
    public
    returns (uint balance)
    {
        return investors[user].balance;
    }

    function getLockedTokens(address user)
    constant
    public
    returns (uint lockedTokens)
    {
        uint reclaimableTokens = 0;
        uint tempBalance = (investors[user].initialBalance.mul(1 ether)).div(3);


        if ((uint(now) >= firstThreshold) && (investors[user].firstWithdraw == 1)) {
            reclaimableTokens = tempBalance;
        }

        tempBalance = tempBalance.mul(2);

        if (uint(now) >= secondThreshold) {
            uint daysPassed = (uint(now).sub(investors[user].lastWithdrawTime)).div(1 days);
            reclaimableTokens = reclaimableTokens.add((tempBalance.div(180)).mul(daysPassed));
        }

        reclaimableTokens = reclaimableTokens.div(1 ether);

        if (investors[user].balance < reclaimableTokens) {
            reclaimableTokens = investors[user].balance;
        }

        lockedTokens = investors[user].balance - reclaimableTokens;
    }

    // Do not allow to send money directly to this contract
    function() payable {
        revert();
    }
}
