pragma solidity ^0.4.0;

import "./IBFactory.sol";
import "installed_contracts/zeppelin/contracts/ownership/Ownable.sol";

// TODO: use SafeMath wherever making calculations here (and in other contracts)
// TODO: implement Ownable style interface for this, RandomLotto, anything else I write that needs it
// possibly implement equitableDestruct as a base contract to inherit here and in RandomLotto
// implement a base contract structure with array of structs w/ mappings of balances as an iterable structure for checking balances, payout out to holders, etc. to be used here + RandomLotto

contract RandomCoin is Ownable {
    // declare state / storage variables
    //address owner;  -- redundant w/ Ownable.sol // for recovery, but make sure it can't do anything weird to pegged in balances

    // averageRate should have an expected value of 100  (1, ideally, but no floats)
    // an "ideal" version of this would allow for timeseries graphing of average rate in the web service -- not sure how this might be achieved though
    uint averageRate;  // update this as events are emitted ? or rely on web service to aggregate records later?
    
    // need to keep track of everyone who has pegged in
    // does "randomcoin" need to be an actual "token"? should it be? I guess that is more interesting tbh... learn about how to do this
    // (alternative is simply using a mapping as the sole arbiter of balances; all "trading" done with the contract only via peg-in / peg-out)
    IBFactory ibf;
    IterableBalances rdcBalances;  // I want this to be a new instance every time the state recycles

    // use (IB.balances[add] / IB.totalBalance) * availablePayout to assign equitable balances to holders
    uint availablePayout;  // set to the CURRENT BALANCE of ether at this contract when an equitable liquidation occurs

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

    // declare modifiers
    // modifier to check that call is internal (for payables that must be public, but should only be triggered by this contract's functions)
    modifier isInternalCall(address _add) {
        require(
            msg.sender == address(this),
            "Function must be called by this contract"
        );
        _;
    }

    // need state-checking modifiers as well
    modifier notLiquidating() {
        require(
            state != State.Liquidating
        );
        _;
    }

    modifier stateIsActive() {
        require(
            state == State.Active
        );
        _;
    }

    modifier canWithdrawEquitably() {
        require(
            state == State.Liquidating
        );
        _;
    }

    // declare constructor + other functions
    constructor()
    public
    {
        owner = msg.sender;
        averageRate = 100;  // since there are no floats yet, index to 100 instead of 1
        ibf = IBFactory(this);
        rdcBalances = ibf.createIB();
        state = State.Funding;
        txLockMutex = false;
    }

    function randomRate()
    private
    pure 
    returns(uint)
    {
        // the most important piece -- will be called to generate the rate when pegIn() or pegOut() is called
        // needs to have an EV of 100
        // no idea what math / random libraries are already available in solidity... hopefully something I can work with for this 
        // just assume that RANDAO is up and running for the time being; tackle random generation last ?
        // can use insecure method hashing block data as a placeholder; replace "in production" w/ something like RANDAO
    }

    function pegIn()
    public
    payable
    notLiquidating()
    {
        
        // logic for checking whether holder is in index is now in IterableBalances.sol
        // just add the balance
        address _add = msg.sender;
        uint _rndamt = msg.value * randomRate();
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
        // logic for checking randomcoin balance has been moved to IterableBalances.sol
        address _add = msg.sender;
        uint _rndamt = _amt / randomRate();

        // still need to think about what happens if amount to send would drain the balance of the contract
        // MAYBE -- equitableDestruct() to return something to everyone
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
    canWithdrawEquitably()
    {
        // check the mutex for payable function
        require(!txLockMutex);
        address _add = msg.sender;
        uint _payout = (rdcBalances.balances(_add) / rdcBalances.totalBalance()) * availablePayout;
        // set the lock mutex before transfer
        txLockMutex = true;
        _add.transfer(_payout);
        // release the lock mutex after transfer
        txLockMutex = false;
        // may need to handle the case where the last person to withdraw cannot do so because fees have drained what would have been proportional shares initially
    }

    // can't be private -- if public, assert that msg.sender is this contract's address ?
    function equitableDestruct()
    public
    //payable
    isInternalCall(msg.sender)
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
    //payable
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
    {
        // any modifiers needed here ?
        state = State.Liquidating;
        emit StateChangeToLiquidating();

        // how can we start a timer and then "ensure" that the contract gets reset to funding state afterwards?
        // this may not be directly possible, so can we make a modifier for ALL other functions that resets the state if eligible to do so ?

    }
}
