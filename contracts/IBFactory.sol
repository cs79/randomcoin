pragma solidity ^0.4.0;

import "./IterableBalances.sol";

contract IBFactory {
    address owner;

    constructor() public {
        owner = msg.sender;
    }

    function createIB()
    public
    returns(IterableBalances)
    {
        IterableBalances IB = new IterableBalances();
        return IB;
    }
}