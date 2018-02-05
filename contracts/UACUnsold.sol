pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./UAC.sol";
import "./Owned.sol";

// This contract will hold all tokens that were unsold during ICO.
//
// Ubiatar Team should be able to withdraw them and sell only after 1 year is passed after
// ICO is finished.
//
// TO BE COMPLETELEY REWRITTEN
contract UACUnsold is Owned{

    using SafeMath for uint;

    address public owner;
    address public teamAccountAddress;
    address public icoContractAddress;
    uint public icoIsFinishedBlockNumber;

    UAC public uacToken;

    function UACUnsold(address _teamAccountAddress, address _uacTokenAddress)
    {
        owner = msg.sender;
        teamAccountAddress = _teamAccountAddress;

        uacToken = UAC(_uacTokenAddress);
    }

    modifier onlyOwner()
    {
        require(msg.sender==owner);
        _;
    }

    modifier onlyIcoContract()
    {
        require(msg.sender==icoContractAddress);
        _;
    }

    // Setters/Getters
    function setIcoContractAddress(address _icoContractAddress)
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
    }

    function finishIco() public onlyIcoContract {
        icoIsFinishedBlockNumber = block.number;
    }

     /*function withdrawTokens() public {
        // Check if 1 year is passed
        uint64 oneYearPassed = icoIsFinishedDate + 365 days;
        require(uint(now) >= oneYearPassed);

        // Transfer all tokens from this contract to the teamAccountAddress
        uint total = uacToken.balanceOf(this);
        uacToken.transfer(teamAccountAddress,total);
    }*/

    // Do not allow to send money directly to this contract
    function() payable {
        revert();
    }
}
