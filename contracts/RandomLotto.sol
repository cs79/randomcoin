pragma solidity ^0.4.0;

contract RandomLotto {
    // should be "round-based" with a minimum number of blocks to pass, plus delay if not enough participants have entered within that limit
    // so, state machine, basically -- see: https://solidity.readthedocs.io/en/develop/common-patterns.html?#state-machine
    // additional function to withdraw your bet should be allowed if the number of blocks have passed but no one else has joined
    // (could just send back after X blocks, but should incentivize staying in)
    address owner;
    uint ticketPrice;  // price in wei
    mapping (address => uint) ticketBalances;
    address[] ticketHolders;  // not sure if necessary ?
    uint lastDraw;
    enum States {
        SellingTickets,
        DrawingWinner,
        PayingOut
    }
    // idea from Medium post here: https://medium.com/@promentol/lottery-smart-contract-can-we-generate-random-numbers-in-solidity-4f586a152b27
    // use a "state" state variable for accepting tickets / drawing the value
    // this would probably be good in general

    // events - will depend on final state varialbes, which need more thought at this point
    event TriggeredEquitableLiquidation(address _add);

    constructor() public
    {
        owner = msg.sender;
        ticketPrice = 1000;  // I dunno, this may not matter a lot
        lastDraw = block.number;
    }

    function getTickets(address _add) public payable
    {
        // is _amt needed in this context ? or can i just use msg.value ?
        ticketBalances[_add] = ticketBalances[_add] + (msg.value / ticketPrice);
    }

    function runDraw() private
    {
        // run the whole lotto
        // draw a winner
        winner = drawJackpot();
        // determine winner payout / losers payout / holdout amount for defending RandomCoin pegs
        // pay the relevant parties
    }

    function drawJackpot() private returns(address)
    {
        // statistically draw a winner based on ticket holdings
        // (look up ticketBalances for each holder in ticketHolders, get a random number, pick winner)
        // return the winning address
    }

    // ideally would return a mapping, but may need to just set one
    // now that i think about this, probably requires both array and mapping since mapping keys can't be iterated over
    function calcPayouts()
    {

    }

    function sendPayouts()
    {
        // calls calcPayouts and then sends the appropriate balances to the addresses in the mapping
    }

    // have some type of closeout by owner that returns balances
    function equitableLiquidation()
    {
        if (msg.sender == owner) {
            // equitable return

            // emit relevant event
            emit TriggeredEquitableLiquidation(msg.sender);
        }
    }
}
