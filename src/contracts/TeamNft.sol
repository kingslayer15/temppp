// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TeamNft is 
    Initializable,
    ContextUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721PausableUpgradeable,
    ERC2981Upgradeable
{

    using StringsUpgradeable for uint256;
    uint256 public index; 
    uint256 public step; //step1,允许兑换step1limit，step2,关闭兑换通道，step3,自由兑换，总数不超过totalAmount
    uint256 public step1limit;
    uint256 public totalAmount;

    string public baseUri;

    mapping(uint256 => uint256) private indices;


    //记录已用过的随机ID，防止重放攻击
    mapping(uint256=>uint256)  public salts;
    //marketplace white list
    bool controlmarketplace;
    mapping(address=>uint256) public marketplacewhitelist;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function initialize(address owner, string memory name, string memory symbol,string calldata _baseurl)
        public
        virtual
        initializer
    {
        __ERC721_init_unchained(name, symbol);
        __Pausable_init_unchained();
        __TeamNft_init_unchained(owner, name, symbol);

        index = 0; 
        step = 1;
        step1limit = 700;
        totalAmount = 2752;
        controlmarketplace = true;
        baseUri = _baseurl;
    }

    function __TeamNft_init_unchained(address owner, string memory, string memory)
        internal
        onlyInitializing
    {
        _setupRole(ADMIN_ROLE, owner);

        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, owner);

        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, owner);

        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    function grantMintRole(address to) external {
        require(hasRole(ADMIN_ROLE, _msgSender()), "n1");
        _grantRole(OPERATOR_ROLE, to);
    }

    function _setBaseURI(string memory baseURI) internal {
        baseUri = baseURI;
    }

    function setBaseURI(string memory baseURI) public onlyRole(OPERATOR_ROLE) {
        _setBaseURI(baseURI);
    }

    function setStepInfo(uint256 _setp,uint256 _setp1limit) public onlyRole(OPERATOR_ROLE) {
        step = _setp;
        step1limit = _setp1limit;
    }

    function setStepValue(uint256 _step) public onlyRole(OPERATOR_ROLE){
        step = _step;
    }      

    function getCurrentCount() public view returns (uint256)
    {
        return index;
    }

    function tokenURI(uint256 tokenId) public view  override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = baseUri;
        return string(abi.encodePacked(baseURI,"/",(tokenId.toString()),".json"));
    }


    function mint(address to) external onlyRole(OPERATOR_ROLE){
        if(step == 1){
            require(index + uint(1) <= step1limit,"step1 limit error");
        }
        
        require(index + uint(1) <= totalAmount,"Exceed the total amount limit ");
        uint _tokenId = randomIndex();
         _safeMint(to, _tokenId);

    }


    function batchMint(address[] memory tos) external onlyRole(OPERATOR_ROLE)
    {
        if(step == 1){
            require(index + tos.length <= step1limit,"step1 limit error");
        }
        
        require(index + tos.length <= totalAmount,"Exceed the total amount limit ");
        for (uint256 i = 0 ; i < tos.length ; i++){
            uint _tokenId = randomIndex();
            _safeMint(tos[i], _tokenId);
        }
        
    }

    function airdrop(address to,uint256 salt, bytes32 _hash,uint8 v,bytes32 r,bytes32 s) external returns (uint tokenid) {
        require(keccak256(abi.encode(to,salt))==_hash,"hash error");
        require(hasRole(OPERATOR_ROLE, ecrecover(_hash, v, r, s)), "sign error");
        require(salts[salt]==0,"salt repeat");

        if(step == 1){
            require(index + uint(1) <= step1limit,"step1 limit error");
        }
        
        require(step != 2 ,"step2 close");
        require(index + uint(1) <= totalAmount,"Exceed the total amount limit ");
        uint _tokenId = randomIndex();
         _safeMint(to, _tokenId);
         salts[salt]=1;
         return _tokenId;
    }

    function randomIndex() private  returns (uint256) {
        uint256 totalSize = totalAmount - index;
        uint256 _index = uint256(
            keccak256(abi.encodePacked(index, msg.sender, block.difficulty, block.timestamp))) % totalSize;
        uint256 tokenIdLocal = 0;
        
        if (indices[_index] != 0) {
            tokenIdLocal = indices[_index];
        } else {
            tokenIdLocal = _index;
        }
        if (indices[totalSize - 1] == 0) {
            indices[_index] = totalSize - 1;
        } else {
            indices[_index] = indices[totalSize - 1];
        }
        index = index + 1;
        return tokenIdLocal + 1;
    }

    function tokensOfOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }


function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC721Upgradeable,
            AccessControlEnumerableUpgradeable,
            ERC721EnumerableUpgradeable,
            ERC2981Upgradeable
        )
        returns (bool)
    {
        return
            interfaceId ==
            type(AccessControlEnumerableUpgradeable).interfaceId ||
            interfaceId == type(IERC721EnumerableUpgradeable).interfaceId ||
            interfaceId == type(ERC2981Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        override(
            ERC721EnumerableUpgradeable,
            ERC721PausableUpgradeable,
            ERC721Upgradeable
        )
    {
        require(!paused(), "pause tx");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @notice Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator)
        external
        onlyRole(OPERATOR_ROLE)
    {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @notice Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `tokenId` must be already minted.
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyRole(OPERATOR_ROLE) {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    } 



    function setmarketplacecontrol(bool _bControl) public onlyRole(OPERATOR_ROLE){
        controlmarketplace = _bControl;
    }    

    function setmarketplace(address marketpalce,uint32 _nset) public onlyRole(OPERATOR_ROLE){
        marketplacewhitelist[marketpalce] = _nset;
    }  

    function approve(address to, uint256 tokenId) public override {
        if(!controlmarketplace)
            return ERC721Upgradeable.approve(to, tokenId);
        else{
            //marketplace must in whitelist
            require(marketplacewhitelist[to]==1, "marketpalce denied");
            return ERC721Upgradeable.approve(to, tokenId);
        }
    }

    function setApprovalForAll(address operator, bool approved) public  override  {
        if(!controlmarketplace)
            return ERC721Upgradeable.setApprovalForAll(operator, approved);
        else{
            //marketplace must in whitelist
            require(marketplacewhitelist[operator]==1, "marketpalce denied");
            return ERC721Upgradeable.setApprovalForAll(operator, approved);
        }
        
    }
}

