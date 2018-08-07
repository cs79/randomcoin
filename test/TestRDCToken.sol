pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RDCToken.sol";

// basically here just ensure the behavior we actually will use in RandomCoin.sol
contract TestRDCToken {

    //RDCToken rdc = RDCToken(DeployedAddresses.RDCToken());  // try to use this if possible
    
    // test ownership set by this contract when instantiated
    function testOwnerSetCorrectly() public {
        RDCToken _this_rdc = new RDCToken();

        address expected = address(this);

        Assert.equal(expected, _this_rdc.owner(), "Owner should be the deploying contract");
    }

    // test ownership via DeployedAddresses();
    /*function testOwnerSetCorrectlyDeployed() public {

        address expected = address(DeployedAddresses.RDCToken());

        Assert.equal(expected, rdc.owner(), "Owner should be the contract which deployed rdc");
    }*/

    // test owner's ability to mint + balanceOf functionality
    function testOwnerCanMintNewTokens() public {
        RDCToken _this_rdc = new RDCToken();

        uint expected = 9001;

        _this_rdc.mint(address(this), 9001);

        Assert.equal(expected, _this_rdc.balanceOf(address(this)), "Address _add should receive 9001 minted tokens");
    }

    // test totalSupply from deployed contract (no activity yet)
    /*
    function testInitialTotalSupply() public {
        
        uint expected = 0;

        Assert.equal(expected, rdc.totalSupply(), "Initial total supply should be 0");
    }*/

    // test totalSupply after minting some tokens
    function testTotalSupply() public {
        RDCToken _this_rdc = new RDCToken();

        address _add = address(this);
        uint firstXfer = 9000;
        uint secondXfer = 1000;
        uint expected = firstXfer + secondXfer;

        _this_rdc.mint(_add, firstXfer);
        _this_rdc.mint(_add, secondXfer);

        Assert.equal(expected, _this_rdc.totalSupply(), "totalSupply should be 10000");
    }

    // test transferFrom (should pass) - can make another version that should fail
    /*function testTransferFrom(address _add) public {
        RDCToken _this_rdc = new RDCToken();

        uint expected = 100;

        // mint some new tokens and then have 100 transferred to this contract's address
        _this_rdc.mint(_add, 1000);
        _this_rdc.transferFrom(_add, address(this), 100);

        Assert.equal(expected, _this_rdc.balanceOf(address(this)), "This contract should have 100 tokens");
    }*/

    // test that bad transferFrom will fail
    /*function testBadTransferFrom(address _add) public {
        RDCToken _this_rdc = new RDCToken();

        uint _bal = 50;
        uint toXfer = 100;

        _this_rdc.mint(_add, _bal);
        _this_rdc.transferFrom(_add, address(this), toXfer);   // should fail

        uint _post_bal = _this_rdc.balanceOf(_add);

        Assert.equal(_post_bal, _bal);
    }*/
}