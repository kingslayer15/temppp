// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "openzeppelin-contracts/access/Ownable.sol";

interface Erc20Service{
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function burn(uint256 amount)  external returns (bool);
}

contract Jiaoyisuo is Ownable{

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
        address httAdd;
        address[] getUsdtPath;
        address[] getHttPath;
        Erc20Service erc20Service;
        Erc20Service erc20HttService;
        address nodeRedAdd; // 节点分红地址
        address levelRedAdd; // 等级分红地址
        address htCPoolAdd; // HTC底池地址
    }

    address signAccount;

    addconfig initconfig;


    constructor(){
        _transferOwnership(msg.sender);
        signAccount = msg.sender;
        initconfig.usdtAdd = 0x2e092dc6eEA2fD92BDAEf3930FdD0e6d38455627;
        initconfig.httAdd = 0x79710a73623cb6f1b4A54EdF1C53a1a44576EB48;
        initconfig.getUsdtPath = [initconfig.httAdd,initconfig.usdtAdd];
        initconfig.getHttPath = [initconfig.usdtAdd,initconfig.httAdd];
        initconfig.erc20Service = Erc20Service(initconfig.usdtAdd);
        initconfig.erc20HttService = Erc20Service(initconfig.httAdd);
        initconfig.nodeRedAdd = 0x5c89C13b8a852c39d57DA8372fCe4Efa079f1dD8;// 节点分红地址
        initconfig.levelRedAdd = 0xe81C89976A67bB353243E2979A13524eEADc4CCD;// 等级分红地址
        initconfig.htCPoolAdd = 0x0DB0739dd90D9c5624efc62a487FB2040d1eD7bA;// HTC底池地址

        reduceInitConfig.timer = 1000*60*60;
        reduceInitConfig.reducePoint = 1;
        reduceInitConfig.divideNum = 100;
        reduceInitConfig.startTimer = block.timestamp*1000;
    }

    function init(address httAdd) public  onlyOwner{
        initconfig.httAdd = httAdd;
    }

    function swapHtt(uint256 orderNo,uint256 amountIn,uint256 amountOut,uint256 expireTimer,
        bytes32  r,bytes32  s,bytes1  v) public {

        require(orderMapping[orderNo]==0,"Exist Swap");
        uint256 nowTimer = block.timestamp*1000;
        require(expireTimer>nowTimer,"More Than Time");
        require(recoverSigner(genMsg(orderNo,amountOut,amountIn,expireTimer,msg.sender,address(this)),r,s,v) == signAccount,"Sign Not Pass");

        uint256 finalIn = (amountIn * 98) / reduceInitConfig.divideNum;
        uint256 part2 = (amountIn * 5) / 1000;


        amountOut = getAmountsOut(finalIn, initconfig.getHttPath);

        initconfig.erc20Service.transferFrom(msg.sender,address(this), finalIn);
        initconfig.erc20Service.transferFrom(msg.sender,address(this), part2);//jiaoyisuo合约底池地址
        initconfig.erc20Service.transferFrom(msg.sender,initconfig.nodeRedAdd, part2);// 节点分红地址
        initconfig.erc20Service.transferFrom(msg.sender,initconfig.levelRedAdd, part2);// 等级分红地址
        initconfig.erc20Service.transferFrom(msg.sender,initconfig.htCPoolAdd, part2); //HTC底池地址

        uint256 finalOut = (amountOut * 98) / reduceInitConfig.divideNum;
        uint256 burnNum = (amountOut * 2) / reduceInitConfig.divideNum;

        initconfig.erc20HttService.transfer(msg.sender, finalOut);

        initconfig.erc20HttService.burn(burnNum);
        orderMapping[orderNo] = amountOut;
        reduceSwap();
    }

    function swapHttAndBurn(uint256 amountIn) public returns (uint256){
        require(noNeedQuotaAddress[msg.sender]>0,"No Authority");
        uint256 amountOut = getAmountsOut(amountIn, initconfig.getHttPath);
        initconfig.erc20HttService.burn(amountOut);
        reduceSwap();
        return amountOut;
    }


    function swapUsdt(uint256 orderNo,uint256 amountIn,uint256 amountOut,uint256 expireTimer) public {

        require(orderMapping[orderNo]==0,"Exist Swap");
        uint256 nowTimer = block.timestamp*1000;
        require(expireTimer>nowTimer,"More Than Time");

        uint256 finalIn = (amountIn * 98) / reduceInitConfig.divideNum;
        uint256 burnNum = (amountIn * 2) / reduceInitConfig.divideNum;

        initconfig.erc20HttService.transferFrom(msg.sender,address(this), finalIn);
        initconfig.erc20HttService.burn(burnNum);

        amountOut = getAmountsOut(finalIn, initconfig.getUsdtPath);

        uint256 finalOut = (amountOut * 98) / reduceInitConfig.divideNum;
        uint256 part2 = (amountOut * 5) / 1000;



        initconfig.erc20Service.transfer(msg.sender, finalOut);
        initconfig.erc20Service.transfer(address(this), part2);//jiaoyisuo合约底池地址
        initconfig.erc20Service.transfer(initconfig.nodeRedAdd, part2);// 节点分红地址
        initconfig.erc20Service.transfer(initconfig.levelRedAdd, part2);// 等级分红地址
        //        initconfig.erc20Service.transfer(initconfig.httDevAdd, part2); //HTC底池地址

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


    function withdraw(address to,uint256 num,address tokenAddress) public onlyOwner{
        Erc20Service(tokenAddress).transfer(to,num);
    }

    function reduceSwap() public {
        uint256 nowTimer = block.timestamp*1000;
        uint256 expireTimer = reduceInitConfig.startTimer+reduceInitConfig.timer;
        if (expireTimer<nowTimer){
            uint256 httNum = initconfig.erc20HttService.balanceOf(address(this));
            uint256 burnNum = reduceInitConfig.reducePoint*httNum/reduceInitConfig.divideNum;
            initconfig.erc20HttService.burn(burnNum);
            reduceInitConfig.startTimer = nowTimer;
        }
    }


    function setReduceConfig(uint256 timer,uint256 reducePoint,uint256 divideNum) public onlyOwner{
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

    function setNoNeedQuotaAddress(address changeAddress)  public onlyOwner{
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