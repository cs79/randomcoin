# Avoiding Common Attacks

This document describes what measures were taken in the design of randomcoin to mitigate against common attacks.  The "safety checklist" at the following link was used as a basis for outlining attack vectors and mitigants:

https://www.kingoftheether.com/contract-safety-checklist.html

## Logic Bugs

Mitigations for potential logic bugs include:
* Unit testing on individual functions
* Unit testing on interaction between functions where relevant
* Unit testing of situations in which a particular chain of function calls / repeated function calls affects state
* Encapsulation of abstracted functionality in separate functions that can be separately tested (where this makes sense to do)

## Failed Sends

Mitigations for failed sends include:
* Use of pull over push for payments
* Use of transfer() rather than send() as transfer will fail in a more easily detectable fashion
* Holdout of "haircut" against peg-in transfers (very small amount) to cover fees for transfer() calls when they need to be made

## Recursive Calls

Mitgations for recursive calls include:
* Performing state updates before sends within function body where relevant
* Use of mutex to lock functions during transaction portion of the call
* Use of transfer() rather than send(), which should not have enough gas to allow recursive calls

## Integer Arithmetic Overflow

Mitigations for integer arithmetic overflow include:
* Use of SafeMath library for mathematical calculations

## Poison Data

There is little room for "poison data" in the design of the RDC contract.  The only non-Owner function that allows user input accepts a uint256 value which is checked against the RDC token balance of the sender.  The two Owner functions which allow user input have guards inside the functions to prevent the values from being changed outside of a +/- 10% band.  (Also N.B. that in a Production implementation these two Owner functions may be stripped out entirely.)

## Exposed Functions

Mitigations for problems arising from exposed functions include:
* Use of audited OpenZeppelin libraries for some base functionality (ownership, mintable / burnable tokens)
* Declaration of functions as private unless there is explicit reason to make them externally callable (N.B. some elements of the RDC contract were changed to public visibility solely for testing purposes; in a Production implementation these should be reset to private)

## Exposed Secrets

Mitigations for exposed secrets include:
* Contracts do not rely on secret information
* Given the random exchange rate mechanism, public visibility of balances has limited game-theoretic impact (mostly impacts probabilities that someone could drain the contract / trigger equitable liquidation, but the latter gives assurance to holders that they will get something "fair" back if the exchange rate mechanism fails)
    * N.B. that during a liquidation event, there is also a last-mover advantage which should incentivize the largest holders to keep funds in RDC (the last-mover advantage comes from an inherent advantage to holding RDC in a newly-reset funding state where it is easier to attempt to force another liquidation event which could potentially result in a more favorable ETH/RDC rate)

## Denial of Service / Dust Spam

Mitigations for dust spam include:
* Requiring a minimum level of ETH to call the peg-in function
* Having equitableCashout() send the user their entire "fair share" the first time they call it (burning all their RDC tokens as a result) and requiring a non-zero RDC balance to call it

## Miner Vulnerabilities

In the development version of the code, there is a known major miner vulnerability in the randomRate() function, which uses a hash of the block number and difficulty to determine the random rate.  Block number (extremely insecure) was used simply to make testing repeated calls possible, as block timestamp (also insecure) was not viable due to lack of sub-second block timestamping in ganache-cli.

Production mitigations for this known vulnerability include:
* Using a deployed instance of RANDAO for random number generation instead of the current randomRate() function: https://github.com/randao/randao
* (Alternatively) using an Oraclize service: http://docs.oraclize.it/#data-sources-random

## Malicious Creator

Owner functions are currently limited to a single function (equitableLiquidation).  This function is somewhat difficult for a malicious Owner to abuse, as it puts the contract into a state where any holders of RDC may burn their stake of the tokens for a proportional amount of the ETH held by the contract (both RDC and contract's own ETH levels are fixed at the time of liquidation).  The Owner could attempt to abuse this function if they themselves pegged in to RDC at a relatively unfavorable rate and wanted to attempt to socialize their losses by triggering a liquidation event shortly after others had pegged in to the contract but before much ETH had been pegged out.

Production mitigations for this problem include:
* Removing the equitableLiquidation() function entirely (the same functionality in a circuit-breaker situation is automated in the equitableDestruct() function)

## Off-chain Safety

* Unlikely to be implemented in a development environment; could use HTTPS certifications on actual servers running the web application in the real world
* (see link for other ideas of good web security practices if this were an actually-deployed application)

## Cross-chain Replay Attacks

Production mitigations for this problem include:
* Creating the production instance of the randomcoin contract from a hard-fork-only address
* Warning users about the potential for making accidental ETC transactions

## Tx.Origin Problem

Mitigations for the tx.origin problem include:
* Contracts do not use tx.origin

## Solidity Function Signatures and Fallback Data Collisions

Mitigations for the fallback signature collision problem include:
* Using an empty fallback function for the RDC contract

## Incorrect Use of Cryptography

The only use of "cryptography" in the contract is in the use of the keccak256() function in the placeholder randomRate() function, which should be replaced in a Production implementation (see notes to **Miner Vulnerabilities** section above).

## Gas Limits

Mitigations for functions running into gas limits include:
* Looping over a fixed-size array in the single function that uses loops
* Limiting the format of user-provided data to uint256 which is not subsequently stored

## Stack Call Depth Exhaustion

Mitigations for the stack call depth exhaustion problem include:
* Using a newer version of Solidity which is not susceptible to this attack
