const MyGameFactory = artifacts.require("MyGameFactory");

module.exports = function (deployer) {
  deployer.deploy(MyGameFactory);
};