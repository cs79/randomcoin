pragma solidity ^0.4.23;

import "../installed_contracts/zeppelin/contracts/ownership/Ownable.sol";
import "./RDCToken.sol";

contract RDCTokenFactory is Ownable {

    constructor() public {
        owner = msg.sender;
    }

    function createRDCToken()
    public
    returns(RDCToken)
    {
        RDCToken RDC = new RDCToken();
        return RDC;
    }
}