# randomcoin
### _A non-correlated cryptocurrency portfolio hedge_

## What is randomcoin?
randomcoin (RDC) is a token built on top of the Ethereum blockchain that offers cryptocurrency investors a non-correlated hedge to their token portfolios.  RDC is pegged to ether (ETH) at a random (bounded) rate, with programmatic and incentive-based mechanisms in place to defend the peg.

## How does it work?
Upon initial contract creation, the RDC contract will be in a "funding" state where investors can peg in to the contract.  Once a sufficient number of peg-in transactions have occured (or a minimum funding level of ETH is met), the contract moves to an "active" state and peg-out transactions can be made as well.

The rate at which any individual peg-in or peg-out transaction will be processed is a random number, bounded to be between 50 and 150 with an expected value of 100.  For investors, this means that *in expectation*, the value of RDC is always 100 per 1 ETH; the *realized* value will rarely be exactly this, though.  The value-in-expectation should make RDC stably tradable for ETH or other crypto-tokens that can be priced in ETH, while its value-in-realization if pegged out of the contract gives it additional value as an uncorrelated portfolio hedge (as pegged-out returns cannot be systematically correlated with any other crypto-token holdings since those returns are random).

### A note on correlation

The term "uncorrelated" here is used w.r.t. a portfolio based in ETH; if an investor is basing their portfolio in a fiat currency such as USD, RDC will be correlated with the ETH/USD exchange rate, though not in exactly the same manner in realization.  (Realized rates for RDC/USD via the RDC/ETH and ETH/USD pairs will not necessarily be at the expected 100/1 RDC/ETH rate.)

## How can I set this up to try it out?

(truffle, development server, etc.)