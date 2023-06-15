// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "forge-std/Script.sol";
import {BenefitCard} from "src/contracts/BenefitCard.sol";

import {ProxyAdmin} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";


contract DeloyBenefitCard is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey("tribe deer ripple cover ostrich hand attitude edit midnight clerk recipe turn",0);
        address deployAddress = 0xDd1E7B529460716fA9Bd9a1582C61F9C4Bfb79bD;
        address payee = 0xF9EA233D38a550c3C546B100fba94bDBb5a4a5be;
        address _freeCity = 0xC3B56a7D6E21D999f03956B4060641553Dfb0A16;
        address _erc1155Card = 0x36d2281b7d4aD770bA201B6B7e9e56471ebcc60E;
        address _erc1155Vip = 0xf9C3fc3C058618597B082ABa5519566259D2BEec;
        address newOwner = 0x53b6511ccF144E6a7fF8578029C24C19C6552A72;
        address contractAddress = 0x6a227b3cC5F34899Bfa0E9B2b01e8bE20Bd68a9b;
        vm.startBroadcast(deployerPrivateKey);

        BenefitCard benefitCard = BenefitCard(contractAddress);
//        function initialize(address _owner, address _payee_, uint256 _mintAmount, address _freeCity, address _erc1155Card, address _erc1155Vip)
//        benefitCard.initialize(deployAddress,payee,1000,_freeCity,_erc1155Card,_erc1155Vip);

        benefitCard.transferOwnership(newOwner);
        // 部署 ProxyAdmin 合约
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        vm.stopBroadcast();

    }

}
