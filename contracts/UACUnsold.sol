pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./UAC.sol";

// This contract will hold all tokens that were unsold during ICO.
//
// Ubiatar Team should be able to withdraw them and sell only after 1 year is passed after
// ICO is finished.
//
// Da modificare completamente
contract UACUnsold {

    using SafeMath for uint;

    address public creator;
    address public teamAccountAddress;
    address public icoContractAddress;
    uint64 public icoIsFinishedDate;

    UAC public uacToken;

    function UACUnsold(address _teamAccountAddress,address _uacTokenAddress){
        creator = msg.sender;
        teamAccountAddress = _teamAccountAddress;

        uacToken = UAC(_uacTokenAddress);
    }

    modifier onlyCreator() {
        require(msg.sender==creator);
        _;
    }

    modifier onlyIcoContract() {
        require(msg.sender==icoContractAddress);
        _;
    }

    // Setters/Getters
    function setIcoContractAddress(address _icoContractAddress) onlyCreator {
        icoContractAddress = _icoContractAddress;
    }

    function finishIco() public onlyIcoContract {
        icoIsFinishedDate = uint64(now);
    }

    // can be called by anyone...
    function withdrawTokens() public {
        // Check if 1 year is passed
        uint64 oneYearPassed = icoIsFinishedDate + 365 days;
        require(uint(now) >= oneYearPassed);

        // Transfer all tokens from this contract to the teamAccountAddress
        uint total = uacToken.balanceOf(this);
        uacToken.transfer(teamAccountAddress,total);
    }

    // Do not allow to send money directly to this contract
    function() payable {
        revert();
    }
}
