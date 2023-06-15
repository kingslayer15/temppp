// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/CountersUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "./interfaces/IFreeCityGameNFT.sol";
// 麦克风NFT合约
contract FreeCityGameNFT is
OwnableUpgradeable,
IFreeCityGameNFT,
AccessControlEnumerableUpgradeable,
ERC721EnumerableUpgradeable,
ReentrancyGuardUpgradeable,
ERC2981Upgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable  for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant MAXMINTLIMIT = 8;

    error NotAllowApproval();

    struct Voice {
        uint128 life;
        uint128 grade;
        uint256 parent;
        uint256 mother;
        string tokenURI;
    }

    bool public canExchange;
    mapping(uint256 => Voice) private  _tokenToVoice;
    mapping(address => bool) public exchangeWhiteMap;
    mapping(uint256 => bool) private freeCityPool;
    CountersUpgradeable.Counter private _tokenIdTracker;

    // event
    event Deposit(address indexed, uint256 indexed, uint256 tokenId);
    event Withdraw(address indexed, uint256 tokenId);
    event Exchange(address indexed, address indexed, uint256 tokenId);
    event Synthesis(uint256 indexed, uint256 parent, uint256 mother);

    function initialize(address owner, string memory name, string memory symbol) public virtual initializer {
        _transferOwnership(owner);
        __ERC721_init_unchained(name, symbol);
        __FreeCityGame_init(owner);
        __ReentrancyGuard_init();
        _tokenIdTracker.increment();
    }

    function __FreeCityGame_init(address owner) internal onlyInitializing {
        // set role
        _setupRole(ADMIN_ROLE, owner);
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, owner);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    function multiPreMint(address to, uint256[] calldata metaDataIds, string calldata baseUri) external override onlyRole(OPERATOR_ROLE) {
        for(uint256 i = 0 ; i < metaDataIds.length; i++) {
            uint256 tokenId = _tokenIdTracker.current();
            _tokenToVoice[tokenId] = Voice(
                0,
                1,
                0,
                0,
                string(abi.encodePacked(baseUri, "/", metaDataIds[i].toString(), ".json"))
            );
            _safeMint(to, tokenId);
            _tokenIdTracker.increment();
        }
    }

    function preMint(address to, uint256 metaDataId, string calldata baseUri) external override onlyRole(OPERATOR_ROLE) {
        uint256 tokenId = _tokenIdTracker.current();
        _tokenToVoice[tokenId] = Voice(
            0,
            1,
            0,
            0,
            string(abi.encodePacked(baseUri, "/", metaDataId.toString(), ".json"))
        );
        _safeMint(to, tokenId);
        _tokenIdTracker.increment();
    }

    function mint(address to, string calldata _tokenURI) external onlyRole(OPERATOR_ROLE) {
        uint256 tokenId = _tokenIdTracker.current();
        _safeMint(to, tokenId);
        _tokenToVoice[tokenId] = Voice(
            0,
            1,
            0,
            0,
            _tokenURI
        );
        _tokenIdTracker.increment();
    }

    function updateVoiceInfo(uint256 tokenId, Voice calldata voice) external onlyRole(OPERATOR_ROLE) {
        require(_existsVoice(tokenId), "n");
        _tokenToVoice[tokenId] = voice;
    }

    function updateTokenUri(uint256 tokenId, string memory _tokenUrl) external onlyRole(OPERATOR_ROLE) {
        require(_exists(tokenId), "n1");
        _tokenToVoice[tokenId].tokenURI = _tokenUrl;
    }

    function metaMutData(uint256 _tokenId) public view returns (uint128 life, uint128 grade, bool status, string memory uri) {
        require(_exists(_tokenId), "n1");
        Voice storage voice = _tokenToVoice[_tokenId];
        return (voice.life, voice.grade, freeCityPool[_tokenId], voice.tokenURI);
    }

    function getVoiceInfo(uint256 tokenId) external view returns (Voice memory) {
        require(ERC721Upgradeable.ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");
        require(_existsVoice(tokenId), "No information is set");
        return _tokenToVoice[tokenId];
    }


    function _existsVoice(uint256 tokenId) internal view returns (bool) {
        return bytes(_tokenToVoice[tokenId].tokenURI).length != 0;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "nonexistent token");
        require(_existsVoice(tokenId), "nonexistent voiceinfo");
        return _tokenToVoice[tokenId].tokenURI;
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _burn(tokenId);
    }

    function isStaking(uint256 tokenId) public view returns (bool) {
        return freeCityPool[tokenId];
    }

    function deposit(uint256 tokenId, uint256 userId) external nonReentrant {
        require(_exists(tokenId), "n1");
        require(!freeCityPool[tokenId], "n2");
        // 只能是token拥有者或授权人操作
        require(_isApprovedOrOwner(_msgSender(), tokenId), "n3");
        freeCityPool[tokenId] = true;
        emit Deposit(_msgSender(), userId, tokenId);
    }

    function withdraw(address to, uint256 tokenId, uint128 life, uint128 grade) external onlyRole(OPERATOR_ROLE) {
        require(_exists(tokenId), "nonexistent token");
        require(freeCityPool[tokenId], "n1");
        _tokenToVoice[tokenId].life = life;
        _tokenToVoice[tokenId].grade = grade;
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        if (owner != to) {
            _transfer(owner, to, tokenId);
        }
        freeCityPool[tokenId] = false;
        delete freeCityPool[tokenId];
        emit Withdraw(to, tokenId);
    }

    function exchange(uint256 tokenId, address to, uint128 life, uint128 grade) external onlyRole(OPERATOR_ROLE) {
        require(freeCityPool[tokenId], "n1");
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        _tokenToVoice[tokenId].life = life;
        _tokenToVoice[tokenId].grade = grade;
        _transfer(owner, to, tokenId);
        emit Exchange(owner, to, tokenId);
    }

    function synthesis(uint256 parent, uint256 mother, address to, string calldata _tokenURI) external onlyRole(OPERATOR_ROLE) {
        require(freeCityPool[parent] && freeCityPool[mother], "n1");
        require(_tokenToVoice[parent].life < MAXMINTLIMIT, "n2");
        require(_tokenToVoice[mother].life < MAXMINTLIMIT, "n3");
    unchecked {
        _tokenToVoice[parent].life = _tokenToVoice[parent].life + 1;
        _tokenToVoice[mother].life = _tokenToVoice[mother].life + 1;
    }
        uint256 tokenId = _tokenIdTracker.current();
        _mint(to, tokenId);
        _tokenToVoice[tokenId] = Voice(
            0,
            1,
            parent,
            mother,
            _tokenURI
        );
        freeCityPool[tokenId] = true;
        _tokenIdTracker.increment();
        emit Synthesis(tokenId, parent, mother);
    }

    function tokensOfOwner(address _user) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_user);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_user, i);
        }
        return tokensId;
    }


    function transferFrom(address from, address to, uint256 _tokenId) public override {
        require(!freeCityPool[_tokenId], "n1");
        ERC721Upgradeable.transferFrom(from, to, _tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 _tokenId) public override {
        require(!freeCityPool[_tokenId], "n1");
        ERC721Upgradeable.safeTransferFrom(from, to, _tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 _tokenId, bytes memory data) public override {
        require(!freeCityPool[_tokenId], "n1");
        ERC721Upgradeable.safeTransferFrom(from, to, _tokenId, data);
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

    function setExchangeWhiteMap(address _to, bool _canExchange) external onlyRole(OPERATOR_ROLE) {
        exchangeWhiteMap[_to] = _canExchange;
    }

    function approve(address to, uint256 tokenId) public virtual override {
        if(!canExchange || !exchangeWhiteMap[to]) {
            revert NotAllowApproval();
        }
        super.approve(to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        if(!canExchange || !exchangeWhiteMap[operator]) {
            revert NotAllowApproval();
        }
        super.setApprovalForAll(operator, approved);
    }

    /*function isApprovedForAll(address _owner, address _operator) public view override(ERC721Upgradeable) returns (bool){
        return ERC721Upgradeable.isApprovedForAll(_owner, _operator);
    }*/


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


}