pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RandomLotto.sol";

contract TestRandomLotto {

    // test constructor
    RandomLotto rl = RandomLotto(DeployedAddresses.RandomLotto());

    function testConstructor() public {
        RandomLotto _this_rl = new RandomLotto();

        uint expected_tp = 1000;
        bool expected_tlm = false;

        // not sure if test can / should call multiple assertions like this, or make different tests
        Assert.equal(expected_tp, _this_rl.ticketPrice(), "ticketPrice should be equal to 1000");
        Assert.equal(expected_tlm, _this_rl.txLockMutex(), "txLockMutex should be false");
    }
}