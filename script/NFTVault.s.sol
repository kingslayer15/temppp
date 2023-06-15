// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "forge-std/Script.sol";
import {NFTVault} from "src/contracts/NFTVault.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_72");
        vm.startBroadcast(deployerPrivateKey);

        NFTVault nft = new NFTVault();

        vm.stopBroadcast();
    }
}
