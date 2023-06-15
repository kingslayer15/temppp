pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {NFTVault} from "src/contracts/NFTVault.sol";
import {FreeCityGameNFTv2} from "src/contracts/v2/FreeCityGameNFTv2.sol";

contract ImportTest is Test {

    function setUp() public {
//        vm.rpcUrl("https://sepolia.infura.io/v3/1b1d8eead5a24420aa64cff5249c8631");

    }

    function testGetDeposits() public {

                uint256 deployerPrivateKey = vm.deriveKey("tribe deer ripple cover ostrich hand attitude edit midnight clerk recipe turn",0);
//        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_72");
        //        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_83");
        vm.startBroadcast(deployerPrivateKey);
        //代理合约
        address proxy = 0xE36777C293184b176865d7f94169b09a8E232330;
        address freeCityContractAddress = 0x4352a311D706dD7439ef1B257A81677bB162e5fc;
        address userAddress = 0x83502fB1227894Dbd7a2c78c30936253808Be439;

        //        FreeCityGameNFTv2 freeCityGameNFTv2 = FreeCityGameNFTv2(freeCityContractAddress);
        //        freeCityGameNFTv2.approve(proxy, 91);
        NFTVault nFTVault = NFTVault(proxy);
        //                nFTVault.deposit(freeCityContractAddress, 91);
        //                nFTVault.withdraw(freeCityContractAddress, userAddress,  91);
        //                nFTVault.getDeposits(userAddress);
        address owner = nFTVault.getOwner();

        vm.stopBroadcast();
    }
}
