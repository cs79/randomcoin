pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RDC.sol";

contract TestRDC {

    // set ETH balance for this testing contract to test RDC functionality that requires it
    uint256 public initialBalance = 10 ether;
    RDC rdc;

    /** @dev Test hook to instantiate owned instance of RDC before running tests
        @dev This allows for testing of onlyOwner functions in RDC
     */
    function beforeAll() public {
        rdc = new RDC();
    }

    /** @dev This is a simple test to ensure that the constructor properly set state variables, including the Owner
        @dev Ownership is handled via the Ownable contract inherited from the OpenZeppelin package
        @dev This test covers all state variables set by the constructor except for the State enum (enums are not currently supported by the ABI)
     */
    function testRandomCoinConstructor() public {
        address expected_owner = address(this);
        uint256 expected_mpib = 100 szabo;
        uint256 expected_mpim = 10;
        uint256 expected_ar = 100;
        uint256 expected_er = 100;
        uint256 expected_hw = 50;
        uint256 expected_bwt = 10; //5760 * 14;  // changed for testing
        uint256 expected_mtta = 10;
        uint256 expected_mbta = 10 finney;
        uint256 expected_mri = 15;
        bool expected_raf = false;
        bool expected_tlm = false;
    
        Assert.equal(expected_owner, rdc.owner(), "Owner should be the deploying contract");
        Assert.equal(expected_mpib, rdc.minimumPegInBaseAmount(), "minimumPegInBaseAmount should be equal to 100 szabo");
        Assert.equal(expected_mpim, rdc.minimumPegInMultiplier(), "minimumPegInMultiplier should be equal to 10");
        Assert.equal(expected_ar, rdc.averageRate(), "averageRate should be equal to 100");
        Assert.equal(expected_er, rdc.expectedRate(), "expectedRate should be equal to 100");
        Assert.equal(expected_hw, rdc.halfWidth(), "halfWidth should be equal to 50");
        Assert.equal(expected_bwt, rdc.blockWaitTime(), "blockWaitTime should be equal to 5760 * 14");
        Assert.equal(expected_mtta, rdc.minTxToActivate(), "minTxToActivate should be equal to 10");
        Assert.equal(expected_mbta, rdc.minBalanceToActivate(), "minBalanceToActivate should be equal to 10 finney");
        Assert.equal(expected_mri, rdc.maxRateIndex(), "maxRateIndex should be equal to 15");
        Assert.equal(expected_raf, rdc.rateArrayFull(), "rateArrayFull should be false");
        Assert.equal(expected_tlm, rdc.txLockMutex(), "txLockMutex should be false");
    }

    /** @dev Test that ownership of the RDC contract can be properly transferred to a new owner
        @dev This functionality also comes from the Ownable contract in the OpenZeppelin library
        @dev This test covers the transferOwnership() function
     */
    function testRDCOwnershipTransfer() public {
        RDC _xfer_rdc = new RDC();

        address expectedOwner = DeployedAddresses.RDC();
        // attempt to transfer ownership
        _xfer_rdc.transferOwnership(expectedOwner);
        // check if we successfully did so
        Assert.equal(expectedOwner, _xfer_rdc.owner(), "RandomCoin contract should now own RDCToken instance");
    }

    /** @dev Test that totalSupply increases after minting some tokens
        @dev RDC is Mintable via imports from the OpenZeppelin package
        @dev This test covers both the mint() function and the totalSupply() state variable which are key for other functions
     */
    function testMintAndTotalSupply() public {
        address _add = address(this);
        uint firstXfer = 9000;
        uint secondXfer = 1000;
        uint expected = firstXfer + secondXfer;

        rdc.mint(_add, firstXfer);
        rdc.mint(_add, secondXfer);

        Assert.equal(expected, rdc.totalSupply(), "totalSupply should be 10000");
    }

    /** @dev This tests that RDC tokens are properly transferable, as this transferability increases their utility
        @dev This functionality is inherited from elements of the OpenZeppelin package (ERC20Basic interface, BasicToken contract)
        @dev This test covers the transfer() function
     */
    function testRDCTokenTransfer() public {
        address _add1 = address(this);
        address _add2 = DeployedAddresses.RDCToken();
        
        // mint to _add1, transfer to _add2
        rdc.mint(_add1, 1000);
        rdc.transfer(_add2, 500);

        uint256 _expected = 500;
        Assert.equal(_expected, rdc.balanceOf(_add2), "balance of _add2 should be 500");
    }

    /** @dev Test that multiple random rates fall within the expected (rescaled) range
        @dev This test covers randomRate() directly, and rescaleRate() indirectly (the latter is always called by the former)
     */
    function testMultipleRandomRate() public {
        uint256 low = 50;
        uint256 high = 150;
        uint256 _cur_rate;
        for (uint i = 0; i < 5; i++) {
            _cur_rate = rdc.randomRate();
            Assert.isAtLeast(_cur_rate, low, "Random rate should be at least 50");
            Assert.isAtMost(_cur_rate, high, "Random rate should be at most 150");
        }
    }

    /** @dev Test that an address can properly receive RDC tokens in exchange for ETH
        @dev This test is also used to ensure that the contract state can move from Funding to Active when the minBalanceToActivate is sent
        @dev (Subsequent tests to peg out would fail if the contract state did not change to Active)
        @dev This test covers the pegIn() function
     */
    function testPegIn() public {
        rdc.pegIn.value(15 finney).gas(1000000)();  // actual gas cost is something like 175,000 it appears
        Assert.isAtLeast(rdc.balanceOf(address(this)), 1, "pegIn should grant at least 1 RDC");
    }

    /** @dev Test various functionality related to pegging in multiple times
        @dev This tests that averageRate gets updated while pegging in, that it falls within the expected range, and that it changes over time
        @dev This also tests that the latestRates array gets properly populated
        @dev *** N.B. that it is possible (though very unlikely) to draw the same random number 5 times in a row, so in the (unlikely) event that this test fails, try rerunning it
        @dev This test covers pegIn(), updateAverageRate(), and latestRates
     */
    function testMultiplePegIn() public {
        uint256 _cap = 5;
        uint256[5] memory _ARs;
        uint256 _sumAR;
        // peg in a few times
        for (uint8 i; i < _cap; i++) {
            rdc.pegIn.value(15 finney).gas(300000)();
            uint256 _curAR = rdc.averageRate();
            Assert.isAtLeast(_curAR, 50, "averageRate should be at least 50");
            Assert.isAtMost(_curAR, 150, "averageRate should be at most 150");
            _ARs[i] = _curAR;
            _sumAR += _curAR;
        }
        // check that averageRate changed during loop
        uint256 _avgAR = _sumAR / _cap;
        uint8 _equalsAvg;
        for (uint8 j; j < _cap; j++) {
            if (_ARs[j] == _avgAR) {
                _equalsAvg += 1;
            }
        }
        Assert.notEqual(_equalsAvg, _cap, "averageRate should have changed over multiple pegIn() calls");
        // check latestRates after loop
        uint256 _expectValueAtIndex = 2;
        uint256 _doNotExpectValueAtIndex = 10;
        Assert.isAtLeast(rdc.latestRates(_expectValueAtIndex), 1, "A value should have been assigned to index 2 of latestRates");
        Assert.equal(rdc.latestRates(_doNotExpectValueAtIndex), 0, "A value should not have been assigned to index 10 of latestRates");
    }

    /** @dev Test that an account can properly receive ETH in exchange for RDC when pegging out
        @dev This test covers the pegOut() function
     */
    function testPegOut() public payable {
        uint256 _this_eth_bal = this.balance;
        uint256 _this_rdc_bal = rdc.balanceOf(address(this));
        Assert.isAtLeast(_this_rdc_bal, 100, "this contract should have at least 100 RDCTokens");
        rdc.pegOut(_this_rdc_bal / 10);
        Assert.isAtLeast(this.balance, _this_eth_bal + 1, "this contract should have received some eth from pegging out");
        Assert.equal(rdc.balanceOf(this), _this_rdc_bal - (_this_rdc_bal / 10), "this contract should have lost 1/10th of its RDCTokens");
    }

    /** @dev Test that the Owner can force an equitable liquidation event
        @dev This is essentially a test of startLiquidation(), which is called by equitableLiquidation() and equitableDestruct() (under different circumstances)
        @dev This test covers the equitableLiquidation() function directly, and the startLiquidation() and equitableDestruct() functions indirectly
     */
    function testEquitableLiquidation() public {
        bool result = rdc.equitableLiquidation();
        Assert.equal(result, true, "Liquidation should have been triggered");
        Assert.notEqual(rdc.liquidationBlockNumber(), 0, "liquidationBlockNumber should have been set");
        Assert.notEqual(rdc.availablePayout(), 0, "availablePayout should habe been set");
        Assert.equal(address(rdc).balance - rdc.haircut(), rdc.availablePayout(), "availablePayout should have been haircut");
        Assert.equal(rdc.mintingFinished(), true, "mintingFinished should have been set to true");
    }

    /** @dev Test that accounts can cash out their "fair share" of ETH in the RDC contract if the exchange peg breaks
        @dev This test covers the equitableCashout() function
     */
    function testEquitableCashout() public payable {
        uint256 _expected_rdc_bal = 0;
        uint256 _this_eth_bal = address(this).balance;
        rdc.equitableCashout();
        Assert.equal(_expected_rdc_bal, rdc.balanceOf(address(this)), "entire RDC balance of testing contract should have been cashed out");
        Assert.isAtLeast(address(this).balance, _this_eth_bal + 1, "the testing contract should have cashed out at least 1 wei worth of ETH");
    }

    /** @dev The next 10 "tests" simply move the block number forward (to allow testing of resetState()) and can be ignored by the tester
        @dev This is done in this fashion as there does not appear to exist any convenient way to do this in Solidity (no equivalent of evm_mine)
     */
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

    /** @dev This tests the contract state can be reset by a new peg-in transaction after the cash-out period has elapsed
        @dev This test covers the canChangeStateToFunding() modifier
     */
    function testResetViaPegIn() public {
        Assert.equal(rdc.mintingFinished(), true, "Minting should be paused in Liquidation state");
        rdc.pegIn.value(15 finney).gas(300000)();
        Assert.equal(rdc.mintingFinished(), false, "Minting should be allowed again after contract reset");
    }

    /** @dev fallback function */
    function() external payable {}
}
