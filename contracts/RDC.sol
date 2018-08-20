pragma solidity ^0.4.23;

// Import zeppelin libraries from EthPM / OpenZeppelin
import "../installed_contracts/zeppelin/contracts/token/MintableToken.sol";
import "../installed_contracts/zeppelin/contracts/token/BurnableToken.sol";

/** @title randomcoin token (RDC) */
contract RDC is MintableToken, BurnableToken {

    using SafeMath for uint256;

    // STATE VARIABLES
    //----------------

    uint256 public availablePayout;  // made public for testing
    uint256 public haircut;  // made public for testing
    uint256 public averageRate;
    uint256 private lastAvgRate;
    uint256 private txCount;  // use this + last rate to adjust averageRage
    uint256 private txCountSinceLastReset;
    uint256 public expectedRate;
    uint256 public halfWidth;  // made public for testing; I guess this is fine to leave as such
    uint256 public liquidationBlockNumber;
    uint256 public blockWaitTime;
    uint256 public minimumPegInBaseAmount; // liquidation haircut
    uint256 public minimumPegInMultiplier;
    uint256 public minTxToActivate;
    uint256 public minBalanceToActivate;

    // for tracking recent transactions in a frontend UI / during testing
    uint256[16] public latestRates;
    uint8 public maxRateIndex;  // set to public for testing
    uint8 private currentRateIndex;
    bool public rateArrayFull;  // set to public for testing

    // state management
    enum State { Funding, Active, Liquidating }
    State public state;
    bool public txLockMutex; // possibly redundant with transfer() calls; made public for testing


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

    modifier txMutexGuarded() {
        require(!txLockMutex, "txLockMutex must be unlocked");
        _;
    }

    // mechanism to allow update from funding to active
    modifier canChangeStateToActive() {
        _;
        if (state == State.Funding) {
            if (txCountSinceLastReset >= minTxToActivate || address(this).balance >= minBalanceToActivate) {
                state = State.Active;
                emit StateChangeToActive();
            }
        }
    }

    // mechanism to allow update from liquidating to funding
    modifier canChangeStateToFunding() {
        if (state == State.Liquidating && block.number.sub(liquidationBlockNumber) >= blockWaitTime) {
            availablePayout = 0;
            haircut = 0;
            txCountSinceLastReset = 0;
            state = State.Funding;
            txLockMutex = false;
            mintingFinished = false;
            emit FullContractReset(msg.sender);
            emit StateChangeToFunding();
        }
        _;
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

    /** @dev Generate a random exchange rate for RDC <--> ETH
        @return _rescaled; the random rate rescaled to fall within a particular range
     */
    function randomRate()
    public //private - made public for testing only
    view
    returns(uint256)
    {
        /*  
        THIS IS AN INSECURE PLACEHOLDER
        For a Production implementation, this should be replaced with something like RANDAO:
        https://github.com/randao/randao

        This implementation was based on an example from the following link:
        https://medium.com/@promentol/lottery-smart-contract-can-we-generate-random-numbers-in-solidity-4f586a152b27
        (modified to accommodate Truffle's testing setup - no subsecond block times are provided, hence the use of block.number)
         */
        uint8 _rand = uint8(uint256(keccak256(abi.encodePacked(block.number, block.difficulty))) % 251);
        // rescale to mean of expectedRate -- 0 and 250 hardcoded here based on how _rand is calculated
        uint256 _rescaled = rescaleRate(0, 250, expectedRate, halfWidth, _rand);
        return _rescaled;
    }

    /** @dev Rescale a randomly-generated exchange rate to a new value range (expectedRate +/- halfWidth)
        @param _min Minimum value of the original range
        @param _max Maximum value of the original range
        @param _ev  Expected value (mean) of the new range
        @param _buf Buffer to add and subtract from _ev to generate the new range
        @param _x   The value to rescale to the new range
        @return _rescaled_x The rescaled value of _x
     */
    function rescaleRate(uint _min, uint _max, uint _ev, uint _buf, uint _x)
    private
    view
    returns(uint256)
    {
        uint256 _rescaled_x;
        uint _a = _ev.sub(_buf);
        uint _b = _ev.add(_buf);
        /*
        Rescale _min, _max to _ev +/- _buf and calculate _x using the following formula:
        _x = ((((_b - _a) * (_x - _min)) / (_max - _min)) + _a)
        
        Source for this formula can be found at the following link:
        https://stackoverflow.com/questions/5294955/how-to-scale-down-a-range-of-numbers-with-a-known-min-and-max-value
         */
        _rescaled_x = ((((_b.sub(_a)).mul((_x.sub(_min)))).div((_max.sub(_min)))).add(_a));
        return _rescaled_x;
    }

    /**@dev Keep track of the running average of random rates generated for transactions
       @param _last_rate The last-generated random rate
       @return _newAR The new value of averageRate
     */
    function updateAverageRate(uint256 _last_rate)
    private
    returns(uint256)
    {
        lastAvgRate = averageRate;
        uint256 _newAR;
        if (txCount == 0) {
            _newAR = _last_rate;
        }
        else {
            /*
            Formula to update the average rate, based on txCount and lastAvgRate:
            averageRate = ((lastAvgRate * txCount) + _last_rate) / (txCount + 1)
             */
            _newAR = (lastAvgRate.mul(txCount).add(_last_rate)).div(txCount.add(1));
        }
        averageRate = _newAR;
        txCount = txCount.add(1);  // keep track of txCount for next call to this function
        txCountSinceLastReset = txCountSinceLastReset.add(1);
        return _newAR;
    }

    /** @dev Update the storage array latestRates on pegIn() or pegOut()
        @param _rate The rate to add to latestRates
        @return _indexed_rate The rate which was newly stored in latestRates
     */
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
        uint256 _indexed_rate = latestRates[_index_used];
        return _indexed_rate;
    }

    /** @dev Peg in from ETH to RDC
        @dev This function, along with pegOut(), is the backbone of the contract
        @dev This function can change State from Funding to Active (if sufficient value or # of transactions are pegged in)
        @dev This function can also change State from Liquidating to Funding (if sufficient time has passed since liquidation)
        @dev The msg.value sent to this function is an implicit parameter: the amount of ETH to exchange for RDC at a random rate
        @return _rdc_amt The amount of RDC received in exchange for the ETH sent in msg.value
     */
    function pegIn()
    public
    payable
    canAffordPegIn()
    canChangeStateToFunding()
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
        emit PeggedIn(_add, _rdc_amt);
        // return the amount received for peg-in
        return _rdc_amt;
    }

    /** @dev Peg out from RDC to ETH
        @dev This function, along with pegIn(), is the backbone of the contract
        @param _amt The amount of RDC to exchange back into ETH at a random rate
        @return _amt The amount of RDC exchanged [IS THIS WHAT IT SHOULD RETURN ???]
    */
    function pegOut(uint256 _amt)
    public
    payable
    stateIsActive()
    txMutexGuarded()
    returns(uint256)
    {
        // check that account has sufficient balance
        address _add = msg.sender;
        require(balanceOf(_add) >= _amt, "Insufficient balance to peg out");
        // calculate amount of eth to send
        uint _rndrate = randomRate();
        uint _eth_amt = _amt.div(_rndrate);
        // if contract would be drained by peg out, allow equitable withdrawal of whatever is left
        if (_eth_amt >= address(this).balance - haircut) {  // capture the haircut here so fees can be paid during cash out
            equitableDestruct();
        }
        // otherwise, send _eth_amt to _add (after switching the mutex)
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

    /** @dev Automatic "fair self-destruct" if the peg breaks
        @dev This is an automatic internal circuit breaker in case the funds available to support the main contract functionality runs out
        @return _success Boolean flag to signal successful start of liquidation
     */
    function equitableDestruct()
    private
    notLiquidating()
    returns(bool _success)
    {
        // This is the first of two pass-throughs to startLiquidation
        startLiquidation();
        emit TriggeredEquitableDestruct();
        return true;
    }

    /** @dev Owner-forced "fair self-destruct"
        @dev This is a manual circuit breaker which only the contract Owner can activate
        @return _success Boolean flag to signal successful start of liquidation
     */
    function equitableLiquidation()
    public
    notLiquidating()
    onlyOwner()
    returns(bool _success)
    {
        // This is the second of two pass-throughs to startLiquidation
        startLiquidation();
        emit TriggeredEquitableLiquidation(msg.sender);
        return true;
    }

    /** @dev Shared method to flip the State-based circuit breaker if pegOut() breaks the peg / owner stops the contract
        @dev Starts a block timer from the current block of [blockWaitTime] blocks
        @dev Additionally calculates the availablePayout for liquidation, and pauses minting of new RDC
        @return _success Boolean flag to signal successful start of liquidation
     */
    function startLiquidation()
    private
    notLiquidating()
    returns(bool _success)
    {
        // set liquidation block height to start "countdown" before owner can reset state
        liquidationBlockNumber = block.number;

        // set availablePayout (minus the haircut accumulated so far via pegIn transactions)
        availablePayout = address(this).balance.sub(haircut);

        // pause minting during liquidation s.t. totalSupply is stable for calculating fair payouts
        mintingFinished = true;

        state = State.Liquidating;
        emit StateChangeToLiquidating();
        return true;
    }

    /** @dev Claim an address' "fair payout" during a liquidation event (proportional to the sending account's RDC holdings)
        @return _payout The amount of ETH cashed out during liquidation
     */
    function equitableCashout()
    public
    payable
    stateIsLiquidating()
    txMutexGuarded()
    returns(uint)
    {
        /*
        From a mechanism design standpoint, this functions nicely:
        
        There is a potential "last-mover advantage" to cashing out during a liquidation
        (if one is the "last RDC holder" and everyone else has cashed out, 
        they could hold their RDC until reset and try to quickly force another liquidation event, 
        which could make their RDC worth proportionately more ETH during the cash out)
        
        Because of this last-mover advantage, there is a natural incentive to keep holding RDC even during a liquidation
        This helps the sustainability of the contract and hence the utility of the RDC token
        */
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

    /** @dev fallback function */
    function () external payable {}

}
