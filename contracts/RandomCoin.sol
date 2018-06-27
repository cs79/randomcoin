pragma solidity ^0.4.0;

contract RandomCoin {
    // declare state / storage variables
    // the lotto contract should have an owner, but maybe this doesn't need one ?
    // maybe another contract type is needed for RDC accounts, individually owned ? or can a mapping handle this fine here?
    address owner;  // for recovery, but make sure it can't do anything weird to pegged in balances
    // averageRate should have an expected value of 100  (1, ideally, but no floats)
    // an "ideal" version of this would allow for timeseries graphing of average rate in the web service -- not sure how this might be achieved though
    uint averageRate;  // update this as events are emitted ? or rely on web service to aggregate records later?
    // need to keep track of everyone who has pegged in
    // does "randomcoin" need to be an actual "token"? should it be? I guess that is more interesting tbh... learn about how to do this
    // (alternative is simply using a mapping as the sole arbiter of balances; all "trading" done with the contract only via peg-in / peg-out)
    mapping (address => uint) rdcBalances;
    // not sure if this one is needed: holders array lists all accounts who have pegged in and not closed out
    address[] holders;

    // declare events
    // do any of these need to be indexed ? any other thing we want to log ?
    event PeggedIn(address _add, int256 _amt);
    event PeggedOut(address _add, int256 _amt);

    // declare modifiers

    // declare constructor + other functions
    constructor() public
    {
        owner = msg.sender;
        averageRate = 100;  // since there are no floats yet, index to 100 instead of 1
    }

    function randomRate() private pure returns(uint)
    {
        // the most important piece -- will be called to generate the rate when pegIn() or pegOut() is called
        // needs to have an EV of 100
        // no idea what math / random libraries are already available in solidity... hopefully something I can work with for this 
    }

    function pegIn(address _add, uint _amt) public payable
    {
        // update the holders mapping at rate determined by randomRate(), in conjunction w/ balance sent by sender
        bool isHolderInMapping = false;
        if (rdcBalances[_add] != 0) {
            isHolderInMapping = true;
        }
        rdcBalances[_add] = randomRate() * _amt;
        // append the address to holders if it doesn't already exist in the array (check if lookup in rdcBalances is default value before adding to mapping)
        if (!isHolderInMapping) {  // not sure on ! syntax here...
            holders.push(_add)
        }
        // emit the PeggedIn event
    }

    function pegOut(address _add, uint _amt) public payable
    {
        // need to validate that _amt does not exceed rdcBalances[_addr]
        if (rdcBalances[_add] < _amt) {
            revert()
        }
        // if it does not, send the random rate in reverse (may need to use floor division for now)
        uint toSend = _amt / randomRate();
        // need to think about what happens if this toSend amount would drain the balance of the contract
        // MAYBE -- equitableDestruct() to return something to everyone
        if (toSend > this.balance) {
            equitableDestruct()
        }
        // otherwise, send the toSend amount to _add
        rdcBalances[_add] = rdcBalances[_add] - _amt;
        _add.send(toSend);
        // emit the PeggedOut event
    }

    function equitableDestruct() private payable
    {
        // split up the ether in this contract's balance proportionally to RDC ownership among all addresses in holders
        // basically a version of equitableLiquidation() that can be called during pegOut if the pot would be drained, rather than on command

    }

    function equitableLiquidation() public payable
    {
        if msg.sender == owner:
            // split up the ether in this contract's balance by proportional RDC balance of all keys
            // maybe this will not work, or addl data structure is required, since mappings cannot be iterated over (?)
            // could store a (potentially expensive) array of holders to identify the "valid" keys in the rdcBalances mapping

    }
}
