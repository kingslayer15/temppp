pragma solidity ^0.8.0;

interface IVipERC1155 {
    function getVipProviso(uint256 id) external view returns (uint256, uint256);
    function mint(address to, uint256 tokenId) external;
    function multiMint(address to, uint256 tokenId, uint256 amount) external;
    function batchMint(address[] calldata tos, uint256[] calldata tokenIds) external;
}