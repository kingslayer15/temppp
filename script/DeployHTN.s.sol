// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "forge-std/Script.sol";
import {FreeCityGameNFTv2} from "src/contracts/v2/FreeCityGameNFTv2.sol";

import {ProxyAdmin} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";


contract DeployHTN is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey("tribe deer ripple cover ostrich hand attitude edit midnight clerk recipe turn",0);
        address deployAddress = 0xDd1E7B529460716fA9Bd9a1582C61F9C4Bfb79bD;
        address newOwner = 0x53b6511ccF144E6a7fF8578029C24C19C6552A72;
        address contractAddress = 0xC3B56a7D6E21D999f03956B4060641553Dfb0A16;
        vm.startBroadcast(deployerPrivateKey);
        // 部署 FreeCityGameNFTv2 合约
        FreeCityGameNFTv2 fcc = FreeCityGameNFTv2(contractAddress);
//        fcc.initialize(deployAddress,"Hot Tok NFT","HTN");

        fcc.transferOwnership(newOwner);

        // 部署 ProxyAdmin 合约
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        vm.stopBroadcast();

    }

}
