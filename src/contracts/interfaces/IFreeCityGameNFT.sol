// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFreeCityGameNFT {
    // 铸造麦克风NFT
    function preMint(address to, uint256 metaDataId, string calldata baseUri) external;
    function multiPreMint(address to, uint256[] calldata metaDataIds, string calldata baseUri) external;
}