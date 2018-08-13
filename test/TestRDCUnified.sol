pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RDCUnified.sol";

// TODO: find out if there is an easy way to set the testing contract as Owner of tested contract(s)

contract TestRDCUnified {

    // check newly-constructed RandomCoin contract state and basic functionality
    // maybe also test on a newly-constructed one that state modifiers correctly restrict access

    // N.B. it is possible to run out of ether in deploying account while testing; just reinit truffle develop if this occurs

    uint public initialBalance = 10 ether;

    RandomCoin rc;
    RDCToken rdc;
    //enum State { Funding, Active, Liquidating }
    
    // context setup / teardown to avoid running out of gas while testing
    function beforeEachAgain() public {
        rc = RandomCoin(DeployedAddresses.RandomCoin());
        rdc = new RDCToken();
        // trying to get owner set to rc
        //rdc.transferOwnership(DeployedAddresses.RandomCoin());
        //rc.rdc = rdc;
        //rc.linkRDC(address(rdc));
    }

    // TODO: try and see if I can set up an owned instance of RandomCoin in beforeEachAgain (no new RDCToken())
    // if that works, see if it can additionally call deployRDC() without running out of gas
    // if so, rewrite the tests below
    // or, declare RandomCoin rc = RandomCoin(DeployedAddresses.RandomCoin()); at the top
    // and in the beforeEachAgain hook, run the rc.deployRDC() function
    // [maybe]


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
        uint256 expected_bwt = 5760 * 14;
        uint256 expected_mpib = 100 szabo;
        //State expected_state = State.Funding;

        uint256 _this_ar = rc.averageRate();
        uint256 _this_bwt = rc.blockWaitTime();
        uint256 _this_mpib = rc.minimumPegInBaseAmount();
        //State _this_state = rc.state();

        // not sure if test can / should call multiple assertions like this, or make different tests
        Assert.equal(expected_ar, _this_ar, "averageRate should be equal to 100");
        Assert.equal(expected_bwt, _this_bwt, "blockWaitTime should be equal to 5760 * 14");
        Assert.equal(expected_mpib, _this_mpib, "minimumPegInBaseAmount should be equal to 100 szabo");
        //Assert.equal(expected_state, _this_state, "state should be Funding");
    }

    // test that RandomCoin contract can deploy an instance of RDCToken
    function testRDCDeployment() public {
        rc.deployRDC();
        bool expected = true;
        Assert.equal(expected, rc.rdcCreated(), "The deployed RandomCoin contract should own the RDCToken contract");
    }

    // idea: test if multiple deploy reverts (as it should -- after first, bool should prevent subsequent deploy)

    // test if random rates fall within the expected (rescaled) range
    // N.B. this indirectly tests rescaleRate() as well
    function testRandomRate() public {
        uint _rand_rate = rc.randomRate();
        uint low = 50;
        uint high = 150;
        
        Assert.isAtLeast(_rand_rate, low, "Random rate should be at least 50");
        Assert.isAtMost(_rand_rate, high, "Random rate should be at most 150");
    }

    // test that multiple random rates average within the expected (rescaled) range
    function testMultipleRandomRate() public {
        uint256 low = 50;
        uint256 high = 150;
        uint256[5] memory _rates;
        for (uint i = 0; i < 5; i++) {
            _rates[i] = rc.randomRate();
            Assert.isAtLeast(_rates[i], low, "Random rate should be at least 50");
            Assert.isAtMost(_rates[i], high, "Random rate should be at most 150");
        }
    }

    // test pegIn - need to send at least 10 finney to move contract out of Funding state
    function testPegIn() public {
        // set rdc owner to rc
        rdc.transferOwnership(DeployedAddresses.RandomCoin());
        address _add1 = address(rdc);
        rc.linkRDC(_add1);  // maybe ?? if this works, do this up top and update all tests
        address _add2 = rc.rdcTokenAddress();
        Assert.equal(_add1, _add2, "rdcTokenAddress should be set on rc");
        // TODO: FIGURE OUT WHY THIS DOESN'T WORK
        
        //RDCToken _deployed = RDCToken(DeployedAddresses.RDCToken());
        //rc.rdc = rdc;//_deployed;

        //address _add = address(this);
        //rc.pegIn.value(15 finney).gas(100000)();  // dunno how much gas is actually needed here
        //Assert.isAtLeast(rc.rdc().balanceOf(_add), 1, "pegIn should grant at least 1 RDC");
    }

    // once testPegIn() is working:
    // new function to peg in multiple times and test that averageRate gets updated each time


    // test pegOut


    // test changePegInBase
    // currently reverting though the math seems OK here..
    function testChangePegInBase() public {
        uint256 _new_base = 109 szabo;  // should pass
        rc.changePegInBase(_new_base);
        Assert.equal(_new_base, rc.minimumPegInBaseAmount(), "Peg in base should be 109 szabo");
    }

    // test changeBlockWaitTime
    function testChangeBlockWaitTime() public {
        uint256 _new_bwt = 5760 * 14 + 1000;  // should be well within bounds
        rc.changeBlockWaitTime(_new_bwt);
        Assert.equal(_new_bwt, rc.blockWaitTime(), "blockWaitTime should be equal to 5760 * 14 + 1000");
    }

    // Still need to test: PegIn(), PegOut(), updateAverageRate() [indirectly, or make public]
    // equitableWithdrawal(), equitableDestruct() [how ?], equitableLiquidation() [can argue this covers equitableDestruct()]
    // startLiquidation(), resetState() [harder - change blockWaitTime for this test]
    // [maybe:] changePegInBase(), changeBlockWaitTime() [if i keep them in the contract design]
}
