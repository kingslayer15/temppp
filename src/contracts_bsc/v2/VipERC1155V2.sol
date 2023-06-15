// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../interfaces/IVipERC1155.sol";

contract VipERC1155V2 is OwnableUpgradeable, IVipERC1155, AccessControlEnumerableUpgradeable, ERC1155SupplyUpgradeable, ERC2981Upgradeable {
    using StringsUpgradeable  for uint256;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error NotAllowApproval();

    struct VipConfig {
        uint128 limit;
        uint128 price;
        bool openSale;
    }

    bool public canExchange;
    string public name;
    string public symbol;
    string public baseMetadataURI;
    mapping(uint256 => VipConfig) public vipConfigs;
    mapping(address => bool) public exchangeWhiteMap;

    function initialize(address _owner, string memory _name, string memory _symbol, string calldata _baseUri) public initializer {
        name = _name;
        symbol = _symbol;
        baseMetadataURI = _baseUri;
        _transferOwnership(_owner);
        vipConfigs[1] = VipConfig(5000, 1 * 10 ** 18, false);
        vipConfigs[2] = VipConfig(5000, 2 * 10 ** 18, true);
        __VipERC1155_init_Role(_owner);
        __ERC1155_init_unchained(string(abi.encodePacked(_baseUri, "/{id}.json")));
    }

    function __VipERC1155_init_Role(address owner) internal onlyInitializing {
        _setupRole(ADMIN_ROLE, owner);
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, owner);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    function getVipProviso(uint256 id) public view override returns (uint256, uint256) {
        VipConfig storage config = vipConfigs[id];
        require(config.limit != 0, "no limit");
        return (config.price, totalSupply(id));
    }

    function mint(address to, uint256 tokenId) external override onlyRole(OPERATOR_ROLE) {
        _mint(to, tokenId, 1, "");
    }

    function multiMint(address to, uint256 tokenId, uint256 amount) external override onlyRole(OPERATOR_ROLE) {
        _mint(to, tokenId, amount, "");
    }

    function batchMint(address[] calldata tos, uint256[] calldata tokenIds) external override onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < tos.length; i++) {
            _mint(tos[i], tokenIds[i], 1, "");
        }
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                require(vipConfigs[ids[i]].openSale == true, "openSale error");
                require(vipConfigs[ids[i]].limit != 0, "no limit");
                require(super.totalSupply(ids[i]) <= vipConfigs[ids[i]].limit, "execed limit");
            }
        }
    }


    function setVipConfig(uint256 _tokenId, uint128 _limit, uint128 _price) external onlyRole(OPERATOR_ROLE) {
        VipConfig storage vipConfig = vipConfigs[_tokenId];
        vipConfig.limit = _limit;
        vipConfig.price = _price;
    }

    function setVipConfigOpen(uint256 _tokenId, bool _open) external onlyRole(OPERATOR_ROLE) {
        VipConfig storage vipConfig = vipConfigs[_tokenId];
        vipConfig.openSale = _open;
    }

    function uri(uint256 tokenId) override public view returns (string memory) {
        return string(abi.encodePacked(baseMetadataURI, "/", tokenId.toString(), ".json"));
    }


    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyRole(OPERATOR_ROLE) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }


    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyRole(OPERATOR_ROLE) {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyRole(OPERATOR_ROLE) {
        _resetTokenRoyalty(tokenId);
    }

    // set role
    function setRoleAdmin(bytes32 roleId, bytes32 adminRoleId) external onlyRole(ADMIN_ROLE) {
        _setRoleAdmin(roleId, adminRoleId);
    }

    // add role account
    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerableUpgradeable, ERC1155Upgradeable, ERC2981Upgradeable) returns (bool){
        return
        interfaceId == type(AccessControlEnumerableUpgradeable).interfaceId ||
        interfaceId == type(IERC1155Upgradeable).interfaceId ||
        interfaceId == type(ERC2981Upgradeable).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function setCanExchange(bool _canExchange) external onlyRole(OPERATOR_ROLE) {
        canExchange = _canExchange;
    }

    function setExchangeWhiteMap(address _to, bool _canExchange) external onlyRole(OPERATOR_ROLE) {
        exchangeWhiteMap[_to] = _canExchange;
    }

    function setApprovalForAll(address operator, bool approved) public override {
        if (!canExchange || !exchangeWhiteMap[operator]) {
            revert NotAllowApproval();
        }
        super.setApprovalForAll(operator, approved);
    }

}