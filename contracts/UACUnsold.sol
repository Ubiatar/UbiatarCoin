pragma solidity ^0.4.18;

import "./Owned.sol";

// This contract will hold all tokens that were unsold during ICO.
contract UACUnsold is Owned{

    // Do not allow to send money directly to this contract
    function() payable {
        revert();
    }
}
