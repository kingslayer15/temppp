// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "forge-std/Script.sol";
import {Jiaoyisuo} from "src/erc20_test/bsc_test_env/Jiaoyisuo.sol";
import {MyToken} from "src/erc20_test/bsc_test_env/MyToken.sol";
import {Rujinpro} from "src/erc20_test/bsc_test_env/Rujinpro.sol";
import {Chujinpro} from "src/erc20_test/bsc_test_env/Chujinpro.sol";
import {FCC} from "src/contracts/FCC.sol";

interface SwapRouterService {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract DeployJiaoyisuo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_72");
        address myusdt = 0x2e092dc6eEA2fD92BDAEf3930FdD0e6d38455627;
        address newOwner = 0x53b6511ccF144E6a7fF8578029C24C19C6552A72;

        address jiaoyisuoAdd = 0x8335a20D761f45Ef6aEa5e50bBfdA80C8521C787;
        address myTokenAdd = 0x1018A49A3143A19401B41352Eb4735df71ed7F3f;
        address rujinproAdd = 0x99dc35e01DC30b66e7A14E6C6827fd8bB0742D97;
        address chujinproAdd = 0xB0ae65e44a89e57bdeb71F008554f2B212A91ec8;
        address pancake = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
        address pancakeBUSD = 0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814;
        vm.startBroadcast(deployerPrivateKey);
        // 部署 FreeCityGameNFTv2 合约
//        Jiaoyisuo jiaoyisuo = new Jiaoyisuo();
//        Jiaoyisuo jiaoyisuo = Jiaoyisuo(jiaoyisuoAdd);
//        jiaoyisuo.init(myTokenAdd);

//        MyToken mytoken = new MyToken(jiaoyisuoAdd);
//        Rujinpro rujinpro1 = new Rujinpro(jiaoyisuoAdd);
//        Chujinpro chujinpro = new Chujinpro();

//        // 部署 FCC 合约
//        FCC fcc = FCC(myusdt);


        vm.stopBroadcast();

    }


}
