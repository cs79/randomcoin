pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RDCUnified.sol";

// TODO: move existing tests from TestRDCToken to here

contract TestRDCUnified {

    // check newly-constructed RandomCoin contract state and basic functionality
    // maybe also test on a newly-constructed one that state modifiers correctly restrict access

    // N.B. it is possible to run out of ether in deploying account while testing; just reinit truffle develop if this occurs

    RandomCoin rc;
    RDCToken rdc;
    
    // context setup / teardown to avoid running out of gas while testing
    function beforeEachAgain() public {
        rc = RandomCoin(DeployedAddresses.RandomCoin());
        rdc = new RDCToken();
    }

    // TODO: try and see if I can set up an owned instance of RandomCoin in beforeEachAgain (no new RDCToken())
    // if that works, see if it can additionally call deployRDC() without running out of gas
    // if so, rewrite the tests below


    // RDCToken contract tests:
    // ------------------------
    
    // test ownership set by this contract when instantiated
    function testRDCOwnerSetCorrectly() public {
        address expected = address(this);
        Assert.equal(expected, rdc.owner(), "Owner should be the deploying contract");
    }

    // test owner's ability to mint + balanceOf functionality
    function testOwnerCanMintNewTokens() public {
        uint expected = 9001;

        rdc.mint(address(this), 9001);

        Assert.equal(expected, rdc.balanceOf(address(this)), "Address _add should receive 9001 minted tokens");
    }

    // test totalSupply after minting some tokens
    function testTotalSupply() public {
        address _add = address(this);
        uint firstXfer = 9000;
        uint secondXfer = 1000;
        uint expected = firstXfer + secondXfer;

        rdc.mint(_add, firstXfer);
        rdc.mint(_add, secondXfer);

        Assert.equal(expected, rdc.totalSupply(), "totalSupply should be 10000");
    }

    // test if RDCToken can have ownership transferred to an instance of RandomCoin
    function testRDCOwnershipTransfer() public {
        RDCToken _xfer_rdc = new RDCToken();

        address expectedOwner = address(rc);
        // attempt to transfer ownership
        _xfer_rdc.transferOwnership(address(rc));
        // check if we successfully did so
        Assert.equal(expectedOwner, _xfer_rdc.owner(), "RandomCoin contract should now own RDCToken instance");
    }


    // RandomCoin contract tests:
    // --------------------------

    // as-is this isn't a very good test
    function testRandomCoinConstructor() public {
        uint256 expected_ar = 100;
        //uint expected_hw = 50;
        //uint expected_bwt = 5760 * 14;

        uint _this_ar = rc.averageRate();
        //uint _this_hw = _this_rc.halfWidth();
        //uint _this_bwt = _this_rc.blockWaitTime();

        // not sure if test can / should call multiple assertions like this, or make different tests
        Assert.equal(expected_ar, _this_ar, "averageRate should be equal to 100");
        //Assert.equal(expected_hw, _this_hw, "halfWidth should be equal to 50");
        //Assert.equal(expected_bwt, _this_bwt, "blockWaitTime should be equal to 5760 * 14");
    }

    // test that RandomCoin contract can deploy an instance of RDCToken
    function testRDCDeployment() public {
        rc.deployRDC();
        bool expected = true;
        Assert.equal(expected, rc.rdcCreated(), "The deployed RandomCoin contract should own the RDCToken contract");
    }

    // idea: test if multiple deploy reverts (as it should -- after first, bool should prevent subsequent deploy)

    // test if random rates fall within the expected (rescaled) range
    function testRandomRate() public {
        uint _rand_rate = rc.randomRate();
        uint low = 50;
        uint high = 150;
        
        Assert.isAtLeast(_rand_rate, low, "Random rate should be at least 50");
        Assert.isAtMost(_rand_rate, high, "Random rate should be at most 150");
    }

    // Still need to test: PegIn(), PegOut(), updateAverageRate() [indirectly, or make public]
    // equitableWithdrawal(), equitableDestruct() [how ?], equitableLiquidation() [can argue this covers equitableDestruct()]
    // startLiquidation(), resetState() [harder - change blockWaitTime for this test]
    // [maybe:] changePegInBase(), changeBlockWaitTime() [if i keep them in the contract design]
}
