# Design Pattern Decisions

This document explains what contract design patterns are used in randomcoin, and why:

## Automatic Circuit Breaker

The combination of the `Liquidating` state and the functions which can trigger it (`equitableLiquidation`, `equitableDestruct`) act as a circuit breaker for the operation of the contract if its core functionality can no longer be fulfilled (i.e. if the exchange rate peg between RDC and ETH breaks).

Currently `equitableLiquidation` can be manually triggered by the owner, while `equitableDestruct` automatically trips the same underlying function (`startLiquidation`) if the ETH balance of the randomcoin contract would be overdrawn.

The `equitableLiquidation` function could be removed in a Production implementation, as the automatic circuit breaker should be sufficient to manage the lifecycle of the contract and removing the manual circuit breaker could preclude a malicious Owner from using it to attempt an attack on the contract.

## State Machine / Autodeprecation / Speed Bump

The life cycle of the contract is managed as a state machine, with three states (`Funding`, `Active`, `Liquidating`) that can be cycled through.  There is functionality built into the contract to manage automatic state transitions when core functions are called under certain circumstances:

* When the contract is instantiated, the `constructor` sets the state to `Funding`
* A successful call to the `pegIn` function can shift the state from `Funding` to `Active` if a threshold (for funding or transaction count) is exceeded by that call
* A call to `pegOut` which would drain the contract of its balance (thus breaking the peg) will trip the automatic circuit breaker (`equitableDestruct`), which will change the state from `Active` to `Liquidating` (`pegOut` can only be called in the `Active` state)
* A call to `pegIn` when the contract is in the `Liquidating` state can reset the state to `Funding`, **if** the `blockWaitTime` has elapsed (giving RDC holders time to cash out their RDC for an equitable share of the ETH held by the contract if they wish to do so)

The lattermost bullet also illustrates the use of an "autodeprecation" or "speed bump" style pattern: the requirement that the contract remain in the `Liquidating` state will automatically deprecate after `blockWaitTime` has elapsed (i.e. the speed bump) following the event which initially triggered the liquidation.

## Ownership

The contract uses the ownership pattern for a limited selection of functions.  In addition to standard modifiers and functionality provided by the `Ownable.sol` contract in the OpenZeppelin library, the randomcoin contract currently defines one Owner function (`equitableLiquidation`).  This is a manual version of the circuit breaker encoded in `equitableDestruct`. Earlier versions of the contract included more Owner functions but these were modified and/or removed to eliminate attack vectors that could be exploited by a malicous Owner.

## Pull over Push Payments

The contract can make ETH payments to RDC holders via the `pegOut` and `equitableCashout` functions.  These payments, even in the case where the contract is liquidating, must be requested by the RDC holder.  This avoids the need to potentially iterate over a set of holders to make payments, which could cause the contract to run out of gas while iterating over an array without a prespecified bound.

## Mutex (Reentrancy Guard)

For those functions which make payments upon request (`pegOut`, `equitableCashout`), a mutex is used as a reentrancy guard -- the mutex is checked at the beginning of both functions (via the modifier `txMutexGuarded`), and is set prior to the send of ETH and then released after the send.  This may be redundant as far as preventing reentrancy is concerned as both functions use `transfer` rather than `send` to make payments, but has been retained for extra safety.

## Equitable Liquidation / Haircut

This pattern was designed for the randomcoin contract in particular, but could be used for any token built on top of Ethereum.  The mechanism is meant to serve as an incentive for investors in the token, which is particularly important for randomcoin as its functionality rests on an exchange rate peg -- investors can have an assurance that if an equitable liquidation is triggered, they can claim a share of ETH from the contract proportional to their share of RDC holdings via the `equitableCashout` function.  While they may experience some dilution (or gain) in this fashion vs. the actual rates they pegged in at, they can in any case be assured that they will not receive *nothing* in exchange for their investment.

`pegIn` transactions are also haircut (for a small fixed amount) to cover fees on `transfer` calls made during equitable liquidations.  Because RDC are transferable between accounts, the haircut cannot absolutely guarantee that the randomcoin contract will have enough ETH to pay all `equitableCashout` fees, but potential fee drain is ameliorated through a floor on RDC required to cash out to prevent abuse by an attacker splitting up RDC across multiple addresses to try to drain the contract's ability to pay transfer fees.

## Ideas for Future Implementation

Future additions would likely focus on patterns that facilitate some form of upgradability:

* Data segregation / contract relay: Separate the storage of token balances from other contract functionality, so that the latter can be upgraded via the relay pattern without disrupting RDC balances
* Rate limiter: some state variables could potentially be changed by an Owner to "upgrade" the contract, but these should be both rate-limited and probably limited in absolute terms.  For example, earlier versions of the contract allowed the owner to manipulate the `minimumPegInBaseAmount` and `blockWaitTime` state variables, but these were removed to avoid potential abuse by a malicious owner.  It is possible that with proper absolute bounds and rate limitations on how quickly the owner could change those parameters that keeping such functionality in the contract could be worthwhile.
