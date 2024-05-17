var DonationExchanger = artifacts.require("DonationExchanger");

module.exports = function(deployer) {
    deployer.deploy(DonationExchanger);
};
