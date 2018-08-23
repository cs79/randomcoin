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
  'state',
  'txLockMutex',
]
import contract from 'truffle-contract'
import React, { Component } from 'react'
import RDCContract from '../build/contracts/RDC.json'
import getWeb3 from './utils/getWeb3'
import { Line } from 'react-chartjs-2'

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
      state: null, // might need to change this to bytes4 or something
      txLockMutex: false,
      latestRates: [],
      lastRate: 0, // not a state variable in RDC.sol; just captured here for testing / convenience until I can get array working
      userPegInValue: '',  // used in form field capture
      userPegOutValue: '', // used in form field capture
      userAcctBalance: 0,  // not a state variable in RDC.sol; just captured here for frontend
      web3: null,
    }
    this.handleGetArrayClick = this.handleGetArrayClick.bind(this)
    this.refreshState = this.refreshState.bind(this)
    this.handleChange = this.handleChange.bind(this)
    this.handlePegInButton = this.handlePegInButton.bind(this)
    this.handlePegOutButton = this.handlePegOutButton.bind(this)
    this.getUpdatedState = this.getUpdatedState.bind(this) // needed or no ?
    this.handleUserAcctBalanceButton = this.handleUserAcctBalanceButton.bind(this)
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
      // this.instantiateContract()
      setInterval(this.instantiateContract.bind(this), 10000)
    })
    .catch((err) => {
      console.log('Error finding web3.', err)
    })
  }

  instantiateContract() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if (err) {
        console.error(err)
      } else {
        const instance = await RDC.deployed()
        const propertyPromises = contractProperties.map(prop => instance[prop].call({ from: accounts[0] }))
        const properties = await Promise.all(propertyPromises)
        const propertyMap = {}
        contractProperties.forEach((prop, idx) => {
          propertyMap[prop] = typeof properties[idx] === 'object' && properties[idx] !== null ? properties[idx].c[0] : properties[idx]
        })
        this.setState(propertyMap)
      }
    })
  }

  // ideally I'd like to be able to "refresh" the state (as read from the contract) after every function
  getUpdatedState() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if (err) {
        console.error(err)
      } else {
        const instance = await RDC.deployed()
        const propertyPromises = contractProperties.map(prop => instance[prop].call({ from: accounts[0] }))
        const properties = await Promise.all(propertyPromises)
        const propertyMap = {}
        contractProperties.forEach((prop, idx) => {
          propertyMap[prop] = typeof properties[idx] === 'object' && properties[idx] !== null ? properties[idx].c[0] : properties[idx]
        })
        return propertyMap
      }
    })
  }

  handleGetArrayClick() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    var rdcInstance

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if (err) {
        console.error(err)
      } else {
        rdcInstance = await RDC.deployed()
        const bnArray = await rdcInstance.getLatestRates({ from: accounts[0] })
        const valArray = bnArray.map(elt => elt.c[0])
        // bnArray.forEach(function(element) {
        //   valArray.push(element.c[0])
        // })
        // unpack the correct values from the array
        // for (let i; i < valArray.length; i++) {
        //   valArray[i] = valArray[i].c[0]
        // }
        // console.log(valArray)
        this.setState({ latestRates: valArray })
      }
    })
  }

  refreshState() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if (err) {
        console.error(err)
      } else {
        const instance = await RDC.deployed()
        const propertyPromises = contractProperties.map(prop => instance[prop].call({ from: accounts[0] }))
        const properties = await Promise.all(propertyPromises)
        const propertyMap = {}
        contractProperties.forEach((prop, idx) => {
          propertyMap[prop] = typeof properties[idx] === 'object' && properties[idx] !== null ? properties[idx].c[0] : properties[idx]
        })
        this.setState(propertyMap)
      }
    })
  }

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
        // this.setState({ lastRate: val.c[0] })
        // this doesn't work as intended currently; probably need to listen for events and manually change state in JS instead (?)
        // const newState = await this.getUpdatedState()
        // this.setState(newState)
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
        const val = rdcInstance.pegOut(this.state.userPegOutValue, {from: accounts[0]})
        console.log(val)
      }
    })
  }

  handleUserAcctBalanceButton() {
    const RDC = contract(RDCContract)
    RDC.setProvider(this.state.web3.currentProvider)

    var rdcInstance

    this.state.web3.eth.getAccounts(async (err, accounts) => {
      if(err) {
        console.error(err)
      } else {
        rdcInstance = await RDC.deployed()
        const bal = await rdcInstance.balanceOf(accounts[0])
        this.setState({userAcctBalance: this.state.web3.fromWei(bal.toNumber())})
      }
    })
  }

  render() {
    console.log('latestRates', this.state.latestRates)
    return (
      <div className="App">
      <nav className="navbar pure-menu pure-menu-horizontal">
        <a href="#" className="pure-menu-heading pure-menu-link nav-title">randomcoin</a>
        <a href="#" className="pure-menu-heading pure-menu-link nav-link">About</a>
        <a href="https://github.com/cs79/randomcoin" className="pure-menu-heading pure-menu-link nav-link">Source</a>
      </nav>
      <main className="container">
        <div className="graphic-container">This is where a timeseries graphic should go I guess</div>
        <div className="graphic-container">And another graphic next to it with the histogram</div>
        <Line data={{
          labels: Array(16).fill(0).map((_, i) => i + 1),
          datasets: [
            {
              data: this.state.latestRates.slice(),
            }
          ]
        }}/>
        <div>Then there needs to be a little text widget with the last tx rate</div>
        <div>And another one with the total tx count (maybe also since last reset ?)</div>
        <div>And then below the histogram the average rate (and maybe expected rate ?)</div>
        <br /><br />
        <div>Account RDC Balance: {this.state.userAcctBalance}</div>
        <div>Last transaction rate: {this.state.lastRate}</div>
        <div>Transaction count: {this.state.txCount}</div>
        <div>Average transaction rate: {this.state.averageRate}</div>
        <br /><br />
        <div>Below all that stuff there should be buttons and maybe some explanation</div>
        <button onClick={this.refreshState}>CLICK HERE TO REFRESH STATE VARIABLES</button>
        <br /><br />
        <button onClick={this.handleGetArrayClick}>CLICK HERE TO FETCH THE RATE ARRAY</button>
        <br /><br />
        <button onClick={this.handleUserAcctBalanceButton}>CLICK HERE TO FETCH USER RDC BALANCE</button>
        <br /><br />
        <input type="numeric" name="userPegInValue" value={this.state.userPegInValue} onChange={this.handleChange} />
        <button onClick={this.handlePegInButton}>Peg in to RDC</button>
        <br /><br />
        <input type="numeric" name="userPegOutValue" value={this.state.userPegOutValue} onChange={this.handleChange} />
        <button onClick={this.handlePegOutButton}>Peg out of RDC</button>
      </main>
      </div>
    );
  }
}

export default App

