pragma solidity ^0.4.18;


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
    public
    onlyOwner
    returns (bool success)
    {
        candidateOwner = newOwner;
        success = true;
        UpdatedCandidate(success);
        return;
    }

    function getOwnership ()
    public
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