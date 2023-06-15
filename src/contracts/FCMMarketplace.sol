// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "openzeppelin-contracts/interfaces/IERC165.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract FCMMarketplace is OwnableUpgradeable, AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable{

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    //using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMathUpgradeable for uint256;

    /// @notice Platform fee receipient收款地址
    address payable public feeReceipient;

    struct Listing {
        uint256 quantity;
        address payToken;       //0x00为以太坊
        uint256 pricePerItem;
        uint256 startingTime;
        address payable seller;
    }

    /// @notice ERC721 Address -> Bool
    //兼容多ERC721
    mapping(address => bool) public nftRegistry;
    //手续费管理器
    mapping(address => uint16) public platformFees;

    /// @notice NftAddress -> Token ID -> Owner -> Listing item
    mapping(address => mapping(uint256 => mapping(address => Listing))) public listings;

    /// @notice Events for the contract
    event ItemListed(
        address indexed owner,
        address indexed nft,
        uint256 tokenId,
        uint256 quantity,
        address payToken,
        uint256 pricePerItem,
        uint256 startingTime
    );
    event ItemSold(
        address indexed seller,
        address indexed buyer,
        address indexed nft,
        uint256 tokenId,
        uint256 quantity,
        address payToken,
        uint256 price,
        uint256 fee
    );
    event ItemUpdated(
        address indexed owner,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 newPrice
    );
    event ItemCanceled(
        address indexed owner,
        address indexed nft,
        uint256 tokenId
    );
    event UpdatePlatformFee(address indexed nft, uint16 platformFee);
    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);

    event TokenAdded(address token);
    event TokenRemoved(address token);
    event NFTAdded(address nftContract);
    event NFTRemoved(address nftContract);

    modifier isListed(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId][_owner];
        require(listing.quantity > 0, "not listed item");
        _;
    }

    modifier notListed(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId][_owner];
        require(listing.quantity == 0, "already listed");
        _;
    }
    
    function initialize() public virtual initializer{
        __Marketplace_init();
        __ReentrancyGuard_init();
    }

    function __Marketplace_init() internal onlyInitializing {
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    /// @notice Method for listing NFT
    /// @param _nftAddress Address of NFT contract
    /// @param _tokenId Token ID of NFT
    /// @param _pricePerItem sale price for each iteam
    /// @param _startingTime scheduling for a future sale
    function listItem(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _pricePerItem,
        uint256 _startingTime
    ) 
        external
        nonReentrant
        notListed(_nftAddress, _tokenId, _msgSender()) {

        //校验NFT合约是否兼容
        _validNftContract(_nftAddress);

        address _owner = _msgSender();

        IERC721 nft = IERC721(_nftAddress);
        require(nft.ownerOf(_tokenId) == _owner, "not owning item");

        listings[_nftAddress][_tokenId][_owner] = Listing(
            1,
            address(0),
            _pricePerItem,
            _startingTime,
            payable(_owner)
        );
        nft.transferFrom(_owner, address(this), _tokenId);
        emit ItemListed(
            _owner,
            _nftAddress,
            _tokenId,
            1,
            address(0),
            _pricePerItem,
            _startingTime
        );
    }

    /// @notice Method for updating listed NFT
    /// @param _nftAddress Address of NFT contract
    /// @param _tokenId Token ID of NFT
    /// @param _newPrice New sale price for each iteam
    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _newPrice        
    )
        external 
        nonReentrant
        isListed(_nftAddress, _tokenId, _msgSender())
    {
        address _owner = _msgSender();
        Listing storage listedItem = listings[_nftAddress][_tokenId][_owner];

        //校验NFT合约是否兼容
        _validNftContract(_nftAddress);

        listedItem.pricePerItem = _newPrice;

        emit ItemUpdated(
            _owner,
            _nftAddress,
            _tokenId,
            address(0),
            _newPrice
        );
    }

    /// @notice Method for canceling listed NFT
    function cancelListing(
        address _nftAddress, 
        uint256 _tokenId
    )
        external
        nonReentrant
        isListed(_nftAddress, _tokenId, _msgSender())
    {
        address _owner = _msgSender();
        
        IERC721 nft = IERC721(_nftAddress);
        require(nft.ownerOf(_tokenId) == _owner, "not owning item");

        delete (listings[_nftAddress][_tokenId][_owner]);
        emit ItemCanceled(_owner, _nftAddress, _tokenId);
    }

    /// @notice Method for buying listed NFT
    /// @param _nftAddress NFT contract address
    /// @param _tokenId TokenId
    function buyItem(
        address _nftAddress, 
        uint256 _tokenId,
        address _owner
    ) 
        external 
        payable
        nonReentrant 
        notListed(_nftAddress, _tokenId, _msgSender())
    {
        address _buyer = _msgSender();
        require(_buyer != _owner, "buy item error");
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
        //校验NFT合约是否兼容
        _validNftContract(_nftAddress);

        //以太坊支付
        _buyItemByEth(listedItem, _nftAddress, _tokenId);
    }

    function fetchItemInfo(address _nftAddress, uint256 _tokenId, address _owner)external view returns(Listing memory){
        return listings[_nftAddress][_tokenId][_owner];
    }

    //-----管理员接口--------
    //修改收款地址
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient) external onlyRole(OPERATOR_ROLE){
        feeReceipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    //修改抽成比例
    function updatePlatformFee(address _nftContract, uint16 _platformFee) external onlyRole(OPERATOR_ROLE) {
        platformFees[_nftContract] = _platformFee;
        emit UpdatePlatformFee(_nftContract, _platformFee);
    }
    //添加兼容的NFT地址
    function addNftContract(address _nftContract) external onlyRole(OPERATOR_ROLE) {
        require(!nftRegistry[_nftContract], "nft already added");
        nftRegistry[_nftContract] = true;
        emit NFTAdded(_nftContract);
    }

    function removeNftContract(address _nftContract) external onlyRole(OPERATOR_ROLE) {
        require(nftRegistry[_nftContract], "nft not exist");
        nftRegistry[_nftContract] = false;
        emit NFTRemoved(_nftContract);
    }

    // set role
    function setRoleAdmin(bytes32 roleId, bytes32 adminRoleId) external onlyRole(ADMIN_ROLE) {
        _setRoleAdmin(roleId, adminRoleId);
    }

    // add role account
    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }


    //--------Internal Function-----------

    function _validNftContract(address _nftContract) internal view{
        require(nftRegistry[_nftContract], "invalid NFT Contract");
    }

    function _buyItemByEth(
        Listing memory listedItem, 
        address _nftAddress,
        uint256 _tokenId
    )internal {
        address _buyer = _msgSender();
        //手续费
        uint16 platformFee = platformFees[_nftAddress];
        uint256 feeAmount = listedItem.pricePerItem.mul(platformFee).div(1e3);
        //扣除手续费价格
        uint256 realAmount = listedItem.pricePerItem.sub(feeAmount);
        //转账
        (bool feeSuccess,) = payable(feeReceipient).call{value : feeAmount}("");
        require(feeSuccess, "feeAmount payble error");
        (bool buySuccess,) = payable(listedItem.seller).call{value : realAmount}("");
        require(buySuccess, "buyItem payble error");
        //中介费
        //feeReceipient.transfer(feeAmount);
        //卖家收钱
        //listedItem.seller.transfer(realAmount);
        delete (listings[_nftAddress][_tokenId][listedItem.seller]);
        //NFT转给买家
        IERC721(_nftAddress).safeTransferFrom(
            address(this),
            _buyer,
            _tokenId
        );
        emit ItemSold(
            listedItem.seller,
            _buyer,
            _nftAddress,
            _tokenId,
            listedItem.quantity,
            address(0),
            realAmount,
            feeAmount
        );   
    }
}