// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IFreeCityGameNFT.sol";
import "./interfaces/ICardERC1155.sol";
import "./interfaces/IVipERC1155.sol";

contract BenefitCard is OwnableUpgradeable, AccessControlEnumerableUpgradeable {

    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.UintToUintMap;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct Round {
        uint256 totalSupply;
        uint256 alreadNonce;
        mapping(uint256 => uint256) indices;
        EnumerableMapUpgradeable.UintToUintMap priceRangeMap;
        string baseUri;
    }


    bool private canSell;
    address public freeCity;
    address public erc1155Card;
    address public erc1155Vip;
    uint256 public currentRound;
    uint256 public mintAmount;
    mapping(uint256 => Round) private rounds;
    mapping(address => uint256) public userBuyTotal;
    // address -> vipType -> alread use
    mapping(address => mapping(uint256 => uint256)) public vipTotal;


    event BuyEvent(address indexed user, uint256 indexed count, uint256 round, uint256 value);
    event BuyVipEvent(address indexed user, uint256 indexed tokenId, uint256 count, uint256 value);
    event AirdropFcm(address indexed airdroper, address[] tos, uint256[] numberOfTokens);

    address private _payee = 0xF9EA233D38a550c3C546B100fba94bDBb5a4a5be;


    function initialize(address _owner, address _payee_, uint256 _mintAmount, address _freeCity, address _erc1155Card, address _erc1155Vip) public initializer {
        _transferOwnership(_owner);
        __BenefitCard_init_Role(_owner);
        mintAmount = _mintAmount;
        freeCity = _freeCity;
        erc1155Card = _erc1155Card;
        erc1155Vip = _erc1155Vip;
        _payee = _payee_;
    }

    function __BenefitCard_init_Role(address _owner) internal onlyInitializing {
        _setupRole(ADMIN_ROLE, _owner);
        // _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _owner);
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
    }

    function setCanSell(bool _canSell) external onlyRole(OPERATOR_ROLE) {
        canSell = _canSell;
    }


    // sell box
    function preSale(uint256 numberOfTokens) external payable {
        require(canSell && currentRound >= 1, "not allowed to buy");
        uint256 alreadNonce = rounds[currentRound].alreadNonce;
        uint256 totalSupply = rounds[currentRound].totalSupply;
        string memory baseUri = rounds[currentRound].baseUri;
        require(totalSupply > 0, "totalSupply error");
        require(alreadNonce + numberOfTokens <= totalSupply, "sell out");
        require(userBuyTotal[msg.sender] + numberOfTokens <= mintAmount, "Exceeded times");
        require(msg.value == getMintPrice(msg.sender, numberOfTokens), "value error");
        if(numberOfTokens == 1) {
            uint256 metaDataId = randomIndex();
            IFreeCityGameNFT(freeCity).preMint(msg.sender, metaDataId, baseUri);
        } else {
            uint256[] memory metaDataIds = new uint256[](numberOfTokens);
            for(uint256 i = 0 ; i < numberOfTokens; i++) {
                metaDataIds[i] = randomIndex();
            }
            IFreeCityGameNFT(freeCity).multiPreMint(msg.sender, metaDataIds, baseUri);
        }
        userBuyTotal[msg.sender] = userBuyTotal[msg.sender] + numberOfTokens;
        (bool success,) = payable(_payee).call{value : msg.value}("");
        require(success, "payble error");
        emit BuyEvent(msg.sender, numberOfTokens, currentRound, msg.value);
    }

    // buy vip
    function saleVip(uint256 tokenId, uint256 numberOfTokens) external payable {
        require(numberOfTokens > 0 , "number error");
        (uint256 price, uint256 totalSupply) = IVipERC1155(erc1155Vip).getVipProviso(tokenId);
        uint256 needTi = _needVipTicket(numberOfTokens, totalSupply);
        require(vipTotal[msg.sender][tokenId] + needTi <= userBuyTotal[msg.sender], "no enough ticket");
        require(price * numberOfTokens == msg.value, "value error");
        IVipERC1155(erc1155Vip).multiMint(msg.sender, tokenId, numberOfTokens);
        vipTotal[msg.sender][tokenId] = vipTotal[msg.sender][tokenId] + needTi;
        (bool success,) = payable(_payee).call{value : msg.value}("");
        require(success, "payble error");
        emit BuyVipEvent(msg.sender, tokenId,numberOfTokens, msg.value);
    }

    // admin airdrop
    function airdropFcm(address[] memory tos, uint256[] memory numberOfTokens) external onlyRole(OPERATOR_ROLE){
        require(tos.length == numberOfTokens.length, "Invalid value.");
        for(uint256 i = 0; i < tos.length; i++){
            string memory baseUri = rounds[currentRound].baseUri;
            require(rounds[currentRound].totalSupply > 0, "totalSupply error");
            require(rounds[currentRound].alreadNonce + numberOfTokens[i] <= rounds[currentRound].totalSupply, "mint out");
            require(userBuyTotal[tos[i]] + numberOfTokens[i] <= mintAmount, "Exceeded times");
            if(numberOfTokens[i] == 1) {
                uint256 metaDataId = randomIndex();
                IFreeCityGameNFT(freeCity).preMint(tos[i], metaDataId, baseUri);
            } else {
                uint256[] memory metaDataIds = new uint256[](numberOfTokens[i]);
                for(uint256 j = 0 ; j < numberOfTokens[i]; j++) {
                    metaDataIds[j] = randomIndex();
                }
                IFreeCityGameNFT(freeCity).multiPreMint(tos[i], metaDataIds, baseUri);
            }
            userBuyTotal[tos[i]] = userBuyTotal[tos[i]] + numberOfTokens[i];
            emit AirdropFcm(msg.sender, tos, numberOfTokens);
        }
    }

    function _needVipTicket(uint256 numberOfTokens, uint256 totalSupply) private pure returns(uint256) {
        uint256 _step = 500;
        uint256 _need = 0;
        if (totalSupply > _step) {
            _need = numberOfTokens * 10;
        } else if (totalSupply + numberOfTokens <= _step) {
            _need = numberOfTokens * 5;
        } else {
            for (uint256 i = 1; i <= numberOfTokens; i++) {
                if (totalSupply + i <= _step) {
                    _need += 5;
                } else {
                    _need += 10;
                }
            }
        }
        return _need;
    }


    /*function setToken(uint i) public {
        uint tokenId = randomIndex();
        testTokens[i] = tokenId;
    }*/

    function randomIndex() private returns (uint256) {
        uint256 nonce = rounds[currentRound].alreadNonce;
        uint256 totalSize = rounds[currentRound].totalSupply - nonce;
        mapping(uint256 => uint256) storage indices = rounds[currentRound].indices;
        uint256 index = uint256(
            keccak256(abi.encodePacked(nonce, msg.sender, block.difficulty, block.timestamp))) % totalSize;
        uint256 value = 0;
        if (indices[index] != 0) {
            value = indices[index];
        } else {
            value = index;
        }
        if (indices[totalSize - 1] == 0) {
            indices[index] = totalSize - 1;
        } else {
            indices[index] = indices[totalSize - 1];
        }
        rounds[currentRound].alreadNonce = rounds[currentRound].alreadNonce + 1;
        return value + 1;
    }

    /* function getCurrentRoundTotalIndex() private view returns (uint256) {
         uint256 index = 1;
         uint256 startIndex = 0;
         while (index < currentRound) {
             startIndex = startIndex + rounds[index].totalSupply;
             index = index + 1;
         }
         return startIndex;
     }*/


    // get pay price
    function getMintPrice(address account, uint256 numberOfTokens) public view returns (uint256) {
        require(numberOfTokens > 0, "n1");
        uint256 discount = ICardERC1155(erc1155Card).getDisCount(account);
        uint256 alreadNonce = rounds[currentRound].alreadNonce;
        uint256 minNonce = alreadNonce + 1;
        uint256 maxNonce = alreadNonce + numberOfTokens;
        require(maxNonce <= rounds[currentRound].totalSupply, "the maximum value is exceeded");
        uint256 totalPrice = 0;
        if (numberOfTokens == 1) {
            return getRoundBasePrice(currentRound) * discount / 100;
        } else {
            uint256 length = rounds[currentRound].priceRangeMap.length();
            for (uint256 i = 0; i < length; i++) {
                (uint256 range, uint256 price1) = rounds[currentRound].priceRangeMap.at(i);
                if (minNonce <= range && maxNonce <= range) {
                    return price1 * numberOfTokens * discount / 100;
                } else if (minNonce <= range && maxNonce > range) {
                    totalPrice = totalPrice + (range - minNonce + 1) * price1;
                    (, uint256 price2) = rounds[currentRound].priceRangeMap.at(i + 1);
                    totalPrice = totalPrice + (maxNonce - range) * price2;
                    return totalPrice * discount / 100;
                }
            }
            return 10 ** 18;
        }
    }

    function getVipPrice(uint256 tokenId, uint256 numberOfTokens) public view returns (uint256) {
        (uint256 price,) = IVipERC1155(erc1155Vip).getVipProviso(tokenId);
        return price * numberOfTokens;
    }


    function withDraw(address to) public onlyRole(ADMIN_ROLE) {
        payable(to).transfer(address(this).balance);
    }

    function setFreeCityContract(address _freeCity) external onlyRole(OPERATOR_ROLE) {
        freeCity = _freeCity;
    }

    function setErc1155CardContract(address _erc1155Card) external onlyRole(OPERATOR_ROLE) {
        erc1155Card = _erc1155Card;
    }

    function setErc1155VipContract(address _erc1155Vip) external onlyRole(OPERATOR_ROLE) {
        erc1155Vip = _erc1155Vip;
    }


    function setCurrentRound(uint256 _round) public onlyRole(OPERATOR_ROLE) {
        currentRound = _round;
    }

    function updateRoundInfo(uint256 _round, uint256 _totalSupply, uint256 _alreadNonce, string calldata baseUri, uint256[] memory ranges, uint256[] memory prices) public onlyRole(OPERATOR_ROLE) {
        require(_round > 0, "n1");
        Round storage round = rounds[_round];
        round.totalSupply = _totalSupply;
        round.alreadNonce = _alreadNonce;
        round.baseUri = baseUri;
        for (uint256 i = 0; i < ranges.length; i++) {
            rounds[_round].priceRangeMap.set(ranges[i], prices[i]);
        }
    }

    // set round info
    function setRoundInfo(uint256 _round, uint256 _totalSupply, string calldata baseUri, uint256[] memory ranges, uint256[] memory prices) public onlyRole(OPERATOR_ROLE) {
        require(_round > currentRound, "n1");
        require(ranges.length == prices.length, "n2");
        require(ranges[ranges.length - 1] == _totalSupply, "n3");
        currentRound = _round;
        if (!canSell) {
            canSell = true;
        }
        Round storage round = rounds[_round];
        round.totalSupply = _totalSupply;
        round.alreadNonce = 0;
        round.baseUri = baseUri;
        for (uint256 i = 0; i < ranges.length; i++) {
            rounds[_round].priceRangeMap.set(ranges[i], prices[i]);
        }
    }

    function getRoundInfo(uint256 _round) public view returns (uint256 total, uint256 alreadyTotal, uint256 price) {
        if (_round == 0) {
            return (rounds[currentRound].totalSupply, rounds[currentRound].alreadNonce, getRoundBasePrice(currentRound));
        } else {
            Round storage round = rounds[_round];
            return (round.totalSupply, round.alreadNonce, getRoundBasePrice(_round));
        }
    }


    function getRoundBasePrice(uint256 _round) private view returns (uint256) {
        if (_round == 0) {
            _round = currentRound;
        }
        Round storage round = rounds[_round];
        uint256 alreadNonce = round.alreadNonce;
        uint256 length = round.priceRangeMap.length();
        for (uint256 i = 0; i < length; i++) {
            (uint256 range, uint256 price1) = round.priceRangeMap.at(i);
            if (alreadNonce + 1 <= range) {
                return price1;
            }
        }
        (, uint256 price2) = round.priceRangeMap.at(length - 1);
        return price2;
    }

    function getPriceRange(uint256 _round) public view returns (uint256[] memory, uint256[] memory) {
        if (_round == 0) {
            _round = currentRound;
        }
        Round storage round = rounds[_round];
        uint256 length = round.priceRangeMap.length();
        uint256[] memory smallRounds = new uint256[](length);
        uint256[] memory prices = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            (uint256 range, uint256 price) = round.priceRangeMap.at(i);
            smallRounds[i] = range;
            prices[i] = price;
        }
        return (smallRounds, prices);
    }

    function setMintAmount(uint256 _mintAmount) external onlyRole(OPERATOR_ROLE) {
        mintAmount = _mintAmount;
    }

    // set role
    function setRoleAdmin(bytes32 roleId, bytes32 adminRoleId) external onlyRole(ADMIN_ROLE) {
        _setRoleAdmin(roleId, adminRoleId);
    }

    // add role account
    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function setPayee(address _newPayee) external onlyRole(ADMIN_ROLE) {
        _payee = _newPayee;
    }
    function getPayee() external view returns(address){
        return _payee;
    }

}