# NFT存储合约(NFTVault)

## 合约简介
提供NFT存储提出查看

## 合约地址
```
正式:
    无
测试Goerli:
    无
测试Sepolia:
    0x52B9e98ee912E2174cD9e65eF841B5E64E25Ff56

```

## ABI
```
[
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": true,
          "internalType": "address",
          "name": "previousOwner",
          "type": "address"
        },
        {
          "indexed": true,
          "internalType": "address",
          "name": "newOwner",
          "type": "address"
        }
      ],
      "name": "OwnershipTransferred",
      "type": "event"
    },
    {
      "inputs": [],
      "name": "owner",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function",
      "constant": true
    },
    {
      "inputs": [],
      "name": "renounceOwnership",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "newOwner",
          "type": "address"
        }
      ],
      "name": "transferOwnership",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "contractAddress",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "tokenId",
          "type": "uint256"
        }
      ],
      "name": "deposit",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "contractAddress",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "to",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "tokenId",
          "type": "uint256"
        }
      ],
      "name": "withdraw",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "contractAddress",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "to",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "tokenId",
          "type": "uint256"
        }
      ],
      "name": "adminWithdraw",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "depositor",
          "type": "address"
        }
      ],
      "name": "getDeposits",
      "outputs": [
        {
          "components": [
            {
              "internalType": "address",
              "name": "contractAddress",
              "type": "address"
            },
            {
              "internalType": "uint256",
              "name": "tokenId",
              "type": "uint256"
            }
          ],
          "internalType": "struct NFTVault.NFT[]",
          "name": "",
          "type": "tuple[]"
        }
      ],
      "stateMutability": "view",
      "type": "function",
      "constant": true
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "contractAddress",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "tokenId",
          "type": "uint256"
        }
      ],
      "name": "getTokenURI",
      "outputs": [
        {
          "internalType": "string",
          "name": "",
          "type": "string"
        }
      ],
      "stateMutability": "view",
      "type": "function",
      "constant": true
    }
  ]
```

## 交易接口
#### 1.存款函数，接收合约地址和tokenId作为参数
```JavaScript
    function deposit(address contractAddress, uint256 tokenId);
    说明: 存款函数，接收合约地址和tokenId作为参数，调用前需要先调用contractAddress的approve方法，授权给本合约
        approve方法的to为本合约地址，tokenId为需存入NFTtokenId
        function approve(address to, uint256 tokenId) public virtual override;

    入参:
        contractAddress: NFT的合约地址
        tokenId : NFT的tokenId

```
#### 2.提款函数，接收合约地址和tokenId作为参数
```JavaScript
    // 提款函数，接收合约地址和tokenId作为参数
    function withdraw(address contractAddress, uint256 tokenId);
    说明: 提款函数，接收合约地址和tokenId作为参数

    入参:
        contractAddress: NFT的合约地址
        tokenId : NFT的tokenId
```

#### 3.获取存款函数，接收存款人地址作为参数，返回NFT数组
```JavaScript
    // 获取存款函数，接收存款人地址作为参数，返回NFT数组
    function getDeposits(address depositor) public view returns (NFT[] memory) ;
    说明: 获取存款函数，接收存款人地址作为参数，返回NFT数组

    入参:
        depositor: 用户地址
    返回:
        1.NFT数组：
            // NFT结构体，包含合约地址和tokenId
            struct NFT {
               address contractAddress; // 合约地址
               uint256 tokenId; // tokenId
            }
```

#### 4.获取令牌URI函数，接收合约地址和tokenId作为参数，返回令牌的URI
```JavaScript
    // 获取令牌URI函数，接收合约地址和tokenId作为参数，返回令牌的URI
    function getTokenURI(address contractAddress, uint256 tokenId) public view returns (string memory);
    说明: 获取令牌URI函数，接收合约地址和tokenId作为参数，返回令牌的URI

    入参:
        contractAddress: NFT的合约地址
        tokenId : NFT的tokenId
    返回:
        1.URI：string
}
```
