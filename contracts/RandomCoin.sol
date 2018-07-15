pragma solidity ^0.4.0;

import "./IBFactory.sol";
import "installed_contracts/zeppelin/contracts/ownership/Ownable.sol";
import "installed_contracts/zeppelin/contracts/math/SafeMath.sol";

// TODO: use SafeMath wherever making calculations here (and in other contracts)
// possibly implement equitableDestruct as a base contract to inherit here and in RandomLotto

contract RandomCoin is Ownable {
    /*

    State / storage variables:
    --------------------------
    availablePayout         : should be set to CURRENT BALANCE of eth at this contract (minus some % to cover fees?) when liquidation occurs
    averageRate             : should have EV of 1 (or 100; index level)
    expectedRate            : hardcode this as a point of comparison for averageRate
    halfWidth               : half interval around expectedRate to get random rates from
    liquidationBlockNumber  : block height at liquidation event
    blockWaitTime           : blocks to wait after liquidation before state reset is allowed
    ibf                     : factory to create new IterableBalance tracking contracts ("objects")
    rdcBalances             : IterableBalances instance to track ownership of RNDC (all pegged-in accts)
    State                   : enum of states this contract can be in
    state                   : contract's current State value
    txLockMutex             : transaction locking mutex to prevent reentrancy

    Notes:
    ------
    - averageRate needs to be managed without floats for now
    - averageRate should ideally create (somewhere) a record of its past values, for frontend TS graphs
    - rdcBalances needs to be "reinstantiated" every time this contract resets (i.e. if liquidated)
    - use (IB.balances[add] / IB.totalBalance) * availablePayout to assign equitable balances to holders
    - txLockMutex may be better replaced by something in an OpenZeppelin library

    */

    using SafeMath for uint256;
    
    // TODO: calculate this MINUS SOME % TO COVER FEES when liquidation is called
    uint256 availablePayout;
    // TODO: update this as events are emitted
    uint256 averageRate;
    uint256 expectedRate;
    uint halfWidth;
    uint256 liquidationBlockNumber;
    uint256 blockWaitTime;
    
    IBFactory ibf;
    IterableBalances rdcBalances;

    // TODO: import ERC20 token contract from OpenZeppelin, instantiate RandomCoin token, use IB to track it (maybe ?)
    // does "randomcoin" need to be an actual "token"? should it be? I guess that is more interesting tbh... learn about how to do this
    // (alternative is simply using a mapping as the sole arbiter of balances; all "trading" done with the contract only via peg-in / peg-out)
    // if RNDC is a TOKEN, IterableBalances is kind of pointless because then you need to keep states in sync
    // harder to recycle state of this contract and start a "new round"
    // I guess you could let people hold on to their RNDC from previous rounds, and if they missed a cash-out state they could peg out on next round
    // but then how to calculate "equitable payouts" ? equitable to "last round", or equitable to OVERALL RNDC outstanding ?
    // from mechanism design perspective, an ERC20 token may be better
    // (disincentivizes rapid peg-in / peg-out to try to force a liquidation after some disproportionate peg-outs)


    // state management
    enum State { Funding, Active, Liquidating }
    State state;
    bool txLockMutex; // possibly redundant with transfer() calls

    // declare events
    // do any of these need to be indexed ? any other thing we want to log ?
    // does it make sense to log "XXX failed" type events?  or are these self-evident in the logs?
    event PeggedIn(address _add, uint256 _amt);
    event PeggedOut(address _add, uint256 _amt);
    event TriggeredEquitableLiquidation(address _add);
    event TriggeredEquitableDestruct();
    event StateChangeToFunding();
    event StateChangeToActive();
    event StateChangeToLiquidating();
    event FullContractReset(address _add);  // maybe; kind of redundant w/ StateChangeToFunding

    // TODO: add more events (or just return values to functions) to make test writing easier

    // declare modifiers
    modifier notLiquidating() {
        require(state != State.Liquidating);
        _;
    }

    modifier stateIsActive() {
        require(state == State.Active);
        _;
    }

    modifier stateIsLiquidating() {
        require(state == State.Liquidating);
        _;
    }

    modifier blockWaitTimeHasElapsed() {
        require(state == State.Liquidating);
        require(block.number.sub(liquidationBlockNumber) >= blockWaitTime);
        _;
    }

    // declare constructor + other functions
    constructor()
    public
    {
        owner = msg.sender;
        availablePayout = 0;  // maybe ?
        averageRate = 100;  // since there are no floats yet, index to 100 (or higher ?) instead of 1
        expectedRate = 100;  // think about this... maybe higher for better decimal approximation ?
        halfWidth = 50;
        blockWaitTime = 5760 * 14;  // 2 weeks seems reasonable I guess 
        ibf = IBFactory(this);
        rdcBalances = ibf.createIB();
        state = State.Funding;
        txLockMutex = false;
    }

    function randomRate()
    private
    view
    returns(uint)
    {
        // the most important piece -- will be called to generate the rate when pegIn() or pegOut() is called
        // needs to have an EV of 100 (or whatever we set the expected rate to be)
        // no idea what math / random libraries are already available in solidity... hopefully something I can work with for this 
        // just assume that RANDAO is up and running for the time being; tackle random generation last ?
        // can use insecure method hashing block data as a placeholder; replace "in production" w/ something like RANDAO

        // insecure placeholder:
        uint8 _rand = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 251);
        // rescale to mean 100 (or whatever) -- 0 and 250 hardcoded here based on how _rand is calculated
        uint _rescaled = rescaleRate(0, 250, expectedRate, halfWidth, _rand);

        // cannot be zero:
        if (_rescaled == 0) {
            _rescaled = 1;
        }
        return _rescaled;
    }

    function rescaleRate(uint _min, uint _max, uint _ev, uint _buf, uint _x)
    private
    view
    returns(uint)
    {
        // rescale _min, _max to _ev-_width, _ev+_width and then return the f(_x) value using:
        // https://stackoverflow.com/questions/5294955/how-to-scale-down-a-range-of-numbers-with-a-known-min-and-max-value
        uint _a = _ev.sub(_buf);
        uint _b = _ev.add(_buf);
        require(_a > 0);
        require(_a < _b);  // redundant now with SafeMath I think ?
        //return ((((_b - _a) * (_x - _min)) / (_max - _min)) + _a);
        return ((((_b.sub(_a)).mul((_x.sub(_min)))).div((_max.sub(_min)))).add(_a));
    }

    function pegIn()
    public
    payable
    notLiquidating()
    {
        // logic for checking whether holder is in index is now in IterableBalances.sol
        // just add the balance
        address _add = msg.sender;
        uint _rndamt = msg.value * randomRate();  // can I use SafeMath here ? need to recast randomRate return variable as uint256?
        rdcBalances.addBalance(_add, _rndamt);  // add the RANDOMCOIN balance, not eth sent amount
        // emit the PeggedIn event
        emit PeggedIn(_add, _rndamt);
    }

    function pegOut(uint _amt)
    public
    payable
    stateIsActive()
    {
        // check the mutex to prevent reentrancy on payable transaction
        require(!txLockMutex);
        address _add = msg.sender;
        // logic for checking randomcoin balance has been moved to IterableBalances.sol
        // BUT still need to check here I think - otherwise sender could easily force equitableDestruct()
        require(rdcBalances.balances(_add) >= _amt, "Insufficient balance to peg out");

        // calculate amount of eth to send (DOES THIS WORK WITHOUT FLOATS ??? MIGHT NEED TO RECONFIGURE MATH FORMULA HERE)
        uint _rndamt = _amt / randomRate(); // maybe rename - _rndamt here is a "random amount of eth"

        // if contract would be drained by peg out, allow equitable withdrawal of whatever is left
        if (_rndamt > address(this).balance) {
            equitableDestruct();
        }
        // otherwise, send the toSend amount to _add (after switching the mutex)
        txLockMutex = true;
        rdcBalances.deductBalance(_add, _amt);  // deduct the RANDOMCOIN balance, not eth payout amt
        _add.transfer(_rndamt);
        // release the mutex after external call
        txLockMutex = false;
        // emit the PeggedOut event
        emit PeggedOut(_add, _amt);
    }

    function equitableWithdrawal()  // maybe rename this...
    public
    payable
    stateIsLiquidating()
    {
        // check the mutex for payable function
        require(!txLockMutex);
        address _add = msg.sender;
        uint _payout = (rdcBalances.balances(_add).div(rdcBalances.totalBalance())).mul(availablePayout);
        // set the lock mutex before transfer
        txLockMutex = true;
        _add.transfer(_payout);
        // release the lock mutex after transfer
        txLockMutex = false;
        // may need to handle the case where the last person to withdraw cannot do so because fees have drained what would have been proportional shares initially
    }

    function equitableDestruct()
    private
    notLiquidating()
    {
        // set state to Liquidating
        startLiquidation();
        // probably need some sort of "startCountdown()" function to get called here which allows for withdrawal within a particular window
        // (window also should then be a state variable -- maybe this can be changed by owner, but ONLY within certain [reasonable] limits)

        // emit relevant events
        emit TriggeredEquitableDestruct();
    }

    function equitableLiquidation()
    public
    notLiquidating()
    onlyOwner()
    {
        // set state to Liquidating
        startLiquidation();

        // emit relevant events
        emit TriggeredEquitableLiquidation(msg.sender);
    }

    // instead of just manually changing the state in equitableDestruct / equitableLiquidation, use a smarter method here:
    function startLiquidation()
    private
    notLiquidating()  // possibly redundant but maybe keep to be safe
    {
        // any modifiers needed here ?
        // set liquidation block height to start "countdown" before owner can reset state
        liquidationBlockNumber = block.number;

        // set availablePayout (minus some percentage to cover fees ?)
        // fees should be paid by caller of this function actually, not this contract, so below should be OK
        // however, we could haircut this by some flat fee (smallish) and require that any pegIn values be at least, say, 10x this small amount
        // in this case, set availablePayout to the result of a call to a new function that checks rdcBalance.numHolders
        // and multiplies that by the fee, deducting the result from address(this).balance to get the return value
        availablePayout = address(this).balance;

        state = State.Liquidating;
        emit StateChangeToLiquidating();

        // how can we start a timer and then "ensure" that the contract gets reset to funding state afterwards?
        // this may not be directly possible, so can we make a modifier for ALL other functions that resets the state if eligible to do so ?
        
    }

    // IDEA: owner can reset state, but ONLY after some window of time has passed allowing people enough time to withdraw (e.g. 2 weeks or something)
    function resetState()
    public
    onlyOwner()
    stateIsLiquidating()
    blockWaitTimeHasElapsed()
    {
        // ALL relevant variables need to be handled here - check constructor / all state vars
        // worth resetting availablePayout to 0 or something here, to keep resetting "cleaner" ? Logically unnecessary I think
        averageRate = expectedRate;  // maybe ? or shoud we track this over longer horizons?
        rdcBalances = ibf.createIB();  // unless we switch to RNDC token, perhaps
        state = State.Funding;
        txLockMutex = false;  // hopefully redundant

        // emit relevant event(s)
        emit FullContractReset(msg.sender);
        emit StateChangeToFunding();
    }
}
