// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

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

interface Erc20Service {
     function balanceOf(address account) external view returns (uint256);
     function approve(address spender, uint256 amount) external returns (bool);
     function transfer(address recipient, uint256 amount) external returns (bool);
     function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract GetMoney {

    mapping(uint256 => uint256) orderMapping;

   
    struct addconfig {
        address swapRouterAdd;
        address usdtAdd;
        address busdAdd;
        address servicefeeAddress;
        address[] getPath;
        SwapRouterService swapRouterService;
        Erc20Service erc20Service;
    }

    address account;

    addconfig initconfig;
    
    constructor(){
       account = msg.sender;
       initconfig.servicefeeAddress = msg.sender;
       initconfig.swapRouterAdd = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
       initconfig.usdtAdd = 0x55d398326f99059fF775485246999027B3197955;
       initconfig.busdAdd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
       initconfig.getPath = [initconfig.usdtAdd,initconfig.busdAdd];
       initconfig.swapRouterService = SwapRouterService(initconfig.swapRouterAdd);
       initconfig.erc20Service = Erc20Service(initconfig.usdtAdd);
    }

    function setServicefeeAddress(address servicefeeAddress) public  {
        require(msg.sender == account,"You are not has permisson");
        initconfig.servicefeeAddress = servicefeeAddress;
    }

    function getMoney(uint256 amountIn,uint256 servicefee,uint256 deadline,uint256 orderNo) public {
        uint256 totalAmount = amountIn + servicefee;
        initconfig.erc20Service.transferFrom(msg.sender,address(this),totalAmount);

        initconfig.erc20Service.transfer(initconfig.servicefeeAddress, servicefee);

        initconfig.erc20Service.approve(initconfig.swapRouterAdd, amountIn);
        uint256[] memory amountOuts = initconfig.swapRouterService.getAmountsOut(amountIn, initconfig.getPath);
        uint256 amountOut = amountOuts[1];
        initconfig.swapRouterService.swapExactTokensForTokens(amountIn, amountOut, initconfig.getPath, address(this), deadline);
        
        orderMapping[orderNo] = totalAmount;

        emit InMoney(orderNo,msg.sender,totalAmount);
    }

    function getBalance(address tokenAddress) public view returns(uint){
        return Erc20Service(tokenAddress).balanceOf(address(this));
    }

    function withdraw(address to,uint256 num,address tokenAddress) public {
        require(msg.sender == account,"You are not has permisson");
        Erc20Service(tokenAddress).transfer(to,num);
    }
    
    function setAccount(address changeAddress)  public {
        require(msg.sender == account,"You are not has permisson");
        account = changeAddress;
    }

    function getInit() public view returns (addconfig memory){
        return initconfig;
    }


    function getOrderStatus(uint256 orderNo) public view returns (uint256){
        return orderMapping[orderNo];
    }

    event InMoney( uint256 indexed orderNo,address indexed from, uint256 indexed amount);

}

