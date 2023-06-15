// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/CountersUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "../interfaces/IFreeCityGameNFTv1.sol";
import "../interfaces/IStakePool.sol";

// 麦克风NFT合约-v2
contract FreeCityGameNFTv2 is
OwnableUpgradeable,
AccessControlEnumerableUpgradeable,
ERC721EnumerableUpgradeable,
ReentrancyGuardUpgradeable,
ERC2981Upgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable  for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error NotAllowApproval();

    bool public canExchange;
    address public stakePool;
    uint256 public oldTotalSupply;
    // address public oldFcm = 0x3505A719Dfe145B65DADbDeB6Ec21990A9b1f60a; //test
    address public oldFcm; //eth mainnet

    // mapping(address => bool) public exchangeWhiteMap;
    mapping(uint256 => bool) private freeCityPool;
    mapping(uint256 => string) private _tokenURIs;

    CountersUpgradeable.Counter private _tokenIdTracker;

    // event
    event Deposit(address indexed, uint256 indexed, uint256 tokenId);
    event Withdraw(address indexed, uint256 tokenId);
    event Exchange(address indexed, address indexed, uint256 tokenId);

    function initialize(address owner, string memory name, string memory symbol) public virtual initializer {
        _transferOwnership(owner);
        __ERC721_init_unchained(name, symbol);
        __FreeCityGame_init(owner);
        __ReentrancyGuard_init();
        _tokenIdTracker.increment();
        oldFcm = 0x9DF98D40Bda4d3865c775E4d576F0C3Fbaa5968a;
        canExchange = true;

    }

    function __FreeCityGame_init(address owner) internal onlyInitializing {
        // set role
        _setupRole(ADMIN_ROLE, owner);
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, owner);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        
    }

    function airdropBatch(address[] calldata tos, uint256[] calldata ids) external onlyRole(OPERATOR_ROLE){
        for(uint256 i = 0 ; i < ids.length; i++) {
            _safeMint(tos[i], ids[i]);
            _tokenIdTracker.increment();
        }
    }

    function multiPreMint(address to, uint256[] calldata metaDataIds, string calldata baseUri) external onlyRole(OPERATOR_ROLE) {
        for(uint256 i = 0 ; i < metaDataIds.length; i++) {
            uint256 tokenId = _tokenIdTracker.current();
            _tokenURIs[tokenId] = string(abi.encodePacked(baseUri, "/", metaDataIds[i].toString(), ".json"));
            _safeMint(to, tokenId);
            _tokenIdTracker.increment();
        }
    }

    function preMint(address to, uint256 metaDataId, string calldata baseUri) external onlyRole(OPERATOR_ROLE) {
        uint256 tokenId = _tokenIdTracker.current();
        _tokenURIs[tokenId] = string(abi.encodePacked(baseUri, "/", metaDataId.toString(), ".json"));
        _safeMint(to, tokenId);
        _tokenIdTracker.increment();
    }

    function mint(address to, string calldata _tokenURI) external onlyRole(OPERATOR_ROLE) {
        uint256 tokenId = _tokenIdTracker.current();
        _safeMint(to, tokenId);
        _tokenURIs[tokenId] = _tokenURI;
        _tokenIdTracker.increment();
    }


    function updateTokenUri(uint256 tokenId, string memory _tokenUrl) external onlyRole(OPERATOR_ROLE) {
        require(_exists(tokenId), "n1");
        _tokenURIs[tokenId] = _tokenUrl;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "nonexistent token");
        if(tokenId <= oldTotalSupply){
            IFreeCityGameNFTv1 oldFcmContract = IFreeCityGameNFTv1(oldFcm);
            return oldFcmContract.tokenURI(tokenId);
        }
        return _tokenURIs[tokenId];
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _burn(tokenId);
    }

    function tokensOfOwner(address _user) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_user);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_user, i);
        }
        return tokensId;
    }


    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyRole(OPERATOR_ROLE) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }


    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyRole(OPERATOR_ROLE) {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyRole(OPERATOR_ROLE) {
        super._resetTokenRoyalty(tokenId);
    }

    function setCanExchange(bool _canExchange) external onlyRole(OPERATOR_ROLE) {
        canExchange = _canExchange;
    }

    function setOldTotalSupply(uint256 _newOldTotalSupply) external onlyRole(OPERATOR_ROLE) {
        oldTotalSupply = _newOldTotalSupply;
    }

    // function setExchangeWhiteMap(address _to, bool _lock) external onlyRole(OPERATOR_ROLE) {
    //     exchangeWhiteMap[_to] = _lock;
    // }


    function supportsInterface(bytes4 interfaceId) public view virtual override(
    AccessControlEnumerableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC2981Upgradeable
    ) returns (bool){
        return
        interfaceId == type(AccessControlEnumerableUpgradeable).interfaceId ||
        interfaceId == type(IERC721EnumerableUpgradeable).interfaceId ||
        interfaceId == type(ERC2981Upgradeable).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function setRoleAdmin(bytes32 roleId, bytes32 adminRoleId) external onlyRole(ADMIN_ROLE) {
        _setRoleAdmin(roleId, adminRoleId);
    }

    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function setStakePool(address _newStakePoll) external onlyRole(ADMIN_ROLE){
        stakePool = _newStakePoll;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
        // IStakePool pool = IStakePool(stakePool);
        // require(!pool.isStaking(firstTokenId), "token is staking.");
        require(canExchange, "CanExchange is false.");
        // require(!exchangeWhiteMap[from], "Address is locking.");
    }


}