const KYC = artifacts.require("KYC");

module.exports = function(deployer) {
    //  Deploy KYC
    deployer.deploy(KYC);
};
