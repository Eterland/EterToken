const token = artifacts.require("ETER");
// dev
module.exports = function (deployer) {
	deployer.deploy(
		token,
		"0xf17f52151EbEF6C7334FAD080c5704D77216b732",
		"0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef",
		"0x5AEDA56215b167893e80B4fE645BA6d5Bab767DE",
		"0x6330A553Fc93768F612722BB8c2eC78aC90B3bbc",
		"0x0F4F2Ac550A1b4e2280d04c21cEa7EBD822934b5"
	);
};