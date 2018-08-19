Explain what measures I took to make sure that contracts are not susceptible to common attacks
See Module 9 Lesson 3 for attacks that contracts should be resistant to
(link to "safety checklist": https://www.kingoftheether.com/contract-safety-checklist.html)

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
* Given random exchange rate mechanism, public visibility of balances has limited game-theoretic impact (mostly impacts probabilities that someone could drain the contract / trigger equitable liquidation, but the latter gives assurance to holders that they will get something "fair" back if the exchange rate mechanism fails) -- NOTE THAT THE LAST-MOVER-ADVANTAGE WILL INCENTIVIZE THE LARGEST HOLDERS TO KEEP THEIR FUNDS IN RDC EVEN IF THE CONTRACT MOVES TO A LIQUIDATION STATE

*** NOTE TO SELF: think about how someone could try to game the system by viewing balances, if they were a relative "whale" -- are there attack vectors whereby they attempt to drain as much ETH from the contract as possible while not triggering equitableLiquidation via a bunch of smaller transactions after a bulk peg-in ?

## Denial of Service / Dust Spam

Mitigations for dust spam include:
* Requiring a minimum level of ETH to call the peg-in function
* Having equitableCashout() send the user their entire "fair share" the first time they call it (burning all their RDC tokens as a result) and requiring a non-zero RDC balance to call it

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