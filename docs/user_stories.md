# User Stories

## User Types

* Contract Owner
* Investor

## Scenario

The user visits a website with a web3 connection to the RandomCoin and RandomLotto contracts. They are presented with an interface which lets them engage in one of two types of financial activity, clearly demarcated by the UI:

    * Investment in a provably randomly priced security

The user can choose to do at most one of these things at a time, with options limited depending on the state of the contracts, interacting via a web3 client (e.g. MetaMask) through the website's UI:

### RandomCoin Contract

    * Peg in to the RandomCoin contract (exchanging ETH for RandomCoin, if the contract is active)
    * Peg out of the RandomCoin contract (exchanging RandomCoin for ETH, if the contract is active)
    * Collect ETH proportional to RandomCoin balance if the contract is liquidating
    * Force equitable liquidation of the contract (if the user is an Owner)

## User Stories

### Owner

* As the Owner of either the Lottery or RandomCoin contract, I can force an equitable liquidation of the contract(s), allowing pull payments to be made to addresses that put in some balance in exchange for either lottery tickets or RandomCoin

### Investor

* As an Investor, I can convert between ETH and the "RandomCoin" currency at a random rate which is reset on every transaction for every user so that I receive the uncorrelated exposure that I am seeking from the instrument [does it work this way right now ?] *** N.B. a pitfall of this entire system is that the exposure to ETH itself may then be back to fiat at a non-random rate, and the investor wants to hedge their fiat exposures rather than their ETH exposures...
* As an Investor, I can withdraw some ETH fairly if I have pegged in to RandomCoin in the event that a large withdrawal breaks the peg, so that I have some assurance that my investment will not simply vanish
* As an Investor, I know there is some mechanism for defending the peg, so that it is not constantly being broken and rendering my investment "useless" by failing to offer me the uncorrelated exposure that I am seeking
* As an Investor, I can collect statistics on the random peg rates so that I can feel assured that the mechanism is correctly offering me the kind of exposure I am seeking

