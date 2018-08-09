pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RDCUnified.sol";

// TODO: move existing tests from TestRDCToken to here

contract TestRDCUnified {

    // check newly-constructed RandomCoin contract state and basic functionality
    // maybe also test on a newly-constructed one that state modifiers correctly restrict access

    //RandomCoin rc = RandomCoin(DeployedAddresses.RandomCoin());

    // RDCToken contract tests:
    
    // test ownership set by this contract when instantiated
    function testRDCOwnerSetCorrectly() public {
        RDCToken _this_rdc = new RDCToken();

        address expected = address(this);

        Assert.equal(expected, _this_rdc.owner(), "Owner should be the deploying contract");
    }

    // test owner's ability to mint + balanceOf functionality
    function testOwnerCanMintNewTokens() public {
        RDCToken _this_rdc = new RDCToken();

        uint expected = 9001;

        _this_rdc.mint(address(this), 9001);

        Assert.equal(expected, _this_rdc.balanceOf(address(this)), "Address _add should receive 9001 minted tokens");
    }

    // test totalSupply after minting some tokens
    function testTotalSupply() public {
        RDCToken _this_rdc = new RDCToken();

        address _add = address(this);
        uint firstXfer = 9000;
        uint secondXfer = 1000;
        uint expected = firstXfer + secondXfer;

        _this_rdc.mint(_add, firstXfer);
        _this_rdc.mint(_add, secondXfer);

        Assert.equal(expected, _this_rdc.totalSupply(), "totalSupply should be 10000");
    }



    // RandomCoin contract tests:
    function testRandomCoinConstructor() public {
        RandomCoin _this_rc = new RandomCoin();

        uint256 expected_ar = 100;
        //uint expected_hw = 50;
        //uint expected_bwt = 5760 * 14;

        uint _this_ar = _this_rc.averageRate();
        //uint _this_hw = _this_rc.halfWidth();
        //uint _this_bwt = _this_rc.blockWaitTime();

        // not sure if test can / should call multiple assertions like this, or make different tests
        Assert.equal(expected_ar, _this_ar, "averageRate should be equal to 100");
        //Assert.equal(expected_hw, _this_hw, "halfWidth should be equal to 50");
        //Assert.equal(expected_bwt, _this_bwt, "blockWaitTime should be equal to 5760 * 14");
    }

    /*function testRDCDeployment() public {
        RandomCoin _this_rc = new RandomCoin();
        _this_rc.deployRDC();
        bool expected = true;
        Assert.equal(expected, _this_rc.rdcCreated(), "The deployed RandomCoin contract should own the RDCToken contract");
    }*/

    function testRandomRate() public {
        RandomCoin _this_rc = new RandomCoin();

        uint _rand_rate = _this_rc.randomRate();
        uint low = 50;
        uint high = 150;
        
        Assert.isAtLeast(_rand_rate, low, "Random rate should be at least 50");
        Assert.isAtMost(_rand_rate, high, "Random rate should be at most 150");
    }
}