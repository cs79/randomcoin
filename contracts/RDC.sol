pragma solidity ^0.4.23;

// attempt at a fully unified token with a bunch of extras

import "../installed_contracts/zeppelin/contracts/token/MintableToken.sol";
import "../installed_contracts/zeppelin/contracts/token/BurnableToken.sol";

contract RDC is MintableToken, BurnableToken {

    using SafeMath for uint256;

    // STATE VARIABLES
    //----------------

    uint256 public availablePayout;  // made public for testing
    uint256 public haircut;  // made public for testing
    uint256 public averageRate;
    uint256 private lastAvgRate;
    uint256 private txCount;  // use this + last rate to adjust averageRage
    uint256 public expectedRate;
    uint256 private halfWidth;
    uint256 public liquidationBlockNumber;
    uint256 public blockWaitTime;
    uint256 public minimumPegInBaseAmount; // liquidation haircut
    uint256 public minimumPegInMultiplier;
    uint256 public minTxToActivate;
    uint256 public minBalanceToActivate;

    // for tracking recent transactions in a frontend UI / during testing
    uint256[16] public latestRates;
    uint8 private maxRateIndex;
    uint8 private currentRateIndex;
    bool private rateArrayFull;

    // state management
    enum State { Funding, Active, Liquidating }
    State public state;
    bool private txLockMutex; // possibly redundant with transfer() calls


    // EVENTS
    //-------

    event PeggedIn(address _add, uint256 _amt);
    event PeggedOut(address _add, uint256 _amt);
    event ChangedPegInBase(uint256 _amt);
    event ChangedBlockWaitTime(uint256 _time);
    event TriggeredEquitableLiquidation(address _add);
    event TriggeredEquitableDestruct();
    event StateChangeToFunding();
    event StateChangeToActive();
    event StateChangeToLiquidating();
    event MadeEquitableCashout(address _add, uint _amt);
    event FullContractReset(address _add);  // maybe; kind of redundant w/ StateChangeToFunding


    // MODIFIERS
    //----------

    modifier notLiquidating() {
        require(state != State.Liquidating, "State must NOT be Liquidating");
        _;
    }

    modifier stateIsActive() {
        require(state == State.Active, "State must be Active");
        _;
    }

    modifier stateIsLiquidating() {
        require(state == State.Liquidating, "State must be Liquidating");
        _;
    }

    modifier blockWaitTimeHasElapsed() {
        require(state == State.Liquidating, "State must be Liquidating");
        require(block.number.sub(liquidationBlockNumber) >= blockWaitTime, "Insufficient block time elapsed");
        _;
    }

    modifier canAffordPegIn() {
        require(msg.value >= (minimumPegInBaseAmount.mul(minimumPegInMultiplier)), "Insufficient peg in value");
        _;
    }

    // mechanism to allow update from funding to active
    modifier canChangeStateToActive() {
        _;
        if (state == State.Funding) {
            if (txCount >= minTxToActivate || address(this).balance >= minBalanceToActivate) {
                state = State.Active;
                emit StateChangeToActive();
            }
        }
    }


    // CONSTRUCTOR
    //------------

    constructor()
    public
    {
        owner = msg.sender;
        minimumPegInBaseAmount = 100 szabo; // ~ 5 cents
        minimumPegInMultiplier = 10;
        averageRate = 100;  // since there are no floats yet, index to 100 (or higher ?) instead of 1
        expectedRate = 100;  // think about this... maybe higher for better decimal approximation ?
        halfWidth = 50;
        blockWaitTime = 10; //changed to 10 for testing //5760 * 14;  // 2 weeks seems reasonable I guess 
        minTxToActivate = 10;
        minBalanceToActivate = 10 finney;
        maxRateIndex = 15;
        rateArrayFull = false;
        state = State.Funding;
        txLockMutex = false;
    }


    // FUNCTIONS
    //----------

    // generate a random exchange rate for RDC <--> ETH
    function randomRate()
    public //private - made public for testing only
    view
    returns(uint)
    {
        // insecure placeholder; use something like RANDAO for a "real" implementation:
        // changing block.timestamp to block.number so that Solidity tests can run; this is super insecure
        // Solidity tests in truffle can run sub-second so block timestamps are the same as each other for subsequent blocks
        uint8 _rand = uint8(uint256(keccak256(abi.encodePacked(block.number, block.difficulty))) % 251);
        // rescale to mean 100 (or whatever) -- 0 and 250 hardcoded here based on how _rand is calculated
        uint _rescaled = rescaleRate(0, 250, expectedRate, halfWidth, _rand);
        return _rescaled;
    }

    // rescale rate to fit within a new range (expectedRate +/- halfWidth)
    function rescaleRate(uint _min, uint _max, uint _ev, uint _buf, uint _x)
    private
    view
    returns(uint)
    {
        // rescale _min, _max to _ev-_width, _ev+_width and then return the f(_x) value using:
        // https://stackoverflow.com/questions/5294955/how-to-scale-down-a-range-of-numbers-with-a-known-min-and-max-value
        uint _a = _ev.sub(_buf);
        uint _b = _ev.add(_buf);
        require(_a < _b, "_buf has under- or overflowed");  // redundant now with SafeMath I think ?
        //return ((((_b - _a) * (_x - _min)) / (_max - _min)) + _a);
        return ((((_b.sub(_a)).mul((_x.sub(_min)))).div((_max.sub(_min)))).add(_a));
    }

    // keep track of the running average of random rates
    function updateAverageRate(uint _last_rate)
    private
    returns(uint)
    {
        lastAvgRate = averageRate;
        uint _newAR;
        if (txCount == 0) {
            _newAR = _last_rate;
        }
        else {
            // averageRate = ((lastAvgRate * txCount) + [new random rate]) / txCount + 1
            _newAR = (lastAvgRate.mul(txCount).add(_last_rate)).div(txCount.add(1));
        }
        averageRate = _newAR;
        // then increment txCount
        txCount = txCount.add(1);
        return _newAR;
    }

    // update the storage array of latest rates; should be called by both pegIn() and pegOut()
    function updateRateStorage(uint256 _rate)
    private
    returns(uint256)
    {
        uint8 _index_used;
        if (!rateArrayFull) {
            // just insert the rate in the latest slot
            latestRates[currentRateIndex] = _rate;
            // update the relevant metadata
            _index_used = currentRateIndex;
            currentRateIndex += 1;
            // guarantees safety for the increment operation - will not overflow as uint8 can store values > 15
            if (currentRateIndex == maxRateIndex) {
                rateArrayFull = true;
            }
        } else {
            _index_used = maxRateIndex;
            uint256[16] memory _temp_rates;
            // shift old rates one index to the left
            for (uint8 i = 1; i <= maxRateIndex; i++) {
                _temp_rates[i - 1] = latestRates[i];
            }
            // insert the new rate in the latest slot of _temp_rates
            _temp_rates[maxRateIndex] = _rate;
            // reassign latestRates to the updated temp array
            latestRates = _temp_rates;
        }
        return latestRates[_index_used];
    }

    // peg in from ETH to RDC
    function pegIn()
    public
    payable
    notLiquidating()
    canAffordPegIn()
    canChangeStateToActive()
    returns(uint256)
    {
        address _add = msg.sender;
        // generate random rate for peg-in transaction
        uint256 _rndrate = randomRate();
        uint256 _rdc_amt = msg.value.mul(_rndrate);
        // mint new RDC in exchange for ETH at the calculated rate
        mint(_add, _rdc_amt);
        // capture the haircut to deduct from availablePayout
        haircut = haircut.add(minimumPegInBaseAmount);
        // update the values of averageRate and the latestRates storage array
        updateAverageRate(_rndrate);
        updateRateStorage(_rndrate);
        // emit the PeggedIn event
        emit PeggedIn(_add, _rdc_amt);
        // return the amount received for peg-in
        return _rdc_amt;
    }

    // peg out from RDC to ETH
    function pegOut(uint _amt)
    public
    payable
    stateIsActive()
    returns(uint)
    {
        // check the mutex to prevent reentrancy on payable transaction
        require(!txLockMutex, "txLockMutex must be unlocked");
        // check that account has sufficient balance
        address _add = msg.sender;
        require(balanceOf(_add) >= _amt, "Insufficient balance to peg out");
        // calculate amount of eth to send (DOES THIS WORK WITHOUT FLOATS ??? MIGHT NEED TO RECONFIGURE MATH FORMULA HERE)
        uint _rndrate = randomRate();
        uint _eth_amt = _amt.div(_rndrate);
        // if contract would be drained by peg out, allow equitable withdrawal of whatever is left
        if (_eth_amt > address(this).balance) {
            equitableDestruct();
        }
        // otherwise, send the toSend amount to _add (after switching the mutex)
        txLockMutex = true;
        // burn the pegged-out RDC amount, then send ETH in exchange
        burn(_amt);
        _add.transfer(_eth_amt);
        // update the values of averageRate and the latestRates storage array
        updateAverageRate(_rndrate);
        updateRateStorage(_rndrate);
        // release the mutex after external call
        txLockMutex = false;
        emit PeggedOut(_add, _amt);
        // return the amount pegged out
        return _amt;
    }

    // this is something of a potential reputational risk
    // a malicious owner could abuse this; maybe put a timer on its use
    // (or don't use it at all)
    function changePegInBase(uint256 _new_base)
    public
    onlyOwner()
    returns(uint256)
    {
        // 10 percent window is sort of arbitrary currently
        // also nothing really prevents you from changing this rapidly and repeatedly atm...
        // maybe add in a timer for this as well ?
        uint256 _lower_bound = minimumPegInBaseAmount.mul(90).div(100);
        uint256 _upper_bound = minimumPegInBaseAmount.mul(110).div(100);
        require(_new_base >= _lower_bound, "Cannot lower minimumPegInBaseAmount that far");
        require(_new_base <= _upper_bound, "Cannot raise minimumPegInBaseAmount that far");
        
        // change the value of minimumPegInBaseAmount
        minimumPegInBaseAmount = _new_base;

        // emit the relevant event
        emit ChangedPegInBase(_new_base);

        // return the new value of minimumPegInBaseAmount
        return _new_base;
    }

    // same caveats re: abuse apply here as to changePegInBase
    // use this with caution; maybe don't implement at all
    function changeBlockWaitTime(uint256 _new_wt)
    public
    onlyOwner()
    returns(uint256)
    {
        uint256 _lower_bound = blockWaitTime.mul(90).div(100);
        uint256 _upper_bound = blockWaitTime.mul(110).div(100);
        require(_new_wt >= _lower_bound, "Cannot lower blockWaitTime that far");
        require(_new_wt <= _upper_bound, "Cannot raise blockWaitTime that far");

        // change the value of blockWaitTime
        blockWaitTime = _new_wt;

        // emit the relevant event
        emit ChangedBlockWaitTime(_new_wt);

        // return the new value of blockWaitTime
        return _new_wt;
    }

    // automatic "fair self-destruct" if peg breaks
    function equitableDestruct()
    private
    notLiquidating()
    returns(bool)
    {
        // set state to Liquidating
        startLiquidation();
        // probably need some sort of "startCountdown()" function to get called here which allows for withdrawal within a particular window
        // (window also should then be a state variable -- maybe this can be changed by owner, but ONLY within certain [reasonable] limits)
        // emit relevant events
        emit TriggeredEquitableDestruct();
        // return true for testing
        return true;
    }

    // owner-forced "fair self-destruct"
    function equitableLiquidation()
    public
    notLiquidating()
    onlyOwner()
    returns(bool)
    {
        // set state to Liquidating
        startLiquidation();
        // emit relevant events
        emit TriggeredEquitableLiquidation(msg.sender);
        // return true for testing
        return true;
    }

    // instead of just manually changing the state in equitableDestruct / equitableLiquidation, use a smarter method here:
    function startLiquidation()
    private
    notLiquidating()  // possibly redundant but maybe keep to be safe
    returns(bool)
    {
        // any modifiers needed here ?
        // set liquidation block height to start "countdown" before owner can reset state
        liquidationBlockNumber = block.number;

        // set availablePayout (minus the haircut accumulated so far via pegIn transactions)
        availablePayout = address(this).balance.sub(haircut);

        // pause minting during liquidation s.t. totalSupply is stable for calculating fair payouts
        mintingFinished = true;

        state = State.Liquidating;
        emit StateChangeToLiquidating();

        // how can we start a timer and then "ensure" that the contract gets reset to funding state afterwards?
        // this may not be directly possible, so can we make a modifier for ALL other functions that resets the state if eligible to do so ?
        
        // return true for testing
        return true;
    }

    // "claim fair payout" after the peg has broken
    function equitableCashout()
    public
    payable
    stateIsLiquidating()
    returns(uint)
    {
        // check the mutex for payable function
        require(!txLockMutex, "txLockMutex must be unlocked");
        address _add = msg.sender;
        uint256 _RDCToCashOut = balanceOf(_add);
        require(_RDCToCashOut > 0, "Nothing to cash out");
        // calculate payout based on ratio of _RDCToCashOut to totalSupply, multiplied by availablePayout
        uint256 _payout = _RDCToCashOut.mul(availablePayout).div(totalSupply);
        // set the lock mutex before transfer
        txLockMutex = true;
        // burn the RDC balance in exchange for ETH
        burn(_RDCToCashOut);
        _add.transfer(_payout);
        // release the lock mutex after transfer
        txLockMutex = false;
        // may need to handle the case where the last person to withdraw cannot do so because fees have drained what would have been proportional shares initially
        
        // emit the relevant event
        emit MadeEquitableCashout(_add, _payout);
        // return the amount paid out
        return _payout;
    }

    // IDEA: owner can reset state, but ONLY after some window of time has passed allowing people enough time to withdraw (e.g. 2 weeks or something)
    // TODO: VALIDATE THAT THESE THINGS STILL MAKE SENSE TO RESET GIVEN THAT THIS IS A PERPETUAL RDC CONTRACT NOW
    function resetState()
    public
    onlyOwner()
    blockWaitTimeHasElapsed()  //disabling for testing as there is no good way to advance block time in Solidity tests :\
    returns(bool)
    {
        // ALL relevant variables need to be handled here - check constructor / all state vars
        // worth resetting availablePayout to 0 or something here, to keep resetting "cleaner" ? Logically unnecessary I think
        haircut = 0; // I think this should be reset here
        averageRate = expectedRate;  // maybe ? or shoud we track this over longer horizons?
        lastAvgRate = 0;
        txCount = 0;
        state = State.Funding;
        txLockMutex = false;  // hopefully redundant
        
        // allow minting again
        mintingFinished = false;
        
        // emit relevant event(s)
        emit FullContractReset(msg.sender);
        emit StateChangeToFunding();

        // return true for testing
        return true;
    }

    // fallback function
    function () external payable {}

}