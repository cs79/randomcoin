const contractProperties = [
  'owner',
  'minimumPegInBaseAmount',
  'minimumPegInMultiplier',
  'averageRate',
  'expectedRate',
  'txCount',  // added; maybe need to add more
  'halfWidth',
  'blockWaitTime',
  'minTxToActivate',
  'minBalanceToActivate',
  'maxRateIndex',
  'rateArrayFull',
  //'state',
  'txLockMutex', // not sure that this is actually working
]

/*
  TODO:
  - replace contractProperties loop thing with a new function to get ALL state variables and unpack correctly
  - on componentDidMount, call the function that resets the state on a loop
  - replace buttons with auto-refresh if it works
  - clean up redundant functions
  - maybe set a "global" default account if I can
  - 
*/

import contract from 'truffle-contract'
import React, { Component } from 'react'
import RDCContract from '../build/contracts/RDC.json'
import getWeb3 from './utils/getWeb3'
import { Line, Bar } from 'react-chartjs-2'

import './css/oswald.css'
import './css/open-sans.css'
import './css/pure-min.css'
import './App.css'

class App extends Component {
  constructor(props) {
    super(props)

    this.state = {
      availablePayout: 0,
      haircut: 0,
      averageRate: 0,
      txCount: 0,
      txCountSinceLastReset: 0,
      expectedRate: 0,
      halfWidth: 0,
      liquidationBlockNumber: 0,
      blockWaitTime: 0,
      minimumPegInBaseAmount: 0,
      minimumPegInMultiplier: 0,
      minTxToActivate: 0,
      minBalanceToActivate: 0,
      latestRates: null, // should be an array of uint256
      maxRateIndex: 0,
      rateArrayFull: false,
      rawState: '',
      state: '', // might need to change this to bytes4 or something
      txLockMutex: false,
      latestRates: [],
      lastRate: 0, // not a state variable in RDC.sol; just captured here for testing / convenience until I can get array working
      userPegInValue: '',  // used in form field capture
      userPegOutValue: '', // used in form field capture
      userAcctBalance: 0,  // not a state variable in RDC.sol; just captured here for frontend
      userIsOwner: false,
      web3: null,
    }
    this.getUpdatedState = this.getUpdatedState.bind(this) // needed or no ?
    this.handleChange = this.handleChange.bind(this)
    this.handlePegInButton = this.handlePegInButton.bind(this)
    this.handlePegOutButton = this.handlePegOutButton.bind(this)
    this.handleCashOutButton = this.handleCashOutButton.bind(this)
    this.handleUnlockMutex = this.handleUnlockMutex.bind(this)
    this.handleEquitableLiquidation = this.handleEquitableLiquidation.bind(this)
    this.handleNextBlock = this.handleNextBlock.bind(this)
  }

  componentWillMount() {
    // Get network provider and web3 instance.
    // See utils/getWeb3 for more info.

    getWeb3
    .then(results => {
      this.setState({
        web3: results.web3
      })

      // Instantiate contract once web3 provided.
      this.getUpdatedState()
      setInterval(this.getUpdatedState.bind(this), 1000)
    })
    .catch((err) => {
      console.log('Error finding web3.', err)
    })
  }

