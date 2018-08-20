# Design Pattern Decisions

This document explains what contract design patterns are used in randomcoin, and why:

## Automatic Circuit Breaker

The combination of the `Liquidating` state and the functions which can trigger it (`equitableLiquidation`, `equitableDestruct`) act as a circuit breaker for the operation of the contract if its core functionality can no longer be fulfilled (i.e. if the exchange rate peg between RDC and ETH breaks).

Currently `equitableLiquidation` can be manually triggered by the owner, while `equitableDestruct` automatically trips the same underlying function (`startLiquidation`) if the ETH balance of the randomcoin contract would be overdrawn.

The `equitableLiquidation` function could be removed in a Production implementation, as the automatic circuit breaker should be sufficient to manage the lifecycle of the contract and removing the manual circuit breaker could preclude a malicious Owner from using it to attempt an attack on the contract.

## State Machine / Autodeprecation

The life cycle of the contract is managed as a state machine, with three states (`Funding`, `Active`, `Liquidating`) that can be cycled through.  There is functionality built into the contract to manage automatic state transitions when core functions are called under certain circumstances:

* When the contract is instantiated, the `constructor` sets the state to `Funding`
* A successful call to the `pegIn` function can shift the state from `Funding` to `Active` if a threshold (for funding or transaction count) is exceeded by that call
* A call to `pegOut` which would drain the contract of its balance (thus breaking the peg) will trip the automatic circuit breaker (`equitableDestruct`), which will change the state from `Active` to `Liquidating` (`pegOut` can only be called in the `Active` state)
* A call to `pegIn` when the contract is in the `Liquidating` state can reset the state to `Funding`, **if** the `blockWaitTime` has elapsed (giving RDC holders time to cash out their RDC for an equitable share of the ETH held by the contract if they wish to do so)

The lattermost bullet also illustrates the use of an "autodeprecation" style pattern: the requirement that the contract remain in the `Liquidating` state will automatically deprecate after `blockWaitTime` has elapsed following the event which initially triggered the liquidation.

## Ownership

The contract uses the ownership pattern for a limited selection of functions.  In addition to standard modifiers and functionality provided by the `Ownable.sol` contract in the OpenZeppelin library, the randomcoin contract currently defines one Owner function (`equitableLiquidation`).  This is a manual version of the circuit breaker encoded in `equitableDestruct`. Earlier versions of the contract included more Owner functions but these were modified and/or removed to eliminate attack vectors that could be exploited by a malicous Owner.

## Pull over Push Payments

The contract can make ETH payments to RDC holders via the `pegOut` and `equitableCashout` functions.  These payments, even in the case where the contract is liquidating, must be requested by the RDC holder.  This avoids the need to potentially iterate over a set of holders to make payments, which could cause the contract to run out of gas while iterating over an array without a prespecified bound.

## Mutex (Reentrancy Guard)

For those functions which make payments upon request (`pegOut`, `equitableCashout`), a mutex is used as a reentrancy guard -- the mutex is checked at the beginning of both functions (via the modifier `txMutexGuarded`), and is set prior to the send of ETH and then released after the send.  This may be redundant as far as preventing reentrancy is concerned as both functions use `transfer` rather than `send` to make payments, but has been retained for extra safety.

## Equitable Liquidation



## Ideas for Future Implementation

* Mortal (maybe... if anything, this would be IN ADDITION to existing equitableDestruct functions) - this would also kind of work against the idea of "securing against malicious owners / creators"

Stretch:
* relay / some form of upgradeability

Other design notes:
* Explain why I used equitable destruction (incentivize people to peg in since they will always get something "fair" out)
* explain why I designed the payout calculation the way I did (intra-round fairness, if I designed it right - compare to dilution in startup cap tables as they raise new funding rounds)
* explain why lotto ("easy" way to collect some extra funding to defend the peg)
* explain why haircut (start gathering capital for defense of peg; haircut rate is adjustable)
* anything else that I need to be able to justify to myself / others
