// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "forge-std/Script.sol";
import {AdminUpgradeabilityProxy} from "src/contracts/import.sol";
import {NFTVault} from "src/contracts/NFTVault.sol";
import {ProxyAdmin} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployLogicAndAdmin is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey("tribe deer ripple cover ostrich hand attitude edit midnight clerk recipe turn",0);
        address deployAddress = 0xDd1E7B529460716fA9Bd9a1582C61F9C4Bfb79bD;
        vm.startBroadcast(deployerPrivateKey);
        // 部署 NFTVault 合约
        NFTVault nftVault = new NFTVault();
        nftVault.initialize(deployAddress);

        // 部署 ProxyAdmin 合约
        ProxyAdmin proxyAdmin = new ProxyAdmin();


        vm.stopBroadcast();

    }

}
