// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/common/ERC2981Upgradeable.sol";

contract FreeCityWorldCup2022 is
    Initializable,
    AccessControlEnumerableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC2981Upgradeable
{
    using StringsUpgradeable for uint256;
    uint256 public index; 
    uint256 public totalAmount;
    uint256 private round;
    uint256 private round1Total;
    uint256 private round1MintAmount;

    string  private baseUri;

    mapping(uint256 => uint256) private indices;
    mapping(uint256 => uint256) public salts;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function initialize(string memory name, string memory symbol)
        public
        virtual
        initializer
    {
        __ERC721_init_unchained(name, symbol);
        __TeamNft_init_unchained(name, symbol);
        round = 1;
        round1Total = 700;
        totalAmount = 2752;
    }

    function __TeamNft_init_unchained(string memory, string memory)
        internal
        onlyInitializing
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }



    function grantMintRole(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "n1");
        _grantRole(MINTER_ROLE, to);
    }

    function _setBaseURI(string memory baseURI) internal {
        baseUri = baseURI;
    }

    function setBaseURI(string memory baseURI) public onlyRole(MINTER_ROLE) {
        _setBaseURI(baseURI);
    }


    function tokenURI(uint256 tokenId) public view  override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = baseUri;
        return string(abi.encodePacked(baseURI,"/",(tokenId.toString()),".json"));
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


    function newRound() public onlyRole(DEFAULT_ADMIN_ROLE){
        round = 2;
        round1MintAmount = index;
    }

    function numberOfTwoRounds() public view returns (uint256 round1Amount, uint256 round2Amount) {
        if(round == 1) {
            round1Amount = index;
            round2Amount = 0;
        }
        else {
            round1Amount = round1MintAmount;
            round2Amount = index - round1MintAmount;
        }
    }

    function getEndTokenId(uint _tokenId) public pure returns(uint _endTokenId) {
        uint _teamNumber = (_tokenId / 86 ) + uint(1);
        uint _memberNumber = (_tokenId % 86 ) + uint(1);
        _endTokenId = (_teamNumber * 100) + _memberNumber;
    }


    function mint(address to) external onlyRole(MINTER_ROLE){
        if(round == 1){
            require(index + uint(1) <= round1Total,"Exceed the amount limit of round 1 nft mint");
        }
        require(index + uint(1) <= totalAmount,"Exceed the total amount limit ");
        uint _tokenId = randomIndex();
        uint _endTokenId = getEndTokenId(_tokenId);
         _safeMint(to, _endTokenId);

    }


    function batchMint(address[] memory tos) external onlyRole(MINTER_ROLE)
    {
        if(round == 1){
            require(index + tos.length <= round1Total,"Exceed the amount limit of round 1 nft mint");
        }
        require(index + tos.length <= totalAmount,"Exceed the total amount limit ");
        for (uint256 i = 0 ; i < tos.length ; i++){
            uint _tokenId = randomIndex();
            uint _endTokenId = getEndTokenId(_tokenId);
            _safeMint(tos[i], _endTokenId);
        }
        
    }

    function airdrop(address to,uint256 salt, bytes32 _hash,uint8 v,bytes32 r,bytes32 s) external {
        require(keccak256(abi.encode(to,salt))==_hash,"hash error");
        require(hasRole(MINTER_ROLE, ecrecover(_hash, v, r, s)), "sign error");
        require(salts[salt]==0,"salt repeat");
        if(round == 1){
            require(index + uint(1) <= round1Total,"Exceed the amount limit of round 1 nft mint");
        }
        require(index + uint(1) <= totalAmount,"Exceed the total amount limit ");
        uint _tokenId = randomIndex();
        uint _endTokenId = getEndTokenId(_tokenId);
         _safeMint(to, _endTokenId);
         salts[salt]=1;
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
        uint256 bathcSize
    )
        internal
        override(
            ERC721EnumerableUpgradeable,
            ERC721Upgradeable
        )
    {
        super._beforeTokenTransfer(from, to, tokenId, bathcSize);
    }




    
    
}

