// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "./interfaces/ICardERC1155.sol";

contract CardERC1155 is ICardERC1155, OwnableUpgradeable, AccessControlEnumerableUpgradeable, ERC1155SupplyUpgradeable, ERC2981Upgradeable {
    using ECDSAUpgradeable for bytes32;
    using StringsUpgradeable  for uint256;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address private openSea;
    string public name;
    string public symbol;
    string public baseMetadataURI;
    mapping(uint256 => uint256) public mintPrice;
    mapping(address => uint256) public ownTokenId;

    function initialize(string memory _name, string memory _symbol, uint256[6] memory mintPrices, string calldata _baseUri) public initializer {
        __Ownable_init();
        __CardERC1155_init_Role();
        name = _name;
        symbol = _symbol;
        baseMetadataURI = _baseUri;
        setEveryNftMintPrice(mintPrices);
        __ERC1155_init_unchained(string(abi.encodePacked(_baseUri, "/{id}.json")));
    }

    function __CardERC1155_init_Role() internal onlyInitializing {
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
    }

    function setEveryNftMintPrice(uint256[6] memory mintPrices) public onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < mintPrices.length; i++) {
            mintPrice[i] = mintPrices[i];
        }
    }

    function setSingleNftMintPrice(uint256 tokenId, uint256 mintSinglePrice) external onlyRole(OPERATOR_ROLE) {
        require(tokenId > 0 && tokenId < 6, "id error");
        mintPrice[tokenId] = mintSinglePrice;
    }

    function _mintCard(address to, uint256 tokenId) private {
        require(tokenId > 0 && tokenId < 6, "id error");
        require(ownTokenId[to] == 0, "only an card");
        _mint(to, tokenId, 1, "");
        ownTokenId[to] = tokenId;
    }


    function airdrop(address to, uint256 tokenId, bytes32 _hash, uint8 v, bytes32 r, bytes32 s) external {
        require(keccak256(abi.encode(to, tokenId)) == _hash, "n1");
        require(hasRole(OPERATOR_ROLE, _hash.recover(v, r, s)), "n2");
        _mintCard(to, tokenId);
    }

    function mint(address to, uint256 tokenId) public onlyRole(OPERATOR_ROLE) {
        _mintCard(to, tokenId);
    }

    function batchMint(address[] calldata tos, uint256[] calldata tokenIds) public onlyRole(OPERATOR_ROLE) {
        require(tos.length == tokenIds.length, "n1");
        for(uint256 i = 0 ; i < tos.length ; i++) {
            _mintCard(tos[i], tokenIds[i]);
        }
    }

    function uri(uint256 id) override public view returns (string memory) {
        if (id == 0) {
            return "";
        } else {
            return string(abi.encodePacked(baseMetadataURI, "/", id.toString(), ".json"));
        }
    }

    // get account discount
    function getDisCount(address account) external override view returns (uint256) {
        uint256 discount = ownTokenId[account];
        return mintPrice[discount];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerableUpgradeable, ERC1155Upgradeable, ERC2981Upgradeable) returns (bool){
        return
        interfaceId == type(AccessControlEnumerableUpgradeable).interfaceId ||
        interfaceId == type(IERC1155Upgradeable).interfaceId ||
        interfaceId == type(ERC2981Upgradeable).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    // set role
    function setRoleAdmin(bytes32 roleId, bytes32 adminRoleId) external onlyRole(ADMIN_ROLE) {
        _setRoleAdmin(roleId, adminRoleId);
    }

    // add role account
    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    // set openSea address
    function setOpenSea(address _openSea) external onlyRole(OPERATOR_ROLE) {
        openSea = _openSea;
    }

    function getOpenSea() public view returns (address) {
        return openSea;
    }

    function setBaseMetadataURI(string calldata _baseUri) external onlyRole(OPERATOR_ROLE) {
        baseMetadataURI = _baseUri;
    }

    function isApprovedForAll(address _owner, address _operator) public view override(ERC1155Upgradeable) returns (bool isOperator) {
        if (openSea != address(0) && _operator == openSea) {
            return true;
        }
        return ERC1155Upgradeable.isApprovedForAll(_owner, _operator);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyRole(ADMIN_ROLE) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }


    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyRole(ADMIN_ROLE) {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

}
