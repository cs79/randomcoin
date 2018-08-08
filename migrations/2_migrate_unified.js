var RDCToken = artifacts.require("RDCToken");
var RandomCoin = artifacts.require("RandomCoin");

module.exports = function(deployer) {
  deployer.deploy(RDCToken);
  deployer.deploy(RandomCoin);
};
