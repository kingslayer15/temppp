// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "openzeppelin-contracts/access/Ownable.sol";

interface SwapRouterService {
     function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface Erc20Service {
     function balanceOf(address account) external view returns (uint256);
     function approve(address spender, uint256 amount) external returns (bool);
     function transfer(address recipient, uint256 amount) external returns (bool);
     function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface SwapService {
     function swapHttAndBurn(uint256 amountIn) external returns (uint256);
}

contract Chujinpro is Ownable{

    mapping(uint256 => uint256) orderMapping;

   
    struct addconfig {
        address swapRouterAdd;
        address usdtAdd;
        address busdAdd;
        address swapAdd;
        address[] getPath;
        SwapRouterService swapRouterService;
        Erc20Service erc20Service;
        Erc20Service erc20BusdService;
        SwapService swapService;
    }

    address signAccount;

    addconfig initconfig;
    
    constructor(){
       signAccount = msg.sender;
       initconfig.swapRouterAdd = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
       initconfig.usdtAdd = 0x55d398326f99059fF775485246999027B3197955;
       initconfig.busdAdd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
       initconfig.swapAdd = 0x2aeC015b728513703A15CF647fa5feFBEc0D2dBC;
       initconfig.getPath = [initconfig.busdAdd,initconfig.usdtAdd];
       initconfig.swapRouterService = SwapRouterService(initconfig.swapRouterAdd);
       initconfig.erc20Service = Erc20Service(initconfig.usdtAdd);
       initconfig.erc20BusdService = Erc20Service(initconfig.busdAdd);
       initconfig.swapService = SwapService(initconfig.swapAdd);
    }

    function setSwapAdd(address changeSwapAdd) public  onlyOwner{
        initconfig.swapAdd = changeSwapAdd;
    }

    function giveMoney(uint256 orderNo,uint256 amountOut,uint256 servicefee,uint256 expireTimer,uint256 deadline,
    bytes32  r,bytes32  s,bytes1  v) public onlyOwner{

        uint256 totalAmount = amountOut + servicefee;

        require(orderMapping[orderNo]==0,"Exist Cash Out");
        uint256 nowTimer = block.timestamp*1000;
        require(expireTimer>nowTimer,"More Than Time");
        require(recoverSigner(genMsg(orderNo,amountOut,servicefee,expireTimer,msg.sender,address(this)),r,s,v) == signAccount,"Sign Not Pass");

        uint256[] memory amountIns = initconfig.swapRouterService.getAmountsIn(totalAmount, initconfig.getPath);
        uint256 amountIn = amountIns[0];
        initconfig.erc20BusdService.approve(initconfig.swapRouterAdd, amountIn);

        initconfig.swapRouterService.swapExactTokensForTokens(amountIn, totalAmount, initconfig.getPath, address(this), deadline);
        
        initconfig.erc20Service.transfer(msg.sender, amountOut);

        if (servicefee >0){
            initconfig.erc20Service.transfer(initconfig.swapAdd, servicefee);
            initconfig.swapService.swapHttAndBurn(servicefee);
        }
        orderMapping[orderNo] = totalAmount;
        
        emit CashOut(orderNo, msg.sender, totalAmount);
    }

    function getBalance(address tokenAddress) public view returns(uint){
        return Erc20Service(tokenAddress).balanceOf(address(this));
    }

    function withdraw(address to,uint256 num,address tokenAddress) public onlyOwner{
        Erc20Service(tokenAddress).transfer(to,num);
    }

    function setSignAccount(address changeAddress)  public onlyOwner{
        require(msg.sender == signAccount,"You are not has permisson");
        signAccount = changeAddress;
    }


    function getOrderStatus(uint256 orderNo) public view returns (uint256){
        return orderMapping[orderNo];
    }

    function closeOrder(uint256 orderNo) public onlyOwner{
        orderMapping[orderNo] = 1;
    }


    function genMsg(
        uint256 orderNo,
        uint256 amountOut,uint256 servicefee,uint256 expireTimer,
        address _address,
        address contractAddress
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(orderNo, amountOut,servicefee,expireTimer,_address,contractAddress));
    }

   

    function recoverSigner(bytes32 message, bytes32  r,
        bytes32  s,
        bytes1  v)
        internal
        pure
        returns (address)
    {
        uint8 vu =uint8(v[0])*(2**(8*(0)));
        return ecrecover(message, vu, r, s);
    }

    event CashOut( uint256 indexed orderNo,address indexed from, uint256 indexed amount);

}