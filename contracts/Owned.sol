pragma solidity ^0.4.19;


contract Owned {
    address public owner;
    address public candidateOwner;

    event UpdatedCandidate(bool success);
    event GotOwnership(bool success);

    function Owned()
    public
    {
        owner = msg.sender;
        candidateOwner = 0x0;
    }

    function setCandidate (address newOwner)
    onlyOwner
    returns (bool success)
    {
        candidateOwner = newOwner;
        success = true;
        UpdatedCandidate(success);
        return;
    }

    function getOwnership ()
    onlyCandidate
    returns (bool success)
    {
        owner = candidateOwner;
        candidateOwner = 0x0;
        success = true;
        GotOwnership(success);
        return;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyCandidate {
        require(candidateOwner != 0x0);
        require(msg.sender == candidateOwner);
        _;
    }
}