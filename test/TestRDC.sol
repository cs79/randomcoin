pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RDC.sol";

contract TestRDC {

    uint256 public initialBalance = 10 ether;
    //RDC rdc = RDC(DeployedAddresses.RDC());
    RDC rdc;

    // setup test hook
    /*function beforeEachAgain() public {
        rdc = new RDC();  // should be owned by this contract
    }*/

    function beforeAll() public {
        rdc = new RDC();
    }

    // test ownership set by this contract when instantiated
    function testOwnerSetCorrectly() public {
        address expected = address(this);
        Assert.equal(expected, rdc.owner(), "Owner should be the deploying contract");
    }

    // as-is this isn't a very good test - silly grab bag atm
    function testRandomCoinConstructor() public {
        uint256 expected_ar = 100;
        uint256 expected_bwt = 10; //5760 * 14;
        uint256 expected_mpib = 100 szabo;

        uint256 _this_ar = rdc.averageRate();
        uint256 _this_bwt = rdc.blockWaitTime();
        uint256 _this_mpib = rdc.minimumPegInBaseAmount();

        Assert.equal(expected_ar, _this_ar, "averageRate should be equal to 100");
        Assert.equal(expected_bwt, _this_bwt, "blockWaitTime should be equal to 5760 * 14");
        Assert.equal(expected_mpib, _this_mpib, "minimumPegInBaseAmount should be equal to 100 szabo");
    }

    // test totalSupply after minting some tokens
    function testMintAndTotalSupply() public {
        address _add = address(this);
        uint firstXfer = 9000;
        uint secondXfer = 1000;
        uint expected = firstXfer + secondXfer;

        rdc.mint(_add, firstXfer);
        rdc.mint(_add, secondXfer);

        Assert.equal(expected, rdc.totalSupply(), "totalSupply should be 10000");
    }

    // test that RDCTokens are transferable
    function testRDCTokenTransfer() public {
        address _add1 = address(this);
        address _add2 = DeployedAddresses.RDCToken();
        
        // mint to _add1, transfer to _add2
        rdc.mint(_add1, 1000);
        rdc.transfer(_add2, 500);

        uint256 _expected = 500;
        Assert.equal(_expected, rdc.balanceOf(_add2), "balance of _add2 should be 500");
    }

    // test if RDCToken can have ownership transferred to an instance of RandomCoin
    function testRDCOwnershipTransfer() public {
        RDC _xfer_rdc = new RDC();

        address expectedOwner = DeployedAddresses.RDC();
        // attempt to transfer ownership
        _xfer_rdc.transferOwnership(expectedOwner);
        // check if we successfully did so
        Assert.equal(expectedOwner, _xfer_rdc.owner(), "RandomCoin contract should now own RDCToken instance");
    }

    // test if random rates fall within the expected (rescaled) range
    // N.B. this indirectly tests rescaleRate() as well
    function testRandomRate() public {
        uint _rand_rate = rdc.randomRate();
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
            _rates[i] = rdc.randomRate();
            Assert.isAtLeast(_rates[i], low, "Random rate should be at least 50");
            Assert.isAtMost(_rates[i], high, "Random rate should be at most 150");
        }
    }

    // test pegIn - need to send at least 10 finney to move contract out of Funding state
    function testPegIn() public {
        rdc.pegIn.value(15 finney).gas(1000000)();  // actual gas cost is something like 175,000 it appears
        Assert.isAtLeast(rdc.balanceOf(address(this)), 1, "pegIn should grant at least 1 RDC");
    }

    // new function to peg in multiple times and test that averageRate gets updated each time
    // also tests that the latestRates array gets populated
    // N.B. THIS TEST CAN FAIL RANDOMLY EVEN IF FUNCTIONALITY IS WORKING PROPERLY
    // this is because rates are getting rounded and squashed quite a bit; the reported rate can end up averaging towards a fixed number in 5 tests
    // if it fails, just try rerunning the truffle test
    // if events suggest that all rates are the same, run compile, migrate --reset, then test in truffle develop to see if it is fixed
    function testMultiplePegIn() public {
        // peg in a few times
        uint256 _lastAR;
        for (uint8 i; i < 5; i++)
        {
            rdc.pegIn.value(15 finney).gas(300000)();
            uint256 _curAR = rdc.averageRate();
            Assert.isAtLeast(_curAR, 1, "averageRate should not be 0");
            // check that averageRate changes during loop
            Assert.notEqual(_lastAR, _curAR, "averageRate should have been updated");
            _lastAR = _curAR;
        }
        // check latestRates after loop
        uint256 _expectValue = 2;
        uint256 _doNotExpectValue = 10;
        Assert.isAtLeast(rdc.latestRates(_expectValue), 1, "value should have been assigned to index 2");
        Assert.equal(rdc.latestRates(_doNotExpectValue), 0, "value should not have been assigned to index 10");
    }

    // test pegOut
    function testPegOut() public payable {
        uint256 _this_eth_bal = this.balance;
        uint256 _this_rdc_bal = rdc.balanceOf(address(this));
        Assert.isAtLeast(_this_rdc_bal, 100, "this contract should have at least 100 RDCTokens");
        rdc.pegOut(_this_rdc_bal / 10);
        Assert.isAtLeast(this.balance, _this_eth_bal + 1, "this contract should have received some eth from pegging out");
        Assert.isAtMost(rdc.balanceOf(this), _this_rdc_bal - 1, "this contract should have lost some RDCTokens");
        Assert.isAtLeast(rdc.balanceOf(address(rdc)), 1, "the RDC contract should have received some RDCTokens");
    }

    // test changePegInBase
    function testChangePegInBase() public {
        uint256 _new_base = 109 szabo;  // should pass
        rdc.changePegInBase(_new_base);
        Assert.equal(_new_base, rdc.minimumPegInBaseAmount(), "Peg in base should be 109 szabo");
    }

    // test changeBlockWaitTime
    function testChangeBlockWaitTime() public {
        uint256 _new_bwt = 9;  // basically at the limit... hopefully works :\
        rdc.changeBlockWaitTime(_new_bwt);
        Assert.equal(_new_bwt, rdc.blockWaitTime(), "blockWaitTime should be equal to 5760 * 14 + 1000");
    }

    // test equitableLiquidation + startLiquidation
    // this test case essentially covers equitableDestruct as they both just call startLiquidation
    function testEquitableLiquidation() public {
        bool expected = true;
        bool result = rdc.equitableLiquidation();
        Assert.equal(expected, result, "Liquidation should have been triggered");
        Assert.notEqual(rdc.liquidationBlockNumber(), 0, "liquidationBlockNumber should have been set");
        Assert.notEqual(rdc.availablePayout(), 0, "availablePayout should habe been set");
        Assert.equal(address(rdc).balance - rdc.haircut(), rdc.availablePayout(), "availablePayout should have been haircut");
    }

    function testMoveTimeForward_1of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_2of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_3of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_4of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_5of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_6of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_7of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_8of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_9of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }
    function testMoveTimeForward_10of10() public {
        bool moveTimeForward = true;
        Assert.equal(moveTimeForward, true, "Wheeee");
    }

    function testResetState() public {
        bool result = rdc.resetState();
        Assert.equal(result, true, "State should have been reset as long as blocks moved forward");
    }

    //fallback function
    function() external payable {}
}