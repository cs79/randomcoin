# randomcoin
### _A non-correlated cryptocurrency portfolio hedge_

## What is randomcoin?
randomcoin (RDC) is a token built on top of the Ethereum blockchain that offers cryptocurrency investors a non-correlated hedge to their token portfolios.  RDC is pegged to ether (ETH) at a random (bounded) rate, with programmatic and incentive-based mechanisms in place to defend the peg.

## How does it work?
Upon initial contract creation, the RDC contract will be in a "funding" state where investors can peg in to the contract.  Once a sufficient number of peg-in transactions have occured (or a minimum funding level of ETH is met), the contract moves to an "active" state and peg-out transactions can be made as well.

The rate at which any individual peg-in or peg-out transaction will be processed is a random number ... cauchy etc.

[, bounded to be between 50 and 150 with an expected value of 100.  For investors, this means that *in expectation*, the value of RDC is always 100 per 1 ETH; the *realized* value will rarely be exactly this, though.  The value-in-expectation should make RDC stably tradable for ETH or other crypto-tokens that can be priced in ETH, while its value-in-realization if pegged out of the contract gives it additional value as an uncorrelated portfolio hedge (as pegged-out returns cannot be systematically correlated with any other crypto-token holdings since those returns are random).]

### A note on correlation

The term "uncorrelated" here is used w.r.t. a portfolio based in ETH; if an investor is basing their portfolio in a fiat currency such as USD, RDC will be correlated with the ETH/USD exchange rate, though not in exactly the same manner in realization.  (Realized rates for RDC/USD via the RDC/ETH and ETH/USD pairs will not necessarily be at the expected 100/1 RDC/ETH rate.)

## How can I set this up to try it out?

The randomcoin application was built on Linux (Ubuntu 16.04.5 LTS) with the following dependencies:

* `Node` version [xxx]
* `Npm` version [xxx]
* `Truffle` version [xxx]
* `ganache-cli` version [xxx]
* `OpenZeppelin` version [xxx]
* `Chart.js` version 2.7.2
* `react-chartjs-2` version 2.7.4
* `MetaMask` version 4.9.3 (or another injected web3 instance; this application was only tested with Metamask)

### Installing Node Packages
(how to fetch these things assuming that packages.json is correct)

[possibly keep the openzeppelin contracts in the repo even if i don't put the rest of the node packages on there]

### Installing MetaMask

`MetaMask` is provided as a browser extension; installation links for supported browsers can be found at https://metamask.io/

### Running the Tests

Once the dependencies (particularly `Truffle`, `ganache-cli`, and `OpenZeppelin`) have been properly installed in the project directory, Truffle can be used to run the contract tests by following these steps:

1) Open a terminal window in the project directory
2) Run the command `truffle develop` to start a Truffle development console session
3) Inside the Truffle development console, run the following commands:
    * `compile`: compile the project's smart contracts
    * `migrate --reset`: migrate the compiled contracts to the development chain (ganache-cli under the hood)
    * `test`: run the tests of the smart contract

### Running the Development Server

With the smart contract tests passing, you can run and interact with the smart contract on a development server by following these steps:

1) Open a second terminal window in the project directory
2) Run the command `npm run start`
3) If a web browser does not automatically load once the server is running, open your browser and go to `localhost:3000` (the default)

The frontend application should now be running in your web browser, connected to a deployed instance of the smart contract running on the development chain. You may need to restart the development chain running in the first terminal (with either `truffle develop --log` or `ganache-cli -l=8000000` if you would like to observe live logs of contract events) and re-migrate the contracts if you experience issues with the application.

In order to test the frontend functionality using MetaMask, copy the seed phrase from the development chain into the appropriate prompt at startup (for a clean install), or copy the first private key generated by the development chain into the private key field for a new account.  You will need to ensure that you have the `LocalHost 8545` network selected in MetaMask in order to connect to the development chain being served by Truffle / ganache-cli.

### Interacting with the Application

(what you can see, what buttons you have available to you, owner stuff)
