pragma solidity ^0.4.23;

// try to put both the RDCToken and RandomCoin functionality into this file
// can keep as separate contracts; just need to ensure they're actually together

//import "./MintableToken.sol";  // changed to copy in this directory rather than openzeppelin dir
import "../installed_contracts/zeppelin/contracts/token/MintableToken.sol";

contract RDCToken is MintableToken {
    string public constant name = "RDCToken";
    string public constant symbol = "RDC";

    // Should be constructed by the RandomCoin contract (exactly once - bool for this?)
    constructor() public {
        owner = msg.sender;
    }

    // EXTREMELY IMPORTANT QUESTION: DOES THIS NEED TO IMPLEMENT ALL NAMED METHODS IN THE CONTRACTS IT INHERITS FROM?
    
}

contract RandomCoin is Ownable {
    /*

    State / storage variables:
    --------------------------
    availablePayout         : should be set to CURRENT BALANCE of eth at this contract (minus some % to cover fees?) when liquidation occurs
    haircut                 : effective fee on peg-in to help maintain the peg; could make this resettable by owner I guess via minimumPegInBaseAmount
    averageRate             : should have EV of 1 (or 100; index level)
    lastAvgRate             : used to recalculate averageRate as transactions occur
    txCount                 : used to recalculate averageRate as transactions occur
    expectedRate            : hardcode this as a point of comparison for averageRate
    halfWidth               : half interval around expectedRate to get random rates from
    liquidationBlockNumber  : block height at liquidation event
    blockWaitTime           : blocks to wait after liquidation before state reset is allowed
    minimumPegInBaseAmount  : effective liquidation haircut to help defend the peg
    minimumPegInMultiplier  : multiplier on top of minimumPegInBaseAmount to set the minimum value of a peg-in transaction
    rdct                    : factory to create a new (single) instance of the RandomCoinToken contract
    rdc                     : RandomCoinToken contract instance
    State                   : enum of states this contract can be in
    state                   : contract's current State value
    txLockMutex             : transaction locking mutex to prevent reentrancy
    rdcCreated              : boolean to track whether the contract has ever instantiated a RDC object from the factory

    Events:
    -------
    PeggedIn                        :
    PeggedOut                       :
    TriggeredEquitableLiquidation   :
    TriggeredEquitableDestruct      :
    StateChangeToFunding            :
    StateChangeToActive             :
    StateChangeToLiquidating        :
    MadeEquitableWithdrawal         : 
    FullContractReset               :


    Modifiers:
    ----------
    notLiquidating                  :
    stateIsActive                   :
    stateIsLiquidating              :
    blockWaitTimeHasElapsed         :
    canAffordPegIn                  : 

    Notes:
    ------
    - averageRate (and all math, for that matter) needs to be managed without floats for now
    - averageRate should ideally create (somewhere) a record of its past values, for frontend TS graphs
    - *** need to consider how holders of rdc from prior "round" of the life of this contract affects its viability
    - use (rdc.balanceOf(add) / rdc.totalSupply) * availablePayout to assign equitable balances to holders
    - txLockMutex may be better replaced by something in an OpenZeppelin library

    */

    using SafeMath for uint256;
    
    uint256 private availablePayout;
    uint256 private haircut;
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

    // to be deployed after instantiating this contract
    // should other functions force this (like PegIn()) if it doesn't exist yet ?
    RDCToken public rdc;
    // is the below redundant with address(address(this).rdc) ?
    address public rdcTokenAddress;  // for users to trade tokens with each other

    // harder to recycle state of this contract and start a "new round"
    // I guess you could let people hold on to their RNDC from previous rounds, and if they missed a cash-out state they could peg out on next round
    // *** but then how to calculate "equitable payouts" ? equitable to "last round", or equitable to OVERALL RNDC outstanding ?
    // from mechanism design perspective, an ERC20 token may be better
    // (disincentivizes rapid peg-in / peg-out to try to force a liquidation after some disproportionate peg-outs)

    // state management
    enum State { Funding, Active, Liquidating }
    State public state;
    bool private txLockMutex; // possibly redundant with transfer() calls
    bool public rdcCreated;  // changed to public for testing

    // declare events
    event DeployedRDC();
    event PeggedIn(address _add, uint256 _amt);
    event PeggedOut(address _add, uint256 _amt);
    event ChangedPegInBase(uint256 _amt);
    event ChangedBlockWaitTime(uint256 _time);
    event TriggeredEquitableLiquidation(address _add);
    event TriggeredEquitableDestruct();
    event StateChangeToFunding();
    event StateChangeToActive();
    event StateChangeToLiquidating();
    event MadeEquitableWithdrawal(address _add, uint _amt);
    event FullContractReset(address _add);  // maybe; kind of redundant w/ StateChangeToFunding

    // declare modifiers
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

    // modifier to check if the RDCToken contract (as owned by this contract) has been deployed
    // if necessary, can also deploy separately and then change ownership to this contract if I can't get this working
    modifier checkRDCTokenDeployed() {
        if (!rdcCreated) {
            deployRDC();
        }
        _;
    }

    // declare constructor + other functions
    constructor()
    public
    {
        owner = msg.sender;
        minimumPegInBaseAmount = 100 szabo; // ~ 5 cents
        minimumPegInMultiplier = 10;
        availablePayout = 0;  // keep at 0 since msg.value when constructed may be higher than the actual contract balance after construction
        haircut = 0;  // this is what should get incremented when accounts peg in
        averageRate = 100;  // since there are no floats yet, index to 100 (or higher ?) instead of 1
        lastAvgRate = 0;
        txCount = 0;
        expectedRate = 100;  // think about this... maybe higher for better decimal approximation ?
        halfWidth = 50;
        blockWaitTime = 5760 * 14;  // 2 weeks seems reasonable I guess 
        minTxToActivate = 10;
        minBalanceToActivate = 10 finney;
        /*
        If I do not instantiate this in the constructor, tests (as of 8/8/18) will run and pass
        solution may be to instantiate it after the fact, but I don't know how to do that exactly
        try doing it without a factory first, but maybe factory would be better if i can't figure that out

        rdc = new RDCToken();*/  // seeing if i can avoid gas constraints with smaller constructor
        state = State.Funding;
        txLockMutex = false;
        rdcCreated = false;  // this may be a better pattern actually - have a modifier that locks certain functionality when this is false
    }

    // testing this out for now
    function deployRDC()
    public
    //onlyOwner()  // turning this off for testing; can also get away without using this since the ownership of rdc will be this, and limited to 1
    returns(bool)
    {
        require(!rdcCreated, "RDCToken instance has already been created");
        rdc = new RDCToken();
        rdcTokenAddress = address(rdc);
        rdcCreated = true;
        emit DeployedRDC();
        return true;
    }

    
    function randomRate()
    //private
    public // for testing
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
        require(_a < _b, "_buf has under- or overflowed");  // redundant now with SafeMath I think ?
        //return ((((_b - _a) * (_x - _min)) / (_max - _min)) + _a);
        return ((((_b.sub(_a)).mul((_x.sub(_min)))).div((_max.sub(_min)))).add(_a));
    }

    function updateAverageRate(uint _last_rate)
    private
    returns(uint)
    {
        uint _newAR;
        if (txCount == 0) {
            _newAR = _last_rate;
        }
        else {
            // averageRage = ((lastAvgRate * txCount) + [new random rate]) / txCount + 1
            _newAR = (lastAvgRate.mul(txCount).add(_last_rate)).div(txCount.add(1));
        }
        lastAvgRate = _newAR;
        // then increment txCount
        txCount = txCount.add(1);
    }


    function pegIn()
    public
    payable
    notLiquidating()
    canAffordPegIn()
    canChangeStateToActive()
    checkRDCTokenDeployed()
    returns(uint)
    {
        // logic for checking whether holder is in index is now in IterableBalances.sol
        // just add the balance
        address _add = msg.sender;
        uint _rndrate = randomRate();
        uint _rndamt = msg.value.mul(_rndrate);  // can I use SafeMath here ? need to recast randomRate return variable as uint256?
        rdc.mint(_add, _rndamt);  // add the RANDOMCOIN balance, not eth sent amount
        // capture the haircut to deduct from availablePayout
        haircut = haircut.add(minimumPegInBaseAmount);
        // update the value of averageRate
        updateAverageRate(_rndrate);
        // emit the PeggedIn event
        emit PeggedIn(_add, _rndamt);
        // return the amount received for peg-in
        return _rndamt;
    }

    // currently:
    // _amt is the amount of RDC to peg out
    // _rndamt is the random amount of Ether received in exchange for _amt RDC
    // maybe rename this to avoid confusing myself (_eth_amt, _rdc_amt) here and elsewhere
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
        require(rdc.balanceOf(_add) >= _amt, "Insufficient balance to peg out");

        // calculate amount of eth to send (DOES THIS WORK WITHOUT FLOATS ??? MIGHT NEED TO RECONFIGURE MATH FORMULA HERE)
        uint _rndrate = randomRate();
        uint _rndamt = _amt.div(_rndrate); // maybe rename - _rndamt here is a "random amount of eth"

        // if contract would be drained by peg out, allow equitable withdrawal of whatever is left
        if (_rndamt > address(this).balance) {
            equitableDestruct();
            // do I need to call anything else here to ensure no weirdness happens after calling equitableDestruct?
        }
        // otherwise, send the toSend amount to _add (after switching the mutex)
        txLockMutex = true;
        rdc.transferFrom(_add, address(this), _amt);  // deduct the RANDOMCOIN balance, not eth payout amt
        _add.transfer(_rndamt);
        
        // update the value of averageRate
        updateAverageRate(_rndrate);
        
        // release the mutex after external call
        txLockMutex = false;
        
        // emit the PeggedOut event
        emit PeggedOut(_add, _amt);
        
        // return the amount pegged out
        return _amt;
    }

    // this is something of a potential reputational risk
    // a malicious owner could abuse this; maybe put a timer on its use
    // (or don't use it at all)
    function changePegInBase(uint256 _new_base)
    public
    //onlyOwner()  // disabling this for testing since deploying an owned instance of this runs out of gas
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
    //onlyOwner()  // disabling for testing only
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

    function equitableWithdrawal()  // maybe rename this...
    public
    payable
    stateIsLiquidating()
    returns(uint)
    {
        // check the mutex for payable function
        require(!txLockMutex, "txLockMutex must be unlocked");
        address _add = msg.sender;
        // calculate payout but without this contract claiming its share (?)
        // e.g. instead of using rdc.totalSupply() as the denominator, use (rdc.totalSupply - rdc.balanceOf(address(this)))
        // this would alleviate the implicit extra haircut to everyone as prior holders failed to cash out their equitable share during earlier liquidiations
        uint _this_bal = rdc.balanceOf(address(this));
        uint _payout = (rdc.balanceOf(_add).div(rdc.totalSupply().sub(_this_bal))).mul(availablePayout);
        // set the lock mutex before transfer
        txLockMutex = true;
        _add.transfer(_payout);
        // release the lock mutex after transfer
        txLockMutex = false;
        // may need to handle the case where the last person to withdraw cannot do so because fees have drained what would have been proportional shares initially
        
        // emit the relevant event
        emit MadeEquitableWithdrawal(_add, _payout);
        // return the amount paid out
        return _payout;
    }

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

        state = State.Liquidating;
        emit StateChangeToLiquidating();

        // how can we start a timer and then "ensure" that the contract gets reset to funding state afterwards?
        // this may not be directly possible, so can we make a modifier for ALL other functions that resets the state if eligible to do so ?
        
        // return true for testing
        return true;
    }

    // IDEA: owner can reset state, but ONLY after some window of time has passed allowing people enough time to withdraw (e.g. 2 weeks or something)
    function resetState()
    public
    onlyOwner()
    //stateIsLiquidating()  // redundant w/ blockWaitTimeHasElapsed()
    blockWaitTimeHasElapsed()
    returns(bool)
    {
        // ALL relevant variables need to be handled here - check constructor / all state vars
        // worth resetting availablePayout to 0 or something here, to keep resetting "cleaner" ? Logically unnecessary I think
        haircut = 0; // I think this should be reset here
        averageRate = expectedRate;  // maybe ? or shoud we track this over longer horizons?
        lastAvgRate = 0;
        txCount = 0;
        // if using rdc instead of rdcBalances, should just check that we have, in fact, created an instance (should always be true)
        require(rdcCreated, "No RDCToken instance has been created");
        state = State.Funding;
        txLockMutex = false;  // hopefully redundant

        // emit relevant event(s)
        emit FullContractReset(msg.sender);
        emit StateChangeToFunding();

        // return true for testing
        return true;
    }
}
