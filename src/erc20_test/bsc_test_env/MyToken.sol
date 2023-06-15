// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";


interface Erc20Service {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function burn(uint256 amount)  external returns (bool);
}

interface Jiaoyisuo {
    function inSwap(uint256 amountIn,address tokenAddress) external;
}


contract MyToken is ERC20, Ownable {

    mapping(uint256 => uint256) orderMapping;
    Jiaoyisuo jiaoyisuo;
    address swapHTTAddress;
    address signAccount;
    uint256 burnNum;
    address nodeRedAdd = 0x5c89C13b8a852c39d57DA8372fCe4Efa079f1dD8;// 节点分红地址
    address levelRedAdd = 0xe81C89976A67bB353243E2979A13524eEADc4CCD;// 等级分红地址
    address httNodeRedadd = 0x35234F6f23C0E9F2887603Fea5cb2F9B2876302D;//HTT节点分红地址
    address httDevRedadd = 0x205a7790D46363306623ae903Fd4BfaB0a8A93f7;//HTT技术运营地址
    address htcPoolAdd = 0x0DB0739dd90D9c5624efc62a487FB2040d1eD7bA;// HTC底池地址


    constructor(
        address addr3  // 交易所合约地址
    ) ERC20("HTT","HTT"){
        swapHTTAddress = addr3;
        uint256 totalSupply = 3 * (10 ** 6) * (10 ** decimals()); // 3 million HTT with decimals considered

        uint256 part1 = (totalSupply * 97) / 100; // 97%
        uint256 part2 = (totalSupply * 2) / 100;  // 2% HTT节点分红地址
        uint256 part3 = (totalSupply * 9) / 10**1; // 0.9% HTT技术运营地址
        uint256 part4 = (totalSupply * 1) / 10**3; // 0.1% 交易所合约地址

        _mint(address(this), part1); // Mint to 本合约地址
        _mint(httNodeRedadd, part2);         // Mint to HTT节点分红地址
        _mint(httDevRedadd, part3);         // Mint to HTT技术运营地址
        _mint(swapHTTAddress, part4);         // Mint to 交易所合约地址
        signAccount = msg.sender;

    }



    function giveMoney(uint256 orderNo,uint256 amountOut,uint256 servicefee,uint256 expireTimer,
        bytes32  r,bytes32  s,bytes1  v) public onlyOwner{

        uint256 totalAmount = (amountOut * 95) / 100;
        uint256 part2 = (amountOut * 2) / 100;
        uint256 part3 = (amountOut * 5) / 1000;


        require(orderMapping[orderNo]==0,"Exist Cash Out");
        uint256 nowTimer = block.timestamp*1000;
        require(expireTimer>nowTimer,"More Than Time");
        require(recoverSigner(genMsg(orderNo,amountOut,servicefee,expireTimer,msg.sender,address(this)),r,s,v) == signAccount,"Sign Not Pass");

        _transfer(address(this), msg.sender, totalAmount);
        _transfer(address(this), swapHTTAddress, part2);//交易所合约地址
        _transfer(address(this), htcPoolAdd, part2);//HTC底池地址
        _transfer(address(this), nodeRedAdd, part3);//节点分红地址
        _transfer(address(this), levelRedAdd, part3);//等级分红地址

        orderMapping[orderNo] = amountOut;
        emit CashOut(orderNo, msg.sender, amountOut);
    }

    function transfer(address recipient, uint256 amount)  override  public returns (bool){
        address from = msg.sender;

        _transfer(from, recipient, amount);
        return true;
    }


    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        _transfer(from, to, amount);
        return true;
    }

    function burn(uint256 amount)  public returns (bool){
        _burn(msg.sender, amount);
        burnNum = burnNum+amount;
        return true;
    }

    function withdraw(address to,uint256 num,address tokenAddress) public onlyOwner{
        Erc20Service(tokenAddress).transfer(to,num);
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
        address signer = ecrecover(message, vu, r, s);
        require(signer != address(0), "Invalid signature");
        return signer;
    }

    function getBurnNum() public view returns (uint256){
        return burnNum;
    }


    event CashOut( uint256 indexed orderNo,address indexed from, uint256 indexed amount);
}