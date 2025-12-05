// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IERC721Harberger {
    // Pricing of the NFT
    function setPrice(uint256 price) external;
    function getPrice() external view returns (uint256);

    // Taxation
    function setTaxRate(uint256 taxRate) external;
    function getTaxRate() external view returns (uint256);
    function payTax() external;

    function withdrawTaxesToDao() external;

    function currentTaxEpoch() external;
    function taxEpochEnd() external;

    // Ownership transfer
    function buy() external;
}
