// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


interface Erc20Service {
     function balanceOf(address account) external view returns (uint256);
     function approve(address spender, uint256 amount) external returns (bool);
     function transfer(address recipient, uint256 amount) external returns (bool);
     function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
     function burn(uint256 amount)  external returns (bool);
     function transferFromReturnAmount(address from,address to,uint256 amount)   
     external returns (uint256);
}

contract SwapFcrUsdt {

    mapping(uint256 => uint256) orderMapping;
    mapping(address => uint256) noNeedQuotaAddress;

    struct reduceConfig{
       uint256 timer;
       uint256 reducePoint;
       uint256 divideNum;
       uint256 startTimer;
    }
    reduceConfig reduceInitConfig;
   
    struct addconfig {
        address usdtAdd;
        address fcrAdd;
        address[] getUsdtPath;
        address[] getFcrPath;
        Erc20Service erc20Service;
        Erc20Service erc20FcrService;
    }

    address account;
    address signAccount;

    addconfig initconfig;
    
    constructor(){
       account = msg.sender;
       signAccount = msg.sender;
       initconfig.usdtAdd = 0x55d398326f99059fF775485246999027B3197955;
       initconfig.fcrAdd = 0xdfc73427256B0e13A200F643C1eddD4A8508E0eC;
       initconfig.getUsdtPath = [initconfig.fcrAdd,initconfig.usdtAdd];
       initconfig.getFcrPath = [initconfig.usdtAdd,initconfig.fcrAdd];
       initconfig.erc20Service = Erc20Service(initconfig.usdtAdd);
       initconfig.erc20FcrService = Erc20Service(initconfig.fcrAdd);

       reduceInitConfig.timer = 1000*60*60;
       reduceInitConfig.reducePoint = 1;
       reduceInitConfig.divideNum = 100;
       reduceInitConfig.startTimer = block.timestamp*1000;
    }

    function init(address fcrAdd) public  {
        require(msg.sender == account,"You are not has permisson");
        initconfig.fcrAdd = fcrAdd;
    }

    function swapFcr(uint256 orderNo,uint256 amountIn,uint256 amountOut,uint256 expireTimer,
    bytes32  r,bytes32  s,bytes1  v) public {

        require(orderMapping[orderNo]==0,"Exist Swap");
        uint256 nowTimer = block.timestamp*1000;
        require(expireTimer>nowTimer,"More Than Time");
        require(recoverSigner(genMsg(orderNo,amountOut,amountIn,expireTimer,msg.sender,address(this)),r,s,v) == signAccount,"Sign Not Pass");
        amountOut = getAmountsOut(amountIn, initconfig.getFcrPath);

        initconfig.erc20Service.transferFrom(msg.sender,address(this), amountIn);
        
        initconfig.erc20FcrService.transfer(msg.sender, amountOut);
        orderMapping[orderNo] = amountOut;
        reduceSwap();
    }

    function swapFcrAndBurn(uint256 amountIn) public returns (uint256){
        require(noNeedQuotaAddress[msg.sender]>0,"No Authority");
        uint256 amountOut = getAmountsOut(amountIn, initconfig.getFcrPath);
        initconfig.erc20FcrService.burn(amountOut);
        reduceSwap();
        return amountOut;
    }

    function swapUsdt(uint256 orderNo,uint256 amountIn,uint256 amountOut,uint256 expireTimer) public {

        require(orderMapping[orderNo]==0,"Exist Swap");
        uint256 nowTimer = block.timestamp*1000;
        require(expireTimer>nowTimer,"More Than Time");
        uint256 realAmountIn = initconfig.erc20FcrService.transferFromReturnAmount(msg.sender,address(this), amountIn);

        amountOut = getAmountsOut(realAmountIn, initconfig.getUsdtPath);

        initconfig.erc20Service.transfer(msg.sender, amountOut);

        orderMapping[orderNo] = amountOut;
        reduceSwap();
    }

    function inSwap(uint256 amountIn,address tokenAddress) public {
        Erc20Service(tokenAddress).transferFrom(msg.sender,address(this), amountIn);
    }

    function inTrimSwap(uint256 amountInA,uint256 amountInB,address tokenA,address tokenB) public {
        Erc20Service(tokenA).transferFrom(msg.sender,address(this), amountInA);
        Erc20Service(tokenB).transferFrom(msg.sender,address(this), amountInB);
    }

    function getBalance(address tokenAddress) public view returns(uint){
        return Erc20Service(tokenAddress).balanceOf(address(this));
    }

    function setSignAccount(address changeAddress)  public {
        require(msg.sender == signAccount,"You are not has permisson");
        signAccount = changeAddress;
    }

    function setAccount(address changeAddress)  public {
        require(msg.sender == account,"You are not has permisson");
        account = changeAddress;
    }

    function withdraw(address to,uint256 num,address tokenAddress) public {
        require(msg.sender == account,"You are not has permisson");
        Erc20Service(tokenAddress).transfer(to,num);
    }

    function reduceSwap() public {
        uint256 nowTimer = block.timestamp*1000;
        uint256 expireTimer = reduceInitConfig.startTimer+reduceInitConfig.timer;
        if (expireTimer<nowTimer){
            uint256 fcrNum = Erc20Service(initconfig.fcrAdd).balanceOf(address(this));
            uint256 burnNum = reduceInitConfig.reducePoint*fcrNum/reduceInitConfig.divideNum;
            Erc20Service(initconfig.fcrAdd).burn(burnNum);
            reduceInitConfig.startTimer = nowTimer;
        }
    }


    function setReduceConfig(uint256 timer,uint256 reducePoint,uint256 divideNum) public {
        require(msg.sender == account,"You are not has permisson");
        reduceInitConfig.timer = timer;
        reduceInitConfig.reducePoint = reducePoint;
        reduceInitConfig.divideNum = divideNum;
    }

    function getCanReduce() public  view returns (uint256){
        uint256 nowTimer = block.timestamp*1000;
        uint256 expireTimer = reduceInitConfig.startTimer+reduceInitConfig.timer;
        if (expireTimer<nowTimer){
            return 1;
        }
        return 0;
    }


    function getOrderStatus(uint256 orderNo) public view returns (uint256){
        return orderMapping[orderNo];
    }

    function genMsg(
        uint256 orderNo,
        uint256 amountOut,uint256 amountIn,uint256 expireTimer,
        address _address,
        address contractAddress
    ) internal  pure returns (bytes32) {
        return keccak256(abi.encodePacked(orderNo, amountOut,amountIn,expireTimer,_address,contractAddress));
    }

    function getAmountsOut(uint256 amountIn, address[] memory path) internal view returns (uint256) {
        require(path.length >= 2, 'PancakeLibrary: INVALID_PATH');
        address tokenA = path[0];
        address tokenB = path[1];
        uint256 tokenANum =  Erc20Service(tokenA).balanceOf(address(this));
        if (tokenANum==0){
            return 0;
        }
        uint256 tokenBNum =  Erc20Service(tokenB).balanceOf(address(this));
        if (tokenBNum==0){
            return 0;
        }
        uint256 k = tokenANum * tokenBNum;
        tokenANum = tokenANum+amountIn;
        tokenBNum = tokenBNum - k / tokenANum;
        return tokenBNum;
    }

    function getAmountsIn(uint256 amountOut, address[] memory path) internal view returns (uint256) {
        require(path.length >= 2, 'PancakeLibrary: INVALID_PATH');
        address tokenA = path[0];
        address tokenB = path[1];
        uint256 tokenANum =  Erc20Service(tokenA).balanceOf(address(this));
        if (tokenANum==0){
            return 0;
        }
        uint256 tokenBNum =  Erc20Service(tokenB).balanceOf(address(this));
        if (tokenBNum==0){
            return 0;
        }
        uint256 k = tokenANum * tokenBNum;
        tokenBNum = tokenBNum-amountOut;
        tokenANum = k / tokenBNum - tokenANum;
        return tokenANum;
    }

    function setNoNeedQuotaAddress(address changeAddress)  public {
        require(msg.sender == account,"You are not has permisson");
        noNeedQuotaAddress[changeAddress] = 1;
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
}