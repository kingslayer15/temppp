// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts/interfaces/IERC721.sol";

/**
 * 需要在fcm合约的交易方法前判断fcmtoken是否在质押中
 */
contract FCMStake is AccessControlEnumerableUpgradeable{

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event Deposit(address indexed account, uint256 pool, uint256[] ids);
    event Withdraw(address indexed account, uint256 pool, uint256[] ids);
    event AddPool(address indexed operator, uint256 poolNo);

    struct Pool {
        string name;   //名称
        uint256 depth; //池子容量
        uint256 fill; //现有数量
        bool opening; //是否已开启
        bool canTakeBack; //是否可以取回
    }

    address public fcmAddress;
    Pool[] public pools; 

    mapping(uint256 => bool) public isStaking; // tokenId => isStake 质押中的token
    mapping(uint256 => uint256) private indexOf; // token => index  stakeMap中的token下标
    mapping(address => mapping(uint256 => uint256[])) private stakeMap; // user => (pool => tokenIds) 用户质押中的tokenIds

    function initialize(address _fcm) public initializer {
        _init_role();
        fcmAddress = _fcm;
        _init_config();
    }
    
    function _init_role() internal onlyInitializing {
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    function _init_config() internal onlyInitializing {
        pools.push(Pool("Diamond Pool", 1000, 0, true, false));
        pools.push(Pool("Gold Pool", 2000, 0, false, false));
        pools.push(Pool("Silver Pool", 3000, 0, false, false));
        pools.push(Pool("Bronze Pool", 4000, 0, false, false));
    }

    function deposit(uint256 _pool, uint256[] calldata _ids) external {
        require(_ids.length > 0, "FCMStake: Params is invalid.");
        require(pools[_pool].opening, "FCMStake: The Pool is not exist or closed.");
        require(pools[_pool].fill + _ids.length <= pools[_pool].depth, "FCMStake: The pool is not depth enough.");
        IERC721 fcm = IERC721(fcmAddress);
        for(uint256 i = 0; i < _ids.length; i++) {
            uint256 tokenId = _ids[i];
            require(!isStaking[tokenId], "FCMStake: Token is being staked.");
            require(fcm.ownerOf(tokenId) == msg.sender,"FCMStake: Your are not the owner of the token.");
            indexOf[tokenId] = stakeMap[msg.sender][_pool].length;
            isStaking[tokenId] = true;
            stakeMap[msg.sender][_pool].push(tokenId);
        }
        pools[_pool].fill += _ids.length;
        //如果池子已满, 关闭本池子, 开启下一个池子
        if (pools[_pool].fill == pools[_pool].depth) {
            pools[_pool].opening = false;
            //判断是否是最后一个池子, 是则不进行开启操作
            if(pools.length != _pool + 1) {
                pools[_pool + 1].opening = true;
            }
        }

        emit Deposit(msg.sender, _pool, _ids);
    }

    function withdraw(uint256 _pool, uint256[] calldata _ids) external {
        require(pools[_pool].canTakeBack, "FCMStake: The fetch function is disabled.");
        for(uint256 i = 0; i < _ids.length; i++) {
            uint256 tokenId = _ids[i];
            require(isStaking[tokenId], "FCMStake: Token is not staking.");
            isStaking[tokenId] = false;
            uint256 index = indexOf[tokenId];
            uint256 len = stakeMap[msg.sender][_pool].length;
            uint256 lastToken = stakeMap[msg.sender][_pool][len - 1];
            indexOf[lastToken] = index;
            stakeMap[msg.sender][_pool][index] = lastToken;
            stakeMap[msg.sender][_pool].pop();
        }
        pools[_pool].fill -= _ids.length;

        emit Withdraw(msg.sender, _pool, _ids);
    }

    //select

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

    /**
     * 查询所有池子信息
     */
    function allPoolInfo() external view returns(Pool[] memory){
        Pool[] memory result = new Pool[](pools.length);
        for(uint8 i = 0; i < pools.length; i++){
            result[i] = pools[i];
        }
        return result;
    }

    /**
     * 查询用户质押中的tokenIds
     */
    function stakeTokens(address _account, uint256 _pool) external view returns(uint256[] memory){
        return stakeMap[_account][_pool];
    }

    // admin
    function addPool(string calldata _name, uint256 _depth) external onlyRole(OPERATOR_ROLE) {
        pools.push(Pool(_name, _depth, 0, false, false));
        emit AddPool(msg.sender, pools.length -1);
    }

    function setFcm(address _newFcm) external onlyRole(OPERATOR_ROLE){
        fcmAddress = _newFcm;
    }

    function setCanTakeBack(uint256 _pool, bool _canTakeBack) external onlyRole(OPERATOR_ROLE){
        pools[_pool].canTakeBack = _canTakeBack;
    }

    function setPoolStatus(uint256 _pool, bool _opening) external onlyRole(OPERATOR_ROLE){
        pools[_pool].opening = _opening;
    }

}
