// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import {AdminUpgradeabilityProxy} from "src/contracts/import.sol";

contract DeployUpgradeability is Script {
    function run() external {

        address logic = 0x9eC0Bf42a992b590F3DbD467Af3d06399D13DebA;

        address admin = 0x5E5b7fe0ebaa8D40c69eD40d29615D55F325f636;

        uint256 deployerPrivateKey = vm.deriveKey("tribe deer ripple cover ostrich hand attitude edit midnight clerk recipe turn",0);
//        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_72");

        deployAdminUpgradeabilityProxy(logic,admin,deployerPrivateKey);
    }

    function deployAdminUpgradeabilityProxy(address logic, address admin, uint256 privateKey) public{
        address deployAddress = 0xDd1E7B529460716fA9Bd9a1582C61F9C4Bfb79bD;
        address payee = 0xF9EA233D38a550c3C546B100fba94bDBb5a4a5be;
        address _freeCity = 0xC3B56a7D6E21D999f03956B4060641553Dfb0A16;
        address _erc1155Card = 0x36d2281b7d4aD770bA201B6B7e9e56471ebcc60E;
        address _erc1155Vip = 0xf9C3fc3C058618597B082ABa5519566259D2BEec;
        vm.startBroadcast(privateKey);
//        bytes memory data = "";
//        function initialize(address owner, string memory name, string memory symbol)
//        bytes memory data = abi.encodeWithSignature("initialize(string, string)", "Hot Tok Coin", "HTC");
        bytes memory data = abi.encodeWithSignature("initialize(address)",deployAddress);

        //        function initialize(address _owner, address _payee_, uint256 _mintAmount, address _freeCity, address _erc1155Card, address _erc1155Vip)

        //        用bytes memory data = abi.encodeWithSignature("initialize(address)", deployAddress);应该怎么写
    AdminUpgradeabilityProxy adminUpgradeabilityProxy = new AdminUpgradeabilityProxy(logic,admin,data);
        vm.stopBroadcast();
    }
}
