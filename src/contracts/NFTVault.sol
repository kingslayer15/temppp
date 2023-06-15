// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// NFT存储合约
contract NFTVault is OwnableUpgradeable,ReentrancyGuardUpgradeable {

    address private _proxyAdmin;

    // NFT结构体，包含合约地址和tokenId
    struct NFT {
        address contractAddress; // 合约地址
        uint256 tokenId; // tokenId
    }

    // 存款映射，将地址映射到NFT数组
    mapping(address => NFT[]) private _deposits;

    // 存储每个NFT的存款人
    mapping(address => mapping(uint256 => address)) private _depositors;

    function initialize(address owner) public virtual initializer {
        _transferOwnership(owner);
        __ReentrancyGuard_init();

    }

    // 存款函数，接收合约地址和tokenId作为参数
    function deposit(address contractAddress, uint256 tokenId) public {

        // 创建ERC721合约实例
        ERC721 nftContract = ERC721(contractAddress);

        // 将NFT从发送者转移到此合约
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        // 记录存款
        _deposits[msg.sender].push(NFT(contractAddress, tokenId));
        _depositors[contractAddress][tokenId] = msg.sender;
    }

    // 提款函数，接收合约地址和tokenId作为参数
    function withdraw(address contractAddress, address to, uint256 tokenId) public{
        require(msg.sender == owner(), "Only the owner can withdraw the NFT.");

        ERC721 nftContract = ERC721(contractAddress);

        // 在存款人的存款中找到NFT
        NFT[] storage deposits = _deposits[_depositors[contractAddress][tokenId]];
        for (uint i = 0; i < deposits.length; i++) {
            if (deposits[i].contractAddress == contractAddress && deposits[i].tokenId == tokenId) {
                // 从存款人的存款中移除NFT
                deposits[i] = deposits[deposits.length - 1];
                deposits.pop();

                // 将NFT转回到存款人
                nftContract.transferFrom(address(this), to, tokenId);

                return;
            }
        }

        // 如果没有找到NFT，回滚交易
        revert("NFT not found in depositor's deposits.");
    }

    // 提款函数，接收合约地址和tokenId作为参数
    function adminWithdraw(address contractAddress, address to, uint256 tokenId) public {
        require(msg.sender == owner() || msg.sender == _depositors[contractAddress][tokenId], "Only the owner or the depositor can withdraw the NFT.");

        ERC721 nftContract = ERC721(contractAddress);

        // 在存款人的存款中找到NFT
        NFT[] storage deposits = _deposits[_depositors[contractAddress][tokenId]];
        for (uint i = 0; i < deposits.length; i++) {
            if (deposits[i].contractAddress == contractAddress && deposits[i].tokenId == tokenId) {
                // 从存款人的存款中移除NFT
                deposits[i] = deposits[deposits.length - 1];
                deposits.pop();

                // 将NFT转回到存款人
                nftContract.transferFrom(address(this), to, tokenId);

                return;
            }
        }

        // 如果没有找到NFT，回滚交易
        revert("NFT not found in depositor's deposits.");
    }

    // 获取存款函数，接收存款人地址作为参数，返回NFT数组
    function getDeposits(address depositor) public view returns (NFT[] memory) {
        return _deposits[depositor];
    }

    // 获取令牌URI函数，接收合约地址和tokenId作为参数，返回令牌的URI
    function getTokenURI(address contractAddress, uint256 tokenId) public view returns (string memory) {
        ERC721 nftContract = ERC721(contractAddress);
        return nftContract.tokenURI(tokenId);
    }
    // 获取令牌URI函数，接收合约地址和tokenId作为参数，返回令牌的URI
    function getOwner() public view returns (address) {
        return owner();
    }
}




//let NFTVault = artifacts.require("./contracts/NFTVault")
//let nFTVault = await NFTVault.at("0x8552B2891d255EDCf5b238036ac619c6AE80CE81");
//let nFTVault = await NFTVault.deployed();

//let result = await nFTVault.deposit("0x4352a311D706dD7439ef1B257A81677bB162e5fc", 57);

//let result = await nFTVault.withdraw("0x4352a311D706dD7439ef1B257A81677bB162e5fc", 57);

//let result = await nFTVault.getTokenURI("0x4352a311D706dD7439ef1B257A81677bB162e5fc", 57);

//console.log(result);


//let FreeCityGameNFTv2 = artifacts.require("./contracts/v2/FreeCityGameNFTv2")
//let instance1 = await FreeCityGameNFTv2.at("0x4352a311D706dD7439ef1B257A81677bB162e5fc");
//let result = await instance1.tokenURI(57)
//let result = await instance1.approve("0x8552B2891d255EDCf5b238036ac619c6AE80CE81", 57)


//let instance = await FreeCityGameNFTv2.deployed();

