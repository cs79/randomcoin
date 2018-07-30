This document should explain what patterns I used and why I chose them

Used so far:

* pull over push payments (w/ one exception from contract to contract; limited scope)
* mutex (if I keep it) -- avoid reentrancy
* ownership (for forcing contract "fair payout" states)

MUST ALSO USE:
* circuit breaker (I believe this is a requirement for the course)

Should also use:
* auto deprecation (makes sense for some state management in both RandomCoin.sol and RandomLotto.sol)
* Mortal (maybe... if anything, this would be IN ADDITION to existing equitableDestruct functions) - this would also kind of work against the idea of "securing against malicious owners / creators"

Stretch:
* relay / some form of upgradeability
