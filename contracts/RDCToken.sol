pragma solidity ^0.4.23;

import "../installed_contracts/zeppelin/contracts/token/MintableToken.sol";

/*
Design notes:
- RandomCoin contract should mint these directly to accounts that peg in
- RandomCoin contract should have the ability to burn them somehow when it receives them back
- (i.e. RandomCoin contract's balance should get zeroed out when it receives a transfer probably ?)
- (may not matter that much as it won't ever "use" them in practice)

 */

contract RDCToken is MintableToken {
    string public constant name = "RDCToken";
    string public constant symbol = "RDC";

    // Should be constructed by the RandomCoin contract (exactly once - bool for this?)
    constructor() public {
        owner = msg.sender;
    }

    // EXTREMELY IMPORTANT QUESTION: DOES THIS NEED TO IMPLEMENT ALL NAMED METHODS IN THE CONTRACTS IT INHERITS FROM?
    
}
