Explain what measures I took to make sure that contracts are not susceptible to common attacks
See Module 9 Lesson 3 for attacks that contracts should be resistant to
(link to "safety checklist": https://www.kingoftheether.com/contract-safety-checklist.html)

## Logic Bugs

## Failed Sends

* Use pull over push for payments except in one instance (should think of a fallback for that one)

## Recursive Calls

* Perform state updates before send within function body
* Use mutex to lock function during transaction portion of the call

## Integer Arithmetic Overflow

* Use SafeMath library for mathematical calculations

## Poison Data

## Exposed Functions

* Declare functions private unless there is explicit reason to make them externally callable

## Exposed Secrets

* Contracts do not rely on secret information
* Given random exchange rate mechanism, public visibility of balances has limited game-theoretic impact (mostly impacts probabilities that someone could drain the contract / trigger equitable liquidation, but the latter gives assurance to holders that they will get something "fair" back if the exchange rate mechanism fails)

*** NOTE TO SELF: think about how someone could try to game the system by viewing balances, if they were a relative "whale" -- are there attack vectors whereby they attempt to drain as much ETH from the contract as possible while not triggering equitableLiquidation via a bunch of smaller transactions after a bulk peg-in ?

## Denial of Service / Dust Spam

## Miner Vulnerabilities

## Malicious Creator

* Currently, the "worst" that the Owner can do is force an equitable liquidation, which does not enable them to "steal" any more ETH than something proportional to what they put in

*** NOTE TO SELF: THINK ABOUT HOW FORCE SENDING ETH COULD POTENTIALLY SKEW INCENTIVES TO FORCE THE LIQUIDATION

## Off-chain Safety

* Unlikely to be implemented in a development environment; could use HTTPS certifications on actual servers running the web application in the real world
* (see link for other ideas of good web security practices if this were an actually-deployed application)

## Cross-chain Replay Attacks

* TODO: Create this contract from a hard-fork-only address (how ?)

## Tx.Origin Problem

* Contracts do not use tx.origin

## Solidity Function Signatures and Fallback Data Collisions

## Incorrect Use of Cryptography

* Contracts do not use cryptography

## Gas Limits

## Stack Call Depth Exhaustion

* Newer version of Solidity used which is not susceptible to this attack