  // call to refresh all relevant state variables from RDC contract
  getUpdatedState() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if (err) {
        console.error(err)
      } else {
        const rdcInstance = await RDC.deployed()
        const propertyPromises = contractProperties.map(prop => rdcInstance[prop].call({ from: accounts[0] }))
        const properties = await Promise.all(propertyPromises)
        const propertyMap = {}
        contractProperties.forEach((prop, idx) => {
          propertyMap[prop] = typeof properties[idx] === 'object' && properties[idx] !== null ? properties[idx].c[0] : properties[idx]
        })
        // check the fetched owner value and compare to accounts[0]
        propertyMap['userIsOwner'] = propertyMap['owner'] === accounts[0]
        // also get latestRates array
        const bnArray = await rdcInstance.getLatestRates({ from: accounts[0] })
        propertyMap['latestRates'] = bnArray.map(elt => elt.c[0])
        propertyMap['lastRate'] = propertyMap['latestRates'].filter(elt => elt !== 0).reverse()[0]
        // also get accounts[0] balance
        const bal = await rdcInstance.balanceOf(accounts[0])
        propertyMap['userAcctBalance'] = this.state.web3.fromWei(bal.toNumber())
        // also get the new stateBytes field
        /*
        VALUES:
        Funding: 0xfa62
        Active: 0xf07b
        Liquidating: 0x6379
        */
        const stateBytes2 = await rdcInstance.getStateBytes({ from: accounts[0] })
        propertyMap['rawState'] = stateBytes2
        if (stateBytes2 === '0xfa62') {
          propertyMap['state'] = 'Funding'
        } else if (stateBytes2 === '0xf07b') {
          propertyMap['state'] = 'Active'
        } else if (stateBytes2 === '0x6379') {
          propertyMap['state'] = 'Liquidating'
        } else {
          propertyMap['state'] = 'UNKNOWN CONTRACT STATE'
        }
        
        // console.log(propertyMap['txLockMutex'])
        
        // add in a mapping for actual state once I figure out how to convert this from whatever bytes returns

        this.setState(propertyMap)
      }
    })
  }

  // various button handlers
  handleChange(e) {
    this.setState({ [e.target.name]: e.target.value })
  }

  handlePegInButton() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    var rdcInstance

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if (err) {
        console.error(err)
      } else {
        rdcInstance = await RDC.deployed()
        // convert the inputted value to Wei; should be clearly marked on the form as being in ETH
        // I'm not sure if it's possible / easy to detect web3 version, but if so, make this call conditional (if ver >= 1.0.0, call web3.utils.toWei instead)
        const val = await rdcInstance.pegIn({ from: accounts[0], value: this.state.web3.toWei(this.state.userPegInValue) })
        console.log(val)
        this.setState({ userPegInValue: '' })
      }
    })
  }

  handlePegOutButton() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    var rdcInstance

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if(err) {
        console.error(err)
      } else {
        rdcInstance = await RDC.deployed()
        // convert down to "wei equivalent" ? Probably...
        const val = rdcInstance.pegOut(this.state.web3.toWei(this.state.userPegOutValue), {from: accounts[0]})
        console.log(val)
        this.setState({ userPegOutValue: '' })
      }
    })
  }

  handleCashOutButton() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    var rdcInstance

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if(err) {
        console.error(err)
      } else {
        rdcInstance = await RDC.deployed()
        const val = rdcInstance.equitableCashout({ from: accounts[0] })
        console.log(val)
      }
    })
  }

  handleUnlockMutex() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    var rdcInstance

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if(err) {
        console.error(err)
      } else {
        rdcInstance = await RDC.deployed()
        const val = rdcInstance.emergencyUnlockTxMutex({ from: accounts[0] })
        console.log(val ? "Success" : "Failure")
      }
    })
  }

  handleEquitableLiquidation() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    var rdcInstance

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if(err) {
        console.error(err)
      } else {
        rdcInstance = await RDC.deployed()
        const val = rdcInstance.equitableLiquidation({ from: accounts[0] })
        console.log(val ? "Success" : "Failure")
      }
    })
  }

  handleNextBlock() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    var rdcInstance

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if(err) {
        console.error(err)
      } else {
        rdcInstance = await RDC.deployed()
        const val = rdcInstance.nextBlock({ from: accounts[0] })
        console.log(val ? "Block Mined!" : "Block Not Mined :(")
      }
    })
  }

  // calculate bins for a simple histogram using Bar class
  calcHistogramBars() {
    var barData = Array(10).fill(0)
    this.state.latestRates.forEach(function(elt) {
      // big dumb switch since I don't know how else to do this in JS
      if (elt >=50 && elt < 60) {
        barData[0] += 1
      } else if (elt >= 60 && elt < 70) {
        barData[1] += 1
      } else if (elt >= 70 && elt < 80) {
        barData[2] += 1
      } else if (elt >= 80 && elt < 90) {
        barData[3] += 1
      } else if (elt >= 90 && elt < 100) {
        barData[4] += 1
      } else if (elt >= 100 && elt < 110) {
        barData[5] += 1
      } else if (elt >= 110 && elt < 120) {
        barData[6] += 1
      } else if (elt >= 120 && elt < 130) {
        barData[7] += 1
      } else if (elt >= 130 && elt < 140) {
        barData[8] += 1
      } else if (elt >= 140) {
        barData[9] += 1
      }
    })
    return barData
  }

  render() {
    console.log('latestRates', this.state.latestRates)

    let cashOutButton
    if (this.state.state === "Liquidating") {
      cashOutButton = <button onClick={this.handleCashOutButton}>Claim equitable cashout</button>
    }

    let ownerArea
    if (this.state.userIsOwner) {
      ownerArea = <div>Welcome to the secret Owner area :)
                    <br /><br />
                    <button onClick={this.handleUnlockMutex} disabled={!this.state.txLockMutex}>Unlock txLockMutex - only active if txLockMutex is LOCKED</button>
                    <br /><br />
                    <button onClick={this.handleEquitableLiquidation}>Trigger equitable liquidation</button>
                    <br /><br />
                    <button onClick={this.handleNextBlock}><strong>Mine a block</strong></button>
                  </div>
    }

    return (
      <div className="App">
      <nav className="navbar pure-menu pure-menu-horizontal">
        <a href="#" className="pure-menu-heading pure-menu-link nav-title">randomcoin</a>
        <a href="#" className="pure-menu-heading pure-menu-link nav-link">About</a>
        <a href="https://github.com/cs79/randomcoin" className="pure-menu-heading pure-menu-link nav-link">Source</a>
      </nav>
      <main className="container">
        <div className="graphic-container">
          <Line data={{
            labels: Array(16).fill(0).map((_, i) => i + 1),
            datasets: [
              {
                data: this.state.latestRates.slice(),
                label: "Latest Transacted Rates",
              }
            ],
            options: {
              maintainAspectRatio: false,
            }
          }}/>
        </div>
        <div className="graphic-container">
          <Bar data={{
            labels: ["50-60", "60-70", "70-80", "80-90", "90-100", "100-110", "110-120", "120-130", "130-140", "140-150"],
            datasets: [
              {
                data: this.calcHistogramBars(),
                label: "Latest Transacted Rates by Bucket"
              }
            ]
          }}/>
        </div>
        <div>Account RDC Balance: {this.state.userAcctBalance}</div>
        <div>Last transaction rate: {this.state.lastRate}</div>
        <div>Transaction count: {this.state.txCount}</div>
        <div>Average transaction rate: {this.state.averageRate}</div>
        <div><strong>Contract State:</strong> {this.state.state}</div>
        <div>Transaction mutex: {this.state.txLockMutex ? "Locked" : "Unlocked"}</div>
        <div>User is owner?: {this.state.userIsOwner ? "True" : "False"}</div>
        <br /><br />
        <input type="numeric" name="userPegInValue" value={this.state.userPegInValue} onChange={this.handleChange} />
        <button onClick={this.handlePegInButton}>Peg in to RDC</button>
        <br /><br />
        <input type="numeric" name="userPegOutValue" value={this.state.userPegOutValue} onChange={this.handleChange} />
        <button onClick={this.handlePegOutButton}>Peg out of RDC</button>
        <br /><br />
        {cashOutButton}
        <br /><br />
        {ownerArea}
      </main>
      </div>
    );
  }
}

export default App

