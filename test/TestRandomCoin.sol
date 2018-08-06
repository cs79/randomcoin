pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RandomCoin.sol";

contract TestRandomCoin {

    // check newly-constructed RandomCoin contract state and basic functionality
    // maybe also test on a newly-constructed one that state modifiers correctly restrict access

    RandomCoin rc = RandomCoin(DeployedAddresses.RandomCoin());

    function testConstructor() public {
        RandomCoin _this_rc = new RandomCoin();

        uint expected_ar = 100;
        uint expected_hw = 50;
        uint expected_bwt = 5760 * 14;

        uint _this_ar = _this_rc.averageRate();
        uint _this_hw = _this_rc.halfWidth();
        uint _this_bwt = _this_rc.blockWaitTime();

        // not sure if test can / should call multiple assertions like this, or make different tests
        Assert.equal(expected_ar, _this_ar, "averageRate should be equal to 100");
        Assert.equal(expected_hw, _this_hw, "halfWidth should be equal to 50");
        Assert.equal(expected_bwt, _this_bwt, "blockWaitTime should be equal to 5760 * 14");
    }

    function testRandomRate() public {
        
        uint _rand_rate = rc.randomRate();
        uint low = 50;
        uint high = 150;
        
        Assert.isAtLeast(_rand_rate, low, "Random rate should be at least 50");
        Assert.isAtMost(_rand_rate, high, "Random rate should be at most 150");
    }
}