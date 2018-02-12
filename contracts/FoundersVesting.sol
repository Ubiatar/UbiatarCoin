pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Owned.sol";

contract UAC {
    function balanceOf(address _owner) public constant returns (uint256);
    function transfer(address _to, uint256 _value) public returns(bool);
}

contract FoundersVesting is Owned{

    using SafeMath for uint;

    address public teamAccountAddress;
    uint64 public lastWithdrawTime;

    uint public withdrawsCount = 0;
    uint public amountToSend = 0;

    address public uacTokenAddress = 0x0;

    UAC public uacToken;

    function FoundersVesting(address _teamAccountAddress, address _uacTokenAddress)
    {
        teamAccountAddress = _teamAccountAddress;
        lastWithdrawTime = uint64(now);

        uacToken = UAC(_uacTokenAddress);
    }

    function setUacTokenAddress(address _uacTokenAddress)
    onlyOwner
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UAC(_uacTokenAddress);
    }

    function setTeamAccountAddress(address _teamAccountAddress)
    onlyOwner
    {
        teamAccountAddress = _teamAccountAddress;
    }

    function withdrawTokens()
    onlyOwner
    public
    {
        // 1 - wait for the next month
        uint64 oneMonth = lastWithdrawTime + 30 days;
        require(uint(now) >= oneMonth);

        // 2 - calculate amount (only first time)
        if(withdrawsCount==0){
            amountToSend = uacToken.balanceOf(this) / 10;
        }

        require(amountToSend!=0);

        // 3 - send 1/10th
        uint currentBalance = uacToken.balanceOf(this);
        if(currentBalance<amountToSend){
            amountToSend = currentBalance;
        }
        uacToken.transfer(teamAccountAddress,amountToSend);

        // 4 - update counter
        withdrawsCount++;
        lastWithdrawTime = uint64(now);
    }

    // Do not allow to send money directly to this contract
    function() payable {
        revert();
    }
}
