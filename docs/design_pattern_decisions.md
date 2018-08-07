This document should explain what patterns I used and why I chose them

Used so far:

* pull over push payments (w/ one exception from contract to contract; limited scope)
* mutex (if I keep it) -- avoid reentrancy
* ownership (for forcing contract "fair payout" states)
* factory (for IterableBalances contract of my own design) - want to be able to share these over more than one contract, and within a specific contract may want to "reset" them / grab a new clean-slate one [N.B. even if I use RDCToken MintableToken instead, still using a factory]

MUST ALSO USE:
* circuit breaker (I believe this is a requirement for the course)

Should also use:
* auto deprecation (makes sense for some state management in both RandomCoin.sol and RandomLotto.sol)
* Mortal (maybe... if anything, this would be IN ADDITION to existing equitableDestruct functions) - this would also kind of work against the idea of "securing against malicious owners / creators"

Stretch:
* relay / some form of upgradeability

Other design notes:
* Explain why I used equitable destruction (incentivize people to peg in since they will always get something "fair" out)
* explain why I designed the payout calculation the way I did (intra-round fairness, if I designed it right - compare to dilution in startup cap tables as they raise new funding rounds)
* explain why lotto ("easy" way to collect some extra funding to defend the peg)
* explain why haircut (start gathering capital for defense of peg; haircut rate is adjustable)
* anything else that I need to be able to justify to myself / others
