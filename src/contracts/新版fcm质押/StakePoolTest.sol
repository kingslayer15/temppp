// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";

contract StakePoolTest is AccessControlEnumerableUpgradeable{

    event Deposit(address indexed account, uint8 pool, uint256[] _ids);
    event Withdraw(address indexed account, uint256[] _ids);
    event Reward(address indexed account,uint256 receiveAmount);

    struct Pool{
        bool opened; //是否开启
        uint256 depth; //池子容量
        uint256 fill; //现有数量
        uint256 rate; //领取比例 ‱
        string name; //池子名称
    }

    struct Item{
        uint256 balances; //余额
        uint256[] ids; //质押的tokenId
        uint256 updateTime; //上次结算时间
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant PERIOD_SECOND = 60; //一天
    uint256 public constant MATCH_MOD = 1e4;

    address public fcc;
    address public fcm;
    address public fccPool; //支出fcc的池子
    uint256 public unlockTime; //解冻时间
    uint256 public fcmValue; //fcm价值
    uint256 public firstRewardRate; //首日释放比例
    uint256 public rewardPeriod; //线性解锁周期

    Pool[] private poolInfo;
    mapping(uint256 => bool) public isStaking;
    mapping(address => mapping(uint8 => Item)) private items; //用户 => (池子 => 账本)
    mapping(uint256 => uint8) private tokenToPool; //tokenId => 质押的池子编号
    mapping(uint256 => uint256) private tokenToIndex; //tokenId => item.ids 的下标
    mapping(address => uint256) public receivedAmount; //用户已领奖励

    function initialize() public initializer{
        _stakePool_init_role();
        _stakePool_init_config();
        fcc = 0xF8a66aA059Db1faE59321cccBb0f000238fa18d5;
        fcm = 0x581B2C66362677EB8765fB103230351A1E437d08;
        fccPool = 0x4E22Eba6da868a8756de534CE10A56D68De43998;
        unlockTime = 99999999999;
        fcmValue = 1560 * 1e18;
        firstRewardRate = 1;
        rewardPeriod = 365;
    }
    
    function _stakePool_init_role() internal onlyInitializing{
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    function _stakePool_init_config() internal onlyInitializing {
        poolInfo.push(Pool(true, 20, 0, 7200, "Diamond Pool")); 
        poolInfo.push(Pool(false, 100, 0, 5600, "Gold Pool")); 
        poolInfo.push(Pool(false, 300, 0, 4200, "Silver Pool")); 
        poolInfo.push(Pool(false, 500, 0, 3000, "Bronze Pool")); 
    }

    function deposit(uint8 _pool, uint256[] calldata _ids) external existPool(_pool){
        Pool memory pool = poolInfo[_pool];
        require(block.timestamp < unlockTime, "Pool: activity has ended.");
        require(pool.fill + _ids.length <= pool.depth, "Pool: out of pool depth.");
        require(pool.opened, "Pool: The pool is closed.");

        address sender = _msgSender(); 
        _updateItem(sender, _pool);
        IERC721 fcmNft = IERC721(fcm);
        for(uint256 i = 0; i < _ids.length; i++){
            uint256 tokenId = _ids[i];
            // require(fcmNft.ownerOf(tokenId) == sender,"Pool: your are not the owner of the token.");
            require(!isStaking[tokenId], "Pool: token is being staked.");
            isStaking[tokenId] = true;
            items[sender][_pool].ids.push(tokenId);
            tokenToPool[tokenId] = _pool;
            tokenToIndex[tokenId] = items[sender][_pool].ids.length - 1;
        }
        poolInfo[_pool].fill += _ids.length;
        
        //如果本池子已满, 开启下一个池子
        if(pool.fill + _ids.length == pool.depth){
            poolInfo[_pool].opened = false;
            if(poolInfo.length - 1 > _pool){
                poolInfo[_pool + 1].opened = true;
            }
        }

        emit Deposit(sender, _pool, _ids);
    }

    /**
     * 解除质押
     */
    function withdraw(uint256[] calldata _ids) external {
        address account = _msgSender();
        require(block.timestamp >= unlockTime, "Pool: the unlocking time is not up.");

        //更新item
        for(uint8 i = 0; i < poolInfo.length; i++){
            _updateItem(account, i);
        }

        //解锁token
        IERC721 fcmNft = IERC721(fcm);
        for(uint256 i = 0; i < _ids.length; i++){
            uint256 tokenId = _ids[i];
            require(isStaking[tokenId], "Pool: token is not staking.");
            // require(fcmNft.ownerOf(tokenId) == account,"Pool: your are not the owner of the token.");
            uint8 pool = tokenToPool[tokenId];
            isStaking[_ids[i]] = false;
            uint256[] memory ids = items[account][pool].ids;
            items[account][pool].ids[tokenToIndex[tokenId]] = ids[ids.length - 1];
            tokenToIndex[ids[ids.length - 1]] = tokenToIndex[tokenId];
            items[account][pool].ids.pop();
            poolInfo[pool].fill -= 1;
        }
        

        emit Withdraw(account, _ids);
    }

    /**
     * 领取收益
     */
    function reward(uint256 _amount) external {
        address account = _msgSender();
        require(block.timestamp >= unlockTime, "Pool: the unlocking time is not up.");
        uint256 all = _awardAmount(account);
        require(all > receivedAmount[account], "Pool: no award.");
        require(all - receivedAmount[account] >= _amount, "Pool: insufficient award.");
        
        IERC20 fccToken = IERC20(fcc);
        receivedAmount[account] += _amount;
        fccToken.transferFrom(fccPool, account, _amount);

        emit Reward(account, _amount);
    }

    /**
     * 计算总收益
     */
    function _awardAmount(address _account) internal view returns(uint256){
        uint256 amount = 0;
        uint256 all = 0;
        if(block.timestamp < unlockTime){
            return amount;
        }
        for(uint8 i = 0; i < poolInfo.length; i++){
            Item memory item = items[_account][i];
            if(item.updateTime == 0){
                continue;
            }
            uint256 poolAmount = _balances(item, i);
            all += poolAmount;
            amount += poolAmount * firstRewardRate / 100; //首日收益
            uint256 spendTime = block.timestamp - unlockTime;
            if(spendTime >= PERIOD_SECOND){
                amount += (spendTime / PERIOD_SECOND) * ((poolAmount - (poolAmount * firstRewardRate/100)) / rewardPeriod);
            }
        }

        return amount > all ? all : amount;
    }

    /**
     * 用户余额
     */
    function _balances(Item memory _item, uint8 _pool) internal view returns(uint256){
        uint256 endTime = block.timestamp < unlockTime ? block.timestamp : unlockTime;
        uint256 updateTime = _item.updateTime;
        if(updateTime == 0){
            _item.updateTime = endTime;
            return _item.balances;
        }
        if (
            _item.ids.length == 0 
            || updateTime == endTime
        ) {
            return _item.balances;
        }
        //秒收益
        uint256 perSecond = fcmValue / (365 * PERIOD_SECOND);
        //收益 = fcm数量 * 秒数 * 秒收益 * 年收益率
        uint256 amount = _item.ids.length  * (endTime - updateTime) * perSecond * poolInfo[_pool].rate;
        return _item.balances += amount / MATCH_MOD; 

    }

    /**
     * 更新用户收益
     */
    function _updateItem(address _account, uint8 _pool) internal {
        uint256 endTime = block.timestamp < unlockTime ? block.timestamp : unlockTime;
        uint256 updateTime = items[_account][_pool].updateTime;
        if(updateTime == 0){
            items[_account][_pool].updateTime = endTime;
            return;
        }
        if (
            items[_account][_pool].ids.length == 0 
            || updateTime == endTime
        ) {
            return;
        }
        //秒收益
        uint256 perSecond = fcmValue / (365 * PERIOD_SECOND);
        //收益 = fcm数量 * 秒数 * 秒收益 * 年收益率
        uint256 amount = items[_account][_pool].ids.length  * (endTime - updateTime) * perSecond * poolInfo[_pool].rate;
        items[_account][_pool].updateTime = endTime;
        items[_account][_pool].balances += amount / MATCH_MOD; 
    }


    /**
     * 查询可领收益
     */
    function canReward(address _account) external view returns(uint256){
        return _awardAmount(_account) - receivedAmount[_account];
    }

    /**
     * 查询所有池子累计收益
     */
    function getAllAward(address _account) external view returns(uint256[] memory){
        uint256[] memory balancesList = new uint256[](poolInfo.length);
        for(uint8 i = 0; i < poolInfo.length; i++){
            balancesList[i] = _balances(items[_account][i], i);
        }
        return balancesList;
    }

    /**
     * 查询所有池子信息
     */
    function allPoolInfo() external view returns(Pool[] memory){
        Pool[] memory result = new Pool[](poolInfo.length);
        for(uint8 i = 0; i < poolInfo.length; i++){
            result[i] = poolInfo[i];
        }
        return result;
    }
    
    /**
     * 查询Item
     */
    function getItems(address _account) external view returns(Item[] memory){
        Item[] memory list = new Item[](poolInfo.length);
        for(uint8 i = 0; i < poolInfo.length; i++){
            list[i] = items[_account][i];
        }
        return list;
    }

    /**
     * 批量查询token是否在质押中
     */
    function isStakingBatch(uint256[] calldata _ids) external view returns(bool[] memory){
        bool[] memory result = new bool[](_ids.length);
        for(uint256 i = 0; i < _ids.length; i++){
            result[i] = isStaking[_ids[i]];
        }
        return result;
    }



    //admin
    function setUnlockTime(uint256 _time) external onlyRole(OPERATOR_ROLE){
        unlockTime = _time;
    }

    function setFcc(address _newFcc) external onlyRole(OPERATOR_ROLE){
        fcc = _newFcc;
    }

    function setFcm(address _newFcm) external onlyRole(OPERATOR_ROLE){
        fcm = _newFcm;
    }

    function setFccPool(address _newFccPool) external onlyRole(OPERATOR_ROLE){
        fccPool = _newFccPool;
    }

    function setFcmValue(uint256 _newFcmValue) external onlyRole(OPERATOR_ROLE){
        fcmValue = _newFcmValue;
    }

    function setFirstRewardRate(uint256 _newFirstRewardRate) external onlyRole(OPERATOR_ROLE){
        firstRewardRate = _newFirstRewardRate;
    }

    function setRewardPeriod(uint256 _newRewardPeriod) external onlyRole(OPERATOR_ROLE){
        rewardPeriod = _newRewardPeriod;
    }

    /**
     * 设置池子参数
     * 注：当池子已有质押时，不建议使用，会使只有没调用过 _updateItme() 函数结算的收益按新的参数计算，已结算的收益不会改变
     */
    function setPoolConfig(uint8 _pool, uint256 _depth, uint256 _rate) external onlyRole(OPERATOR_ROLE){
        poolInfo[_pool].depth = _depth;
        poolInfo[_pool].rate = _rate;
    }
    
    modifier existPool(uint8 _pool){
        require(_pool >= 0 && _pool < poolInfo.length, "Pool: pool is not exist.");
        _;
    }


    //test
    function blockTime() external view returns(uint256){
        return block.timestamp;
    }



}
