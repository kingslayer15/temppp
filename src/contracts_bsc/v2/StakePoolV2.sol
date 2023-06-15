// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";

contract StakePoolV2 is AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable{

    event Deposit(address indexed account, uint8 pool, uint256[] _ids, uint256 startTime, uint256 withdrawTime);
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

    struct Stake{
        uint8 poolId;
        uint256 tokenId;
        uint256 timestamp;
        address owner;
        uint256 withdrawTime;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant PERIOD_SECOND = 86400; //一天86400
    uint256 public constant MATCH_MOD = 1e4;

    address public fcc;
    address public fcm;
    address public fccPool; //支出fcc的池子
    uint256 public unlockTime; //解冻时间
    uint256 public fcmValue; //fcm价值
    uint256 public firstRewardRate; //首日释放比例
    uint256 public rewardPeriod; //线性解锁周期
    uint256 public minStakeTime;    //最小质押时间
    bool public openStake;

    Pool[] private poolInfo;
    mapping(address => mapping(uint8 => Item)) private items; //用户 => (池子 => 账本)
    mapping(uint256 => Stake) private vault;        //token => 质押信息
    mapping(uint256 => uint256) private tokenToIndex; //tokenId => item.ids 的下标
    mapping(address => uint256) public receivedAmount; //用户已领奖励

    function initialize() public initializer{
        _stakePool_init_role();
        _stakePool_init_config();
        fcm = 0xae2a446987443f8b3BEce157F9FdB2AD549B4D8C;
        unlockTime = 99999999999;
        fcmValue = 1560 * 1e18;
        firstRewardRate = 1;
        rewardPeriod = 365;
        minStakeTime = 2592000; //30天
        openStake = false;
    }

    function _stakePool_init_role() internal onlyInitializing{
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    function _stakePool_init_config() internal onlyInitializing {
        poolInfo.push(Pool(true, 500, 0, 7200, "Diamond Pool")); 
        poolInfo.push(Pool(false, 1000, 0, 5600, "Gold Pool")); 
        poolInfo.push(Pool(false, 3000, 0, 4200, "Silver Pool")); 
        poolInfo.push(Pool(false, 5000, 0, 3000, "Bronze Pool")); 
    }

    function deposit(uint8 _pool, uint256[] calldata _ids) external nonReentrant existPool(_pool){
        require(openStake, "Pool: open stake false");
        Pool memory pool = poolInfo[_pool];
        require(block.timestamp < unlockTime, "Pool: activity has ended.");
        require(pool.fill + _ids.length <= pool.depth, "Pool: out of pool depth.");
        require(pool.opened, "Pool: The pool is closed.");

        address sender = _msgSender();
        _updateItem(sender, _pool);
        //若最小质押时间UTC大于UnLockTime,直接取UnLockTime
        uint256 depositTime = block.timestamp;
        uint256 readyTime = depositTime + minStakeTime;
        uint256 withdrawTime = readyTime < unlockTime ? readyTime: unlockTime;
        //
        IERC721 fcmNft = IERC721(fcm);
        for(uint256 i = 0; i < _ids.length; i++){
            uint256 tokenId = _ids[i];
            require(vault[tokenId].tokenId == 0, "already staked");
            fcmNft.transferFrom(msg.sender, address(this), tokenId);

            vault[tokenId] = Stake({
                owner: sender,
                poolId: _pool,
                tokenId: tokenId,
                timestamp: depositTime,
                withdrawTime: withdrawTime
            });
            items[sender][_pool].ids.push(tokenId);
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

        emit Deposit(sender, _pool, _ids, depositTime, withdrawTime);
    }

    /**
     * 解除质押
     */
    function withdraw(uint256[] calldata _ids) external nonReentrant{
        require(openStake, "Pool: is closed");
        address account = _msgSender();

        //更新item
        for(uint8 i = 0; i < poolInfo.length; i++){
            _updateItem(account, i);
        }

        //解锁token
        IERC721 fcmNft = IERC721(fcm);
        for(uint256 i = 0; i < _ids.length; i++){
            uint256 tokenId = _ids[i];
            require(vault[tokenId].tokenId != 0, "Pool: token is not staking");
            Stake memory staked = vault[tokenId];
            require(staked.owner == account, "Pool: your are not the owner of the token");
            require(block.timestamp >= staked.withdrawTime, "Pool: time has not arrived");

            uint8 pool = staked.poolId;
            uint256[] memory ids = items[account][pool].ids;
            items[account][pool].ids[tokenToIndex[tokenId]] = ids[ids.length - 1];
            tokenToIndex[ids[ids.length - 1]] = tokenToIndex[tokenId];
            items[account][pool].ids.pop();
            poolInfo[pool].fill -= 1;

            delete vault[tokenId];

            fcmNft.transferFrom(address(this), account, tokenId);

            emit Withdraw(account, _ids);
        }
    }

    /**
     * 领取收益
     */
    function reward(uint256 _amount) external nonReentrant{
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
            if(poolAmount == 0){
                continue;
            }
            all += poolAmount;
            amount += poolAmount * firstRewardRate / 100; //首日收益
            uint256 spendTime = block.timestamp - unlockTime;
            if(spendTime >= PERIOD_SECOND){
                amount += (spendTime / PERIOD_SECOND) * ((poolAmount - (poolAmount * firstRewardRate/100)) / (rewardPeriod - 1));
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
        //第一次质押调用
        if(updateTime == 0){
            items[_account][_pool].updateTime = endTime;
            return;
        }
        //质押时才会调用
        if (
            items[_account][_pool].ids.length == 0 
            || updateTime == endTime
        ) {
            //修复多次质押 区间累加错误
            items[_account][_pool].updateTime = endTime;
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

    function getAccountBalance(address _account, uint8 i) external view returns(uint256){
        return _balances(items[_account][i], i);
    }

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

    function setMinStakeTime(uint256 _minStakeTime) external onlyRole(OPERATOR_ROLE){
        minStakeTime = _minStakeTime;
    }

    function setOpenStake(bool _openStake) external onlyRole(OPERATOR_ROLE){
        openStake = _openStake;
    }

    function setWithdrawTime(uint256 _tokenId, uint256 _withdrawTime) external onlyRole(OPERATOR_ROLE){
        vault[_tokenId].withdrawTime = _withdrawTime;
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

    function isStakingBatch(uint256[] calldata _ids) external view returns(bool[] memory){
        bool[] memory result = new bool[](_ids.length);
        for(uint256 i = 0; i < _ids.length; i++){
            //result[i] = isStaking[_ids[i]];
            Stake memory stakeInfo = vault[_ids[i]];
            result[i] = (stakeInfo.tokenId == 0 ? false: true);
        }
        return result;
    }

    function getPoolOfItem(address _account, uint8 _pool) external view returns(Item memory){
        return items[_account][_pool];
    }

    function getPoolOfItemIds(address _account, uint8 _pool) external view returns(uint256[] memory){
        return items[_account][_pool].ids;
    }

    function getTokenStakeInfo(uint256 _tokenId) external view returns(Stake memory){
        return vault[_tokenId];
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

}