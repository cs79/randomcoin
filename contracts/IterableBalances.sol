pragma solidity ^0.4.0;

// should this be a library instead of a contract ?  Maybe...
// ORRRR instead of a struct inside a contract, maybe the contract itself is the thing we want to be the iterable item
// and we use the factory pattern to instantiate these when we need to create an iterable balance thing
// I think this may make more sense
contract IterableBalances {
    uint maxIndex;
    address[] holders;
    mapping (address => uint) index;  // simply used to avoid costly search through holders when checking for existence of a holder's address
    mapping (address => uint) balances;

    // events go here
    event AddedUser(address _add, uint _idx);
    event RemovedUser(address _add, uint _idx);
    event AddedBalance(address _add, uint _amt);
    event DeductedBalance(address _add, uint _amt);

    constructor() public {
        maxIndex = 0;
    }

    function isUserInIndex(address _add)
    public
    view
    returns(bool inIndex)
    {
        if (index[_add] == 0) {
            return(false);
        }
        return(true);
    }

    function addUserToIndex(address _add)
    private
    returns(uint _idx)
    {
        assert(!isUserInIndex(_add));
        index[_add] = maxIndex;
        holders[maxIndex] = _add;
        maxIndex += 1;
        emit AddedUser(_add, index[_add]);
        return(index[_add]);
    }

    function removeUserFromIndex(address _add)
    private
    {
        uint _idx = index[_add];
        assert(isUserInIndex(_add));
        assert(balances[_add] == 0);  // maybe
        delete holders[index[_add]];
        index[_add] = 0;
        emit RemovedUser(_add, _idx);
    }

    function addBalance(address _add, uint _amt) 
    public
    payable
    returns(uint _bal)
    {
        if (!isUserInIndex(_add)) {
            addUserToIndex(_add);
        }
        balances[_add] += _amt;
        emit AddedBalance(_add, _amt);
        return(balances[_add]);
    }

    function deductBalance(address _add, uint _amt)
    public
    payable
    returns(uint _bal)
    {
        if (!isUserInIndex(_add)) {
            revert();
        }
        assert(balances[_add] >= _amt);
        balances[_add] -= _amt;
        emit DeductedBalance(_add, _amt);
        return(balances[_add]);
    }
}