// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Events {
    event TaxRateSet(uint256 taxRate);

    event NFTSeized(address prevOwner, address to, uint256 tokenId);
    event NFTBought(address prevOwner, address newOwner, uint256 tokenId, uint256 price);
}
