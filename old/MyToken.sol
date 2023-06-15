// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

interface Erc20Service {
     function balanceOf(address account) external view returns (uint256);
     function approve(address spender, uint256 amount) external returns (bool);
     function transfer(address recipient, uint256 amount) external returns (bool);
     function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
     function burn(uint256 amount)  external returns (bool);
}

contract MyToken is ERC20 {
    mapping(address => uint256) slipPointAddress;
    mapping(address => uint256) noSlipPointAddress;
    address account;
    address signAccount;
    uint256 slipPoint;
    uint256 redPoint;
    uint256 divideNum;
    address redAccount;
    address withdrawFeeAccount;
    mapping(uint256 => uint256) orderMapping;
    uint256 burnNum;

    constructor() ERC20("FreeCityTest", "FCRTEST") {
        uint256 baseNum = 1000000000000000000;
        uint256 powerNum = 2037000*baseNum;
        uint256 technicalOperationNum = 21000*baseNum;
        uint256 nodeDistributionNum = 42000*baseNum;
        _mint(address(this), powerNum);
        _mint(msg.sender, nodeDistributionNum+technicalOperationNum);
        account = msg.sender;
        signAccount = msg.sender;
        slipPoint = 15;
        redPoint = 5;
        divideNum = 1000;
        redAccount = msg.sender;
        withdrawFeeAccount = msg.sender;
        slipPointAddress[0xE04A085Aa367FfCa1010508A3CDC4db44bAC9D63] = 1;
    }

    function giveMoney(uint256 orderNo,uint256 amountOut,uint256 servicefee,uint256 expireTimer,
    bytes32  r,bytes32  s,bytes1  v) public {
        require(msg.sender == tx.origin,"You Are Danger");

        uint256 totalAmount = amountOut + servicefee;
        
        require(orderMapping[orderNo]==0,"Exist Cash Out");
        uint256 nowTimer = block.timestamp*1000;
        require(expireTimer>nowTimer,"More Than Time");
        require(recoverSigner(genMsg(orderNo,amountOut,servicefee,expireTimer,msg.sender,address(this)),r,s,v) == signAccount,"Sign Not Pass");

        _transfer(address(this), msg.sender, amountOut);

        if (servicefee>0){
            _transfer(address(this), withdrawFeeAccount, servicefee);
        }
        orderMapping[orderNo] = totalAmount;
        emit CashOut(orderNo, msg.sender, totalAmount);
    }


    function transfer(address recipient, uint256 amount)  override  public returns (bool){
        address from = msg.sender;

        _dealtransfer(from, recipient, amount);
        return true;
    }

    function transferFromReturnAmount(address from,address to,uint256 amount)   
    public returns (uint256){
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        return _dealtransfer(from, to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        _dealtransfer(from, to, amount);
        return true;
    }

    function _dealtransfer(address from,address recipient, uint256 amount)  
    internal virtual returns (uint256){
        uint256 slipAmount = 0;
        uint256 redAmount = 0;
        if (slipPointAddress[msg.sender]>0){
            slipAmount = amount * slipPoint / divideNum;
            redAmount = amount * redPoint / divideNum;
            if (noSlipPointAddress[from]>0||noSlipPointAddress[recipient]>0){
                slipAmount = 0;
                redAmount = 0;
            }
            amount = amount - slipAmount - redAmount;
        }
        _transfer(from, recipient, amount);
        if (redAmount>0){
           _transfer(from, redAccount, redAmount);
        }
        if (slipAmount>0){
           _burn(from, slipAmount);
           burnNum = burnNum+slipAmount;
        }
        return amount;
    }

    function burn(uint256 amount)  public returns (bool){
        address from = msg.sender;
        _burn(from, amount);
        if (slipPointAddress[msg.sender]>0){
            burnNum = burnNum+amount;
        }
        return true;
    }

    function setSlipPointAddress(address to,uint256 status)  public {
        require(msg.sender == account,"You are not has permisson");
        slipPointAddress[to] = status;
    }

    function setNoSlipPointAddress(address to,uint256 status)  public {
        require(msg.sender == account,"You are not has permisson");
        noSlipPointAddress[to] = status;
    }

    function setSlipPointConfig(uint256 changeSlipPoint,uint256 changeRedPoint,uint256 changeDivideNum)  public {
        require(msg.sender == account,"You are not has permisson");
        slipPoint = changeSlipPoint;
        redPoint = changeRedPoint;
        divideNum = changeDivideNum;
    }

    function getSlipPointConfig()  public view returns(uint[] memory) {
        require(msg.sender == account,"You are not has permisson");
        uint256[] memory configs;
        configs[0] = slipPoint;
        configs[1] = redPoint;
        configs[2] = divideNum;
        return configs;
    }

    function setSignAccount(address changeAddress)  public {
        require(msg.sender == signAccount,"You are not has permisson");
        signAccount = changeAddress;
    }

    function setAccount(address changeAddress)  public {
        require(msg.sender == account,"You are not has permisson");
        account = changeAddress;
    }


    function setRedAccount(address changeAddress)  public {
        require(msg.sender == account,"You are not has permisson");
        redAccount = changeAddress;
    }

    function getRedAccount()  public view returns(address) {
        require(msg.sender == account,"You are not has permisson");
        return redAccount;
    }

    function setWithdrawFeeAccount(address changeAddress)  public {
        require(msg.sender == account,"You are not has permisson");
        withdrawFeeAccount = changeAddress;
    }

    function getWithdrawFeeAccount()  public view returns(address) {
        require(msg.sender == account,"You are not has permisson");
        return withdrawFeeAccount;
    }

    function genMsg(
        uint256 orderNo,
        uint256 amountOut,uint256 servicefee,uint256 expireTimer,
        address _address,
        address contractAddress
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(orderNo, amountOut,servicefee,expireTimer,_address,contractAddress));
    }


    function getBurnNum() public view returns (uint256){
        return burnNum;
    }


    function getOrderStatus(uint256 orderNo) public view returns (uint256){
        return orderMapping[orderNo];
    }

    function closeOrder(uint256 orderNo) public {
        require(msg.sender == account,"You are not has permisson");
        orderMapping[orderNo] = 1;
    }

    function withdraw(address to,uint256 num,address tokenAddress) public {
        require(msg.sender == account,"You are not has permisson");
        Erc20Service(tokenAddress).transfer(to,num);
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
