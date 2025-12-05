// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { IERC721 } from "../../lib/forge-std/src/interfaces/IERC721.sol";

interface IERC721Harberger is IERC721 {
    // Pricing of the NFT
    function setPrice(uint256 price) external;
    function getPrice() external view returns (uint256);

    // Taxation
    function setTaxRate(uint256 taxRate) external;
    function getTaxRate() external view returns (uint256);
    function payTax() external;

    function withdrawTaxesToDAO() external;

    function currentTaxEpoch() external;
    function taxEpochEnd() external;

    // Ownership transfer
    function buy() external;
}
