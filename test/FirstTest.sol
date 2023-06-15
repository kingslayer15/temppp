pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {NFTVault} from "src/contracts/NFTVault.sol";


contract FirstTest is Test {
    NFTVault nftVault;

    function setUp() public {
    nftVault = new NFTVault();
        nftVault.getDeposits(0x9B00a2290f694A5699453a3ABecBDdFb648d3D08);
    }
}