// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "openzeppelin-contracts/access/Ownable.sol";

interface SwapRouterService{
     function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface Erc20Service {
     function balanceOf(address account) external view returns (uint256);
     function approve(address spender, uint256 amount) external returns (bool);
     function transfer(address recipient, uint256 amount) external returns (bool);
     function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract Rujinpro is Ownable {

    mapping(uint256 => uint256) orderMapping;

   
    struct addconfig {
        address swapRouterAdd;
        address usdtAdd;
        address busdAdd;
        address swapHTTAddress;
        address[] getPath;
        SwapRouterService swapRouterService;
        Erc20Service erc20Service;
    }

    address account;

    addconfig initconfig;
    
    constructor(address addr1){

       initconfig.swapRouterAdd = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
       initconfig.usdtAdd = 0x2e092dc6eEA2fD92BDAEf3930FdD0e6d38455627;
       initconfig.busdAdd = 0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814;
       initconfig.getPath = [initconfig.usdtAdd,initconfig.busdAdd];
       initconfig.swapRouterService = SwapRouterService(initconfig.swapRouterAdd);
       initconfig.erc20Service = Erc20Service(initconfig.usdtAdd);
       initconfig.swapHTTAddress = addr1;
    }


    function getMoney(uint256 amountIn,uint256 servicefee,uint256 deadline,uint256 orderNo) public {
        uint256 finalIn = (amountIn * 98) / 100;
        uint256 part2 = (amountIn * 2) / 100;

        initconfig.erc20Service.transferFrom(msg.sender,address(this), finalIn);
        initconfig.erc20Service.transferFrom(msg.sender,initconfig.swapHTTAddress, part2);//jiaoyisuo合约底池地址



        initconfig.erc20Service.approve(initconfig.swapRouterAdd, finalIn);
        uint256[] memory amountOuts = initconfig.swapRouterService.getAmountsOut(finalIn, initconfig.getPath);
        uint256 amountOut = amountOuts[1];
        initconfig.swapRouterService.swapExactTokensForTokens(finalIn, amountOut, initconfig.getPath, address(this), deadline);
        
        orderMapping[orderNo] = finalIn;

        emit InMoney(orderNo,msg.sender,finalIn);
    }

    function getBalance(address tokenAddress) public view returns(uint){
        return Erc20Service(tokenAddress).balanceOf(address(this));
    }

    function withdraw(address to,uint256 num,address tokenAddress) public onlyOwner{
        Erc20Service(tokenAddress).transfer(to,num);
    }
    
    function setSwapHTTAddress(address changeAddress)  public onlyOwner{
        initconfig.swapHTTAddress = changeAddress;
    }

    function getInit() public view returns (addconfig memory){
        return initconfig;
    }


    function getOrderStatus(uint256 orderNo) public view returns (uint256){
        return orderMapping[orderNo];
    }

    event InMoney( uint256 indexed orderNo,address indexed from, uint256 indexed amount);

}

