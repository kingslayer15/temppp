// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IStakePool{
    function isStaking(uint256 tokenId) external view returns(bool);
}