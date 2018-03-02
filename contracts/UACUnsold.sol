pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";

// This contract will hold all tokens that were unsold during ICO.
contract UACUnsold is Ownable{

    // Do not allow to send money directly to this contract
    function() payable {
        revert();
    }
}
