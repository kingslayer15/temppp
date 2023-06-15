// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFreeCityGameNFTv1 {
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function totalSupply() external view returns(uint256);
}