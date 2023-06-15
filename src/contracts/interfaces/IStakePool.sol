// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IStakePool{
    function isStaking(uint256 tokenId) external view returns(bool);
}