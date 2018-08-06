pragma solidity ^0.4.13;

// not sure if this meets the "EthPM" requirement for the class... hopefully good enough
// if this seems to work OK in this contract, add it to RandomCoin.sol as well
// also check if there is any SafeMath library that can be imported in a similar fashion
import "installed_contracts/zeppelin/contracts/ownership/Ownable.sol";

contract RandomLotto is Ownable {
    // should be "round-based" with a minimum number of blocks to pass, plus delay if not enough participants have entered within that limit
    // so, state machine, basically -- see: https://solidity.readthedocs.io/en/develop/common-patterns.html?#state-machine
    // additional function to withdraw your bet should be allowed if the number of blocks have passed but no one else has joined
    // (could just send back after X blocks, but should incentivize staying in)
    //address owner;  -- redundant when using Ownable.sol
    uint ticketPrice;  // price in wei
    mapping (address => uint) ticketBalances;
    mapping (address => uint) currentPayouts;  // maybe...
    address[] ticketHolders;  // not sure if necessary ?  use IterableBalances for this? or wrong structure?
    uint lastDraw;  // rename to "lastDrawAt" ?
    enum State {
        SellingTickets,
        DrawingWinner,
        PayingOut,
        Liquidating
    }
    State state;
    bool txLockMutex;
    uint totalTickets;  // to store total number of issued tickets; !!! needs to be reset when lottery resets !!!
    uint availablePayout;  // to store contract balance snapshot in case of equitable liquidation event

    // should have a declared address pointing to the RandomCoin.sol deployed contract instance
    // this needs to be settable by the owner; will be required for testing
    address rdcContractAddress;

    // idea from Medium post here: https://medium.com/@promentol/lottery-smart-contract-can-we-generate-random-numbers-in-solidity-4f586a152b27
    // use a "state" state variable for accepting tickets / drawing the value
    // this would probably be good in general

    // events - will depend on final state varialbes, which need more thought at this point
    event SoldTickets(address _add, uint _tickets);
    event DrewWinner(address _add);
    event PayoutClaimed(address _add, uint _amt);
    event WithdrawalMade(address _add, uint _amt);  // redundant w/ above??
    event TriggeredEquitableLiquidation(address _add);
    event StateChangeToSellingTickets();
    event StateChangeToDrawingWinner();
    event StateChangeToPayingOut(); 
    event StateChangeToLiquidating();
    event SetRdcContractAddress(address _add);
    event PaidToRandomCoin();  // need a function that does this, too - push at PayingOut stage?

    // modifiers: need state checking at a minimum here I think
    modifier sellingTickets() {
        require(state == State.SellingTickets, "State must be SellingTickets");
        _;
    }

    // copied from RandomCoin.sol -- maybe abstract some of these into a library if it makes sense
    modifier canWithdrawEquitably() {
        require(state == State.Liquidating, "State must be Liquidating");
        _;
    }

    modifier rdcContractAddressExists() {
        require(rdcContractAddress != address(0), "rdcContractAddress must be set");
        _;
    }

    constructor() public
    {
        owner = msg.sender;
        ticketPrice = 1000;  // I dunno, this may not matter a lot
        lastDraw = block.number;
        state = State.SellingTickets;
        txLockMutex = false;
        availablePayout = msg.value;  // I guess ? or set to 0?
    }

    function getTickets(address _add)
    public
    payable
    sellingTickets()
    returns(uint)
    {
        // credit the balance of the paying address w/ tickets based on price
        // (could eliminate price and have 1 ticket = 1 wei I guess, but maybe better to divide to avoid overflow)
        uint _tickets = (msg.value / ticketPrice);
        ticketBalances[_add] += _tickets;
        totalTickets += _tickets;
        availablePayout += msg.value;
        // emit the relevant event
        emit SoldTickets(_add, _tickets);
        // return the amount of tickets purchased
        return _tickets;
    }

    // how does this get triggered ? possible to automate?  or should this be an "only owner" thing?
    // if owner, is it possible to write a script that would externally monitor and automate the draw,
    // based on some timeframe or something like that?  Would be more convenient than manually running
    // TODO: implement some block time-based timers for state transitions (e.g. blocks elapsed must be X before ticket sales stop, etc.)
    // (above is similar to how RandomCoin contract has been changed to allow reset after elapsed time)
    function runDraw()
    private
    sellingTickets()
    onlyOwner()  // I guess ?
    returns(address)
    {
        // run the whole lotto
        // set the state appropriately
        state = State.DrawingWinner;
        emit StateChangeToDrawingWinner();
        // draw a winner
        address winner = drawJackpot();
        // determine winner payout / losers payout / holdout amount for defending RandomCoin pegs
        
        // emit the relevant event
        emit DrewWinner(winner);
        
        // pay the relevant parties (including )
        return(winner);
    }

    function drawJackpot()
    private
    returns(address)
    {
        // statistically draw a winner based on ticket holdings
        // (look up ticketBalances for each holder in ticketHolders, get a random number, pick winner)
        // return the winning address

        // this may need to use some random math + rescaling, where the rescaling parameter actually matter a lot
        // e.g. need to make sure the range is proportional to the number of people who hold tickets
        // this actually seems very hard...
    }

    // ideally would return a mapping, but may need to just set one
    // now that i think about this, probably requires both array and mapping since mapping keys can't be iterated over
    function calcPayouts()
    private
    returns(bool)
    {
        // should set a mapping called currentPayouts or something


        // return true for testing
        return true;
    }

    /* DEPRECATED - USE PULL PAYMENTS INSTEAD AS IN RandomCoin.sol
    function sendPayouts()
    public
    payable
    {
        // calls calcPayouts and then sends the appropriate balances to the addresses in the mapping
        // honestly this probably isn't going to work -- just have a state enum that has a "Payout" state
        // and during Payout period people can withdraw their winnings
        // this has the extra benefit of potentially capturing more ether if it is coded in such a way as to take any ether for the peg defense pot which is not claimed within a certain window of time
        
    }*/

    // use this instead of sendPayouts
    function claimPayout()
    public
    payable
    returns(uint)
    {
        address _add = msg.sender;
        uint _tktbal = ticketBalances[_add];

        // do any other logic checks needed here / transformations to the amount to send
        uint _toSend = _tktbal;  // CHANGE THIS

        _add.transfer(_toSend);

        // emit the relevant event
        emit PayoutClaimed(_add, _toSend);

        // return the amount sent
        return _toSend;
    }

    // IS THIS REDUNDANT WITH claimPayout() ??
    // also copied more or less from RandomCoin.sol -- is there a way to abstract these?
    function equitableWithdrawal()  // maybe rename this...
    public
    payable
    canWithdrawEquitably()
    returns(uint)
    {
        // check the mutex for payable function
        require(!txLockMutex);
        address _add = msg.sender;

        // update this to reference the mapping instead of the IterableBalances contract instance
        // (... or change to use an IterableBalances instance instead of a mapping for tickets)
        //uint _payout = (rdcBalances.balances(_add) / rdcBalances.totalBalance()) * availablePayout;
        uint _payout = (ticketBalances[_add] / totalTickets) * availablePayout;
    
        // set the lock mutex before transfer
        txLockMutex = true;
        _add.transfer(_payout);
        // release the lock mutex after transfer
        txLockMutex = false;
        // may need to handle the case where the last person to withdraw cannot do so because fees have drained what would have been proportional shares initially

        // emit the relevant event
        emit WithdrawalMade(_add, _payout);
        // return the amount withdrawn
        return _payout;
    }

    // have some type of closeout by owner that returns balances
    function equitableLiquidation()
    public
    onlyOwner()
    returns(bool)
    {
        // set state
        state = State.Liquidating;

        // does this need to do anything else, like set a mapping of payouts ?
        // check code for RandomCoin.sol

        // emit relevant event
        emit TriggeredEquitableLiquidation(msg.sender);
        // return true for testing
        return true;
    }

    function setRdcContractAddress(address _add)
    public
    onlyOwner()
    returns(address)
    {
        rdcContractAddress = _add;
        emit SetRdcContractAddress(_add);
        return _add;
    }
}
