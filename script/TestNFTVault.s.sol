// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "forge-std/Script.sol";
import {NFTVault} from "src/contracts/NFTVault.sol";
import {FreeCityGameNFTv2} from "src/contracts/v2/FreeCityGameNFTv2.sol";
import {ProxyAdmin} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import {AdminUpgradeabilityProxy} from "src/contracts/import.sol";
import {TransparentUpgradeableProxy} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TestNFTVault is Script {
    // 定义一个新的事件
    event Owner(address indexed owner);

    function run() external {
//    代理合约的地址是0xE430F2091c457d11Ded67771A62BeE1678c5ce46
//    代理合约的部署地址是0x72803C7D1ba53D50a459F7267bdF755275394211
//        逻辑合约的地址是0xa1413526F9117536Dd94aB2Cb4eDa3E19aF218b6
//        逻辑合约的部署地址是0xDd1E7B529460716fA9Bd9a1582C61F9C4Bfb79bD
//        逻辑合约的ProxyAdmin是0xE430F2091c457d11Ded67771A62BeE1678c5ce46
//
//    根据上面的智能合约代码逻辑合约的owner()是哪个地址
//
//        我使用0xDd1E7B529460716fA9Bd9a1582C61F9C4Bfb79bD调代理合约的withdraw()时提示Only the owner can withdraw the NFT.
//        我调代理合约的owner()结果是0x0000000000000000000000000000000000000000
//    我调逻辑合约的owner()结果是0xDd1E7B529460716fA9Bd9a1582C61F9C4Bfb79bD
                uint256 deployerPrivateKey = vm.deriveKey("tribe deer ripple cover ostrich hand attitude edit midnight clerk recipe turn",0);
//        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_72");
//        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_83");
        vm.startBroadcast(deployerPrivateKey);
        //代理合约
        address payable proxy = payable(address(0x4254E880110a042290161702af9A14250977a32c));
        address freeCityContractAddress = 0x4352a311D706dD7439ef1B257A81677bB162e5fc;
        address nFTVaultContractAddress = 0x936539206F8e8BeDb6F80937a9879920112C510F;
        address userAddress = 0x83502fB1227894Dbd7a2c78c30936253808Be439;
        address deployAddress = 0xDd1E7B529460716fA9Bd9a1582C61F9C4Bfb79bD;
        address adminContractAddress = 0x469077f83C24910f18EA190E9E35fCE46525C942;

//        FreeCityGameNFTv2 freeCityGameNFTv2 = FreeCityGameNFTv2(freeCityContractAddress);
//        freeCityGameNFTv2.approve(proxy, 96);
                NFTVault nFTVault = NFTVault(proxy);
//        AdminUpgradeabilityProxy proxyContract = AdminUpgradeabilityProxy(proxy);
//                ProxyAdmin proxyAdmin = ProxyAdmin(adminContractAddress);
//                proxyAdmin.upgrade(proxyContract,nFTVaultContractAddress);
//                nFTVault.deposit(freeCityContractAddress, 96);
                nFTVault.withdraw(freeCityContractAddress, userAddress,  96);
//        nFTVault.setProxyAdmin(deployAddress);
//                nFTVault.getDeposits(userAddress);
//        address owner = nFTVault.owner();
        // 发出新的事件
//        emit Owner(owner);
        vm.stopBroadcast();
    }

}